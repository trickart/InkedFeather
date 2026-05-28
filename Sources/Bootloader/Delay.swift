// SYSTIMER-based delay for bootloader.
// ESP32-C3 SYSTIMER runs at 16 MHz (1 tick = 1/16 us).
// SYSTIMER base: 0x60023000

import _Volatile

private let SYSTIMER_UNIT0_OP: UInt32       = 0x6002_3004
private let SYSTIMER_UNIT0_VALUE_LO: UInt32 = 0x6002_3044

/// Delay for the specified number of milliseconds using SYSTIMER.
func delayMs(_ ms: UInt32) {
    regStore(SYSTIMER_UNIT0_OP, 1 << 30)
    while regLoad(SYSTIMER_UNIT0_OP) & (1 << 29) == 0 {}
    let start = regLoad(SYSTIMER_UNIT0_VALUE_LO)

    let ticks = ms &* 16000  // 16 ticks/us * 1000 us/ms
    while true {
        regStore(SYSTIMER_UNIT0_OP, 1 << 30)
        while regLoad(SYSTIMER_UNIT0_OP) & (1 << 29) == 0 {}
        let now = regLoad(SYSTIMER_UNIT0_VALUE_LO)
        if (now &- start) >= ticks { break }
    }
}
