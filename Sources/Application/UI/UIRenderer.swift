/// Screen state manager and renderer for the e-ink display.
///
/// Manages transitions between screens and renders the active screen
/// into the framebuffer. The display is 480×800 in portrait mode (rotated 270°).
///
/// All text is drawn at 2× scale (16×32 effective pixels per character).
struct UIRenderer {
    enum Screen: UInt8 {
        case boot = 0
        case fileBrowser = 1
        case textViewer = 2
        case imageViewer = 3
    }

    private(set) var currentScreen: Screen = .boot
    private var needsRedraw: Bool = true

    /// Screen dimensions (logical, portrait).
    static let screenWidth = 480
    static let screenHeight = 800

    /// Font scale factor. 2× means 16×32 pixel characters.
    static let fontScale = 2
    static let charWidth = 8 * fontScale   // 16
    static let charHeight = FontData.glyphHeight * fontScale  // 32

    // MARK: - Screen Transitions

    /// Switch to a new screen.
    mutating func setScreen(_ screen: Screen) {
        currentScreen = screen
        needsRedraw = true
    }

    /// Mark the display as needing a redraw.
    mutating func invalidate() {
        needsRedraw = true
    }

    /// Check if a redraw is needed, and clear the flag.
    mutating func consumeRedraw() -> Bool {
        if needsRedraw {
            needsRedraw = false
            return true
        }
        return false
    }

    // MARK: - Boot Screen

    /// Render the boot splash screen using the embedded bitmap logo.
    static func drawBootScreen(fb: Framebuffer) {
        BootLogo.draw(fb: fb)
    }

    // MARK: - File Browser Screen

    /// Render the file browser with header bar.
    static func drawFileBrowser(fb: Framebuffer, fileList: FileListView,
                                batteryStatus: BatteryStatus) {
        fb.clear()
        drawHeader(fb: fb, title: "Files", batteryStatus: batteryStatus)
        // Separator line below header (2px thick)
        fb.drawRect(x: 0, y: FileListView.headerHeight - 2,
                    w: screenWidth, h: 2, black: true)
        fileList.draw(fb: fb)
    }

    // MARK: - Text Viewer Screen

    /// Render the text viewer with header bar and content.
    static func drawTextViewer(fb: Framebuffer, textViewer: TextViewer,
                               font: inout BitmapFont, fat: inout FATFileSystem,
                               batteryStatus: BatteryStatus) {
        fb.clear()
        textViewer.drawHeader(fb: fb, batteryStatus: batteryStatus)
        fb.drawRect(x: 0, y: FileListView.headerHeight - 2,
                    w: screenWidth, h: 2, black: true)
        textViewer.draw(fb: fb, font: &font, fat: &fat)
    }

    // MARK: - Image Viewer Screen

    /// Render the image viewer with header bar and decoded image.
    static func drawImageViewer(fb: Framebuffer, imageViewer: inout ImageViewer,
                                fat: inout FATFileSystem, batteryStatus: BatteryStatus) {
        fb.clear()
        imageViewer.drawHeader(fb: fb, batteryStatus: batteryStatus)
        fb.drawRect(x: 0, y: FileListView.headerHeight - 2,
                    w: screenWidth, h: 2, black: true)
        imageViewer.drawImage(fat: &fat, fb: fb)
    }

    // MARK: - Sleep Screen

    /// Render the sleep screen using the embedded boot logo.
    static func drawSleepScreen(fb: Framebuffer) {
        BootLogo.draw(fb: fb)
    }

    // MARK: - Header Bar

    /// Draw the header bar with title and battery indicator.
    static func drawHeader(fb: Framebuffer, title: StaticString,
                           batteryStatus: BatteryStatus) {
        withFontData { font in
            // Title on the left
            fb.drawStringScaled(x: 8, y: 8, text: title,
                                fontData: font, glyphHeight: FontData.glyphHeight,
                                scale: fontScale)
        }

        // Battery icon on the right
        let batteryX = screenWidth - BatteryIcon.iconWidth - 48 - 8
        BatteryIcon.drawWithText(fb: fb, x: batteryX, y: 8, status: batteryStatus)
    }
}
