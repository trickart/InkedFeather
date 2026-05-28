// Generated from esp32c3.svd — do not edit.

/// Interrupt Controller (Core 0)
public struct INTERRUPT_CORE0 {
    @usableFromInline let _base: UInt

    @inline(__always)
    public init(unsafeAddress: UInt) {
        self._base = unsafeAddress
    }

    /// mac intr map register
    public var mac_intr_map: Register<MAC_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base)
        }
    }

    /// mac nmi_intr map register
    public var mac_nmi_map: Register<MAC_NMI_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4)
        }
    }

    /// pwr intr map register
    public var pwr_intr_map: Register<PWR_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8)
        }
    }

    /// bb intr map register
    public var bb_int_map: Register<BB_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc)
        }
    }

    /// bt intr map register
    public var bt_mac_int_map: Register<BT_MAC_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x10)
        }
    }

    /// bb_bt intr map register
    public var bt_bb_int_map: Register<BT_BB_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x14)
        }
    }

    /// bb_bt_nmi intr map register
    public var bt_bb_nmi_map: Register<BT_BB_NMI_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x18)
        }
    }

    /// rwbt intr map register
    public var rwbt_irq_map: Register<RWBT_IRQ_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x1c)
        }
    }

    /// rwble intr map register
    public var rwble_irq_map: Register<RWBLE_IRQ_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x20)
        }
    }

    /// rwbt_nmi intr map register
    public var rwbt_nmi_map: Register<RWBT_NMI_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x24)
        }
    }

    /// rwble_nmi intr map register
    public var rwble_nmi_map: Register<RWBLE_NMI_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x28)
        }
    }

    /// i2c intr map register
    public var i2c_mst_int_map: Register<I2C_MST_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x2c)
        }
    }

    /// slc0 intr map register
    public var slc0_intr_map: Register<SLC0_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x30)
        }
    }

    /// slc1 intr map register
    public var slc1_intr_map: Register<SLC1_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x34)
        }
    }

    /// apb_ctrl intr map register
    public var apb_ctrl_intr_map: Register<APB_CTRL_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x38)
        }
    }

    /// uchi0 intr map register
    public var uhci0_intr_map: Register<UHCI0_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x3c)
        }
    }

    /// gpio intr map register
    public var gpio_interrupt_pro_map: Register<GPIO_INTERRUPT_PRO_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x40)
        }
    }

    /// gpio_pro intr map register
    public var gpio_interrupt_pro_nmi_map: Register<GPIO_INTERRUPT_PRO_NMI_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x44)
        }
    }

    /// gpio_pro_nmi intr map register
    public var spi_intr_1_map: Register<SPI_INTR_1_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x48)
        }
    }

    /// spi1 intr map register
    public var spi_intr_2_map: Register<SPI_INTR_2_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4c)
        }
    }

    /// spi2 intr map register
    public var i2s1_int_map: Register<I2S1_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x50)
        }
    }

    /// i2s1 intr map register
    public var uart_intr_map: Register<UART_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x54)
        }
    }

    /// uart1 intr map register
    public var uart1_intr_map: Register<UART1_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x58)
        }
    }

    /// ledc intr map register
    public var ledc_int_map: Register<LEDC_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x5c)
        }
    }

    /// efuse intr map register
    public var efuse_int_map: Register<EFUSE_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x60)
        }
    }

    /// can intr map register
    public var can_int_map: Register<CAN_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x64)
        }
    }

    /// usb intr map register
    public var usb_intr_map: Register<USB_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x68)
        }
    }

    /// rtc intr map register
    public var rtc_core_intr_map: Register<RTC_CORE_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x6c)
        }
    }

    /// rmt intr map register
    public var rmt_intr_map: Register<RMT_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x70)
        }
    }

    /// i2c intr map register
    public var i2c_ext0_intr_map: Register<I2C_EXT0_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x74)
        }
    }

    /// timer1 intr map register
    public var timer_int1_map: Register<TIMER_INT1_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x78)
        }
    }

    /// timer2 intr map register
    public var timer_int2_map: Register<TIMER_INT2_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x7c)
        }
    }

    /// tg to intr map register
    public var tg_t0_int_map: Register<TG_T0_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x80)
        }
    }

    /// tg wdt intr map register
    public var tg_wdt_int_map: Register<TG_WDT_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x84)
        }
    }

    /// tg1 to intr map register
    public var tg1_t0_int_map: Register<TG1_T0_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x88)
        }
    }

    /// tg1 wdt intr map register
    public var tg1_wdt_int_map: Register<TG1_WDT_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8c)
        }
    }

    /// cache ia intr map register
    public var cache_ia_int_map: Register<CACHE_IA_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x90)
        }
    }

    /// systimer intr map register
    public var systimer_target0_int_map: Register<SYSTIMER_TARGET0_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x94)
        }
    }

    /// systimer target1 intr map register
    public var systimer_target1_int_map: Register<SYSTIMER_TARGET1_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x98)
        }
    }

    /// systimer target2 intr map register
    public var systimer_target2_int_map: Register<SYSTIMER_TARGET2_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x9c)
        }
    }

    /// spi mem reject intr map register
    public var spi_mem_reject_intr_map: Register<SPI_MEM_REJECT_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xa0)
        }
    }

    /// icache perload intr map register
    public var icache_preload_int_map: Register<ICACHE_PRELOAD_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xa4)
        }
    }

    /// icache sync intr map register
    public var icache_sync_int_map: Register<ICACHE_SYNC_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xa8)
        }
    }

    /// adc intr map register
    public var apb_adc_int_map: Register<APB_ADC_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xac)
        }
    }

    /// dma ch0 intr map register
    public var dma_ch0_int_map: Register<DMA_CH0_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xb0)
        }
    }

    /// dma ch1 intr map register
    public var dma_ch1_int_map: Register<DMA_CH1_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xb4)
        }
    }

    /// dma ch2 intr map register
    public var dma_ch2_int_map: Register<DMA_CH2_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xb8)
        }
    }

    /// rsa intr map register
    public var rsa_int_map: Register<RSA_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xbc)
        }
    }

    /// aes intr map register
    public var aes_int_map: Register<AES_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc0)
        }
    }

    /// sha intr map register
    public var sha_int_map: Register<SHA_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc4)
        }
    }

    /// cpu from cpu 0 intr map register
    public var cpu_intr_from_cpu_0_map: Register<CPU_INTR_FROM_CPU_0_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc8)
        }
    }

    /// cpu from cpu 0 intr map register
    public var cpu_intr_from_cpu_1_map: Register<CPU_INTR_FROM_CPU_1_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xcc)
        }
    }

    /// cpu from cpu 1 intr map register
    public var cpu_intr_from_cpu_2_map: Register<CPU_INTR_FROM_CPU_2_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xd0)
        }
    }

    /// cpu from cpu 3 intr map register
    public var cpu_intr_from_cpu_3_map: Register<CPU_INTR_FROM_CPU_3_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xd4)
        }
    }

    /// assist debug intr map register
    public var assist_debug_intr_map: Register<ASSIST_DEBUG_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xd8)
        }
    }

    /// dma pms violatile intr map register
    public var dma_apbperi_pms_monitor_violate_intr_map: Register<DMA_APBPERI_PMS_MONITOR_VIOLATE_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xdc)
        }
    }

    /// iram0 pms violatile intr map register
    public var core_0_iram0_pms_monitor_violate_intr_map: Register<CORE_0_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xe0)
        }
    }

    /// mac intr map register
    public var core_0_dram0_pms_monitor_violate_intr_map: Register<CORE_0_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xe4)
        }
    }

    /// mac intr map register
    public var core_0_pif_pms_monitor_violate_intr_map: Register<CORE_0_PIF_PMS_MONITOR_VIOLATE_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xe8)
        }
    }

    /// mac intr map register
    public var core_0_pif_pms_monitor_violate_size_intr_map: Register<CORE_0_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xec)
        }
    }

    /// mac intr map register
    public var backup_pms_violate_intr_map: Register<BACKUP_PMS_VIOLATE_INTR_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xf0)
        }
    }

    /// mac intr map register
    public var cache_core0_acs_int_map: Register<CACHE_CORE0_ACS_INT_MAP> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xf4)
        }
    }

    /// mac intr map register
    public var intr_status_reg_0: Register<INTR_STATUS_REG_0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xf8)
        }
    }

    /// mac intr map register
    public var intr_status_reg_1: Register<INTR_STATUS_REG_1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xfc)
        }
    }

    /// mac intr map register
    public var clock_gate: Register<CLOCK_GATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x100)
        }
    }

    /// mac intr map register
    public var cpu_int_enable: Register<CPU_INT_ENABLE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x104)
        }
    }

    /// mac intr map register
    public var cpu_int_type: Register<CPU_INT_TYPE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x108)
        }
    }

    /// mac intr map register
    public var cpu_int_clear: Register<CPU_INT_CLEAR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x10c)
        }
    }

    /// mac intr map register
    public var cpu_int_eip_status: Register<CPU_INT_EIP_STATUS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x110)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_0: Register<CPU_INT_PRI_0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x114)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_1: Register<CPU_INT_PRI_1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x118)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_2: Register<CPU_INT_PRI_2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x11c)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_3: Register<CPU_INT_PRI_3> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x120)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_4: Register<CPU_INT_PRI_4> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x124)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_5: Register<CPU_INT_PRI_5> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x128)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_6: Register<CPU_INT_PRI_6> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x12c)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_7: Register<CPU_INT_PRI_7> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x130)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_8: Register<CPU_INT_PRI_8> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x134)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_9: Register<CPU_INT_PRI_9> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x138)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_10: Register<CPU_INT_PRI_10> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x13c)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_11: Register<CPU_INT_PRI_11> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x140)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_12: Register<CPU_INT_PRI_12> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x144)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_13: Register<CPU_INT_PRI_13> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x148)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_14: Register<CPU_INT_PRI_14> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x14c)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_15: Register<CPU_INT_PRI_15> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x150)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_16: Register<CPU_INT_PRI_16> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x154)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_17: Register<CPU_INT_PRI_17> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x158)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_18: Register<CPU_INT_PRI_18> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x15c)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_19: Register<CPU_INT_PRI_19> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x160)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_20: Register<CPU_INT_PRI_20> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x164)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_21: Register<CPU_INT_PRI_21> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x168)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_22: Register<CPU_INT_PRI_22> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x16c)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_23: Register<CPU_INT_PRI_23> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x170)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_24: Register<CPU_INT_PRI_24> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x174)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_25: Register<CPU_INT_PRI_25> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x178)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_26: Register<CPU_INT_PRI_26> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x17c)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_27: Register<CPU_INT_PRI_27> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x180)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_28: Register<CPU_INT_PRI_28> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x184)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_29: Register<CPU_INT_PRI_29> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x188)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_30: Register<CPU_INT_PRI_30> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x18c)
        }
    }

    /// mac intr map register
    public var cpu_int_pri_31: Register<CPU_INT_PRI_31> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x190)
        }
    }

    /// mac intr map register
    public var cpu_int_thresh: Register<CPU_INT_THRESH> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x194)
        }
    }

    /// mac intr map register
    public var interrupt_reg_date: Register<INTERRUPT_REG_DATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x7fc)
        }
    }

    // Phantom types
    public struct MAC_INTR_MAP {}
    public struct MAC_NMI_MAP {}
    public struct PWR_INTR_MAP {}
    public struct BB_INT_MAP {}
    public struct BT_MAC_INT_MAP {}
    public struct BT_BB_INT_MAP {}
    public struct BT_BB_NMI_MAP {}
    public struct RWBT_IRQ_MAP {}
    public struct RWBLE_IRQ_MAP {}
    public struct RWBT_NMI_MAP {}
    public struct RWBLE_NMI_MAP {}
    public struct I2C_MST_INT_MAP {}
    public struct SLC0_INTR_MAP {}
    public struct SLC1_INTR_MAP {}
    public struct APB_CTRL_INTR_MAP {}
    public struct UHCI0_INTR_MAP {}
    public struct GPIO_INTERRUPT_PRO_MAP {}
    public struct GPIO_INTERRUPT_PRO_NMI_MAP {}
    public struct SPI_INTR_1_MAP {}
    public struct SPI_INTR_2_MAP {}
    public struct I2S1_INT_MAP {}
    public struct UART_INTR_MAP {}
    public struct UART1_INTR_MAP {}
    public struct LEDC_INT_MAP {}
    public struct EFUSE_INT_MAP {}
    public struct CAN_INT_MAP {}
    public struct USB_INTR_MAP {}
    public struct RTC_CORE_INTR_MAP {}
    public struct RMT_INTR_MAP {}
    public struct I2C_EXT0_INTR_MAP {}
    public struct TIMER_INT1_MAP {}
    public struct TIMER_INT2_MAP {}
    public struct TG_T0_INT_MAP {}
    public struct TG_WDT_INT_MAP {}
    public struct TG1_T0_INT_MAP {}
    public struct TG1_WDT_INT_MAP {}
    public struct CACHE_IA_INT_MAP {}
    public struct SYSTIMER_TARGET0_INT_MAP {}
    public struct SYSTIMER_TARGET1_INT_MAP {}
    public struct SYSTIMER_TARGET2_INT_MAP {}
    public struct SPI_MEM_REJECT_INTR_MAP {}
    public struct ICACHE_PRELOAD_INT_MAP {}
    public struct ICACHE_SYNC_INT_MAP {}
    public struct APB_ADC_INT_MAP {}
    public struct DMA_CH0_INT_MAP {}
    public struct DMA_CH1_INT_MAP {}
    public struct DMA_CH2_INT_MAP {}
    public struct RSA_INT_MAP {}
    public struct AES_INT_MAP {}
    public struct SHA_INT_MAP {}
    public struct CPU_INTR_FROM_CPU_0_MAP {}
    public struct CPU_INTR_FROM_CPU_1_MAP {}
    public struct CPU_INTR_FROM_CPU_2_MAP {}
    public struct CPU_INTR_FROM_CPU_3_MAP {}
    public struct ASSIST_DEBUG_INTR_MAP {}
    public struct DMA_APBPERI_PMS_MONITOR_VIOLATE_INTR_MAP {}
    public struct CORE_0_IRAM0_PMS_MONITOR_VIOLATE_INTR_MAP {}
    public struct CORE_0_DRAM0_PMS_MONITOR_VIOLATE_INTR_MAP {}
    public struct CORE_0_PIF_PMS_MONITOR_VIOLATE_INTR_MAP {}
    public struct CORE_0_PIF_PMS_MONITOR_VIOLATE_SIZE_INTR_MAP {}
    public struct BACKUP_PMS_VIOLATE_INTR_MAP {}
    public struct CACHE_CORE0_ACS_INT_MAP {}
    public struct INTR_STATUS_REG_0 {}
    public struct INTR_STATUS_REG_1 {}
    public struct CLOCK_GATE {}
    public struct CPU_INT_ENABLE {}
    public struct CPU_INT_TYPE {}
    public struct CPU_INT_CLEAR {}
    public struct CPU_INT_EIP_STATUS {}
    public struct CPU_INT_PRI_0 {}
    public struct CPU_INT_PRI_1 {}
    public struct CPU_INT_PRI_2 {}
    public struct CPU_INT_PRI_3 {}
    public struct CPU_INT_PRI_4 {}
    public struct CPU_INT_PRI_5 {}
    public struct CPU_INT_PRI_6 {}
    public struct CPU_INT_PRI_7 {}
    public struct CPU_INT_PRI_8 {}
    public struct CPU_INT_PRI_9 {}
    public struct CPU_INT_PRI_10 {}
    public struct CPU_INT_PRI_11 {}
    public struct CPU_INT_PRI_12 {}
    public struct CPU_INT_PRI_13 {}
    public struct CPU_INT_PRI_14 {}
    public struct CPU_INT_PRI_15 {}
    public struct CPU_INT_PRI_16 {}
    public struct CPU_INT_PRI_17 {}
    public struct CPU_INT_PRI_18 {}
    public struct CPU_INT_PRI_19 {}
    public struct CPU_INT_PRI_20 {}
    public struct CPU_INT_PRI_21 {}
    public struct CPU_INT_PRI_22 {}
    public struct CPU_INT_PRI_23 {}
    public struct CPU_INT_PRI_24 {}
    public struct CPU_INT_PRI_25 {}
    public struct CPU_INT_PRI_26 {}
    public struct CPU_INT_PRI_27 {}
    public struct CPU_INT_PRI_28 {}
    public struct CPU_INT_PRI_29 {}
    public struct CPU_INT_PRI_30 {}
    public struct CPU_INT_PRI_31 {}
    public struct CPU_INT_THRESH {}
    public struct INTERRUPT_REG_DATE {}
}
