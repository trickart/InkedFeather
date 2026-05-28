# E-Ink Display

InkedFeather drives a **GDEY0426T82** 4.26" e-ink panel (480 × 800, 1bpp B/W)
through the **SSD1677** controller over SPI. The driver is reimplemented in
pure Swift from the public SSD1677 datasheet and the vendor reference sequence;
no third-party code is reused.

## Source Files

| File | Description |
|------|-------------|
| `Drivers/EInkDisplay.swift` | SSD1677 driver: init, RAM writes, waveform activation, deep sleep |
| `Drivers/EInkPins.swift` | Pin bundle (SPI + CS/DC/RST/BUSY) |
| `Drivers/Framebuffer.swift` | 1bpp framebuffer in panel-native byte order, with portrait-rotation mapping |

## Pin Map

| Signal | GPIO | Direction |
|--------|------|-----------|
| SPI SCLK | 8 | shared with SD |
| SPI MOSI | 10 | shared with SD |
| CS | 21 | output (active LOW) |
| DC | 4 | output (LOW = command, HIGH = data) |
| RST | 5 | output (active LOW) |
| BUSY | 6 | input (HIGH = busy) |

These match `PowerManager.preparePinsForSleep`, which holds them at safe
levels during deep sleep so a hot-removed SD card or floating SPI lines can't
disturb the panel.

## Refresh Model

The driver issues **only the partial-refresh waveform** (`0xFF` to register
`0x22`). Two surface APIs are exposed:

| API | Sequence | Use |
|-----|----------|-----|
| `writeFramebuffer` + `partialRefresh` | one partial update (~300 ms) | normal UI redraws |
| `pseudoFullRefresh(buffer)` | inverted-then-target via two partials (~600 ms) | screen transitions that need ghosting cleared (wake, sleep image, boot logo) |

The native full-refresh waveform (`0xF7`) is intentionally not used. Its
~1.5 s flicker dwarfs the redraw cost on this panel, and the pseudo path
below produces a clean enough result for our content.

### Pseudo Full Refresh

```
Phase 1: drive whatever is on screen → fully inverted target
  partialInit()
  writeRAMInverted(0x24, target)
  activate(0xFF)        // partial waveform, ~300 ms

Phase 2: drive inverted → target
  partialInit()
  writeRAMInverted(0x26, target)   // seed previous-frame baseline
  writeRAM(0x24, target)
  activate(0xFF)        // partial waveform, ~300 ms
```

**Why both phases.** A single partial update from "previous content" to the
target leaves visible ghosting after large changes (e.g. replacing the sleep
image with the file browser). Forcing every pixel through the extreme
inverted state first exercises the electrophoretic ink enough to settle
cleanly on the second pass.

**Why we write `0x26` explicitly in Phase 2.** SSD1677 computes the partial
waveform from the diff between RAM[B/W] (`0x24`, current frame) and RAM[Red]
(`0x26`, previous frame on monochrome panels). Whether the controller
auto-copies `0x24 → 0x26` after a partial update is undocumented for this
chip; seeding `0x26` with the inverted image makes Phase 2's diff correct
regardless.

**Inversion without a second 48 KB buffer.** `writeRAMInverted` keeps a
64-byte stack window, fills it with `~buffer[i]` one SPI chunk at a time,
and streams it out. No heap allocation, no `O(framebuffer size)` copy.

### Where each refresh is used

| Call site | Path |
|-----------|------|
| Boot / wake initial draw (file browser, text viewer, image viewer) | `pseudoFullRefresh` |
| Boot logo redraw (`case .boot`) | `pseudoFullRefresh` |
| Sleep image draw (just before `powerOff`) | `pseudoFullRefresh` |
| All other redraws in the main loop | `writeFramebuffer` + `partialRefresh` |

## SSD1677 Init Sequences

Two init paths are kept. Both end with `BUSY` low and the chip ready to
receive RAM data.

### `fullInit` — once at boot

Runs from `initialize()` to put the chip in a known-good state. Sets
booster soft start, driver output control (gate count = 479, scan mode
`0x02`), border waveform (`0x01`), and data entry mode `0x03` (X+, Y+).
After this the RAM window covers the full 800 × 480.

### `partialInit` — before every partial update

A lighter HW reset + minimal re-program: temperature sensor, border
waveform (`0x80`, "do not change during partial"), RAM window, RAM counter.
Driver-output / data-entry / booster carry through the HW reset on the
defaults the chip retains, mirroring the vendor reference flow.

### Command Reference

