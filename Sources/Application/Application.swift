import Registers

@main
struct Application {
    static func main() {
        clearBSS()
        disableWatchdogs()
        setupTrapVector()

        // Clear RTC pad hold left over from deep sleep (RTC domain survives reset)
        PowerManager.clearSleepState()

        // Check if this boot is a deep sleep wake — RTC store0 holds the
        // marker. The flag determines whether we attempt to restore the
        // previous screen via RESUME.DAT (see resume path below).
        let isResume = PowerManager.readAndClearWakeMarker()

        usbPrint("=== InkedFeather ===")
        if isResume {
            usbPrint("wake from deep sleep")
        } else {
            usbPrint("boot OK")
        }

        // SPI2 peripheral init (10 MHz)
        let spi = SPIDriver(
            sclkPin: Pin(number: 8),
            mosiPin: Pin(number: 10),
            misoPin: Pin(number: 7)
        )
        spi.initialize(clkdivPre: 0, clkcntN: 7)

        // Power manager — initialized before BatteryMonitor.read() so the
        // USB detect pin reports valid state for the charging-offset decision.
        PowerManager.initialize()

        // Battery monitor
        BatteryMonitor.initialize()
        delayUs(10_000)  // ADC warm-up
        let battStatus = BatteryMonitor.read()

        // Button driver
        ButtonDriver.initialize()

        // Framebuffer (480x800 portrait, rotated 270)
        let fb = Framebuffer(rotated: true)

        // E-ink display
        let einkIO = EInkPins(spi: spi)
        var eink = EInkDisplay(io: einkIO)
        eink.initialize()

        // Skip the intermediate boot/Resuming screen entirely.
        //
        // Originally we drew a boot logo / "Resuming..." overlay here so the
        // user got immediate feedback while SD/FAT/font initialized. After the
        // FAT-sector cache landed, time-to-ready is short enough that the cost
        // of a throwaway refresh hurts more than it helps. The panel keeps
        // showing the sleep image (or whatever was on screen at power-off)
        // until the real final screen is drawn below; that draw runs through
        // pseudoFullRefresh so the prior content is wiped cleanly.
        var ui = UIRenderer()

        // SD card
        var sd = SDCard(spi: spi)
        let sdOk = sd.initialize()
        if sdOk { usbPrint("SD OK") } else { usbPrint("SD FAIL") }

        // FAT filesystem
        var fat = FATFileSystem(sd: sd)
        var fatOk = false
        if sdOk {
            fatOk = fat.mount()
            if fatOk { usbPrint("FAT OK") } else { usbPrint("FAT FAIL") }
        }

        // File list view
        var fileList = FileListView(displayHeight: fb.height)
        if fatOk {
            fileList.loadFromRoot(fat: &fat)
        }

        // Bitmap font (loaded from font.bin on SD card root)
        var bitmapFont = BitmapFont()
        var fontCluster: UInt32 = 0
        var fontFileSize: UInt32 = 0
        if fatOk {
            fat.listRootDirectory { entry in
                if !entry.isDirectory && isFontBinEntry(entry) {
                    fontCluster = entry.cluster
                    fontFileSize = entry.fileSize
                    return false
                }
                return true
            }
            if fontCluster != 0
               && bitmapFont.load(fat: &fat, cluster: fontCluster,
                                  fileSize: fontFileSize) {
                usbPrint("Font OK")
            } else {
                usbPrint("Font: not found, ASCII fallback")
            }
        }

        // Text viewer
        var textViewer = TextViewer()
        if bitmapFont.loaded {
            textViewer.configureFont(font: bitmapFont)
        }

        // Image viewer
        var imageViewer = ImageViewer()

        // Directory navigation stack (cluster of parent directories)
        let dirStack: UnsafeMutablePointer<UInt32> = .allocate(capacity: 16)
        var dirDepth = 0

        // Resume path: if waking from deep sleep, attempt to restore the
        // previous screen and viewer state from RESUME.DAT. On any failure
        // we fall through to a normal cold start at the file browser root.
        var initialScreen: UIRenderer.Screen = .fileBrowser
        var resumed = false
        if isResume && fatOk {
            if let state = ResumeStorage.load(fat: &fat, dirStack: dirStack) {
                dirDepth = Int(state.dirDepth)
                resumed = restoreFromResumeState(state: state,
                                                 fileList: &fileList,
                                                 textViewer: &textViewer,
                                                 imageViewer: &imageViewer,
                                                 fat: &fat,
                                                 dirStack: dirStack,
                                                 dirDepth: &dirDepth,
                                                 initialScreen: &initialScreen)
                if resumed {
                    usbPrint("Resumed")
                } else {
                    usbPrint("Resume failed - cold start")
                }
            } else {
                usbPrint("RESUME.DAT missing/invalid")
            }
            // If restoration failed, ensure we end up at a clean root view.
            if !resumed {
                dirDepth = 0
                if fatOk {
                    fileList.loadFromRoot(fat: &fat)
                }
            }
        }

        // Switch to the chosen screen and render it. The first commit goes
        // through pseudoFullRefresh so the sleep image (or any previous
        // on-screen content) is fully replaced.
        ui.setScreen(initialScreen)
        switch initialScreen {
        case .fileBrowser, .boot:
            UIRenderer.drawFileBrowser(fb: fb, fileList: fileList,
                                       batteryStatus: battStatus)
        case .textViewer:
            PowerManager.setCPU160MHz()
            UIRenderer.drawTextViewer(fb: fb, textViewer: textViewer,
                                      font: &bitmapFont, fat: &fat,
                                      batteryStatus: battStatus)
            PowerManager.setCPU80MHz()
        case .imageViewer:
            UIRenderer.drawImageViewer(fb: fb, imageViewer: &imageViewer,
                                       fat: &fat, batteryStatus: battStatus)
        }
        fb.withBuffer { eink.pseudoFullRefresh($0) }

        // Drop CPU to 80 MHz for the idle main loop.
        // Image decode paths boost to 160 MHz on demand.
        PowerManager.setCPU80MHz()

        // Main loop
        var lastButton: ButtonDriver.Button = .none
        var lastBatteryMs: UInt32 = TimerDriver.millis()
        var lastActivityMs: UInt32 = lastBatteryMs
        var lastResumeSaveMs: UInt32 = lastBatteryMs
        var currentBattStatus = battStatus
        var wasUSBConnected: Bool = PowerManager.isUSBConnected()

        while true {
            let btn = ButtonDriver.poll()

            // Detect rising edge (new press)
            if btn != lastButton {
                if btn != .none {
                    lastActivityMs = TimerDriver.millis()
                    handleButton(btn, ui: &ui, fb: fb, eink: &eink,
                                 fileList: &fileList,
                                 fat: &fat, fatOk: fatOk,
                                 dirStack: dirStack, dirDepth: &dirDepth,
                                 textViewer: &textViewer,
                                 imageViewer: &imageViewer,
                                 bitmapFont: &bitmapFont)
                }
                lastButton = btn
            }

            // Periodic battery check (~30 seconds).
            // Redraw on either SOC change or charging-state transition so the
            // bolt indicator appears/disappears on plug/unplug.
            let now = TimerDriver.millis()
            if (now &- lastBatteryMs) >= 30_000 {
                lastBatteryMs = now
                let newStatus = BatteryMonitor.read()
                if newStatus.percentage != currentBattStatus.percentage
                   || newStatus.isCharging != currentBattStatus.isCharging {
                    currentBattStatus = newStatus
                    if ui.currentScreen == .fileBrowser
                       || ui.currentScreen == .textViewer
                       || ui.currentScreen == .imageViewer {
                        ui.invalidate()
                    }
                }
            }

            // Periodic resume save (~60 seconds, only if position changed)
            if (now &- lastResumeSaveMs) >= 60_000 {
                lastResumeSaveMs = now
                if ui.currentScreen == .textViewer {
                    textViewer.saveIfNeeded(fat: &fat)
                }
            }

            // Redraw if needed
            if ui.consumeRedraw() {
                switch ui.currentScreen {
                case .boot:
                    UIRenderer.drawBootScreen(fb: fb)
                    fb.withBuffer { eink.pseudoFullRefresh($0) }
                case .fileBrowser:
                    redrawFileBrowser(fb: fb, eink: &eink,
                                     fileList: fileList, batteryStatus: currentBattStatus)
                case .textViewer:
                    redrawTextViewer(fb: fb, eink: &eink,
                                    textViewer: textViewer,
                                    bitmapFont: &bitmapFont, fat: &fat,
                                    batteryStatus: currentBattStatus)
                case .imageViewer:
                    redrawImageViewer(fb: fb, eink: &eink, fat: &fat,
                                     imageViewer: &imageViewer, batteryStatus: currentBattStatus)
                }
            }

            // Track USB disconnect edge — reset idle timer when unplugged
            let usbNow = PowerManager.isUSBConnected()
            if wasUSBConnected && !usbNow {
                lastActivityMs = now
            }
            wasUSBConnected = usbNow

            // Auto-sleep check (~1 hour idle, skip if USB connected).
            // enterSleep does not return — the chip resets on wake.
            if !usbNow {
                if (now &- lastActivityMs) >= 3_600_000 {
                    enterSleep(fb: fb, eink: &eink, ui: &ui,
                               fat: &fat, fatOk: fatOk,
                               fileList: fileList,
                               textViewer: &textViewer,
                               imageViewer: &imageViewer,
                               dirStack: dirStack, dirDepth: dirDepth)
                }
            }

            USBController.pollBusReset()
            delayUs(50_000)  // 50ms poll interval
        }
    }
}

