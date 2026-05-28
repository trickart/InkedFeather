/// 8×8 Bayer ordered dithering for converting grayscale to 1-bit.
///
/// The Bayer matrix provides a threshold map: for each pixel position (x, y),
/// compare the grayscale value against the threshold at (x%8, y%8).
/// No extra row buffers are needed, making it ideal for streaming decode.
enum ImageDither {
    /// 8×8 Bayer threshold matrix, pre-scaled to 0–255 range.
    /// Stored in flash (DROM) as a compile-time constant.
    private static let bayerMatrix:
        (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
         UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
         UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
         UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
         UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
         UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
         UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
         UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
        (  0, 128,  32, 160,   8, 136,  40, 168,
         192,  64, 224,  96, 200,  72, 232, 104,
          48, 176,  16, 144,  56, 184,  24, 152,
         240, 112, 208,  80, 248, 120, 216,  88,
          12, 140,  44, 172,   4, 132,  36, 164,
         204,  76, 236, 108, 196,  68, 228, 100,
          60, 188,  28, 156,  52, 180,  20, 148,
         252, 124, 220,  92, 244, 116, 212,  84)

    /// Returns true if the pixel should be black.
    /// `gray` is 0 (black) to 255 (white).
    /// Pure black (0) and pure white (255) are preserved without dithering.
    @inline(__always)
    static func shouldBeBlack(gray: UInt8, x: Int, y: Int) -> Bool {
        if gray == 0 { return true }
        if gray == 255 { return false }
        let index = (y & 7) * 8 + (x & 7)
        let threshold = withUnsafePointer(to: bayerMatrix) { ptr in
            UnsafeRawPointer(ptr).load(fromByteOffset: index, as: UInt8.self)
        }
        return gray < threshold
    }

    /// Convert RGB to grayscale using integer-only luminance formula.
    /// Y = (R*77 + G*150 + B*29) >> 8
    @inline(__always)
    static func rgbToGray(r: UInt8, g: UInt8, b: UInt8) -> UInt8 {
        let y = UInt32(r) * 77 + UInt32(g) * 150 + UInt32(b) * 29
        return UInt8(y >> 8)
    }
}
