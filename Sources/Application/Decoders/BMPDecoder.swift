/// BMP image decoder with streaming row-by-row decode.
///
/// Decodes BMP files directly from the FAT filesystem into the 1-bit framebuffer.
/// Supports 24-bit RGB, 32-bit RGBA, 8-bit palette, and 1-bit monochrome BMPs.
/// Uses ordered dithering for grayscale-to-1-bit conversion.
///
/// Memory usage: ~10.5KB (row buffer + cluster map + IO buffer).
struct BMPDecoder {
    /// Maximum image width we support (display native width).
    static let maxWidth = 800

    /// Maximum cluster map entries (supports files up to ~4MB with 4KB clusters).
    static let maxClusters = 1024

    /// IO buffer size (8 sectors for efficient reads).
    static let ioBufferSize = 4096

    /// Row buffer: max 800px * 4 bytes (32-bit RGBA).
    static let rowBufferSize = maxWidth * 4

    /// Palette buffer: max 256 entries * 4 bytes.
    static let paletteSize = 256 * 4

    // MARK: - Parsed Header

    private(set) var imageWidth: Int = 0
    private(set) var imageHeight: Int = 0
    private(set) var bitsPerPixel: Int = 0
    private(set) var topDown: Bool = false
    private(set) var pixelDataOffset: Int = 0
    private(set) var rowStride: Int = 0  // bytes per row (padded to 4-byte boundary)
    private(set) var valid: Bool = false

    // MARK: - Buffers

    private let rowBuffer: UnsafeMutablePointer<UInt8>
    private let ioBuffer: UnsafeMutablePointer<UInt8>
    private let clusterMap: UnsafeMutablePointer<UInt32>
    private let palette: UnsafeMutablePointer<UInt8>
    private(set) var clusterCount: Int = 0

    init() {
        rowBuffer = .allocate(capacity: Self.rowBufferSize)
        ioBuffer = .allocate(capacity: Self.ioBufferSize)
        clusterMap = .allocate(capacity: Self.maxClusters)
        palette = .allocate(capacity: Self.paletteSize)
    }

    // MARK: - Header Parsing

    /// Parse BMP headers from the first bytes of the file.
    /// Call this after reading the header bytes into ioBuffer.
    mutating func parseHeader(fat: inout FATFileSystem, cluster: UInt32, fileSize: UInt32) -> Bool {
        // Build cluster map for random access
        clusterCount = fat.buildClusterMap(startCluster: cluster,
                                           into: clusterMap,
                                           maxClusters: Self.maxClusters)
        guard clusterCount > 0 else {
            valid = false
            return false
        }

        // Read first 512 bytes (contains all BMP headers)
        let headerBytes = fat.readBytes(clusterMap: clusterMap,
                                        clusterCount: clusterCount,
                                        fileOffset: 0,
                                        into: ioBuffer,
                                        count: min(Int(fileSize), Self.ioBufferSize))
        guard headerBytes >= 54 else {
            valid = false
            return false
        }

        // BMP file header (14 bytes)
        guard ioBuffer[0] == 0x42, ioBuffer[1] == 0x4D else {  // "BM"
            valid = false
            return false
        }
        pixelDataOffset = Int(readU32(ioBuffer, offset: 10))

        // DIB header
        let dibHeaderSize = Int(readU32(ioBuffer, offset: 14))
        guard dibHeaderSize >= 40 else {  // BITMAPINFOHEADER or larger
            valid = false
            return false
        }

        let rawWidth = Int(Int32(bitPattern: readU32(ioBuffer, offset: 18)))
        let rawHeight = Int(Int32(bitPattern: readU32(ioBuffer, offset: 22)))
        let compression = readU32(ioBuffer, offset: 30)

        // Only BI_RGB (uncompressed) and BI_BITFIELDS supported
        guard compression == 0 || compression == 3 else {
            valid = false
            return false
        }

        imageWidth = rawWidth
        if rawHeight < 0 {
            imageHeight = -rawHeight
            topDown = true
        } else {
            imageHeight = rawHeight
            topDown = false
        }

        guard imageWidth > 0, imageWidth <= Self.maxWidth,
              imageHeight > 0 else {
            valid = false
            return false
        }

        bitsPerPixel = Int(readU16(ioBuffer, offset: 28))
        guard bitsPerPixel == 1 || bitsPerPixel == 4 || bitsPerPixel == 8
              || bitsPerPixel == 24 || bitsPerPixel == 32 else {
            valid = false
            return false
        }

        // Calculate row stride (padded to 4 bytes)
        let bitsPerRow = imageWidth * bitsPerPixel
        rowStride = ((bitsPerRow + 31) / 32) * 4

        // Read palette if needed
        if bitsPerPixel <= 8 {
            let paletteOffset = 14 + dibHeaderSize
            let paletteEntries = 1 << bitsPerPixel
            let paletteBytes = paletteEntries * 4
            if paletteOffset + paletteBytes <= headerBytes {
                // Palette is in the already-read buffer
                for i in 0..<paletteBytes {
                    palette[i] = ioBuffer[paletteOffset + i]
                }
            } else {
                // Need separate read for palette
                let read = fat.readBytes(clusterMap: clusterMap,
                                         clusterCount: clusterCount,
                                         fileOffset: paletteOffset,
                                         into: palette,
                                         count: paletteBytes)
                guard read == paletteBytes else {
                    valid = false
                    return false
                }
            }
        }

        valid = true
        return true
    }

