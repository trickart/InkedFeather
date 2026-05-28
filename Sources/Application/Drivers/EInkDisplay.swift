/// Driver for the GDEY0426T82 4.26" panel (SSD1677 controller, 480×800).
///
/// The application uses two refresh modes, both driven by the SSD1677
/// partial-refresh waveform (~300 ms, no flicker):
///   - Partial refresh: `writeFramebuffer` + `partialRefresh` — updates
///     a single frame, leaves ghosting for large changes.
///   - Pseudo full refresh: `pseudoFullRefresh` — paints the inverted
///     image then the target image (two partials, ~600 ms) so every
///     pixel is exercised. Used in place of the slow native full-refresh
///     waveform to wipe ghosting on wake or sleep transitions.
///
/// The SSD1677 computes partial waveforms from the diff between
/// RAM[B/W] (0x24, current frame) and RAM[Red] (0x26, previous frame on
/// monochrome panels). `pseudoFullRefresh` seeds 0x26 with the inverted
/// image between phases so phase 2's diff is correct regardless of
/// whether the controller auto-copies after phase 1.
struct EInkDisplay {
    let io: EInkPins

    /// SSD1677 register addresses used here.
    private enum Cmd {
        static let driverOutputControl: UInt8 = 0x01
        static let boosterSoftStart: UInt8 = 0x0C
        static let deepSleep: UInt8 = 0x10
        static let dataEntryMode: UInt8 = 0x11
        static let softwareReset: UInt8 = 0x12
        static let tempSensor: UInt8 = 0x18
        static let masterActivation: UInt8 = 0x20
        static let displayUpdateCtl2: UInt8 = 0x22
        static let writeRAMBW: UInt8 = 0x24
        static let writeRAMRed: UInt8 = 0x26
        static let borderWaveform: UInt8 = 0x3C
        static let setRAMXRange: UInt8 = 0x44
        static let setRAMYRange: UInt8 = 0x45
        static let setRAMXCounter: UInt8 = 0x4E
        static let setRAMYCounter: UInt8 = 0x4F
    }

    /// Display Update Control 2 sequence selector for partial waveform.
    private static let partialUpdateMode: UInt8 = 0xFF

    init(io: EInkPins) {
        self.io = io
    }

    // MARK: - Public API

    mutating func initialize() {
        // Configure control pins. SPI clock/data come from SPIDriver.
        io.cs.setOutput()
        io.cs.high()
        io.dc.setOutput()
        io.dc.high()
        io.rst.setOutput()
        io.rst.high()
        io.busy.setInput()
        // Run the full SSD1677 init once so driver-output / data-entry /
        // booster settings are in known good state. Subsequent partial
        // updates do a lighter re-init.
        fullInit()
    }

    func writeFramebuffer(_ buffer: UnsafePointer<UInt8>) {
        partialInit()
        writeRAM(command: Cmd.writeRAMBW, buffer: buffer)
    }

    func partialRefresh() {
        activate()
    }

    /// Pseudo full refresh: paint the inverted image first, then the
    /// target image, both via the partial-refresh waveform. Total time
    /// is roughly 2× a partial refresh — much faster than a native full
    /// refresh — and the strong inversion step still kicks every pixel
    /// enough to clear large-scale ghosting (e.g. replacing the sleep
    /// image on wake).
    ///
    /// Phase 2 also seeds RAM[Red] (0x26) with the inverted image so the
    /// diff is computed from the correct baseline regardless of whether
    /// the controller auto-copies after the phase-1 partial update.
    func pseudoFullRefresh(_ buffer: UnsafePointer<UInt8>) {
        // Phase 1: drive current screen → inverted.
        partialInit()
        writeRAMInverted(command: Cmd.writeRAMBW, buffer: buffer)
        activate()

        // Phase 2: drive inverted → target.
        partialInit()
        writeRAMInverted(command: Cmd.writeRAMRed, buffer: buffer)
        writeRAM(command: Cmd.writeRAMBW, buffer: buffer)
        activate()
    }

    func powerOff() {
        writeCommand(Cmd.deepSleep)
        writeData(0x01)
        delayUs(100_000)
    }

    // MARK: - Init sequences

    /// Full hardware + software init. Run once from `initialize()` so the
    /// SSD1677's driver-output, data-entry, and booster registers are
    /// programmed; partial updates can rely on these values surviving in
    /// the chip's defaults across the lighter `partialInit` HW reset.
    private func fullInit() {
        hardwareReset()
        waitBusy()

        writeCommand(Cmd.softwareReset)
        waitBusy()

        writeCommand(Cmd.tempSensor)
        writeData(0x80)  // use internal temperature sensor

        writeCommand(Cmd.boosterSoftStart)
        writeData(0xAE); writeData(0xC7); writeData(0xC3); writeData(0xC0); writeData(0x80)

        // Gate count = nativeHeight (480), MUX value = 479.
        let gateLast = Framebuffer.nativeHeight &- 1
        writeCommand(Cmd.driverOutputControl)
        writeData(UInt8(truncatingIfNeeded: gateLast & 0xFF))
        writeData(UInt8(truncatingIfNeeded: (gateLast >> 8) & 0xFF))
        writeData(0x02)

        writeCommand(Cmd.borderWaveform)
        writeData(0x01)

        writeCommand(Cmd.dataEntryMode)
        writeData(0x03)  // X+, Y+

        setRAMWindow()
        setRAMCounter()
        waitBusy()
    }

