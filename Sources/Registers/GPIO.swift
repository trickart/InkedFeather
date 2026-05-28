// Generated from esp32c3.svd — do not edit.

/// General Purpose Input/Output
public struct GPIO {
    @usableFromInline let _base: UInt

    @inline(__always)
    public init(unsafeAddress: UInt) {
        self._base = unsafeAddress
    }

    /// GPIO bit select register
    public var bt_select: Register<BT_SELECT> {
        @inline(__always) get {
            Register(unsafeAddress: _base)
        }
    }

    /// GPIO output register
    public var out: Register<OUT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4)
        }
    }

    /// GPIO output set register
    public var out_w1ts: Register<OUT_W1TS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8)
        }
    }

    /// GPIO output clear register
    public var out_w1tc: Register<OUT_W1TC> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc)
        }
    }

    /// GPIO sdio select register
    public var sdio_select: Register<SDIO_SELECT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x1c)
        }
    }

    /// GPIO output enable register
    public var enable: Register<ENABLE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x20)
        }
    }

    /// GPIO output enable set register
    public var enable_w1ts: Register<ENABLE_W1TS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x24)
        }
    }

    /// GPIO output enable clear register
    public var enable_w1tc: Register<ENABLE_W1TC> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x28)
        }
    }

    /// pad strapping register
    public var strap: Register<STRAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x38)
        }
    }

    /// GPIO input register
    public var `in`: Register<IN> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x3c)
        }
    }

    /// GPIO interrupt status register
    public var status: Register<STATUS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x44)
        }
    }

    /// GPIO interrupt status set register
    public var status_w1ts: Register<STATUS_W1TS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x48)
        }
    }

    /// GPIO interrupt status clear register
    public var status_w1tc: Register<STATUS_W1TC> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4c)
        }
    }

    /// GPIO PRO_CPU interrupt status register
    public var pcpu_int: Register<PCPU_INT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x5c)
        }
    }

    /// GPIO PRO_CPU(not shielded) interrupt status register
    public var pcpu_nmi_int: Register<PCPU_NMI_INT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x60)
        }
    }

    /// GPIO CPUSDIO interrupt status register
    public var cpusdio_int: Register<CPUSDIO_INT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x64)
        }
    }

    /// GPIO pin configuration register
    public var pin: RegisterArray<PIN> {
        @inline(__always) get {
            RegisterArray(unsafeAddress: _base &+ 0x74, stride: 4)
        }
    }

    /// GPIO interrupt source register
    public var status_next: Register<STATUS_NEXT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x14c)
        }
    }

    /// GPIO input function configuration register
    public var func_in_sel_cfg: RegisterArray<FUNC_IN_SEL_CFG> {
        @inline(__always) get {
            RegisterArray(unsafeAddress: _base &+ 0x154, stride: 4)
        }
    }

    /// GPIO output function select register
    public var func_out_sel_cfg: RegisterArray<FUNC_OUT_SEL_CFG> {
        @inline(__always) get {
            RegisterArray(unsafeAddress: _base &+ 0x554, stride: 4)
        }
    }

    /// GPIO clock gate register
    public var clock_gate: Register<CLOCK_GATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x62c)
        }
    }

    /// GPIO version register
    public var reg_date: Register<REG_DATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x6fc)
        }
    }

    // Phantom types
    public struct BT_SELECT {}
    public struct OUT {}
    public struct OUT_W1TS {}
    public struct OUT_W1TC {}
    public struct SDIO_SELECT {}
    public struct ENABLE {}
    public struct ENABLE_W1TS {}
    public struct ENABLE_W1TC {}
    public struct STRAP {}
    public struct IN {}
    public struct STATUS {}
    public struct STATUS_W1TS {}
    public struct STATUS_W1TC {}
    public struct PCPU_INT {}
    public struct PCPU_NMI_INT {}
    public struct CPUSDIO_INT {}
    public struct PIN {}
    public struct STATUS_NEXT {}
    public struct FUNC_IN_SEL_CFG {}
    public struct FUNC_OUT_SEL_CFG {}
    public struct CLOCK_GATE {}
    public struct REG_DATE {}
}
