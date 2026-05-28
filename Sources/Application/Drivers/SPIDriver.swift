import Registers

/// ESP32-C3 SPI2 master driver using CPU-controlled FIFO transfer.
///
/// SPI2 base: 0x60024000, up to 64 bytes per transaction via W0–W15 buffers.
/// Uses GPIO Matrix for pin routing. SPI_MODE0 (CPOL=0, CPHA=0).
struct SPIDriver {
    /// SPI2 GPIO Matrix signal indices (ESP32-C3 TRM Table 5-1)
    private static let fspiclkOut: UInt32 = 63  // FSPICLK_OUT_IDX
    private static let fspidOut: UInt32 = 65    // FSPID_OUT_IDX (MOSI)
    private static let fspiqIn: UInt32 = 64     // FSPIQ_IN_IDX (MISO)

    /// SPI2 W0–W15 base address for direct access (offset 0x98 from SPI2 base)
    private static let spi2Base: UInt32 = 0x6002_4000
    private static let wBase: UInt32 = spi2Base + 0x98

    let sclkPin: Pin
    let mosiPin: Pin
    let misoPin: Pin

    /// Initialize SPI2 master with the given pins and clock divider.
    ///
    /// APB clock = 80 MHz. SPI clock = APB / (clkdivPre + 1) / (clkcntN + 1).
    /// For 10 MHz: clkdivPre=0, clkcntN=7 → 80/(1)/(8) = 10 MHz.
    /// For 40 MHz: clkdivPre=0, clkcntN=1 → 80/(1)/(2) = 40 MHz.
    func initialize(clkdivPre: UInt32 = 0, clkcntN: UInt32 = 7) {
        // Enable SPI2 peripheral clock, deassert reset
        system.perip_clk_en0.modify { $0.raw.storage = $0.raw.storage | (1 << 6) }
        system.perip_rst_en0.modify { $0.raw.storage = $0.raw.storage & ~(1 << 6) }

        // Route SCLK via GPIO Matrix
        sclkPin.setFunction(output: Self.fspiclkOut)

        // Route MOSI via GPIO Matrix
        mosiPin.setFunction(output: Self.fspidOut)

        // Route MISO via GPIO Matrix (input)
        misoPin.setInput()
        gpio.func_in_sel_cfg[Int(Self.fspiqIn)].write {
            $0.raw.storage = UInt32(misoPin.number) | (1 << 6)  // sel=1
        }

        // Reset FIFOs
        spi2.dma_conf.write {
            $0.raw.storage = (1 << 29) | (1 << 30)  // rx_afifo_rst, buf_afifo_rst
        }
        spi2.dma_conf.write { $0.raw.storage = 0 }

        // Master mode (slave.mode = 0 is default)
        spi2.slave.write { $0.raw.storage = 0 }

        // Clock configuration
        let clkcntH = (clkcntN + 1) / 2 - 1
        spi2.clock.write {
            $0.raw.storage = (clkcntN & 0x3F)
                | ((clkcntH & 0x3F) << 6)
                | ((clkcntN & 0x3F) << 12)
                | ((clkdivPre & 0xF) << 18)
        }

        // USER register: MOSI enabled, half-duplex by default (no MISO unless requested)
        // cs_setup=1, cs_hold=1 for proper CS timing
        spi2.user.write {
            $0.raw.storage = (1 << 27)  // usr_mosi
                | (1 << 6)              // cs_hold
                | (1 << 7)              // cs_setup
        }

        // CS setup/hold time
        spi2.user1.write {
            $0.raw.storage = (1 << 17)   // cs_setup_time = 1 cycle
                | (1 << 22)              // cs_hold_time = 1 cycle
        }

        // Disable all hardware CS (we use GPIO for CS)
        spi2.misc.write {
            $0.raw.storage = 0x3F  // cs0_dis..cs5_dis = all disabled
        }

        // MSB first, standard SPI (no dual/quad)
        spi2.ctrl.write { $0.raw.storage = 0 }

        // Enable SPI clock gate
        spi2.clk_gate.write { $0.raw.storage = 0x7 }  // clk_en | mst_clk_active | mst_clk_sel
    }

    /// Reinitialize SPI2 after light sleep (clock gating may reset peripheral state).
    func reinitialize() {
        initialize()
    }

