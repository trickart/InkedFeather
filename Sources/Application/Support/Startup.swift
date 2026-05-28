import Registers
import TrapHandler

// MARK: - BSS

@inline(__always)
private func linkerSymbolAddress(_ symbol: inout UInt8) -> UInt {
    withUnsafePointer(to: &symbol) { UInt(bitPattern: $0) }
}

@_extern(c, "_sbss") nonisolated(unsafe) var _sbss: UInt8
@_extern(c, "_ebss") nonisolated(unsafe) var _ebss: UInt8

func clearBSS() {
    let start = linkerSymbolAddress(&_sbss)
    let end = linkerSymbolAddress(&_ebss)
    guard let ptr = UnsafeMutablePointer<UInt8>(bitPattern: start) else { return }
    var i = 0
    while start &+ UInt(i) < end {
        ptr[i] = 0
        i &+= 1
    }
}

// MARK: - GPIO

/// Configure a GPIO pin as output.
/// ESP32-C3 IO_MUX GPIO registers: fun_ie=bit9, mcu_sel=bits14:12, fun_drv=bits11:10
func configureGPIOOutput(pin: Int, driveStrength: UInt32? = nil) {
    io_mux.gpio[pin].modify {
        $0.raw.storage = ($0.raw.storage & ~(0x7 << 12)) | (1 << 12)  // mcu_sel=1 (GPIO)
        $0.raw.storage = $0.raw.storage & ~(1 << 9)                   // fun_ie=0 (output)
        if let drv = driveStrength {
            $0.raw.storage = ($0.raw.storage & ~(0x3 << 10)) | (drv << 10)
        }
    }
    gpio.func_out_sel_cfg[pin].modify {
        $0.raw.storage = 128 | (1 << 10)  // func_out_sel=128 (GPIO), oen_sel=1
    }
    gpio.enable_w1ts.write { $0.raw.storage = 1 << UInt32(pin) }
}

/// Configure a GPIO pin as input.
func configureGPIOInput(pin: Int, pullUp: Bool = false) {
    io_mux.gpio[pin].modify {
        $0.raw.storage = ($0.raw.storage & ~(0x7 << 12)) | (1 << 12)  // mcu_sel=1 (GPIO)
        $0.raw.storage = $0.raw.storage | (1 << 9)                    // fun_ie=1 (input)
        if pullUp {
            $0.raw.storage = $0.raw.storage | (1 << 8)                // fun_wpu=1
        }
    }
}

// MARK: - Trap Vector

@_extern(c, "_vector_table") nonisolated(unsafe) var _vector_table_symbol: UInt8

func setupTrapVector() {
    let vecAddr = withUnsafePointer(to: &_vector_table_symbol) {
        UInt32(UInt(bitPattern: $0))
    }
    CSR.setTrapVector(vecAddr)
}

// MARK: - Global Interrupts

func enableGlobalInterrupts() {
    csr_write_mstatus(csr_read_mstatus() | (1 << 3))  // MIE
}
