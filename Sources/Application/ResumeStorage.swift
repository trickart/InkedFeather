/// Persistent resume state for deep sleep wake.
///
/// Stores a snapshot of the active screen and viewer state to a small
/// fixed-size file (`RESUME.DAT`) in the SD card root. The next boot
/// reads this file (after detecting the wake marker in RTC store0) and
/// restores the screen the user was on before pressing power.
///
/// File layout (100 bytes, little-endian):
/// ```
/// offset  size  field
///   0      4   magic           ("IFRS" = 0x49465253)
///   4      1   version         (= 1)
///   5      1   screen          (0 = fileBrowser, 1 = textViewer, 2 = imageViewer)
///   6      1   dirDepth        (0..16)
///   7      1   reserved
///   8     64   dirStack[16]    UInt32 cluster numbers
///  72      4   selectedIndex   Int32  (FileListView cursor)
///  76      4   scrollOffset    Int32  (FileListView scroll)
///  80      4   parentDirClust  UInt32 (parent dir for text/image viewer)
///  84      4   fileCluster     UInt32 (open file's start cluster)
///  88      4   fileSize        UInt32 (open file's size, integrity check)
///  92      4   textScrollLine  Int32  (TextViewer.scrollLine)
///  96      4   checksum        UInt32 (sum of bytes 0..95)
/// ```
///
/// The dirStack is passed via external pointers (UnsafePointer / UnsafeMutablePointer)
/// to avoid bulky tuple types in the public API — Application.swift already
/// manages dirStack as a heap buffer.
struct ResumeState {
    var screen: UInt8 = 0
    var dirDepth: UInt8 = 0
    var selectedIndex: Int32 = 0
    var scrollOffset: Int32 = 0
    var parentDirCluster: UInt32 = 0
    var fileCluster: UInt32 = 0
    var fileSize: UInt32 = 0
    var textScrollLine: Int32 = 0
}

enum ResumeStorage {
    static let magic: UInt32 = 0x4946_5253  // "IFRS" (little-endian)
    static let version: UInt8 = 1
    static let totalSize: Int = 100
    static let maxDirDepth: Int = 16

    /// SFN: "RESUME  " / "DAT"
    private static let nameTuple: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
        (0x52, 0x45, 0x53, 0x55, 0x4D, 0x45, 0x20, 0x20)
    private static let extTuple: (UInt8, UInt8, UInt8) =
        (0x44, 0x41, 0x54)

    /// Maximum cluster map entries for the resume file (1 cluster is enough at 100 B).
    private static let maxClusters: Int = 4

    /// Save resume state to RESUME.DAT in the SD card root.
    ///
    /// Returns true on success. On failure, the caller should NOT set the
    /// wake marker so the next boot falls back to a normal cold start.
    static func save(fat: inout FATFileSystem,
                     state: ResumeState,
                     dirStack: UnsafePointer<UInt32>) -> Bool {
        let buf: UnsafeMutablePointer<UInt8> = .allocate(capacity: totalSize)
        defer { buf.deallocate() }

        // Zero
        for i in 0..<totalSize { buf[i] = 0 }

        // Header
        writeLE32(buf, at: 0, value: magic)
        buf[4] = version
        buf[5] = state.screen
        buf[6] = state.dirDepth
        buf[7] = 0

        // dirStack (always write 16 slots, using 0 for unused)
        let depth = min(Int(state.dirDepth), maxDirDepth)
        for i in 0..<depth {
            writeLE32(buf, at: 8 + i * 4, value: dirStack[i])
        }

        // Tail fields
        writeLE32(buf, at: 72, value: UInt32(bitPattern: state.selectedIndex))
        writeLE32(buf, at: 76, value: UInt32(bitPattern: state.scrollOffset))
        writeLE32(buf, at: 80, value: state.parentDirCluster)
        writeLE32(buf, at: 84, value: state.fileCluster)
        writeLE32(buf, at: 88, value: state.fileSize)
        writeLE32(buf, at: 92, value: UInt32(bitPattern: state.textScrollLine))

        // Checksum (sum of bytes 0..95 as UInt32)
        var sum: UInt32 = 0
        for i in 0..<96 {
            sum = sum &+ UInt32(buf[i])
        }
        writeLE32(buf, at: 96, value: sum)

        // Delete existing then write fresh
        var existingCluster: UInt32 = 0
        var existingSize: UInt32 = 0
        if fat.findFile(name: nameTuple, ext: extTuple,
                        cluster: &existingCluster, fileSize: &existingSize) {
            _ = fat.deleteFile(dirCluster: 0, fileCluster: existingCluster)
        }

        return fat.writeFile(
            dirCluster: 0,
            name: nameTuple,
            ext: extTuple,
            data: UnsafePointer(buf),
            size: totalSize)
    }

