/// Text viewer for displaying .txt file contents on the e-ink display.
///
/// Uses a ring buffer to hold line offsets for a sliding window around
/// the current scroll position, enabling arbitrarily large files with
/// fixed ~7 KB of heap.  Checkpoints recorded every 256 lines allow
/// fast backward navigation.  Resume state is persisted to SD card.
struct TextViewer {
    // MARK: - Display Constants (ASCII fallback defaults)

    static let headerHeight = 48
    static let separatorHeight = 2
    static let contentTop = headerHeight + separatorHeight  // 50
    static let leftMargin = 8
    static let rightMargin = 8
    static let lineHeight = 34  // 32px char + 2px spacing
    static let charsPerLine = (UIRenderer.screenWidth - leftMargin - rightMargin)
                              / UIRenderer.charWidth  // 29
    static let linesPerPage = (UIRenderer.screenHeight - contentTop) / lineHeight  // 22

    /// Ring buffer size (must be power of 2).
    static let ringSize = 256
    static let ringMask = ringSize - 1

    /// Checkpoint interval — one checkpoint every `ringSize` lines.
    static let checkpointInterval = 256
    static let maxCheckpoints = 64

    /// Maximum cluster map entries (supports ~1 MB with 4 KB clusters).
    static let maxClusters = 256

    /// Buffer size for streaming scan and on-demand page reads.
    static let ioBufferSize = 4096

    /// Maximum resume entries persisted to SD card.
    static let maxResumeEntries = 16
    /// Per-entry size in READHIST.DAT (16 B header + 6 × 8 B checkpoints).
    static let resumeEntrySize = 64
    /// Number of checkpoint slots persisted per entry.
    static let resumeCheckpointSlots = 6

    // MARK: - Effective Layout (updated when BitmapFont is configured)

    private(set) var effectiveCharWidth: Int = UIRenderer.charWidth       // 16
    private(set) var effectiveLineHeight: Int = lineHeight                // 34
    private(set) var effectiveCharsPerLine: Int = charsPerLine            // 29
    private(set) var effectiveLinesPerPage: Int = linesPerPage            // 22
    private(set) var hasBitmapFont: Bool = false

    // MARK: - Buffers

    /// Reusable IO buffer for chunk reads (scan & draw). Lazily allocated.
    private var _ioBuffer: UnsafeMutablePointer<UInt8>? = nil

    /// Cluster map for random-access reads. Lazily allocated.
    private var _clusterMap: UnsafeMutablePointer<UInt32>? = nil
    private(set) var clusterCount: Int = 0
    private(set) var fileSize: Int = 0

    /// Ring buffer for line file-offsets (Int32). Lazily allocated.
    private var _ringOffsets: UnsafeMutablePointer<Int32>? = nil
    /// Ring buffer for line byte-lengths (Int16). Lazily allocated.
    private var _ringLengths: UnsafeMutablePointer<Int16>? = nil

    /// Checkpoint array: (fileOffset: Int32, lineIndex: Int32). Lazily allocated.
    private var _checkpoints: UnsafeMutablePointer<Int64>? = nil
    private(set) var checkpointCount: Int = 0

    // MARK: - Ring State

    /// Absolute line index of the first entry held in the ring.
    private var ringHead: Int = 0
    /// Number of valid entries currently in the ring (0 … ringSize).
    private var ringCount: Int = 0
    /// Slot index in the ring array that corresponds to `ringHead`.
    private var ringBase: Int = 0

    // MARK: - Scan State

    /// Total lines discovered so far (grows as we scan forward).
    private(set) var knownLineCount: Int = 0
    /// File offset just past the last byte scanned.
    private var scanEndOffset: Int = 0
    /// True once the scanner has reached EOF.
    private(set) var scannedToEnd: Bool = false

    // MARK: - Scroll & File Identity

    /// Index of the first visible line.
    private(set) var scrollLine: Int = 0

    /// Start cluster of the currently loaded file (used for resume).
    private(set) var fileCluster: UInt32 = 0

    /// ScrollLine value at last resume save (skip save when unchanged).
    private var lastSavedScrollLine: Int = -1

    /// Filename for header display.
    private let nameBuffer: UnsafeMutablePointer<UInt8>
    private(set) var nameLen: Int = 0

    init() {
        nameBuffer = .allocate(capacity: 64)
    }

    // MARK: - Buffer Management

