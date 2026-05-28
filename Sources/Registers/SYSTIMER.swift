// Generated from esp32c3.svd — do not edit.

/// System Timer
public struct SYSTIMER {
    @usableFromInline let _base: UInt

    @inline(__always)
    public init(unsafeAddress: UInt) {
        self._base = unsafeAddress
    }

    /// SYSTIMER_CONF.
    public var conf: Register<CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base)
        }
    }

    /// SYSTIMER_UNIT0_OP.
    public var unit0_op: Register<UNIT0_OP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4)
        }
    }

    /// SYSTIMER_UNIT1_OP.
    public var unit1_op: Register<UNIT1_OP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8)
        }
    }

    /// SYSTIMER_UNIT0_LOAD_HI.
    public var unit0_load_hi: Register<UNIT0_LOAD_HI> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc)
        }
    }

    /// SYSTIMER_UNIT0_LOAD_LO.
    public var unit0_load_lo: Register<UNIT0_LOAD_LO> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x10)
        }
    }

    /// SYSTIMER_UNIT1_LOAD_HI.
    public var unit1_load_hi: Register<UNIT1_LOAD_HI> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x14)
        }
    }

    /// SYSTIMER_UNIT1_LOAD_LO.
    public var unit1_load_lo: Register<UNIT1_LOAD_LO> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x18)
        }
    }

    /// SYSTIMER_TARGET0_HI.
    public var target0_hi: Register<TARGET0_HI> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x1c)
        }
    }

    /// SYSTIMER_TARGET0_LO.
    public var target0_lo: Register<TARGET0_LO> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x20)
        }
    }

    /// SYSTIMER_TARGET1_HI.
    public var target1_hi: Register<TARGET1_HI> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x24)
        }
    }

    /// SYSTIMER_TARGET1_LO.
    public var target1_lo: Register<TARGET1_LO> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x28)
        }
    }

    /// SYSTIMER_TARGET2_HI.
    public var target2_hi: Register<TARGET2_HI> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x2c)
        }
    }

    /// SYSTIMER_TARGET2_LO.
    public var target2_lo: Register<TARGET2_LO> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x30)
        }
    }

    /// SYSTIMER_TARGET0_CONF.
    public var target0_conf: Register<TARGET0_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x34)
        }
    }

    /// SYSTIMER_TARGET1_CONF.
    public var target1_conf: Register<TARGET1_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x38)
        }
    }

    /// SYSTIMER_TARGET2_CONF.
    public var target2_conf: Register<TARGET2_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x3c)
        }
    }

    /// SYSTIMER_UNIT0_VALUE_HI.
    public var unit0_value_hi: Register<UNIT0_VALUE_HI> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x40)
        }
    }

    /// SYSTIMER_UNIT0_VALUE_LO.
    public var unit0_value_lo: Register<UNIT0_VALUE_LO> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x44)
        }
    }

    /// SYSTIMER_UNIT1_VALUE_HI.
    public var unit1_value_hi: Register<UNIT1_VALUE_HI> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x48)
        }
    }

    /// SYSTIMER_UNIT1_VALUE_LO.
    public var unit1_value_lo: Register<UNIT1_VALUE_LO> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4c)
        }
    }

    /// SYSTIMER_COMP0_LOAD.
    public var comp0_load: Register<COMP0_LOAD> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x50)
        }
    }

    /// SYSTIMER_COMP1_LOAD.
    public var comp1_load: Register<COMP1_LOAD> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x54)
        }
    }

    /// SYSTIMER_COMP2_LOAD.
    public var comp2_load: Register<COMP2_LOAD> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x58)
        }
    }

    /// SYSTIMER_UNIT0_LOAD.
    public var unit0_load: Register<UNIT0_LOAD> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x5c)
        }
    }

    /// SYSTIMER_UNIT1_LOAD.
    public var unit1_load: Register<UNIT1_LOAD> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x60)
        }
    }

    /// SYSTIMER_INT_ENA.
    public var int_ena: Register<INT_ENA> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x64)
        }
    }

    /// SYSTIMER_INT_RAW.
    public var int_raw: Register<INT_RAW> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x68)
        }
    }

    /// SYSTIMER_INT_CLR.
    public var int_clr: Register<INT_CLR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x6c)
        }
    }

    /// SYSTIMER_INT_ST.
    public var int_st: Register<INT_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x70)
        }
    }

    /// SYSTIMER_DATE.
    public var date: Register<DATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xfc)
        }
    }

    // Phantom types
    public struct CONF {}
    public struct UNIT0_OP {}
    public struct UNIT1_OP {}
    public struct UNIT0_LOAD_HI {}
    public struct UNIT0_LOAD_LO {}
    public struct UNIT1_LOAD_HI {}
    public struct UNIT1_LOAD_LO {}
    public struct TARGET0_HI {}
    public struct TARGET0_LO {}
    public struct TARGET1_HI {}
    public struct TARGET1_LO {}
    public struct TARGET2_HI {}
    public struct TARGET2_LO {}
    public struct TARGET0_CONF {}
    public struct TARGET1_CONF {}
    public struct TARGET2_CONF {}
    public struct UNIT0_VALUE_HI {}
    public struct UNIT0_VALUE_LO {}
    public struct UNIT1_VALUE_HI {}
    public struct UNIT1_VALUE_LO {}
    public struct COMP0_LOAD {}
    public struct COMP1_LOAD {}
    public struct COMP2_LOAD {}
    public struct UNIT0_LOAD {}
    public struct UNIT1_LOAD {}
    public struct INT_ENA {}
    public struct INT_RAW {}
    public struct INT_CLR {}
    public struct INT_ST {}
    public struct DATE {}
}