// MARK: - Button Handling

private func handleButton(_ btn: ButtonDriver.Button, ui: inout UIRenderer, fb: Framebuffer,
                           eink: inout EInkDisplay,
                           fileList: inout FileListView,
                           fat: inout FATFileSystem, fatOk: Bool,
                           dirStack: UnsafeMutablePointer<UInt32>,
                           dirDepth: inout Int,
                           textViewer: inout TextViewer,
                           imageViewer: inout ImageViewer,
                           bitmapFont: inout BitmapFont) {
    switch ui.currentScreen {
    case .boot:
        // Any button → switch to file browser
        ui.setScreen(.fileBrowser)

    case .fileBrowser:
        // Handle action menu / confirm modes first
        if fileList.mode == .actionMenu {
            handleActionMenu(btn, ui: &ui, fb: fb, eink: &eink,
                             fileList: &fileList, fat: &fat,
                             dirStack: dirStack, dirDepth: dirDepth)
            break
        }
        if fileList.mode == .confirmDelete {
            handleConfirmDelete(btn, ui: &ui, fb: fb, eink: &eink,
                                fileList: &fileList, fat: &fat,
                                dirStack: dirStack, dirDepth: dirDepth)
            break
        }

        switch btn {
        case .up:
            fileList.moveUp()
            ui.invalidate()
        case .down:
            fileList.moveDown()
            ui.invalidate()
        case .confirm:
            if let entry = fileList.selectedEntry() {
                if entry.isDirectory {
                    let name0 = entry.nameBuffer[0]
                    let name1 = entry.nameBuffer[1]
                    if name0 == 0x2E && name1 == 0x2E && entry.nameLen == 2 {
                        // ".." → go back up
                        if dirDepth > 0 {
                            dirDepth -= 1
                            if dirDepth == 0 {
                                fileList.loadFromRoot(fat: &fat)
                            } else {
                                fileList.loadFromDirectory(fat: &fat,
                                                          cluster: dirStack[dirDepth - 1])
                            }
                        }
                    } else {
                        // Enter subdirectory
                        if dirDepth < 16 {
                            dirStack[dirDepth] = entry.cluster
                            dirDepth += 1
                            fileList.loadFromDirectory(fat: &fat, cluster: entry.cluster)
                        }
                    }
                    ui.invalidate()
                } else if isTxtFile(name: entry.nameBuffer, len: entry.nameLen) {
                    showLoadingOverlay(fb: fb, eink: &eink)
                    textViewer.loadFile(fat: &fat,
                                        cluster: entry.cluster,
                                        fileSize: entry.fileSize,
                                        name: entry.nameBuffer,
                                        nameLength: entry.nameLen)
                    ui.setScreen(.textViewer)
                } else if isImageFile(name: entry.nameBuffer, len: entry.nameLen) {
                    showLoadingOverlay(fb: fb, eink: &eink)
                    imageViewer.loadFile(fat: &fat,
                                         cluster: entry.cluster,
                                         fileSize: entry.fileSize,
                                         name: entry.nameBuffer,
                                         nameLength: entry.nameLen)
                    ui.setScreen(.imageViewer)
                }
            }
        case .back:
            // Go back to parent directory
            if dirDepth > 0 {
                dirDepth -= 1
                if dirDepth == 0 {
                    fileList.loadFromRoot(fat: &fat)
                } else {
                    fileList.loadFromDirectory(fat: &fat,
                                              cluster: dirStack[dirDepth - 1])
                }
                ui.invalidate()
            }
        case .right:
            fileList.openActionMenu()
            ui.invalidate()
        case .power:
            enterSleep(fb: fb, eink: &eink, ui: &ui,
                       fat: &fat, fatOk: fatOk,
                       fileList: fileList,
                       textViewer: &textViewer,
                       imageViewer: &imageViewer,
                       dirStack: dirStack, dirDepth: dirDepth)
        case .none, .left:
            break
        }

    case .textViewer:
        switch btn {
        case .up:
            textViewer.scrollUp(fat: &fat)
            ui.invalidate()
        case .down:
            textViewer.scrollDown(fat: &fat)
            ui.invalidate()
        case .left:
            textViewer.pageUp(fat: &fat)
            ui.invalidate()
        case .right:
            textViewer.pageDown(fat: &fat)
            ui.invalidate()
        case .back:
            textViewer.saveResumeState(fat: &fat)
            textViewer.releaseBuffers()
            ui.setScreen(.fileBrowser)
        case .power:
            textViewer.saveResumeState(fat: &fat)
            enterSleep(fb: fb, eink: &eink, ui: &ui,
                       fat: &fat, fatOk: fatOk,
                       fileList: fileList,
                       textViewer: &textViewer,
                       imageViewer: &imageViewer,
                       dirStack: dirStack, dirDepth: dirDepth)
        case .confirm, .none:
            break
        }

    case .imageViewer:
        switch btn {
        case .back:
            imageViewer.releaseHeavyDecoders()
            ui.setScreen(.fileBrowser)
        case .power:
            enterSleep(fb: fb, eink: &eink, ui: &ui,
                       fat: &fat, fatOk: fatOk,
                       fileList: fileList,
                       textViewer: &textViewer,
                       imageViewer: &imageViewer,
                       dirStack: dirStack, dirDepth: dirDepth)
        case .up, .down, .left, .right, .confirm, .none:
            break
        }
    }
}

