/// Battery status snapshot returned by `BatteryMonitor.read()`.
///
/// `millivolts` is the raw (uncorrected) terminal voltage — useful for
/// calibration logging. `percentage` is the SOC estimate after charge-mode
/// compensation, so it can be displayed directly.
struct BatteryStatus {
    var millivolts: UInt32
    var percentage: UInt32
    var isCharging: Bool
}

/// Battery voltage monitor via ADC on GPIO0.
///
/// Hardware: LiPo battery through 2x 10K resistor divider (1:2 ratio).
/// ADC reads half the actual battery voltage.
/// Range: ~3.0V (empty) to ~4.2V (full).
///
/// When USB is connected the terminal voltage reads 100–200 mV above the
/// open-circuit voltage (charge-current IR drop + CV-phase regulation),
/// which would otherwise cause a visible jump in the displayed percentage
/// on plug/unplug. `read()` applies a fixed offset while charging and
/// reports the charging state so the UI can show a bolt indicator.
struct BatteryMonitor {
    static let adcChannel: UInt32 = 0  // GPIO0 = ADC1 channel 0

    /// Voltage subtracted from the raw reading while charging to approximate
    /// the resting (open-circuit) voltage. Tune by logging `millivolts` before
    /// and after plugging USB: pick a value that keeps the percentage steady
    /// across the transition.
    static let chargingOffsetMv: UInt32 = 120

    /// Initialize the ADC for battery reading.
    static func initialize() {
        ADCDriver.initialize()
        ADCDriver.configurePin(0)
    }

    /// Read battery status: raw voltage, compensated SOC, charging flag.
    ///
    /// Requires `PowerManager.initialize()` to have been called first so the
    /// USB-detect pin reports valid state.
    static func read() -> BatteryStatus {
        let rawMv = readRawMillivolts()
        let isCharging = PowerManager.isUSBConnected()
        let adjusted: UInt32
        if isCharging && rawMv > chargingOffsetMv {
            adjusted = rawMv &- chargingOffsetMv
        } else {
            adjusted = rawMv
        }
        return BatteryStatus(
            millivolts: rawMv,
            percentage: percentage(fromMillivolts: adjusted),
            isCharging: isCharging
        )
    }

    /// Read raw battery voltage in millivolts.
    /// Applies 2x multiplier for the resistor divider.
    /// Averages multiple reads for stability (first read discarded as warm-up).
    private static func readRawMillivolts() -> UInt32 {
        // Discard first read (ADC warm-up after channel switch)
        _ = ADCDriver.read(channel: adcChannel, attenuation: .db11)

        // Average 4 reads
        var sum: UInt32 = 0
        for _ in 0..<4 {
            sum &+= ADCDriver.readMillivolts(channel: adcChannel, attenuation: .db11)
        }
        let adcMv = sum / 4
        return adcMv * 2  // Resistor divider ratio
    }

    /// Piecewise linear SOC curve derived from the LiPo polynomial:
    ///   y = -144.939*v³ + 1655.863*v² - 6158.852*v + 7501.320
    /// (from sample firmware BatteryMonitor.cpp)
    ///
    /// Key points:
    ///   4200mV=100%, 4100mV=95%, 4000mV=84%, 3900mV=79%,
    ///   3800mV=56%, 3700mV=43%, 3600mV=31%, 3500mV=15%,
    ///   3400mV=6%, 3300mV=1%, 3000mV=0%
    private static func percentage(fromMillivolts mv: UInt32) -> UInt32 {
        if mv >= 4200 { return 100 }
        if mv <= 3300 { return 0 }

        if mv >= 4100 {
            return 95 &+ (mv &- 4100) * 5 / 100     // 4100-4200: 95-100%
        } else if mv >= 4000 {
            return 84 &+ (mv &- 4000) * 11 / 100    // 4000-4100: 84-95%
        } else if mv >= 3900 {
            return 79 &+ (mv &- 3900) * 5 / 100     // 3900-4000: 79-84%
        } else if mv >= 3800 {
            return 56 &+ (mv &- 3800) * 23 / 100    // 3800-3900: 56-79%
        } else if mv >= 3700 {
            return 43 &+ (mv &- 3700) * 13 / 100    // 3700-3800: 43-56%
        } else if mv >= 3600 {
            return 31 &+ (mv &- 3600) * 12 / 100    // 3600-3700: 31-43%
        } else if mv >= 3500 {
            return 15 &+ (mv &- 3500) * 16 / 100    // 3500-3600: 15-31%
        } else if mv >= 3400 {
            return 6 &+ (mv &- 3400) * 9 / 100      // 3400-3500: 6-15%
        } else {
            return (mv &- 3300) * 6 / 100            // 3300-3400: 0-6%
        }
    }
}
