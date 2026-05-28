// MARK: - SAR ADC registers (ESP32-C3, base 0x6004_0000)

private let APB_SARADC_CTRL_REG: UInt32          = 0x6004_0000
private let APB_SARADC_CTRL2_REG: UInt32         = 0x6004_0004
private let APB_SARADC_SAR_PATT_TAB1_REG: UInt32 = 0x6004_0018

// MARK: - System clock registers (ESP32-C3)

private let SYSTEM_PERIP_CLK_EN0_REG: UInt32  = 0x600C_0010
private let SYSTEM_PERIP_RST_EN0_REG: UInt32  = 0x600C_0018

// MARK: - RNG data register (ESP32-C3)

private let RNG_DATA_REG: UInt32               = 0x6002_60B0

// MARK: - ROM I2C functions for entropy source

@_extern(c, "rom_i2c_writeReg_Mask")
private func _romI2cWriteRegMask(_ block: UInt8, _ hostId: UInt8, _ regAddr: UInt8, _ msb: UInt8, _ lsb: UInt8, _ data: UInt8)

private let ANA_CONFIG_REG: UInt32   = 0x6000_E044
private let ANA_CONFIG2_REG: UInt32  = 0x6000_E048

private func romI2cWriteMask(regAddr: UInt8, msb: UInt8, lsb: UInt8, data: UInt8) {
    _romI2cWriteRegMask(0x69, 0, regAddr, msb, lsb, data)
}

// MARK: - Entropy source initialization

/// Enable the SAR ADC as an entropy source for the hardware RNG.
/// Must be called before any use of arc4random_buf.
/// Ported from ESP-IDF bootloader_random_esp32c3.c.
func enableEntropySource() {
    // 1. Pull SAR ADC out of reset, enable clock
    regStore(SYSTEM_PERIP_RST_EN0_REG, regLoad(SYSTEM_PERIP_RST_EN0_REG) | (1 << 28))
    regStore(SYSTEM_PERIP_RST_EN0_REG, regLoad(SYSTEM_PERIP_RST_EN0_REG) & ~(1 << 28))
    regStore(SYSTEM_PERIP_CLK_EN0_REG, regLoad(SYSTEM_PERIP_CLK_EN0_REG) | (1 << 28))

    // 2. Enable SAR I2C power
    regStore(ANA_CONFIG_REG, regLoad(ANA_CONFIG_REG) & ~(1 << 18))
    regStore(ANA_CONFIG2_REG, regLoad(ANA_CONFIG2_REG) | (1 << 16))

    // 3. Configure SAR ADC internal registers via ROM I2C
    romI2cWriteMask(regAddr: 0x2, msb: 6, lsb: 4, data: 4)     // SAR1_DREF
    romI2cWriteMask(regAddr: 0x5, msb: 6, lsb: 4, data: 4)     // SAR2_DREF
    romI2cWriteMask(regAddr: 0x2, msb: 2, lsb: 0, data: 2)     // SAR1_SAMPLE_CYCLE
    romI2cWriteMask(regAddr: 0x7, msb: 2, lsb: 2, data: 1)     // ENT_TSENS
    romI2cWriteMask(regAddr: 0x7, msb: 1, lsb: 0, data: 0)     // DTEST_RTC = 0
    romI2cWriteMask(regAddr: 0x7, msb: 3, lsb: 3, data: 1)     // ENT_RTC = 1

    // 4. Pattern table: channel 9 with attenuation 1 (two entries)
    let patternOne: UInt32 = (9 << 2) | 1   // 0x25
    let patternTwo: UInt32 = 1               // channel 0, atten 1
    let patternTable = (patternTwo << 18) | (patternOne << 12)
    regStore(APB_SARADC_SAR_PATT_TAB1_REG, patternTable)

    // 5. Pattern length = 1 (2 entries), SAR CLK divider = 15
    var ctrl = regLoad(APB_SARADC_CTRL_REG)
    ctrl &= ~(0x7 << 15)                    // clear PATT_LEN
    ctrl |= (1 << 15)                       // PATT_LEN = 1
    ctrl &= ~(0xFF << 7)                    // clear SAR_CLK_DIV
    ctrl |= (15 << 7)                       // SAR_CLK_DIV = 15
    regStore(APB_SARADC_CTRL_REG, ctrl)

    // 6. Timer target = 200, enable timer
    var ctrl2 = regLoad(APB_SARADC_CTRL2_REG)
    ctrl2 &= ~(0xFFF << 12)                 // clear TIMER_TARGET
    ctrl2 |= (200 << 12)                    // TIMER_TARGET = 200
    ctrl2 |= (1 << 24)                      // TIMER_EN
    regStore(APB_SARADC_CTRL2_REG, ctrl2)
}