    /// Transfer bytes (write-only, ignoring MISO). Max 64 bytes per call.
    func write(_ data: UnsafeBufferPointer<UInt8>) {
        let count = min(data.count, 64)
        if count == 0 { return }

        // Load data into W0–W15 (little-endian, 4 bytes per register)
        let words = (count + 3) / 4
        for i in 0..<words {
            var word: UInt32 = 0
            for j in 0..<4 {
                let idx = i * 4 + j
                if idx < count {
                    word |= UInt32(data[idx]) << (j * 8)
                }
            }
            regStore(Self.wBase + UInt32(i) * 4, word)
        }

        // Set data bit length
        spi2.ms_dlen.write {
            $0.raw.storage = UInt32(count * 8 - 1) & 0x3FFFF
        }

        // Configure for write-only (MOSI only, no MISO)
        spi2.user.modify {
            $0.raw.storage = $0.raw.storage | (1 << 27)   // usr_mosi
            $0.raw.storage = $0.raw.storage & ~(1 << 28)  // usr_miso off
        }

        // Sync config registers to SPI clock domain
        spi2.cmd.write { $0.raw.storage = (1 << 23) }  // SPI_UPDATE
        var t1: UInt32 = 100_000
        while spi2.cmd.read().raw.storage & (1 << 23) != 0 { t1 &-= 1; if t1 == 0 { break } }

        // Start transfer
        spi2.cmd.write { $0.raw.storage = (1 << 24) }  // SPI_USR
        var t2: UInt32 = 100_000
        while spi2.cmd.read().raw.storage & (1 << 24) != 0 { t2 &-= 1; if t2 == 0 { break } }
    }

    /// Full-duplex transfer: write txData while simultaneously reading into rxData.
    /// Both buffers should be the same length, max 64 bytes.
    func transfer(tx txData: UnsafeBufferPointer<UInt8>,
                  rx rxData: UnsafeMutableBufferPointer<UInt8>) {
        let count = min(min(txData.count, rxData.count), 64)
        if count == 0 { return }

        // Load TX data
        let words = (count + 3) / 4
        for i in 0..<words {
            var word: UInt32 = 0
            for j in 0..<4 {
                let idx = i * 4 + j
                if idx < count {
                    word |= UInt32(txData[idx]) << (j * 8)
                }
            }
            regStore(Self.wBase + UInt32(i) * 4, word)
        }

        // Set data bit length
        spi2.ms_dlen.write {
            $0.raw.storage = UInt32(count * 8 - 1) & 0x3FFFF
        }

        // Full-duplex: MOSI + MISO + doutdin
        spi2.user.modify {
            $0.raw.storage = $0.raw.storage | (1 << 27)  // usr_mosi
            $0.raw.storage = $0.raw.storage | (1 << 28)  // usr_miso
            $0.raw.storage = $0.raw.storage | (1 << 0)   // doutdin (full duplex)
        }

        // Sync config registers to SPI clock domain
        spi2.cmd.write { $0.raw.storage = (1 << 23) }  // SPI_UPDATE
        var t1: UInt32 = 100_000
        while spi2.cmd.read().raw.storage & (1 << 23) != 0 { t1 &-= 1; if t1 == 0 { break } }

        // Start transfer
        spi2.cmd.write { $0.raw.storage = (1 << 24) }  // SPI_USR
        var t2: UInt32 = 100_000
        while spi2.cmd.read().raw.storage & (1 << 24) != 0 { t2 &-= 1; if t2 == 0 { break } }

        // Read RX data from W0–W15
        for i in 0..<words {
            let word = regLoad(Self.wBase + UInt32(i) * 4)
            for j in 0..<4 {
                let idx = i * 4 + j
                if idx < count {
                    rxData[idx] = UInt8(truncatingIfNeeded: word >> (j * 8))
                }
            }
        }

        // Restore half-duplex mode
        spi2.user.modify {
            $0.raw.storage = $0.raw.storage & ~(1 << 28)  // usr_miso off
            $0.raw.storage = $0.raw.storage & ~(1 << 0)   // doutdin off
        }
    }

    /// Write a single byte (convenience).
    func writeByte(_ byte: UInt8) {
        var b = byte
        withUnsafePointer(to: &b) {
            $0.withMemoryRebound(to: UInt8.self, capacity: 1) {
                write(UnsafeBufferPointer(start: $0, count: 1))
            }
        }
    }
}
