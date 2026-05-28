import Registers

/// Write a byte to USB Serial/JTAG EP1 FIFO if space is available.
/// ESP32-C3 USB_DEVICE base=0x60043000
private func usbFifoWrite(_ byte: UInt8) -> Bool {
    var timeout: UInt32 = 50_000
    while usb_device.ep1_conf.read().raw.storage & (1 << 1) == 0 {
        timeout &-= 1
        if timeout == 0 { return false }
    }
    usb_device.ep1.write { $0.raw.storage = UInt32(byte) }
    return true
}

/// Print a hex value using only literal bytes (no StaticString/DROM dependency).
func usbPrintHex(_ value: UInt32) {
    _ = usbFifoWrite(0x30)  // '0'
    _ = usbFifoWrite(0x78)  // 'x'
    for i in stride(from: 28, through: 0, by: -4) {
        let nibble = UInt8((value >> UInt32(i)) & 0xF)
        let ch: UInt8 = nibble < 10 ? (0x30 + nibble) : (0x41 + nibble - 10)
        _ = usbFifoWrite(ch)
    }
    _ = usbFifoWrite(0x0D)
    _ = usbFifoWrite(0x0A)
    usb_device.ep1_conf.write { $0.raw.storage = 1 }
}

/// Print literal bytes: "OK\r\n" (no StaticString dependency).
func usbPrintOK() {
    _ = usbFifoWrite(0x4F)  // 'O'
    _ = usbFifoWrite(0x4B)  // 'K'
    _ = usbFifoWrite(0x0D)
    _ = usbFifoWrite(0x0A)
    usb_device.ep1_conf.write { $0.raw.storage = 1 }
}

/// Print a StaticString via USB. Appends \r\n and flushes.
func usbPrint(_ s: StaticString) {
    var ptr = UnsafeRawPointer(s.utf8Start)
    for _ in 0..<s.utf8CodeUnitCount {
        if !usbFifoWrite(ptr.load(as: UInt8.self)) { return }
        ptr = ptr.advanced(by: 1)
    }
    _ = usbFifoWrite(0x0D)
    _ = usbFifoWrite(0x0A)
    usb_device.ep1_conf.write { $0.raw.storage = 1 }  // Flush (wr_done)
}

/// Print a StaticString prefix followed by a decimal number and \r\n.
func usbPrintNum(_ prefix: StaticString, _ value: UInt32) {
    var ptr = UnsafeRawPointer(prefix.utf8Start)
    for _ in 0..<prefix.utf8CodeUnitCount {
        if !usbFifoWrite(ptr.load(as: UInt8.self)) { return }
        ptr = ptr.advanced(by: 1)
    }
    // Convert to decimal (max 10 digits for UInt32)
    if value == 0 {
        _ = usbFifoWrite(0x30)  // '0'
    } else {
        var digits: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
            (0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        var n = value
        var count = 0
        while n > 0 {
            withUnsafeMutablePointer(to: &digits) { p in
                UnsafeMutableRawPointer(p).storeBytes(of: UInt8(n % 10) + 0x30,
                                                       toByteOffset: count, as: UInt8.self)
            }
            count += 1
            n /= 10
        }
        // Print in reverse (most significant first)
        for i in stride(from: count - 1, through: 0, by: -1) {
            let ch = withUnsafePointer(to: digits) { p in
                UnsafeRawPointer(p).load(fromByteOffset: i, as: UInt8.self)
            }
            _ = usbFifoWrite(ch)
        }
    }
    _ = usbFifoWrite(0x0D)
    _ = usbFifoWrite(0x0A)
    usb_device.ep1_conf.write { $0.raw.storage = 1 }
}

@_extern(c, "heap_stats")
func _heapStats(_ totalFree: UnsafeMutablePointer<UInt>, _ largestBlock: UnsafeMutablePointer<UInt>)

/// Print heap free memory stats via USB serial.
func usbPrintHeapStats() {
    var totalFree: UInt = 0
    var largest: UInt = 0
    _heapStats(&totalFree, &largest)
    usbPrintNum("Heap free: ", UInt32(totalFree))
    usbPrintNum("Heap largest: ", UInt32(largest))
}

/// Print from a mutable buffer in DRAM (not flash-mapped DROM).
func usbPrintBytes(_ bytes: UnsafeBufferPointer<UInt8>) {
    for byte in bytes {
        if !usbFifoWrite(byte) { return }
    }
    _ = usbFifoWrite(0x0D)
    _ = usbFifoWrite(0x0A)
    usb_device.ep1_conf.write { $0.raw.storage = 1 }
}
