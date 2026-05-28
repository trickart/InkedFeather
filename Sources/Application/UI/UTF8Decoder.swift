/// Stateless UTF-8 decoder for bare-metal use.
///
/// Decodes one Unicode code point at a time from a byte buffer.
/// Invalid sequences produce U+FFFD and consume one byte.
enum UTF8Decoder {
    /// Decode one code point starting at `pos` in `buffer`.
    /// - Returns: `(codePoint, bytesConsumed)`
    static func decode(_ buffer: UnsafePointer<UInt8>, at pos: Int,
                       length: Int) -> (UInt32, Int) {
        guard pos < length else { return (0xFFFD, 0) }

        let b0 = UInt32(buffer[pos])

        // 1-byte: 0xxxxxxx
        if b0 < 0x80 {
            return (b0, 1)
        }

        // 2-byte: 110xxxxx 10xxxxxx
        if b0 & 0xE0 == 0xC0 {
            guard pos + 1 < length else { return (0xFFFD, 1) }
            let b1 = UInt32(buffer[pos + 1])
            guard b1 & 0xC0 == 0x80 else { return (0xFFFD, 1) }
            let cp = (b0 & 0x1F) << 6 | (b1 & 0x3F)
            if cp < 0x80 { return (0xFFFD, 1) }  // overlong
            return (cp, 2)
        }

        // 3-byte: 1110xxxx 10xxxxxx 10xxxxxx
        if b0 & 0xF0 == 0xE0 {
            guard pos + 2 < length else { return (0xFFFD, 1) }
            let b1 = UInt32(buffer[pos + 1])
            let b2 = UInt32(buffer[pos + 2])
            guard b1 & 0xC0 == 0x80 && b2 & 0xC0 == 0x80 else { return (0xFFFD, 1) }
            let cp = (b0 & 0x0F) << 12 | (b1 & 0x3F) << 6 | (b2 & 0x3F)
            if cp < 0x800 { return (0xFFFD, 1) }  // overlong
            if cp >= 0xD800 && cp <= 0xDFFF { return (0xFFFD, 1) }  // surrogate
            return (cp, 3)
        }

        // 4-byte: 11110xxx 10xxxxxx 10xxxxxx 10xxxxxx
        if b0 & 0xF8 == 0xF0 {
            guard pos + 3 < length else { return (0xFFFD, 1) }
            let b1 = UInt32(buffer[pos + 1])
            let b2 = UInt32(buffer[pos + 2])
            let b3 = UInt32(buffer[pos + 3])
            guard b1 & 0xC0 == 0x80 && b2 & 0xC0 == 0x80
                  && b3 & 0xC0 == 0x80 else { return (0xFFFD, 1) }
            let cp = (b0 & 0x07) << 18 | (b1 & 0x3F) << 12
                   | (b2 & 0x3F) << 6 | (b3 & 0x3F)
            if cp < 0x10000 || cp > 0x10FFFF { return (0xFFFD, 1) }
            return (cp, 4)
        }

        // Invalid lead byte
        return (0xFFFD, 1)
    }
}