    private mutating func ensureBuffers() {
        if _ioBuffer == nil { _ioBuffer = .allocate(capacity: Self.ioBufferSize) }
        if _clusterMap == nil { _clusterMap = .allocate(capacity: Self.maxClusters) }
        if _ringOffsets == nil { _ringOffsets = .allocate(capacity: Self.ringSize) }
        if _ringLengths == nil { _ringLengths = .allocate(capacity: Self.ringSize) }
        if _checkpoints == nil { _checkpoints = .allocate(capacity: Self.maxCheckpoints) }
    }

    mutating func releaseBuffers() {
        _ioBuffer?.deallocate(); _ioBuffer = nil
        _clusterMap?.deallocate(); _clusterMap = nil
        _ringOffsets?.deallocate(); _ringOffsets = nil
        _ringLengths?.deallocate(); _ringLengths = nil
        _checkpoints?.deallocate(); _checkpoints = nil
        clusterCount = 0
        fileSize = 0
        checkpointCount = 0
        ringHead = 0; ringCount = 0; ringBase = 0
        knownLineCount = 0; scanEndOffset = 0; scannedToEnd = false
        scrollLine = 0
        fileCluster = 0
        lastSavedScrollLine = -1
    }

    // Non-optional accessors for use after ensureBuffers().
    private var ioBuffer: UnsafeMutablePointer<UInt8> { _ioBuffer! }
    private var clusterMap: UnsafeMutablePointer<UInt32> { _clusterMap! }
    private var ringOffsets: UnsafeMutablePointer<Int32> { _ringOffsets! }
    private var ringLengths: UnsafeMutablePointer<Int16> { _ringLengths! }
    private var checkpoints: UnsafeMutablePointer<Int64> { _checkpoints! }

    // MARK: - Ring Buffer Accessors

    /// Whether absolute line `line` is currently held in the ring.
    private func ringContains(_ line: Int) -> Bool {
        line >= ringHead && line < ringHead + ringCount
    }

    /// Slot index in the ring arrays for absolute line `line`.
    private func ringSlot(_ line: Int) -> Int {
        (ringBase + (line - ringHead)) & Self.ringMask
    }

    /// File offset of the start of absolute line `line`.
    private func lineOffset(_ line: Int) -> Int {
        Int(ringOffsets[ringSlot(line)])
    }

    /// Byte length of absolute line `line`.
    private func lineLength(_ line: Int) -> Int {
        Int(ringLengths[ringSlot(line)])
    }

    // MARK: - Checkpoint Helpers

    /// Pack a checkpoint into Int64: high 32 bits = fileOffset, low 32 bits = lineIndex.
    private static func packCheckpoint(fileOffset: Int, lineIndex: Int) -> Int64 {
        Int64(Int32(truncatingIfNeeded: fileOffset)) << 32 | Int64(UInt32(bitPattern: Int32(truncatingIfNeeded: lineIndex)))
    }

    private static func checkpointFileOffset(_ packed: Int64) -> Int {
        Int(Int32(truncatingIfNeeded: packed >> 32))
    }

    private static func checkpointLineIndex(_ packed: Int64) -> Int {
        Int(Int32(bitPattern: UInt32(truncatingIfNeeded: packed)))
    }

    /// Record a checkpoint (append or overwrite oldest if full).
    private mutating func addCheckpoint(fileOffset: Int, lineIndex: Int) {
        // Skip if the most recent checkpoint already covers this line.
        // This guards against the duplicate emit when scanLines resumes
        // exactly on a checkpoint boundary (e.g. after restoring saved
        // checkpoints from READHIST.DAT and re-scanning forward).
        if checkpointCount > 0 {
            let last = checkpoints[checkpointCount - 1]
            if Self.checkpointLineIndex(last) == lineIndex {
                return
            }
        }
        let packed = Self.packCheckpoint(fileOffset: fileOffset, lineIndex: lineIndex)
        if checkpointCount < Self.maxCheckpoints {
            checkpoints[checkpointCount] = packed
            checkpointCount += 1
        }
        // When full, the last slot is overwritten — acceptable since the most
        // recent checkpoints are the most useful for forward progress.
    }

    /// Find the last checkpoint at or before `targetLine`.
    private func findCheckpointBefore(_ targetLine: Int) -> (fileOffset: Int, lineIndex: Int) {
        var bestOffset = 0
        var bestLine = 0
        for i in 0..<checkpointCount {
            let cp = checkpoints[i]
            let li = Self.checkpointLineIndex(cp)
            if li <= targetLine {
                bestOffset = Self.checkpointFileOffset(cp)
                bestLine = li
            }
        }
        return (bestOffset, bestLine)
    }

    // MARK: - Font Configuration

