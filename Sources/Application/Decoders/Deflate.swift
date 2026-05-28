/// Streaming DEFLATE decompressor (RFC 1951) with zlib wrapper (RFC 1950).
///
/// Designed for row-by-row PNG decoding: the caller requests exactly N bytes
/// per call, and the decompressor suspends/resumes across calls. All state
/// is stored in struct fields (explicit state machine, no recursion).
///
/// When the input buffer is exhausted mid-operation, `needsInput` is set
/// and `inflate()` returns with partial output. The caller should refill
/// the input via `provideInput()` and call `inflate()` again to continue.
///
/// Memory usage:
///   - 32 KB sliding window (LZ77 back-references)
///   - 4 KB input buffer (compressed data from SD card)
///   - 4 KB Huffman lookup tables (2 × 512 entries)
struct Deflate {
    // MARK: - Constants

    static let windowSize = 32768       // 32 KB
    static let windowMask = 32767
    static let inputBufferSize = 4096   // 4 KB
    static let primaryBits = 9          // primary Huffman lookup bits
    static let primarySize = 1 << 9     // 512 entries

    /// Maximum code lengths per DEFLATE spec.
    static let maxLitLenCodes = 286
    static let maxDistCodes = 30
    static let maxCodeLenCodes = 19

    // MARK: - Sliding Window

    private let window: UnsafeMutablePointer<UInt8>
    private var windowPos: Int = 0

    // MARK: - Input Buffer

    private let inputBuffer: UnsafeMutablePointer<UInt8>
    private var inputPos: Int = 0
    private var inputEnd: Int = 0

    // MARK: - Bit Reader

    private var bitBuffer: UInt32 = 0
    private var bitsAvailable: Int = 0

    // MARK: - Huffman Tables

    private let litLenTable: UnsafeMutablePointer<UInt32>
    private let distTable: UnsafeMutablePointer<UInt32>

    static let tableAlloc = 2048  // 512 primary + 1536 secondary max

    /// Scratch buffer for code lengths during Huffman table construction.
    /// Max needed: 286 (lit/len) + 30 (dist) = 316 bytes.
    private let codeLenBuf: UnsafeMutablePointer<UInt8>
    static let codeLenBufSize = 320

    // MARK: - State Machine
    //
    // The decompressor is a flat state machine so it can suspend at any point
    // where the input buffer may run dry (ensureBits failure) and resume
    // after the caller refills the buffer.

    private enum State: UInt8 {
        case zlibHeader = 0      // need to read 2-byte zlib header
        case blockHeader = 1     // need to read 3-bit block header
        case rawHeader = 2       // need to read uncompressed block length
        case rawData = 3         // reading uncompressed block bytes
        case dynamicTables = 4   // reading dynamic Huffman table definitions
        case symbol = 5          // decoding next lit/len symbol
        case lengthExtra = 6     // reading extra bits for length
        case distSymbol = 7      // decoding distance symbol
        case distExtra = 8       // reading extra bits for distance
        case matchCopy = 9       // copying match bytes to output
        case done = 10           // stream ended
    }

    private var state: State = .zlibHeader
    private var finalBlock: Bool = false

    // Uncompressed block
    private var rawRemaining: Int = 0

    // Match decode in progress
    private var pendingLenCode: Int = 0  // length symbol (257–285)
    private var pendingLength: Int = 0   // decoded length value
    private var pendingDistCode: Int = 0 // distance symbol (0–29)
    private var matchDist: Int = 0
    private var matchLength: Int = 0

    // MARK: - Error / Input State

    private(set) var error: Bool = false
    /// Set when inflate needs more input data. Caller should call
    /// `provideInput()` and then resume `inflate()`.
    private(set) var needsInput: Bool = false

    /// Force error state (used by caller to break out of stuck loops).
    mutating func setError() { error = true }

    // MARK: - Init

    init() {
        window = .allocate(capacity: Self.windowSize)
        inputBuffer = .allocate(capacity: Self.inputBufferSize)
        litLenTable = .allocate(capacity: Self.tableAlloc)
        distTable = .allocate(capacity: Self.tableAlloc)
        codeLenBuf = .allocate(capacity: Self.codeLenBufSize)
    }

