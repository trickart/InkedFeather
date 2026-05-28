// Generated from esp32c3.svd — do not edit.

/// External Memory
public struct EXTMEM {
    @usableFromInline let _base: UInt

    @inline(__always)
    public init(unsafeAddress: UInt) {
        self._base = unsafeAddress
    }

    /// This description will be updated in the near future.
    public var icache_ctrl: Register<ICACHE_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base)
        }
    }

    /// This description will be updated in the near future.
    public var icache_ctrl1: Register<ICACHE_CTRL1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4)
        }
    }

    /// This description will be updated in the near future.
    public var icache_tag_power_ctrl: Register<ICACHE_TAG_POWER_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8)
        }
    }

    /// This description will be updated in the near future.
    public var icache_prelock_ctrl: Register<ICACHE_PRELOCK_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc)
        }
    }

    /// This description will be updated in the near future.
    public var icache_prelock_sct0_addr: Register<ICACHE_PRELOCK_SCT0_ADDR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x10)
        }
    }

    /// This description will be updated in the near future.
    public var icache_prelock_sct1_addr: Register<ICACHE_PRELOCK_SCT1_ADDR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x14)
        }
    }

    /// This description will be updated in the near future.
    public var icache_prelock_sct_size: Register<ICACHE_PRELOCK_SCT_SIZE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x18)
        }
    }

    /// This description will be updated in the near future.
    public var icache_lock_ctrl: Register<ICACHE_LOCK_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x1c)
        }
    }

    /// This description will be updated in the near future.
    public var icache_lock_addr: Register<ICACHE_LOCK_ADDR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x20)
        }
    }

    /// This description will be updated in the near future.
    public var icache_lock_size: Register<ICACHE_LOCK_SIZE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x24)
        }
    }

    /// This description will be updated in the near future.
    public var icache_sync_ctrl: Register<ICACHE_SYNC_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x28)
        }
    }

    /// This description will be updated in the near future.
    public var icache_sync_addr: Register<ICACHE_SYNC_ADDR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x2c)
        }
    }

    /// This description will be updated in the near future.
    public var icache_sync_size: Register<ICACHE_SYNC_SIZE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x30)
        }
    }

    /// This description will be updated in the near future.
    public var icache_preload_ctrl: Register<ICACHE_PRELOAD_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x34)
        }
    }

    /// This description will be updated in the near future.
    public var icache_preload_addr: Register<ICACHE_PRELOAD_ADDR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x38)
        }
    }

    /// This description will be updated in the near future.
    public var icache_preload_size: Register<ICACHE_PRELOAD_SIZE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x3c)
        }
    }

    /// This description will be updated in the near future.
    public var icache_autoload_ctrl: Register<ICACHE_AUTOLOAD_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x40)
        }
    }

    /// This description will be updated in the near future.
    public var icache_autoload_sct0_addr: Register<ICACHE_AUTOLOAD_SCT0_ADDR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x44)
        }
    }

    /// This description will be updated in the near future.
    public var icache_autoload_sct0_size: Register<ICACHE_AUTOLOAD_SCT0_SIZE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x48)
        }
    }

    /// This description will be updated in the near future.
    public var icache_autoload_sct1_addr: Register<ICACHE_AUTOLOAD_SCT1_ADDR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4c)
        }
    }

    /// This description will be updated in the near future.
    public var icache_autoload_sct1_size: Register<ICACHE_AUTOLOAD_SCT1_SIZE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x50)
        }
    }

    /// This description will be updated in the near future.
    public var ibus_to_flash_start_vaddr: Register<IBUS_TO_FLASH_START_VADDR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x54)
        }
    }

    /// This description will be updated in the near future.
    public var ibus_to_flash_end_vaddr: Register<IBUS_TO_FLASH_END_VADDR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x58)
        }
    }

    /// This description will be updated in the near future.
    public var dbus_to_flash_start_vaddr: Register<DBUS_TO_FLASH_START_VADDR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x5c)
        }
    }

    /// This description will be updated in the near future.
    public var dbus_to_flash_end_vaddr: Register<DBUS_TO_FLASH_END_VADDR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x60)
        }
    }

    /// This description will be updated in the near future.
    public var cache_acs_cnt_clr: Register<CACHE_ACS_CNT_CLR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x64)
        }
    }

    /// This description will be updated in the near future.
    public var ibus_acs_miss_cnt: Register<IBUS_ACS_MISS_CNT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x68)
        }
    }

    /// This description will be updated in the near future.
    public var ibus_acs_cnt: Register<IBUS_ACS_CNT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x6c)
        }
    }

    /// This description will be updated in the near future.
    public var dbus_acs_flash_miss_cnt: Register<DBUS_ACS_FLASH_MISS_CNT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x70)
        }
    }

    /// This description will be updated in the near future.
    public var dbus_acs_cnt: Register<DBUS_ACS_CNT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x74)
        }
    }

    /// This description will be updated in the near future.
    public var cache_ilg_int_ena: Register<CACHE_ILG_INT_ENA> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x78)
        }
    }

    /// This description will be updated in the near future.
    public var cache_ilg_int_clr: Register<CACHE_ILG_INT_CLR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x7c)
        }
    }

    /// This description will be updated in the near future.
    public var cache_ilg_int_st: Register<CACHE_ILG_INT_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x80)
        }
    }

    /// This description will be updated in the near future.
    public var core0_acs_cache_int_ena: Register<CORE0_ACS_CACHE_INT_ENA> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x84)
        }
    }

    /// This description will be updated in the near future.
    public var core0_acs_cache_int_clr: Register<CORE0_ACS_CACHE_INT_CLR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x88)
        }
    }

    /// This description will be updated in the near future.
    public var core0_acs_cache_int_st: Register<CORE0_ACS_CACHE_INT_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8c)
        }
    }

    /// This description will be updated in the near future.
    public var core0_dbus_reject_st: Register<CORE0_DBUS_REJECT_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x90)
        }
    }

    /// This description will be updated in the near future.
    public var core0_dbus_reject_vaddr: Register<CORE0_DBUS_REJECT_VADDR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x94)
        }
    }

    /// This description will be updated in the near future.
    public var core0_ibus_reject_st: Register<CORE0_IBUS_REJECT_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x98)
        }
    }

    /// This description will be updated in the near future.
    public var core0_ibus_reject_vaddr: Register<CORE0_IBUS_REJECT_VADDR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x9c)
        }
    }

    /// This description will be updated in the near future.
    public var cache_mmu_fault_content: Register<CACHE_MMU_FAULT_CONTENT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xa0)
        }
    }

    /// This description will be updated in the near future.
    public var cache_mmu_fault_vaddr: Register<CACHE_MMU_FAULT_VADDR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xa4)
        }
    }

    /// This description will be updated in the near future.
    public var cache_wrap_around_ctrl: Register<CACHE_WRAP_AROUND_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xa8)
        }
    }

    /// This description will be updated in the near future.
    public var cache_mmu_power_ctrl: Register<CACHE_MMU_POWER_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xac)
        }
    }

    /// This description will be updated in the near future.
    public var cache_state: Register<CACHE_STATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xb0)
        }
    }

    /// This description will be updated in the near future.
    public var cache_encrypt_decrypt_record_disable: Register<CACHE_ENCRYPT_DECRYPT_RECORD_DISABLE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xb4)
        }
    }

    /// This description will be updated in the near future.
    public var cache_encrypt_decrypt_clk_force_on: Register<CACHE_ENCRYPT_DECRYPT_CLK_FORCE_ON> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xb8)
        }
    }

    /// This description will be updated in the near future.
    public var cache_preload_int_ctrl: Register<CACHE_PRELOAD_INT_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xbc)
        }
    }

    /// This description will be updated in the near future.
    public var cache_sync_int_ctrl: Register<CACHE_SYNC_INT_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc0)
        }
    }

    /// This description will be updated in the near future.
    public var cache_mmu_owner: Register<CACHE_MMU_OWNER> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc4)
        }
    }

    /// This description will be updated in the near future.
    public var cache_conf_misc: Register<CACHE_CONF_MISC> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc8)
        }
    }

    /// This description will be updated in the near future.
    public var icache_freeze: Register<ICACHE_FREEZE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xcc)
        }
    }

    /// This description will be updated in the near future.
    public var icache_atomic_operate_ena: Register<ICACHE_ATOMIC_OPERATE_ENA> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xd0)
        }
    }

    /// This description will be updated in the near future.
    public var cache_request: Register<CACHE_REQUEST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xd4)
        }
    }

    /// This description will be updated in the near future.
    public var ibus_pms_tbl_lock: Register<IBUS_PMS_TBL_LOCK> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xd8)
        }
    }

    /// This description will be updated in the near future.
    public var ibus_pms_tbl_boundary0: Register<IBUS_PMS_TBL_BOUNDARY0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xdc)
        }
    }

    /// This description will be updated in the near future.
    public var ibus_pms_tbl_boundary1: Register<IBUS_PMS_TBL_BOUNDARY1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xe0)
        }
    }

    /// This description will be updated in the near future.
    public var ibus_pms_tbl_boundary2: Register<IBUS_PMS_TBL_BOUNDARY2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xe4)
        }
    }

    /// This description will be updated in the near future.
    public var ibus_pms_tbl_attr: Register<IBUS_PMS_TBL_ATTR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xe8)
        }
    }

    /// This description will be updated in the near future.
    public var dbus_pms_tbl_lock: Register<DBUS_PMS_TBL_LOCK> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xec)
        }
    }

    /// This description will be updated in the near future.
    public var dbus_pms_tbl_boundary0: Register<DBUS_PMS_TBL_BOUNDARY0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xf0)
        }
    }

    /// This description will be updated in the near future.
    public var dbus_pms_tbl_boundary1: Register<DBUS_PMS_TBL_BOUNDARY1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xf4)
        }
    }

    /// This description will be updated in the near future.
    public var dbus_pms_tbl_boundary2: Register<DBUS_PMS_TBL_BOUNDARY2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xf8)
        }
    }

    /// This description will be updated in the near future.
    public var dbus_pms_tbl_attr: Register<DBUS_PMS_TBL_ATTR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xfc)
        }
    }

    /// This description will be updated in the near future.
    public var clock_gate: Register<CLOCK_GATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x100)
        }
    }

    /// This description will be updated in the near future.
    public var reg_date: Register<REG_DATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x3fc)
        }
    }

    // Phantom types
    public struct ICACHE_CTRL {}
    public struct ICACHE_CTRL1 {}
    public struct ICACHE_TAG_POWER_CTRL {}
    public struct ICACHE_PRELOCK_CTRL {}
    public struct ICACHE_PRELOCK_SCT0_ADDR {}
    public struct ICACHE_PRELOCK_SCT1_ADDR {}
    public struct ICACHE_PRELOCK_SCT_SIZE {}
    public struct ICACHE_LOCK_CTRL {}
    public struct ICACHE_LOCK_ADDR {}
    public struct ICACHE_LOCK_SIZE {}
    public struct ICACHE_SYNC_CTRL {}
    public struct ICACHE_SYNC_ADDR {}
    public struct ICACHE_SYNC_SIZE {}
    public struct ICACHE_PRELOAD_CTRL {}
    public struct ICACHE_PRELOAD_ADDR {}
    public struct ICACHE_PRELOAD_SIZE {}
    public struct ICACHE_AUTOLOAD_CTRL {}
    public struct ICACHE_AUTOLOAD_SCT0_ADDR {}
    public struct ICACHE_AUTOLOAD_SCT0_SIZE {}
    public struct ICACHE_AUTOLOAD_SCT1_ADDR {}
    public struct ICACHE_AUTOLOAD_SCT1_SIZE {}
    public struct IBUS_TO_FLASH_START_VADDR {}
    public struct IBUS_TO_FLASH_END_VADDR {}
    public struct DBUS_TO_FLASH_START_VADDR {}
    public struct DBUS_TO_FLASH_END_VADDR {}
    public struct CACHE_ACS_CNT_CLR {}
    public struct IBUS_ACS_MISS_CNT {}
    public struct IBUS_ACS_CNT {}
    public struct DBUS_ACS_FLASH_MISS_CNT {}
    public struct DBUS_ACS_CNT {}
    public struct CACHE_ILG_INT_ENA {}
    public struct CACHE_ILG_INT_CLR {}
    public struct CACHE_ILG_INT_ST {}
    public struct CORE0_ACS_CACHE_INT_ENA {}
    public struct CORE0_ACS_CACHE_INT_CLR {}
    public struct CORE0_ACS_CACHE_INT_ST {}
    public struct CORE0_DBUS_REJECT_ST {}
    public struct CORE0_DBUS_REJECT_VADDR {}
    public struct CORE0_IBUS_REJECT_ST {}
    public struct CORE0_IBUS_REJECT_VADDR {}
    public struct CACHE_MMU_FAULT_CONTENT {}
    public struct CACHE_MMU_FAULT_VADDR {}
    public struct CACHE_WRAP_AROUND_CTRL {}
    public struct CACHE_MMU_POWER_CTRL {}
    public struct CACHE_STATE {}
    public struct CACHE_ENCRYPT_DECRYPT_RECORD_DISABLE {}
    public struct CACHE_ENCRYPT_DECRYPT_CLK_FORCE_ON {}
    public struct CACHE_PRELOAD_INT_CTRL {}
    public struct CACHE_SYNC_INT_CTRL {}
    public struct CACHE_MMU_OWNER {}
    public struct CACHE_CONF_MISC {}
    public struct ICACHE_FREEZE {}
    public struct ICACHE_ATOMIC_OPERATE_ENA {}
    public struct CACHE_REQUEST {}
    public struct IBUS_PMS_TBL_LOCK {}
    public struct IBUS_PMS_TBL_BOUNDARY0 {}
    public struct IBUS_PMS_TBL_BOUNDARY1 {}
    public struct IBUS_PMS_TBL_BOUNDARY2 {}
    public struct IBUS_PMS_TBL_ATTR {}
    public struct DBUS_PMS_TBL_LOCK {}
    public struct DBUS_PMS_TBL_BOUNDARY0 {}
    public struct DBUS_PMS_TBL_BOUNDARY1 {}
    public struct DBUS_PMS_TBL_BOUNDARY2 {}
    public struct DBUS_PMS_TBL_ATTR {}
    public struct CLOCK_GATE {}
    public struct REG_DATE {}
}
