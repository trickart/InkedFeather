/// PNG image decoder with streaming row-by-row decode.
///
/// Decodes PNG files directly from the FAT filesystem into the 1-bit framebuffer.
/// Supports color types 0 (Grayscale), 2 (RGB), 3 (Palette), 4 (GrayAlpha),
/// 6 (RGBA) at bit depths 1, 2, 4, and 8. Adam7 interlacing is not supported.
///
/// Memory usage: ~54KB (deflate window 32KB + row buffers + IO + cluster map).
struct PNGDecoder {
    /// Maximum image width (display native width).
    static let maxWidth = 800

    /// Maximum cluster map entries.
    static let maxClusters = 1024

    /// Maximum IDAT chunks tracked.
    static let maxIDATChunks = 256

    /// Row buffer size: max 800px × 4 bytes (RGBA) + 1 filter byte.
    static let rowBufferSize = maxWidth * 4 + 1

    // MARK: - Parsed Header

    private(set) var imageWidth: Int = 0
    private(set) var imageHeight: Int = 0
    private(set) var bitDepth: Int = 0
    private(set) var colorType: Int = 0
    private(set) var bytesPerPixel: Int = 0
    private(set) var rawRowBytes: Int = 0    // bytes per row (excluding filter byte)
    private(set) var valid: Bool = false

    // MARK: - Buffers

    private let currentRow: UnsafeMutablePointer<UInt8>
    private let previousRow: UnsafeMutablePointer<UInt8>
    private let clusterMap: UnsafeMutablePointer<UInt32>
    private let palette: UnsafeMutablePointer<UInt8>  // 256 × 3 = 768 bytes
    private(set) var clusterCount: Int = 0
    private var paletteCount: Int = 0

    /// IDAT chunk map: alternating (fileOffset, length) pairs.
    private let idatMap: UnsafeMutablePointer<UInt32>
    private var idatCount: Int = 0

    /// DEFLATE decompressor.
    private var deflate = Deflate()

    // MARK: - IDAT Stream State

    /// Current position in the virtual IDAT stream (for input reading).
    private var idatStreamPos: Int = 0
    /// Total size of concatenated IDAT data.
    private var idatTotalSize: Int = 0

    init() {
        currentRow = .allocate(capacity: Self.rowBufferSize)
        previousRow = .allocate(capacity: Self.rowBufferSize)
        clusterMap = .allocate(capacity: Self.maxClusters)
        palette = .allocate(capacity: 256 * 3)
        idatMap = .allocate(capacity: Self.maxIDATChunks * 2)
    }

    /// Deallocate all buffers (including Deflate's).
    mutating func deallocateBuffers() {
        currentRow.deallocate()
        previousRow.deallocate()
        clusterMap.deallocate()
        palette.deallocate()
        idatMap.deallocate()
        deflate.deallocateBuffers()
    }

    // MARK: - Header Parsing

