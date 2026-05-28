import Registers

/// ESP32-C3 ADC1 driver using oneshot (single-read) mode via APB_SARADC.
///
/// ADC1 channels on ESP32-C3:
///   Channel 0 = GPIO0, Channel 1 = GPIO1, Channel 2 = GPIO2,
///   Channel 3 = GPIO3, Channel 4 = GPIO4
///
/// Resolution: 12-bit (0–4095).
/// Attenuation levels: 0dB (~0-750mV), 2.5dB (~0-1050mV), 6dB (~0-1300mV), 11dB (~0-2500mV).
///
/// Initialization sequence derived from ESP-IDF adc_oneshot_hal.c / adc_ll.h for ESP32-C3.
struct ADCDriver {
    enum Attenuation: UInt32 {
        case db0   = 0  // ~0-750mV
        case db2_5 = 1  // ~0-1050mV
        case db6   = 2  // ~0-1300mV
        case db11  = 3  // ~0-2500mV
    }

    /// Configure a GPIO pin for ADC input.
    ///
    /// Disables the digital input buffer (fun_ie=0) and output,
    /// and removes pull-up/pull-down resistors to avoid interfering
    /// with the analog signal. ESP-IDF uses GPIO_MODE_DISABLE for this.
    static func configurePin(_ gpioNum: Int) {
        // IO_MUX: mcu_sel=1 (GPIO func), fun_ie=0, fun_wpu=0, fun_wpd=0
        io_mux.gpio[gpioNum].modify {
            $0.raw.storage = ($0.raw.storage & ~(0x7 << 12)) | (1 << 12)  // mcu_sel=1
            $0.raw.storage = $0.raw.storage & ~(1 << 9)   // fun_ie=0 (disable digital input buffer)
            $0.raw.storage = $0.raw.storage & ~(1 << 8)   // fun_wpu=0 (no pull-up)
            $0.raw.storage = $0.raw.storage & ~(1 << 7)   // fun_wpd=0 (no pull-down)
        }
        // Disable output
        gpio.enable_w1tc.write { $0.raw.storage = 1 << UInt32(gpioNum) }
    }

    // ESP32-C3 ROM I2C analog master functions (addresses from esp32c3.rom.ld).
    // Direct register manipulation does NOT work for this peripheral;
    // the ROM functions handle the I2C bus protocol internally.
    private static let I2C_SAR_ADC: UInt8 = 0x69
    private static let I2C_SAR_ADC_HOSTID: UInt8 = 0

    @_extern(c, "rom_i2c_writeReg_Mask")
    private static func _romI2cWriteRegMask(_ block: UInt8, _ hostId: UInt8, _ regAddr: UInt8, _ msb: UInt8, _ lsb: UInt8, _ data: UInt8)

    /// Write specific bits of a SAR ADC internal register via ROM I2C function.
    private static func i2cWriteMask(regAddr: UInt8, msb: UInt8, lsb: UInt8, data: UInt8) {
        _romI2cWriteRegMask(I2C_SAR_ADC, I2C_SAR_ADC_HOSTID, regAddr, msb, lsb, data)
    }