// MARK: - File Action Handlers

private func handleActionMenu(
    _ btn: ButtonDriver.Button,
    ui: inout UIRenderer, fb: Framebuffer, eink: inout EInkDisplay,
    fileList: inout FileListView, fat: inout FATFileSystem,
    dirStack: UnsafeMutablePointer<UInt32>, dirDepth: Int
) {
    switch btn {
    case .up:
        fileList.actionMoveUp()
        ui.invalidate()
    case .down:
        fileList.actionMoveDown()
        ui.invalidate()
    case .confirm:
        let action = fileList.selectedAction()
        if action == .delete {
            fileList.enterConfirmDelete()
            ui.invalidate()
        } else {
            // Copy
            if let entry = fileList.selectedEntry() {
                showOperationOverlay(fb: fb, eink: &eink, text: "Copying...")
                let dirCluster = dirDepth == 0 ? UInt32(0) : dirStack[dirDepth - 1]
                let copyName = buildCopyName(
                    src: entry.nameBuffer, srcLen: entry.nameLen)
                let ok = fat.copyFileWithLFN(
                    srcCluster: entry.cluster,
                    srcSize: entry.fileSize,
                    dirCluster: dirCluster,
                    lfn: UnsafePointer(copyName.buf),
                    lfnLen: copyName.len)
                copyName.buf.deallocate()
                fileList.closeActionMenu()
                reloadFileList(fileList: &fileList, fat: &fat,
                               dirStack: dirStack, dirDepth: dirDepth)
                ui.invalidate()
                if ok {
                    usbPrint("Copy OK")
                } else {
                    usbPrint("Copy FAIL")
                }
            }
        }
    case .back:
        fileList.closeActionMenu()
        ui.invalidate()
    case .none, .left, .right, .power:
        break
    }
}