    // MARK: - Decode to Framebuffer

    /// Decode the BMP image directly into the framebuffer with dithering.
    /// The image is centered in the given area (areaX, areaY, areaW, areaH).
    func decode(fat: inout FATFileSystem, fb: Framebuffer,
                areaX: Int, areaY: Int, areaW: Int, areaH: Int) {
        guard valid else { return }

        // Center the image within the area
        let drawW = min(imageWidth, areaW)
        let drawH = min(imageHeight, areaH)
        let offsetX = areaX + (areaW - drawW) / 2
        let offsetY = areaY + (areaH - drawH) / 2

        // Skip pixels if image is larger than area
        let srcStartX = imageWidth > areaW ? (imageWidth - areaW) / 2 : 0

        // 1-bit BMP fast path: batch-read rows into rowBuffer to minimize SD accesses
        if bitsPerPixel == 1 {
            let gray0 = ImageDither.rgbToGray(r: palette[2], g: palette[1], b: palette[0])
            let invert = gray0 > 128
            let rowsPerBatch = Self.rowBufferSize / rowStride  // 3200/60 = 53 rows

            // Vertical skip for centering
            let vSkip = imageHeight > areaH ? (imageHeight - areaH) / 2 : 0

            var row = 0
            while row < drawH {
                let batchRows = min(rowsPerBatch, drawH - row)

                // Determine contiguous file region for this batch.
                // Top-down: sequential rows; bottom-up: read sequentially, process reversed.
                let batchFirstSrcRow: Int
                if topDown {
                    batchFirstSrcRow = row + vSkip
                } else {
                    batchFirstSrcRow = imageHeight - 1 - (row + vSkip + batchRows - 1)
                }

                let batchBytes = batchRows * rowStride
                let fileOffset = pixelDataOffset + batchFirstSrcRow * rowStride

                let bytesRead = fat.readBytes(clusterMap: clusterMap,
                                              clusterCount: clusterCount,
                                              fileOffset: fileOffset,
                                              into: rowBuffer,
                                              count: batchBytes)

                guard bytesRead >= batchBytes else {
                    row += batchRows
                    continue
                }

                for i in 0..<batchRows {
                    let bufRow = topDown ? i : batchRows - 1 - i
                    let rowPtr = rowBuffer + bufRow * rowStride
                    fb.write1bitRow(y: offsetY + row + i, startX: offsetX,
                                    srcData: rowPtr, srcBitOffset: srcStartX,
                                    pixelCount: drawW, invert: invert)
                }

                row += batchRows
            }
            return
        }

        for row in 0..<drawH {
            // Determine the source row index
            let srcRow: Int
            if topDown {
                srcRow = row + (imageHeight > areaH ? (imageHeight - areaH) / 2 : 0)
            } else {
                // Bottom-to-top: row 0 in display = last row in file
                let displayRow = row + (imageHeight > areaH ? (imageHeight - areaH) / 2 : 0)
                srcRow = imageHeight - 1 - displayRow
            }

            guard srcRow >= 0, srcRow < imageHeight else { continue }

            // Read the row from the file
            let fileOffset = pixelDataOffset + srcRow * rowStride
            let bytesNeeded = min(rowStride, Self.rowBufferSize)
            let bytesRead = fat.readBytes(clusterMap: clusterMap,
                                          clusterCount: clusterCount,
                                          fileOffset: fileOffset,
                                          into: rowBuffer,
                                          count: bytesNeeded)
            guard bytesRead >= bytesNeeded else { continue }

            // Decode pixels and write to framebuffer
            let destY = offsetY + row
            for col in 0..<drawW {
                let srcX = srcStartX + col
                let gray = pixelToGray(x: srcX)
                let black = ImageDither.shouldBeBlack(gray: gray, x: col, y: row)
                fb.setPixel(x: offsetX + col, y: destY, black: black)
            }
        }
    }

