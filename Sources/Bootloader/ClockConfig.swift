// PLL clock initialization for ESP32-C3.
//
// Switches CPU clock from XTAL (40MHz) to 160MHz PLL.
// Must be called after disableWatchdogs() and before configureFlashSPI().
//
// ESP32-C3 uses RTC_CNTL/SYSTEM registers (not PMU/PCR like ESP32-C6).
// BBPLL analog configuration requires I2C writes via mask ROM functions
// at fixed addresses (ESP32-C3 lacks direct I2C_ANA_MST control registers).

import _Volatile

// MARK: - Register Addresses

// RTC_CNTL (base 0x60008000)
private let RTC_CNTL_OPTIONS0_REG: UInt32 = 0x6000_8000
private let RTC_CNTL_BB_I2C_FORCE_PD: UInt32    = 1 << 6
private let RTC_CNTL_BBPLL_I2C_FORCE_PD: UInt32 = 1 << 8
private let RTC_CNTL_BBPLL_FORCE_PD: UInt32      = 1 << 10

// I2C_ANA_MST
private let I2C_MST_ANA_CONF0_REG: UInt32 = 0x6000_E040
private let I2C_MST_BBPLL_STOP_FORCE_HIGH: UInt32 = 1 << 2
private let I2C_MST_BBPLL_STOP_FORCE_LOW: UInt32  = 1 << 3

private let ANA_CONFIG_REG: UInt32    = 0x6000_E044
private let ANA_I2C_BBPLL_M: UInt32   = 1 << 17

// SYSTEM (base 0x600C0000)
private let SYSTEM_CPU_PER_CONF_REG: UInt32 = 0x600C_0008
private let SYSTEM_SYSCLK_CONF_REG: UInt32  = 0x600C_0058

// MARK: - ROM I2C Functions (mask ROM, linked via bootloader.ld)

@_extern(c, "rom_i2c_writeReg")
@discardableResult
func romI2CWrite(_ block: UInt32, _ hostid: UInt32, _ regAddr: UInt32, _ data: UInt32) -> UInt32

@_extern(c, "rom_i2c_writeReg_Mask")
@discardableResult
func romI2CWriteMask(_ block: UInt32, _ hostid: UInt32, _ regAddr: UInt32, _ msb: UInt32, _ lsb: UInt32, _ data: UInt32) -> UInt32

// MARK: - BBPLL I2C Constants

private let I2C_BBPLL: UInt32        = 0x66
private let I2C_BBPLL_HOSTID: UInt32 = 0

// MARK: - PLL Configuration

/// Switch CPU clock from XTAL (40MHz) to 160MHz PLL.
func configurePLL() {
    // Step 1: Enable BBPLL power (clear force-power-down bits)
    var opt0 = regLoad(RTC_CNTL_OPTIONS0_REG)
    opt0 &= ~(RTC_CNTL_BB_I2C_FORCE_PD | RTC_CNTL_BBPLL_I2C_FORCE_PD | RTC_CNTL_BBPLL_FORCE_PD)
    regStore(RTC_CNTL_OPTIONS0_REG, opt0)

    // Step 2: Enable I2C access to BBPLL
    let ana = regLoad(ANA_CONFIG_REG)
    regStore(ANA_CONFIG_REG, ana & ~ANA_I2C_BBPLL_M)

    // Step 3: Select 480MHz PLL (SYSTEM_PLL_FREQ_SEL = bit 2)
    var cpuPerConf = regLoad(SYSTEM_CPU_PER_CONF_REG)
    cpuPerConf |= (1 << 2)
    regStore(SYSTEM_CPU_PER_CONF_REG, cpuPerConf)

    // Step 4: Start BBPLL calibration
    var conf0 = regLoad(I2C_MST_ANA_CONF0_REG)
    conf0 &= ~I2C_MST_BBPLL_STOP_FORCE_HIGH
    conf0 |= I2C_MST_BBPLL_STOP_FORCE_LOW
    regStore(I2C_MST_ANA_CONF0_REG, conf0)

    // Step 5: Configure BBPLL analog registers for 40MHz XTAL -> 480MHz PLL
    // Parameters: div_ref=0, div7_0=8, dr1=0, dr3=0, dchgp=5, dcur=3, dbias=2
    let lref: UInt32  = (5 << 4) | 0       // dchgp=5, div_ref=0
    let div70: UInt32 = 8                   // div7_0=8
    // ESP-IDF assembles dcur as: (2 << OC_DLREF_SEL_LSB) | (1 << OC_DHREF_SEL_LSB) | dcur
    // OC_DLREF_SEL_LSB=6, OC_DHREF_SEL_LSB=4
    // = (2 << 6) | (1 << 4) | 3 = 128 + 16 + 3 = 0x93
    let dcurVal: UInt32 = (2 << 6) | (1 << 4) | 3  // 0x93

    romI2CWrite(I2C_BBPLL, I2C_BBPLL_HOSTID, 4, 0x6B)       // MODE_HF for 480MHz
    romI2CWrite(I2C_BBPLL, I2C_BBPLL_HOSTID, 2, lref)        // OC_REF_DIV + DCHGP
    romI2CWrite(I2C_BBPLL, I2C_BBPLL_HOSTID, 3, div70)       // OC_DIV_7_0
    romI2CWriteMask(I2C_BBPLL, I2C_BBPLL_HOSTID, 5, 2, 0, 0) // OC_DR1=0
    romI2CWriteMask(I2C_BBPLL, I2C_BBPLL_HOSTID, 5, 6, 4, 0) // OC_DR3=0
    romI2CWrite(I2C_BBPLL, I2C_BBPLL_HOSTID, 6, dcurVal)     // OC_DCUR + DHREF + DLREF
    romI2CWriteMask(I2C_BBPLL, I2C_BBPLL_HOSTID, 9, 1, 0, 2) // OC_VCO_DBIAS=2
    romI2CWriteMask(I2C_BBPLL, I2C_BBPLL_HOSTID, 6, 5, 4, 2) // OC_DHREF_SEL=2
    romI2CWriteMask(I2C_BBPLL, I2C_BBPLL_HOSTID, 6, 7, 6, 1) // OC_DLREF_SEL=1

    // Step 6: Set CPU to 160MHz from PLL (CPUPERIOD_SEL = 1)
    cpuPerConf = regLoad(SYSTEM_CPU_PER_CONF_REG)
    cpuPerConf = (cpuPerConf & ~UInt32(0x3)) | 1
    regStore(SYSTEM_CPU_PER_CONF_REG, cpuPerConf)

    // Step 7: Switch clock source to PLL (SOC_CLK_SEL bits[11:10] = 1)
    var sysclk = regLoad(SYSTEM_SYSCLK_CONF_REG)
    sysclk = (sysclk & ~(0x3 << 10)) | (1 << 10)
    // Also set PRE_DIV_CNT to 0 (divider = 1)
    sysclk = sysclk & ~UInt32(0x3FF)
    regStore(SYSTEM_SYSCLK_CONF_REG, sysclk)
}