private func handleConfirmDelete(
    _ btn: ButtonDriver.Button,
    ui: inout UIRenderer, fb: Framebuffer, eink: inout EInkDisplay,
    fileList: inout FileListView, fat: inout FATFileSystem,
    dirStack: UnsafeMutablePointer<UInt32>, dirDepth: Int
) {
    switch btn {
    case .up:
        fileList.actionMoveUp()
        ui.invalidate()
    case .down:
        fileList.actionMoveDown()
        ui.invalidate()
    case .confirm:
        if fileList.isConfirmYes {
            if let entry = fileList.selectedEntry() {
                showOperationOverlay(fb: fb, eink: &eink, text: "Deleting...")
                let dirCluster = dirDepth == 0 ? UInt32(0) : dirStack[dirDepth - 1]
                let ok = fat.deleteFile(dirCluster: dirCluster,
                                        fileCluster: entry.cluster)
                fileList.closeActionMenu()
                reloadFileList(fileList: &fileList, fat: &fat,
                               dirStack: dirStack, dirDepth: dirDepth)
                ui.invalidate()
                if ok {
                    usbPrint("Delete OK")
                } else {
                    usbPrint("Delete FAIL")
                }
            }
        } else {
            fileList.closeActionMenu()
            ui.invalidate()
        }
    case .back:
        fileList.closeActionMenu()
        ui.invalidate()
    case .none, .left, .right, .power:
        break
    }
}

