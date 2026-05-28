/// Baseline JPEG (SOF0) decoder with streaming MCU-row decode.
///
/// Decodes JPEG files directly from the FAT filesystem into the 1-bit framebuffer.
/// Supports grayscale and YCbCr color spaces with 4:4:4, 4:2:2, and 4:2:0
/// chroma subsampling. Progressive JPEG is not supported.
///
/// Memory usage: ~45KB (IO buffer + quant/Huffman tables + MCU row buffer + cluster map).
struct JPEGDecoder {
    // MARK: - Constants

    static let maxWidth = 800
    static let maxClusters = 1024
    static let ioBufferSize = 4096
    static let maxComponents = 3

    // MARK: - Parsed Header

    private(set) var imageWidth: Int = 0
    private(set) var imageHeight: Int = 0
    private(set) var componentCount: Int = 0
    private(set) var valid: Bool = false

    /// Component info: (id, quantTableIdx, dcTableIdx, acTableIdx, hSamp, vSamp)
    private var compId:       (UInt8, UInt8, UInt8) = (0, 0, 0)
    private var compQuantIdx: (UInt8, UInt8, UInt8) = (0, 0, 0)
    private var compDcIdx:    (UInt8, UInt8, UInt8) = (0, 0, 0)
    private var compAcIdx:    (UInt8, UInt8, UInt8) = (0, 0, 0)
    private var compHSamp:    (UInt8, UInt8, UInt8) = (1, 1, 1)
    private var compVSamp:    (UInt8, UInt8, UInt8) = (1, 1, 1)

    /// Maximum sampling factors (determines MCU size).
    private var maxHSamp: Int = 1
    private var maxVSamp: Int = 1

    /// MCU dimensions in pixels.
    private var mcuWidth: Int = 8
    private var mcuHeight: Int = 8

    /// MCU grid dimensions.
    private var mcuCountX: Int = 0
    private var mcuCountY: Int = 0

    /// Restart interval (0 = no restart markers).
    private var restartInterval: Int = 0

    /// File offset where entropy-coded data begins (after SOS header).
    private var sosDataOffset: Int = 0

    // MARK: - Quantization Tables

    /// 4 quantization tables, each 64 entries in natural (row-major) order.
    private let quantTables: UnsafeMutablePointer<UInt16>  // 4 * 64 * 2 = 512 bytes
    private var quantValid: UInt8 = 0  // bitmask of valid tables

    // MARK: - Huffman Tables

    /// Huffman lookup: primary table (8-bit, 256 entries).
    /// Each entry: bits 0–7 = symbol, bits 8–11 = code length (0 = invalid/needs slow path).
    /// DC tables: 2, AC tables: 2.
    private let huffDC: UnsafeMutablePointer<UInt16>   // 2 * 256 = 1024 bytes
    private let huffAC: UnsafeMutablePointer<UInt16>   // 2 * 256 = 1024 bytes

    /// Slow-path Huffman data for codes longer than 8 bits.
    /// Stores (minCode, maxCode, firstSymbolIdx) per code length 9..16.
    /// Plus the symbol arrays.
    private let huffSlowDC: UnsafeMutablePointer<UInt8>  // 2 tables * 176 bytes
    private let huffSlowAC: UnsafeMutablePointer<UInt8>  // 2 tables * 176 bytes
    private let huffSymsDC: UnsafeMutablePointer<UInt8>  // 2 * 16 symbols max
    private let huffSymsAC: UnsafeMutablePointer<UInt8>  // 2 * 256 symbols max

    static let huffSlowTableSize = 176  // 8 lengths * (2+2+2) padding to 22 bytes each = 176
    static let huffDCSymsSize = 32      // 2 tables * 16 symbols
    static let huffACSymsSize = 512     // 2 tables * 256 symbols

    // MARK: - Bitstream State

    private var bitBuffer: UInt32 = 0
    private var bitsAvailable: Int = 0
    /// Set when readNextByte encounters a marker (0xFF followed by non-0x00).
    /// Prevents further byte reads until the marker is consumed by alignToNextRestart.
    private var hitMarker: Bool = false

    // MARK: - IO Buffer

    private let ioBuffer: UnsafeMutablePointer<UInt8>
    private var ioPos: Int = 0
    private var ioEnd: Int = 0
    private var filePos: Int = 0  // current file read position

    // MARK: - Cluster Map

    private let clusterMap: UnsafeMutablePointer<UInt32>
    private var clusterCount: Int = 0
    private var fileSize: Int = 0

    // MARK: - DC Predictors

    private var dcPred: (Int32, Int32, Int32) = (0, 0, 0)

    // MARK: - Block Buffer

    /// 64 coefficients for current block decode (Int32 to avoid overflow during dequantize/IDCT).
    private let blockBuf: UnsafeMutablePointer<Int32>  // 64 * 4 = 256 bytes

    // MARK: - MCU Row Buffer

    /// Decoded pixel data for one MCU row.
    private let mcuRowBuf: UnsafeMutablePointer<UInt8>
    static let mcuRowBufSize = maxWidth * 16  // max MCU height = 16 for 4:2:0

    /// Cb and Cr buffers for color images.
    /// Sized to cover 4:4:4 (full-res chroma): maxWidth * 8 = 6400.
    private let cbBuf: UnsafeMutablePointer<UInt8>
    private let crBuf: UnsafeMutablePointer<UInt8>
    static let chromaBufSize = maxWidth * 8  // covers 4:4:4 (800*8) and 4:2:0 (400*8)

    /// Chroma buffer stride (columns per row in chroma buffer).
    private var chromaStride: Int = 0

    // MARK: - Zigzag Table

