/// FAT16/FAT32 filesystem driver.
///
/// Supports: MBR partition table, BPB parsing, directory listing, cluster chain
/// traversal, file reading, and file writing. Long file names (LFN) are supported for reading.
struct FATFileSystem {
    private var sd: SDCard

    private var isFAT32: Bool = false
    private var sectorsPerCluster: UInt32 = 0
    private var reservedSectors: UInt32 = 0
    private var numberOfFATs: UInt32 = 0
    private var fatSizeSectors: UInt32 = 0
    private var rootDirCluster: UInt32 = 0   // FAT32 only
    private var rootDirSectors: UInt32 = 0   // FAT16 only
    private var rootDirEntries: UInt32 = 0   // FAT16 only
    private var partitionLBA: UInt32 = 0
    private var fatStartSector: UInt32 = 0
    private var dataStartSector: UInt32 = 0
    private var rootDirStartSector: UInt32 = 0  // FAT16 only

    private var sectorBuf: UnsafeMutablePointer<UInt8>

    // FAT sector cache: a dedicated 512-byte buffer that holds the most recently
    // accessed FAT sector. Without this cache, walking a long cluster chain
    // (e.g. font.bin during boot) re-reads the same FAT sector hundreds of times
    // — each FAT32 sector covers 128 consecutive cluster entries, so a sequential
    // walk only needs one SD read per 128 clusters when the cache is hit.
    // The cache uses its own buffer (not sectorBuf) so other code paths that
    // overwrite sectorBuf (directory parsing, file I/O) don't invalidate it.
    private var fatCacheBuf: UnsafeMutablePointer<UInt8>
    private var fatCacheSector: UInt32 = 0xFFFF_FFFF  // sentinel: nothing cached

    // LFN assembly
    private var lfnUtf16Buf: UnsafeMutablePointer<UInt16>
    private var lfnUtf8Buf: UnsafeMutablePointer<UInt8>
    private var lfnMaxSeq: Int = 0
    private var lfnActive: Bool = false

    init(sd: SDCard) {
        self.sd = sd
        self.sectorBuf = .allocate(capacity: 512)
        self.fatCacheBuf = .allocate(capacity: 512)
        self.lfnUtf16Buf = .allocate(capacity: 260)  // 20 entries * 13 chars
        self.lfnUtf8Buf = .allocate(capacity: 768)    // worst case UTF-8
    }

    /// Replace the internal SD card reference (e.g. after re-initialization).
    mutating func replaceSD(_ newSD: SDCard) {
        sd = newSD
        fatCacheSector = 0xFFFF_FFFF
    }

    // MARK: - Mount

    /// Mount the first FAT partition found on the SD card.
    mutating func mount() -> Bool {
        // Invalidate the FAT cache: re-mounting may switch to a different
        // partition or filesystem layout, so any previously cached sector is stale.
        fatCacheSector = 0xFFFF_FFFF

        // Read MBR (sector 0)
        guard sd.readSector(sector: 0, into: sectorBuf) else { return false }

        // Check MBR signature
        guard sectorBuf[510] == 0x55, sectorBuf[511] == 0xAA else { return false }

        // Check if sector 0 is itself a BPB (no MBR, superfloppy format)
        if sectorBuf[0] == 0xEB || sectorBuf[0] == 0xE9 {
            partitionLBA = 0
        } else {
            // Read first partition entry (offset 0x1BE)
            let partType = sectorBuf[0x1BE + 4]
            guard partType == 0x0B || partType == 0x0C  // FAT32
               || partType == 0x06 || partType == 0x0E  // FAT16
               || partType == 0x01                       // FAT12 (we'll try)
            else { return false }

            partitionLBA = readU32(sectorBuf, offset: 0x1BE + 8)
        }

        // Read BPB (Volume Boot Record)
        guard sd.readSector(sector: partitionLBA, into: sectorBuf) else { return false }
        guard sectorBuf[510] == 0x55, sectorBuf[511] == 0xAA else { return false }

        let bytesPerSector = UInt32(readU16(sectorBuf, offset: 11))
        guard bytesPerSector == 512 else { return false }

        sectorsPerCluster = UInt32(sectorBuf[13])
        reservedSectors = UInt32(readU16(sectorBuf, offset: 14))
        numberOfFATs = UInt32(sectorBuf[16])
        rootDirEntries = UInt32(readU16(sectorBuf, offset: 17))

        let fatSize16 = UInt32(readU16(sectorBuf, offset: 22))
        let fatSize32 = readU32(sectorBuf, offset: 36)
        fatSizeSectors = fatSize16 != 0 ? fatSize16 : fatSize32

        fatStartSector = partitionLBA + reservedSectors

        if rootDirEntries == 0 {
            // FAT32
            isFAT32 = true
            rootDirCluster = readU32(sectorBuf, offset: 44)
            rootDirSectors = 0
            dataStartSector = fatStartSector + numberOfFATs * fatSizeSectors
        } else {
            // FAT16
            isFAT32 = false
            rootDirSectors = (rootDirEntries * 32 + 511) / 512
            dataStartSector = fatStartSector + numberOfFATs * fatSizeSectors + rootDirSectors
            rootDirStartSector = fatStartSector + numberOfFATs * fatSizeSectors
        }

        return true
    }

    // MARK: - Directory Entry

    struct DirEntry {
        var name: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0,0,0,0,0,0,0,0)
        var ext: (UInt8, UInt8, UInt8) = (0,0,0)
        var attr: UInt8 = 0
        var ntRes: UInt8 = 0    // byte 12: bit 3 = name lowercase, bit 4 = ext lowercase
        var cluster: UInt32 = 0
        var fileSize: UInt32 = 0
        /// LFN as UTF-8. Points to FATFileSystem's internal buffer; valid only during visitor callback.
        var lfnPtr: UnsafePointer<UInt8>? = nil
        var lfnLen: Int = 0