/// Reload the file list for the current directory.
private func reloadFileList(fileList: inout FileListView, fat: inout FATFileSystem,
                            dirStack: UnsafeMutablePointer<UInt32>, dirDepth: Int) {
    if dirDepth == 0 {
        fileList.loadFromRoot(fat: &fat)
    } else {
        fileList.loadFromDirectory(fat: &fat, cluster: dirStack[dirDepth - 1])
    }
}

/// Build a copy name by inserting "_copy" before the last extension dot.
/// Returns a buffer and length. Caller must deallocate the buffer.
private func buildCopyName(
    src: UnsafeMutablePointer<UInt8>, srcLen: Int
) -> (buf: UnsafeMutablePointer<UInt8>, len: Int) {
    let buf: UnsafeMutablePointer<UInt8> = .allocate(capacity: 128)
    let suffix: StaticString = "_copy"

    // Find last '.' in display name
    var lastDot = -1
    var i = srcLen - 1
    while i >= 0 {
        if src[i] == 0x2E { lastDot = i; break }
        i -= 1
    }

    var pos = 0
    let insertAt = lastDot >= 0 ? lastDot : srcLen

    // Copy chars before the dot (or all chars if no dot)
    for j in 0..<insertAt {
        if pos >= 122 { break }
        buf[pos] = src[j]; pos += 1
    }

    // Insert "_copy"
    suffix.withUTF8Buffer { utf8 in
        for j in 0..<utf8.count {
            if pos >= 122 { break }
            buf[pos] = utf8[j]; pos += 1
        }
    }

    // Copy extension (including the dot)
    if lastDot >= 0 {
        for j in lastDot..<srcLen {
            if pos >= 127 { break }
            buf[pos] = src[j]; pos += 1
        }
    }

    return (buf, pos)
}

/// Show a centered operation overlay and partial-refresh.
private func showOperationOverlay(fb: Framebuffer, eink: inout EInkDisplay,
                                  text: StaticString) {
    let boxW = 224
    let boxH = 64
    let boxX = (UIRenderer.screenWidth - boxW) / 2
    let boxY = (UIRenderer.screenHeight - boxH) / 2

    fb.drawRect(x: boxX, y: boxY, w: boxW, h: boxH, black: false)
    fb.drawRectOutline(x: boxX, y: boxY, w: boxW, h: boxH, black: true)
    fb.drawRectOutline(x: boxX + 1, y: boxY + 1, w: boxW - 2, h: boxH - 2, black: true)

    withFontData { font in
        var textLen = 0
        text.withUTF8Buffer { utf8 in textLen = utf8.count }
        let textW = textLen * UIRenderer.charWidth
        let textX = boxX + (boxW - textW) / 2
        let textY = boxY + (boxH - UIRenderer.charHeight) / 2
        fb.drawStringScaled(x: textX, y: textY, text: text,
                            fontData: font, glyphHeight: FontData.glyphHeight,
                            scale: UIRenderer.fontScale)
    }

    fb.withBuffer { eink.writeFramebuffer($0) }
    eink.partialRefresh()
}

/// Check if a filename ends with ".bmp", ".png", ".jpg", or ".jpeg" (case-insensitive).
private func isImageFile(name: UnsafeMutablePointer<UInt8>, len: Int) -> Bool {
    if len >= 4 {
        let dot = name[len - 4]
        let e1 = name[len - 3] | 0x20
        let e2 = name[len - 2] | 0x20
        let e3 = name[len - 1] | 0x20
        // .bmp
        if dot == 0x2E && e1 == 0x62 && e2 == 0x6D && e3 == 0x70 { return true }
        // .png
        if dot == 0x2E && e1 == 0x70 && e2 == 0x6E && e3 == 0x67 { return true }
        // .jpg
        if dot == 0x2E && e1 == 0x6A && e2 == 0x70 && e3 == 0x67 { return true }
    }
    // .jpeg
    if len >= 5 {
        let dot = name[len - 5]
        let j = name[len - 4] | 0x20
        let p = name[len - 3] | 0x20
        let e = name[len - 2] | 0x20
        let g = name[len - 1] | 0x20
        if dot == 0x2E && j == 0x6A && p == 0x70 && e == 0x65 && g == 0x67 { return true }
    }
    return false
}

/// Check if a DirEntry matches "FONT.BIN" in 8.3 SFN format (case-insensitive).
/// SFN stores uppercase padded: name = "FONT    ", ext = "BIN".
private func isFontBinEntry(_ entry: FATFileSystem.DirEntry) -> Bool {
    let n = entry.name
    let e = entry.ext
    // name: 'F','O','N','T',' ',' ',' ',' '  (case-insensitive)
    return (n.0 | 0x20) == 0x66  // f
        && (n.1 | 0x20) == 0x6F  // o
        && (n.2 | 0x20) == 0x6E  // n
        && (n.3 | 0x20) == 0x74  // t
        && n.4 == 0x20 && n.5 == 0x20 && n.6 == 0x20 && n.7 == 0x20
        // ext: 'B','I','N'
        && (e.0 | 0x20) == 0x62  // b
        && (e.1 | 0x20) == 0x69  // i
        && (e.2 | 0x20) == 0x6E  // n
}