    /// Zigzag order to natural order mapping.
    private static let zigzag: (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    ) = (
         0,  1,  8, 16,  9,  2,  3, 10,
        17, 24, 32, 25, 18, 11,  4,  5,
        12, 19, 26, 33, 40, 48, 41, 34,
        27, 20, 13,  6,  7, 14, 21, 28,
        35, 42, 49, 56, 57, 50, 43, 36,
        29, 22, 15, 23, 30, 37, 44, 51,
        58, 59, 52, 45, 38, 31, 39, 46,
        53, 60, 61, 54, 47, 55, 62, 63
    )

    @inline(__always)
    private static func zigzagIndex(_ i: Int) -> Int {
        Int(withUnsafePointer(to: zigzag) { ptr in
            UnsafeRawPointer(ptr).load(fromByteOffset: i, as: UInt8.self)
        })
    }

    // MARK: - Init

    init() {
        quantTables = .allocate(capacity: 4 * 64)
        huffDC = .allocate(capacity: 2 * 256)
        huffAC = .allocate(capacity: 2 * 256)
        huffSlowDC = .allocate(capacity: 2 * Self.huffSlowTableSize)
        huffSlowAC = .allocate(capacity: 2 * Self.huffSlowTableSize)
        huffSymsDC = .allocate(capacity: Self.huffDCSymsSize)
        huffSymsAC = .allocate(capacity: Self.huffACSymsSize)
        ioBuffer = .allocate(capacity: Self.ioBufferSize)
        clusterMap = .allocate(capacity: Self.maxClusters)
        blockBuf = .allocate(capacity: 64)
        mcuRowBuf = .allocate(capacity: Self.mcuRowBufSize)
        cbBuf = .allocate(capacity: Self.chromaBufSize)
        crBuf = .allocate(capacity: Self.chromaBufSize)
    }

    /// Deallocate all buffers.
    mutating func deallocateBuffers() {
        quantTables.deallocate()
        huffDC.deallocate()
        huffAC.deallocate()
        huffSlowDC.deallocate()
        huffSlowAC.deallocate()
        huffSymsDC.deallocate()
        huffSymsAC.deallocate()
        ioBuffer.deallocate()
        clusterMap.deallocate()
        blockBuf.deallocate()
        mcuRowBuf.deallocate()
        cbBuf.deallocate()
        crBuf.deallocate()
    }

    // MARK: - Header Parsing

    /// Parse JPEG markers and prepare for decoding.
    mutating func parseHeader(fat: inout FATFileSystem, cluster: UInt32, fileSize: UInt32) -> Bool {
        self.fileSize = Int(fileSize)

        // Build cluster map
        clusterCount = fat.buildClusterMap(startCluster: cluster,
                                           into: clusterMap,
                                           maxClusters: Self.maxClusters)
        guard clusterCount > 0 else { valid = false; return false }

        // Reset state
        quantValid = 0
        restartInterval = 0
        componentCount = 0
        maxHSamp = 1
        maxVSamp = 1

        // Clear Huffman tables
        for i in 0..<(2 * 256) { huffDC[i] = 0; huffAC[i] = 0 }

        // Read SOI marker
        filePos = 0
        fillIOBuffer(fat: &fat)
        guard ioEnd >= 2,
              ioBuffer[0] == 0xFF, ioBuffer[1] == 0xD8 else {
            valid = false
            return false
        }

        var offset = 2
        filePos = 2

        // Parse markers
        while offset < Int(fileSize) - 1 {
            // Ensure we have bytes to read
            if ioPos >= ioEnd {
                filePos = offset
                fillIOBuffer(fat: &fat)
                if ioEnd == 0 { break }
            }

            // Read marker: must start with 0xFF
            let b0 = readByteAt(offset: offset, fat: &fat)
            guard b0 == 0xFF else { valid = false; return false }
            offset += 1

            // Skip padding 0xFF bytes
            var marker = readByteAt(offset: offset, fat: &fat)
            while marker == 0xFF && offset < Int(fileSize) {
                offset += 1
                marker = readByteAt(offset: offset, fat: &fat)
            }
            offset += 1

            // Handle markers
            switch marker {
            case 0xD8:
                // SOI - shouldn't appear again but ignore
                continue

            case 0xD9:
                // EOI
                valid = false
                return false  // hit EOI before SOS

            case 0xC0:
                // SOF0 - Baseline DCT
                guard parseSOF0(offset: offset, fat: &fat) else {
                    valid = false
                    return false
                }
                let len = readU16BE(offset: offset, fat: &fat)
                offset += Int(len)

            case 0xC4:
                // DHT - Define Huffman Table
                let len = Int(readU16BE(offset: offset, fat: &fat))
                guard parseDHT(offset: offset + 2, length: len - 2, fat: &fat) else {
                    valid = false
                    return false
                }
                offset += len

            case 0xDB:
                // DQT - Define Quantization Table
                let len = Int(readU16BE(offset: offset, fat: &fat))
                guard parseDQT(offset: offset + 2, length: len - 2, fat: &fat) else {
                    valid = false
                    return false
                }
                offset += len

            case 0xDD:
                // DRI - Define Restart Interval
                let len = Int(readU16BE(offset: offset, fat: &fat))
                if len >= 4 {
                    restartInterval = Int(readU16BE(offset: offset + 2, fat: &fat))
                }
                offset += len

            case 0xDA:
                // SOS - Start of Scan
                let len = Int(readU16BE(offset: offset, fat: &fat))
                guard parseSOS(offset: offset + 2, length: len - 2, fat: &fat) else {
                    valid = false
                    return false
                }
                sosDataOffset = offset + len
                // Done parsing markers
                valid = true
                return true

            case 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
                 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF:
                // Unsupported SOF types (progressive, lossless, etc.)
                valid = false
                return false

            default:
                // Skip unknown marker segment (APPn, COM, etc.)
                if marker >= 0xE0 || marker == 0xFE || (marker >= 0xC0 && marker <= 0xDF) {
                    let len = Int(readU16BE(offset: offset, fat: &fat))
                    offset += len
                } else {
                    // Standalone marker or unknown - skip
                    continue
                }
            }
        }

        valid = false
        return false
    }

