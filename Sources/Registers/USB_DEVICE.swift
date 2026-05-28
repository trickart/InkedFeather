// Generated from esp32c3.svd — do not edit.

/// Full-speed USB Serial/JTAG Controller
public struct USB_DEVICE {
    @usableFromInline let _base: UInt

    @inline(__always)
    public init(unsafeAddress: UInt) {
        self._base = unsafeAddress
    }

    /// USB_DEVICE_EP1_REG.
    public var ep1: Register<EP1> {
        @inline(__always) get {
            Register(unsafeAddress: _base)
        }
    }

    /// USB_DEVICE_EP1_CONF_REG.
    public var ep1_conf: Register<EP1_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4)
        }
    }

    /// USB_DEVICE_INT_RAW_REG.
    public var int_raw: Register<INT_RAW> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8)
        }
    }

    /// USB_DEVICE_INT_ST_REG.
    public var int_st: Register<INT_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc)
        }
    }

    /// USB_DEVICE_INT_ENA_REG.
    public var int_ena: Register<INT_ENA> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x10)
        }
    }

    /// USB_DEVICE_INT_CLR_REG.
    public var int_clr: Register<INT_CLR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x14)
        }
    }

    /// USB_DEVICE_CONF0_REG.
    public var conf0: Register<CONF0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x18)
        }
    }

    /// USB_DEVICE_TEST_REG.
    public var test: Register<TEST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x1c)
        }
    }

    /// USB_DEVICE_JFIFO_ST_REG.
    public var jfifo_st: Register<JFIFO_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x20)
        }
    }

    /// USB_DEVICE_FRAM_NUM_REG.
    public var fram_num: Register<FRAM_NUM> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x24)
        }
    }

    /// USB_DEVICE_IN_EP0_ST_REG.
    public var in_ep0_st: Register<IN_EP0_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x28)
        }
    }

    /// USB_DEVICE_IN_EP1_ST_REG.
    public var in_ep1_st: Register<IN_EP1_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x2c)
        }
    }

    /// USB_DEVICE_IN_EP2_ST_REG.
    public var in_ep2_st: Register<IN_EP2_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x30)
        }
    }

    /// USB_DEVICE_IN_EP3_ST_REG.
    public var in_ep3_st: Register<IN_EP3_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x34)
        }
    }

    /// USB_DEVICE_OUT_EP0_ST_REG.
    public var out_ep0_st: Register<OUT_EP0_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x38)
        }
    }

    /// USB_DEVICE_OUT_EP1_ST_REG.
    public var out_ep1_st: Register<OUT_EP1_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x3c)
        }
    }

    /// USB_DEVICE_OUT_EP2_ST_REG.
    public var out_ep2_st: Register<OUT_EP2_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x40)
        }
    }

    /// USB_DEVICE_MISC_CONF_REG.
    public var misc_conf: Register<MISC_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x44)
        }
    }

    /// USB_DEVICE_MEM_CONF_REG.
    public var mem_conf: Register<MEM_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x48)
        }
    }

    /// USB_DEVICE_DATE_REG.
    public var date: Register<DATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x80)
        }
    }

    // Phantom types
    public struct EP1 {}
    public struct EP1_CONF {}
    public struct INT_RAW {}
    public struct INT_ST {}
    public struct INT_ENA {}
    public struct INT_CLR {}
    public struct CONF0 {}
    public struct TEST {}
    public struct JFIFO_ST {}
    public struct FRAM_NUM {}
    public struct IN_EP0_ST {}
    public struct IN_EP1_ST {}
    public struct IN_EP2_ST {}
    public struct IN_EP3_ST {}
    public struct OUT_EP0_ST {}
    public struct OUT_EP1_ST {}
    public struct OUT_EP2_ST {}
    public struct MISC_CONF {}
    public struct MEM_CONF {}
    public struct DATE {}
}
