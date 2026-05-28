/// ADC resistor-ladder button driver.
///
/// Open X4 hardware uses two ADC channels with resistor ladders:
///   GPIO1 (ADC1 ch1): Back, Confirm, Left, Right
///   GPIO2 (ADC1 ch2): Up, Down
///
/// Thresholds use raw 12-bit ADC values (0-4095) directly.
/// Raw ADC measured values:
///   Ch1: None=4095, Back~3517, Confirm~2686, Left~1487, Right~5
///   Ch2: None=4095, Up~2234, Down~3
struct ButtonDriver {
    enum Button: UInt8 {
        case none    = 0
        case back    = 1
        case confirm = 2
        case left    = 3
        case right   = 4
        case up      = 5
        case down    = 6
        case power   = 7
    }

    /// ADC channels
    private static let channel1: UInt32 = 1  // GPIO1
    private static let channel2: UInt32 = 2  // GPIO2

    /// Power button: GPIO3, digital, active LOW
    private static let powerPin = Pin(number: 3)

    /// Debounce state
    nonisolated(unsafe) private static var lastButton: Button = .none
    nonisolated(unsafe) private static var stableCount: UInt32 = 0
    nonisolated(unsafe) private static var debounced: Button = .none

    private static let debounceThreshold: UInt32 = 2  // release debounce: ~100ms at 50ms poll

    /// Decode GPIO1 buttons from raw ADC value.
    /// Measured: None=4095, Back~3517, Confirm~2686, Left~1487, Right~5
    /// Thresholds at midpoints:
    ///   adc > 3800         → None     (midpoint 4095↔3517)
    ///   3100 < adc <= 3800 → Back     (midpoint 3517���2686)
    ///   2090 < adc <= 3100 → Confirm  (midpoint 2686↔1487)
    ///    750 < adc <= 2090 → Left     (midpoint 1487↔5)
    ///          adc <=  750 → Right
    private static func decodeChannel1(_ adc: UInt32) -> Button {
        if adc > 3800 { return .none }
        if adc > 3100 { return .back }
        if adc > 2090 { return .confirm }
        if adc > 750  { return .left }
        return .right
    }

    /// Decode GPIO2 buttons from raw ADC value.
    /// Measured: None=4095, Up~2234, Down~3
    /// Thresholds at midpoints:
    ///   adc > 3160  → None   (midpoint 4095↔2234)
    ///   adc > 1120  → Up     (midpoint 2234↔3)
    ///   adc <= 1120 → Down
    private static func decodeChannel2(_ adc: UInt32) -> Button {
        if adc > 3160 { return .none }
        if adc > 1120 { return .up }
        return .down
    }

    /// Initialize button ADC pins and power button GPIO.
    static func initialize() {
        ADCDriver.initialize()
        ADCDriver.configurePin(1)
        ADCDriver.configurePin(2)
        powerPin.setInput(pullUp: true)
    }

    /// Poll buttons and return the debounced button state.
    /// Press is detected immediately; release requires debounce.
    /// Should be called every ~50ms.
    static func poll() -> Button {
        let raw = readRaw()

        if raw == lastButton {
            if stableCount < debounceThreshold {
                stableCount &+= 1
            }
        } else {
            lastButton = raw
            stableCount = 0
        }

        // Immediate press: accept new button right away
        if raw != .none && debounced == .none {
            debounced = raw
        } else if stableCount >= debounceThreshold {
            debounced = raw
        }

        return debounced
    }

    /// Last raw ADC values (for debug access).
    nonisolated(unsafe) static var lastAdc1: UInt32 = 0
    nonisolated(unsafe) static var lastAdc2: UInt32 = 0

    /// Read the current raw (non-debounced) button state.
    static func readRaw() -> Button {
        // Power button (GPIO3, active LOW) — check first
        if !powerPin.read() { return .power }

        let adc1 = ADCDriver.read(channel: channel1, attenuation: .db11)
        let adc2 = ADCDriver.read(channel: channel2, attenuation: .db11)
        lastAdc1 = adc1
        lastAdc2 = adc2

        let btn1 = decodeChannel1(adc1)
        if btn1 != .none { return btn1 }
        return decodeChannel2(adc2)
    }
}