    /// Initialize the ADC1 peripheral.
    static func initialize() {
        // Enable APB_SARADC peripheral clock and perform a clean reset.
        // Assert reset first, then deassert, to clear any stale state.
        system.perip_clk_en0.modify { $0.raw.storage = $0.raw.storage | (1 << 28) }
        system.perip_rst_en0.modify { $0.raw.storage = $0.raw.storage | (1 << 28) }
        system.perip_rst_en0.modify { $0.raw.storage = $0.raw.storage & ~(1 << 28) }

        // Set SAR1_DREF = 4 (internal reference voltage level).
        // Required for correct ADC conversion — POR default (0) gives wrong readings.
        i2cWriteMask(regAddr: 0x2, msb: 6, lsb: 4, data: 4)
        // Ensure calibration inputs are disconnected for normal operation.
        i2cWriteMask(regAddr: 0x7, msb: 5, lsb: 5, data: 0)  // SAR1_ENCAL_GND = 0
        i2cWriteMask(regAddr: 0x7, msb: 4, lsb: 4, data: 0)  // SARADC1_ENCAL_REF = 0

        // Clock configuration (matching ESP-IDF defaults):
        //   clk_sel=2 (RC_FAST / FOSC), clk_en=1, clkm_div_num=15
        apb_saradc.clkm_conf.write {
            $0.raw.storage = (1 << 20)   // clk_en=1
                | (2 << 21)              // clk_sel=2 (FOSC_CLK)
                | (15 << 0)              // clkm_div_num=15
                | (0 << 8)               // clkm_div_b=0
                | (1 << 14)              // clkm_div_a=1
        }

        // CTRL register:
        //   sar_clk_gated=1 (bit 6)
        //   sar_clk_div=2 (bits 7-14, matching ESP-IDF default)
        //   sar_patt_len=0 (bits 15-17, means length 1)
        //   xpd_sar_force=3 (bits 27-28, SW mode power on)
        //   wait_arb_cycle=1 (bits 30-31)
        apb_saradc.ctrl.write {
            $0.raw.storage = (1 << 6)    // sar_clk_gated=1
                | (2 << 7)              // sar_clk_div=2
                | (0 << 15)             // sar_patt_len=0 (1 item)
                | (3 << 27)             // xpd_sar_force=3 (force power on)
                | (1 << 30)             // wait_arb_cycle=1
        }

        // Arbiter: APB controller priority
        apb_saradc.arb_ctrl.write {
            $0.raw.storage = (1 << 2)    // adc_arb_apb_force=1
                | (2 << 6)              // apb_priority=2
                | (1 << 8)              // rtc_priority=1
                | (0 << 10)             // wifi_priority=0
                | (1 << 12)             // fix_priority=1
        }

        // Disable DMA mode
        apb_saradc.dma_conf.write { $0.raw.storage = 0 }

        // FSM timing: match ESP-IDF defaults for proper sampling
        //   xpd_wait=8 (bits 0-7): power-up wait cycles
        //   rstb_wait=100 (bits 8-15): reset wait cycles
        //   standby_wait=100 (bits 16-23): standby wait cycles
        apb_saradc.fsm_wait.write {
            $0.raw.storage = (8 << 0) | (100 << 8) | (100 << 16)
        }

        // CTRL2: disable timer, no inversion
        apb_saradc.ctrl2.write { $0.raw.storage = 0 }

        // Run hardware calibration: measure internal ground offset and write
        // to INITIAL_CODE so the hardware compensates automatically.
        // Matches ESP-IDF adc_hal_calibration() / adc_hal_set_calibration_param().
        runHardwareCalibration()
    }

    /// Measure ADC ground offset and write to SAR1_INITIAL_CODE.
    ///
    /// Connects ADC to internal ground, takes multiple readings, averages
    /// them, and programs the result into the hardware offset registers.
    /// The hardware then subtracts this offset from all subsequent readings.
    /// Runs on every initialize() call (including after sleep wakeup).
    private static func runHardwareCalibration() {
        // 1. Connect ADC1 input to internal ground
        i2cWriteMask(regAddr: 0x7, msb: 5, lsb: 5, data: 1)  // SAR1_ENCAL_GND = 1

        // 2. Clear any existing INITIAL_CODE so it doesn't affect the measurement
        i2cWriteMask(regAddr: 0x0, msb: 7, lsb: 0, data: 0)
        i2cWriteMask(regAddr: 0x1, msb: 3, lsb: 0, data: 0)

        // 3. Take multiple readings and average (ESP-IDF uses 10 samples)
        var sum: UInt32 = 0
        for _ in 0..<10 {
            sum &+= readRaw(channel: 0, attenuation: .db11)
        }
        let avg = sum / 10

        // 4. Write calibration offset to INITIAL_CODE registers
        i2cWriteMask(regAddr: 0x0, msb: 7, lsb: 0, data: UInt8(avg & 0xFF))
        i2cWriteMask(regAddr: 0x1, msb: 3, lsb: 0, data: UInt8((avg >> 8) & 0xF))

        // 5. Disconnect from internal ground
        i2cWriteMask(regAddr: 0x7, msb: 5, lsb: 5, data: 0)  // SAR1_ENCAL_GND = 0
    }

    /// Raw read without calibration check (used during calibration itself).
    private static func readRaw(channel: UInt32, attenuation: Attenuation) -> UInt32 {
        let chanAtten: UInt32 = (attenuation.rawValue << 23) | (channel << 25)
        regStore(intClr, 1 << 31)
        regStore(onetimeSample, chanAtten)
        regStore(onetimeSample, chanAtten | (1 << 31))
        regStore(onetimeSample, chanAtten | (1 << 31) | (1 << 29))
        var timeout: UInt32 = 100_000
        while timeout > 0 {
            if regLoad(intRaw) & (1 << 31) != 0 { break }
            timeout &-= 1
        }
        let data = regLoad(sar1DataStatus)
        regStore(onetimeSample, chanAtten | (1 << 31))
        regStore(onetimeSample, chanAtten)
        if timeout == 0 { return 0 }
        return data & 0xFFF
    }

    // APB_SARADC register addresses (base 0x6004_0000)
    private static let intRaw:          UInt32 = 0x6004_0044  // int_raw (offset 0x44)
    private static let intClr:          UInt32 = 0x6004_004c  // int_clr (offset 0x4c)
    private static let onetimeSample:   UInt32 = 0x6004_0020  // onetime_sample (offset 0x20)
    private static let sar1DataStatus:  UInt32 = 0x6004_002c  // sar1data_status (offset 0x2c)

