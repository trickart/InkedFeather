import Registers

/// ESP32-C3 SYSTIMER-based timer utilities.
///
/// SYSTIMER runs at 16 MHz with a 52-bit counter (wraps after ~8.9 years).
/// `millis()` reads the full 52-bit counter and converts to milliseconds
/// using shifts only (no division, no interrupts).
///
/// The 32-bit result wraps every ~49.7 days, which is safe for idle
/// timeouts up to several hours with wrapping subtraction (`&-`).
enum TimerDriver {
    /// Read SYSTIMER unit0 as milliseconds (32-bit, wraps every ~49.7 days).
    ///
    /// Uses the full 52-bit SYSTIMER counter (hi + lo) to avoid the
    /// 268-second wraparound of the 32-bit `unit0_value_lo` alone.
    /// Approximates division by 16000 as a right-shift by 14 (~2.4% fast,
    /// negligible for idle timeouts).
    static func millis() -> UInt32 {
        systimer.unit0_op.write { $0.raw.storage = 1 << 30 }
        while systimer.unit0_op.read().raw.storage & (1 << 29) == 0 {}
        let lo = systimer.unit0_value_lo.read().raw.storage
        let hi = systimer.unit0_value_hi.read().raw.storage & 0xF_FFFF  // 20 bits
        // ticks >> 14 ≈ ticks / 16000 (actually / 16384, ~2.4% fast)
        return (hi << 18) | (lo >> 14)
    }

    /// Read SYSTIMER unit0 as microseconds (32-bit, wraps every ~268 seconds).
    /// Uses shift instead of division to avoid __udivdi3 on RV32.
    static func micros() -> UInt32 {
        systimer.unit0_op.write { $0.raw.storage = 1 << 30 }
        while systimer.unit0_op.read().raw.storage & (1 << 29) == 0 {}
        let ticks = systimer.unit0_value_lo.read().raw.storage
        return ticks >> 4  // divide by 16 (16 ticks = 1 us)
    }
}