| Cmd | Register | Use |
|-----|----------|-----|
| `0x01` | Driver Output Control | gate count + scan direction (full init) |
| `0x0C` | Booster Soft Start | analog timings (full init) |
| `0x10` | Deep Sleep Mode | `powerOff` — argument `0x01` |
| `0x11` | Data Entry Mode | `0x03` = X+, Y+ (full init) |
| `0x12` | Software Reset | full init |
| `0x18` | Temperature Sensor | `0x80` = internal sensor (every init) |
| `0x20` | Master Activation | kicks off the loaded waveform |
| `0x22` | Display Update Control 2 | sequence selector — driver writes `0xFF` (partial) |
| `0x24` | Write RAM (B/W) | current frame |
| `0x26` | Write RAM (Red) | previous-frame baseline on B/W panels |
| `0x3C` | Border Waveform | `0x01` full / `0x80` partial |
| `0x44`/`0x45` | RAM X/Y Range | window (0..799 X, 0..479 Y) |
| `0x4E`/`0x4F` | RAM X/Y Counter | start address for next data byte |

## Framebuffer Layout

The framebuffer is **48 000 bytes laid out in the panel's native byte
order** — 800 source pixels per row × 480 gate rows, MSB-first within each
byte. `writeRAM(0x24, buffer)` streams these bytes straight to the panel
with no per-pixel transform.

Bit semantics match RAM[B/W]:

| Bit | Color |
|-----|-------|
| 1 | white |
| 0 | black |

`clear()` resets the buffer to all-`0xFF`.

### Rotation

The application draws in **portrait 480 × 800**, while the panel scans in
**landscape 800 × 480**. `Framebuffer(rotated: true)` advertises the
portrait dimensions and applies a per-pixel coordinate transform on the
way in:

```swift
// rotated == true
toNative(px, py) → (nx: py, ny: px)
```

This is an axis transpose: portrait Y becomes the source axis (long, 800),
portrait X becomes the gate axis (short, 480). Pixel-by-pixel paths
(`setPixel`, `drawRect`, `drawGlyph`, `drawCharScaled`, `drawStringScaled`,
`write1bitRow`) all funnel through `toNative`, so they agree on
orientation.

`copyToNativeBuffer` writes raw bytes straight into the buffer at a given
offset, bypassing the rotation. It is used only by pre-baked content like
`BootLogo`, which is generated by `Tools/convert-bootlogo.swift` already in
the panel's native byte ordering.

## SPI Transfer

`SPIDriver.write` caps each transaction at 64 bytes (the W0..W15 FIFO
limit on ESP32-C3 SPI2). `writeRAM` and `writeRAMInverted` hold CS LOW
across all chunks for one 48 000-byte RAM bank:

```
CS↓ DC=data
  [64 B][64 B][64 B] ... × 750 chunks
CS↑
```

At 10 MHz SPI clock this is ~54 ms of bus time per RAM bank — dominant
over the per-chunk overhead.

Per-command/data writes use single-byte transactions with full CS toggling
because the chip needs DC to settle between command and data bytes.

## BUSY Handling

After each refresh activation (`0x20`) and after `softwareReset` /
`hardwareReset`, the driver polls the `BUSY` pin until it drops LOW
(HIGH = busy on SSD1677). `waitBusy` has a 5-second timeout — generous
enough for the slowest refresh on this panel (~1.5 s, though we never
trigger the native full waveform).

If `BUSY` is still HIGH after 5 s the driver returns rather than hanging;
the most likely cause at that point is the panel cable being unseated, and
the device stays responsive.

## Power-Off

`powerOff()` sends `0x10` `0x01` (deep sleep mode 1) then waits 100 ms.
Combined with `PowerManager.preparePinsForSleep` holding RST/DC HIGH and
CS HIGH through `PAD_HOLD`, this keeps the panel image latched while the
ESP32-C3 is in deep sleep.

The next boot re-runs `EInkDisplay.initialize`, which does an HW reset and
`fullInit`, which is the supported way to wake the chip from deep sleep
mode.

## Boot/Wake Timing

A wake-from-sleep redraw looks like:

| Step | Approx. time |
|------|--------------|
| Bootloader + BSS + watchdog disable | ~5 ms |
| SD / FAT / font init (cache-warm) | ~50–150 ms |
| Render UI to framebuffer | ~5 ms |
| `pseudoFullRefresh` phase 1 (init + invert + activate) | ~300 ms |
| `pseudoFullRefresh` phase 2 (init + invert+target + activate) | ~300 ms |
| **Total (wake → first visible UI)** | **~700 ms** |

vs. ~2.0 s if we had used the native full-refresh waveform instead.
