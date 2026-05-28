/// File list view for browsing SD card contents.
///
/// Displays a scrollable list of files/directories from a FAT filesystem.
/// Supports Up/Down navigation and selection cursor.
///
/// Layout on 480×800 portrait display (2× font scale = 16×32 chars):
/// - Header bar: 48px (title + battery)
/// - File list: remaining height, 40px per row
/// - Each row: icon (folder/file) + filename
struct FileListView {
    /// Maximum entries we can hold in memory.
    static let maxEntries = 64

    /// Display metrics (logical coordinates, 480×800 portrait, 2× scale).
    static let headerHeight = 48
    static let rowHeight = 40
    static let leftPadding = 8
    static let textLeftPadding = 40  // After folder/file icon

    /// Action menu mode.
    enum Mode: UInt8 {
        case normal = 0
        case actionMenu = 1
        case confirmDelete = 2
    }

    /// Action menu items.
    enum Action: UInt8 {
        case copy = 0
        case delete = 1
    }

    /// Entry storage.
    struct FileEntry {
        var nameBuffer: UnsafeMutablePointer<UInt8>
        var nameLen: Int
        var isDirectory: Bool
        var cluster: UInt32
        var fileSize: UInt32
        var name83: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) = (0x20,0x20,0x20,0x20,0x20,0x20,0x20,0x20)
        var ext83: (UInt8, UInt8, UInt8) = (0x20,0x20,0x20)

