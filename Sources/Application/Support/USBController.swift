import Registers

/// USB Serial/JTAG reconnection handler for ESP32-C3.
///
/// The built-in USB controller handles protocol-level enumeration in hardware,
/// but after a cable unplug/replug the JTAG and serial FIFOs can be left in a
/// stale state.  Polling `pollBusReset()` from the main loop detects the
/// hardware USB_BUS_RESET event and restores the controller to a working state.
enum USBController {
    /// Check for a USB bus reset (cable replug) and recover if detected.
    static func pollBusReset() {
        let raw = usb_device.int_raw.read().raw.storage
        // bit 9 = USB_BUS_RESET_INT_RAW
        guard raw & (1 << 9) != 0 else { return }

        // 1. Clear all pending USB interrupt flags
        usb_device.int_clr.write { $0.raw.storage = 0xFFFF_FFFF }

        // 2. Reset JTAG FIFOs (JFIFO_ST: bit 8 = IN_FIFO_RESET, bit 9 = OUT_FIFO_RESET)
        usb_device.jfifo_st.modify {
            $0.raw.storage = $0.raw.storage | (1 << 8) | (1 << 9)
        }
        usb_device.jfifo_st.modify {
            $0.raw.storage = $0.raw.storage & ~((1 << 8) | (1 << 9))
        }

        // 3. Ensure USB PHY pad and D+ pull-up are enabled (CONF0: bit 14, bit 9)
        usb_device.conf0.modify {
            $0.raw.storage = $0.raw.storage | (1 << 14) | (1 << 9)
        }
    }
}