    /// Parse PNG headers and build IDAT map.
    mutating func parseHeader(fat: inout FATFileSystem, cluster: UInt32, fileSize: UInt32) -> Bool {
        // Build cluster map for random access
        clusterCount = fat.buildClusterMap(startCluster: cluster,
                                           into: clusterMap,
                                           maxClusters: Self.maxClusters)
        guard clusterCount > 0 else {
            valid = false
            return false
        }

        // Reuse deflate's input buffer for header parsing (4096 bytes, not yet in use)
        let headerBuf = deflate.inputBufferPtr

        let sigRead = fat.readBytes(clusterMap: clusterMap,
                                     clusterCount: clusterCount,
                                     fileOffset: 0,
                                     into: headerBuf,
                                     count: 8)
        guard sigRead >= 8 else { valid = false; return false }

        // Verify PNG signature: 0x89 P N G \r \n 0x1A \n
        guard headerBuf[0] == 0x89,
              headerBuf[1] == 0x50,  // P
              headerBuf[2] == 0x4E,  // N
              headerBuf[3] == 0x47,  // G
              headerBuf[4] == 0x0D,
              headerBuf[5] == 0x0A,
              headerBuf[6] == 0x1A,
              headerBuf[7] == 0x0A else {
            valid = false
            return false
        }

        // Iterate chunks
        var offset = 8
        var hasIHDR = false
        idatCount = 0
        idatTotalSize = 0
        paletteCount = 0

        while offset + 8 <= Int(fileSize) {
            // Read chunk length (4 bytes big-endian) + type (4 bytes)
            let chunkHeaderRead = fat.readBytes(clusterMap: clusterMap,
                                                 clusterCount: clusterCount,
                                                 fileOffset: offset,
                                                 into: headerBuf,
                                                 count: 8)
            guard chunkHeaderRead >= 8 else { break }

            let chunkLen = Int(readU32BE(headerBuf, offset: 0))
            let type0 = headerBuf[4]
            let type1 = headerBuf[5]
            let type2 = headerBuf[6]
            let type3 = headerBuf[7]

            let dataOffset = offset + 8

            if type0 == 0x49 && type1 == 0x48 && type2 == 0x44 && type3 == 0x52 {
                // IHDR
                guard chunkLen == 13 else { valid = false; return false }
                let ihdrRead = fat.readBytes(clusterMap: clusterMap,
                                              clusterCount: clusterCount,
                                              fileOffset: dataOffset,
                                              into: headerBuf,
                                              count: 13)
                guard ihdrRead >= 13 else { valid = false; return false }

                imageWidth = Int(readU32BE(headerBuf, offset: 0))
                imageHeight = Int(readU32BE(headerBuf, offset: 4))
                bitDepth = Int(headerBuf[8])
                colorType = Int(headerBuf[9])
                let compression = headerBuf[10]
                let filter = headerBuf[11]
                let interlace = headerBuf[12]

                // Validate
                guard compression == 0, filter == 0, interlace == 0 else {
                    valid = false
                    return false
                }
                guard imageWidth > 0, imageWidth <= Self.maxWidth, imageHeight > 0 else {
                    valid = false
                    return false
                }
                guard bitDepth == 1 || bitDepth == 2 || bitDepth == 4 || bitDepth == 8 else {
                    valid = false
                    return false
                }

                // Compute bytes per pixel and raw row bytes
                switch colorType {
                case 0:  // Grayscale
                    bytesPerPixel = 1
                    rawRowBytes = (imageWidth * bitDepth + 7) / 8
                case 2:  // RGB
                    guard bitDepth == 8 else { valid = false; return false }
                    bytesPerPixel = 3
                    rawRowBytes = imageWidth * 3
                case 3:  // Palette
                    bytesPerPixel = 1
                    rawRowBytes = (imageWidth * bitDepth + 7) / 8
                case 4:  // GrayAlpha
                    guard bitDepth == 8 else { valid = false; return false }
                    bytesPerPixel = 2
                    rawRowBytes = imageWidth * 2
                case 6:  // RGBA
                    guard bitDepth == 8 else { valid = false; return false }
                    bytesPerPixel = 4
                    rawRowBytes = imageWidth * 4
                default:
                    valid = false
                    return false
                }

                hasIHDR = true

            } else if type0 == 0x50 && type1 == 0x4C && type2 == 0x54 && type3 == 0x45 {
                // PLTE
                paletteCount = chunkLen / 3
                if paletteCount > 256 { paletteCount = 256 }
                let palBytes = paletteCount * 3
                let palRead = fat.readBytes(clusterMap: clusterMap,
                                             clusterCount: clusterCount,
                                             fileOffset: dataOffset,
                                             into: palette,
                                             count: palBytes)
                if palRead < palBytes { paletteCount = 0 }

            } else if type0 == 0x49 && type1 == 0x44 && type2 == 0x41 && type3 == 0x54 {
                // IDAT
                if idatCount < Self.maxIDATChunks {
                    idatMap[idatCount * 2] = UInt32(dataOffset)
                    idatMap[idatCount * 2 + 1] = UInt32(chunkLen)
                    idatCount += 1
                    idatTotalSize += chunkLen
                }

            } else if type0 == 0x49 && type1 == 0x45 && type2 == 0x4E && type3 == 0x44 {
                // IEND
                break
            }

            // Skip to next chunk: data + CRC (4 bytes)
            offset = dataOffset + chunkLen + 4
        }

        // Validate: must have IHDR and at least one IDAT
        guard hasIHDR, idatCount > 0 else {
            valid = false
            return false
        }
        // Palette required for color type 3
        if colorType == 3 && paletteCount == 0 {
            valid = false
            return false
        }

        valid = true
        return true
    }

