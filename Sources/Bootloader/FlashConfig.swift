// Flash SPI configuration for ESP32-C3.
//
// Configures SPI0/SPI1 clock dividers and read mode.
// ESP32-C3 SPI0 base=0x60003000 (cache), SPI1 base=0x60002000 (flash).

import _Volatile

// SPI_MEM_CLOCK_REG: base + 0x14
private let SPI_MEM_CLK_EQU_SYSCLK: UInt32 = 1 << 31

// SPI_MEM_CTRL_REG read mode bits (base + 0x08)
private let SPI_MEM_FREAD_QIO: UInt32  = 1 << 24
private let SPI_MEM_FREAD_DIO: UInt32  = 1 << 23
private let SPI_MEM_FASTRD_MODE: UInt32 = 1 << 13

// SPI_MEM_USR_DUMMY_CYCLELEN field: bits [5:0] in USER1_REG (base + 0x1C)
private let SPI_MEM_USR_DUMMY_CYCLELEN_M: UInt32 = 0x3F

/// Configure SPI clock divider for the given SPI peripheral.
/// spiNum: 0 = SPI0 (0x60003000), 1 = SPI1 (0x60002000)
private func configureSpiClock(_ spiNum: UInt32, freqdiv: UInt32) {
    // ESP32-C3: SPI1 base=0x60002000, SPI0 base=0x60003000
    let base: UInt32 = (spiNum == 0) ? 0x6000_3000 : 0x6000_2000
    let clockReg = base + 0x14
    if freqdiv == 1 {
        regStore(clockReg, SPI_MEM_CLK_EQU_SYSCLK)
    } else {
        let n = freqdiv - 1
        let h = (freqdiv - 1) / 2
        let l = freqdiv - 1
        regStore(clockReg, (n << 16) | (h << 8) | l)
    }
}

/// Fix dummy cycle length for the given SPI peripheral.
/// When CLK_EQU_SYSCLK (freqdiv=1), apply -2 correction to dummy cycles.
private func fixDummyCycles(_ spiNum: UInt32, freqdiv: UInt32) {
    let base: UInt32 = (spiNum == 0) ? 0x6000_3000 : 0x6000_2000
    let ctrl = regLoad(base + 0x08)

    let baseDummy: Int32
    if ctrl & SPI_MEM_FREAD_QIO != 0 {
        baseDummy = 5
    } else if ctrl & SPI_MEM_FREAD_DIO != 0 {
        baseDummy = 3
    } else if ctrl & SPI_MEM_FASTRD_MODE != 0 {
        baseDummy = 7
    } else {
        return
    }

    let correction: Int32 = (freqdiv == 1) ? -2 : 0
    let dummyCycles = UInt32(baseDummy + correction)

    let user1 = regLoad(base + 0x1C)
    regStore(base + 0x1C, (user1 & ~SPI_MEM_USR_DUMMY_CYCLELEN_M) | (dummyCycles & SPI_MEM_USR_DUMMY_CYCLELEN_M))
}

/// Configure flash SPI for operation.
/// After PLL is enabled (APB=80MHz), reconfigure SPI0/SPI1 clocks and
/// dummy cycles for 80MHz flash operation, then set SPI1 DIO read mode.
func configureFlashSPI() {
    // Configure SPI0 (cache) and SPI1 (flash) for 80MHz (freqdiv=1, CLK_EQU_SYSCLK)
    configureSpiClock(0, freqdiv: 1)
    configureSpiClock(1, freqdiv: 1)

    // Fix dummy cycles for 80MHz operation
    // Only fix SPI1 (direct reads). SPI0 (cache) dummy cycles are left
    // as ROM bootloader configured them — the ROM may use a different
    // read mode than DIO, and incorrect dummy cycles cause bad cache reads.
    fixDummyCycles(1, freqdiv: 1)

    // Configure SPI1 for DIO flash reads
    configureSpiReadMode()
}