    mutating func configureFont(font: BitmapFont) {
        effectiveCharWidth = font.glyphWidth
        effectiveLineHeight = font.glyphHeight + 2
        effectiveCharsPerLine = (UIRenderer.screenWidth - Self.leftMargin - Self.rightMargin)
                                / font.glyphWidth
        effectiveLinesPerPage = (UIRenderer.screenHeight - Self.contentTop)
                                / effectiveLineHeight
        hasBitmapFont = true
    }

    mutating func resetFont() {
        effectiveCharWidth = UIRenderer.charWidth
        effectiveLineHeight = Self.lineHeight
        effectiveCharsPerLine = Self.charsPerLine
        effectiveLinesPerPage = Self.linesPerPage
        hasBitmapFont = false
    }

    // MARK: - Loading

    mutating func loadFile(fat: inout FATFileSystem, cluster: UInt32, fileSize: UInt32,
                           name: UnsafeMutablePointer<UInt8>, nameLength: Int) {
        ensureBuffers()

        // Store filename
        nameLen = min(nameLength, 63)
        for i in 0..<nameLen {
            nameBuffer[i] = name[i]
        }

        self.fileSize = Int(fileSize)
        self.fileCluster = cluster

        // Build cluster map for random-access reads
        clusterCount = fat.buildClusterMap(startCluster: cluster,
                                           into: clusterMap,
                                           maxClusters: Self.maxClusters)

        // Try to restore resume position
        let resumed = loadResumeState(fat: &fat)

        if !resumed {
            // Scan from the beginning, filling the ring buffer
            ringHead = 0; ringCount = 0; ringBase = 0
            knownLineCount = 0; scanEndOffset = 0; scannedToEnd = false
            checkpointCount = 0
            scanLines(fat: &fat, fromOffset: 0, startLine: 0, maxLines: Self.ringSize)
            scrollLine = 0
        }

        lastSavedScrollLine = -1
    }

    // MARK: - Line Scanning (Ring Buffer Word Wrap)

    /// Scan forward from `fromOffset`, computing word-wrapped lines and
    /// writing them into the ring buffer.  Also records checkpoints.
    ///
    /// - `fromOffset`: file byte offset to start scanning from.
    /// - `startLine`: the absolute line index corresponding to `fromOffset`.
    /// - `maxLines`: maximum number of lines to emit into the ring.
    /// - `resetRing`: if true, clear the ring first; if false, append to it.
    private mutating func scanLines(fat: inout FATFileSystem,
                                    fromOffset: Int,
                                    startLine: Int,
                                    maxLines: Int,
                                    resetRing: Bool = true) {
        let maxChars = effectiveCharsPerLine

        var filePos = fromOffset
        var scanPos = fromOffset
        var lineStart = fromOffset
        var charCount = 0
        var lastSpaceFilePos = -1

        var bufStart = 0
        var bufLen = 0

        var emitted = 0

        if resetRing {
            // Reset ring to start filling from startLine
            ringHead = startLine
            ringCount = 0
            ringBase = 0
        }

        while scanPos < fileSize && emitted < maxLines {
            // Ensure we have data covering scanPos
            if scanPos < bufStart || scanPos >= bufStart + bufLen {
                filePos = scanPos
                let toRead = min(Self.ioBufferSize, fileSize - filePos)
                bufLen = fat.readBytes(clusterMap: clusterMap,
                                       clusterCount: clusterCount,
                                       fileOffset: filePos,
                                       into: ioBuffer,
                                       count: toRead)
                bufStart = filePos
                guard bufLen > 0 else { break }
            }

            let bufOffset = scanPos - bufStart
            let b = ioBuffer[bufOffset]

            // Line endings
            if b == 0x0A {
                emitLine(lineStart: lineStart, length: scanPos - lineStart,
                         absoluteLine: startLine + emitted)
                emitted += 1
                scanPos += 1
                lineStart = scanPos
                charCount = 0
                lastSpaceFilePos = -1
                continue
            }
            if b == 0x0D {
                emitLine(lineStart: lineStart, length: scanPos - lineStart,
                         absoluteLine: startLine + emitted)
                emitted += 1
                scanPos += 1
                if scanPos < fileSize {
                    if scanPos >= bufStart + bufLen {
                        let toRead = min(Self.ioBufferSize, fileSize - scanPos)
                        bufLen = fat.readBytes(clusterMap: clusterMap,
                                               clusterCount: clusterCount,
                                               fileOffset: scanPos,
                                               into: ioBuffer,
                                               count: toRead)
                        bufStart = scanPos
                    }
                    if bufLen > 0 && ioBuffer[scanPos - bufStart] == 0x0A {
                        scanPos += 1
                    }
                }
                lineStart = scanPos
                charCount = 0
                lastSpaceFilePos = -1
                continue
            }

            // UTF-8 decode
            let bytesAvail = bufStart + bufLen - scanPos
            let seqLen = utf8SequenceLength(b)

            if seqLen > bytesAvail {
                let toRead = min(Self.ioBufferSize, fileSize - scanPos)
                bufLen = fat.readBytes(clusterMap: clusterMap,
                                       clusterCount: clusterCount,
                                       fileOffset: scanPos,
                                       into: ioBuffer,
                                       count: toRead)
                bufStart = scanPos
                guard bufLen > 0 else { break }
                continue
            }

            let (cp, consumed) = UTF8Decoder.decode(ioBuffer,
                                                     at: scanPos - bufStart,
                                                     length: bufStart + bufLen)

            if cp == 0x20 {
                lastSpaceFilePos = scanPos
            }

            scanPos += consumed
            charCount += 1

            if charCount >= maxChars {
                if lastSpaceFilePos > lineStart {
                    emitLine(lineStart: lineStart, length: lastSpaceFilePos - lineStart,
                             absoluteLine: startLine + emitted)
                    emitted += 1
                    scanPos = lastSpaceFilePos + 1
                } else {
                    emitLine(lineStart: lineStart, length: scanPos - lineStart,
                             absoluteLine: startLine + emitted)
                    emitted += 1
                }
                lineStart = scanPos
                charCount = 0
                lastSpaceFilePos = -1
            }
        }

        // Final partial line
        if lineStart < fileSize && emitted < maxLines && lineStart < scanPos {
            emitLine(lineStart: lineStart, length: scanPos - lineStart,
                     absoluteLine: startLine + emitted)
            emitted += 1
        }

        // Update scan state
        let totalLines = startLine + emitted
        if totalLines > knownLineCount {
            knownLineCount = totalLines
        }
        scanEndOffset = scanPos
        if scanPos >= fileSize {
            scannedToEnd = true
        }
    }

