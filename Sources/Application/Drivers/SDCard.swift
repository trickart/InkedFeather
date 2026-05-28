import Registers

/// SPI-mode SD card driver.
///
/// Supports SDHC/SDXC (CMD8/ACMD41 with HCS). Sector size = 512 bytes.
/// CS = GPIO12 (Open X4 hardware). Shares SPI bus with e-ink display.
struct SDCard {
    /// SD SPI command indices.
    enum Command: UInt8 {
        case goIdleState     = 0   // CMD0
        case sendIfCond      = 8   // CMD8
        case setBlockLen     = 16  // CMD16
        case readSingleBlock  = 17  // CMD17
        case writeSingleBlock = 24  // CMD24
        case sdSendOpCond     = 41  // ACMD41
        case appCmd          = 55  // CMD55
        case readOCR         = 58  // CMD58
    }

    /// SD SPI R1 response values.
    enum R1: UInt8 {
        case ready = 0x00
        case idle  = 0x01
    }

    static let cs = Pin(number: 12)
    static let sectorSize = 512

    private let spi: SPIDriver
    private var initialized = false
    private var isSDHC = false

    init(spi: SPIDriver) {
        self.spi = spi
    }

    // MARK: - Public API

    /// Initialize the SD card: power-up sequence, CMD0, CMD8, ACMD41, CMD58.
    /// SPI bus should already be initialized. Clock will be slow (~400kHz) initially.
    mutating func initialize() -> Bool {
        Self.cs.setOutput()
        Self.cs.high()

        // Send ≥74 clock pulses with CS high (power-up sequence)
        for _ in 0..<10 {
            _ = spiTransferByte(0xFF)
        }

        // CMD0: GO_IDLE_STATE → expect R1 = idle
        var r1 = sendCommand(cmd: Command.goIdleState.rawValue, arg: 0)
        if r1 != R1.idle.rawValue { return false }

        // CMD8: SEND_IF_COND (voltage check, 0x1AA pattern)
        r1 = sendCommand(cmd: Command.sendIfCond.rawValue, arg: 0x0000_01AA)
        if r1 == R1.idle.rawValue {
            // SDHC/SDXC: read 4-byte response
            let _ = spiTransferByte(0xFF)
            let _ = spiTransferByte(0xFF)
            let _ = spiTransferByte(0xFF)
            let echo = spiTransferByte(0xFF)
            if echo != 0xAA { return false }
        }

        // ACMD41: SD_SEND_OP_COND with HCS=1, wait for ready
        var timeout: UInt32 = 1000
        repeat {
            r1 = sendAppCommand(cmd: Command.sdSendOpCond.rawValue, arg: 0x4000_0000)
            if r1 == R1.ready.rawValue { break }
            delayUs(1000)
            timeout &-= 1
        } while timeout > 0

        if r1 != R1.ready.rawValue { return false }

        // CMD58: READ_OCR (check CCS bit for block addressing)
        r1 = sendCommand(cmd: Command.readOCR.rawValue, arg: 0)
        if r1 == R1.ready.rawValue {
            let ocr3 = spiTransferByte(0xFF)
            let _ = spiTransferByte(0xFF)
            let _ = spiTransferByte(0xFF)
            let _ = spiTransferByte(0xFF)
            // CCS bit (bit 30 of OCR, in ocr3 bit 6)
            isSDHC = (ocr3 & 0x40) != 0
        }

        // CMD16: SET_BLOCKLEN = 512 (for non-SDHC, but harmless for SDHC)
        _ = sendCommand(cmd: Command.setBlockLen.rawValue, arg: 512)

        initialized = true
        return true
    }

    /// Read a single 512-byte sector.
    ///
    /// - Parameters:
    ///   - sector: Sector number (LBA).
    ///   - buffer: Destination buffer, must be at least 512 bytes.
    /// - Returns: true on success.
    func readSector(sector: UInt32, into buffer: UnsafeMutablePointer<UInt8>) -> Bool {
        // CMD17: READ_SINGLE_BLOCK
        // SDHC uses block addressing, SDSC uses byte addressing
        let addr = isSDHC ? sector : sector &* 512
        let r1 = sendCommand(cmd: Command.readSingleBlock.rawValue, arg: addr)
        if r1 != R1.ready.rawValue {
            deselect()
            return false
        }

        // Wait for data token (0xFE)
        var timeout: UInt32 = 10_000
        while timeout > 0 {
            let token = spiTransferByte(0xFF)
            if token == 0xFE { break }
            if token != 0xFF {
                deselect()
                return false  // Error token
            }
            timeout &-= 1
        }
        if timeout == 0 {
            deselect()
            return false
        }

        // Read 512 bytes of data
        for i in 0..<512 {
            buffer[i] = spiTransferByte(0xFF)
        }

        // Read and discard 2 CRC bytes
        let _ = spiTransferByte(0xFF)
        let _ = spiTransferByte(0xFF)

        deselect()
        return true
    }

