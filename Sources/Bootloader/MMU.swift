// Flash MMU configuration for ESP32-C3.
//
// ESP32-C3 MMU differs from ESP32-C6:
//   - MMU table is memory-mapped at 0x600C5000 (128 entries x 4 bytes)
//   - Invalid flag is bit 8 (0x100), valid entries have bit 8 clear
//   - Page size is 64KB
//   - IROM (0x42000000) and DROM (0x3C000000) share the same MMU table
//
// Following ESP-IDF's set_cache_and_start_app() sequence:
//   1. Disable cache
//   2. Unmap all MMU entries
//   3. Map DROM and IROM segments
//   4. Enable cache buses (IBUS + DBUS)
//   5. Re-enable cache

import _Volatile

// MMU table base (memory-mapped, 128 entries)
private let MMU_TABLE_BASE: UInt32   = 0x600C_5000
private let MMU_ENTRY_NUM: Int       = 128
private let MMU_PAGE_SIZE: UInt32    = 0x10000  // 64KB
private let MMU_INVALID: UInt32      = 1 << 8   // bit 8 = invalid

// Virtual address ranges
private let IROM_VADDR_BASE: UInt32  = 0x4200_0000
private let DROM_VADDR_BASE: UInt32  = 0x3C00_0000
private let VADDR_MASK: UInt32       = 0x007F_FFFF  // 23-bit offset within 8MB region

// Cache control registers (EXTMEM base = 0x600C4000)
private let EXTMEM_ICACHE_CTRL_REG: UInt32  = 0x600C_4000  // bit 0 = cache enable
private let EXTMEM_ICACHE_CTRL1_REG: UInt32 = 0x600C_4004  // bit 0 = IBUS shut, bit 1 = DBUS shut

/// Disable the ICache.
func cacheDisableICache() {
    let ctrl = regLoad(EXTMEM_ICACHE_CTRL_REG)
    regStore(EXTMEM_ICACHE_CTRL_REG, ctrl & ~UInt32(1))  // Clear enable bit
}

/// Re-enable the ICache.
func cacheEnableICache() {
    let ctrl = regLoad(EXTMEM_ICACHE_CTRL_REG)
    regStore(EXTMEM_ICACHE_CTRL_REG, ctrl | 1)  // Set enable bit
}

/// Invalidate all MMU entries.
func mmuUnmapAll() {
    for i in 0..<UInt32(MMU_ENTRY_NUM) {
        regStore(MMU_TABLE_BASE + i * 4, MMU_INVALID)
    }
}

/// Map a region of flash to a virtual address range.
/// entryStart: first MMU entry index
/// pageNum: flash physical page number (paddr >> 16)
/// pageCount: number of 64KB pages to map
private func mmuMapPages(entryStart: UInt32, pageNum: UInt32, pageCount: UInt32) {
    for i in 0..<pageCount {
        regStore(MMU_TABLE_BASE + (entryStart + i) * 4, pageNum + i)
    }
}

/// Enable cache buses (IBUS and DBUS) by clearing the shutdown bits.
func enableCacheBuses() {
    let ctrl1 = regLoad(EXTMEM_ICACHE_CTRL1_REG)
    regStore(EXTMEM_ICACHE_CTRL1_REG, ctrl1 & ~UInt32(0x3))  // Clear bits 0 and 1
}

// MARK: - Segment info for MMU mapping

struct FlashMappedSegment {
    var flashAddr: UInt32  // Physical flash address of segment data
    var loadAddr: UInt32   // Virtual address (IROM or DROM range)
    var size: UInt32
    var valid: Bool
}

/// Configure Flash MMU mapping for an app image's flash-mapped segments.
/// Walks through image segments to find DROM and IROM, then maps them.
func setupFlashMMU(appFlashOffset: UInt32, segmentCount: UInt8) {
    var drom = FlashMappedSegment(flashAddr: 0, loadAddr: 0, size: 0, valid: false)
    var irom = FlashMappedSegment(flashAddr: 0, loadAddr: 0, size: 0, valid: false)

    // Walk segments to find DROM and IROM
    var fileOffset: UInt32 = appFlashOffset + 24  // skip 24-byte image header

    for _ in 0..<segmentCount {
        let loadAddr = readFlashUInt32(at: fileOffset)
        let dataLen  = readFlashUInt32(at: fileOffset + 4)
        let dataStart = fileOffset + 8

        if loadAddr >= DROM_VADDR_BASE && loadAddr < DROM_VADDR_BASE + 0x0080_0000 {
            drom = FlashMappedSegment(flashAddr: dataStart, loadAddr: loadAddr, size: dataLen, valid: true)
        } else if loadAddr >= IROM_VADDR_BASE && loadAddr < IROM_VADDR_BASE + 0x0080_0000 {
            irom = FlashMappedSegment(flashAddr: dataStart, loadAddr: loadAddr, size: dataLen, valid: true)
        }

        fileOffset = dataStart + dataLen
    }

    // Disable cache before modifying MMU
    cacheDisableICache()

    // Invalidate all MMU entries
    mmuUnmapAll()

    // Map DROM segment
    if drom.valid {
        let vaddrAligned = drom.loadAddr & ~(MMU_PAGE_SIZE - 1)
        let paddrAligned = drom.flashAddr & ~(MMU_PAGE_SIZE - 1)
        let size = (drom.loadAddr - vaddrAligned) + drom.size
        let pageCount = (size + MMU_PAGE_SIZE - 1) / MMU_PAGE_SIZE
        let entryId = (vaddrAligned & VADDR_MASK) >> 16
        let pageNum = paddrAligned >> 16
        mmuMapPages(entryStart: entryId, pageNum: pageNum, pageCount: pageCount)
    }

    // Map IROM segment
    if irom.valid {
        let vaddrAligned = irom.loadAddr & ~(MMU_PAGE_SIZE - 1)
        let paddrAligned = irom.flashAddr & ~(MMU_PAGE_SIZE - 1)
        let size = (irom.loadAddr - vaddrAligned) + irom.size
        let pageCount = (size + MMU_PAGE_SIZE - 1) / MMU_PAGE_SIZE
        let entryId = (vaddrAligned & VADDR_MASK) >> 16
        let pageNum = paddrAligned >> 16
        mmuMapPages(entryStart: entryId, pageNum: pageNum, pageCount: pageCount)
    }

    // Enable cache buses
    enableCacheBuses()

    // Re-enable cache
    cacheEnableICache()
}