    /// Write one line into the ring buffer and record a checkpoint if due.
    private mutating func emitLine(lineStart: Int, length: Int, absoluteLine: Int) {
        let slot = (ringBase + ringCount) & Self.ringMask
        ringOffsets[slot] = Int32(truncatingIfNeeded: lineStart)
        ringLengths[slot] = Int16(truncatingIfNeeded: min(length, Int(Int16.max)))

        if ringCount < Self.ringSize {
            ringCount += 1
        } else {
            // Ring full — advance head
            ringHead += 1
            ringBase = (ringBase + 1) & Self.ringMask
        }

        // Record checkpoint at interval boundaries
        if absoluteLine > 0 && (absoluteLine % Self.checkpointInterval) == 0 {
            addCheckpoint(fileOffset: lineStart, lineIndex: absoluteLine)
        }
    }

    /// Ensure that lines `first...last` are in the ring.
    /// Scans forward or backward as needed.
    private mutating func ensureLinesInRing(first: Int, last: Int,
                                            fat: inout FATFileSystem) {
        let effectiveLast = scannedToEnd ? min(last, max(knownLineCount - 1, 0)) : last

        // Fast path: already cached
        if ringCount > 0 && ringContains(first) && ringContains(effectiveLast) {
            return
        }

        // Forward extension: first is in ring (or at ring end) but last is beyond
        if ringCount > 0 && first >= ringHead && first < ringHead + ringCount && !scannedToEnd {
            let lastRing = ringHead + ringCount - 1
            let scanFrom = lineOffset(lastRing) + lineLength(lastRing)
            let startLine = lastRing + 1
            let needed = effectiveLast - startLine + 1 + Self.ringSize / 2
            if needed > 0 {
                scanLines(fat: &fat, fromOffset: scanFrom, startLine: startLine,
                          maxLines: min(needed, Self.ringSize), resetRing: false)
            }
            return
        }

        // Forward: completely past current ring
        if first >= ringHead + ringCount && ringCount > 0 && !scannedToEnd {
            let lastRing = ringHead + ringCount - 1
            let scanFrom = lineOffset(lastRing) + lineLength(lastRing)
            let startLine = lastRing + 1
            let needed = effectiveLast - startLine + 1 + Self.ringSize / 2
            if needed > 0 {
                scanLines(fat: &fat, fromOffset: scanFrom, startLine: startLine,
                          maxLines: min(needed, Self.ringSize), resetRing: false)
            }
            return
        }

        // Backward: need lines before current ring head
        if first < ringHead {
            let (cpOffset, cpLine) = findCheckpointBefore(first)
            let needed = min(effectiveLast - cpLine + 1 + Self.ringSize / 2, Self.ringSize)
            scanLines(fat: &fat, fromOffset: cpOffset, startLine: cpLine,
                      maxLines: needed)
            return
        }

        // Fallback: ring empty or other edge case — scan from nearest checkpoint
        let (cpOffset, cpLine) = findCheckpointBefore(first)
        let needed = min(effectiveLast - cpLine + 1 + Self.ringSize / 2, Self.ringSize)
        scanLines(fat: &fat, fromOffset: cpOffset, startLine: cpLine,
                  maxLines: needed)
    }