    /// Write a single 512-byte sector.
    ///
    /// - Parameters:
    ///   - sector: Sector number (LBA).
    ///   - buffer: Source buffer, must be at least 512 bytes.
    /// - Returns: true on success.
    func writeSector(sector: UInt32, from buffer: UnsafePointer<UInt8>) -> Bool {
        // CMD24: WRITE_SINGLE_BLOCK
        let addr = isSDHC ? sector : sector &* 512
        let r1 = sendCommand(cmd: Command.writeSingleBlock.rawValue, arg: addr)
        if r1 != R1.ready.rawValue {
            deselect()
            return false
        }

        // Gap byte before data token
        let _ = spiTransferByte(0xFF)

        // Data start token
        let _ = spiTransferByte(0xFE)

        // Send 512 bytes of data
        for i in 0..<512 {
            let _ = spiTransferByte(buffer[i])
        }

        // Dummy CRC (2 bytes)
        let _ = spiTransferByte(0xFF)
        let _ = spiTransferByte(0xFF)

        // Read data response token
        let response = spiTransferByte(0xFF)
        if (response & 0x1F) != 0x05 {
            deselect()
            return false  // Data rejected
        }

        // Wait for card to finish programming (busy = 0x00)
        var timeout: UInt32 = 100_000
        while timeout > 0 {
            let status = spiTransferByte(0xFF)
            if status != 0x00 { break }
            timeout &-= 1
        }

        deselect()
        return timeout > 0
    }

    // MARK: - SPI Low-Level

    /// Transfer one byte (full-duplex). CS is NOT managed here.
    private func spiTransferByte(_ tx: UInt8) -> UInt8 {
        var txBuf = tx
        var rxBuf: UInt8 = 0
        withUnsafePointer(to: &txBuf) { txPtr in
            txPtr.withMemoryRebound(to: UInt8.self, capacity: 1) { txp in
                withUnsafeMutablePointer(to: &rxBuf) { rxPtr in
                    rxPtr.withMemoryRebound(to: UInt8.self, capacity: 1) { rxp in
                        spi.transfer(
                            tx: UnsafeBufferPointer(start: txp, count: 1),
                            rx: UnsafeMutableBufferPointer(start: rxp, count: 1)
                        )
                    }
                }
            }
        }
        return rxBuf
    }

    /// Send an SD command and return R1 response.
    private func sendCommand(cmd: UInt8, arg: UInt32) -> UInt8 {
        deselect()
        Self.cs.low()
        let _ = spiTransferByte(0xFF)  // Sync

        // Command frame: 0x40 | cmd, arg (big-endian), CRC
        let _ = spiTransferByte(0x40 | cmd)
        let _ = spiTransferByte(UInt8(truncatingIfNeeded: arg >> 24))
        let _ = spiTransferByte(UInt8(truncatingIfNeeded: arg >> 16))
        let _ = spiTransferByte(UInt8(truncatingIfNeeded: arg >> 8))
        let _ = spiTransferByte(UInt8(truncatingIfNeeded: arg))

        // CRC (only needed for CMD0 and CMD8)
        var crc: UInt8 = 0xFF
        if cmd == Command.goIdleState.rawValue { crc = 0x95 }
        if cmd == Command.sendIfCond.rawValue { crc = 0x87 }
        let _ = spiTransferByte(crc)

        // Wait for response (R1, MSB=0)
        var r1: UInt8 = 0xFF
        for _ in 0..<10 {
            r1 = spiTransferByte(0xFF)
            if r1 & 0x80 == 0 { break }
        }
        return r1
    }

    /// Send CMD55 + ACMD.
    private func sendAppCommand(cmd: UInt8, arg: UInt32) -> UInt8 {
        let _ = sendCommand(cmd: Command.appCmd.rawValue, arg: 0)
        return sendCommand(cmd: cmd, arg: arg)
    }

    /// Deselect (CS high) with trailing clock.
    private func deselect() {
        Self.cs.high()
        let _ = spiTransferByte(0xFF)
    }
}
