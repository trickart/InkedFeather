import Registers

/// Power management for ESP32-C3.
///
/// Handles USB power detection, deep sleep entry, and GPIO wakeup.
///
/// - USB detection: GPIO20 (USB D-) is high when USB is connected
/// - Deep sleep: RTC_CNTL deep sleep with GPIO wakeup
/// - Wakeup: Power button press (GPIO3 low = active LOW)
enum PowerManager {
    /// RTC_CNTL base address.
    private static let rtcBase: UInt32 = 0x6000_8000

    /// RTC_CNTL register offsets (from SVD / ESP-IDF).
    private static let options0Offset: UInt32      = 0x00
    private static let state0Offset: UInt32        = 0x18
    private static let wakeupStateOffset: UInt32   = 0x3C
    private static let intRawOffset: UInt32        = 0x44
    private static let intClrOffset: UInt32        = 0x4C
    private static let extWakeupConfOffset: UInt32 = 0x64
    private static let slpRejectConfOffset: UInt32 = 0x68
    private static let clkConfOffset: UInt32       = 0x70
    private static let biasConfOffset: UInt32      = 0x7C
    private static let digPwcOffset: UInt32        = 0x88
    private static let digIsoOffset: UInt32        = 0x8C
    private static let padHoldOffset: UInt32       = 0xD0
    private static let gpioWakeupOffset: UInt32    = 0x110
    private static let store0Offset: UInt32        = 0x50

    /// Magic value written to RTC store0 to mark a deep sleep wake.
    /// Survives deep sleep (RTC domain stays powered) but is cleared on
    /// full power-off (battery removal) or hardware reset.
    private static let wakeMarkerMagic: UInt32 = 0x494E_4B44  // "INKD"

    /// GPIO20 = USB D- line. High when USB is connected.
    private static let usbDetectPin = Pin(number: 20)

    /// Clear RTC pad hold left over from deep sleep.
    /// PAD_HOLD survives reset (RTC domain stays powered) and the ESP-IDF
    /// bootloader does not clear it.
    static func clearSleepState() {
        regStore(rtcBase + padHoldOffset, 0)
    }

    /// Initialize power management (USB detection pin).
    static func initialize() {
        usbDetectPin.setInput(pullUp: false, pullDown: true)
    }

    /// Check if USB power is connected.
    static func isUSBConnected() -> Bool {
        usbDetectPin.read()
    }

    /// Set the wake marker in RTC store0.
    ///
    /// Called immediately before `enterDeepSleep()` to signal that the next
    /// boot should attempt state restoration. RTC store0 survives deep sleep
    /// but is cleared on full power loss or hardware reset.
    static func setWakeMarker() {
        regStore(rtcBase + store0Offset, wakeMarkerMagic)
    }

    /// Check the wake marker and clear it.
    ///
    /// Returns true if the previous boot was a deep sleep wake (and the
    /// caller should attempt to restore state). Always clears the marker
    /// so a subsequent boot without sleep entry behaves normally.
    static func readAndClearWakeMarker() -> Bool {
        let value = regLoad(rtcBase + store0Offset)
        regStore(rtcBase + store0Offset, 0)
        return value == wakeMarkerMagic
    }

