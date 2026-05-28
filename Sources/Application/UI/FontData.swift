/// 8x16 bitmap font for ASCII 0x20–0x7E (95 printable characters).
///
/// Each glyph is 16 bytes (one byte per row, MSB = leftmost pixel).
/// Compatible with Framebuffer.drawChar(glyphHeight: 16).
///
/// Based on the classic VGA/CP437 8x16 font (public domain).
enum FontData {
    static let glyphWidth = 8
    static let glyphHeight = 16
    static let firstChar: UInt8 = 0x20
    static let lastChar: UInt8 = 0x7E
    static let glyphCount = 95

    /// Raw font bitmap: 95 glyphs × 16 bytes = 1520 bytes.
    /// Index: (charCode - 0x20) * 16 + row
    static let data: StaticArray1520 = makeFont()
}

/// Fixed-size array stored in flash (DROM) — avoids heap allocation.
struct StaticArray1520 {
    // 1520 bytes stored as 190 × UInt64 = 1520 bytes
    let storage: (
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 0-7
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 8-15
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 16-23
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 24-31
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 32-39
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 40-47
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 48-55
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 56-63
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 64-71
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 72-79
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 80-87
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 88-95
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 96-103
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 104-111
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 112-119
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 120-127
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 128-135
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 136-143
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 144-151
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 152-159
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 160-167
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 168-175
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, UInt64, // 176-183
        UInt64, UInt64, UInt64, UInt64, UInt64, UInt64                  // 184-189
    )

    /// Access byte at index (bounds-unchecked for performance).
    func byte(at index: Int) -> UInt8 {
        withUnsafePointer(to: storage) { ptr in
            UnsafeRawPointer(ptr).load(fromByteOffset: index, as: UInt8.self)
        }
    }
}

/// Decoded font buffer (endian-corrected). Allocated once on first use.
nonisolated(unsafe) private var _fontBuffer: UnsafeMutablePointer<UInt8>? = nil

/// Pointer to font data for use with Framebuffer.drawChar.
/// On first call, decodes UInt64 values to bytes in big-endian order
/// (RISC-V is little-endian, so raw memory access would reverse bytes within each UInt64).
func withFontData<T>(_ body: (UnsafePointer<UInt8>) -> T) -> T {
    if _fontBuffer == nil {
        let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: 1520)
        withUnsafePointer(to: FontData.data.storage) { ptr in
            let u64ptr = UnsafeRawPointer(ptr).assumingMemoryBound(to: UInt64.self)
            for i in 0..<190 {
                let val = u64ptr[i]
                buf[i &* 8 + 0] = UInt8(truncatingIfNeeded: val >> 56)
                buf[i &* 8 + 1] = UInt8(truncatingIfNeeded: val >> 48)
                buf[i &* 8 + 2] = UInt8(truncatingIfNeeded: val >> 40)
                buf[i &* 8 + 3] = UInt8(truncatingIfNeeded: val >> 32)
                buf[i &* 8 + 4] = UInt8(truncatingIfNeeded: val >> 24)
                buf[i &* 8 + 5] = UInt8(truncatingIfNeeded: val >> 16)
                buf[i &* 8 + 6] = UInt8(truncatingIfNeeded: val >> 8)
                buf[i &* 8 + 7] = UInt8(truncatingIfNeeded: val)
            }
        }
        _fontBuffer = buf
    }
    return body(UnsafePointer(_fontBuffer!))
}

// MARK: - Font Bitmap Generation