    // MARK: - SOF0 Parsing

    private mutating func parseSOF0(offset: Int, fat: inout FATFileSystem) -> Bool {
        let len = Int(readU16BE(offset: offset, fat: &fat))
        guard len >= 8 else { return false }

        let precision = readByteAt(offset: offset + 2, fat: &fat)
        guard precision == 8 else { return false }  // only 8-bit supported

        imageHeight = Int(readU16BE(offset: offset + 3, fat: &fat))
        imageWidth = Int(readU16BE(offset: offset + 5, fat: &fat))
        componentCount = Int(readByteAt(offset: offset + 7, fat: &fat))

        guard imageWidth > 0, imageWidth <= Self.maxWidth,
              imageHeight > 0,
              componentCount == 1 || componentCount == 3 else {
            return false
        }
        guard len >= 8 + componentCount * 3 else { return false }

        var off = offset + 8
        for i in 0..<componentCount {
            let id = readByteAt(offset: off, fat: &fat)
            let sampFact = readByteAt(offset: off + 1, fat: &fat)
            let qtIdx = readByteAt(offset: off + 2, fat: &fat)
            let h = Int(sampFact >> 4)
            let v = Int(sampFact & 0x0F)
            guard h >= 1, h <= 2, v >= 1, v <= 2, qtIdx < 4 else { return false }

            switch i {
            case 0:
                compId.0 = id; compHSamp.0 = UInt8(h); compVSamp.0 = UInt8(v); compQuantIdx.0 = qtIdx
            case 1:
                compId.1 = id; compHSamp.1 = UInt8(h); compVSamp.1 = UInt8(v); compQuantIdx.1 = qtIdx
            case 2:
                compId.2 = id; compHSamp.2 = UInt8(h); compVSamp.2 = UInt8(v); compQuantIdx.2 = qtIdx
            default: break
            }

            if h > maxHSamp { maxHSamp = h }
            if v > maxVSamp { maxVSamp = v }
            off += 3
        }

        mcuWidth = maxHSamp * 8
        mcuHeight = maxVSamp * 8
        mcuCountX = (imageWidth + mcuWidth - 1) / mcuWidth
        mcuCountY = (imageHeight + mcuHeight - 1) / mcuHeight
        chromaStride = mcuCountX * 8

        return true
    }

    // MARK: - DQT Parsing

    private mutating func parseDQT(offset: Int, length: Int, fat: inout FATFileSystem) -> Bool {
        var pos = offset
        let end = offset + length

        while pos < end {
            let info = readByteAt(offset: pos, fat: &fat)
            pos += 1
            let precision = info >> 4   // 0 = 8-bit, 1 = 16-bit
            let tableIdx = Int(info & 0x0F)
            guard tableIdx < 4 else { return false }

            let base = tableIdx * 64
            if precision == 0 {
                // 8-bit values — store in natural (row-major) order via zigzag mapping
                guard pos + 64 <= end else { return false }
                for i in 0..<64 {
                    let natural = Self.zigzagIndex(i)
                    quantTables[base + natural] = UInt16(readByteAt(offset: pos + i, fat: &fat))
                }
                pos += 64
            } else {
                // 16-bit values — store in natural order
                guard pos + 128 <= end else { return false }
                for i in 0..<64 {
                    let natural = Self.zigzagIndex(i)
                    quantTables[base + natural] = readU16BE(offset: pos + i * 2, fat: &fat)
                }
                pos += 128
            }
            quantValid |= UInt8(1 << tableIdx)
        }
        return true
    }

    // MARK: - DHT Parsing

    private mutating func parseDHT(offset: Int, length: Int, fat: inout FATFileSystem) -> Bool {
        var pos = offset
        let end = offset + length

        while pos < end {
            let info = readByteAt(offset: pos, fat: &fat)
            pos += 1
            let tableClass = Int(info >> 4)   // 0 = DC, 1 = AC
            let tableId = Int(info & 0x0F)
            guard tableId < 2, tableClass <= 1 else { return false }

            // Read 16 count bytes
            var counts = (UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                          UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                          UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                          UInt8(0), UInt8(0), UInt8(0), UInt8(0))
            guard pos + 16 <= end else { return false }
            withUnsafeMutablePointer(to: &counts) { ptr in
                let raw = UnsafeMutableRawPointer(ptr)
                for i in 0..<16 {
                    raw.storeBytes(of: readByteAt(offset: pos + i, fat: &fat),
                                   toByteOffset: i, as: UInt8.self)
                }
            }
            pos += 16

            // Count total symbols
            var totalSymbols = 0
            withUnsafePointer(to: counts) { ptr in
                let raw = UnsafeRawPointer(ptr)
                for i in 0..<16 {
                    totalSymbols += Int(raw.load(fromByteOffset: i, as: UInt8.self))
                }
            }
            guard pos + totalSymbols <= end else { return false }

            // Build lookup table
            if tableClass == 0 {
                buildHuffmanTable(
                    primary: huffDC.advanced(by: tableId * 256),
                    slowTable: huffSlowDC.advanced(by: tableId * Self.huffSlowTableSize),
                    syms: huffSymsDC.advanced(by: tableId * 16),
                    counts: counts,
                    symbolsOffset: pos,
                    fat: &fat)
            } else {
                buildHuffmanTable(
                    primary: huffAC.advanced(by: tableId * 256),
                    slowTable: huffSlowAC.advanced(by: tableId * Self.huffSlowTableSize),
                    syms: huffSymsAC.advanced(by: tableId * 256),
                    counts: counts,
                    symbolsOffset: pos,
                    fat: &fat)
            }
            pos += totalSymbols
        }
        return true
    }

