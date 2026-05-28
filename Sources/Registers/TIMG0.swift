// Generated from esp32c3.svd — do not edit.

/// Timer Group 0
public struct TIMG0 {
    @usableFromInline let _base: UInt

    @inline(__always)
    public init(unsafeAddress: UInt) {
        self._base = unsafeAddress
    }

    /// TIMG_T0CONFIG_REG.
    public var t0config: Register<T0CONFIG> {
        @inline(__always) get {
            Register(unsafeAddress: _base)
        }
    }

    /// TIMG_T0LO_REG.
    public var t0lo: Register<T0LO> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4)
        }
    }

    /// TIMG_T0HI_REG.
    public var t0hi: Register<T0HI> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8)
        }
    }

    /// TIMG_T0UPDATE_REG.
    public var t0update: Register<T0UPDATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc)
        }
    }

    /// TIMG_T0ALARMLO_REG.
    public var t0alarmlo: Register<T0ALARMLO> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x10)
        }
    }

    /// TIMG_T0ALARMHI_REG.
    public var t0alarmhi: Register<T0ALARMHI> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x14)
        }
    }

    /// TIMG_T0LOADLO_REG.
    public var t0loadlo: Register<T0LOADLO> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x18)
        }
    }

    /// TIMG_T0LOADHI_REG.
    public var t0loadhi: Register<T0LOADHI> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x1c)
        }
    }

    /// TIMG_T0LOAD_REG.
    public var t0load: Register<T0LOAD> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x20)
        }
    }

    /// TIMG_WDTCONFIG0_REG.
    public var wdtconfig0: Register<WDTCONFIG0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x48)
        }
    }

    /// TIMG_WDTCONFIG1_REG.
    public var wdtconfig1: Register<WDTCONFIG1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4c)
        }
    }

    /// TIMG_WDTCONFIG2_REG.
    public var wdtconfig2: Register<WDTCONFIG2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x50)
        }
    }

    /// TIMG_WDTCONFIG3_REG.
    public var wdtconfig3: Register<WDTCONFIG3> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x54)
        }
    }

    /// TIMG_WDTCONFIG4_REG.
    public var wdtconfig4: Register<WDTCONFIG4> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x58)
        }
    }

    /// TIMG_WDTCONFIG5_REG.
    public var wdtconfig5: Register<WDTCONFIG5> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x5c)
        }
    }

    /// TIMG_WDTFEED_REG.
    public var wdtfeed: Register<WDTFEED> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x60)
        }
    }

    /// TIMG_WDTWPROTECT_REG.
    public var wdtwprotect: Register<WDTWPROTECT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x64)
        }
    }

    /// TIMG_RTCCALICFG_REG.
    public var rtccalicfg: Register<RTCCALICFG> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x68)
        }
    }

    /// TIMG_RTCCALICFG1_REG.
    public var rtccalicfg1: Register<RTCCALICFG1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x6c)
        }
    }

    /// INT_ENA_TIMG_REG
    public var int_ena_timers: Register<INT_ENA_TIMERS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x70)
        }
    }

    /// INT_RAW_TIMG_REG
    public var int_raw_timers: Register<INT_RAW_TIMERS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x74)
        }
    }

    /// INT_ST_TIMG_REG
    public var int_st_timers: Register<INT_ST_TIMERS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x78)
        }
    }

    /// INT_CLR_TIMG_REG
    public var int_clr_timers: Register<INT_CLR_TIMERS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x7c)
        }
    }

    /// TIMG_RTCCALICFG2_REG.
    public var rtccalicfg2: Register<RTCCALICFG2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x80)
        }
    }

    /// TIMG_NTIMG_DATE_REG.
    public var ntimg_date: Register<NTIMG_DATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xf8)
        }
    }

    /// TIMG_REGCLK_REG.
    public var regclk: Register<REGCLK> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xfc)
        }
    }

    // Phantom types
    public struct T0CONFIG {}
    public struct T0LO {}
    public struct T0HI {}
    public struct T0UPDATE {}
    public struct T0ALARMLO {}
    public struct T0ALARMHI {}
    public struct T0LOADLO {}
    public struct T0LOADHI {}
    public struct T0LOAD {}
    public struct WDTCONFIG0 {}
    public struct WDTCONFIG1 {}
    public struct WDTCONFIG2 {}
    public struct WDTCONFIG3 {}
    public struct WDTCONFIG4 {}
    public struct WDTCONFIG5 {}
    public struct WDTFEED {}
    public struct WDTWPROTECT {}
    public struct RTCCALICFG {}
    public struct RTCCALICFG1 {}
    public struct INT_ENA_TIMERS {}
    public struct INT_RAW_TIMERS {}
    public struct INT_ST_TIMERS {}
    public struct INT_CLR_TIMERS {}
    public struct RTCCALICFG2 {}
    public struct NTIMG_DATE {}
    public struct REGCLK {}
}