    // MARK: - Pixel Conversion

    /// Extract grayscale value from a pixel in the row buffer.
    @inline(__always)
    private func pixelToGray(x: Int) -> UInt8 {
        switch bitsPerPixel {
        case 24:
            let offset = x * 3
            let b = rowBuffer[offset]
            let g = rowBuffer[offset + 1]
            let r = rowBuffer[offset + 2]
            return ImageDither.rgbToGray(r: r, g: g, b: b)

        case 32:
            let offset = x * 4
            let b = rowBuffer[offset]
            let g = rowBuffer[offset + 1]
            let r = rowBuffer[offset + 2]
            return ImageDither.rgbToGray(r: r, g: g, b: b)

        case 8:
            let index = Int(rowBuffer[x])
            let palOffset = index * 4
            let b = palette[palOffset]
            let g = palette[palOffset + 1]
            let r = palette[palOffset + 2]
            return ImageDither.rgbToGray(r: r, g: g, b: b)

        case 4:
            let byteIndex = x / 2
            let nibble: UInt8
            if x & 1 == 0 {
                nibble = rowBuffer[byteIndex] >> 4
            } else {
                nibble = rowBuffer[byteIndex] & 0x0F
            }
            let palOffset = Int(nibble) * 4
            let b = palette[palOffset]
            let g = palette[palOffset + 1]
            let r = palette[palOffset + 2]
            return ImageDither.rgbToGray(r: r, g: g, b: b)

        case 1:
            let byteIndex = x / 8
            let bitIndex = 7 - (x & 7)
            let bit = (rowBuffer[byteIndex] >> bitIndex) & 1
            // 1-bit BMP: index 0 = palette[0], index 1 = palette[4]
            let palOffset = Int(bit) * 4
            let b = palette[palOffset]
            let g = palette[palOffset + 1]
            let r = palette[palOffset + 2]
            return ImageDither.rgbToGray(r: r, g: g, b: b)

        default:
            return 128
        }
    }

    // MARK: - Helpers

    @inline(__always)
    private func readU16(_ buf: UnsafeMutablePointer<UInt8>, offset: Int) -> UInt16 {
        UInt16(buf[offset]) | (UInt16(buf[offset + 1]) << 8)
    }

    @inline(__always)
    private func readU32(_ buf: UnsafeMutablePointer<UInt8>, offset: Int) -> UInt32 {
        UInt32(buf[offset])
        | (UInt32(buf[offset + 1]) << 8)
        | (UInt32(buf[offset + 2]) << 16)
        | (UInt32(buf[offset + 3]) << 24)
    }
}
