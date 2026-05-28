/// 1bpp framebuffer for the GDEY0426T82 panel (480×800 logical).
///
/// The buffer is laid out in the panel's *native* byte order — 800 source
/// pixels per row × 480 gate rows, MSB-first within each byte — so it can
/// be streamed to RAM 0x24 with no per-pixel transform on the hot path.
/// Logical (x, y) input coordinates are mapped to native coordinates on
/// the way in instead. With `rotated == true` the logical frame is
/// portrait 480×800 and the mapping transposes axes so the panel's source
/// axis runs top-to-bottom of the portrait view and its gate axis runs
/// left-to-right; with `rotated == false` the frame is the native 800×480
/// landscape and the mapping is the identity.
///
/// Bit semantics match the SSD1677 RAM[B/W] register: bit value `1` is
/// white, `0` is black. The buffer is initialized to all-white.
struct Framebuffer {
    /// Native panel dimensions (long axis = source = 800).
    static let nativeWidth = 800
    static let nativeHeight = 480
    static let bytesPerRow = nativeWidth / 8   // 100
    static let bufferBytes = bytesPerRow * nativeHeight  // 48000

    let width: Int
    let height: Int
    let rotated: Bool
    private let buffer: UnsafeMutablePointer<UInt8>

    init(rotated: Bool) {
        self.rotated = rotated
        self.width = rotated ? Self.nativeHeight : Self.nativeWidth
        self.height = rotated ? Self.nativeWidth : Self.nativeHeight
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: Self.bufferBytes)
        for i in 0..<Self.bufferBytes { buf[i] = 0xFF }
        self.buffer = buf
    }

    func clear() {
        for i in 0..<Self.bufferBytes { buffer[i] = 0xFF }
    }

    // MARK: - Coordinate mapping

    /// Map logical (x, y) to native (nx, ny). Axis transpose when rotated.
    @inline(__always)
    private func toNative(_ x: Int, _ y: Int) -> (nx: Int, ny: Int) {
        if rotated {
            return (y, x)
        } else {
            return (x, y)
        }
    }

    @inline(__always)
    private func writeNativeBit(nx: Int, ny: Int, black: Bool) {
        let off = ny &* Self.bytesPerRow &+ (nx >> 3)
        let mask: UInt8 = 1 << UInt8(7 - (nx & 7))
        if black {
            buffer[off] &= ~mask
        } else {
            buffer[off] |= mask
        }
    }

    // MARK: - Primitives

    func setPixel(x: Int, y: Int, black: Bool) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        let (nx, ny) = toNative(x, y)
        writeNativeBit(nx: nx, ny: ny, black: black)
    }

    func drawRect(x: Int, y: Int, w: Int, h: Int, black: Bool) {
        let x0 = max(0, x)
        let y0 = max(0, y)
        let x1 = min(width, x &+ w)
        let y1 = min(height, y &+ h)
        guard x0 < x1, y0 < y1 else { return }
        for yy in y0..<y1 {
            for xx in x0..<x1 {
                let (nx, ny) = toNative(xx, yy)
                writeNativeBit(nx: nx, ny: ny, black: black)
            }
        }
    }

    func drawRectOutline(x: Int, y: Int, w: Int, h: Int, black: Bool) {
        guard w > 0, h > 0 else { return }
        drawRect(x: x, y: y, w: w, h: 1, black: black)
        if h > 1 {
            drawRect(x: x, y: y &+ h &- 1, w: w, h: 1, black: black)
        }
        if h > 2 {
            drawRect(x: x, y: y &+ 1, w: 1, h: h &- 2, black: black)
            if w > 1 {
                drawRect(x: x &+ w &- 1, y: y &+ 1, w: 1, h: h &- 2, black: black)
            }
        }
    }

    // MARK: - Glyphs

    /// Draw a 1bpp glyph (MSB-first per row) at logical (x, y).
    /// `bit == 1` pixels become black; `bit == 0` pixels are left as-is.
    func drawGlyph(x: Int, y: Int,
                   glyphData: UnsafePointer<UInt8>,
                   glyphWidth: Int, glyphHeight: Int,
                   bytesPerRow: Int) {
        for row in 0..<glyphHeight {
            let rowPtr = glyphData + row &* bytesPerRow
            let ly = y &+ row
            if ly < 0 || ly >= height { continue }
            for col in 0..<glyphWidth {
                let byte = rowPtr[col >> 3]
                if (byte >> UInt8(7 - (col & 7))) & 1 == 0 { continue }
                let lx = x &+ col
                if lx < 0 || lx >= width { continue }
                let (nx, ny) = toNative(lx, ly)
                writeNativeBit(nx: nx, ny: ny, black: true)
            }
        }
    }

    /// Draw an ASCII glyph (8 px wide, `glyphHeight` rows) scaled `scale` times.
    /// Falls back to glyph 0 when the character is outside 0x20..0x7E.
    func drawCharScaled(x: Int, y: Int, char: UInt8,
                        fontData: UnsafePointer<UInt8>,
                        glyphHeight: Int, scale: Int,
                        black: Bool = true) {
        let firstChar: UInt8 = 0x20
        let lastChar: UInt8 = 0x7E
        let idx = (char >= firstChar && char <= lastChar) ? Int(char &- firstChar) : 0
        let glyph = fontData + idx &* glyphHeight
        for row in 0..<glyphHeight {
            let byte = glyph[row]
            for col in 0..<8 {
                if (byte >> UInt8(7 - col)) & 1 == 0 { continue }
                let baseX = x &+ col &* scale
                let baseY = y &+ row &* scale
                for dy in 0..<scale {
                    let ly = baseY &+ dy
                    if ly < 0 || ly >= height { continue }
                    for dx in 0..<scale {
                        let lx = baseX &+ dx
                        if lx < 0 || lx >= width { continue }
                        let (nx, ny) = toNative(lx, ly)
                        writeNativeBit(nx: nx, ny: ny, black: black)
                    }
                }
            }
        }
    }

    func drawStringScaled(x: Int, y: Int, text: StaticString,
                          fontData: UnsafePointer<UInt8>,
                          glyphHeight: Int, scale: Int,
                          black: Bool = true) {
        text.withUTF8Buffer { utf8 in
            var cx = x
            let advance = 8 &* scale
            for c in utf8 {
                drawCharScaled(x: cx, y: y, char: c,
                               fontData: fontData,
                               glyphHeight: glyphHeight,
                               scale: scale, black: black)
                cx &+= advance
            }
        }
    }

    // MARK: - Bulk paths

    /// Blit raw bytes into the native buffer at `offset`. Used by content
    /// already prepared in native packing (e.g. the boot logo).
    func copyToNativeBuffer(from src: UnsafePointer<UInt8>,
                            offset: Int, count: Int) {
        let dst = buffer + offset
        for i in 0..<count { dst[i] = src[i] }
    }

    /// Draw a horizontal row of 1bpp source pixels at logical (startX, y),
    /// fully writing each destination pixel (no transparency). After the
    /// optional invert, source bit `1` = white, `0` = black — matching the
    /// BMP convention used by the decoder.
    func write1bitRow(y: Int, startX: Int,
                      srcData: UnsafePointer<UInt8>,
                      srcBitOffset: Int, pixelCount: Int,
                      invert: Bool) {
        if y < 0 || y >= height { return }
        for i in 0..<pixelCount {
            let lx = startX &+ i
            if lx < 0 || lx >= width { continue }
            let bitIdx = srcBitOffset &+ i
            let byte = srcData[bitIdx >> 3]
            var bit = (byte >> UInt8(7 - (bitIdx & 7))) & 1
            if invert { bit ^= 1 }
            let (nx, ny) = toNative(lx, y)
            writeNativeBit(nx: nx, ny: ny, black: bit == 0)
        }
    }

    func withBuffer(_ body: (UnsafePointer<UInt8>) -> Void) {
        body(UnsafePointer(buffer))
    }
}