    // MARK: - Decode to Framebuffer

    /// Decode the PNG image directly into the framebuffer with dithering.
    mutating func decode(fat: inout FATFileSystem, fb: Framebuffer,
                         areaX: Int, areaY: Int, areaW: Int, areaH: Int) {
        guard valid else { return }

        // Center the image within the area
        let drawW = min(imageWidth, areaW)
        let drawH = min(imageHeight, areaH)
        let offsetX = areaX + (areaW - drawW) / 2
        let offsetY = areaY + (areaH - drawH) / 2

        // Skip pixels if image is larger than area
        let srcStartX = imageWidth > areaW ? (imageWidth - areaW) / 2 : 0
        let skipTopRows = imageHeight > areaH ? (imageHeight - areaH) / 2 : 0

        // Reset deflate and previous row
        deflate.reset()
        idatStreamPos = 0
        for i in 0..<rawRowBytes { previousRow[i] = 0 }

        // Pre-fill deflate input buffer
        fillDeflateInput(fat: &fat)

        // Decode each row
        let rowTotal = rawRowBytes + 1  // filter byte + pixel data
        var displayRow = 0

        for srcRow in 0..<imageHeight {
            // Inflate one row, refilling input as needed
            let inflated = inflateRow(fat: &fat, count: rowTotal)
            if inflated < rowTotal || deflate.error { break }

            // Unfilter
            let filterByte = currentRow[0]
            unfilterRow(filter: filterByte,
                        current: currentRow.advanced(by: 1),
                        previous: previousRow,
                        bpp: bytesPerPixel,
                        rowBytes: rawRowBytes)

            // Copy current to previous for next row's unfiltering
            for i in 0..<rawRowBytes {
                previousRow[i] = currentRow[i + 1]
            }

            // Skip rows outside the visible area
            if srcRow < skipTopRows { continue }
            if displayRow >= drawH { continue }

            // Convert pixels and write to framebuffer
            let destY = offsetY + displayRow
            for col in 0..<drawW {
                let srcX = srcStartX + col
                let gray = pixelToGray(row: currentRow.advanced(by: 1), x: srcX)
                let black = ImageDither.shouldBeBlack(gray: gray, x: col, y: displayRow)
                fb.setPixel(x: offsetX + col, y: destY, black: black)
            }

            displayRow += 1
        }
    }

    // MARK: - IDAT Stream Management

    /// Inflate exactly `count` bytes into currentRow, refilling deflate's
    /// input buffer from the IDAT stream as needed.
    private mutating func inflateRow(fat: inout FATFileSystem, count: Int) -> Int {
        var totalProduced = 0
        var iterations = 0
        while totalProduced < count {
            iterations += 1
            if iterations > 1000 {
                deflate.setError()
                return totalProduced
            }
            let produced = deflate.inflate(
                into: currentRow.advanced(by: totalProduced),
                count: count - totalProduced)
            totalProduced += produced
            if deflate.error { return totalProduced }
            if deflate.needsInput {
                fillDeflateInput(fat: &fat)
                if deflate.needsInput {
                    // No more data available
                    return totalProduced
                }
            } else if produced == 0 {
                // Stream ended
                return totalProduced
            }
        }
        return totalProduced
    }

