// Generated from esp32c3.svd — do not edit.

/// SPI (Serial Peripheral Interface) Controller 0
public struct SPI0 {
    @usableFromInline let _base: UInt

    @inline(__always)
    public init(unsafeAddress: UInt) {
        self._base = unsafeAddress
    }

    /// SPI0 control register.
    public var ctrl: Register<CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8)
        }
    }

    /// SPI0 control1 register.
    public var ctrl1: Register<CTRL1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc)
        }
    }

    /// SPI0 control2 register.
    public var ctrl2: Register<CTRL2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x10)
        }
    }

    /// SPI clock division control register.
    public var clock: Register<CLOCK> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x14)
        }
    }

    /// SPI0 user register.
    public var user: Register<USER> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x18)
        }
    }

    /// SPI0 user1 register.
    public var user1: Register<USER1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x1c)
        }
    }

    /// SPI0 user2 register.
    public var user2: Register<USER2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x20)
        }
    }

    /// SPI0 read control register.
    public var rd_status: Register<RD_STATUS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x2c)
        }
    }

    /// SPI0 misc register
    public var misc: Register<MISC> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x34)
        }
    }

    /// SPI0 bit mode control register.
    public var cache_fctrl: Register<CACHE_FCTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x3c)
        }
    }

    /// SPI0 FSM status register
    public var fsm: Register<FSM> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x54)
        }
    }

    /// SPI0 timing calibration register
    public var timing_cali: Register<TIMING_CALI> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xa8)
        }
    }

    /// SPI0 input delay mode control register
    public var din_mode: Register<DIN_MODE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xac)
        }
    }

    /// SPI0 input delay number control register
    public var din_num: Register<DIN_NUM> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xb0)
        }
    }

    /// SPI0 output delay mode control register
    public var dout_mode: Register<DOUT_MODE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xb4)
        }
    }

    /// SPI0 clk_gate register
    public var clock_gate: Register<CLOCK_GATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xdc)
        }
    }

    /// SPI0 module clock select register
    public var core_clk_sel: Register<CORE_CLK_SEL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xe0)
        }
    }

    /// Version control register
    public var date: Register<DATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x3fc)
        }
    }

    // Phantom types
    public struct CTRL {}
    public struct CTRL1 {}
    public struct CTRL2 {}
    public struct CLOCK {}
    public struct USER {}
    public struct USER1 {}
    public struct USER2 {}
    public struct RD_STATUS {}
    public struct MISC {}
    public struct CACHE_FCTRL {}
    public struct FSM {}
    public struct TIMING_CALI {}
    public struct DIN_MODE {}
    public struct DIN_NUM {}
    public struct DOUT_MODE {}
    public struct CLOCK_GATE {}
    public struct CORE_CLK_SEL {}
    public struct DATE {}
}