    private func utf8SequenceLength(_ b: UInt8) -> Int {
        if b < 0x80 { return 1 }
        if b & 0xE0 == 0xC0 { return 2 }
        if b & 0xF0 == 0xE0 { return 3 }
        if b & 0xF8 == 0xF0 { return 4 }
        return 1
    }

    // MARK: - Navigation

    mutating func scrollUp(fat: inout FATFileSystem) {
        if scrollLine > 0 {
            scrollLine -= 1
            let lastVisible = scrollLine + effectiveLinesPerPage - 1
            ensureLinesInRing(first: scrollLine, last: lastVisible, fat: &fat)
        }
    }

    mutating func scrollDown(fat: inout FATFileSystem) {
        let newLine = scrollLine + 1
        let lastVisible = newLine + effectiveLinesPerPage - 1
        ensureLinesInRing(first: newLine, last: lastVisible, fat: &fat)
        // Clamp after ensuring lines are scanned
        if scannedToEnd {
            let maxScroll = max(knownLineCount - effectiveLinesPerPage, 0)
            if newLine <= maxScroll {
                scrollLine = newLine
            }
        } else {
            // Not at EOF yet — if we got the lines, allow scroll
            if ringContains(lastVisible) {
                scrollLine = newLine
            }
        }
    }

    mutating func pageUp(fat: inout FATFileSystem) {
        let newLine = max(scrollLine - effectiveLinesPerPage, 0)
        let lastVisible = newLine + effectiveLinesPerPage - 1
        ensureLinesInRing(first: newLine, last: lastVisible, fat: &fat)
        scrollLine = newLine
    }

    mutating func pageDown(fat: inout FATFileSystem) {
        let newLine = scrollLine + effectiveLinesPerPage
        let lastVisible = newLine + effectiveLinesPerPage - 1
        ensureLinesInRing(first: newLine, last: lastVisible, fat: &fat)
        if scannedToEnd {
            let maxScroll = max(knownLineCount - effectiveLinesPerPage, 0)
            scrollLine = min(newLine, maxScroll)
        } else {
            if ringContains(lastVisible) {
                scrollLine = newLine
            } else {
                // Scanned but didn't reach lastVisible — clamp to what we have
                let maxScroll = max(knownLineCount - effectiveLinesPerPage, 0)
                scrollLine = min(newLine, maxScroll)
            }
        }
    }

    // MARK: - Drawing

    func draw(fb: Framebuffer, font: inout BitmapFont, fat: inout FATFileSystem) {
        guard _ioBuffer != nil else { return }

        if hasBitmapFont && font.loaded {
            drawWithBitmapFont(fb: fb, font: &font, fat: &fat)
        } else {
            drawASCIIFallback(fb: fb, fat: &fat)
        }

        if knownLineCount > effectiveLinesPerPage || !scannedToEnd {
            drawScrollbar(fb: fb)
        }
    }

    private func readVisibleLines(fat: inout FATFileSystem) -> (Int, Int) {
        let endLine = min(scrollLine + effectiveLinesPerPage, knownLineCount)
        guard endLine > scrollLine, ringContains(scrollLine), ringContains(endLine - 1)
        else { return (0, 0) }

        let readStart = lineOffset(scrollLine)
        let lastLine = endLine - 1
        let readEnd = lineOffset(lastLine) + lineLength(lastLine)
        let readSize = min(readEnd - readStart, Self.ioBufferSize)

        let bytesRead = fat.readBytes(clusterMap: clusterMap,
                                       clusterCount: clusterCount,
                                       fileOffset: readStart,
                                       into: ioBuffer,
                                       count: readSize)
        return (readStart, bytesRead)
    }