    /// Minimal re-init used before each partial update. Mirrors the sample
    /// flow: HW reset, restore temperature sensor + border, re-program the
    /// RAM window.
    private func partialInit() {
        hardwareReset()

        writeCommand(Cmd.tempSensor)
        writeData(0x80)

        writeCommand(Cmd.borderWaveform)
        writeData(0x80)  // do not change border during partial update

        setRAMWindow()
        setRAMCounter()
    }

    private func setRAMWindow() {
        // X range covers the source axis (0 .. nativeWidth-1 in pixels).
        let xLast = Framebuffer.nativeWidth &- 1
        writeCommand(Cmd.setRAMXRange)
        writeData(0x00); writeData(0x00)
        writeData(UInt8(truncatingIfNeeded: xLast & 0xFF))
        writeData(UInt8(truncatingIfNeeded: (xLast >> 8) & 0xFF))

        // Y range covers the gate axis (0 .. nativeHeight-1 in pixels).
        let yLast = Framebuffer.nativeHeight &- 1
        writeCommand(Cmd.setRAMYRange)
        writeData(0x00); writeData(0x00)
        writeData(UInt8(truncatingIfNeeded: yLast & 0xFF))
        writeData(UInt8(truncatingIfNeeded: (yLast >> 8) & 0xFF))
    }

    private func setRAMCounter() {
        writeCommand(Cmd.setRAMXCounter)
        writeData(0x00); writeData(0x00)
        writeCommand(Cmd.setRAMYCounter)
        writeData(0x00); writeData(0x00)
    }

    private func hardwareReset() {
        io.rst.low()
        delayUs(10_000)
        io.rst.high()
        delayUs(10_000)
    }

    // MARK: - SPI helpers

    @inline(__always)
    private func writeCommand(_ command: UInt8) {
        io.dc.low()
        io.cs.low()
        io.spi.writeByte(command)
        io.cs.high()
    }

    @inline(__always)
    private func writeData(_ datum: UInt8) {
        io.dc.high()
        io.cs.low()
        io.spi.writeByte(datum)
        io.cs.high()
    }

    /// Stream the framebuffer to the named RAM bank. CS is held LOW for
    /// the whole transfer; SPIDriver.write caps each transaction at 64
    /// bytes, so we chunk through the buffer.
    private func writeRAM(command: UInt8, buffer: UnsafePointer<UInt8>) {
        writeCommand(command)

        io.dc.high()
        io.cs.low()
        var remaining = Framebuffer.bufferBytes
        var p = buffer
        while remaining > 0 {
            let chunk = remaining < 64 ? remaining : 64
            io.spi.write(UnsafeBufferPointer(start: p, count: chunk))
            p = p.advanced(by: chunk)
            remaining &-= chunk
        }
        io.cs.high()
    }

    /// Stream the bitwise inverse of the framebuffer to the named RAM
    /// bank. Uses a 64-byte stack window so we never materialize a full
    /// 48 KB inverted image in heap.
    private func writeRAMInverted(command: UInt8, buffer: UnsafePointer<UInt8>) {
        writeCommand(command)

        io.dc.high()
        io.cs.low()
        var chunk: (UInt64, UInt64, UInt64, UInt64,
                    UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0, 0, 0, 0, 0)
        withUnsafeMutablePointer(to: &chunk) { ptr in
            let raw = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: UInt8.self)
            var remaining = Framebuffer.bufferBytes
            var p = buffer
            while remaining > 0 {
                let n = remaining < 64 ? remaining : 64
                for i in 0..<n { raw[i] = ~p[i] }
                io.spi.write(UnsafeBufferPointer(start: raw, count: n))
                p = p.advanced(by: n)
                remaining &-= n
            }
        }
        io.cs.high()
    }

    /// Kick off a partial-waveform display update.
    private func activate() {
        writeCommand(Cmd.displayUpdateCtl2)
        writeData(Self.partialUpdateMode)
        writeCommand(Cmd.masterActivation)
        waitBusy()
    }

    /// Block until BUSY drops (HIGH = busy on SSD1677). Bounded so a
    /// stuck panel can't hang the device — partial refresh is ~300 ms,
    /// so 5 s is a generous ceiling.
    private func waitBusy() {
        let start = TimerDriver.millis()
        let timeoutMs: UInt32 = 5_000
        while io.busy.read() {
            if (TimerDriver.millis() &- start) > timeoutMs { return }
        }
    }
}