    /// Deallocate all buffers.
    mutating func deallocateBuffers() {
        window.deallocate()
        inputBuffer.deallocate()
        litLenTable.deallocate()
        distTable.deallocate()
        codeLenBuf.deallocate()
    }

    // MARK: - Reset

    mutating func reset() {
        windowPos = 0
        inputPos = 0
        inputEnd = 0
        bitBuffer = 0
        bitsAvailable = 0
        state = .zlibHeader
        finalBlock = false
        rawRemaining = 0
        pendingLenCode = 0
        pendingLength = 0
        pendingDistCode = 0
        matchDist = 0
        matchLength = 0
        error = false
        needsInput = false
    }

    // MARK: - Input Management

    var inputBufferPtr: UnsafeMutablePointer<UInt8> { inputBuffer }
    var inputBufferCapacity: Int { Self.inputBufferSize }

    /// Tell deflate that `count` bytes have been written into `inputBufferPtr`.
    mutating func provideInput(count: Int) {
        inputPos = 0
        inputEnd = count
        needsInput = false
    }

    // MARK: - Public API

    /// Decompress up to `count` bytes into `output`.
    /// Returns the number of bytes actually produced. Returns less than
    /// `count` when:
    ///   - `needsInput` is true  → caller should refill and retry
    ///   - `error` is true       → corrupt stream, stop
    ///   - stream ended normally  → check `state == .done`
    mutating func inflate(into output: UnsafeMutablePointer<UInt8>, count: Int) -> Int {
        if error { return 0 }

        var produced = 0
        var loopCount = 0

        while produced < count {
            loopCount += 1
            if loopCount > 100_000 {
                error = true
                return produced
            }
            switch state {
            // ----------------------------------------------------------
            case .zlibHeader:
                guard ensureBits(16) else { return produced }
                let cmf = bitBuffer & 0xFF
                let flg = (bitBuffer >> 8) & 0xFF
                dropBits(16)
                if cmf & 0x0F != 8 { error = true; return produced }
                if (cmf * 256 + flg) % 31 != 0 { error = true; return produced }
                if flg & 0x20 != 0 { error = true; return produced }
                state = .blockHeader

            // ----------------------------------------------------------
            case .blockHeader:
                if finalBlock {
                    state = .done
                    return produced
                }
                guard ensureBits(3) else { return produced }
                finalBlock = (bitBuffer & 1) != 0
                let btype = (bitBuffer >> 1) & 3
                dropBits(3)

                switch btype {
                case 0:
                    state = .rawHeader
                case 1:
                    buildFixedTables()
                    state = .symbol
                case 2:
                    state = .dynamicTables
                default:
                    error = true
                    return produced
                }

            // ----------------------------------------------------------
            case .rawHeader:
                // Align to byte boundary, then read LEN / NLEN
                dropBits(bitsAvailable & 7)
                guard ensureBits(32) else { return produced }
                let len = Int(bitBuffer & 0xFFFF)
                let nlen = Int((bitBuffer >> 16) & 0xFFFF)
                dropBits(32)
                if len != (~nlen & 0xFFFF) { error = true; return produced }
                rawRemaining = len
                state = .rawData

            // ----------------------------------------------------------
            case .rawData:
                while rawRemaining > 0 && produced < count {
                    guard let byte = readByte() else { return produced }
                    output[produced] = byte
                    window[windowPos] = byte
                    windowPos = (windowPos + 1) & Self.windowMask
                    produced += 1
                    rawRemaining -= 1
                }
                if rawRemaining == 0 {
                    state = .blockHeader
                }

            // ----------------------------------------------------------
            case .dynamicTables:
                // Save bit/input state so we can retry from scratch if
                // input runs out partway through table decoding.
                let savedBB = bitBuffer
                let savedBA = bitsAvailable
                let savedIP = inputPos
                if !decodeDynamicTables() {
                    if needsInput {
                        bitBuffer = savedBB
                        bitsAvailable = savedBA
                        inputPos = savedIP
                        return produced
                    }
                    error = true
                    return produced
                }
                state = .symbol

            // ----------------------------------------------------------
            case .symbol:
                // Decode next literal/length symbol.
                // ensureBits(15) makes decodeSymbol atomic: max DEFLATE
                // code is 15 bits, and we never split a symbol across refills.
                let sym = decodeSymbol(table: litLenTable)
                if sym < 0 {
                    if needsInput { return produced }
                    error = true; return produced
                }

                if sym < 256 {
                    // Literal byte
                    let byte = UInt8(truncatingIfNeeded: sym)
                    output[produced] = byte
                    window[windowPos] = byte
                    windowPos = (windowPos + 1) & Self.windowMask
                    produced += 1
                } else if sym == 256 {
                    // End of block
                    state = .blockHeader
                } else {
                    // Length code — transition to extra-bits state
                    pendingLenCode = sym
                    state = .lengthExtra
                }

            // ----------------------------------------------------------
            case .lengthExtra:
                let length = decodeLengthExtra(pendingLenCode)
                if length < 0 {
                    if needsInput { return produced }
                    error = true; return produced
                }
                pendingLength = length
                state = .distSymbol

            // ----------------------------------------------------------
            case .distSymbol:
                let sym = decodeSymbol(table: distTable)
                if sym < 0 {
                    if needsInput { return produced }
                    error = true; return produced
                }
                if sym >= 30 { error = true; return produced }
                pendingDistCode = sym
                state = .distExtra

            // ----------------------------------------------------------
            case .distExtra:
                let dist = decodeDistExtra(pendingDistCode)
                if dist < 0 {
                    if needsInput { return produced }
                    error = true; return produced
                }
                matchDist = dist
                matchLength = pendingLength
                state = .matchCopy

            // ----------------------------------------------------------
            case .matchCopy:
                while matchLength > 0 && produced < count {
                    let srcPos = (windowPos - matchDist + Self.windowSize) & Self.windowMask
                    let byte = window[srcPos]
                    output[produced] = byte
                    window[windowPos] = byte
                    windowPos = (windowPos + 1) & Self.windowMask
                    produced += 1
                    matchLength -= 1
                }
                if matchLength == 0 {
                    state = .symbol
                }

            // ----------------------------------------------------------
            case .done:
                return produced
            }
        }

        return produced
    }

