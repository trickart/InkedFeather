/// Image viewer for displaying BMP and PNG images on the e-ink display.
///
/// Decodes images from the SD card via streaming row-by-row decode
/// and renders them into the 1-bit framebuffer with ordered dithering.
///
/// Layout on 480×800 portrait display:
/// - Header bar: 48px (filename + battery)
/// - Separator: 2px
/// - Image area: remaining 750px, image centered within
struct ImageViewer {
    // MARK: - Display Constants

    static let headerHeight = 48
    static let separatorHeight = 2
    static let contentTop = headerHeight + separatorHeight  // 50

    /// Available area for the image.
    static let imageAreaWidth = UIRenderer.screenWidth     // 480
    static let imageAreaHeight = UIRenderer.screenHeight - contentTop  // 750

    // MARK: - State

    var bmpDecoder = BMPDecoder()
    private var _pngDecoder: PNGDecoder? = nil
    private var _jpegDecoder: JPEGDecoder? = nil

    /// Lazily allocated PNG decoder (~65 KB with Deflate).
    var pngDecoder: PNGDecoder {
        mutating get {
            if _pngDecoder == nil { _pngDecoder = PNGDecoder() }
            return _pngDecoder!
        }
        set { _pngDecoder = newValue }
    }

    /// Lazily allocated JPEG decoder (~38 KB).
    var jpegDecoder: JPEGDecoder {
        mutating get {
            if _jpegDecoder == nil { _jpegDecoder = JPEGDecoder() }
            return _jpegDecoder!
        }
        set { _jpegDecoder = newValue }
    }

    private enum ImageFormat { case none, bmp, png, jpeg }
    private var format: ImageFormat = .none

    private(set) var loaded: Bool = false

    /// Start cluster and size of the currently loaded file (used for resume).
    private(set) var fileCluster: UInt32 = 0
    private(set) var fileSize: UInt32 = 0

    /// Filename for header display.
    private let nameBuffer: UnsafeMutablePointer<UInt8>
    private(set) var nameLen: Int = 0

    init() {
        nameBuffer = .allocate(capacity: 64)
    }

    /// Release PNG/JPEG decoders to free ~103 KB of heap.
    mutating func releaseHeavyDecoders() {
        _pngDecoder?.deallocateBuffers()
        _pngDecoder = nil
        _jpegDecoder?.deallocateBuffers()
        _jpegDecoder = nil
    }

    // MARK: - Loading

    /// Load and parse an image file from the FAT filesystem.
    mutating func loadFile(fat: inout FATFileSystem, cluster: UInt32, fileSize: UInt32,
                           name: UnsafeMutablePointer<UInt8>, nameLength: Int) {
        // Store filename
        nameLen = min(nameLength, 63)
        for i in 0..<nameLen {
            nameBuffer[i] = name[i]
        }

        // Track identity for resume
        self.fileCluster = cluster
        self.fileSize = fileSize

        // Detect format by extension
        if isPNG(name: name, len: nameLength) {
            loaded = pngDecoder.parseHeader(fat: &fat, cluster: cluster, fileSize: fileSize)
            format = loaded ? .png : .none
        } else if isJPEG(name: name, len: nameLength) {
            loaded = jpegDecoder.parseHeader(fat: &fat, cluster: cluster, fileSize: fileSize)
            format = loaded ? .jpeg : .none
        } else {
            loaded = bmpDecoder.parseHeader(fat: &fat, cluster: cluster, fileSize: fileSize)
            format = loaded ? .bmp : .none
        }
    }

    // MARK: - Drawing

    /// Decode and draw the image into the framebuffer.
    mutating func drawImage(fat: inout FATFileSystem, fb: Framebuffer) {
        guard loaded else { return }

        PowerManager.setCPU160MHz()

        switch format {
        case .bmp:
            bmpDecoder.decode(fat: &fat, fb: fb,
                              areaX: 0, areaY: Self.contentTop,
                              areaW: Self.imageAreaWidth,
                              areaH: Self.imageAreaHeight)
        case .png:
            pngDecoder.decode(fat: &fat, fb: fb,
                              areaX: 0, areaY: Self.contentTop,
                              areaW: Self.imageAreaWidth,
                              areaH: Self.imageAreaHeight)
        case .jpeg:
            jpegDecoder.decode(fat: &fat, fb: fb,
                               areaX: 0, areaY: Self.contentTop,
                               areaW: Self.imageAreaWidth,
                               areaH: Self.imageAreaHeight)
        case .none:
            break
        }

        PowerManager.setCPU80MHz()
    }

    /// Draw filename in the header.
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

    // MARK: - Format Detection

    /// Check if a filename ends with ".png" (case-insensitive).
    private func isPNG(name: UnsafeMutablePointer<UInt8>, len: Int) -> Bool {
        guard len >= 4 else { return false }
        let dot = name[len - 4]
        let p = name[len - 3] | 0x20
        let n = name[len - 2] | 0x20
        let g = name[len - 1] | 0x20
        return dot == 0x2E && p == 0x70 && n == 0x6E && g == 0x67
    }

    /// Check if a filename ends with ".jpg" or ".jpeg" (case-insensitive).
    private func isJPEG(name: UnsafeMutablePointer<UInt8>, len: Int) -> Bool {
        // .jpg (3-char extension)
        if len >= 4 {
            let dot = name[len - 4]
            let j = name[len - 3] | 0x20
            let p = name[len - 2] | 0x20
            let g = name[len - 1] | 0x20
            if dot == 0x2E && j == 0x6A && p == 0x70 && g == 0x67 { return true }
        }
        // .jpeg (4-char extension)
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
}
