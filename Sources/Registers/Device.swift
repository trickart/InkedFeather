// Generated from esp32c3.svd — do not edit.

/// Timer Group 1
public typealias TIMG1 = TIMG0

/// SAR (Successive Approximation Register) Analog-to-Digital Converter
public nonisolated(unsafe) let apb_saradc = APB_SARADC(unsafeAddress: 0x60040000)

/// External Memory
public nonisolated(unsafe) let extmem = EXTMEM(unsafeAddress: 0x600c4000)

/// General Purpose Input/Output
public nonisolated(unsafe) let gpio = GPIO(unsafeAddress: 0x60004000)

/// Interrupt Controller (Core 0)
public nonisolated(unsafe) let interrupt_core0 = INTERRUPT_CORE0(unsafeAddress: 0x600c2000)

/// Input/Output Multiplexer
public nonisolated(unsafe) let io_mux = IO_MUX(unsafeAddress: 0x60009000)

/// Real-Time Clock Control
public nonisolated(unsafe) let rtc_cntl = RTC_CNTL(unsafeAddress: 0x60008000)

/// SPI (Serial Peripheral Interface) Controller 0
public nonisolated(unsafe) let spi0 = SPI0(unsafeAddress: 0x60003000)

/// SPI (Serial Peripheral Interface) Controller 1
public nonisolated(unsafe) let spi1 = SPI1(unsafeAddress: 0x60002000)

/// SPI (Serial Peripheral Interface) Controller 2
public nonisolated(unsafe) let spi2 = SPI2(unsafeAddress: 0x60024000)

/// System Configuration Registers
public nonisolated(unsafe) let system = SYSTEM(unsafeAddress: 0x600c0000)

/// System Timer
public nonisolated(unsafe) let systimer = SYSTIMER(unsafeAddress: 0x60023000)

/// Timer Group 0
public nonisolated(unsafe) let timg0 = TIMG0(unsafeAddress: 0x6001f000)

/// Timer Group 1
public nonisolated(unsafe) let timg1 = TIMG1(unsafeAddress: 0x60020000)

/// UART (Universal Asynchronous Receiver-Transmitter) Controller 0
public nonisolated(unsafe) let uart0 = UART0(unsafeAddress: 0x60000000)

/// Full-speed USB Serial/JTAG Controller
public nonisolated(unsafe) let usb_device = USB_DEVICE(unsafeAddress: 0x60043000)