    // MARK: - Huffman Symbol Decoding

    /// Decode one symbol from the given Huffman table.
    /// Ensures 15 bits upfront so the decode is atomic (no partial consumption).
    /// Returns -1 on failure (check `needsInput` to distinguish input starvation
    /// from actual error).
    private mutating func decodeSymbol(table: UnsafeMutablePointer<UInt32>) -> Int {
        // Max DEFLATE code = 15 bits. Ensuring 15 bits makes this fully atomic:
        // after this point we only consume bits, never request more.
        guard ensureBits(15) else { return -1 }

        let index = Int(bitBuffer & UInt32(Self.primarySize - 1))
        let entry = table[index]

        if entry & 0x8000_0000 == 0 {
            // Primary hit
            let len = Int((entry >> 16) & 0xF)
            if len == 0 { return -1 }
            dropBits(len)
            return Int(entry & 0xFFFF)
        } else {
            // Secondary table lookup
            let primaryLen = Int((entry >> 16) & 0xF)
            dropBits(primaryLen)
            let secondaryOffset = Int(entry & 0x7FFF)
            let extraBits = Int((entry >> 20) & 0xF)
            // We ensured 15 bits above and consumed at most primaryLen (≤9),
            // so we have at least 6 bits remaining — enough for extraBits (≤6).
            let idx2 = Int(bitBuffer & ((1 << extraBits) - 1))
            let entry2 = table[secondaryOffset + idx2]
            let len2 = Int((entry2 >> 16) & 0xF)
            dropBits(len2)
            return Int(entry2 & 0xFFFF)
        }
    }

    // MARK: - Length / Distance Extra Bits

    /// Extra bits for length codes 257–285.
    private static let lengthExtraBits:
        (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
         UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
         UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
         UInt8, UInt8, UInt8, UInt8, UInt8) =
        (0, 0, 0, 0, 0, 0, 0, 0,
         1, 1, 1, 1, 2, 2, 2, 2,
         3, 3, 3, 3, 4, 4, 4, 4,
         5, 5, 5, 5, 0)

