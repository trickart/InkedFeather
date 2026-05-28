// Generated from esp32c3.svd — do not edit.

/// Real-Time Clock Control
public struct RTC_CNTL {
    @usableFromInline let _base: UInt

    @inline(__always)
    public init(unsafeAddress: UInt) {
        self._base = unsafeAddress
    }

    /// rtc configure register
    public var options0: Register<OPTIONS0> {
        @inline(__always) get {
            Register(unsafeAddress: _base)
        }
    }

    /// rtc configure register
    public var slp_timer0: Register<SLP_TIMER0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4)
        }
    }

    /// rtc configure register
    public var slp_timer1: Register<SLP_TIMER1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8)
        }
    }

    /// rtc configure register
    public var time_update: Register<TIME_UPDATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc)
        }
    }

    /// rtc configure register
    public var time_low0: Register<TIME_LOW0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x10)
        }
    }

    /// rtc configure register
    public var time_high0: Register<TIME_HIGH0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x14)
        }
    }

    /// rtc configure register
    public var state0: Register<STATE0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x18)
        }
    }

    /// rtc configure register
    public var timer1: Register<TIMER1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x1c)
        }
    }

    /// rtc configure register
    public var timer2: Register<TIMER2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x20)
        }
    }

    /// rtc configure register
    public var timer3: Register<TIMER3> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x24)
        }
    }

    /// rtc configure register
    public var timer4: Register<TIMER4> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x28)
        }
    }

    /// rtc configure register
    public var timer5: Register<TIMER5> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x2c)
        }
    }

    /// rtc configure register
    public var timer6: Register<TIMER6> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x30)
        }
    }

    /// rtc configure register
    public var ana_conf: Register<ANA_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x34)
        }
    }

    /// rtc configure register
    public var reset_state: Register<RESET_STATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x38)
        }
    }

    /// rtc configure register
    public var wakeup_state: Register<WAKEUP_STATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x3c)
        }
    }

    /// rtc configure register
    public var int_ena_rtc: Register<INT_ENA_RTC> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x40)
        }
    }

    /// rtc configure register
    public var int_raw_rtc: Register<INT_RAW_RTC> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x44)
        }
    }

    /// rtc configure register
    public var int_st_rtc: Register<INT_ST_RTC> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x48)
        }
    }

    /// rtc configure register
    public var int_clr_rtc: Register<INT_CLR_RTC> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4c)
        }
    }

    /// rtc configure register
    public var store0: Register<STORE0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x50)
        }
    }

    /// rtc configure register
    public var store1: Register<STORE1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x54)
        }
    }

    /// rtc configure register
    public var store2: Register<STORE2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x58)
        }
    }

    /// rtc configure register
    public var store3: Register<STORE3> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x5c)
        }
    }

    /// rtc configure register
    public var ext_xtl_conf: Register<EXT_XTL_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x60)
        }
    }

    /// rtc configure register
    public var ext_wakeup_conf: Register<EXT_WAKEUP_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x64)
        }
    }

    /// rtc configure register
    public var slp_reject_conf: Register<SLP_REJECT_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x68)
        }
    }

    /// rtc configure register
    public var cpu_period_conf: Register<CPU_PERIOD_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x6c)
        }
    }

    /// rtc configure register
    public var clk_conf: Register<CLK_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x70)
        }
    }

    /// rtc configure register
    public var slow_clk_conf: Register<SLOW_CLK_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x74)
        }
    }

    /// rtc configure register
    public var sdio_conf: Register<SDIO_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x78)
        }
    }

    /// rtc configure register
    public var bias_conf: Register<BIAS_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x7c)
        }
    }

    /// rtc configure register
    public var rtc_cntl: Register<RTC_CNTL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x80)
        }
    }

    /// rtc configure register
    public var pwc: Register<PWC> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x84)
        }
    }

    /// rtc configure register
    public var dig_pwc: Register<DIG_PWC> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x88)
        }
    }

    /// rtc configure register
    public var dig_iso: Register<DIG_ISO> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8c)
        }
    }

    /// rtc configure register
    public var wdtconfig0: Register<WDTCONFIG0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x90)
        }
    }

    /// rtc configure register
    public var wdtconfig1: Register<WDTCONFIG1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x94)
        }
    }

    /// rtc configure register
    public var wdtconfig2: Register<WDTCONFIG2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x98)
        }
    }

    /// rtc configure register
    public var wdtconfig3: Register<WDTCONFIG3> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x9c)
        }
    }

    /// rtc configure register
    public var wdtconfig4: Register<WDTCONFIG4> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xa0)
        }
    }

    /// rtc configure register
    public var wdtfeed: Register<WDTFEED> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xa4)
        }
    }

    /// rtc configure register
    public var wdtwprotect: Register<WDTWPROTECT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xa8)
        }
    }

    /// rtc configure register
    public var swd_conf: Register<SWD_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xac)
        }
    }

    /// rtc configure register
    public var swd_wprotect: Register<SWD_WPROTECT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xb0)
        }
    }

    /// rtc configure register
    public var sw_cpu_stall: Register<SW_CPU_STALL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xb4)
        }
    }

    /// rtc configure register
    public var store4: Register<STORE4> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xb8)
        }
    }

    /// rtc configure register
    public var store5: Register<STORE5> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xbc)
        }
    }

    /// rtc configure register
    public var store6: Register<STORE6> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc0)
        }
    }

    /// rtc configure register
    public var store7: Register<STORE7> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc4)
        }
    }

    /// rtc configure register
    public var low_power_st: Register<LOW_POWER_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc8)
        }
    }

    /// rtc configure register
    public var diag0: Register<DIAG0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xcc)
        }
    }

    /// rtc configure register
    public var pad_hold: Register<PAD_HOLD> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xd0)
        }
    }

    /// rtc configure register
    public var dig_pad_hold: Register<DIG_PAD_HOLD> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xd4)
        }
    }

    /// rtc configure register
    public var brown_out: Register<BROWN_OUT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xd8)
        }
    }

    /// rtc configure register
    public var time_low1: Register<TIME_LOW1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xdc)
        }
    }

    /// rtc configure register
    public var time_high1: Register<TIME_HIGH1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xe0)
        }
    }

    /// rtc configure register
    public var xtal32k_clk_factor: Register<XTAL32K_CLK_FACTOR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xe4)
        }
    }

    /// rtc configure register
    public var xtal32k_conf: Register<XTAL32K_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xe8)
        }
    }

    /// rtc configure register
    public var usb_conf: Register<USB_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xec)
        }
    }

    /// RTC_CNTL_RTC_SLP_REJECT_CAUSE_REG
    public var slp_reject_cause: Register<SLP_REJECT_CAUSE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xf0)
        }
    }

    /// rtc configure register
    public var option1: Register<OPTION1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xf4)
        }
    }

    /// RTC_CNTL_RTC_SLP_WAKEUP_CAUSE_REG
    public var slp_wakeup_cause: Register<SLP_WAKEUP_CAUSE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xf8)
        }
    }

    /// rtc configure register
    public var ulp_cp_timer_1: Register<ULP_CP_TIMER_1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xfc)
        }
    }

    /// rtc configure register
    public var int_ena_rtc_w1ts: Register<INT_ENA_RTC_W1TS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x100)
        }
    }

    /// rtc configure register
    public var int_ena_rtc_w1tc: Register<INT_ENA_RTC_W1TC> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x104)
        }
    }

    /// rtc configure register
    public var retention_ctrl: Register<RETENTION_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x108)
        }
    }

    /// rtc configure register
    public var fib_sel: Register<FIB_SEL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x10c)
        }
    }

    /// rtc configure register
    public var gpio_wakeup: Register<GPIO_WAKEUP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x110)
        }
    }

    /// rtc configure register
    public var dbg_sel: Register<DBG_SEL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x114)
        }
    }

    /// rtc configure register
    public var dbg_map: Register<DBG_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x118)
        }
    }

    /// rtc configure register
    public var sensor_ctrl: Register<SENSOR_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x11c)
        }
    }

    /// rtc configure register
    public var dbg_sar_sel: Register<DBG_SAR_SEL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x120)
        }
    }

    /// rtc configure register
    public var pg_ctrl: Register<PG_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x124)
        }
    }

    /// rtc configure register
    public var date: Register<DATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x1fc)
        }
    }

    // Phantom types
    public struct OPTIONS0 {}
    public struct SLP_TIMER0 {}
    public struct SLP_TIMER1 {}
    public struct TIME_UPDATE {}
    public struct TIME_LOW0 {}
    public struct TIME_HIGH0 {}
    public struct STATE0 {}
    public struct TIMER1 {}
    public struct TIMER2 {}
    public struct TIMER3 {}
    public struct TIMER4 {}
    public struct TIMER5 {}
    public struct TIMER6 {}
    public struct ANA_CONF {}
    public struct RESET_STATE {}
    public struct WAKEUP_STATE {}
    public struct INT_ENA_RTC {}
    public struct INT_RAW_RTC {}
    public struct INT_ST_RTC {}
    public struct INT_CLR_RTC {}
    public struct STORE0 {}
    public struct STORE1 {}
    public struct STORE2 {}
    public struct STORE3 {}
    public struct EXT_XTL_CONF {}
    public struct EXT_WAKEUP_CONF {}
    public struct SLP_REJECT_CONF {}
    public struct CPU_PERIOD_CONF {}
    public struct CLK_CONF {}
    public struct SLOW_CLK_CONF {}
    public struct SDIO_CONF {}
    public struct BIAS_CONF {}
    public struct RTC_CNTL {}
    public struct PWC {}
    public struct DIG_PWC {}
    public struct DIG_ISO {}
    public struct WDTCONFIG0 {}
    public struct WDTCONFIG1 {}
    public struct WDTCONFIG2 {}
    public struct WDTCONFIG3 {}
    public struct WDTCONFIG4 {}
    public struct WDTFEED {}
    public struct WDTWPROTECT {}
    public struct SWD_CONF {}
    public struct SWD_WPROTECT {}
    public struct SW_CPU_STALL {}
    public struct STORE4 {}
    public struct STORE5 {}
    public struct STORE6 {}
    public struct STORE7 {}
    public struct LOW_POWER_ST {}
    public struct DIAG0 {}
    public struct PAD_HOLD {}
    public struct DIG_PAD_HOLD {}
    public struct BROWN_OUT {}
    public struct TIME_LOW1 {}
    public struct TIME_HIGH1 {}
    public struct XTAL32K_CLK_FACTOR {}
    public struct XTAL32K_CONF {}
    public struct USB_CONF {}
    public struct SLP_REJECT_CAUSE {}
    public struct OPTION1 {}
    public struct SLP_WAKEUP_CAUSE {}
    public struct ULP_CP_TIMER_1 {}
    public struct INT_ENA_RTC_W1TS {}
    public struct INT_ENA_RTC_W1TC {}
    public struct RETENTION_CTRL {}
    public struct FIB_SEL {}
    public struct GPIO_WAKEUP {}
    public struct DBG_SEL {}
    public struct DBG_MAP {}
    public struct SENSOR_CTRL {}
    public struct DBG_SAR_SEL {}
    public struct PG_CTRL {}
    public struct DATE {}
}