/// Build the 8x16 font at compile time (stored in DROM).
private func makeFont() -> StaticArray1520 {
    // We construct 1520 bytes as 190 UInt64 values.
    // The font data is encoded below as hex UInt64 literals (8 bytes each = half a glyph).

    return StaticArray1520(storage: (
        // 0x20 ' ' (space)
        0x00_00_00_00_00_00_00_00, 0x00_00_00_00_00_00_00_00,
        // 0x21 '!'
        0x00_00_18_3C_3C_3C_18_18, 0x18_00_18_18_00_00_00_00,
        // 0x22 '"'
        0x00_66_66_66_24_00_00_00, 0x00_00_00_00_00_00_00_00,
        // 0x23 '#'
        0x00_00_00_6C_6C_FE_6C_6C, 0xFE_6C_6C_00_00_00_00_00,
        // 0x24 '$'
        0x18_18_7C_C6_C2_C0_7C_06, 0x06_86_C6_7C_18_18_00_00,
        // 0x25 '%'
        0x00_00_00_00_C2_C6_0C_18, 0x30_60_C6_86_00_00_00_00,
        // 0x26 '&'
        0x00_00_38_6C_6C_38_76_DC, 0xCC_CC_CC_76_00_00_00_00,
        // 0x27 '''
        0x00_30_30_30_60_00_00_00, 0x00_00_00_00_00_00_00_00,
        // 0x28 '('
        0x00_00_0C_18_30_30_30_30, 0x30_30_18_0C_00_00_00_00,
        // 0x29 ')'
        0x00_00_30_18_0C_0C_0C_0C, 0x0C_0C_18_30_00_00_00_00,
        // 0x2A '*'
        0x00_00_00_00_00_66_3C_FF, 0x3C_66_00_00_00_00_00_00,
        // 0x2B '+'
        0x00_00_00_00_00_18_18_7E, 0x18_18_00_00_00_00_00_00,
        // 0x2C ','
        0x00_00_00_00_00_00_00_00, 0x00_18_18_18_30_00_00_00,
        // 0x2D '-'
        0x00_00_00_00_00_00_00_FE, 0x00_00_00_00_00_00_00_00,
        // 0x2E '.'
        0x00_00_00_00_00_00_00_00, 0x00_00_18_18_00_00_00_00,
        // 0x2F '/'
        0x00_00_00_00_02_06_0C_18, 0x30_60_C0_80_00_00_00_00,
        // 0x30 '0'
        0x00_00_3C_66_C3_C3_DB_DB, 0xC3_C3_66_3C_00_00_00_00,
        // 0x31 '1'
        0x00_00_18_38_78_18_18_18, 0x18_18_18_7E_00_00_00_00,
        // 0x32 '2'
        0x00_00_7C_C6_06_0C_18_30, 0x60_C0_C6_FE_00_00_00_00,
        // 0x33 '3'
        0x00_00_7C_C6_06_06_3C_06, 0x06_06_C6_7C_00_00_00_00,
        // 0x34 '4'
        0x00_00_0C_1C_3C_6C_CC_FE, 0x0C_0C_0C_1E_00_00_00_00,
        // 0x35 '5'
        0x00_00_FE_C0_C0_C0_FC_06, 0x06_06_C6_7C_00_00_00_00,
        // 0x36 '6'
        0x00_00_38_60_C0_C0_FC_C6, 0xC6_C6_C6_7C_00_00_00_00,
        // 0x37 '7'
        0x00_00_FE_C6_06_06_0C_18, 0x30_30_30_30_00_00_00_00,
        // 0x38 '8'
        0x00_00_7C_C6_C6_C6_7C_C6, 0xC6_C6_C6_7C_00_00_00_00,
        // 0x39 '9'
        0x00_00_7C_C6_C6_C6_7E_06, 0x06_06_0C_78_00_00_00_00,
        // 0x3A ':'
        0x00_00_00_00_18_18_00_00, 0x00_18_18_00_00_00_00_00,
        // 0x3B ';'
        0x00_00_00_00_18_18_00_00, 0x00_18_18_30_00_00_00_00,
        // 0x3C '<'
        0x00_00_00_06_0C_18_30_60, 0x30_18_0C_06_00_00_00_00,
        // 0x3D '='
        0x00_00_00_00_00_7E_00_00, 0x7E_00_00_00_00_00_00_00,
        // 0x3E '>'
        0x00_00_00_60_30_18_0C_06, 0x0C_18_30_60_00_00_00_00,
        // 0x3F '?'
        0x00_00_7C_C6_C6_0C_18_18, 0x18_00_18_18_00_00_00_00,
        // 0x40 '@'
        0x00_00_00_7C_C6_C6_DE_DE, 0xDE_DC_C0_7C_00_00_00_00,
        // 0x41 'A'
        0x00_00_10_38_6C_C6_C6_FE, 0xC6_C6_C6_C6_00_00_00_00,
        // 0x42 'B'
        0x00_00_FC_66_66_66_7C_66, 0x66_66_66_FC_00_00_00_00,
        // 0x43 'C'
        0x00_00_3C_66_C2_C0_C0_C0, 0xC0_C2_66_3C_00_00_00_00,
        // 0x44 'D'
        0x00_00_F8_6C_66_66_66_66, 0x66_66_6C_F8_00_00_00_00,
        // 0x45 'E'
        0x00_00_FE_66_62_68_78_68, 0x60_62_66_FE_00_00_00_00,
        // 0x46 'F'
        0x00_00_FE_66_62_68_78_68, 0x60_60_60_F0_00_00_00_00,
        // 0x47 'G'
        0x00_00_3C_66_C2_C0_C0_DE, 0xC6_C6_66_3A_00_00_00_00,
        // 0x48 'H'
        0x00_00_C6_C6_C6_C6_FE_C6, 0xC6_C6_C6_C6_00_00_00_00,
        // 0x49 'I'
        0x00_00_3C_18_18_18_18_18, 0x18_18_18_3C_00_00_00_00,
        // 0x4A 'J'
        0x00_00_1E_0C_0C_0C_0C_0C, 0xCC_CC_CC_78_00_00_00_00,
        // 0x4B 'K'
        0x00_00_E6_66_66_6C_78_78, 0x6C_66_66_E6_00_00_00_00,
        // 0x4C 'L'
        0x00_00_F0_60_60_60_60_60, 0x60_62_66_FE_00_00_00_00,
        // 0x4D 'M'
        0x00_00_C6_EE_FE_FE_D6_C6, 0xC6_C6_C6_C6_00_00_00_00,
        // 0x4E 'N'
        0x00_00_C6_E6_F6_FE_DE_CE, 0xC6_C6_C6_C6_00_00_00_00,
        // 0x4F 'O'
        0x00_00_7C_C6_C6_C6_C6_C6, 0xC6_C6_C6_7C_00_00_00_00,
        // 0x50 'P'
        0x00_00_FC_66_66_66_7C_60, 0x60_60_60_F0_00_00_00_00,
        // 0x51 'Q'
        0x00_00_7C_C6_C6_C6_C6_C6, 0xC6_D6_DE_7C_0C_0E_00_00,
        // 0x52 'R'
        0x00_00_FC_66_66_66_7C_6C, 0x66_66_66_E6_00_00_00_00,
        // 0x53 'S'
        0x00_00_7C_C6_C6_60_38_0C, 0x06_C6_C6_7C_00_00_00_00,
        // 0x54 'T'
        0x00_00_FF_DB_99_18_18_18, 0x18_18_18_3C_00_00_00_00,
        // 0x55 'U'
        0x00_00_C6_C6_C6_C6_C6_C6, 0xC6_C6_C6_7C_00_00_00_00,
        // 0x56 'V'
        0x00_00_C6_C6_C6_C6_C6_C6, 0xC6_6C_38_10_00_00_00_00,
        // 0x57 'W'
        0x00_00_C6_C6_C6_C6_D6_D6, 0xD6_FE_EE_6C_00_00_00_00,
        // 0x58 'X'
        0x00_00_C6_C6_6C_7C_38_38, 0x7C_6C_C6_C6_00_00_00_00,
        // 0x59 'Y'
        0x00_00_C3_C3_C3_66_3C_18, 0x18_18_18_3C_00_00_00_00,
        // 0x5A 'Z'
        0x00_00_FE_C6_86_0C_18_30, 0x60_C2_C6_FE_00_00_00_00,
        // 0x5B '['
        0x00_00_3C_30_30_30_30_30, 0x30_30_30_3C_00_00_00_00,
        // 0x5C '\'
        0x00_00_00_80_C0_E0_70_38, 0x1C_0E_06_02_00_00_00_00,
        // 0x5D ']'
        0x00_00_3C_0C_0C_0C_0C_0C, 0x0C_0C_0C_3C_00_00_00_00,
        // 0x5E '^'
        0x10_38_6C_C6_00_00_00_00, 0x00_00_00_00_00_00_00_00,
        // 0x5F '_'
        0x00_00_00_00_00_00_00_00, 0x00_00_00_00_00_FF_00_00,
        // 0x60 '`'
        0x30_30_18_00_00_00_00_00, 0x00_00_00_00_00_00_00_00,
        // 0x61 'a'
        0x00_00_00_00_00_78_0C_7C, 0xCC_CC_CC_76_00_00_00_00,
        // 0x62 'b'
        0x00_00_E0_60_60_78_6C_66, 0x66_66_66_7C_00_00_00_00,
        // 0x63 'c'
        0x00_00_00_00_00_7C_C6_C0, 0xC0_C0_C6_7C_00_00_00_00,
        // 0x64 'd'
        0x00_00_1C_0C_0C_3C_6C_CC, 0xCC_CC_CC_76_00_00_00_00,
        // 0x65 'e'
        0x00_00_00_00_00_7C_C6_FE, 0xC0_C0_C6_7C_00_00_00_00,
        // 0x66 'f'
        0x00_00_38_6C_64_60_F0_60, 0x60_60_60_F0_00_00_00_00,
        // 0x67 'g'
        0x00_00_00_00_00_76_CC_CC, 0xCC_CC_CC_7C_0C_CC_78_00,
        // 0x68 'h'
        0x00_00_E0_60_60_6C_76_66, 0x66_66_66_E6_00_00_00_00,
        // 0x69 'i'
        0x00_00_18_18_00_38_18_18, 0x18_18_18_3C_00_00_00_00,
        // 0x6A 'j'
        0x00_00_06_06_00_0E_06_06, 0x06_06_06_06_66_66_3C_00,
        // 0x6B 'k'
        0x00_00_E0_60_60_66_6C_78, 0x78_6C_66_E6_00_00_00_00,
        // 0x6C 'l'
        0x00_00_38_18_18_18_18_18, 0x18_18_18_3C_00_00_00_00,
        // 0x6D 'm'
        0x00_00_00_00_00_E6_FF_DB, 0xDB_DB_DB_DB_00_00_00_00,
        // 0x6E 'n'
        0x00_00_00_00_00_DC_66_66, 0x66_66_66_66_00_00_00_00,
        // 0x6F 'o'
        0x00_00_00_00_00_7C_C6_C6, 0xC6_C6_C6_7C_00_00_00_00,
        // 0x70 'p'
        0x00_00_00_00_00_DC_66_66, 0x66_66_66_7C_60_60_F0_00,
        // 0x71 'q'
        0x00_00_00_00_00_76_CC_CC, 0xCC_CC_CC_7C_0C_0C_1E_00,
        // 0x72 'r'
        0x00_00_00_00_00_DC_76_66, 0x60_60_60_F0_00_00_00_00,
        // 0x73 's'
        0x00_00_00_00_00_7C_C6_60, 0x38_0C_C6_7C_00_00_00_00,
        // 0x74 't'
        0x00_00_10_30_30_FC_30_30, 0x30_30_36_1C_00_00_00_00,
        // 0x75 'u'
        0x00_00_00_00_00_CC_CC_CC, 0xCC_CC_CC_76_00_00_00_00,
        // 0x76 'v'
        0x00_00_00_00_00_C3_C3_C3, 0xC3_66_3C_18_00_00_00_00,
        // 0x77 'w'
        0x00_00_00_00_00_C6_C6_D6, 0xD6_D6_FE_6C_00_00_00_00,
        // 0x78 'x'
        0x00_00_00_00_00_C6_6C_38, 0x38_38_6C_C6_00_00_00_00,
        // 0x79 'y'
        0x00_00_00_00_00_C6_C6_C6, 0xC6_C6_C6_7E_06_0C_F8_00,
        // 0x7A 'z'
        0x00_00_00_00_00_FE_CC_18, 0x30_60_C6_FE_00_00_00_00,
        // 0x7B '{'
        0x00_00_0E_18_18_18_70_18, 0x18_18_18_0E_00_00_00_00,
        // 0x7C '|'
        0x00_00_18_18_18_18_00_18, 0x18_18_18_18_00_00_00_00,
        // 0x7D '}'
        0x00_00_70_18_18_18_0E_18, 0x18_18_18_70_00_00_00_00,
        // 0x7E '~'
        0x00_00_76_DC_00_00_00_00, 0x00_00_00_00_00_00_00_00
    ))
}