    /// Base length for length codes 257–285.
    private static let lengthBase:
        (UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16,
         UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16,
         UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16,
         UInt16, UInt16, UInt16, UInt16, UInt16) =
        (3, 4, 5, 6, 7, 8, 9, 10,
         11, 13, 15, 17, 19, 23, 27, 31,
         35, 43, 51, 59, 67, 83, 99, 115,
         131, 163, 195, 227, 258)

    /// Extra bits for distance codes 0–29.
    private static let distExtraBits:
        (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
         UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
         UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
         UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
        (0, 0, 0, 0, 1, 1, 2, 2,
         3, 3, 4, 4, 5, 5, 6, 6,
         7, 7, 8, 8, 9, 9, 10, 10,
         11, 11, 12, 12, 13, 13)

    /// Base distance for distance codes 0–29.
    private static let distBase:
        (UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16,
         UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16,
         UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16,
         UInt16, UInt16, UInt16, UInt16, UInt16, UInt16) =
        (1, 2, 3, 4, 5, 7, 9, 13,
         17, 25, 33, 49, 65, 97, 129, 193,
         257, 385, 513, 769, 1025, 1537, 2049, 3073,
         4097, 6145, 8193, 12289, 16385, 24577)

    /// Read extra bits for a length code. Returns -1 if not enough input.
    /// This is atomic: ensureBits first, then consume.
    private mutating func decodeLengthExtra(_ sym: Int) -> Int {
        let idx = sym - 257
        if idx < 0 || idx >= 29 { return -1 }
        let base = withUnsafePointer(to: Self.lengthBase) { ptr in
            UnsafeRawPointer(ptr).load(fromByteOffset: idx &* MemoryLayout<UInt16>.stride, as: UInt16.self)
        }
        let extra = withUnsafePointer(to: Self.lengthExtraBits) { ptr in
            UnsafeRawPointer(ptr).load(fromByteOffset: idx, as: UInt8.self)
        }
        if extra > 0 {
            guard ensureBits(Int(extra)) else { return -1 }
            let add = Int(bitBuffer & ((1 << extra) - 1))
            dropBits(Int(extra))
            return Int(base) + add
        }
        return Int(base)
    }

    /// Read extra bits for a distance code. Returns -1 if not enough input.
    private mutating func decodeDistExtra(_ sym: Int) -> Int {
        if sym < 0 || sym >= 30 { return -1 }
        let base = withUnsafePointer(to: Self.distBase) { ptr in
            UnsafeRawPointer(ptr).load(fromByteOffset: sym &* MemoryLayout<UInt16>.stride, as: UInt16.self)
        }
        let extra = withUnsafePointer(to: Self.distExtraBits) { ptr in
            UnsafeRawPointer(ptr).load(fromByteOffset: sym, as: UInt8.self)
        }
        if extra > 0 {
            guard ensureBits(Int(extra)) else { return -1 }
            let add = Int(bitBuffer & ((1 << extra) - 1))
            dropBits(Int(extra))
            return Int(base) + add
        }
        return Int(base)
    }

    // MARK: - Fixed Huffman Tables

    private mutating func buildFixedTables() {
        for i in 0..<144   { codeLenBuf[i] = 8 }
        for i in 144..<256 { codeLenBuf[i] = 9 }
        for i in 256..<280 { codeLenBuf[i] = 7 }
        for i in 280..<288 { codeLenBuf[i] = 8 }
        buildHuffmanTable(table: litLenTable, codeLengths: codeLenBuf, count: 288)

        for i in 0..<32 { codeLenBuf[i] = 5 }
        buildHuffmanTable(table: distTable, codeLengths: codeLenBuf, count: 32)
    }

    // MARK: - Dynamic Huffman Tables

    private static let codeLenOrder:
        (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
         UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
         UInt8, UInt8, UInt8) =
        (16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15)

    /// Decode dynamic Huffman tables. Returns false on failure.
    /// If `needsInput` is set, the caller should refill and retry from the
    /// `.dynamicTables` state (the tables will be re-decoded from scratch,
    /// which is safe because no output has been emitted yet).
    private mutating func decodeDynamicTables() -> Bool {
        guard ensureBits(14) else { return false }
        let hlit = Int(bitBuffer & 0x1F) + 257
        let hdist = Int((bitBuffer >> 5) & 0x1F) + 1
        let hclen = Int((bitBuffer >> 10) & 0xF) + 4
        dropBits(14)

        if hlit > Self.maxLitLenCodes || hdist > Self.maxDistCodes { return false }

        // Read code length code lengths (use first 19 bytes of codeLenBuf)
        for i in 0..<Self.maxCodeLenCodes { codeLenBuf[i] = 0 }

        for i in 0..<hclen {
            guard ensureBits(3) else { return false }
            let order = withUnsafePointer(to: Self.codeLenOrder) { ptr in
                UnsafeRawPointer(ptr).load(fromByteOffset: i, as: UInt8.self)
            }
            codeLenBuf[Int(order)] = UInt8(bitBuffer & 7)
            dropBits(3)
        }

        // Build code length Huffman table (reuse distTable temporarily)
        buildHuffmanTable(table: distTable, codeLengths: codeLenBuf, count: Self.maxCodeLenCodes)

        // Decode literal/length + distance code lengths into codeLenBuf
        let totalCodes = hlit + hdist
        if totalCodes > Self.codeLenBufSize { return false }
        for i in 0..<totalCodes { codeLenBuf[i] = 0 }

        var i = 0
        while i < totalCodes {
            let sym = decodeSymbol(table: distTable)
            if sym < 0 { return false }

            if sym < 16 {
                codeLenBuf[i] = UInt8(sym)
                i += 1
            } else if sym == 16 {
                guard ensureBits(2), i > 0 else { return false }
                let repeatCount = Int(bitBuffer & 3) + 3
                dropBits(2)
                let prev = codeLenBuf[i - 1]
                for _ in 0..<repeatCount {
                    if i >= totalCodes { break }
                    codeLenBuf[i] = prev
                    i += 1
                }
            } else if sym == 17 {
                guard ensureBits(3) else { return false }
                let repeatCount = Int(bitBuffer & 7) + 3
                dropBits(3)
                for _ in 0..<repeatCount {
                    if i >= totalCodes { break }
                    codeLenBuf[i] = 0
                    i += 1
                }
            } else if sym == 18 {
                guard ensureBits(7) else { return false }
                let repeatCount = Int(bitBuffer & 0x7F) + 11
                dropBits(7)
                for _ in 0..<repeatCount {
                    if i >= totalCodes { break }
                    codeLenBuf[i] = 0
                    i += 1
                }
            } else {
                return false
            }
        }

        buildHuffmanTable(table: litLenTable, codeLengths: codeLenBuf, count: hlit)
        buildHuffmanTable(table: distTable, codeLengths: codeLenBuf.advanced(by: hlit), count: hdist)

        return true
    }

    // MARK: - Huffman Table Builder

    /// Build a two-level Huffman lookup table using a two-pass approach.
    ///
    /// Pass 1: Determine the max secondary bits needed per primary prefix.
    /// Pass 2: Allocate correctly-sized secondary tables and fill all entries.
    ///
    /// This ensures that when multiple codes share the same 9-bit primary
    /// prefix but have different lengths, the secondary table is large enough
    /// for the longest code.
    private func buildHuffmanTable(
        table: UnsafeMutablePointer<UInt32>,
        codeLengths: UnsafeMutablePointer<UInt8>,
        count: Int
    ) {
        let maxBits = 15

        for i in 0..<Self.primarySize {
            table[i] = 0
        }

        // Count code lengths
        var blCount = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        for i in 0..<count {
            let len = Int(codeLengths[i])
            if len > 0 && len <= maxBits {
                withUnsafeMutablePointer(to: &blCount) { ptr in
                    UnsafeMutableRawPointer(ptr)
                        .assumingMemoryBound(to: Int.self)[len] += 1
                }
            }
        }

        // Compute first code for each length (RFC 1951 §3.2.2)
        var nextCode: (UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32,
                        UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32) =
            (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        var code: UInt32 = 0
        for bits in 1...maxBits {
            let blPrev = withUnsafePointer(to: blCount) { ptr in
                UnsafeRawPointer(ptr).load(fromByteOffset: (bits - 1) * MemoryLayout<Int>.stride, as: Int.self)
            }
            code = (code + UInt32(blPrev)) << 1
            withUnsafeMutablePointer(to: &nextCode) { ptr in
                UnsafeMutableRawPointer(ptr)
                    .storeBytes(of: code, toByteOffset: bits * MemoryLayout<UInt32>.stride, as: UInt32.self)
            }
        }

        // Save nextCode for the second pass
        let savedNextCode = nextCode

        // ---- Pass 1: find max secondary bits per primary prefix ----
        // Temporarily store max secondaryBits in primary table entries.

        for sym in 0..<count {
            let len = Int(codeLengths[sym])
            if len == 0 { continue }

            var symCode: UInt32 = 0
            withUnsafeMutablePointer(to: &nextCode) { ptr in
                let p = UnsafeMutableRawPointer(ptr)
                    .assumingMemoryBound(to: UInt32.self)
                symCode = p[len]
                p[len] = symCode + 1
            }

            if len <= Self.primaryBits { continue }

            // Reverse bits to get primary prefix
            var reversed: UInt32 = 0
            for b in 0..<len {
                reversed |= ((symCode >> b) & 1) << (len - 1 - b)
            }
            let prefix = Int(reversed & UInt32(Self.primarySize - 1))
            let secBits = UInt32(len - Self.primaryBits)
            if secBits > table[prefix] {
                table[prefix] = secBits
            }
        }

        // Allocate secondary tables based on the max sizes found
        var secondaryOffset = Self.primarySize
        for prefix in 0..<Self.primarySize {
            let maxSecBits = Int(table[prefix])
            if maxSecBits > 0 {
                let size = 1 << maxSecBits
                let entry = UInt32(secondaryOffset) | 0x8000_0000
                    | (UInt32(Self.primaryBits) << 16)
                    | (UInt32(maxSecBits) << 20)
                table[prefix] = entry
                for j in 0..<size {
                    if secondaryOffset + j < Self.tableAlloc {
                        table[secondaryOffset + j] = 0
                    }
                }
                secondaryOffset += size
            } else {
                table[prefix] = 0
            }
        }

        // ---- Pass 2: fill primary and secondary entries ----
        nextCode = savedNextCode

        for sym in 0..<count {
            let len = Int(codeLengths[sym])
            if len == 0 { continue }

            var symCode: UInt32 = 0
            withUnsafeMutablePointer(to: &nextCode) { ptr in
                let p = UnsafeMutableRawPointer(ptr)
                    .assumingMemoryBound(to: UInt32.self)
                symCode = p[len]
                p[len] = symCode + 1
            }

            var reversed: UInt32 = 0
            for b in 0..<len {
                reversed |= ((symCode >> b) & 1) << (len - 1 - b)
            }

            if len <= Self.primaryBits {
                // Fill primary table entries
                let entry = UInt32(sym) | (UInt32(len) << 16)
                let step = 1 << len
                var idx = Int(reversed)
                while idx < Self.primarySize {
                    table[idx] = entry
                    idx += step
                }
            } else {
                // Fill secondary table entry
                let primaryPrefix = Int(reversed & UInt32(Self.primarySize - 1))
                let primEntry = table[primaryPrefix]
                let secOffset = Int(primEntry & 0x7FFF)
                let secBits = Int((primEntry >> 20) & 0xF)

                let secondaryBits = len - Self.primaryBits
                let secondaryKey = Int(reversed >> Self.primaryBits)

                let secEntry = UInt32(sym) | (UInt32(secondaryBits) << 16)
                let secStep = 1 << secondaryBits
                var idx = secondaryKey
                while idx < (1 << secBits) {
                    if secOffset + idx < Self.tableAlloc {
                        table[secOffset + idx] = secEntry
                    }
                    idx += secStep
                }
            }
        }
    }

    // MARK: - Bit Reader

    @inline(__always)
    private mutating func ensureBits(_ n: Int) -> Bool {
        while bitsAvailable < n {
            guard let byte = readByte() else { return false }
            bitBuffer |= UInt32(byte) << bitsAvailable
            bitsAvailable += 8
        }
        return true
    }

    @inline(__always)
    private mutating func dropBits(_ n: Int) {
        bitBuffer >>= n
        bitsAvailable -= n
    }

    // MARK: - Input Reading

    @inline(__always)
    private mutating func readByte() -> UInt8? {
        if inputPos >= inputEnd {
            needsInput = true
            return nil
        }
        let byte = inputBuffer[inputPos]
        inputPos += 1
        return byte
    }
}