    /// Build a Huffman lookup table.
    /// Primary table: 256 entries for codes up to 8 bits.
    /// Slow table: for codes 9-16 bits, stores (minCode, maxCode, symOffset) per length.
    private mutating func buildHuffmanTable(
        primary: UnsafeMutablePointer<UInt16>,
        slowTable: UnsafeMutablePointer<UInt8>,
        syms: UnsafeMutablePointer<UInt8>,
        counts: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                 UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8),
        symbolsOffset: Int,
        fat: inout FATFileSystem
    ) {
        // Clear primary table
        for i in 0..<256 { primary[i] = 0 }

        // Clear slow table
        for i in 0..<Self.huffSlowTableSize { slowTable[i] = 0 }

        var code: UInt32 = 0
        var symIdx = 0
        var slowSymIdx = 0

        for bitLen in 1...16 {
            let count = Int(withUnsafePointer(to: counts) { ptr in
                UnsafeRawPointer(ptr).load(fromByteOffset: bitLen - 1, as: UInt8.self)
            })

            if bitLen <= 8 {
                // Fill primary table
                for _ in 0..<count {
                    let symbol = readByteAt(offset: symbolsOffset + symIdx, fat: &fat)
                    let fillCount = 1 << (8 - bitLen)
                    let baseCode = Int(code) << (8 - bitLen)
                    let entry = UInt16(symbol) | (UInt16(bitLen) << 8)
                    for f in 0..<fillCount {
                        primary[baseCode + f] = entry
                    }
                    code += 1
                    symIdx += 1
                }
            } else {
                // Store in slow table for this bit length
                let slowOff = (bitLen - 9) * 6  // 6 bytes per entry
                let minCode = code
                let symOff = UInt16(slowSymIdx)

                for _ in 0..<count {
                    let symbol = readByteAt(offset: symbolsOffset + symIdx, fat: &fat)
                    syms[slowSymIdx] = symbol
                    slowSymIdx += 1
                    code += 1
                    symIdx += 1
                }

                let maxCode = code - 1
                // Store: minCode(2) + maxCode(2) + symOffset(2)
                slowTable[slowOff] = UInt8(minCode & 0xFF)
                slowTable[slowOff + 1] = UInt8((minCode >> 8) & 0xFF)
                slowTable[slowOff + 2] = UInt8(maxCode & 0xFF)
                slowTable[slowOff + 3] = UInt8((maxCode >> 8) & 0xFF)
                slowTable[slowOff + 4] = UInt8(symOff & 0xFF)
                slowTable[slowOff + 5] = UInt8((symOff >> 8) & 0xFF)
            }

            code <<= 1
        }
    }

    // MARK: - SOS Parsing

    private mutating func parseSOS(offset: Int, length: Int, fat: inout FATFileSystem) -> Bool {
        guard length >= 1 else { return false }
        let numComp = Int(readByteAt(offset: offset, fat: &fat))
        guard numComp == componentCount, length >= 1 + numComp * 2 + 3 else { return false }

        var pos = offset + 1
        for i in 0..<numComp {
            let _ = readByteAt(offset: pos, fat: &fat)  // component selector
            let tableSpec = readByteAt(offset: pos + 1, fat: &fat)
            let dcIdx = tableSpec >> 4
            let acIdx = tableSpec & 0x0F
            guard dcIdx < 2, acIdx < 2 else { return false }

            switch i {
            case 0: compDcIdx.0 = dcIdx; compAcIdx.0 = acIdx
            case 1: compDcIdx.1 = dcIdx; compAcIdx.1 = acIdx
            case 2: compDcIdx.2 = dcIdx; compAcIdx.2 = acIdx
            default: break
            }
            pos += 2
        }

        // Skip spectral selection and successive approximation (baseline: 0, 63, 0)
        return true
    }

    // MARK: - Decode to Framebuffer

    /// Decode the JPEG image directly into the framebuffer with dithering.
    mutating func decode(fat: inout FATFileSystem, fb: Framebuffer,
                         areaX: Int, areaY: Int, areaW: Int, areaH: Int) {
        guard valid else { return }

        // Center the image within the area
        let drawW = min(imageWidth, areaW)
        let drawH = min(imageHeight, areaH)
        let offsetX = areaX + (areaW - drawW) / 2
        let offsetY = areaY + (areaH - drawH) / 2

        let skipLeft = imageWidth > areaW ? (imageWidth - areaW) / 2 : 0
        let skipTop = imageHeight > areaH ? (imageHeight - areaH) / 2 : 0

        // Reset bitstream
        filePos = sosDataOffset
        fillIOBuffer(fat: &fat)
        ioPos = 0
        bitBuffer = 0
        bitsAvailable = 0
        hitMarker = false

        // Reset DC predictors
        dcPred = (0, 0, 0)

        var restartCount = 0
        var displayY = 0

        for mcuRow in 0..<mcuCountY {
            let pixelY = mcuRow * mcuHeight

            for mcuCol in 0..<mcuCountX {
                // Check for restart marker
                if restartInterval > 0 && restartCount > 0
                    && restartCount % restartInterval == 0 {
                    alignToNextRestart(fat: &fat)
                    dcPred = (0, 0, 0)
                }

                // Decode all blocks in this MCU
                decodeMCU(mcuCol: mcuCol, mcuRow: mcuRow, fat: &fat)
                restartCount += 1
            }

            // Write MCU row to framebuffer
            let rowStartY = pixelY
            let rowEndY = min(pixelY + mcuHeight, imageHeight)

            for py in rowStartY..<rowEndY {
                let screenRow = py - skipTop
                if screenRow < 0 { continue }
                if screenRow >= drawH { break }

                let destY = offsetY + screenRow

                for px in 0..<drawW {
                    let srcX = skipLeft + px
                    let gray = getPixelGray(x: srcX, y: py - rowStartY)
                    let black = ImageDither.shouldBeBlack(gray: gray,
                                                          x: px, y: screenRow)
                    fb.setPixel(x: offsetX + px, y: destY, black: black)
                }
            }

            displayY += (rowEndY - rowStartY)
        }
    }

    // MARK: - MCU Decode

    /// Decode one MCU and store pixel data into mcuRowBuf/cbBuf/crBuf.
    private mutating func decodeMCU(mcuCol: Int, mcuRow: Int, fat: inout FATFileSystem) {
        if componentCount == 1 {
            // Grayscale: one 8x8 block
            decodeBlock(quantIdx: Int(compQuantIdx.0),
                        dcTableIdx: Int(compDcIdx.0),
                        acTableIdx: Int(compAcIdx.0),
                        compIdx: 0,
                        fat: &fat)
            storeBlockGray(mcuCol: mcuCol, blockX: 0, blockY: 0)
        } else {
            // YCbCr: decode Y blocks
            let hSamp = Int(compHSamp.0)
            let vSamp = Int(compVSamp.0)

            for by in 0..<vSamp {
                for bx in 0..<hSamp {
                    decodeBlock(quantIdx: Int(compQuantIdx.0),
                                dcTableIdx: Int(compDcIdx.0),
                                acTableIdx: Int(compAcIdx.0),
                                compIdx: 0,
                                fat: &fat)
                    storeBlockY(mcuCol: mcuCol, blockX: bx, blockY: by)
                }
            }

            // Decode Cb block
            decodeBlock(quantIdx: Int(compQuantIdx.1),
                        dcTableIdx: Int(compDcIdx.1),
                        acTableIdx: Int(compAcIdx.1),
                        compIdx: 1,
                        fat: &fat)
            storeBlockChroma(buf: cbBuf, mcuCol: mcuCol)

            // Decode Cr block
            decodeBlock(quantIdx: Int(compQuantIdx.2),
                        dcTableIdx: Int(compDcIdx.2),
                        acTableIdx: Int(compAcIdx.2),
                        compIdx: 2,
                        fat: &fat)
            storeBlockChroma(buf: crBuf, mcuCol: mcuCol)
        }
    }

    /// Decode one 8x8 block: Huffman decode → dequantize → IDCT.
    private mutating func decodeBlock(quantIdx: Int, dcTableIdx: Int, acTableIdx: Int,
                                      compIdx: Int, fat: inout FATFileSystem) {
        // Clear block
        for i in 0..<64 { blockBuf[i] = 0 }

        // DC coefficient
        let dcSymbol = decodeHuffman(isDC: true, tableIdx: dcTableIdx, fat: &fat)
        let dcBits = Int(dcSymbol & 0x0F)
        if dcBits > 0 {
            let dcValue = Int32(receiveExtend(bits: dcBits, fat: &fat))
            switch compIdx {
            case 0: dcPred.0 += dcValue; blockBuf[0] = dcPred.0
            case 1: dcPred.1 += dcValue; blockBuf[0] = dcPred.1
            case 2: dcPred.2 += dcValue; blockBuf[0] = dcPred.2
            default: break
            }
        } else {
            switch compIdx {
            case 0: blockBuf[0] = dcPred.0
            case 1: blockBuf[0] = dcPred.1
            case 2: blockBuf[0] = dcPred.2
            default: break
            }
        }

        // AC coefficients (stored in natural order via zigzag mapping)
        var k = 1
        while k < 64 {
            let acSymbol = decodeHuffman(isDC: false, tableIdx: acTableIdx, fat: &fat)
            if acSymbol == 0 {
                break  // EOB
            }
            let runLen = Int(acSymbol >> 4)
            let size = Int(acSymbol & 0x0F)

            if size == 0 {
                if runLen == 15 {
                    k += 16  // ZRL
                    continue
                }
                break
            }

            k += runLen
            guard k < 64 else { break }

            let value = Int32(receiveExtend(bits: size, fat: &fat))
            blockBuf[Self.zigzagIndex(k)] = value
            k += 1
        }

        // Dequantize (both blockBuf and quantTables are now in natural order)
        let qBase = quantIdx * 64
        for i in 0..<64 {
            blockBuf[i] = blockBuf[i] * Int32(quantTables[qBase + i])
        }

        // IDCT
        idct8x8()
    }

    // MARK: - IDCT (Integer, based on IJG libjpeg jidctint.c)

    /// Integer IDCT using Loeffler-Ligtenberg-Moschytz algorithm.
    /// 13-bit fixed-point constants, row-column decomposition.
    /// Operates in-place on blockBuf (64 Int32 entries, natural order).
    private mutating func idct8x8() {
        // DC-only fast path
        var allZeroAC = true
        for i in 1..<64 {
            if blockBuf[i] != 0 { allZeroAC = false; break }
        }
        if allZeroAC {
            let dcVal = Int32(clampU8(Int(blockBuf[0]) / 8 + 128))
            for i in 0..<64 { blockBuf[i] = dcVal }
            return
        }

        // Row pass: output scaled by 2^PASS1_BITS (=2)
        for row in 0..<8 {
            idctRowPass(base: row * 8)
        }

        // Column pass: output clamped to 0-255
        for col in 0..<8 {
            idctColPass(col: col)
        }
    }

    /// 1D IDCT on a row. DESCALE by CONST_BITS - PASS1_BITS = 11.
    private mutating func idctRowPass(base: Int) {
        let x0 = blockBuf[base]
        let x1 = blockBuf[base + 1]
        let x2 = blockBuf[base + 2]
        let x3 = blockBuf[base + 3]
        let x4 = blockBuf[base + 4]
        let x5 = blockBuf[base + 5]
        let x6 = blockBuf[base + 6]
        let x7 = blockBuf[base + 7]

        // Row AC-zero shortcut
        if x1 == 0 && x2 == 0 && x3 == 0 && x4 == 0
            && x5 == 0 && x6 == 0 && x7 == 0 {
            let dc = x0 << 2  // scale by PASS1_BITS
            blockBuf[base] = dc
            blockBuf[base + 1] = dc
            blockBuf[base + 2] = dc
            blockBuf[base + 3] = dc
            blockBuf[base + 4] = dc
            blockBuf[base + 5] = dc
            blockBuf[base + 6] = dc
            blockBuf[base + 7] = dc
            return
        }

        // Even part
        let z2 = x2
        let z3 = x6
        let z1e = (z2 + z3) * 4433             // FIX(0.541196100)
        let tmp2 = z1e - (z3 * 15137)           // FIX(1.847759065)
        let tmp3 = z1e + (z2 * 6270)            // FIX(0.765366865)

        let tmp0e = (x0 + x4) << 13             // << CONST_BITS
        let tmp1e = (x0 - x4) << 13

        let tmp10 = tmp0e + tmp3
        let tmp13 = tmp0e - tmp3
        let tmp11 = tmp1e + tmp2
        let tmp12 = tmp1e - tmp2

        // Odd part
        var t0 = x7
        var t1 = x5
        var t2 = x3
        var t3 = x1

        let z1o = t0 + t3
        let z2o = t1 + t2
        let z3o = t0 + t2
        let z4o = t1 + t3
        let z5 = (z3o + z4o) * 9633             // FIX(1.175875602)

        t0 = t0 * 2446                          // FIX(0.298631336)
        t1 = t1 * 16819                         // FIX(2.053119869)
        t2 = t2 * 25172                         // FIX(3.072711026)
        t3 = t3 * 12299                         // FIX(1.501321110)
        let z1f = z1o * -7373                    // -FIX(0.899976223)
        let z2f = z2o * -20995                   // -FIX(2.562915447)
        let z3f = z3o * -16069 + z5              // -FIX(1.961570560) + z5
        let z4f = z4o * -3196 + z5               // -FIX(0.390180644) + z5

        t0 = t0 + z1f + z3f
        t1 = t1 + z2f + z4f
        t2 = t2 + z2f + z3f
        t3 = t3 + z1f + z4f

        // Recombine and DESCALE by 11 (CONST_BITS - PASS1_BITS)
        blockBuf[base]     = descale(tmp10 + t3, 11)
        blockBuf[base + 1] = descale(tmp11 + t2, 11)
        blockBuf[base + 2] = descale(tmp12 + t1, 11)
        blockBuf[base + 3] = descale(tmp13 + t0, 11)
        blockBuf[base + 4] = descale(tmp13 - t0, 11)
        blockBuf[base + 5] = descale(tmp12 - t1, 11)
        blockBuf[base + 6] = descale(tmp11 - t2, 11)
        blockBuf[base + 7] = descale(tmp10 - t3, 11)
    }

    /// 1D IDCT on a column. DESCALE by CONST_BITS + PASS1_BITS + 3 = 18, level shift +128.
    private mutating func idctColPass(col: Int) {
        let x0 = blockBuf[col]
        let x1 = blockBuf[col + 8]
        let x2 = blockBuf[col + 16]
        let x3 = blockBuf[col + 24]
        let x4 = blockBuf[col + 32]
        let x5 = blockBuf[col + 40]
        let x6 = blockBuf[col + 48]
        let x7 = blockBuf[col + 56]

        // Column AC-zero shortcut
        if x1 == 0 && x2 == 0 && x3 == 0 && x4 == 0
            && x5 == 0 && x6 == 0 && x7 == 0 {
            let val = Int32(clampU8(Int(descale(x0, 5)) + 128))
            blockBuf[col] = val
            blockBuf[col + 8] = val
            blockBuf[col + 16] = val
            blockBuf[col + 24] = val
            blockBuf[col + 32] = val
            blockBuf[col + 40] = val
            blockBuf[col + 48] = val
            blockBuf[col + 56] = val
            return
        }

        // Even part
        let z2 = x2
        let z3 = x6
        let z1e = (z2 + z3) * 4433
        let tmp2 = z1e - (z3 * 15137)
        let tmp3 = z1e + (z2 * 6270)

        let tmp0e = (x0 + x4) << 13
        let tmp1e = (x0 - x4) << 13

        let tmp10 = tmp0e + tmp3
        let tmp13 = tmp0e - tmp3
        let tmp11 = tmp1e + tmp2
        let tmp12 = tmp1e - tmp2

        // Odd part
        var t0 = x7
        var t1 = x5
        var t2 = x3
        var t3 = x1

        let z1o = t0 + t3
        let z2o = t1 + t2
        let z3o = t0 + t2
        let z4o = t1 + t3
        let z5 = (z3o + z4o) * 9633

        t0 = t0 * 2446
        t1 = t1 * 16819
        t2 = t2 * 25172
        t3 = t3 * 12299
        let z1f = z1o * -7373
        let z2f = z2o * -20995
        let z3f = z3o * -16069 + z5
        let z4f = z4o * -3196 + z5

        t0 = t0 + z1f + z3f
        t1 = t1 + z2f + z4f
        t2 = t2 + z2f + z3f
        t3 = t3 + z1f + z4f

        // Recombine, DESCALE by 18, level shift +128, clamp to 0-255
        blockBuf[col]      = Int32(clampU8(Int(descale(tmp10 + t3, 18)) + 128))
        blockBuf[col + 8]  = Int32(clampU8(Int(descale(tmp11 + t2, 18)) + 128))
        blockBuf[col + 16] = Int32(clampU8(Int(descale(tmp12 + t1, 18)) + 128))
        blockBuf[col + 24] = Int32(clampU8(Int(descale(tmp13 + t0, 18)) + 128))
        blockBuf[col + 32] = Int32(clampU8(Int(descale(tmp13 - t0, 18)) + 128))
        blockBuf[col + 40] = Int32(clampU8(Int(descale(tmp12 - t1, 18)) + 128))
        blockBuf[col + 48] = Int32(clampU8(Int(descale(tmp11 - t2, 18)) + 128))
        blockBuf[col + 56] = Int32(clampU8(Int(descale(tmp10 - t3, 18)) + 128))
    }

    /// Rounded right shift (arithmetic).
    @inline(__always)
    private func descale(_ x: Int32, _ n: Int) -> Int32 {
        return (x + (1 << (n - 1))) >> n
    }

    // MARK: - Block Storage

    /// Store decoded grayscale block into mcuRowBuf.
    private func storeBlockGray(mcuCol: Int, blockX: Int, blockY: Int) {
        let pixelX = mcuCol * mcuWidth + blockX * 8
        let pixelYBase = blockY * 8
        for row in 0..<8 {
            let bufY = pixelYBase + row
            let srcBase = row * 8
            for col in 0..<8 {
                let px = pixelX + col
                if px < Self.maxWidth && bufY < 16 {
                    mcuRowBuf[bufY * Self.maxWidth + px] = UInt8(blockBuf[srcBase + col])
                }
            }
        }
    }

    /// Store decoded Y block into mcuRowBuf.
    private func storeBlockY(mcuCol: Int, blockX: Int, blockY: Int) {
        let pixelX = mcuCol * mcuWidth + blockX * 8
        let pixelYBase = blockY * 8
        for row in 0..<8 {
            let bufY = pixelYBase + row
            let srcBase = row * 8
            for col in 0..<8 {
                let px = pixelX + col
                if px < Self.maxWidth && bufY < 16 {
                    mcuRowBuf[bufY * Self.maxWidth + px] = UInt8(blockBuf[srcBase + col])
                }
            }
        }
    }

    /// Store decoded chroma block into Cb or Cr buffer.
    private func storeBlockChroma(buf: UnsafeMutablePointer<UInt8>, mcuCol: Int) {
        let baseX = mcuCol * 8
        for row in 0..<8 {
            let srcBase = row * 8
            for col in 0..<8 {
                let px = baseX + col
                if px < chromaStride && row < 8 {
                    buf[row * chromaStride + px] = UInt8(blockBuf[srcBase + col])
                }
            }
        }
    }

    // MARK: - Pixel Access

    /// Get grayscale value for a pixel in the current MCU row buffer.
    @inline(__always)
    private func getPixelGray(x: Int, y: Int) -> UInt8 {
        if componentCount == 1 {
            return mcuRowBuf[y * Self.maxWidth + x]
        }

        // YCbCr → RGB → gray
        let yVal = mcuRowBuf[y * Self.maxWidth + x]

        let chromaX: Int
        let chromaY: Int

        if maxHSamp == 2 && maxVSamp == 2 {
            // 4:2:0
            chromaX = x / 2
            chromaY = y / 2
        } else if maxHSamp == 2 {
            // 4:2:2
            chromaX = x / 2
            chromaY = y
        } else {
            // 4:4:4
            chromaX = x
            chromaY = y
        }

        let cx = min(chromaX, chromaStride - 1)
        let cy = min(chromaY, 7)

        let cb = Int(cbBuf[cy * chromaStride + cx]) - 128
        let cr = Int(crBuf[cy * chromaStride + cx]) - 128

        // YCbCr to RGB (integer approximation)
        let yInt = Int(yVal)
        let r = clampU8(yInt + ((359 * cr) >> 8))
        let g = clampU8(yInt - ((88 * cb + 183 * cr) >> 8))
        let b = clampU8(yInt + ((454 * cb) >> 8))

        return ImageDither.rgbToGray(r: UInt8(r), g: UInt8(g), b: UInt8(b))
    }

    // MARK: - Huffman Decoding

    /// Decode one Huffman symbol from the bitstream.
    private mutating func decodeHuffman(isDC: Bool, tableIdx: Int,
                                         fat: inout FATFileSystem) -> UInt8 {
        // Ensure at least 16 bits available
        while bitsAvailable < 16 {
            let byte = readNextByte(fat: &fat)
            bitBuffer = (bitBuffer << 8) | UInt32(byte)
            bitsAvailable += 8
        }

        // Try primary table (8-bit lookup)
        let peek = Int((bitBuffer >> (bitsAvailable - 8)) & 0xFF)

        let primary: UnsafeMutablePointer<UInt16>
        if isDC {
            primary = huffDC.advanced(by: tableIdx * 256)
        } else {
            primary = huffAC.advanced(by: tableIdx * 256)
        }

        let entry = primary[peek]
        let codeLen = Int(entry >> 8)

        if codeLen > 0 && codeLen <= 8 {
            bitsAvailable -= codeLen
            return UInt8(entry & 0xFF)
        }

        // Slow path: codes 9-16 bits
        let slowTable: UnsafeMutablePointer<UInt8>
        let syms: UnsafeMutablePointer<UInt8>
        if isDC {
            slowTable = huffSlowDC.advanced(by: tableIdx * Self.huffSlowTableSize)
            syms = huffSymsDC.advanced(by: tableIdx * 16)
        } else {
            slowTable = huffSlowAC.advanced(by: tableIdx * Self.huffSlowTableSize)
            syms = huffSymsAC.advanced(by: tableIdx * 256)
        }

        for bitLen in 9...16 {
            let slowOff = (bitLen - 9) * 6
            let minCode = UInt32(slowTable[slowOff]) | (UInt32(slowTable[slowOff + 1]) << 8)
            let maxCode = UInt32(slowTable[slowOff + 2]) | (UInt32(slowTable[slowOff + 3]) << 8)
            let symOff = Int(UInt16(slowTable[slowOff + 4]) | (UInt16(slowTable[slowOff + 5]) << 8))

            if minCode == 0 && maxCode == 0 && symOff == 0 && bitLen > 9 {
                // Empty entry - but could be legitimately zero, check next
                continue
            }

            let code = UInt32((bitBuffer >> (bitsAvailable - bitLen)) & ((1 << bitLen) - 1))
            if code >= minCode && code <= maxCode {
                bitsAvailable -= bitLen
                return syms[symOff + Int(code - minCode)]
            }
        }

        // Error: no valid code found
        bitsAvailable -= 1  // consume a bit to avoid infinite loop
        return 0
    }

    /// Read additional bits and extend sign (JPEG receive/extend).
    @inline(__always)
    private mutating func receiveExtend(bits: Int, fat: inout FATFileSystem) -> Int {
        while bitsAvailable < bits {
            let byte = readNextByte(fat: &fat)
            bitBuffer = (bitBuffer << 8) | UInt32(byte)
            bitsAvailable += 8
        }

        bitsAvailable -= bits
        let value = Int((bitBuffer >> bitsAvailable) & ((1 << bits) - 1))

        // Extend sign: if value < 2^(bits-1), subtract 2^bits - 1
        if value < (1 << (bits - 1)) {
            return value - (1 << bits) + 1
        }
        return value
    }

    // MARK: - Bitstream IO

    /// Read next byte from entropy-coded data, handling byte stuffing.
    /// Returns 0 and sets hitMarker when a marker is encountered.
    private mutating func readNextByte(fat: inout FATFileSystem) -> UInt8 {
        // Once a marker is hit, pad with zeros until it's consumed
        if hitMarker { return 0 }

        if ioPos >= ioEnd {
            fillIOBuffer(fat: &fat)
            if ioEnd == 0 { return 0 }
        }

        let byte = ioBuffer[ioPos]
        ioPos += 1

        if byte == 0xFF {
            // Check next byte for stuffing
            if ioPos >= ioEnd {
                fillIOBuffer(fat: &fat)
            }
            if ioEnd > 0 {
                let next = ioBuffer[ioPos]
                if next == 0x00 {
                    // Byte stuffing: 0xFF 0x00 → 0xFF
                    ioPos += 1
                    return 0xFF
                }
                // Marker found — consume the marker byte and set flag
                ioPos += 1
                hitMarker = true
                return 0
            }
        }
        return byte
    }

    // MARK: - Restart Marker Handling

    /// Consume the restart marker and realign the bitstream.
    private mutating func alignToNextRestart(fat: inout FATFileSystem) {
        bitBuffer = 0
        bitsAvailable = 0

        if hitMarker {
            // The marker was already consumed by readNextByte
            hitMarker = false
            return
        }

        // Fallback: scan for RST marker if not already found
        while true {
            if ioPos >= ioEnd {
                fillIOBuffer(fat: &fat)
                if ioEnd == 0 { return }
            }

            let byte = ioBuffer[ioPos]
            ioPos += 1

            if byte == 0xFF {
                if ioPos >= ioEnd {
                    fillIOBuffer(fat: &fat)
                    if ioEnd == 0 { return }
                }
                let marker = ioBuffer[ioPos]
                if marker >= 0xD0 && marker <= 0xD7 {
                    ioPos += 1
                    return
                }
                if marker == 0x00 {
                    ioPos += 1
                }
                if marker == 0xD9 { return }
            }
        }
    }

    // MARK: - IO Helpers

    /// Read a byte at a given file offset (for header parsing).
    private mutating func readByteAt(offset: Int, fat: inout FATFileSystem) -> UInt8 {
        // Check if in current IO buffer
        if offset >= filePos - ioEnd && offset < filePos {
            let idx = offset - (filePos - ioEnd)
            return ioBuffer[idx]
        }

        // Need to seek
        filePos = offset
        fillIOBuffer(fat: &fat)
        if ioEnd > 0 {
            ioPos = 1
            return ioBuffer[0]
        }
        return 0
    }

    /// Fill IO buffer from file.
    private mutating func fillIOBuffer(fat: inout FATFileSystem) {
        let toRead = min(Self.ioBufferSize, fileSize - filePos)
        if toRead <= 0 {
            ioPos = 0
            ioEnd = 0
            return
        }
        let read = fat.readBytes(clusterMap: clusterMap,
                                  clusterCount: clusterCount,
                                  fileOffset: filePos,
                                  into: ioBuffer,
                                  count: toRead)
        ioPos = 0
        ioEnd = read
        filePos += read
    }

    // MARK: - Helpers

    @inline(__always)
    private mutating func readU16BE(offset: Int, fat: inout FATFileSystem) -> UInt16 {
        let hi = UInt16(readByteAt(offset: offset, fat: &fat))
        let lo = UInt16(readByteAt(offset: offset + 1, fat: &fat))
        return (hi << 8) | lo
    }

    @inline(__always)
    private func clampU8(_ value: Int) -> Int {
        if value < 0 { return 0 }
        if value > 255 { return 255 }
        return value
    }
}