    /// Read compressed data from IDAT chunks into deflate's input buffer.
    private mutating func fillDeflateInput(fat: inout FATFileSystem) {
        let capacity = deflate.inputBufferCapacity
        let buffer = deflate.inputBufferPtr
        let bytesRead = readIDATBytes(fat: &fat, into: buffer, count: capacity)
        if bytesRead > 0 {
            deflate.provideInput(count: bytesRead)
        }
    }

    /// Read bytes from the concatenated IDAT stream.
    /// Translates a linear stream position into the correct IDAT chunk + file offset.
    private mutating func readIDATBytes(fat: inout FATFileSystem,
                                         into buffer: UnsafeMutablePointer<UInt8>,
                                         count: Int) -> Int {
        var bytesRead = 0
        var remaining = count

        while remaining > 0 && idatStreamPos < idatTotalSize {
            // Find which IDAT chunk contains the current stream position
            var chunkStreamStart = 0
            var chunkIdx = -1

            for i in 0..<idatCount {
                let chunkLen = Int(idatMap[i * 2 + 1])
                if idatStreamPos < chunkStreamStart + chunkLen {
                    chunkIdx = i
                    break
                }
                chunkStreamStart += chunkLen
            }

            guard chunkIdx >= 0 else { break }

            let chunkFileOffset = Int(idatMap[chunkIdx * 2])
            let chunkLen = Int(idatMap[chunkIdx * 2 + 1])
            let offsetInChunk = idatStreamPos - chunkStreamStart
            let availableInChunk = chunkLen - offsetInChunk
            let toRead = min(remaining, availableInChunk)

            let read = fat.readBytes(
                clusterMap: clusterMap,
                clusterCount: clusterCount,
                fileOffset: chunkFileOffset + offsetInChunk,
                into: buffer.advanced(by: bytesRead),
                count: toRead)

            if read <= 0 { break }
            bytesRead += read
            remaining -= read
            idatStreamPos += read
        }

        return bytesRead
    }

    // MARK: - Row Unfiltering

    /// Apply PNG row unfiltering in-place.
    /// `current` points to pixel data (after filter byte), `previous` is the prior row.
    private func unfilterRow(filter: UInt8,
                             current: UnsafeMutablePointer<UInt8>,
                             previous: UnsafeMutablePointer<UInt8>,
                             bpp: Int, rowBytes: Int) {
        switch filter {
        case 0:
            // None
            break

        case 1:
            // Sub: current[i] += current[i - bpp]
            for i in bpp..<rowBytes {
                current[i] = current[i] &+ current[i - bpp]
            }

        case 2:
            // Up: current[i] += previous[i]
            for i in 0..<rowBytes {
                current[i] = current[i] &+ previous[i]
            }

        case 3:
            // Average: current[i] += floor((left + above) / 2)
            for i in 0..<rowBytes {
                let left: UInt16 = i >= bpp ? UInt16(current[i - bpp]) : 0
                let above = UInt16(previous[i])
                current[i] = current[i] &+ UInt8((left + above) >> 1)
            }

        case 4:
            // Paeth: current[i] += paethPredictor(left, above, upperLeft)
            for i in 0..<rowBytes {
                let a: UInt8 = i >= bpp ? current[i - bpp] : 0       // left
                let b: UInt8 = previous[i]                             // above
                let c: UInt8 = i >= bpp ? previous[i - bpp] : 0      // upper-left
                current[i] = current[i] &+ paethPredictor(a: a, b: b, c: c)
            }

        default:
            break
        }
    }

    /// Paeth predictor function.
    @inline(__always)
    private func paethPredictor(a: UInt8, b: UInt8, c: UInt8) -> UInt8 {
        let p = Int(a) + Int(b) - Int(c)
        let pa = p >= Int(a) ? p - Int(a) : Int(a) - p
        let pb = p >= Int(b) ? p - Int(b) : Int(b) - p
        let pc = p >= Int(c) ? p - Int(c) : Int(c) - p
        if pa <= pb && pa <= pc { return a }
        if pb <= pc { return b }
        return c
    }

    // MARK: - Pixel Conversion