// MARK: - Direct hardware RNG read

/// Read one 32-bit random value from the hardware RNG register.
func readRandom32() -> UInt32 {
    regLoad(RNG_DATA_REG)
}

// MARK: - ChaCha20 CSPRNG state

// Input state: [0-3] constants, [4-11] key, [12] counter, [13-15] nonce
nonisolated(unsafe) private var csprngState: (
    UInt32, UInt32, UInt32, UInt32,
    UInt32, UInt32, UInt32, UInt32,
    UInt32, UInt32, UInt32, UInt32,
    UInt32, UInt32, UInt32, UInt32
) = (
    0x6170_7865, 0x3320_646e, 0x7962_2d32, 0x6b20_6574,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
)

// Output buffer (64 bytes)
nonisolated(unsafe) private var csprngBuffer: (
    UInt32, UInt32, UInt32, UInt32,
    UInt32, UInt32, UInt32, UInt32,
    UInt32, UInt32, UInt32, UInt32,
    UInt32, UInt32, UInt32, UInt32
) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)

nonisolated(unsafe) private var csprngBufPos: Int = 64  // Bytes consumed; starts exhausted
nonisolated(unsafe) private var csprngBlockCount: UInt32 = 0

/// Seed the ChaCha20 CSPRNG from the hardware RNG.
/// Must be called after enableEntropySource().
func seedCsprng() {
    withUnsafeMutablePointer(to: &csprngState) { ptr in
        let s = UnsafeMutableRawPointer(ptr).assumingMemoryBound(to: UInt32.self)
        for i in 4..<12 {
            s[i] = regLoad(RNG_DATA_REG)
        }
        s[12] = 0
        for i in 13..<16 {
            s[i] = regLoad(RNG_DATA_REG)
        }
    }
    csprngBufPos = 64
    csprngBlockCount = 0
}

private func generateCsprngBlock() {
    // Reseed every ~1MB (16384 blocks x 64 bytes)
    if csprngBlockCount >= 16384 {
        seedCsprng()
    }

    withUnsafeMutablePointer(to: &csprngState) { statePtr in
        let state = UnsafeMutableRawPointer(statePtr).assumingMemoryBound(to: UInt32.self)
        withUnsafeMutablePointer(to: &csprngBuffer) { bufPtr in
            let buf = UnsafeMutableRawPointer(bufPtr).assumingMemoryBound(to: UInt32.self)
            chacha20Block(state, buf)
        }
        state[12] &+= 1
    }
    csprngBufPos = 0
    csprngBlockCount &+= 1
}

// MARK: - arc4random_buf

@c(arc4random_buf)
public func arc4random_buf(_ buf: UnsafeMutableRawPointer, _ nbytes: Int) {
    let dst = buf.assumingMemoryBound(to: UInt8.self)
    var offset = 0
    while offset < nbytes {
        if csprngBufPos >= 64 {
            generateCsprngBlock()
        }

        let available = 64 &- csprngBufPos
        let needed = nbytes &- offset
        let toCopy = available < needed ? available : needed

        withUnsafePointer(to: &csprngBuffer) { bufPtr in
            let src = UnsafeRawPointer(bufPtr).assumingMemoryBound(to: UInt8.self)
            for i in 0..<toCopy {
                dst[offset &+ i] = src[csprngBufPos &+ i]
            }
        }

        offset &+= toCopy
        csprngBufPos &+= toCopy
    }
}
