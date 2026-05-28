# CPU Frequency Boost

## Overview

InkedFeather runs the ESP32-C3 CPU at **80 MHz** by default and temporarily
boosts to **160 MHz** only for CPU-intensive operations (image decoding,
text rendering). This halves idle power without sacrificing responsiveness.

The PLL stays locked at 480 MHz at all times — only the CPU divider changes.
APB clock remains 80 MHz regardless, so SPI, timers, and other peripherals
are unaffected by the switch.

## Register

CPU frequency is controlled by `SYSTEM_CPU_PER_CONF_REG` (`0x600C_0008`),
bits `[1:0]` (`CPUPERIOD_SEL`):

| CPUPERIOD_SEL | CPU Clock | Derivation |
|:---:|:---:|---|
| 0 | 80 MHz | 480 MHz PLL / 6 |
| 1 | 160 MHz | 480 MHz PLL / 3 |

## API

`PowerManager` provides two static methods:

```swift
PowerManager.setCPU80MHz()    // CPUPERIOD_SEL = 0
PowerManager.setCPU160MHz()   // CPUPERIOD_SEL = 1
```

Both are single register read-modify-write operations with no settling time
required. Safe to call from any context.

## Where Boost Is Applied

| Call site | File | What runs at 160 MHz |
|---|---|---|
| `ImageViewer.drawImage()` | `ImageViewer.swift` | BMP / PNG / JPEG decode + dither + framebuffer draw |
| `drawSleepImage()` | `Application.swift` | BMP decode for `sleep.bmp` before deep sleep entry |
| `redrawTextViewer()` | `Application.swift` | `UIRenderer.drawTextViewer` (UTF-8 decode, glyph cache, font rendering) |

In each case the pattern is the same:

```swift
PowerManager.setCPU160MHz()
// ... CPU-intensive work ...
PowerManager.setCPU80MHz()
```

The e-ink transfer (`writeFramebuffer`) and panel refresh (`partialRefresh`)
that follow run at 80 MHz — they are SPI/IO-bound, not CPU-bound.

## Boot Sequence

The bootloader's `configurePLL()` sets up the PLL and switches to 160 MHz.
The application runs its entire initialization (SPI, SD, FAT, font load,
resume restore, first screen draw) at 160 MHz. Immediately before entering
the main loop, `PowerManager.setCPU80MHz()` drops to 80 MHz for the idle
polling state.

```
configurePLL()          ← 160 MHz (bootloader)
  ↓
Application.main()      ← 160 MHz (init, first draw)
  ↓
setCPU80MHz()           ← 80 MHz (main loop)
  ↓
  ┌─ poll buttons ──────── 80 MHz
  │  ↓ (redraw needed)
  │  setCPU160MHz()     ← 160 MHz (render)
  │  draw...
  │  setCPU80MHz()      ← 80 MHz
  └──────────────────────→ loop
```

## Power Savings

From the ESP32-C3 datasheet (Table 5-8, Modem-sleep, peripherals off):

| CPU | Running | Idle (WFI) |
|---|---|---|
| 160 MHz | 23 mA | 16 mA |
| 80 MHz | 17 mA | 13 mA |

In a typical e-reader session the CPU spends >99% of its time in the idle
polling loop (50 ms delay between button checks). Dropping from 160 MHz to
80 MHz saves ~6 mA during CPU-running intervals and ~3 mA during WFI,
roughly a **26% reduction** in steady-state current.

## What Does Not Need 160 MHz

These operations are safe at 80 MHz because they are I/O-bound or trivially
short:

- E-ink panel update (`waitBusy` ~500 ms, physics-limited)
- SPI transfers (clock set by peripheral divider)
- FAT cluster walks (SD I/O dominates)
- Button polling / ADC sampling
- CRC-32 on PNG chunks
- Resume checksum (~100 bytes)
- File list sorting (max 64 entries, runs once per directory open)
