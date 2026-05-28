# Boot Sequence

## Overview

```
ROM Bootloader (in chip ROM)
    ↓
ESP-IDF 2nd-stage Bootloader (flash 0x0)
    - Reads partition table at 0x8000
    - Finds app0 at 0x10000
    - Sets up flash MMU (IROM + DROM mapping)
    - Loads RAM segments (IRAM, DRAM)
    - Jumps to app entry point
    ↓
Application main() (InkedFeather)
    1. clearBSS()           — Zero .bss section
    2. disableWatchdogs()   — TIMG0, TIMG1, RTC WDT, SWD
    3. setupTrapVector()    — Set mtvec to vector table (vectored mode)
    4. PowerManager.clearSleepState()    — Release PAD_HOLD from deep sleep
    5. PowerManager.readAndClearWakeMarker() — RTC store0 → isResume flag
    6. [peripheral init]    — SPI, battery, buttons, framebuffer, e-ink
    7. SD / FAT / font load — same in cold-boot and resume paths
    8. If isResume → ResumeStorage.load + restore screen state
    9. requestFullRefreshes(1) → redraw chosen screen (one full refresh
       replaces the sleep image with the live UI)
   10. Main loop
```

Steps 4–9 follow the deep-sleep wake path; on a cold boot the wake marker
read in step 5 returns false and steps 8 collapses to "stay at the file
browser root". See `docs/sleep.md` for the deep-sleep / resume design,
the RESUME.DAT format, and the rationale for sharing the cold-boot and
resume code paths.

## Bootloader

Currently using the ESP-IDF bootloader extracted from the sample-firmware PlatformIO build.
A custom Swift bootloader exists as a stub (`Sources/Bootloader/`) for future development.

The ESP-IDF bootloader handles:
- PLL clock configuration (160MHz CPU)
- Flash MMU setup for IROM (0x42000000+) and DROM (0x3C040000+)
- Loading IRAM/DRAM segments from flash to SRAM
- Watchdog feeding during boot

## Application Startup

### 1. clearBSS()

Zeroes the `.bss` section (uninitialized global variables in DRAM).
Uses linker symbols `_sbss` / `_ebss` to determine the region.
Manual byte-by-byte clear to avoid dependency on memset (which lives in MemoryPrimitives).

### 2. disableWatchdogs()

Four independent watchdog timers must be disabled:

1. **TIMG0 MWDT** (`0x6001F000`) — Main watchdog, timer group 0
2. **TIMG1 MWDT** (`0x60020000`) — Main watchdog, timer group 1
3. **RTC WDT** (`0x60008000 + 0x90`) — RTC domain watchdog
4. **SWD** (`0x60008000 + 0xAC`) — Super watchdog (set auto-feed)

MWDT and RWDT use unlock key `0x50D83AA1`. SWD uses a separate key `0x8F1D312A`.

### 3. setupTrapVector()

Sets the `mtvec` CSR to point to the vector table in IRAM (`.trap_handler` section).
Mode = vectored (bit 0 = 1): exception goes to BASE+0, interrupt N goes to BASE+4*N.

## Trap Handler (Assembly)

Minimal assembly in `trap.S`:

- **Vector table**: 32 entries (64-byte aligned), each a `j` instruction
- **Interrupt handler**: Save 16 caller-saved registers → call `trap_handler_swift(mcause)` → restore → `mret`
- **Exception handler**: Call `trap_handler_swift(mcause)` → `mret`
- **CSR accessors**: `csr_read_mstatus`, `csr_write_mtvec`, etc. (2 instructions each)
- **nop_delay**: Cycle-accurate delay loop for bit-bang timing

The Swift dispatcher (`TrapDispatcher.swift`) receives `mcause` and routes to the appropriate ISR.