/// Check if a filename ends with ".txt" (case-insensitive).
private func isTxtFile(name: UnsafeMutablePointer<UInt8>, len: Int) -> Bool {
    guard len >= 4 else { return false }
    let dot = name[len - 4]
    let t1 = name[len - 3] | 0x20   // to lowercase
    let x  = name[len - 2] | 0x20
    let t2 = name[len - 1] | 0x20
    return dot == 0x2E && t1 == 0x74 && x == 0x78 && t2 == 0x74
}

// MARK: - Sleep Image

/// Check if a DirEntry matches "SLEEP.BMP" in 8.3 SFN format.
private func isSleepBMP(_ entry: FATFileSystem.DirEntry) -> Bool {
    let n = entry.name
    guard (n.0 | 0x20) == 0x73,  // s
          (n.1 | 0x20) == 0x6C,  // l
          (n.2 | 0x20) == 0x65,  // e
          (n.3 | 0x20) == 0x65,  // e
          (n.4 | 0x20) == 0x70,  // p
          n.5 == 0x20, n.6 == 0x20, n.7 == 0x20
    else { return false }

    let e = entry.ext
    return (e.0 | 0x20) == 0x62 && (e.1 | 0x20) == 0x6D && (e.2 | 0x20) == 0x70
}

/// Search the root directory for SLEEP.BMP.
private func findSleepImage(fat: inout FATFileSystem)
    -> (cluster: UInt32, fileSize: UInt32)?
{
    var resultCluster: UInt32 = 0
    var resultSize: UInt32 = 0
    var found = false

    fat.listRootDirectory { entry in
        guard !entry.isDirectory else { return true }
        if isSleepBMP(entry) {
            resultCluster = entry.cluster
            resultSize = entry.fileSize
            found = true
            return false  // stop
        }
        return true
    }

    return found ? (resultCluster, resultSize) : nil
}

/// Decode SLEEP.BMP fullscreen into the framebuffer.
private func drawSleepImage(fat: inout FATFileSystem, fb: Framebuffer,
                            bmpDecoder: inout BMPDecoder,
                            cluster: UInt32, fileSize: UInt32) -> Bool {
    fb.clear()
    guard bmpDecoder.parseHeader(fat: &fat, cluster: cluster, fileSize: fileSize) else { return false }
    PowerManager.setCPU160MHz()
    bmpDecoder.decode(fat: &fat, fb: fb, areaX: 0, areaY: 0,
                      areaW: UIRenderer.screenWidth, areaH: UIRenderer.screenHeight)
    PowerManager.setCPU80MHz()
    return true
}