    private func drawWithBitmapFont(fb: Framebuffer, font: inout BitmapFont,
                                    fat: inout FATFileSystem) {
        let gw = font.glyphWidth
        let gh = font.glyphHeight
        let bpr = font.bytesPerRow

        let (readStart, bytesRead) = readVisibleLines(fat: &fat)
        guard bytesRead > 0 else { return }

        let endLine = min(scrollLine + effectiveLinesPerPage, knownLineCount)
        for i in scrollLine..<endLine {
            let row = i - scrollLine
            let y = Self.contentTop + row * effectiveLineHeight
            let localOffset = lineOffset(i) - readStart
            let len = lineLength(i)

            var x = Self.leftMargin
            var bytePos = 0
            while bytePos < len {
                let (cp, consumed) = UTF8Decoder.decode(ioBuffer,
                                                        at: localOffset + bytePos,
                                                        length: bytesRead)
                bytePos += consumed
                if consumed == 0 { break }

                if let glyphPtr = font.glyphData(codePoint: cp, fat: &fat) {
                    fb.drawGlyph(x: x, y: y, glyphData: glyphPtr,
                                 glyphWidth: gw, glyphHeight: gh,
                                 bytesPerRow: bpr)
                } else {
                    fb.drawRectOutline(x: x + 2, y: y + 2,
                                       w: gw - 4, h: gh - 4, black: true)
                }
                x += gw
            }
        }
    }

    private func drawASCIIFallback(fb: Framebuffer, fat: inout FATFileSystem) {
        let scale = UIRenderer.fontScale
        let gh = FontData.glyphHeight
        let charW = UIRenderer.charWidth

        let (readStart, bytesRead) = readVisibleLines(fat: &fat)
        guard bytesRead > 0 else { return }

        withFontData { fontPtr in
            let endLine = min(scrollLine + effectiveLinesPerPage, knownLineCount)
            for i in scrollLine..<endLine {
                let row = i - scrollLine
                let y = Self.contentTop + row * effectiveLineHeight
                let localOffset = lineOffset(i) - readStart
                let len = lineLength(i)

                var x = Self.leftMargin
                var bytePos = 0
                while bytePos < len {
                    let (cp, consumed) = UTF8Decoder.decode(ioBuffer,
                                                            at: localOffset + bytePos,
                                                            length: bytesRead)
                    bytePos += consumed
                    if consumed == 0 { break }

                    if cp >= 0x20 && cp <= 0x7E {
                        fb.drawCharScaled(x: x, y: y,
                                          char: UInt8(cp), fontData: fontPtr,
                                          glyphHeight: gh, scale: scale)
                    } else if cp > 0x7F {
                        let tofuW = charW - 4
                        let tofuH = gh * scale - 4
                        fb.drawRectOutline(x: x + 2, y: y + 2,
                                           w: tofuW, h: tofuH, black: true)
                    }
                    x += charW
                }
            }
        }
    }

    func drawHeader(fb: Framebuffer, batteryStatus: BatteryStatus) {
        withFontData { font in
            let scale = UIRenderer.fontScale
            let gh = FontData.glyphHeight
            let charW = UIRenderer.charWidth
            let maxChars = min(nameLen, 20)

            for i in 0..<maxChars {
                let ch = nameBuffer[i]
                if ch >= 0x20 && ch <= 0x7E {
                    fb.drawCharScaled(x: 8 + i * charW, y: 8,
                                      char: ch, fontData: font,
                                      glyphHeight: gh, scale: scale)
                }
            }
        }

        let batteryX = UIRenderer.screenWidth - BatteryIcon.iconWidth - 48 - 8
        BatteryIcon.drawWithText(fb: fb, x: batteryX, y: 8, status: batteryStatus)
    }

    /// Draw scrollbar using byte-position approximation.
    private func drawScrollbar(fb: Framebuffer) {
        let trackX = UIRenderer.screenWidth - 6
        let trackY = Self.contentTop
        let trackH = effectiveLinesPerPage * effectiveLineHeight

        // Thin track
        fb.drawRect(x: trackX + 2, y: trackY, w: 2, h: trackH, black: true)

        // Byte-position-based thumb
        let currentOffset = ringContains(scrollLine) ? lineOffset(scrollLine) : 0
        let thumbH = max(16, trackH / 8)
        let thumbY: Int
        if fileSize > 0 {
            thumbY = trackY + (trackH - thumbH) * currentOffset / fileSize
        } else {
            thumbY = trackY
        }
        fb.drawRect(x: trackX, y: thumbY, w: 6, h: thumbH, black: true)
    }

    // MARK: - Resume Persistence