    /// Load resume state from RESUME.DAT.
    ///
    /// Returns nil if the file is missing, malformed, or fails the checksum.
    /// On success, fills `dirStack[0..state.dirDepth]` and returns the state.
    static func load(fat: inout FATFileSystem,
                     dirStack: UnsafeMutablePointer<UInt32>) -> ResumeState? {
        var fileCluster: UInt32 = 0
        var fileSize: UInt32 = 0
        guard fat.findFile(name: nameTuple, ext: extTuple,
                           cluster: &fileCluster, fileSize: &fileSize)
        else { return nil }
        guard fileSize >= UInt32(totalSize) else { return nil }

        let buf: UnsafeMutablePointer<UInt8> = .allocate(capacity: totalSize)
        defer { buf.deallocate() }

        let clusterMap: UnsafeMutablePointer<UInt32> = .allocate(capacity: maxClusters)
        defer { clusterMap.deallocate() }

        let clusterCount = fat.buildClusterMap(startCluster: fileCluster,
                                               into: clusterMap,
                                               maxClusters: maxClusters)
        let bytesRead = fat.readBytes(clusterMap: clusterMap,
                                      clusterCount: clusterCount,
                                      fileOffset: 0,
                                      into: buf,
                                      count: totalSize)
        guard bytesRead == totalSize else { return nil }

        // Validate
        guard readLE32(buf, at: 0) == magic else { return nil }
        guard buf[4] == version else { return nil }

        var sum: UInt32 = 0
        for i in 0..<96 {
            sum = sum &+ UInt32(buf[i])
        }
        guard readLE32(buf, at: 96) == sum else { return nil }

        var state = ResumeState()
        state.screen = buf[5]
        state.dirDepth = buf[6]

        // Bounds check
        guard Int(state.dirDepth) <= maxDirDepth else { return nil }
        guard state.screen <= 2 else { return nil }

        // Extract dirStack
        for i in 0..<Int(state.dirDepth) {
            dirStack[i] = readLE32(buf, at: 8 + i * 4)
        }
        // Zero unused slots in caller's buffer (defensive)
        for i in Int(state.dirDepth)..<maxDirDepth {
            dirStack[i] = 0
        }

        state.selectedIndex = Int32(bitPattern: readLE32(buf, at: 72))
        state.scrollOffset = Int32(bitPattern: readLE32(buf, at: 76))
        state.parentDirCluster = readLE32(buf, at: 80)
        state.fileCluster = readLE32(buf, at: 84)
        state.fileSize = readLE32(buf, at: 88)
        state.textScrollLine = Int32(bitPattern: readLE32(buf, at: 92))

        return state
    }

    // MARK: - Little-Endian Byte Helpers

    private static func readLE32(_ buf: UnsafeMutablePointer<UInt8>, at offset: Int) -> UInt32 {
        UInt32(buf[offset]) |
        (UInt32(buf[offset + 1]) << 8) |
        (UInt32(buf[offset + 2]) << 16) |
        (UInt32(buf[offset + 3]) << 24)
    }

    private static func writeLE32(_ buf: UnsafeMutablePointer<UInt8>, at offset: Int, value: UInt32) {
        buf[offset] = UInt8(truncatingIfNeeded: value)
        buf[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
        buf[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
        buf[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
    }
}