    /// Read a single ADC1 channel. Returns 12-bit value (0–4095).
    ///
    /// Uses direct volatile register access (regLoad/regStore) to guarantee
    /// each write is emitted as a separate store instruction.
    /// Sequence matches ESP-IDF adc_oneshot_hal_convert():
    ///   clear → configure → enable → start → wait → read → stop → disable
    @inline(never)
    static func read(channel: UInt32, attenuation: Attenuation = .db11) -> UInt32 {
        let chanAtten: UInt32 = (attenuation.rawValue << 23) | (channel << 25)

        // 1. Clear ADC1 done interrupt flag (bit 31)
        regStore(intClr, 1 << 31)

        // 2. Configure channel and attenuation (enable/start both 0)
        regStore(onetimeSample, chanAtten)

        // 3. Enable saradc1_onetime_sample (bit 31)
        regStore(onetimeSample, chanAtten | (1 << 31))

        // 4. Start conversion (bit 29)
        regStore(onetimeSample, chanAtten | (1 << 31) | (1 << 29))

        // 5. Wait for ADC1 conversion done (bit 31 in int_raw)
        var timeout: UInt32 = 100_000
        while timeout > 0 {
            if regLoad(intRaw) & (1 << 31) != 0 { break }
            timeout &-= 1
        }

        // 6. Read 12-bit result from sar1data_status
        let data = regLoad(sar1DataStatus)

        // 7. Stop: clear start bit
        regStore(onetimeSample, chanAtten | (1 << 31))

        // 8. Disable: clear saradc1_onetime_sample
        regStore(onetimeSample, chanAtten)

        if timeout == 0 { return 0xFFFF }
        return data & 0xFFF
    }

    // eFuse BLOCK2 (SYS_DATA_PART1) register addresses for ADC calibration.
    // EFUSE base: 0x6000_8800, RD_SYS_PART1_DATA0 offset: 0x5C
    private static let efuseBlk2Data4: UInt32 = 0x6000_886C  // DATA0 + 0x10
    private static let efuseBlk2Data5: UInt32 = 0x6000_8870
    private static let efuseBlk2Data6: UInt32 = 0x6000_8874
    private static let efuseBlk2Data7: UInt32 = 0x6000_8878

    /// Cached calibration digi value (0 = not yet read).
    nonisolated(unsafe) private static var cachedDigi: UInt32 = 0

    /// Read ADC1 calibration digi value for ATTEN3 (11dB) from eFuse.
    ///
    /// The digi value represents the ADC raw reading at 1370mV reference.
    /// eFuse stores a signed 10-bit offset from default value 2000.
    private static func readCalibrationDigi() -> UInt32 {
        if cachedDigi != 0 { return cachedDigi }

        // BLK_VERSION_MAJOR: DATA4 bits [1:0]
        let version = regLoad(efuseBlk2Data4) & 0x3
        guard version >= 1 else {
            // No calibration data burned — use default
            cachedDigi = 2000
            return 2000
        }

        // ADC1_CAL_VOL_ATTEN3: bit 218 (10 bits, crosses DATA6/DATA7 boundary)
        //   DATA6 bits [31:26] = lower 6 bits, DATA7 bits [3:0] = upper 4 bits
        let data6 = regLoad(efuseBlk2Data6)
        let data7 = regLoad(efuseBlk2Data7)
        let raw10 = ((data7 & 0xF) << 6) | (data6 >> 26)

        // Signed 10-bit: bit 9 is sign
        let digi: UInt32
        if raw10 & 0x200 != 0 {
            let magnitude = ((~raw10) &+ 1) & 0x3FF
            digi = 2000 &- magnitude
        } else {
            digi = 2000 &+ raw10
        }
        cachedDigi = digi
        return digi
    }

    /// Read ADC1 channel and convert to millivolts.
    ///
    /// For 11dB attenuation, uses eFuse calibration data for accuracy.
    /// Reference: ESP-IDF `esp_adc_cal_characterize` curve fitting scheme.
    /// Calibration formula: voltage = raw * 1370 / digi
    ///   where digi is a chip-specific ADC reading at 1370mV reference.
    static func readMillivolts(channel: UInt32, attenuation: Attenuation = .db11) -> UInt32 {
        let raw = read(channel: channel, attenuation: attenuation)
        switch attenuation {
        case .db0:   return raw * 750 / 4095
        case .db2_5: return raw * 1050 / 4095
        case .db6:   return raw * 1300 / 4095
        case .db11:
            let digi = readCalibrationDigi()
            if digi == 0 { return 0 }
            return raw * 1370 / digi
        }
    }
}