    /// Save resume state if scroll position has changed since last save.
    mutating func saveIfNeeded(fat: inout FATFileSystem) {
        guard scrollLine != lastSavedScrollLine else { return }
        saveResumeState(fat: &fat)
    }

    /// Save current reading position to READHIST.DAT on SD card.
    mutating func saveResumeState(fat: inout FATFileSystem) {
        guard _ioBuffer != nil, fileCluster != 0 else { return }

        let entrySize = Self.resumeEntrySize  // 64
        let totalSize = Self.maxResumeEntries * entrySize  // 1024

        // Try to read existing resume file
        var resumeCluster: UInt32 = 0
        var resumeFileSize: UInt32 = 0
        let found = fat.findFile(name: (0x52, 0x45, 0x41, 0x44, 0x48, 0x49, 0x53, 0x54),  // READHIST
                                 ext: (0x44, 0x41, 0x54),  // DAT
                                 cluster: &resumeCluster,
                                 fileSize: &resumeFileSize)

        // Zero the working area first so unused checkpoint slots stay zero.
        for i in 0..<totalSize {
            ioBuffer[i] = 0
        }

        if found && resumeFileSize > 0 {
            // Read existing data
            let readMap = UnsafeMutablePointer<UInt32>.allocate(capacity: Self.maxClusters)
            let readCount = fat.buildClusterMap(startCluster: resumeCluster,
                                                into: readMap,
                                                maxClusters: Self.maxClusters)
            let _ = fat.readBytes(clusterMap: readMap, clusterCount: readCount,
                                  fileOffset: 0, into: ioBuffer,
                                  count: min(Int(resumeFileSize), totalSize))
            readMap.deallocate()
        }

        // Find matching entry or empty slot
        var targetSlot = -1
        var emptySlot = -1
        for i in 0..<Self.maxResumeEntries {
            let base = i * entrySize
            let cluster = readLE32(ioBuffer, at: base)
            if cluster == fileCluster {
                targetSlot = i
                break
            }
            if cluster == 0 && emptySlot < 0 {
                emptySlot = i
            }
        }

        if targetSlot < 0 {
            targetSlot = emptySlot >= 0 ? emptySlot : (Self.maxResumeEntries - 1)
        }

        // Zero the target slot so stale checkpoint slots don't leak through
        // when the new save has fewer checkpoints than the old one.
        let base = targetSlot * entrySize
        for i in 0..<entrySize {
            ioBuffer[base + i] = 0
        }

        // Write entry header:
        // [0..3] cluster, [4..7] fileSize,
        // [8..11] scrollLine, [12..15] scrollOffset
        let scrollOff: Int32 = ringContains(scrollLine) ? Int32(truncatingIfNeeded: lineOffset(scrollLine)) : 0
        let scrollLn = Int32(truncatingIfNeeded: scrollLine)
        let fSize = UInt32(truncatingIfNeeded: fileSize)

        writeLE32(ioBuffer, at: base, value: fileCluster)
        writeLE32(ioBuffer, at: base + 4, value: fSize)
        writeLE32(ioBuffer, at: base + 8, value: UInt32(bitPattern: scrollLn))
        writeLE32(ioBuffer, at: base + 12, value: UInt32(bitPattern: scrollOff))

        // Persist the most-recent `resumeCheckpointSlots` checkpoints.
        // Checkpoints are appended in scan order, so the tail is the most
        // useful for fast resume + nearby backward navigation.
        let cpSaveCount = min(checkpointCount, Self.resumeCheckpointSlots)
        let cpStartIdx = checkpointCount - cpSaveCount
        for s in 0..<cpSaveCount {
            let cp = checkpoints[cpStartIdx + s]
            let cpOff = Self.checkpointFileOffset(cp)
            let cpLn = Self.checkpointLineIndex(cp)
            let off = base + 16 + s * 8
            writeLE32(ioBuffer, at: off, value: UInt32(bitPattern: Int32(truncatingIfNeeded: cpOff)))
            writeLE32(ioBuffer, at: off + 4, value: UInt32(bitPattern: Int32(truncatingIfNeeded: cpLn)))
        }

        // Delete old file and write new one
        if found {
            let _ = fat.deleteFile(dirCluster: 0, fileCluster: resumeCluster)
        }
        let _ = fat.writeFile(
            dirCluster: 0,
            name: (0x52, 0x45, 0x41, 0x44, 0x48, 0x49, 0x53, 0x54),  // READHIST
            ext: (0x44, 0x41, 0x54),  // DAT
            data: UnsafePointer(ioBuffer),
            size: totalSize)

        lastSavedScrollLine = scrollLine
    }

