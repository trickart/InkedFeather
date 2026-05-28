import Registers

/// ESP32-C3 GPIO pin abstraction.
///
/// Wraps GPIO Matrix + IO_MUX register access into a lightweight value type.
/// ESP32-C3 has GPIO0–GPIO21 (22 pins total).
struct Pin {
    let number: Int

    /// Configure as GPIO output.
    func setOutput(driveStrength: UInt32 = 2) {
        // IO_MUX: mcu_sel=1 (GPIO function), fun_ie=0 (disable input), fun_drv
        io_mux.gpio[number].modify {
            $0.raw.storage = ($0.raw.storage & ~(0x7 << 12)) | (1 << 12)
            $0.raw.storage = $0.raw.storage & ~(1 << 9)
            $0.raw.storage = ($0.raw.storage & ~(0x3 << 10)) | (driveStrength << 10)
        }
        // GPIO Matrix: func_out_sel=128 (simple GPIO out), oen_sel=1 (bit 9)
        gpio.func_out_sel_cfg[number].modify {
            $0.raw.storage = 128 | (1 << 9)
        }
        // Enable output
        gpio.enable_w1ts.write { $0.raw.storage = 1 << UInt32(number) }
    }

    /// Configure as GPIO input.
    func setInput(pullUp: Bool = false, pullDown: Bool = false) {
        io_mux.gpio[number].modify {
            $0.raw.storage = ($0.raw.storage & ~(0x7 << 12)) | (1 << 12)  // mcu_sel=1
            $0.raw.storage = $0.raw.storage | (1 << 9)                    // fun_ie=1
            if pullUp {
                $0.raw.storage = $0.raw.storage | (1 << 8)                // fun_wpu=1
            } else {
                $0.raw.storage = $0.raw.storage & ~(1 << 8)
            }
            if pullDown {
                $0.raw.storage = $0.raw.storage | (1 << 7)                // fun_wpd=1
            } else {
                $0.raw.storage = $0.raw.storage & ~(1 << 7)
            }
        }
        // Disable output
        gpio.enable_w1tc.write { $0.raw.storage = 1 << UInt32(number) }
    }

    /// Set output high.
    @inline(__always)
    func high() {
        gpio.out_w1ts.write { $0.raw.storage = 1 << UInt32(number) }
    }

    /// Set output low.
    @inline(__always)
    func low() {
        gpio.out_w1tc.write { $0.raw.storage = 1 << UInt32(number) }
    }

    /// Write a boolean value (true = high).
    @inline(__always)
    func write(_ value: Bool) {
        if value { high() } else { low() }
    }

    /// Read the current pin level.
    @inline(__always)
    func read() -> Bool {
        (gpio.`in`.read().raw.storage >> UInt32(number)) & 1 != 0
    }

    /// Route a peripheral signal to this pin via GPIO Matrix.
    ///
    /// - Parameters:
    ///   - function: Peripheral output signal index (see ESP32-C3 TRM Table 5-1).
    ///   - input: If true, also configure as input and route input signal.
    ///   - inputSignal: Peripheral input signal index for GPIO Matrix func_in_sel_cfg.
    func setFunction(output function: UInt32, enableInput: Bool = false, inputSignal: UInt32? = nil) {
        // IO_MUX: mcu_sel=1 (GPIO), set fun_ie if needed
        io_mux.gpio[number].modify {
            $0.raw.storage = ($0.raw.storage & ~(0x7 << 12)) | (1 << 12)
            if enableInput {
                $0.raw.storage = $0.raw.storage | (1 << 9)   // fun_ie=1
            } else {
                $0.raw.storage = $0.raw.storage & ~(1 << 9)  // fun_ie=0
            }
        }
        // Output signal routing
        gpio.func_out_sel_cfg[number].write {
            $0.raw.storage = function & 0xFF  // oen_sel=0 (peripheral controls OE)
        }
        gpio.enable_w1ts.write { $0.raw.storage = 1 << UInt32(number) }

        // Input signal routing
        if let sig = inputSignal {
            gpio.func_in_sel_cfg[Int(sig)].write {
                $0.raw.storage = UInt32(number) | (1 << 6)  // in_sel=pin, sel=1 (route via GPIO Matrix)
            }
        }
    }
}
