/// Manages an Xteinl X4 format bitmap font loaded from SD card.
///
/// The font file is a headerless array of 65,536 glyph bitmaps (Unicode BMP),
/// where glyph for code point N starts at offset `N * bytesPerGlyph`.
/// Glyph dimensions are derived from the file size.
///
/// Glyphs are loaded on demand via FATFileSystem random access and cached
/// using an LRU strategy to minimize SD card reads.
///
/// Memory is allocated lazily on `load()` to avoid consuming heap
/// when no font file is present.
struct BitmapFont {
    // MARK: - Font Geometry

    /// Pixel width of each glyph.
    private(set) var glyphWidth: Int = 0
    /// Pixel height of each glyph.
    private(set) var glyphHeight: Int = 0
    /// Bytes per row (ceil(glyphWidth / 8)).
    private(set) var bytesPerRow: Int = 0
    /// Bytes per glyph (bytesPerRow * glyphHeight).
    private(set) var bytesPerGlyph: Int = 0
    /// Whether a valid font is loaded and ready.
    private(set) var loaded: Bool = false

    // MARK: - SD Card Access

    /// Pre-built cluster map for O(1) random access into the font file.
    private var clusterMap: UnsafeMutablePointer<UInt32>? = nil
    private var clusterCount: Int = 0
    static let maxClusters = 4096

    // MARK: - Glyph Cache (LRU)

    /// Number of cached glyph slots.
    static let cacheSlots = 128
    /// Contiguous glyph bitmap storage: slot i at offset i * bytesPerGlyph.
    private var cacheData: UnsafeMutablePointer<UInt8>? = nil
    /// Code point stored in each cache slot (0xFFFF_FFFF = empty).
    private var cacheCodePoints: UnsafeMutablePointer<UInt32>? = nil
    /// LRU generation counter for each slot.
    private var cacheAge: UnsafeMutablePointer<UInt32>? = nil
    /// Global generation counter, incremented on each access.
    private var generation: UInt32 = 0

    // MARK: - Initialization

    init() {
        // No allocation here — memory is allocated lazily in load().
    }

    // MARK: - Loading

    /// Load a font file from SD card. Builds the cluster map, detects
    /// glyph dimensions, and allocates the glyph cache.
    /// - Returns: `true` if the font was loaded successfully.
    mutating func load(fat: inout FATFileSystem, cluster: UInt32,
                       fileSize: UInt32) -> Bool {
        // File must contain exactly 65536 glyphs
        guard fileSize >= 65536, fileSize % 65536 == 0 else { return false }

        let bpg = Int(fileSize) / 65536
        guard bpg > 0, bpg <= 1024 else { return false }

        // Detect dimensions from bytes-per-glyph
        guard detectDimensions(bpg: bpg) else { return false }

        // Allocate cluster map
        if clusterMap == nil {
            clusterMap = .allocate(capacity: Self.maxClusters)
        }

        // Build cluster map for random access
        clusterCount = fat.buildClusterMap(startCluster: cluster,
                                           into: clusterMap!,
                                           maxClusters: Self.maxClusters)
        guard clusterCount > 0 else { return false }

        // Allocate glyph cache sized to actual bytesPerGlyph
        cacheData = .allocate(capacity: Self.cacheSlots * bytesPerGlyph)
        cacheCodePoints = .allocate(capacity: Self.cacheSlots)
        cacheAge = .allocate(capacity: Self.cacheSlots)

        // Mark all slots empty
        for i in 0..<Self.cacheSlots {
            cacheCodePoints![i] = 0xFFFF_FFFF
            cacheAge![i] = 0
        }
        generation = 0

        loaded = true
        return true
    }

    // MARK: - Glyph Size Detection

    /// Derive glyph width and height from bytes-per-glyph.
    ///
    /// Tries row byte counts 1–8, checks that:
    /// - bytesPerGlyph divides evenly by rowBytes
    /// - resulting width (rowBytes*8) and height are in 8–128
    /// - aspect ratio (w/h) is between 0.5 and 0.9
    private mutating func detectDimensions(bpg: Int) -> Bool {
        for rowBytes in 1...8 {
            guard bpg % rowBytes == 0 else { continue }
            let h = bpg / rowBytes
            let w = rowBytes * 8
            guard w >= 8, w <= 64, h >= 8, h <= 128 else { continue }
            // Aspect ratio check: w*10/h should be 5–9 (i.e. 0.5–0.9)
            let ratio10 = w * 10 / h
            if ratio10 >= 5 && ratio10 <= 9 {
                glyphWidth = w
                glyphHeight = h
                bytesPerRow = rowBytes
                bytesPerGlyph = bpg
                return true
            }
        }
        return false
    }

    // MARK: - Glyph Access

    /// Get the bitmap data for a Unicode code point.
    /// Returns a pointer to the glyph bitmap (bytesPerGlyph bytes), or nil
    /// if the code point is out of range or the read fails.
    mutating func glyphData(codePoint: UInt32,
                            fat: inout FATFileSystem) -> UnsafePointer<UInt8>? {
        guard loaded, codePoint < 65536,
              let cacheData, let cacheCodePoints, let cacheAge,
              let clusterMap else { return nil }

        // Search cache
        for i in 0..<Self.cacheSlots {
            if cacheCodePoints[i] == codePoint {
                generation &+= 1
                cacheAge[i] = generation
                return UnsafePointer(cacheData.advanced(by: i * bytesPerGlyph))
            }
        }

        // Cache miss — find LRU slot
        var lruSlot = 0
        var lruAge: UInt32 = cacheAge[0]
        for i in 1..<Self.cacheSlots {
            if cacheAge[i] < lruAge {
                lruAge = cacheAge[i]
                lruSlot = i
            }
        }

        // Read glyph from SD card
        let fileOffset = Int(codePoint) * bytesPerGlyph
        let dest = cacheData.advanced(by: lruSlot * bytesPerGlyph)
        let bytesRead = fat.readBytes(clusterMap: clusterMap,
                                      clusterCount: clusterCount,
                                      fileOffset: fileOffset,
                                      into: dest,
                                      count: bytesPerGlyph)
        guard bytesRead == bytesPerGlyph else { return nil }

        // Update cache metadata
        generation &+= 1
        cacheCodePoints[lruSlot] = codePoint
        cacheAge[lruSlot] = generation

        return UnsafePointer(dest)
    }
}
