# MMIO Register Access

Lightweight register access library for ESP32-C3 peripherals. No external dependencies — backed by Swift's `_Volatile` module.

## Overview

Apple's [swift-mmio](https://github.com/apple/swift-mmio) is excellent register access library, but its Swift macro expansion is slow in embedded builds. This project uses a custom macro-free implementation instead.

### Core types (`Sources/Registers/RegisterAccess.swift`)

| Type | Description |
|------|-------------|
| `Register<T>` | Single 32-bit memory-mapped register with volatile read/write |
| `RegisterArray<T>` | Array of registers at a fixed stride |
| `RegisterValue` | Value wrapper returned by `read()` / passed into `write`/`modify` closures |
| `RawStorage` | Inner wrapper exposing `.storage: UInt32` |

The generic parameter `T` is a phantom type (empty struct) used only for type-level distinction between registers. It has zero runtime cost.

## API

### Read

```swift
let value = gpio.`in`.read().raw.storage
let busy = spi2.cmd.read().raw.storage & (1 << 24) != 0
```

### Write (from zero)

```swift
gpio.out_w1ts.write { $0.raw.storage = 1 << UInt32(pin) }
spi2.clock.write { $0.raw.storage = clkcntN | (clkcntH << 6) | (clkcntN << 12) }
```

### Modify (read-modify-write)

```swift
system.perip_clk_en0.modify { $0.raw.storage = $0.raw.storage | (1 << 6) }

io_mux.gpio[pin].modify {
    $0.raw.storage = ($0.raw.storage & ~(0x7 << 12)) | (1 << 12)  // mcu_sel=1
    $0.raw.storage = $0.raw.storage | (1 << 9)                    // fun_ie=1
}
```

### Register arrays

```swift
gpio.pin[0].modify { ... }               // GPIO pin 0 config
gpio.func_in_sel_cfg[64].write { ... }    // Input signal routing
io_mux.gpio[number].modify { ... }        // IO MUX pad config
```

### Direct volatile access

For performance-critical sequences (FIFO writes, polling loops), `regLoad`/`regStore` in `Sources/Application/Support/VolatileRegister.swift` provide raw address-based access:

```swift
regStore(0x6002_4098, word)   // SPI2 W0 register
let status = regLoad(0x6004_0068)
```

## SVD Code Generation

Register definitions are auto-generated from the ESP32-C3 SVD file.

### Source

SVD file: `Sources/Registers/esp32c3.svd`
Downloaded from [espressif/svd 2024-05-09](https://github.com/espressif/svd/releases/tag/2024-05-09).

### Generator

```
swift Tools/generate-registers.swift <svd-file> <output-dir> [--peripherals NAME1,NAME2,...]
```

Or via Makefile:

```
make generate-registers
```

### Generated output structure

Each peripheral becomes a Swift struct with computed properties for its registers:

```swift
public struct UART0 {
    @usableFromInline let _base: UInt

    public init(unsafeAddress: UInt) { self._base = unsafeAddress }

    public var fifo: Register<FIFO> {
        @inline(__always) get { Register(unsafeAddress: _base) }
    }
    public var int_raw: Register<INT_RAW> {
        @inline(__always) get { Register(unsafeAddress: _base &+ 0x4) }
    }
    // ...

    public struct FIFO {}      // phantom type
    public struct INT_RAW {}
}
```

Array registers (using SVD `dim`/`dimIncrement`):

```swift
public var pin: RegisterArray<PIN> {
    @inline(__always) get { RegisterArray(unsafeAddress: _base &+ 0x74, stride: 4) }
}
```

Derived peripherals (e.g. TIMG1 from TIMG0):

```swift
public typealias TIMG1 = TIMG0
```

Global instances in `Device.swift`:

```swift
public nonisolated(unsafe) let gpio = GPIO(unsafeAddress: 0x60004000)
```

### Generated files

| File | Content |
|------|---------|
| `Device.swift` | Global peripheral instances + typealiases |
| `GPIO.swift` | 22 registers (incl. pin[26], func_in_sel_cfg[128], func_out_sel_cfg[26]) |
| `UART0.swift` | 33 registers |
| `SPI0.swift` / `SPI1.swift` / `SPI2.swift` | SPI controllers |
| `IO_MUX.swift` | 3 registers (incl. gpio[22] pad config array) |
| `SYSTEM.swift` | 40 registers (clock/reset control) |
| `SYSTIMER.swift` | 30 registers |
| `TIMG0.swift` | 26 registers (TIMG1 is typealias) |
| `RTC_CNTL.swift` | 75 registers |
| `INTERRUPT_CORE0.swift` | 103 registers (interrupt matrix) |
| `EXTMEM.swift` | 66 registers (cache/MMU) |
| `APB_SARADC.swift` | 26 registers |
| `USB_DEVICE.swift` | 20 registers |
| `RegisterAccess.swift` | Core types (hand-written, not generated) |

### Regenerating

To regenerate after modifying the SVD or generator:

```
make generate-registers
make build
```

Only `RegisterAccess.swift` is hand-maintained. All other `.swift` files in `Sources/Registers/` are generated and should not be edited directly.

## Adding a new peripheral

1. Add the peripheral name to the `--peripherals` list in the Makefile
2. Run `make generate-registers`
3. Create a driver in `Sources/Application/Drivers/` that `import Registers`

Available peripherals in the SVD (not currently generated): AES, APB_CTRL, ASSIST_DEBUG, BB, DMA, DS, EFUSE, GPIO_SD, HMAC, I2C0, I2S0, LEDC, RMT, RNG, RSA, SENSITIVE, SHA, TWAI0, UART1, UHCI0, UHCI1, XTS_AES.