    /// Enter deep sleep with GPIO wakeup.
    ///
    /// The chip will wake up when the power button is pressed (GPIO3 pulled low).
    /// After wakeup, the chip resets and re-executes from the beginning.
    ///
    /// SPI/display pins are set to safe states and held via PAD_HOLD so that
    /// SD cards can be safely inserted or removed while the chip sleeps.
    ///
    /// Sequence follows ESP-IDF's rtc_sleep_init() + rtc_deep_sleep_start().
    static func enterDeepSleep() {
        // Wait for power button release to avoid immediate re-wakeup
        while !powerPin.read() {
            delayUs(50_000)
        }
        delayUs(100_000)

        // Put SPI bus and display pins into safe states before sleep.
        // Digital GPIOs lose state during deep sleep unless held via PAD_HOLD.
        preparePinsForSleep()

        // Configure GPIO3 as input with pull-up for wakeup
        powerPin.setInput(pullUp: true)

        // --- GPIO wakeup configuration ---

        // Enable RTC IO clock gate + configure GPIO3 wakeup
        var gpioWakeup = regLoad(rtcBase + gpioWakeupOffset)
        gpioWakeup |= (1 << 7)         // gpio_pin_clk_gate = 1
        gpioWakeup &= ~(0x3F << 26)    // Disable all wakeup enables
        gpioWakeup &= ~(0x7 << 14)     // Clear GPIO3 INT_TYPE (bits 14-16)
        gpioWakeup |= (4 << 14)        // GPIO3: low level trigger
        gpioWakeup |= (1 << 28)        // GPIO3 wakeup enable
        regStore(rtcBase + gpioWakeupOffset, gpioWakeup)

        // Enable GPIO wakeup filter
        var extConf = regLoad(rtcBase + extWakeupConfOffset)
        extConf |= (1 << 31)
        regStore(rtcBase + extWakeupConfOffset, extConf)

        // Enable pad hold for power button + SPI bus + display pins.
        // Maintains safe pin states during deep sleep so SD cards can be
        // inserted/removed without encountering floating SPI lines.
        //   GPIO3=power, 4=DC, 5=RST, 6=BUSY, 7=MISO, 8=SCLK, 10=MOSI,
        //   12=SD_CS, 21=E-ink_CS
        var padHold = regLoad(rtcBase + padHoldOffset)
        padHold |= (1 << 3) | (1 << 4) | (1 << 5) | (1 << 6)
              | (1 << 7) | (1 << 8) | (1 << 10) | (1 << 12) | (1 << 21)
        regStore(rtcBase + padHoldOffset, padHold)

        // Clear wakeup status (toggle bit 6)
        var gwk = regLoad(rtcBase + gpioWakeupOffset)
        gwk |= (1 << 6)
        regStore(rtcBase + gpioWakeupOffset, gwk)
        gwk &= ~(1 << 6)
        regStore(rtcBase + gpioWakeupOffset, gwk)

        // --- Power domain configuration (rtc_sleep_init equivalent) ---

        // DIG_ISO: clear WiFi/BT force-noiso so they can be isolated
        var digIso = regLoad(rtcBase + digIsoOffset)
        digIso &= ~(1 << 29)   // WIFI_FORCE_NOISO = 0
        digIso &= ~(1 << 23)   // BT_FORCE_NOISO = 0
        regStore(rtcBase + digIsoOffset, digIso)

        // DIG_PWC: enable power-down for digital domain, WiFi, BT
        var digPwc = regLoad(rtcBase + digPwcOffset)
        digPwc &= ~(1 << 18)   // WIFI_FORCE_PU = 0
        digPwc &= ~(1 << 12)   // BT_FORCE_PU = 0
        digPwc |= (1 << 31)    // DG_WRAP_PD_EN = 1 (digital domain power-down)
        digPwc |= (1 << 30)    // WIFI_PD_EN = 1
        digPwc |= (1 << 27)    // BT_PD_EN = 1
        digPwc |= (1 << 16)    // FASTMEM_FORCE_LPU = 1
        digPwc |= (1 << 4)     // LSLP_MEM_FORCE_PU = 1
        regStore(rtcBase + digPwcOffset, digPwc)

        // BIAS_CONF: configure for deep sleep
        var bias = regLoad(rtcBase + biasConfOffset)
        bias &= ~(0xF << 22)   // DBG_ATTEN_MONITOR = 0
        bias = (bias & ~(0xF << 18)) | (0xF << 18)  // DBG_ATTEN_DEEP_SLP = 15
        bias |= (1 << 16)      // BIAS_SLEEP_DEEP_SLP = 1
        bias |= (1 << 14)      // PD_CUR_DEEP_SLP = 1
        bias &= ~(1 << 17)     // BIAS_SLEEP_MONITOR = 0
        bias &= ~(1 << 15)     // PD_CUR_MONITOR = 0
        regStore(rtcBase + biasConfOffset, bias)

        // CLK_CONF: allow clocks to be gated during sleep
        var clkConf = regLoad(rtcBase + clkConfOffset)
        clkConf &= ~(1 << 26)  // CK8M_FORCE_PU = 0
        clkConf &= ~(1 << 16)  // CK8M_FORCE_NOGATING = 0
        clkConf &= ~(1 << 28)  // XTAL_GLOBAL_FORCE_NOGATING = 0
        regStore(rtcBase + clkConfOffset, clkConf)

        // OPTIONS0: allow XTAL and BB I2C to power down
        var opt0 = regLoad(rtcBase + options0Offset)
        opt0 &= ~(1 << 13)     // XTL_FORCE_PU = 0
        opt0 &= ~(1 << 7)      // BB_I2C_FORCE_PU = 0
        regStore(rtcBase + options0Offset, opt0)

        // --- Enter deep sleep ---

        // Set wakeup source: GPIO (RTC_GPIO_TRIG_EN = BIT(2), bit 15+2 = 17)
        var wakeState = regLoad(rtcBase + wakeupStateOffset)
        wakeState &= ~(0x1FFFF << 15)
        wakeState |= (1 << 17)
        regStore(rtcBase + wakeupStateOffset, wakeState)

        // Disable sleep reject (prevent spurious rejects)
        regStore(rtcBase + slpRejectConfOffset, 0)

        // Clear pending wakeup/reject interrupts (INT_CLR at 0x4C)
        regStore(rtcBase + intClrOffset, 0x3)  // bits 0-1: SLP_WAKEUP + SLP_REJECT

        // Trigger deep sleep
        var state0 = regLoad(rtcBase + state0Offset)
        state0 |= (1 << 31)    // SLEEP_EN = 1
        regStore(rtcBase + state0Offset, state0)

        // Should not reach here — chip resets on wakeup
        while true {
            delayUs(1_000_000)
        }
    }

