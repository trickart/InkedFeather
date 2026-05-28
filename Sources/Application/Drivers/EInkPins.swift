/// Pin bundle for the GDEY0426T82 e-ink panel (SSD1677 controller).
///
/// SPI is shared with the SD card. The panel needs four additional GPIO
/// lines: chip select, data/command select, hardware reset, and the
/// busy-output sensed by the host. The numbers here must agree with
/// `PowerManager.preparePinsForSleep`, which holds these lines at safe
/// levels through deep sleep.
struct EInkPins {
    static let csPin = 21
    static let dcPin = 4
    static let rstPin = 5
    static let busyPin = 6

    let spi: SPIDriver
    let cs: Pin
    let dc: Pin
    let rst: Pin
    let busy: Pin

    init(spi: SPIDriver) {
        self.spi = spi
        self.cs = Pin(number: Self.csPin)
        self.dc = Pin(number: Self.dcPin)
        self.rst = Pin(number: Self.rstPin)
        self.busy = Pin(number: Self.busyPin)
    }
}
