private let unlockKey: UInt32 = 0x50D8_3AA1

/// Disable a MWDT (Main Watchdog Timer) given the TIMG base address.
/// ESP32-C3 TIMG0=0x6001F000, TIMG1=0x60020000
/// WDTCONFIG0 offset=0x48, WDTWPROTECT offset=0x64
private func disableMWDT(_ base: UInt32) {
    regStore(base + 0x64, unlockKey)             // Unlock WPROTECT
    var cfg = regLoad(base + 0x48)
    cfg &= ~(UInt32(1) << 31)                   // Clear wdt_en
    cfg &= ~(UInt32(1) << 14)                   // Clear flashboot_mod_en
    cfg &= ~(0x3 << 29)                         // Clear stg0
    cfg &= ~(0x3 << 27)                         // Clear stg1
    cfg &= ~(0x3 << 25)                         // Clear stg2
    cfg &= ~(0x3 << 23)                         // Clear stg3
    regStore(base + 0x48, cfg)
    cfg = regLoad(base + 0x48)
    cfg |= (1 << 22)                            // Set conf_update_en
    regStore(base + 0x48, cfg)
    regStore(base + 0x64, 0)                     // Re-lock WPROTECT
}

/// Disable RTC Watchdog.
/// ESP32-C3 RTC_CNTL base=0x60008000
/// WDTCONFIG0 offset=0x90, WDTFEED offset=0xA4, WDTWPROTECT offset=0xA8
private func disableRWDT() {
    let base: UInt32 = 0x6000_8000
    regStore(base + 0xA8, unlockKey)             // Unlock WPROTECT
    regStore(base + 0xA4, 1)                     // Feed before disabling
    var cfg = regLoad(base + 0x90)
    cfg &= ~(UInt32(1) << 31)                   // Clear wdt_en
    cfg &= ~(UInt32(1) << 12)                   // Clear flashboot_mod_en
    cfg &= ~(0x7 << 28)                         // Clear stg0
    cfg &= ~(0x7 << 25)                         // Clear stg1
    cfg &= ~(0x7 << 22)                         // Clear stg2
    cfg &= ~(0x7 << 19)                         // Clear stg3
    regStore(base + 0x90, cfg)
    regStore(base + 0xA8, 0)                     // Re-lock WPROTECT
}

/// Disable Super Watchdog (SWD).
/// ESP32-C3 RTC_CNTL_SWD_CONF offset=0xAC, SWD_WPROTECT offset=0xB0.
/// SWD uses its own magic key (distinct from the RWDT/MWDT key).
private let swdUnlockKey: UInt32 = 0x8F1D_312A
private func disableSWD() {
    let base: UInt32 = 0x6000_8000
    regStore(base + 0xB0, swdUnlockKey)          // Unlock SWD_WPROTECT
    var cfg = regLoad(base + 0xAC)
    cfg |= (UInt32(1) << 31)                    // swd_auto_feed_en (bit 31)
    regStore(base + 0xAC, cfg)
    regStore(base + 0xB0, 0)                     // Re-lock SWD_WPROTECT
}

/// Disable all watchdog timers to prevent chip reset.
func disableWatchdogs() {
    disableMWDT(0x6001_F000)                     // TIMG0
    disableMWDT(0x6002_0000)                     // TIMG1
    disableRWDT()
    disableSWD()
}