/// Save state, show sleep screen, then enter deep sleep.
///
/// Deep sleep loses all SRAM, so the chip resets on wake. The next boot
/// reads the wake marker (RTC store0) plus `RESUME.DAT` to restore the
/// active screen, returning the user to where they left off.
///
/// This function does not return.
private func enterSleep(fb: Framebuffer, eink: inout EInkDisplay,
                        ui: inout UIRenderer,
                        fat: inout FATFileSystem, fatOk: Bool,
                        fileList: FileListView,
                        textViewer: inout TextViewer,
                        imageViewer: inout ImageViewer,
                        dirStack: UnsafeMutablePointer<UInt32>,
                        dirDepth: Int) {
    // Immediate feedback before slow image decode
    showSleepingOverlay(fb: fb, eink: &eink)

    var drewImage = false
    if fatOk {
        if let found = findSleepImage(fat: &fat) {
            drewImage = drawSleepImage(fat: &fat, fb: fb,
                                       bmpDecoder: &imageViewer.bmpDecoder,
                                       cluster: found.cluster,
                                       fileSize: found.fileSize)
        }
    }
    if !drewImage {
        UIRenderer.drawSleepScreen(fb: fb)
    }
    fb.withBuffer { eink.pseudoFullRefresh($0) }
    eink.powerOff()

    // Persist text viewer scroll position (READHIST.DAT) for the auto-sleep
    // path — the .power button handler does this explicitly, but auto-sleep
    // does not, so do it here for consistency.
    if ui.currentScreen == .textViewer && fatOk {
        textViewer.saveResumeState(fat: &fat)
    }

    // Build resume state and write it to RESUME.DAT.
    // The wake marker is only set if this succeeds; otherwise the next boot
    // falls back to a normal cold start (FileBrowser at root).
    var saved = false
    if fatOk {
        var state = ResumeState()
        switch ui.currentScreen {
        case .fileBrowser, .boot:
            state.screen = 0
        case .textViewer:
            state.screen = 1
        case .imageViewer:
            state.screen = 2
        }
        state.dirDepth = UInt8(min(dirDepth, ResumeStorage.maxDirDepth))
        state.selectedIndex = Int32(truncatingIfNeeded: fileList.selectedIndex)
        state.scrollOffset = Int32(truncatingIfNeeded: fileList.scrollOffset)
        state.parentDirCluster = dirDepth == 0 ? 0 : dirStack[dirDepth - 1]
        if ui.currentScreen == .textViewer {
            state.fileCluster = textViewer.fileCluster
            state.fileSize = UInt32(truncatingIfNeeded: textViewer.fileSize)
            state.textScrollLine = Int32(truncatingIfNeeded: textViewer.scrollLine)
        } else if ui.currentScreen == .imageViewer {
            state.fileCluster = imageViewer.fileCluster
            state.fileSize = imageViewer.fileSize
        }
        saved = ResumeStorage.save(fat: &fat, state: state,
                                   dirStack: UnsafePointer(dirStack))
    }

    // Disconnect USB before sleep (disable D+ pull-up → host sees disconnect)
    usb_device.conf0.modify { $0.raw.storage = $0.raw.storage & ~(1 << 9) }
    delayUs(10_000)

    // Only set the marker if state was saved — otherwise next boot is cold.
    if saved {
        PowerManager.setWakeMarker()
    }

    // Deep sleep — chip resets on GPIO3 wakeup, never returns from this call.
    PowerManager.enterDeepSleep()
}

// MARK: - Resume Restoration

/// Restore state loaded from RESUME.DAT.
///
/// On success, mutates `fileList`, `textViewer`, `imageViewer`, `dirDepth`,
/// and `initialScreen` to reflect the previous session and returns true.
/// Returns false if the saved file/directory cannot be located, in which
/// case the caller should reset to a clean cold start (file browser root).
private func restoreFromResumeState(state: ResumeState,
                                    fileList: inout FileListView,
                                    textViewer: inout TextViewer,
                                    imageViewer: inout ImageViewer,
                                    fat: inout FATFileSystem,
                                    dirStack: UnsafeMutablePointer<UInt32>,
                                    dirDepth: inout Int,
                                    initialScreen: inout UIRenderer.Screen) -> Bool {
    switch state.screen {
    case 0:  // fileBrowser
        // Load the directory pointed to by dirStack
        if dirDepth == 0 {
            fileList.loadFromRoot(fat: &fat)
        } else {
            fileList.loadFromDirectory(fat: &fat,
                                       cluster: dirStack[dirDepth - 1])
        }
        fileList.restoreCursor(selectedIndex: Int(state.selectedIndex),
                               scrollOffset: Int(state.scrollOffset))
        initialScreen = .fileBrowser
        return true

    case 1:  // textViewer
        // Reload the parent directory containing the file
        if state.parentDirCluster == 0 {
            fileList.loadFromRoot(fat: &fat)
        } else {
            fileList.loadFromDirectory(fat: &fat,
                                       cluster: state.parentDirCluster)
        }
        // Find the file by cluster + size (rename-tolerant)
        guard let idx = fileList.indexOfEntry(cluster: state.fileCluster,
                                              fileSize: state.fileSize),
              let entry = fileList.entry(at: idx)
        else {
            // File missing — fall back to the parent directory's file browser
            // rather than the root, so the user keeps their navigation context.
            initialScreen = .fileBrowser
            return true
        }
        textViewer.loadFile(fat: &fat,
                            cluster: entry.cluster,
                            fileSize: entry.fileSize,
                            name: entry.nameBuffer,
                            nameLength: entry.nameLen)
        // textViewer.loadFile internally restores scrollLine from
        // READHIST.DAT, which was updated by enterSleep before sleeping,
        // so the scroll position is recovered automatically.
        initialScreen = .textViewer
        return true

    case 2:  // imageViewer
        if state.parentDirCluster == 0 {
            fileList.loadFromRoot(fat: &fat)
        } else {
            fileList.loadFromDirectory(fat: &fat,
                                       cluster: state.parentDirCluster)
        }
        guard let idx = fileList.indexOfEntry(cluster: state.fileCluster,
                                              fileSize: state.fileSize),
              let entry = fileList.entry(at: idx)
        else {
            initialScreen = .fileBrowser
            return true
        }
        imageViewer.loadFile(fat: &fat,
                             cluster: entry.cluster,
                             fileSize: entry.fileSize,
                             name: entry.nameBuffer,
                             nameLength: entry.nameLen)
        guard imageViewer.loaded else {
            initialScreen = .fileBrowser
            return true
        }
        initialScreen = .imageViewer
        return true

    default:
        return false
    }
}