    /// Attempt to restore scroll position from READHIST.DAT.
    /// Returns true if resume succeeded.
    private mutating func loadResumeState(fat: inout FATFileSystem) -> Bool {
        var resumeCluster: UInt32 = 0
        var resumeFileSize: UInt32 = 0
        let found = fat.findFile(name: (0x52, 0x45, 0x41, 0x44, 0x48, 0x49, 0x53, 0x54),
                                 ext: (0x44, 0x41, 0x54),
                                 cluster: &resumeCluster,
                                 fileSize: &resumeFileSize)
        guard found, resumeFileSize > 0 else { return false }

        let entrySize = Self.resumeEntrySize
        let totalSize = Self.maxResumeEntries * entrySize

        // Read resume file using a temporary cluster map
        let readMap = UnsafeMutablePointer<UInt32>.allocate(capacity: Self.maxClusters)
        let readCount = fat.buildClusterMap(startCluster: resumeCluster,
                                            into: readMap,
                                            maxClusters: Self.maxClusters)
        let bytesRead = fat.readBytes(clusterMap: readMap, clusterCount: readCount,
                                      fileOffset: 0, into: ioBuffer,
                                      count: min(Int(resumeFileSize), totalSize))
        readMap.deallocate()
        guard bytesRead > 0 else { return false }

        // Search for matching entry
        for i in 0..<Self.maxResumeEntries {
            let base = i * entrySize
            if base + entrySize > bytesRead { break }

            let cluster = readLE32(ioBuffer, at: base)
            let fSize = readLE32(ioBuffer, at: base + 4)

            if cluster == fileCluster && fSize == UInt32(truncatingIfNeeded: fileSize) {
                let scrollLn = Int(Int32(bitPattern: readLE32(ioBuffer, at: base + 8)))
                let scrollOff = Int(Int32(bitPattern: readLE32(ioBuffer, at: base + 12)))

                guard scrollOff >= 0 && scrollOff <= fileSize && scrollLn >= 0 else {
                    return false
                }

                // Reset state and restore the persisted checkpoints.
                ringHead = 0; ringCount = 0; ringBase = 0
                knownLineCount = 0; scanEndOffset = 0; scannedToEnd = false
                checkpointCount = 0

                for s in 0..<Self.resumeCheckpointSlots {
                    let off = base + 16 + s * 8
                    let cpOff = Int(Int32(bitPattern: readLE32(ioBuffer, at: off)))
                    let cpLn = Int(Int32(bitPattern: readLE32(ioBuffer, at: off + 4)))
                    // Sentinel: lineIndex == 0 means unused (line 0 is never
                    // a checkpoint — see emitLine).
                    if cpLn > 0 && cpOff > 0 && cpOff < fileSize {
                        addCheckpoint(fileOffset: cpOff, lineIndex: cpLn)
                    }
                }

                // Scan forward only from the nearest checkpoint at or
                // before the saved scroll line, instead of from the file
                // start. addCheckpoint dedups the duplicate emit at cpLine.
                let (cpOffset, cpLine) = findCheckpointBefore(scrollLn)
                let needed = scrollLn - cpLine + effectiveLinesPerPage + Self.ringSize / 2
                scanLines(fat: &fat, fromOffset: cpOffset, startLine: cpLine,
                          maxLines: max(needed, Self.ringSize))

                // Clamp scroll to what we actually scanned
                if scrollLn < knownLineCount {
                    scrollLine = scrollLn
                } else {
                    scrollLine = max(knownLineCount - effectiveLinesPerPage, 0)
                }

                // Ensure visible lines are in ring
                let lastVisible = scrollLine + effectiveLinesPerPage - 1
                if !ringContains(scrollLine) || (lastVisible < knownLineCount && !ringContains(lastVisible)) {
                    ensureLinesInRing(first: scrollLine, last: min(lastVisible, knownLineCount - 1), fat: &fat)
                }

                return true
            }
        }

        return false
    }

    // MARK: - Little-Endian Byte Helpers

    private func readLE32(_ buf: UnsafeMutablePointer<UInt8>, at offset: Int) -> UInt32 {
        UInt32(buf[offset]) |
        (UInt32(buf[offset + 1]) << 8) |
        (UInt32(buf[offset + 2]) << 16) |
        (UInt32(buf[offset + 3]) << 24)
    }

    private func writeLE32(_ buf: UnsafeMutablePointer<UInt8>, at offset: Int, value: UInt32) {
        buf[offset] = UInt8(truncatingIfNeeded: value)
        buf[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
        buf[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
        buf[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
    }
}