    // MARK: - CPU Frequency

    /// SYSTEM_CPU_PER_CONF_REG address.
    private static let cpuPerConfReg: UInt32 = 0x600C_0008

    /// Switch CPU to 80 MHz (PLL 480 MHz / 6).
    ///
    /// The PLL stays running — only the CPU divider changes.
    /// Safe to call at any time; SPI peripheral clocks derive from APB
    /// (80 MHz) and are unaffected.
    static func setCPU80MHz() {
        var conf = regLoad(cpuPerConfReg)
        conf = (conf & ~UInt32(0x3)) | 0   // CPUPERIOD_SEL = 0 → 80 MHz
        regStore(cpuPerConfReg, conf)
    }

    /// Switch CPU to 160 MHz (PLL 480 MHz / 3).
    static func setCPU160MHz() {
        var conf = regLoad(cpuPerConfReg)
        conf = (conf & ~UInt32(0x3)) | 1   // CPUPERIOD_SEL = 1 → 160 MHz
        regStore(cpuPerConfReg, conf)
    }

    // MARK: - Private

    /// Power button: GPIO3, active LOW
    private static let powerPin = Pin(number: 3)

    /// Set SPI bus and display pins to safe, deterministic states.
    ///
    /// Reclaims peripheral-routed pins (SCLK, MOSI) back to simple GPIO mode
    /// so that PAD_HOLD latches the correct output level rather than whatever
    /// the SPI peripheral was driving.
    private static func preparePinsForSleep() {
        // SCLK (GPIO8): reclaim from SPI2, drive LOW
        Pin(number: 8).setOutput()
        Pin(number: 8).low()

        // MOSI (GPIO10): reclaim from SPI2, drive LOW
        Pin(number: 10).setOutput()
        Pin(number: 10).low()

        // MISO (GPIO7): input with pull-down (prevents float)
        Pin(number: 7).setInput(pullDown: true)

        // SD CS (GPIO12): deselect
        Pin(number: 12).setOutput()
        Pin(number: 12).high()

        // E-ink CS (GPIO21): deselect
        Pin(number: 21).setOutput()
        Pin(number: 21).high()

        // E-ink DC (GPIO4): hold HIGH
        Pin(number: 4).setOutput()
        Pin(number: 4).high()

        // E-ink RST (GPIO5): hold HIGH (active-low reset)
        Pin(number: 5).setOutput()
        Pin(number: 5).high()

        // E-ink BUSY (GPIO6): input with pull-down
        Pin(number: 6).setInput(pullDown: true)
    }
}