    /// Extract grayscale value from a pixel in the decoded row buffer.
    @inline(__always)
    private func pixelToGray(row: UnsafeMutablePointer<UInt8>, x: Int) -> UInt8 {
        switch colorType {
        case 0:
            // Grayscale
            return unpackGray(row: row, x: x)

        case 2:
            // RGB (8-bit only)
            let offset = x * 3
            let r = row[offset]
            let g = row[offset + 1]
            let b = row[offset + 2]
            return ImageDither.rgbToGray(r: r, g: g, b: b)

        case 3:
            // Palette
            let index = unpackPaletteIndex(row: row, x: x)
            let palOffset = Int(index) * 3
            if palOffset + 2 < paletteCount * 3 {
                let r = palette[palOffset]
                let g = palette[palOffset + 1]
                let b = palette[palOffset + 2]
                return ImageDither.rgbToGray(r: r, g: g, b: b)
            }
            return 128

        case 4:
            // GrayAlpha (8-bit only) — composite over white
            let offset = x * 2
            let gray = row[offset]
            let alpha = row[offset + 1]
            return compositeOverWhite(value: gray, alpha: alpha)

        case 6:
            // RGBA (8-bit only) — composite over white, then to gray
            let offset = x * 4
            let r = row[offset]
            let g = row[offset + 1]
            let b = row[offset + 2]
            let a = row[offset + 3]
            let cr = compositeOverWhite(value: r, alpha: a)
            let cg = compositeOverWhite(value: g, alpha: a)
            let cb = compositeOverWhite(value: b, alpha: a)
            return ImageDither.rgbToGray(r: cr, g: cg, b: cb)

        default:
            return 128
        }
    }

    /// Unpack grayscale value for sub-byte bit depths.
    @inline(__always)
    private func unpackGray(row: UnsafeMutablePointer<UInt8>, x: Int) -> UInt8 {
        switch bitDepth {
        case 8:
            return row[x]
        case 4:
            let byte = row[x / 2]
            let shift = (1 - (x & 1)) * 4
            let val = (byte >> shift) & 0x0F
            return val * 17  // scale 0–15 to 0–255
        case 2:
            let byte = row[x / 4]
            let shift = (3 - (x & 3)) * 2
            let val = (byte >> shift) & 0x03
            return val * 85  // scale 0–3 to 0–255
        case 1:
            let byte = row[x / 8]
            let shift = 7 - (x & 7)
            let val = (byte >> shift) & 0x01
            return val == 0 ? 0 : 255
        default:
            return 128
        }
    }

    /// Unpack palette index for sub-byte bit depths.
    @inline(__always)
    private func unpackPaletteIndex(row: UnsafeMutablePointer<UInt8>, x: Int) -> UInt8 {
        switch bitDepth {
        case 8:
            return row[x]
        case 4:
            let byte = row[x / 2]
            let shift = (1 - (x & 1)) * 4
            return (byte >> shift) & 0x0F
        case 2:
            let byte = row[x / 4]
            let shift = (3 - (x & 3)) * 2
            return (byte >> shift) & 0x03
        case 1:
            let byte = row[x / 8]
            let shift = 7 - (x & 7)
            return (byte >> shift) & 0x01
        default:
            return 0
        }
    }

    /// Composite a color value over white using alpha.
    /// Result = (alpha * value + (255 - alpha) * 255) / 255
    @inline(__always)
    private func compositeOverWhite(value: UInt8, alpha: UInt8) -> UInt8 {
        if alpha == 255 { return value }
        if alpha == 0 { return 255 }
        let v = UInt32(alpha) * UInt32(value) + UInt32(255 - alpha) * 255
        return UInt8(v / 255)
    }

    // MARK: - Helpers

    @inline(__always)
    private func readU32BE(_ buf: UnsafeMutablePointer<UInt8>, offset: Int) -> UInt32 {
        (UInt32(buf[offset]) << 24)
        | (UInt32(buf[offset + 1]) << 16)
        | (UInt32(buf[offset + 2]) << 8)
        | UInt32(buf[offset + 3])
    }
}