        var isDirectory: Bool { attr & 0x10 != 0 }
        var isHidden: Bool { attr & 0x02 != 0 }
        var isLFN: Bool { attr == 0x0F }
        var hasLFN: Bool { lfnLen > 0 }
    }

    // MARK: - Directory Listing

    /// Iterate over entries in the root directory.
    /// Calls `visitor` for each valid entry. Return `false` from visitor to stop.
    mutating func listRootDirectory(_ visitor: (DirEntry) -> Bool) {
        lfnActive = false
        lfnMaxSeq = 0
        if isFAT32 {
            listClusterChainDir(startCluster: rootDirCluster, visitor)
        } else {
            listFAT16RootDir(visitor)
        }
    }

    /// List entries in a subdirectory given by its start cluster.
    mutating func listDirectory(cluster: UInt32, _ visitor: (DirEntry) -> Bool) {
        lfnActive = false
        lfnMaxSeq = 0
        listClusterChainDir(startCluster: cluster, visitor)
    }

    // MARK: - File Lookup

    /// Find a file in the root directory by 8.3 name.
    /// Sets `cluster` and `fileSize` on success, returns true if found.
    mutating func findFile(
        name: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        ext: (UInt8, UInt8, UInt8),
        cluster: inout UInt32,
        fileSize: inout UInt32
    ) -> Bool {
        var foundCluster: UInt32 = 0
        var foundSize: UInt32 = 0
        var found = false
        listRootDirectory { entry in
            if entry.name.0 == name.0 && entry.name.1 == name.1 &&
               entry.name.2 == name.2 && entry.name.3 == name.3 &&
               entry.name.4 == name.4 && entry.name.5 == name.5 &&
               entry.name.6 == name.6 && entry.name.7 == name.7 &&
               entry.ext.0 == ext.0 && entry.ext.1 == ext.1 && entry.ext.2 == ext.2 {
                foundCluster = entry.cluster
                foundSize = entry.fileSize
                found = true
                return false  // stop
            }
            return true  // continue
        }
        if found {
            cluster = foundCluster
            fileSize = foundSize
        }
        return found
    }

    // MARK: - File Reading

    /// Read a file into a buffer, up to `maxBytes`. Returns bytes read.
    mutating func readFile(entry: DirEntry, into buffer: UnsafeMutablePointer<UInt8>,
                           maxBytes: Int) -> Int {
        var cluster = entry.cluster
        var bytesRead = 0
        let totalSize = min(Int(entry.fileSize), maxBytes)

        while bytesRead < totalSize && cluster >= 2 {
            let sectorBase = clusterToSector(cluster)
            for s in 0..<sectorsPerCluster {
                if bytesRead >= totalSize { break }
                guard sd.readSector(sector: sectorBase + s, into: sectorBuf) else { return bytesRead }
                let toCopy = min(512, totalSize - bytesRead)
                for i in 0..<toCopy {
                    buffer[bytesRead + i] = sectorBuf[i]
                }
                bytesRead += toCopy
            }
            cluster = nextCluster(cluster)
        }
        return bytesRead
    }

    // MARK: - Random Access (Cluster Map)

    /// Build a cluster map for a file, enabling O(1) random access.
    /// Walks the FAT chain once and stores cluster numbers sequentially.
    /// Returns the number of clusters stored.
    mutating func buildClusterMap(startCluster: UInt32,
                                  into map: UnsafeMutablePointer<UInt32>,
                                  maxClusters: Int) -> Int {
        var cluster = startCluster
        var count = 0
        while cluster >= 2 && count < maxClusters {
            map[count] = cluster
            count += 1
            cluster = nextCluster(cluster)
        }
        return count
    }

    /// Read arbitrary bytes from a file using a pre-built cluster map.
    /// Returns the number of bytes actually read.
    mutating func readBytes(clusterMap: UnsafeMutablePointer<UInt32>,
                            clusterCount: Int,
                            fileOffset: Int,
                            into buffer: UnsafeMutablePointer<UInt8>,
                            count: Int) -> Int {
        let bytesPerCluster = Int(sectorsPerCluster) * 512
        var remaining = count
        var bufOffset = 0
        var offset = fileOffset

        while remaining > 0 {
            let clusterIndex = offset / bytesPerCluster
            guard clusterIndex < clusterCount else { break }

            let offsetInCluster = offset % bytesPerCluster
            let sectorInCluster = offsetInCluster / 512
            let offsetInSector = offsetInCluster % 512

            let cluster = clusterMap[clusterIndex]
            let sectorBase = clusterToSector(cluster)
            let sector = sectorBase + UInt32(sectorInCluster)

            guard sd.readSector(sector: sector, into: sectorBuf) else { break }

            let available = 512 - offsetInSector
            let toCopy = min(available, remaining)
            for i in 0..<toCopy {
                buffer[bufOffset + i] = sectorBuf[offsetInSector + i]
            }

            bufOffset += toCopy
            offset += toCopy
            remaining -= toCopy
        }

        return bufOffset
    }

    // MARK: - Private: FAT Chain

    private mutating func nextCluster(_ cluster: UInt32) -> UInt32 {
        if isFAT32 {
            let fatOffset = cluster * 4
            let fatSector = fatStartSector + fatOffset / 512
            let entryOffset = Int(fatOffset % 512)
            guard readFATSector(fatSector) else { return 0 }
            let next = readU32(fatCacheBuf, offset: entryOffset) & 0x0FFF_FFFF
            return next >= 0x0FFF_FFF8 ? 0 : next
        } else {
            let fatOffset = cluster * 2
            let fatSector = fatStartSector + fatOffset / 512
            let entryOffset = Int(fatOffset % 512)
            guard readFATSector(fatSector) else { return 0 }
            let next = UInt32(readU16(fatCacheBuf, offset: entryOffset))
            return next >= 0xFFF8 ? 0 : next
        }
    }

    /// Load a FAT sector into the dedicated cache buffer, skipping the SD read
    /// when the requested sector is already cached. This turns sequential
    /// cluster-chain walks from O(N) SD reads into O(N / entriesPerSector).
    private mutating func readFATSector(_ sector: UInt32) -> Bool {
        if sector == fatCacheSector { return true }
        guard sd.readSector(sector: sector, into: fatCacheBuf) else {
            fatCacheSector = 0xFFFF_FFFF
            return false
        }
        fatCacheSector = sector
        return true
    }

    private func clusterToSector(_ cluster: UInt32) -> UInt32 {
        dataStartSector + (cluster - 2) * sectorsPerCluster
    }

    // MARK: - Private: Directory Parsing

    private mutating func listFAT16RootDir(_ visitor: (DirEntry) -> Bool) {
        for s in 0..<rootDirSectors {
            guard sd.readSector(sector: rootDirStartSector + s, into: sectorBuf) else { return }
            if !parseDirSector(visitor) { return }
        }
    }

    private mutating func listClusterChainDir(startCluster: UInt32, _ visitor: (DirEntry) -> Bool) {
        var cluster = startCluster
        while cluster >= 2 {
            let sectorBase = clusterToSector(cluster)
            for s in 0..<sectorsPerCluster {
                guard sd.readSector(sector: sectorBase + s, into: sectorBuf) else { return }
                if !parseDirSector(visitor) { return }
            }
            cluster = nextCluster(cluster)
        }
    }

    /// Parse one sector of directory entries. Returns false to stop iteration.
    private mutating func parseDirSector(_ visitor: (DirEntry) -> Bool) -> Bool {
        for i in 0..<16 {  // 16 entries per sector (32 bytes each)
            let base = i * 32
            let firstByte = sectorBuf[base]
            if firstByte == 0x00 { return false }  // End of directory
            if firstByte == 0xE5 {
                lfnActive = false
                continue
            }

            let attr = sectorBuf[base + 11]
            if attr == 0x0F {
                // LFN entry
                let seq = firstByte
                if seq & 0x40 != 0 {
                    // First LFN entry encountered (last part of name)
                    lfnActive = true
                    lfnMaxSeq = Int(seq & 0x1F)
                }
                if lfnActive {
                    extractLFNEntry(base: base, seqNum: Int(seq & 0x1F))
                }
                continue
            }

            var entry = DirEntry()
            entry.name = (
                sectorBuf[base], sectorBuf[base+1], sectorBuf[base+2], sectorBuf[base+3],
                sectorBuf[base+4], sectorBuf[base+5], sectorBuf[base+6], sectorBuf[base+7]
            )
            entry.ext = (sectorBuf[base+8], sectorBuf[base+9], sectorBuf[base+10])
            entry.attr = attr
            entry.ntRes = sectorBuf[base + 12]

            let clusterHi = UInt32(readU16(sectorBuf, offset: base + 20))
            let clusterLo = UInt32(readU16(sectorBuf, offset: base + 26))
            entry.cluster = (clusterHi << 16) | clusterLo
            entry.fileSize = readU32(sectorBuf, offset: base + 28)

            if lfnActive {
                let len = convertLFNtoUTF8()
                entry.lfnPtr = UnsafePointer(lfnUtf8Buf)
                entry.lfnLen = len
                lfnActive = false
            }

            if !visitor(entry) { return false }
        }
        return true
    }

    // MARK: - LFN Support

    /// Extract 13 UTF-16LE characters from an LFN directory entry.
    private func extractLFNEntry(base: Int, seqNum: Int) {
        let charBase = (seqNum - 1) * 13

        // Characters 1–5: bytes 1–10
        for j in 0..<5 {
            let lo = UInt16(sectorBuf[base + 1 + j * 2])
            let hi = UInt16(sectorBuf[base + 2 + j * 2])
            lfnUtf16Buf[charBase + j] = lo | (hi << 8)
        }
        // Characters 6–11: bytes 14–25
        for j in 0..<6 {
            let lo = UInt16(sectorBuf[base + 14 + j * 2])
            let hi = UInt16(sectorBuf[base + 15 + j * 2])
            lfnUtf16Buf[charBase + 5 + j] = lo | (hi << 8)
        }
        // Characters 12–13: bytes 28–31
        for j in 0..<2 {
            let lo = UInt16(sectorBuf[base + 28 + j * 2])
            let hi = UInt16(sectorBuf[base + 29 + j * 2])
            lfnUtf16Buf[charBase + 11 + j] = lo | (hi << 8)
        }
    }

    /// Convert collected UTF-16 LFN to UTF-8. Returns byte count.
    private func convertLFNtoUTF8() -> Int {
        var out = 0
        var i = 0
        let maxChars = lfnMaxSeq * 13

        while i < maxChars && out < 760 {
            let cp = lfnUtf16Buf[i]
            if cp == 0x0000 || cp == 0xFFFF { break }

            if cp < 0x80 {
                lfnUtf8Buf[out] = UInt8(cp)
                out += 1
            } else if cp < 0x800 {
                lfnUtf8Buf[out]     = UInt8(0xC0 | (cp >> 6))
                lfnUtf8Buf[out + 1] = UInt8(0x80 | (cp & 0x3F))
                out += 2
            } else if cp >= 0xD800 && cp <= 0xDBFF {
                // Surrogate pair
                i += 1
                if i < maxChars {
                    let lo = lfnUtf16Buf[i]
                    if lo >= 0xDC00 && lo <= 0xDFFF {
                        let u = UInt32(0x10000)
                            + UInt32(cp - 0xD800) * 0x400
                            + UInt32(lo - 0xDC00)
                        lfnUtf8Buf[out]     = UInt8(0xF0 | ((u >> 18) & 0x07))
                        lfnUtf8Buf[out + 1] = UInt8(0x80 | ((u >> 12) & 0x3F))
                        lfnUtf8Buf[out + 2] = UInt8(0x80 | ((u >> 6) & 0x3F))
                        lfnUtf8Buf[out + 3] = UInt8(0x80 | (u & 0x3F))
                        out += 4
                    }
                }
            } else {
                lfnUtf8Buf[out]     = UInt8(0xE0 | (cp >> 12))
                lfnUtf8Buf[out + 1] = UInt8(0x80 | ((cp >> 6) & 0x3F))
                lfnUtf8Buf[out + 2] = UInt8(0x80 | (cp & 0x3F))
                out += 3
            }
            i += 1
        }
        return out
    }

    // MARK: - Helpers

    private func readU16(_ buf: UnsafeMutablePointer<UInt8>, offset: Int) -> UInt16 {
        UInt16(buf[offset]) | (UInt16(buf[offset + 1]) << 8)
    }

    private func readU32(_ buf: UnsafeMutablePointer<UInt8>, offset: Int) -> UInt32 {
        UInt32(buf[offset])
        | (UInt32(buf[offset + 1]) << 8)
        | (UInt32(buf[offset + 2]) << 16)
        | (UInt32(buf[offset + 3]) << 24)
    }

    private func writeU16(_ buf: UnsafeMutablePointer<UInt8>, offset: Int, value: UInt16) {
        buf[offset]     = UInt8(truncatingIfNeeded: value)
        buf[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
    }

    private func writeU32(_ buf: UnsafeMutablePointer<UInt8>, offset: Int, value: UInt32) {
        buf[offset]     = UInt8(truncatingIfNeeded: value)
        buf[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
        buf[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
        buf[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
    }

    // MARK: - Writing: FAT Table

    /// Write a FAT entry for a cluster. Updates all FAT copies.
    private mutating func writeFATEntry(cluster: UInt32, value: UInt32) -> Bool {
        let entrySize: UInt32 = isFAT32 ? 4 : 2
        let fatOffset = cluster * entrySize
        let sectorOffset = fatOffset / 512
        let byteOffset = Int(fatOffset % 512)

        // Read-modify-write the first FAT copy
        let fatSector = fatStartSector + sectorOffset
        guard sd.readSector(sector: fatSector, into: sectorBuf) else { return false }

        if isFAT32 {
            let existing = readU32(sectorBuf, offset: byteOffset)
            let newVal = (existing & 0xF000_0000) | (value & 0x0FFF_FFFF)
            writeU32(sectorBuf, offset: byteOffset, value: newVal)
        } else {
            writeU16(sectorBuf, offset: byteOffset, value: UInt16(truncatingIfNeeded: value))
        }

        guard sd.writeSector(sector: fatSector, from: UnsafePointer(sectorBuf)) else { return false }

        // Invalidate the FAT read cache: the FAT contents just changed, so any
        // cached sector (whether or not it matches this one) might be stale on
        // the next read. Writes are off the hot path, so simple invalidation is
        // cheaper than tracking write-through.
        fatCacheSector = 0xFFFF_FFFF

        // Write to additional FAT copies
        for f: UInt32 in 1..<numberOfFATs {
            let copySector = fatStartSector + f * fatSizeSectors + sectorOffset
            guard sd.writeSector(sector: copySector, from: UnsafePointer(sectorBuf)) else { return false }
        }

        return true
    }

    /// Find a free cluster in the FAT and mark it as end-of-chain.
    /// Returns the cluster number, or 0 if the disk is full.
    private mutating func allocateCluster() -> UInt32 {
        let entrySize: UInt32 = isFAT32 ? 4 : 2
        let entriesPerSector = 512 / entrySize
        let endOfChain: UInt32 = isFAT32 ? 0x0FFF_FFF8 : 0xFFF8

        // Scan FAT sector by sector
        for sectorIdx: UInt32 in 0..<fatSizeSectors {
            guard sd.readSector(sector: fatStartSector + sectorIdx, into: sectorBuf) else { return 0 }

            for entryIdx: UInt32 in 0..<entriesPerSector {
                let cluster = sectorIdx * entriesPerSector + entryIdx
                if cluster < 2 { continue }  // Clusters 0 and 1 are reserved

                let offset = Int(entryIdx * entrySize)
                let entryVal: UInt32
                if isFAT32 {
                    entryVal = readU32(sectorBuf, offset: offset) & 0x0FFF_FFFF
                } else {
                    entryVal = UInt32(readU16(sectorBuf, offset: offset))
                }

                if entryVal == 0 {
                    // Free cluster found — mark as end-of-chain
                    if writeFATEntry(cluster: cluster, value: endOfChain) {
                        return cluster
                    }
                    return 0
                }
            }
        }
        return 0  // Disk full
    }

    // MARK: - Writing: Directory Entries

    /// Create a directory entry in the specified directory.
    /// For root directory, pass dirCluster = 0.
    private mutating func createDirEntry(
        dirCluster: UInt32,
        name: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        ext: (UInt8, UInt8, UInt8),
        attr: UInt8,
        startCluster: UInt32,
        fileSize: UInt32
    ) -> Bool {
        if dirCluster == 0 && !isFAT32 {
            return createDirEntryInFAT16Root(
                name: name, ext: ext, attr: attr,
                startCluster: startCluster, fileSize: fileSize)
        }
        let cluster = (dirCluster == 0) ? rootDirCluster : dirCluster
        return createDirEntryInClusterChain(
            startCluster: cluster, name: name, ext: ext, attr: attr,
            startFileCluster: startCluster, fileSize: fileSize)
    }

    private mutating func createDirEntryInFAT16Root(
        name: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        ext: (UInt8, UInt8, UInt8),
        attr: UInt8,
        startCluster: UInt32,
        fileSize: UInt32
    ) -> Bool {
        for s: UInt32 in 0..<rootDirSectors {
            let sector = rootDirStartSector + s
            guard sd.readSector(sector: sector, into: sectorBuf) else { return false }
            if let slot = findEmptyDirSlot() {
                writeDirSlot(slot: slot, name: name, ext: ext, attr: attr,
                             startCluster: startCluster, fileSize: fileSize)
                return sd.writeSector(sector: sector, from: UnsafePointer(sectorBuf))
            }
        }
        return false  // FAT16 root directory is full
    }

    private mutating func createDirEntryInClusterChain(
        startCluster: UInt32,
        name: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        ext: (UInt8, UInt8, UInt8),
        attr: UInt8,
        startFileCluster: UInt32,
        fileSize: UInt32
    ) -> Bool {
        var cluster = startCluster
        var prevCluster: UInt32 = 0

        while cluster >= 2 {
            let sectorBase = clusterToSector(cluster)
            for s: UInt32 in 0..<sectorsPerCluster {
                let sector = sectorBase + s
                guard sd.readSector(sector: sector, into: sectorBuf) else { return false }
                if let slot = findEmptyDirSlot() {
                    writeDirSlot(slot: slot, name: name, ext: ext, attr: attr,
                                 startCluster: startFileCluster, fileSize: fileSize)
                    return sd.writeSector(sector: sector, from: UnsafePointer(sectorBuf))
                }
            }
            prevCluster = cluster
            cluster = nextCluster(cluster)
        }

        // Directory is full — allocate a new cluster for it
        let newCluster = allocateCluster()
        if newCluster == 0 { return false }

        // Link previous last cluster to new cluster
        if !writeFATEntry(cluster: prevCluster, value: newCluster) { return false }

        // Zero-fill the new cluster
        for i in 0..<512 { sectorBuf[i] = 0 }
        let sectorBase = clusterToSector(newCluster)
        for s: UInt32 in 0..<sectorsPerCluster {
            guard sd.writeSector(sector: sectorBase + s, from: UnsafePointer(sectorBuf)) else { return false }
        }

        // Read back first sector and write the entry in slot 0
        guard sd.readSector(sector: sectorBase, into: sectorBuf) else { return false }
        writeDirSlot(slot: 0, name: name, ext: ext, attr: attr,
                     startCluster: startFileCluster, fileSize: fileSize)
        return sd.writeSector(sector: sectorBase, from: UnsafePointer(sectorBuf))
    }

    /// Find an empty directory entry slot (0x00 or 0xE5) in the current sectorBuf.
    /// Returns the slot index (0–15), or nil if none found.
    private func findEmptyDirSlot() -> Int? {
        for i in 0..<16 {
            let first = sectorBuf[i * 32]
            if first == 0x00 || first == 0xE5 { return i }
        }
        return nil
    }

    /// Write a 32-byte directory entry at the given slot in sectorBuf.
    private func writeDirSlot(
        slot: Int,
        name: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        ext: (UInt8, UInt8, UInt8),
        attr: UInt8,
        startCluster: UInt32,
        fileSize: UInt32
    ) {
        let base = slot * 32

        // Clear the entire 32-byte entry first
        for i in 0..<32 { sectorBuf[base + i] = 0 }

        // Name (8 bytes) and extension (3 bytes)
        sectorBuf[base]     = name.0
        sectorBuf[base + 1] = name.1
        sectorBuf[base + 2] = name.2
        sectorBuf[base + 3] = name.3
        sectorBuf[base + 4] = name.4
        sectorBuf[base + 5] = name.5
        sectorBuf[base + 6] = name.6
        sectorBuf[base + 7] = name.7
        sectorBuf[base + 8] = ext.0
        sectorBuf[base + 9] = ext.1
        sectorBuf[base + 10] = ext.2

        // Attributes
        sectorBuf[base + 11] = attr

        // Cluster high word (FAT32 only, bytes 20-21)
        writeU16(sectorBuf, offset: base + 20, value: UInt16(truncatingIfNeeded: startCluster >> 16))

        // Cluster low word (bytes 26-27)
        writeU16(sectorBuf, offset: base + 26, value: UInt16(truncatingIfNeeded: startCluster))

        // File size (bytes 28-31)
        writeU32(sectorBuf, offset: base + 28, value: fileSize)
    }

    // MARK: - Writing: File API

    /// Write a file to the filesystem.
    ///
    /// - Parameters:
    ///   - dirCluster: Parent directory cluster. Use 0 for root directory.
    ///   - name: 8-byte filename in 8.3 format, space-padded.
    ///   - ext: 3-byte extension in 8.3 format, space-padded.
    ///   - data: Pointer to file data.
    ///   - size: Number of bytes to write.
    /// - Returns: true on success.
    mutating func writeFile(
        dirCluster: UInt32,
        name: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        ext: (UInt8, UInt8, UInt8),
        data: UnsafePointer<UInt8>,
        size: Int
    ) -> Bool {
        // Empty file: no clusters needed
        if size == 0 {
            return createDirEntry(
                dirCluster: dirCluster, name: name, ext: ext, attr: 0x20,
                startCluster: 0, fileSize: 0)
        }

        let bytesPerCluster = Int(sectorsPerCluster) * 512
        let clustersNeeded = (size + bytesPerCluster - 1) / bytesPerCluster

        // Allocate clusters and chain them
        var firstCluster: UInt32 = 0
        var prevCluster: UInt32 = 0

        for i in 0..<clustersNeeded {
            let c = allocateCluster()
            if c == 0 {
                // Disk full — free already allocated clusters
                freeChain(startCluster: firstCluster)
                return false
            }
            if i == 0 {
                firstCluster = c
            }
            if prevCluster != 0 {
                if !writeFATEntry(cluster: prevCluster, value: c) {
                    freeChain(startCluster: firstCluster)
                    return false
                }
            }
            prevCluster = c
        }

        // Write file data
        var cluster = firstCluster
        var written = 0

        while written < size && cluster >= 2 {
            let sectorBase = clusterToSector(cluster)
            for s: UInt32 in 0..<sectorsPerCluster {
                if written >= size { break }
                let toWrite = min(512, size - written)
                for i in 0..<toWrite {
                    sectorBuf[i] = data[written + i]
                }
                // Zero-pad the last partial sector
                for i in toWrite..<512 {
                    sectorBuf[i] = 0
                }
                guard sd.writeSector(sector: sectorBase + s, from: UnsafePointer(sectorBuf)) else {
                    return false
                }
                written += toWrite
            }
            cluster = nextCluster(cluster)
        }

        // Create directory entry
        return createDirEntry(
            dirCluster: dirCluster, name: name, ext: ext, attr: 0x20,
            startCluster: firstCluster, fileSize: UInt32(size))
    }

    /// Delete a file by marking its directory entry as deleted and freeing its cluster chain.
    ///
    /// - Parameters:
    ///   - dirCluster: Parent directory cluster. Use 0 for root directory.
    ///   - fileCluster: The start cluster of the file to delete.
    /// - Returns: true on success.
    mutating func deleteFile(dirCluster: UInt32, fileCluster: UInt32) -> Bool {
        if dirCluster == 0 && !isFAT32 {
            return deleteInFAT16Root(fileCluster: fileCluster)
        }
        let cluster = (dirCluster == 0) ? rootDirCluster : dirCluster
        return deleteInClusterChain(dirStartCluster: cluster, fileCluster: fileCluster)
    }

    private mutating func deleteInFAT16Root(fileCluster: UInt32) -> Bool {
        for s: UInt32 in 0..<rootDirSectors {
            let sector = rootDirStartSector + s
            guard sd.readSector(sector: sector, into: sectorBuf) else { return false }
            if let found = findEntryByCluster(fileCluster) {
                sectorBuf[found * 32] = 0xE5
                guard sd.writeSector(sector: sector, from: UnsafePointer(sectorBuf)) else { return false }
                freeChain(startCluster: fileCluster)
                return true
            }
        }
        return false
    }

    private mutating func deleteInClusterChain(dirStartCluster: UInt32, fileCluster: UInt32) -> Bool {
        var cluster = dirStartCluster
        while cluster >= 2 {
            let sectorBase = clusterToSector(cluster)
            for s: UInt32 in 0..<sectorsPerCluster {
                let sector = sectorBase + s
                guard sd.readSector(sector: sector, into: sectorBuf) else { return false }
                if let found = findEntryByCluster(fileCluster) {
                    sectorBuf[found * 32] = 0xE5
                    guard sd.writeSector(sector: sector, from: UnsafePointer(sectorBuf)) else { return false }
                    freeChain(startCluster: fileCluster)
                    return true
                }
            }
            cluster = nextCluster(cluster)
        }
        return false
    }

    /// Find a non-LFN directory entry in sectorBuf whose start cluster matches.
    /// Returns slot index (0–15), or nil.
    private func findEntryByCluster(_ target: UInt32) -> Int? {
        for i in 0..<16 {
            let base = i * 32
            let first = sectorBuf[base]
            if first == 0x00 { return nil }
            if first == 0xE5 { continue }
            let attr = sectorBuf[base + 11]
            if attr == 0x0F { continue }
            let clHi = UInt32(readU16(sectorBuf, offset: base + 20))
            let clLo = UInt32(readU16(sectorBuf, offset: base + 26))
            if (clHi << 16) | clLo == target { return i }
        }
        return nil
    }

    /// Copy a file with an 8.3 short name.
    mutating func copyFile(
        srcCluster: UInt32,
        srcSize: UInt32,
        dirCluster: UInt32,
        name: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        ext: (UInt8, UInt8, UInt8)
    ) -> Bool {
        if srcSize == 0 {
            return createDirEntry(
                dirCluster: dirCluster, name: name, ext: ext, attr: 0x20,
                startCluster: 0, fileSize: 0)
        }
        let firstCluster = copyFileData(srcCluster: srcCluster, srcSize: srcSize)
        if firstCluster == 0 { return false }
        return createDirEntry(
            dirCluster: dirCluster, name: name, ext: ext, attr: 0x20,
            startCluster: firstCluster, fileSize: srcSize)
    }

    /// Copy a file with a Long File Name (UTF-8).
    mutating func copyFileWithLFN(
        srcCluster: UInt32,
        srcSize: UInt32,
        dirCluster: UInt32,
        lfn: UnsafePointer<UInt8>,
        lfnLen: Int
    ) -> Bool {
        if srcSize == 0 {
            return createDirEntryWithLFN(
                dirCluster: dirCluster, lfn: lfn, lfnLen: lfnLen,
                attr: 0x20, startCluster: 0, fileSize: 0)
        }
        let firstCluster = copyFileData(srcCluster: srcCluster, srcSize: srcSize)
        if firstCluster == 0 { return false }
        return createDirEntryWithLFN(
            dirCluster: dirCluster, lfn: lfn, lfnLen: lfnLen,
            attr: 0x20, startCluster: firstCluster, fileSize: srcSize)
    }

    // MARK: - Writing: LFN Support

    /// Create a directory entry with a Long File Name.
    ///
    /// Generates LFN entries (UTF-16LE, 13 chars each) followed by an
    /// auto-generated 8.3 SFN entry. Finds consecutive free slots in the
    /// directory to hold all entries.
    mutating func createDirEntryWithLFN(
        dirCluster: UInt32,
        lfn: UnsafePointer<UInt8>,
        lfnLen: Int,
        attr: UInt8,
        startCluster: UInt32,
        fileSize: UInt32
    ) -> Bool {
        // Convert UTF-8 to UTF-16LE
        let utf16Buf: UnsafeMutablePointer<UInt16> = .allocate(capacity: 256)
        let utf16Len = utf8ToUtf16(src: lfn, srcLen: lfnLen, dst: utf16Buf, maxDst: 255)
        guard utf16Len > 0 else {
            utf16Buf.deallocate()
            return false
        }

        // Generate 8.3 SFN from LFN
        let sfn: UnsafeMutablePointer<UInt8> = .allocate(capacity: 11)
        generateSFN(lfn: lfn, lfnLen: lfnLen, sfn: sfn)

        // Compute checksum of the SFN
        let checksum = sfnChecksum(sfn: sfn)

        // Build all entries: LFN entries (reverse order) + 1 SFN entry
        let lfnEntryCount = (utf16Len + 12) / 13
        let totalEntries = lfnEntryCount + 1
        let entryBuf: UnsafeMutablePointer<UInt8> = .allocate(capacity: totalEntries * 32)

        // Build LFN entries (highest sequence number first)
        for i in 0..<lfnEntryCount {
            let seqNum = lfnEntryCount - i
            buildLFNDirEntry(
                buf: entryBuf.advanced(by: i * 32),
                seqNum: seqNum, isLast: i == 0,
                checksum: checksum,
                utf16: utf16Buf, utf16Len: utf16Len)
        }

        // Build SFN entry
        let sfnBase = lfnEntryCount * 32
        for j in 0..<32 { entryBuf[sfnBase + j] = 0 }
        for j in 0..<11 { entryBuf[sfnBase + j] = sfn[j] }
        entryBuf[sfnBase + 11] = attr
        writeU16(entryBuf, offset: sfnBase + 20,
                 value: UInt16(truncatingIfNeeded: startCluster >> 16))
        writeU16(entryBuf, offset: sfnBase + 26,
                 value: UInt16(truncatingIfNeeded: startCluster))
        writeU32(entryBuf, offset: sfnBase + 28, value: fileSize)

        let ok = writeConsecutiveDirEntries(
            dirCluster: dirCluster,
            entryData: entryBuf,
            totalEntries: totalEntries)

        entryBuf.deallocate()
        utf16Buf.deallocate()
        sfn.deallocate()
        return ok
    }

    /// Find a run of consecutive free directory slots and write entries there.
    private mutating func writeConsecutiveDirEntries(
        dirCluster: UInt32,
        entryData: UnsafePointer<UInt8>,
        totalEntries: Int
    ) -> Bool {
        var freeRunStart = 0
        var freeRunLen = 0
        var hitEnd = false

        if dirCluster == 0 && !isFAT32 {
            // FAT16 root: scan fixed sectors
            var idx = 0
            var foundAt = -1
            for s: UInt32 in 0..<rootDirSectors {
                guard sd.readSector(sector: rootDirStartSector + s, into: sectorBuf)
                else { return false }
                for slot in 0..<16 {
                    let first = sectorBuf[slot * 32]
                    if first == 0x00 || first == 0xE5 {
                        if freeRunLen == 0 { freeRunStart = idx }
                        freeRunLen += 1
                        if first == 0x00 { hitEnd = true }
                        if freeRunLen >= totalEntries || hitEnd {
                            foundAt = freeRunStart
                            break
                        }
                    } else {
                        freeRunLen = 0
                    }
                    idx += 1
                }
                if foundAt >= 0 { break }
            }
            guard foundAt >= 0 else { return false }
            return writeDirEntriesSequential(
                isFAT16Root: true, dirCluster: 0,
                startIndex: foundAt, entryData: entryData,
                totalEntries: totalEntries, setEndMarker: hitEnd)
        }

        // FAT32 or subdirectory
        let startCluster = (dirCluster == 0) ? rootDirCluster : dirCluster
        var cluster = startCluster
        var idx = 0
        var foundAt = -1

        while cluster >= 2 {
            let sectorBase = clusterToSector(cluster)
            for s: UInt32 in 0..<sectorsPerCluster {
                guard sd.readSector(sector: sectorBase + s, into: sectorBuf)
                else { return false }
                for slot in 0..<16 {
                    let first = sectorBuf[slot * 32]
                    if first == 0x00 || first == 0xE5 {
                        if freeRunLen == 0 { freeRunStart = idx }
                        freeRunLen += 1
                        if first == 0x00 { hitEnd = true }
                        if freeRunLen >= totalEntries || hitEnd {
                            foundAt = freeRunStart
                            break
                        }
                    } else {
                        freeRunLen = 0
                    }
                    idx += 1
                }
                if foundAt >= 0 { break }
            }
            if foundAt >= 0 { break }
            cluster = nextCluster(cluster)
        }

        if foundAt < 0 { return false }

        return writeDirEntriesSequential(
            isFAT16Root: false, dirCluster: dirCluster,
            startIndex: foundAt, entryData: entryData,
            totalEntries: totalEntries, setEndMarker: hitEnd)
    }

    /// Write directory entries sequentially starting at `startIndex`.
    /// Handles sector and cluster boundaries, extending the directory if needed.
    private mutating func writeDirEntriesSequential(
        isFAT16Root: Bool,
        dirCluster: UInt32,
        startIndex: Int,
        entryData: UnsafePointer<UInt8>,
        totalEntries: Int,
        setEndMarker: Bool
    ) -> Bool {
        let totalToWrite = totalEntries + (setEndMarker ? 1 : 0)

        // Navigate to the starting sector
        var currentSector: UInt32 = 0
        var currentSlot = startIndex % 16
        var cluster: UInt32 = 0

        if isFAT16Root {
            currentSector = rootDirStartSector + UInt32(startIndex / 16)
        } else {
            let start = (dirCluster == 0) ? rootDirCluster : dirCluster
            let entriesPerCluster = Int(sectorsPerCluster) * 16
            let targetClusterIdx = startIndex / entriesPerCluster
            let inClusterEntry = startIndex % entriesPerCluster

            cluster = start
            for _ in 0..<targetClusterIdx {
                cluster = nextCluster(cluster)
                if cluster < 2 { return false }
            }
            currentSector = clusterToSector(cluster) + UInt32(inClusterEntry / 16)
        }

        guard sd.readSector(sector: currentSector, into: sectorBuf) else { return false }

        for i in 0..<totalToWrite {
            if currentSlot >= 16 {
                // Flush current sector and advance
                guard sd.writeSector(sector: currentSector, from: UnsafePointer(sectorBuf))
                else { return false }
                currentSlot = 0
                currentSector += 1

                // Handle cluster boundary for non-FAT16-root
                if !isFAT16Root {
                    let sectorBase = clusterToSector(cluster)
                    if currentSector >= sectorBase + sectorsPerCluster {
                        let nextC = nextCluster(cluster)
                        if nextC < 2 {
                            // Extend directory with a new cluster
                            let newC = allocateCluster()
                            if newC == 0 { return false }
                            if !writeFATEntry(cluster: cluster, value: newC) { return false }
                            for b in 0..<512 { sectorBuf[b] = 0 }
                            let newBase = clusterToSector(newC)
                            for s: UInt32 in 0..<sectorsPerCluster {
                                guard sd.writeSector(sector: newBase + s,
                                                     from: UnsafePointer(sectorBuf))
                                else { return false }
                            }
                            cluster = newC
                        } else {
                            cluster = nextC
                        }
                        currentSector = clusterToSector(cluster)
                    }
                }

                guard sd.readSector(sector: currentSector, into: sectorBuf) else { return false }
            }

            if i < totalEntries {
                let dataOff = i * 32
                for b in 0..<32 { sectorBuf[currentSlot * 32 + b] = entryData[dataOff + b] }
            } else {
                // End-of-directory marker
                sectorBuf[currentSlot * 32] = 0x00
            }
            currentSlot += 1
        }

        // Flush the last sector
        return sd.writeSector(sector: currentSector, from: UnsafePointer(sectorBuf))
    }

    // MARK: - Private: LFN Helpers

    /// Convert UTF-8 to UTF-16LE. Returns the number of UTF-16 code units written.
    private func utf8ToUtf16(
        src: UnsafePointer<UInt8>, srcLen: Int,
        dst: UnsafeMutablePointer<UInt16>, maxDst: Int
    ) -> Int {
        var si = 0
        var di = 0
        while si < srcLen && di < maxDst {
            let b0 = src[si]
            if b0 < 0x80 {
                dst[di] = UInt16(b0)
                si += 1; di += 1
            } else if b0 < 0xE0 {
                guard si + 1 < srcLen else { break }
                dst[di] = (UInt16(b0 & 0x1F) << 6) | UInt16(src[si + 1] & 0x3F)
                si += 2; di += 1
            } else if b0 < 0xF0 {
                guard si + 2 < srcLen else { break }
                dst[di] = (UInt16(b0 & 0x0F) << 12)
                    | (UInt16(src[si + 1] & 0x3F) << 6)
                    | UInt16(src[si + 2] & 0x3F)
                si += 3; di += 1
            } else {
                guard si + 3 < srcLen, di + 1 < maxDst else { break }
                let cp = (UInt32(b0 & 0x07) << 18)
                    | (UInt32(src[si + 1] & 0x3F) << 12)
                    | (UInt32(src[si + 2] & 0x3F) << 6)
                    | UInt32(src[si + 3] & 0x3F)
                let u = cp &- 0x10000
                dst[di] = UInt16(0xD800 + (u >> 10))
                dst[di + 1] = UInt16(0xDC00 + (u & 0x3FF))
                si += 4; di += 2
            }
        }
        return di
    }

    /// Generate an 8.3 SFN from a long filename. Output is 11 bytes (8 name + 3 ext).
    private func generateSFN(
        lfn: UnsafePointer<UInt8>, lfnLen: Int,
        sfn: UnsafeMutablePointer<UInt8>
    ) {
        for i in 0..<11 { sfn[i] = 0x20 }

        // Find the last dot for extension
        var lastDot = -1
        var i = lfnLen - 1
        while i >= 0 {
            if lfn[i] == 0x2E { lastDot = i; break }
            i -= 1
        }

        // Extract extension (up to 3 uppercase ASCII chars)
        if lastDot >= 0 && lastDot < lfnLen - 1 {
            var ei = 0
            for j in (lastDot + 1)..<lfnLen {
                if ei >= 3 { break }
                let c = lfn[j]
                if c >= 0x61 && c <= 0x7A {
                    sfn[8 + ei] = c &- 32
                    ei += 1
                } else if (c >= 0x41 && c <= 0x5A) || (c >= 0x30 && c <= 0x39) {
                    sfn[8 + ei] = c
                    ei += 1
                } else if c < 0x80 {
                    sfn[8 + ei] = 0x5F
                    ei += 1
                }
            }
        }

        // Extract name: first 6 valid chars + "~1"
        let nameEnd = lastDot >= 0 ? lastDot : lfnLen
        var ni = 0
        for j in 0..<nameEnd {
            if ni >= 6 { break }
            let c = lfn[j]
            if c >= 0x61 && c <= 0x7A {
                sfn[ni] = c &- 32; ni += 1
            } else if (c >= 0x41 && c <= 0x5A) || (c >= 0x30 && c <= 0x39) {
                sfn[ni] = c; ni += 1
            } else if c < 0x80 && c != 0x20 && c != 0x2E {
                sfn[ni] = 0x5F; ni += 1
            }
        }
        if ni == 0 {
            sfn[0] = 0x46; sfn[1] = 0x49; sfn[2] = 0x4C; sfn[3] = 0x45  // "FILE"
            ni = 4
        }
        sfn[ni] = 0x7E      // '~'
        sfn[ni + 1] = 0x31  // '1'
    }

    /// Compute the LFN checksum for an 11-byte SFN.
    private func sfnChecksum(sfn: UnsafePointer<UInt8>) -> UInt8 {
        var sum: UInt8 = 0
        for i in 0..<11 {
            sum = ((sum >> 1) | (sum << 7)) &+ sfn[i]
        }
        return sum
    }

    /// Build a single 32-byte LFN directory entry.
    private func buildLFNDirEntry(
        buf: UnsafeMutablePointer<UInt8>,
        seqNum: Int,
        isLast: Bool,
        checksum: UInt8,
        utf16: UnsafePointer<UInt16>,
        utf16Len: Int
    ) {
        for i in 0..<32 { buf[i] = 0 }

        buf[0] = UInt8(seqNum) | (isLast ? 0x40 : 0)
        buf[11] = 0x0F   // LFN attribute
        buf[13] = checksum

        let charBase = (seqNum - 1) * 13

        // Characters 1–5: bytes 1–10
        for j in 0..<5 {
            let idx = charBase + j
            let ch: UInt16 = idx < utf16Len ? utf16[idx] : (idx == utf16Len ? 0x0000 : 0xFFFF)
            buf[1 + j * 2] = UInt8(truncatingIfNeeded: ch)
            buf[2 + j * 2] = UInt8(truncatingIfNeeded: ch >> 8)
        }
        // Characters 6–11: bytes 14–25
        for j in 0..<6 {
            let idx = charBase + 5 + j
            let ch: UInt16 = idx < utf16Len ? utf16[idx] : (idx == utf16Len ? 0x0000 : 0xFFFF)
            buf[14 + j * 2] = UInt8(truncatingIfNeeded: ch)
            buf[15 + j * 2] = UInt8(truncatingIfNeeded: ch >> 8)
        }
        // Characters 12–13: bytes 28–31
        for j in 0..<2 {
            let idx = charBase + 11 + j
            let ch: UInt16 = idx < utf16Len ? utf16[idx] : (idx == utf16Len ? 0x0000 : 0xFFFF)
            buf[28 + j * 2] = UInt8(truncatingIfNeeded: ch)
            buf[29 + j * 2] = UInt8(truncatingIfNeeded: ch >> 8)
        }
    }

    // MARK: - Private: File Copy Data

    /// Allocate destination clusters and copy file data from source.
    /// Returns the first destination cluster, or 0 on failure.
    /// Allocate destination clusters and stream-copy file data one cluster at a time.
    /// Uses only 512 bytes of extra memory regardless of file size.
    private mutating func copyFileData(srcCluster: UInt32, srcSize: UInt32) -> UInt32 {
        let size = Int(srcSize)
        let copyBuf: UnsafeMutablePointer<UInt8> = .allocate(capacity: 512)

        var src = srcCluster
        var firstDst: UInt32 = 0
        var prevDst: UInt32 = 0
        var remaining = size
        while src >= 2 && remaining > 0 {
            // Allocate a destination cluster (uses sectorBuf internally)
            let dst = allocateCluster()
            if dst == 0 {
                if firstDst != 0 { freeChain(startCluster: firstDst) }
                copyBuf.deallocate()
                return 0
            }
            if firstDst == 0 { firstDst = dst }
            if prevDst != 0 {
                if !writeFATEntry(cluster: prevDst, value: dst) {
                    freeChain(startCluster: firstDst)
                    copyBuf.deallocate()
                    return 0
                }
            }

            // Copy sectors using copyBuf (separate from sectorBuf)
            let srcBase = clusterToSector(src)
            let dstBase = clusterToSector(dst)
            for s: UInt32 in 0..<sectorsPerCluster {
                if remaining <= 0 { break }
                guard sd.readSector(sector: srcBase + s, into: copyBuf) else {
                    freeChain(startCluster: firstDst)
                    copyBuf.deallocate()
                    return 0
                }
                let inSector = min(512, remaining)
                for j in inSector..<512 { copyBuf[j] = 0 }
                guard sd.writeSector(sector: dstBase + s, from: UnsafePointer(copyBuf)) else {
                    freeChain(startCluster: firstDst)
                    copyBuf.deallocate()
                    return 0
                }
                remaining -= inSector
            }

            prevDst = dst
            src = nextCluster(src)  // uses sectorBuf — safe, copyBuf is separate
        }

        copyBuf.deallocate()
        return firstDst
    }

    /// Free a chain of clusters starting from the given cluster.
    private mutating func freeChain(startCluster: UInt32) {
        var cluster = startCluster
        while cluster >= 2 {
            let next = nextCluster(cluster)
            _ = writeFATEntry(cluster: cluster, value: 0)
            cluster = next
        }
    }
}
