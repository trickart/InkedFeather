// Pure Swift 2nd-stage bootloader for ESP32-C3.
//
// Replaces the ESP-IDF bootloader with a minimal implementation
// using direct register access (no ESP-IDF or SDK dependencies).
//
// Boot flow:
//   ROM Bootloader -> this code (IRAM 0x403D0000)
//   -> BSS clear + watchdog disable
//   -> PLL clock: 40MHz XTAL -> 480MHz PLL -> 160MHz CPU / 80MHz APB
//   -> SPI flash clock + DIO read mode setup
//   -> read partition table -> find app partition (factory or OTA_0)
//   -> load IRAM/DRAM segments from flash to RAM
//   -> configure MMU for IROM/DROM flash mapping
//   -> jump to app entry point

// MARK: - Constants

let ESP_IMAGE_MAGIC: UInt8    = 0xE9
let PARTITION_TABLE_OFFSET: UInt32 = 0x8000
let PARTITION_ENTRY_SIZE: Int = 32
let PARTITION_MAGIC: UInt16   = 0x50AA
let PARTITION_MD5_MAGIC: UInt16 = 0xEBEB

// Partition types/subtypes
let PART_TYPE_APP: UInt8      = 0x00
let PART_SUBTYPE_FACTORY: UInt8 = 0x00
let PART_SUBTYPE_OTA_0: UInt8 = 0x10

// ESP32-C3 memory regions
let IROM_START: UInt32 = 0x4200_0000
let IROM_END: UInt32   = 0x4280_0000
let DROM_START: UInt32 = 0x3C00_0000
let DROM_END: UInt32   = 0x3C80_0000
let IRAM_START: UInt32 = 0x4037_C000
let IRAM_END: UInt32   = 0x403E_0000
let DRAM_START: UInt32 = 0x3FC8_0000
let DRAM_END: UInt32   = 0x3FD0_0000

// MARK: - Image Header

struct ESPImageHeader {
    let magic: UInt8
    let segmentCount: UInt8
    let flashMode: UInt8
    let flashConfig: UInt8
    let entryPoint: UInt32
}

func readImageHeader(at flashOffset: UInt32) -> ESPImageHeader {
    var buf = (UInt32(0), UInt32(0), UInt32(0), UInt32(0), UInt32(0), UInt32(0))
    withUnsafeMutableBytes(of: &buf) { ptr in
        readFlash(src: flashOffset, dest: ptr.baseAddress!, length: 24)
    }
    return withUnsafeBytes(of: &buf) { ptr in
        let bytes = ptr.bindMemory(to: UInt8.self).baseAddress!
        return ESPImageHeader(
            magic: bytes[0],
            segmentCount: bytes[1],
            flashMode: bytes[2],
            flashConfig: bytes[3],
            entryPoint: UInt32(bytes[4])
                | (UInt32(bytes[5]) << 8)
                | (UInt32(bytes[6]) << 16)
                | (UInt32(bytes[7]) << 24)
        )
    }
}

// MARK: - Partition Table

struct PartitionInfo {
    let offset: UInt32
    let size: UInt32
}

/// Search partition table for the factory app partition.
func findAppPartition() -> PartitionInfo? {
    let maxEntries = 8
    var rawBuf: (
        UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32,
        UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32,
        UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32,
        UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32,
        UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32,
        UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32,
        UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32,
        UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32, UInt32
    ) = (
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0
    )
    let bufSize = maxEntries * PARTITION_ENTRY_SIZE
    withUnsafeMutableBytes(of: &rawBuf) { ptr in
        readFlash(src: PARTITION_TABLE_OFFSET, dest: ptr.baseAddress!, length: bufSize)
    }

    let bytes = withUnsafeBytes(of: &rawBuf) { $0.bindMemory(to: UInt8.self).baseAddress! }

    for i in 0..<maxEntries {
        let base = i * PARTITION_ENTRY_SIZE
        let magic = UInt16(bytes[base]) | (UInt16(bytes[base + 1]) << 8)

        if magic == 0xFFFF { break }
        if magic == PARTITION_MD5_MAGIC { break }
        if magic != PARTITION_MAGIC { continue }

        let type = bytes[base + 2]
        let subtype = bytes[base + 3]

        if type == PART_TYPE_APP && (subtype == PART_SUBTYPE_FACTORY || subtype == PART_SUBTYPE_OTA_0) {
            let offset = UInt32(bytes[base + 4])
                | (UInt32(bytes[base + 5]) << 8)
                | (UInt32(bytes[base + 6]) << 16)
                | (UInt32(bytes[base + 7]) << 24)
            let size = UInt32(bytes[base + 8])
                | (UInt32(bytes[base + 9]) << 8)
                | (UInt32(bytes[base + 10]) << 16)
                | (UInt32(bytes[base + 11]) << 24)
            return PartitionInfo(offset: offset, size: size)
        }
    }
    return nil
}

// MARK: - Segment Loading

/// Load RAM segments (IRAM/DRAM) from the app image into their target addresses.
func loadRAMSegments(appFlashOffset: UInt32, segmentCount: UInt8) {
    var fileOffset = appFlashOffset + 24  // skip 24-byte image header

    for _ in 0..<segmentCount {
        let loadAddr = readFlashUInt32(at: fileOffset)
        let dataLen  = readFlashUInt32(at: fileOffset + 4)
        let dataStart = fileOffset + 8

        let isIRAM = loadAddr >= IRAM_START && loadAddr < IRAM_END
        let isDRAM = loadAddr >= DRAM_START && loadAddr < DRAM_END

        if (isIRAM || isDRAM) && dataLen > 0 {
            let dest = UnsafeMutableRawPointer(bitPattern: UInt(loadAddr))!
            readFlash(src: dataStart, dest: dest, length: Int(dataLen))
        }

        fileOffset = dataStart + dataLen
    }
}

// MARK: - Linker Symbol Helper

@inline(__always)
func linkerSymbolAddress(_ symbol: inout UInt8) -> UInt {
    withUnsafePointer(to: &symbol) { UInt(bitPattern: $0) }
}

// MARK: - BSS Initialization

@_extern(c, "_sbss") nonisolated(unsafe) var _sbss: UInt8
@_extern(c, "_ebss") nonisolated(unsafe) var _ebss: UInt8

func clearBSS() {
    let start = linkerSymbolAddress(&_sbss)
    let end = linkerSymbolAddress(&_ebss)
    guard let ptr = UnsafeMutablePointer<UInt8>(bitPattern: start) else { return }
    var i = 0
    while start &+ UInt(i) < end {
        ptr[i] = 0
        i &+= 1
    }
}

// MARK: - Entry Point

@main
struct Bootloader {
    static func main() {
        clearBSS()
        disableWatchdogs()
        configurePLL()
        configureFlashSPI()

        guard let app = findAppPartition() else {
            while true {}
        }

        let header = readImageHeader(at: app.offset)
        guard header.magic == ESP_IMAGE_MAGIC else {
            while true {}
        }

        loadRAMSegments(appFlashOffset: app.offset, segmentCount: header.segmentCount)
        setupFlashMMU(appFlashOffset: app.offset, segmentCount: header.segmentCount)

        let entry = unsafeBitCast(
            UInt(header.entryPoint),
            to: (@convention(c) () -> Void).self
        )
        entry()

        while true {}
    }
}
