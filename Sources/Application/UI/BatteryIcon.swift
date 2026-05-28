/// Battery icon renderer for the e-ink display.
///
/// Draws a battery outline with fill level at the specified position.
/// Icon size: 48×28 pixels (scaled for readability on 188 DPI e-ink).
enum BatteryIcon {
    static let iconWidth = 48
    static let iconHeight = 28

    /// Draw a battery icon with the given status.
    static func draw(fb: Framebuffer, x: Int, y: Int, status: BatteryStatus) {
        let bodyW = 40
        let bodyH = 28
        let termW = 8
        let termH = 12
        let border = 2

        // Clear icon area
        fb.drawRect(x: x, y: y, w: iconWidth, h: iconHeight, black: false)

        // Battery body outline (2px thick)
        fb.drawRect(x: x, y: y, w: bodyW, h: border, black: true)                     // top
        fb.drawRect(x: x, y: y + bodyH - border, w: bodyW, h: border, black: true)     // bottom
        fb.drawRect(x: x, y: y, w: border, h: bodyH, black: true)                      // left
        fb.drawRect(x: x + bodyW - border, y: y, w: border, h: bodyH, black: true)     // right

        // Terminal nub (right side, centered vertically)
        let termY = y + (bodyH - termH) / 2
        fb.drawRect(x: x + bodyW, y: termY, w: termW, h: termH, black: true)

        // Fill bar inside the body
        let pad = border + 2
        let maxFillW = bodyW - pad * 2
        let fillW = Int(status.percentage) * maxFillW / 100
        if fillW > 0 {
            fb.drawRect(x: x + pad, y: y + pad,
                        w: fillW, h: bodyH - pad * 2, black: true)
        }

        // Charging bolt overlay: cut a white window inside the body and
        // draw a black lightning bolt on top, so it's visible regardless of
        // the fill level underneath.
        if status.isCharging {
            drawChargingBolt(fb: fb, bodyX: x, bodyY: y, bodyW: bodyW, bodyH: bodyH)
        }
    }

    /// Draw battery icon with percentage text at 2× scale.
    static func drawWithText(fb: Framebuffer, x: Int, y: Int, status: BatteryStatus) {
        draw(fb: fb, x: x, y: y, status: status)

        let textX = x + iconWidth + 6
        let textY = y - 2  // Align with icon top

        withFontData { font in
            var pct = status.percentage
            if pct > 100 { pct = 100 }

            let scale = UIRenderer.fontScale
            let gh = FontData.glyphHeight
            let cw = 8 * scale

            var digits: (UInt8, UInt8, UInt8, UInt8) = (0, 0, 0, 0)
            var len = 0

            if pct >= 100 {
                digits.0 = 0x31; digits.1 = 0x30; digits.2 = 0x30
                len = 3
            } else if pct >= 10 {
                digits.0 = UInt8(0x30 + pct / 10)
                digits.1 = UInt8(0x30 + pct % 10)
                len = 2
            } else {
                digits.0 = UInt8(0x30 + pct)
                len = 1
            }

            for i in 0..<len {
                let ch: UInt8
                switch i {
                case 0: ch = digits.0
                case 1: ch = digits.1
                case 2: ch = digits.2
                default: ch = digits.3
                }
                fb.drawCharScaled(x: textX + i * cw, y: textY, char: ch,
                                  fontData: font, glyphHeight: gh, scale: scale)
            }
            fb.drawCharScaled(x: textX + len * cw, y: textY, char: 0x25,
                              fontData: font, glyphHeight: gh, scale: scale)
        }
    }

    /// Draw a charging lightning bolt centered in the battery body.
    ///
    /// Clears a small white window first so the bolt is visible regardless
    /// of whether the fill bar covers that area.
    private static func drawChargingBolt(fb: Framebuffer,
                                         bodyX: Int, bodyY: Int,
                                         bodyW: Int, bodyH: Int) {
        // Bolt bitmap: 8 wide × 12 tall (per-row horizontal runs).
        let boltW = 8
        let boltH = 12
        let bx = bodyX + (bodyW - boltW) / 2
        let by = bodyY + (bodyH - boltH) / 2

        // White window (2px margin around the bolt) masks the fill bar
        let winPad = 1
        fb.drawRect(x: bx - winPad, y: by - winPad,
                    w: boltW + winPad * 2, h: boltH + winPad * 2, black: false)

        // Black bolt — stylized zig-zag with a widened crossbar.
        //   ....BBB.    row 0 (upper diagonal, 3 px)
        //   ...BBB..    row 1
        //   ..BBB...    row 2
        //   .BBB....    row 3
        //   BBB.....    row 4
        //   BBBBBBBB    row 5 (crossbar, full width)
        //   .BBBBBBB    row 6 (crossbar)
        //   .....BB.    row 7 (lower diagonal, 2 px)
        //   ....BB..    row 8
        //   ...BB...    row 9
        //   ..BB....    row 10
        //   .BB.....    row 11
        fb.drawRect(x: bx + 4, y: by + 0, w: 3, h: 1, black: true)
        fb.drawRect(x: bx + 3, y: by + 1, w: 3, h: 1, black: true)
        fb.drawRect(x: bx + 2, y: by + 2, w: 3, h: 1, black: true)
        fb.drawRect(x: bx + 1, y: by + 3, w: 3, h: 1, black: true)
        fb.drawRect(x: bx + 0, y: by + 4, w: 3, h: 1, black: true)
        fb.drawRect(x: bx + 0, y: by + 5, w: 8, h: 1, black: true)
        fb.drawRect(x: bx + 1, y: by + 6, w: 7, h: 1, black: true)
        fb.drawRect(x: bx + 5, y: by + 7, w: 2, h: 1, black: true)
        fb.drawRect(x: bx + 4, y: by + 8, w: 2, h: 1, black: true)
        fb.drawRect(x: bx + 3, y: by + 9, w: 2, h: 1, black: true)
        fb.drawRect(x: bx + 2, y: by + 10, w: 2, h: 1, black: true)
        fb.drawRect(x: bx + 1, y: by + 11, w: 2, h: 1, black: true)
    }
}
