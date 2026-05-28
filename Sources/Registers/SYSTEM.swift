// Generated from esp32c3.svd — do not edit.

/// System Configuration Registers
public struct SYSTEM {
    @usableFromInline let _base: UInt

    @inline(__always)
    public init(unsafeAddress: UInt) {
        self._base = unsafeAddress
    }

    /// cpu_peripheral clock gating register
    public var cpu_peri_clk_en: Register<CPU_PERI_CLK_EN> {
        @inline(__always) get {
            Register(unsafeAddress: _base)
        }
    }

    /// cpu_peripheral reset register
    public var cpu_peri_rst_en: Register<CPU_PERI_RST_EN> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4)
        }
    }

    /// cpu clock config register
    public var cpu_per_conf: Register<CPU_PER_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8)
        }
    }

    /// memory power down mask register
    public var mem_pd_mask: Register<MEM_PD_MASK> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc)
        }
    }

    /// peripheral clock gating register
    public var perip_clk_en0: Register<PERIP_CLK_EN0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x10)
        }
    }

    /// peripheral clock gating register
    public var perip_clk_en1: Register<PERIP_CLK_EN1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x14)
        }
    }

    /// reserved
    public var perip_rst_en0: Register<PERIP_RST_EN0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x18)
        }
    }

    /// peripheral reset register
    public var perip_rst_en1: Register<PERIP_RST_EN1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x1c)
        }
    }

    /// clock config register
    public var bt_lpck_div_int: Register<BT_LPCK_DIV_INT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x20)
        }
    }

    /// clock config register
    public var bt_lpck_div_frac: Register<BT_LPCK_DIV_FRAC> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x24)
        }
    }

    /// interrupt generate register
    public var cpu_intr_from_cpu_0: Register<CPU_INTR_FROM_CPU_0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x28)
        }
    }

    /// interrupt generate register
    public var cpu_intr_from_cpu_1: Register<CPU_INTR_FROM_CPU_1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x2c)
        }
    }

    /// interrupt generate register
    public var cpu_intr_from_cpu_2: Register<CPU_INTR_FROM_CPU_2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x30)
        }
    }

    /// interrupt generate register
    public var cpu_intr_from_cpu_3: Register<CPU_INTR_FROM_CPU_3> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x34)
        }
    }

    /// rsa memory power control register
    public var rsa_pd_ctrl: Register<RSA_PD_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x38)
        }
    }

    /// EDMA clock and reset register
    public var edma_ctrl: Register<EDMA_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x3c)
        }
    }

    /// cache control register
    public var cache_control: Register<CACHE_CONTROL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x40)
        }
    }

    /// SYSTEM_EXTERNAL_DEVICE_ENCRYPT_DECRYPT_CONTROL_REG
    public var external_device_encrypt_decrypt_control: Register<EXTERNAL_DEVICE_ENCRYPT_DECRYPT_CONTROL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x44)
        }
    }

    /// fast memory config register
    public var rtc_fastmem_config: Register<RTC_FASTMEM_CONFIG> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x48)
        }
    }

    /// reserved
    public var rtc_fastmem_crc: Register<RTC_FASTMEM_CRC> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4c)
        }
    }

    /// eco register
    public var redundant_eco_ctrl: Register<REDUNDANT_ECO_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x50)
        }
    }

    /// clock gating register
    public var clock_gate: Register<CLOCK_GATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x54)
        }
    }

    /// system clock config register
    public var sysclk_conf: Register<SYSCLK_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x58)
        }
    }

    /// mem pvt register
    public var mem_pvt: Register<MEM_PVT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x5c)
        }
    }

    /// mem pvt register
    public var comb_pvt_lvt_conf: Register<COMB_PVT_LVT_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x60)
        }
    }

    /// mem pvt register
    public var comb_pvt_nvt_conf: Register<COMB_PVT_NVT_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x64)
        }
    }

    /// mem pvt register
    public var comb_pvt_hvt_conf: Register<COMB_PVT_HVT_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x68)
        }
    }

    /// mem pvt register
    public var comb_pvt_err_lvt_site0: Register<COMB_PVT_ERR_LVT_SITE0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x6c)
        }
    }

    /// mem pvt register
    public var comb_pvt_err_nvt_site0: Register<COMB_PVT_ERR_NVT_SITE0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x70)
        }
    }

    /// mem pvt register
    public var comb_pvt_err_hvt_site0: Register<COMB_PVT_ERR_HVT_SITE0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x74)
        }
    }

    /// mem pvt register
    public var comb_pvt_err_lvt_site1: Register<COMB_PVT_ERR_LVT_SITE1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x78)
        }
    }

    /// mem pvt register
    public var comb_pvt_err_nvt_site1: Register<COMB_PVT_ERR_NVT_SITE1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x7c)
        }
    }

    /// mem pvt register
    public var comb_pvt_err_hvt_site1: Register<COMB_PVT_ERR_HVT_SITE1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x80)
        }
    }

    /// mem pvt register
    public var comb_pvt_err_lvt_site2: Register<COMB_PVT_ERR_LVT_SITE2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x84)
        }
    }

    /// mem pvt register
    public var comb_pvt_err_nvt_site2: Register<COMB_PVT_ERR_NVT_SITE2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x88)
        }
    }

    /// mem pvt register
    public var comb_pvt_err_hvt_site2: Register<COMB_PVT_ERR_HVT_SITE2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8c)
        }
    }

    /// mem pvt register
    public var comb_pvt_err_lvt_site3: Register<COMB_PVT_ERR_LVT_SITE3> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x90)
        }
    }

    /// mem pvt register
    public var comb_pvt_err_nvt_site3: Register<COMB_PVT_ERR_NVT_SITE3> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x94)
        }
    }

    /// mem pvt register
    public var comb_pvt_err_hvt_site3: Register<COMB_PVT_ERR_HVT_SITE3> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x98)
        }
    }

    /// Version register
    public var system_reg_date: Register<SYSTEM_REG_DATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xffc)
        }
    }

    // Phantom types
    public struct CPU_PERI_CLK_EN {}
    public struct CPU_PERI_RST_EN {}
    public struct CPU_PER_CONF {}
    public struct MEM_PD_MASK {}
    public struct PERIP_CLK_EN0 {}
    public struct PERIP_CLK_EN1 {}
    public struct PERIP_RST_EN0 {}
    public struct PERIP_RST_EN1 {}
    public struct BT_LPCK_DIV_INT {}
    public struct BT_LPCK_DIV_FRAC {}
    public struct CPU_INTR_FROM_CPU_0 {}
    public struct CPU_INTR_FROM_CPU_1 {}
    public struct CPU_INTR_FROM_CPU_2 {}
    public struct CPU_INTR_FROM_CPU_3 {}
    public struct RSA_PD_CTRL {}
    public struct EDMA_CTRL {}
    public struct CACHE_CONTROL {}
    public struct EXTERNAL_DEVICE_ENCRYPT_DECRYPT_CONTROL {}
    public struct RTC_FASTMEM_CONFIG {}
    public struct RTC_FASTMEM_CRC {}
    public struct REDUNDANT_ECO_CTRL {}
    public struct CLOCK_GATE {}
    public struct SYSCLK_CONF {}
    public struct MEM_PVT {}
    public struct COMB_PVT_LVT_CONF {}
    public struct COMB_PVT_NVT_CONF {}
    public struct COMB_PVT_HVT_CONF {}
    public struct COMB_PVT_ERR_LVT_SITE0 {}
    public struct COMB_PVT_ERR_NVT_SITE0 {}
    public struct COMB_PVT_ERR_HVT_SITE0 {}
    public struct COMB_PVT_ERR_LVT_SITE1 {}
    public struct COMB_PVT_ERR_NVT_SITE1 {}
    public struct COMB_PVT_ERR_HVT_SITE1 {}
    public struct COMB_PVT_ERR_LVT_SITE2 {}
    public struct COMB_PVT_ERR_NVT_SITE2 {}
    public struct COMB_PVT_ERR_HVT_SITE2 {}
    public struct COMB_PVT_ERR_LVT_SITE3 {}
    public struct COMB_PVT_ERR_NVT_SITE3 {}
    public struct COMB_PVT_ERR_HVT_SITE3 {}
    public struct SYSTEM_REG_DATE {}
}
