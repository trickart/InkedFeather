// Generated from esp32c3.svd — do not edit.

/// SAR (Successive Approximation Register) Analog-to-Digital Converter
public struct APB_SARADC {
    @usableFromInline let _base: UInt

    @inline(__always)
    public init(unsafeAddress: UInt) {
        self._base = unsafeAddress
    }

    /// digital saradc configure register
    public var ctrl: Register<CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base)
        }
    }

    /// digital saradc configure register
    public var ctrl2: Register<CTRL2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4)
        }
    }

    /// digital saradc configure register
    public var filter_ctrl1: Register<FILTER_CTRL1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8)
        }
    }

    /// digital saradc configure register
    public var fsm_wait: Register<FSM_WAIT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc)
        }
    }

    /// digital saradc configure register
    public var sar1_status: Register<SAR1_STATUS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x10)
        }
    }

    /// digital saradc configure register
    public var sar2_status: Register<SAR2_STATUS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x14)
        }
    }

    /// digital saradc configure register
    public var sar_patt_tab1: Register<SAR_PATT_TAB1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x18)
        }
    }

    /// digital saradc configure register
    public var sar_patt_tab2: Register<SAR_PATT_TAB2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x1c)
        }
    }

    /// digital saradc configure register
    public var onetime_sample: Register<ONETIME_SAMPLE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x20)
        }
    }

    /// digital saradc configure register
    public var arb_ctrl: Register<ARB_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x24)
        }
    }

    /// digital saradc configure register
    public var filter_ctrl0: Register<FILTER_CTRL0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x28)
        }
    }

    /// digital saradc configure register
    public var sar1data_status: Register<SAR1DATA_STATUS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x2c)
        }
    }

    /// digital saradc configure register
    public var sar2data_status: Register<SAR2DATA_STATUS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x30)
        }
    }

    /// digital saradc configure register
    public var thres0_ctrl: Register<THRES0_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x34)
        }
    }

    /// digital saradc configure register
    public var thres1_ctrl: Register<THRES1_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x38)
        }
    }

    /// digital saradc configure register
    public var thres_ctrl: Register<THRES_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x3c)
        }
    }

    /// digital saradc int register
    public var int_ena: Register<INT_ENA> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x40)
        }
    }

    /// digital saradc int register
    public var int_raw: Register<INT_RAW> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x44)
        }
    }

    /// digital saradc int register
    public var int_st: Register<INT_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x48)
        }
    }

    /// digital saradc int register
    public var int_clr: Register<INT_CLR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4c)
        }
    }

    /// digital saradc configure register
    public var dma_conf: Register<DMA_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x50)
        }
    }

    /// digital saradc configure register
    public var clkm_conf: Register<CLKM_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x54)
        }
    }

    /// digital tsens configure register
    public var apb_tsens_ctrl: Register<APB_TSENS_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x58)
        }
    }

    /// digital tsens configure register
    public var tsens_ctrl2: Register<TSENS_CTRL2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x5c)
        }
    }

    /// digital saradc configure register
    public var cali: Register<CALI> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x60)
        }
    }

    /// version
    public var ctrl_date: Register<CTRL_DATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x3fc)
        }
    }

    // Phantom types
    public struct CTRL {}
    public struct CTRL2 {}
    public struct FILTER_CTRL1 {}
    public struct FSM_WAIT {}
    public struct SAR1_STATUS {}
    public struct SAR2_STATUS {}
    public struct SAR_PATT_TAB1 {}
    public struct SAR_PATT_TAB2 {}
    public struct ONETIME_SAMPLE {}
    public struct ARB_CTRL {}
    public struct FILTER_CTRL0 {}
    public struct SAR1DATA_STATUS {}
    public struct SAR2DATA_STATUS {}
    public struct THRES0_CTRL {}
    public struct THRES1_CTRL {}
    public struct THRES_CTRL {}
    public struct INT_ENA {}
    public struct INT_RAW {}
    public struct INT_ST {}
    public struct INT_CLR {}
    public struct DMA_CONF {}
    public struct CLKM_CONF {}
    public struct APB_TSENS_CTRL {}
    public struct TSENS_CTRL2 {}
    public struct CALI {}
    public struct CTRL_DATE {}
}