        init() {
            self.nameBuffer = .allocate(capacity: 64)
            self.nameLen = 0
            self.isDirectory = false
            self.cluster = 0
            self.fileSize = 0
        }
    }

    private let entries: UnsafeMutablePointer<FileEntry>
    private(set) var entryCount: Int = 0
    private(set) var selectedIndex: Int = 0
    private(set) var scrollOffset: Int = 0
    private let visibleRows: Int
    private(set) var mode: Mode = .normal
    private(set) var actionIndex: Int = 0  // 0 = copy, 1 = delete (actionMenu); 0 = yes, 1 = no (confirmDelete)

    init(displayHeight: Int) {
        entries = .allocate(capacity: Self.maxEntries)
        for i in 0..<Self.maxEntries {
            entries[i] = FileEntry()
        }
        visibleRows = (displayHeight - Self.headerHeight) / Self.rowHeight
    }

    /// Load file entries from a FAT directory.
    mutating func loadFromRoot(fat: inout FATFileSystem) {
        entryCount = 0
        selectedIndex = 0
        scrollOffset = 0

        fat.listRootDirectory { entry in
            guard self.entryCount < Self.maxEntries else { return false }
            if entry.isHidden { return true }
            if entry.attr & 0x08 != 0 { return true }

            let idx = self.entryCount
            self.entries[idx].isDirectory = entry.isDirectory
            self.entries[idx].cluster = entry.cluster
            self.entries[idx].fileSize = entry.fileSize
            self.entries[idx].name83 = entry.name
            self.entries[idx].ext83 = entry.ext

            if entry.hasLFN, let lfnPtr = entry.lfnPtr {
                let len = min(entry.lfnLen, 63)
                for i in 0..<len {
                    self.entries[idx].nameBuffer[i] = lfnPtr[i]
                }
                self.entries[idx].nameLen = len
            } else {
                let len = self.format83Name(entry: entry, into: self.entries[idx].nameBuffer)
                self.entries[idx].nameLen = len
            }

            self.entryCount += 1
            return true
        }
        sortEntries(from: 0)
    }

    /// Load file entries from a subdirectory.
    mutating func loadFromDirectory(fat: inout FATFileSystem, cluster: UInt32) {
        entryCount = 0
        selectedIndex = 0
        scrollOffset = 0

        fat.listDirectory(cluster: cluster) { entry in
            guard self.entryCount < Self.maxEntries else { return false }
            if entry.isHidden { return true }
            if entry.attr & 0x08 != 0 { return true }
            let first = entry.name.0
            if first == 0x2E && entry.name.1 == 0x20 { return true }

            let idx = self.entryCount
            self.entries[idx].isDirectory = entry.isDirectory
            self.entries[idx].cluster = entry.cluster
            self.entries[idx].fileSize = entry.fileSize
            self.entries[idx].name83 = entry.name
            self.entries[idx].ext83 = entry.ext

            if first == 0x2E && entry.name.1 == 0x2E {
                self.entries[idx].nameBuffer[0] = 0x2E
                self.entries[idx].nameBuffer[1] = 0x2E
                self.entries[idx].nameLen = 2
            } else if entry.hasLFN, let lfnPtr = entry.lfnPtr {
                let len = min(entry.lfnLen, 63)
                for i in 0..<len {
                    self.entries[idx].nameBuffer[i] = lfnPtr[i]
                }
                self.entries[idx].nameLen = len
            } else {
                let len = self.format83Name(entry: entry, into: self.entries[idx].nameBuffer)
                self.entries[idx].nameLen = len
            }

            self.entryCount += 1
            return true
        }
        // ".." entry stays at index 0; sort the rest
        let sortStart = (entryCount > 0 && entries[0].nameLen == 2
                         && entries[0].nameBuffer[0] == 0x2E
                         && entries[0].nameBuffer[1] == 0x2E) ? 1 : 0
        sortEntries(from: sortStart)
    }

    /// Move selection up (wraps to bottom at top).
    mutating func moveUp() {
        guard entryCount > 0 else { return }
        if selectedIndex > 0 {
            selectedIndex -= 1
        } else {
            selectedIndex = entryCount - 1
        }
        if selectedIndex < scrollOffset {
            scrollOffset = selectedIndex
        } else if selectedIndex >= scrollOffset + visibleRows {
            scrollOffset = selectedIndex - visibleRows + 1
        }
    }

    /// Move selection down (wraps to top at bottom).
    mutating func moveDown() {
        guard entryCount > 0 else { return }
        if selectedIndex < entryCount - 1 {
            selectedIndex += 1
        } else {
            selectedIndex = 0
        }
        if selectedIndex >= scrollOffset + visibleRows {
            scrollOffset = selectedIndex - visibleRows + 1
        } else if selectedIndex < scrollOffset {
            scrollOffset = selectedIndex
        }
    }

    /// Get the currently selected entry (if any).
    func selectedEntry() -> FileEntry? {
        guard entryCount > 0 else { return nil }
        return entries[selectedIndex]
    }

    /// Restore cursor and scroll position after a deep sleep wake.
    /// Both values are clamped to the current `entryCount`.
    mutating func restoreCursor(selectedIndex: Int, scrollOffset: Int) {
        guard entryCount > 0 else {
            self.selectedIndex = 0
            self.scrollOffset = 0
            return
        }
        let sel = max(0, min(selectedIndex, entryCount - 1))
        let maxScroll = max(0, entryCount - visibleRows)
        let scroll = max(0, min(scrollOffset, maxScroll))
        self.selectedIndex = sel
        self.scrollOffset = scroll
    }

    /// Find an entry index by start cluster (used when restoring viewer state
    /// after a deep sleep wake — the file is identified by its FAT cluster
    /// rather than its name to survive renames).
    func indexOfEntry(cluster: UInt32, fileSize: UInt32) -> Int? {
        for i in 0..<entryCount {
            if entries[i].cluster == cluster && entries[i].fileSize == fileSize {
                return i
            }
        }
        return nil
    }

    /// Get an entry by index (returns nil if out of bounds).
    func entry(at index: Int) -> FileEntry? {
        guard index >= 0 && index < entryCount else { return nil }
        return entries[index]
    }

    // MARK: - Action Menu

    /// Open the action menu for the selected file (not directories or "..").
    mutating func openActionMenu() {
        guard entryCount > 0 else { return }
        let entry = entries[selectedIndex]
        if entry.isDirectory { return }
        mode = .actionMenu
        actionIndex = 0
    }

    /// Close the action menu / confirmation dialog.
    mutating func closeActionMenu() {
        mode = .normal
        actionIndex = 0
    }

    /// Navigate within the action menu or confirmation dialog.
    mutating func actionMoveUp() {
        actionIndex = actionIndex == 0 ? 1 : 0
    }

    /// Navigate within the action menu or confirmation dialog.
    mutating func actionMoveDown() {
        actionIndex = actionIndex == 0 ? 1 : 0
    }

    /// Get the selected action in action menu mode.
    func selectedAction() -> Action {
        actionIndex == 0 ? .copy : .delete
    }

    /// Enter delete confirmation mode.
    mutating func enterConfirmDelete() {
        mode = .confirmDelete
        actionIndex = 0  // 0 = yes, 1 = no
    }

    /// Whether "Yes" is selected in the confirmation dialog.
    var isConfirmYes: Bool { actionIndex == 0 }

    /// Draw the file list into the framebuffer.
    func draw(fb: Framebuffer) {
        let scale = UIRenderer.fontScale
        let gh = FontData.glyphHeight
        let charW = 8 * scale

        withFontData { font in
            let endIdx = min(scrollOffset + visibleRows, entryCount)

            for i in scrollOffset..<endIdx {
                let rowY = Self.headerHeight + (i - scrollOffset) * Self.rowHeight
                let entry = entries[i]

                let isSelected = (i == selectedIndex)
                if isSelected {
                    fb.drawRect(x: 0, y: rowY, w: fb.width, h: Self.rowHeight, black: true)
                }

                // Icon
                let iconX = Self.leftPadding
                let iconY = rowY + (Self.rowHeight - 24) / 2
                if entry.isDirectory {
                    drawFolderIcon(fb: fb, x: iconX, y: iconY, inverted: isSelected)
                } else {
                    drawFileIcon(fb: fb, x: iconX, y: iconY, inverted: isSelected)
                }

                // Filename (2× scale)
                let textX = Self.textLeftPadding
                let textY = rowY + (Self.rowHeight - gh * scale) / 2
                let maxChars = (fb.width - textX - 8) / charW
                for c in 0..<min(entry.nameLen, maxChars) {
                    fb.drawCharScaled(x: textX + c * charW, y: textY,
                                      char: entry.nameBuffer[c],
                                      fontData: font, glyphHeight: gh, scale: scale,
                                      black: !isSelected)
                }
            }

            // Scrollbar if needed
            if entryCount > visibleRows {
                drawScrollbar(fb: fb)
            }

            // "No files" message if empty
            if entryCount == 0 {
                let msg: StaticString = "No files found"
                let msgW = 14 * charW
                let msgX = (fb.width - msgW) / 2
                let msgY = Self.headerHeight + 40
                fb.drawStringScaled(x: msgX, y: msgY, text: msg,
                                    fontData: font, glyphHeight: gh, scale: scale)
            }

            // Action menu overlay
            if mode == .actionMenu {
                drawActionMenu(fb: fb, font: font, gh: gh, scale: scale, charW: charW)
            } else if mode == .confirmDelete {
                drawConfirmDelete(fb: fb, font: font, gh: gh, scale: scale, charW: charW)
            }
        }
    }

    /// Draw the action menu popup (Copy / Delete).
    private func drawActionMenu(fb: Framebuffer,
                                font: UnsafePointer<UInt8>, gh: Int,
                                scale: Int, charW: Int) {
        let boxW = 200
        let boxH = 100
        let boxX = (fb.width - boxW) / 2
        let boxY = (fb.height - boxH) / 2

        fb.drawRect(x: boxX, y: boxY, w: boxW, h: boxH, black: false)
        fb.drawRectOutline(x: boxX, y: boxY, w: boxW, h: boxH, black: true)
        fb.drawRectOutline(x: boxX + 1, y: boxY + 1, w: boxW - 2, h: boxH - 2, black: true)

        let itemH = 36
        let textX = boxX + 24
        let row0Y = boxY + 10
        let row1Y = row0Y + itemH

        // Highlight selected row
        let selY = actionIndex == 0 ? row0Y : row1Y
        fb.drawRect(x: boxX + 4, y: selY, w: boxW - 8, h: itemH, black: true)

        // "Copy"
        let copyY = row0Y + (itemH - gh * scale) / 2
        let copyStr: StaticString = "Copy"
        fb.drawStringScaled(x: textX, y: copyY, text: copyStr,
                            fontData: font, glyphHeight: gh, scale: scale,
                            black: actionIndex != 0)

        // "Delete"
        let delY = row1Y + (itemH - gh * scale) / 2
        let delStr: StaticString = "Delete"
        fb.drawStringScaled(x: textX, y: delY, text: delStr,
                            fontData: font, glyphHeight: gh, scale: scale,
                            black: actionIndex != 1)
    }

    /// Draw the delete confirmation popup (Yes / No).
    private func drawConfirmDelete(fb: Framebuffer,
                                   font: UnsafePointer<UInt8>, gh: Int,
                                   scale: Int, charW: Int) {
        let boxW = 240
        let boxH = 140
        let boxX = (fb.width - boxW) / 2
        let boxY = (fb.height - boxH) / 2

        fb.drawRect(x: boxX, y: boxY, w: boxW, h: boxH, black: false)
        fb.drawRectOutline(x: boxX, y: boxY, w: boxW, h: boxH, black: true)
        fb.drawRectOutline(x: boxX + 1, y: boxY + 1, w: boxW - 2, h: boxH - 2, black: true)

        // "Delete?" title
        let titleStr: StaticString = "Delete?"
        let titleX = boxX + (boxW - 7 * charW) / 2
        let titleY = boxY + 12
        fb.drawStringScaled(x: titleX, y: titleY, text: titleStr,
                            fontData: font, glyphHeight: gh, scale: scale)

        let itemH = 36
        let textX = boxX + 24
        let row0Y = boxY + 12 + gh * scale + 12
        let row1Y = row0Y + itemH

        let selY = actionIndex == 0 ? row0Y : row1Y
        fb.drawRect(x: boxX + 4, y: selY, w: boxW - 8, h: itemH, black: true)

        // "Yes"
        let yesStr: StaticString = "Yes"
        let yesY = row0Y + (itemH - gh * scale) / 2
        fb.drawStringScaled(x: textX, y: yesY, text: yesStr,
                            fontData: font, glyphHeight: gh, scale: scale,
                            black: actionIndex != 0)

        // "No"
        let noStr: StaticString = "No"
        let noY = row1Y + (itemH - gh * scale) / 2
        fb.drawStringScaled(x: textX, y: noY, text: noStr,
                            fontData: font, glyphHeight: gh, scale: scale,
                            black: actionIndex != 1)
    }

    // MARK: - Private

    /// Sort entries[from..<entryCount]: directories first, then files, each group alphabetically (case-insensitive).
    /// Uses insertion sort (small N, no allocations).
    private mutating func sortEntries(from start: Int) {
        for i in (start + 1)..<entryCount {
            // Save entry i
            let tmpDir = entries[i].isDirectory
            let tmpCluster = entries[i].cluster
            let tmpSize = entries[i].fileSize
            let tmpLen = entries[i].nameLen
            let tmpName83 = entries[i].name83
            let tmpExt83 = entries[i].ext83
            // nameBuffer is a pointer; we need to swap contents, not pointers
            let tmpBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: 64)
            for b in 0..<tmpLen { tmpBuf[b] = entries[i].nameBuffer[b] }

            var j = i
            while j > start && entryLessThan(tmpDir, tmpBuf, tmpLen, entries[j - 1]) {
                // move entries[j-1] -> entries[j]
                entries[j].isDirectory = entries[j - 1].isDirectory
                entries[j].cluster = entries[j - 1].cluster
                entries[j].fileSize = entries[j - 1].fileSize
                entries[j].nameLen = entries[j - 1].nameLen
                entries[j].name83 = entries[j - 1].name83
                entries[j].ext83 = entries[j - 1].ext83
                for b in 0..<entries[j - 1].nameLen {
                    entries[j].nameBuffer[b] = entries[j - 1].nameBuffer[b]
                }
                j -= 1
            }
            entries[j].isDirectory = tmpDir
            entries[j].cluster = tmpCluster
            entries[j].fileSize = tmpSize
            entries[j].nameLen = tmpLen
            entries[j].name83 = tmpName83
            entries[j].ext83 = tmpExt83
            for b in 0..<tmpLen { entries[j].nameBuffer[b] = tmpBuf[b] }
            tmpBuf.deallocate()
        }
    }

    /// Returns true if (aDir, aName) should come before entry b.
    /// Directories before files; within same type, case-insensitive alphabetical.
    private func entryLessThan(_ aDir: Bool, _ aBuf: UnsafeMutablePointer<UInt8>, _ aLen: Int,
                               _ b: FileEntry) -> Bool {
        if aDir && !b.isDirectory { return true }
        if !aDir && b.isDirectory { return false }
        let minLen = aLen < b.nameLen ? aLen : b.nameLen
        for i in 0..<minLen {
            let ca = toLower(aBuf[i])
            let cb = toLower(b.nameBuffer[i])
            if ca < cb { return true }
            if ca > cb { return false }
        }
        return aLen < b.nameLen
    }

    /// ASCII tolower.
    private func toLower(_ c: UInt8) -> UInt8 {
        (c >= 0x41 && c <= 0x5A) ? c + 32 : c
    }

    /// Format an 8.3 FAT name into a readable string. Returns length.
    private func format83Name(entry: FATFileSystem.DirEntry, into buf: UnsafeMutablePointer<UInt8>) -> Int {
        var pos = 0
        let nameLower = entry.ntRes & 0x08 != 0
        let extLower = entry.ntRes & 0x10 != 0

        let nameBytes = entry.name
        for i in 0..<8 {
            let ch: UInt8
            switch i {
            case 0: ch = nameBytes.0
            case 1: ch = nameBytes.1
            case 2: ch = nameBytes.2
            case 3: ch = nameBytes.3
            case 4: ch = nameBytes.4
            case 5: ch = nameBytes.5
            case 6: ch = nameBytes.6
            default: ch = nameBytes.7
            }
            if ch == 0x20 { break }
            buf[pos] = nameLower && ch >= 0x41 && ch <= 0x5A ? ch + 32 : ch
            pos += 1
        }

        let ext0 = entry.ext.0
        if ext0 != 0x20 {
            buf[pos] = 0x2E
            pos += 1
            let extBytes = entry.ext
            for i in 0..<3 {
                let ch: UInt8
                switch i {
                case 0: ch = extBytes.0
                case 1: ch = extBytes.1
                default: ch = extBytes.2
                }
                if ch == 0x20 { break }
                buf[pos] = extLower && ch >= 0x41 && ch <= 0x5A ? ch + 32 : ch
                pos += 1
            }
        }
        return pos
    }

    /// Draw a folder icon (24×20 pixels, scaled up).
    private func drawFolderIcon(fb: Framebuffer, x: Int, y: Int, inverted: Bool) {
        let c = !inverted
        // Tab top
        fb.drawRect(x: x, y: y, w: 10, h: 2, black: c)
        // Body outline
        fb.drawRect(x: x, y: y + 2, w: 24, h: 2, black: c)          // top
        fb.drawRect(x: x, y: y + 18, w: 24, h: 2, black: c)         // bottom
        fb.drawRect(x: x, y: y + 2, w: 2, h: 18, black: c)          // left
        fb.drawRect(x: x + 22, y: y + 2, w: 2, h: 18, black: c)     // right
    }

    /// Draw a file icon (20×24 pixels, scaled up).
    private func drawFileIcon(fb: Framebuffer, x: Int, y: Int, inverted: Bool) {
        let c = !inverted
        // Top edge (shorter for corner fold)
        fb.drawRect(x: x, y: y, w: 16, h: 2, black: c)
        // Left side
        fb.drawRect(x: x, y: y, w: 2, h: 22, black: c)
        // Bottom
        fb.drawRect(x: x, y: y + 20, w: 20, h: 2, black: c)
        // Right side (from fold)
        fb.drawRect(x: x + 18, y: y + 4, w: 2, h: 18, black: c)
        // Fold diagonal (simplified as L-shape)
        fb.drawRect(x: x + 16, y: y, w: 2, h: 6, black: c)
        fb.drawRect(x: x + 16, y: y + 4, w: 4, h: 2, black: c)
    }

    /// Draw a scrollbar on the right edge.
    private func drawScrollbar(fb: Framebuffer) {
        let trackX = fb.width - 6
        let trackY = Self.headerHeight
        let trackH = visibleRows * Self.rowHeight

        // Track (2px wide)
        fb.drawRect(x: trackX + 2, y: trackY, w: 2, h: trackH, black: true)

        // Thumb
        let thumbH = max(trackH * visibleRows / entryCount, 16)
        let thumbY = trackY + (trackH - thumbH) * scrollOffset / max(entryCount - visibleRows, 1)
        fb.drawRect(x: trackX, y: thumbY, w: 6, h: thumbH, black: true)
    }
}