// MARK: - Overlays

/// Show a centered "Sleeping..." box on the current framebuffer and partial-refresh.
private func showSleepingOverlay(fb: Framebuffer, eink: inout EInkDisplay) {
    let boxW = 224
    let boxH = 64
    let boxX = (UIRenderer.screenWidth - boxW) / 2
    let boxY = (UIRenderer.screenHeight - boxH) / 2

    // White box with black border
    fb.drawRect(x: boxX, y: boxY, w: boxW, h: boxH, black: false)
    fb.drawRectOutline(x: boxX, y: boxY, w: boxW, h: boxH, black: true)
    fb.drawRectOutline(x: boxX + 1, y: boxY + 1, w: boxW - 2, h: boxH - 2, black: true)

    // "Sleeping..." text centered in box
    withFontData { font in
        let text: StaticString = "Sleeping..."
        let textW = 11 * UIRenderer.charWidth  // 11 chars
        let textX = boxX + (boxW - textW) / 2
        let textY = boxY + (boxH - UIRenderer.charHeight) / 2
        fb.drawStringScaled(x: textX, y: textY, text: text,
                            fontData: font, glyphHeight: FontData.glyphHeight,
                            scale: UIRenderer.fontScale)
    }

    fb.withBuffer { eink.writeFramebuffer($0) }
    eink.partialRefresh()
}

/// Show a centered "Loading..." box on the current framebuffer and refresh.
private func showLoadingOverlay(fb: Framebuffer, eink: inout EInkDisplay) {
    let boxW = 224
    let boxH = 64
    let boxX = (UIRenderer.screenWidth - boxW) / 2
    let boxY = (UIRenderer.screenHeight - boxH) / 2

    // White box with black border
    fb.drawRect(x: boxX, y: boxY, w: boxW, h: boxH, black: false)
    fb.drawRectOutline(x: boxX, y: boxY, w: boxW, h: boxH, black: true)
    fb.drawRectOutline(x: boxX + 1, y: boxY + 1, w: boxW - 2, h: boxH - 2, black: true)

    // "Loading..." text centered in box
    withFontData { font in
        let text: StaticString = "Loading..."
        let textW = 10 * UIRenderer.charWidth  // 10 chars * 16px
        let textX = boxX + (boxW - textW) / 2
        let textY = boxY + (boxH - UIRenderer.charHeight) / 2
        fb.drawStringScaled(x: textX, y: textY, text: text,
                            fontData: font, glyphHeight: FontData.glyphHeight,
                            scale: UIRenderer.fontScale)
    }

    fb.withBuffer { eink.writeFramebuffer($0) }
    eink.partialRefresh()
}

// MARK: - Rendering Helpers

private func redrawFileBrowser(fb: Framebuffer, eink: inout EInkDisplay,
                                fileList: FileListView, batteryStatus: BatteryStatus) {
    UIRenderer.drawFileBrowser(fb: fb, fileList: fileList, batteryStatus: batteryStatus)
    fb.withBuffer { eink.writeFramebuffer($0) }
    eink.partialRefresh()
}

private func redrawTextViewer(fb: Framebuffer, eink: inout EInkDisplay,
                               textViewer: TextViewer,
                               bitmapFont: inout BitmapFont, fat: inout FATFileSystem,
                               batteryStatus: BatteryStatus) {
    PowerManager.setCPU160MHz()
    UIRenderer.drawTextViewer(fb: fb, textViewer: textViewer,
                              font: &bitmapFont, fat: &fat,
                              batteryStatus: batteryStatus)
    PowerManager.setCPU80MHz()
    fb.withBuffer { eink.writeFramebuffer($0) }
    eink.partialRefresh()
}

private func redrawImageViewer(fb: Framebuffer, eink: inout EInkDisplay,
                                fat: inout FATFileSystem,
                                imageViewer: inout ImageViewer,
                                batteryStatus: BatteryStatus) {
    UIRenderer.drawImageViewer(fb: fb, imageViewer: &imageViewer,
                               fat: &fat, batteryStatus: batteryStatus)
    fb.withBuffer { eink.writeFramebuffer($0) }
    eink.partialRefresh()
}
