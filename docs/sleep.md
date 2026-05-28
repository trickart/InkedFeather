# Deep Sleep & State Restore

## Overview

InkedFeather uses ESP32-C3 **deep sleep** to minimize idle power consumption.
Unlike light sleep, deep sleep powers down the digital domain (including SRAM)
and resets the CPU on wake. The trade-off is dramatically lower current —
~5 µA versus ~140 µA for light sleep — at the cost of needing to restore
application state from non-volatile storage on wake.

State restoration uses two stages:

1. **RTC store0** holds a 4-byte "wake marker" (`"INKD" = 0x494E_4B44`).
   The RTC domain stays powered through deep sleep, so the marker survives.
   It is *cleared* on full power-off (battery removal) or hardware reset,
   so the next cold boot proceeds normally.
2. **`RESUME.DAT`** in the SD card root holds the full snapshot
   (~100 bytes): which screen was active, the file browser dirStack,
   cursor position, and the open file's start cluster.

```
Active
  ↓  (Power button press OR 1 hour idle without USB)
Show "Sleeping..." overlay (partial e-ink refresh — immediate feedback)
  ↓
Search SD root for sleep.{bmp} (or fall back to default text)
  ↓
Show sleep screen (full e-ink refresh)
  ↓
E-ink display powered off
  ↓
TextViewer.saveResumeState (READHIST.DAT — per-file scroll history)
  ↓
ResumeStorage.save (RESUME.DAT — current screen snapshot)
  ↓
USB disconnected (D+ pull-up disabled)
  ↓
PowerManager.setWakeMarker (RTC store0 ← "INKD")
  ↓
PowerManager.enterDeepSleep (configures GPIO3 wakeup, PAD_HOLD, then SLEEP_EN)
  ↓
  ... CPU powered down, only RTC domain alive ...
  ↓
Power button press (GPIO3 LOW)  →  CHIP RESET (deep sleep wake)
  ↓
ROM bootloader → Bootloader.swift → Application.main()
  ↓
clearBSS → clearSleepState (PAD_HOLD release) → readAndClearWakeMarker
  ↓
Init SPI/Battery/Buttons/Framebuffer/E-ink
  ↓                                              ↓ (isResume = true)
  ↓ (isResume = false)                           Init SD/FAT/Font (panel still
  ↓                                              shows the sleep image)
Init SD/FAT/Font                                  ↓
  ↓                                              ResumeStorage.load (RESUME.DAT)
  ↓                                                ↓
  ↓                                              Reload parent dir + open file
  ↓                                                ↓
Render file browser (full refresh)              Render restored screen (full refresh)
  ↓                                                ↓
                  Main loop  ←─────────────────────┘
```

The display intentionally keeps the previous sleep image up until the final
screen is drawn — there is no separate intermediate "Resuming..." overlay.
With the FAT-sector cache in `FATFileSystem`, total time-to-ready is short
enough (~1.5 s for FileView resume) that the throwaway full refresh that
the overlay required (~1.4 s) cost more than the visual feedback was worth.

## Sleep Triggers

| Trigger | Condition | Source |
|---------|-----------|--------|
| Power button | Press during any screen | `Application.swift` button handler |
| Auto-sleep | 1 hour idle, USB disconnected | `Application.swift` main loop |

Auto-sleep uses `TimerDriver.millis()` for idle time tracking. `millis()`
reads the full 52-bit SYSTIMER counter and approximates milliseconds via
`>> 14`. The 32-bit result wraps after ~49 days, safe for the 1-hour timeout.

Auto-sleep is skipped when USB is connected (`PowerManager.isUSBConnected()`
checks GPIO20 / USB D- line).

## Sleep Screen

Before entering deep sleep, a sleep screen is displayed via full e-ink refresh.
Because e-ink retains its image without power, this screen remains visible
while the device sleeps.

### Custom Sleep Image

If a file named `sleep.bmp` exists in the SD card root directory, it is decoded
and displayed fullscreen (480×800). The filename match is case-insensitive.
Only BMP format is supported for sleep images — this avoids allocating the
~103 KB PNG/JPEG decoders during sleep entry.

### Default Text Screen

The fallback shows "Sleeping..." at 3× scale and "Press Power to wake" at
2× scale. Rendered by `UIRenderer.drawSleepScreen()`.

## Resume State

### `RESUME.DAT` format (100 bytes, little-endian)

| Offset | Size | Field |
|---:|---:|---|
| 0 | 4 | magic = `0x49465253` ("IFRS") |
| 4 | 1 | version = 1 |
| 5 | 1 | screen (0 = fileBrowser, 1 = textViewer, 2 = imageViewer) |
| 6 | 1 | dirDepth (0..16) |
| 7 | 1 | reserved |
| 8 | 64 | dirStack[16] (UInt32 cluster numbers) |
| 72 | 4 | selectedIndex (Int32 — FileListView cursor) |
| 76 | 4 | scrollOffset (Int32 — FileListView scroll) |
| 80 | 4 | parentDirCluster (UInt32 — for textViewer/imageViewer) |
| 84 | 4 | fileCluster (UInt32 — open file's start cluster) |
| 88 | 4 | fileSize (UInt32 — integrity check) |
| 92 | 4 | textScrollLine (Int32) |
| 96 | 4 | checksum (UInt32 — sum of bytes 0..95) |

The filename of the open file is *not* stored. On restoration, the parent
directory is re-listed and the entry is located by `fileCluster + fileSize`
match. This is rename-tolerant.

`textScrollLine` is included for completeness but unused on restore — the
TextViewer's existing per-file resume mechanism (`READHIST.DAT`) is updated
right before each sleep entry, so `loadFile()` automatically restores scroll
position via that path.

### `READHIST.DAT` (separate)

`READHIST.DAT` is a TextViewer-specific file holding per-file scroll
positions and the last 6 in-memory checkpoints for the last 16 files read.
It is *not* the same as `RESUME.DAT`. Both files coexist:

- `RESUME.DAT` — "what screen was active when we slept" (one snapshot)
- `READHIST.DAT` — "where was I in each file I've recently read, and which
  checkpoints had I built up" (LRU cache, see [`docs/text-viewer.md`](text-viewer.md)
  for the entry layout)

Storing the checkpoints alongside the scroll position lets `loadFile()` skip
the full-file rescan that would otherwise be needed to rebuild the
checkpoint array — the resume scan starts from the closest persisted
checkpoint instead of from offset 0.

## Wake Marker

`PowerManager.setWakeMarker()` writes `0x494E_4B44` to RTC_CNTL.store0
(offset `0x50` from base `0x6000_8000`) just before `enterDeepSleep()`.

`PowerManager.readAndClearWakeMarker()` reads store0, clears it, and
returns whether the magic was set. Called once at boot, immediately after
`clearSleepState()`.

Why two stages (RTC store0 + RESUME.DAT) instead of just RESUME.DAT?

- If we relied on RESUME.DAT alone, a user who reboots manually (or whose
  battery dies and is later replaced) would unexpectedly resume into the
  last sleep state instead of starting fresh. The RTC store0 marker ensures
  resume only happens after a *clean wake from deep sleep*.
- If we used RTC alone, the 32 bytes of store registers would not fit
  `dirStack[16]` (64 bytes by itself).

## Sleep Entry Sequence (`enterSleep`)

1. `showSleepingOverlay()` — partial refresh of "Sleeping..." for instant feedback
2. `findSleepImage()` + `drawSleepImage()` — load `sleep.bmp` if present
3. `eink.fullRefresh()` — render sleep screen
4. `eink.powerOff()` — put e-ink controller into its own deep sleep
5. `textViewer.saveResumeState()` — flush READHIST.DAT (auto-sleep path may have skipped it)
6. `ResumeStorage.save()` — write `RESUME.DAT`
7. USB D+ pull-up disabled (host sees disconnect)
8. `PowerManager.setWakeMarker()` — only if step 6 succeeded
9. `PowerManager.enterDeepSleep()` — *does not return*

If `RESUME.DAT` save fails (SD unavailable, write error), the marker is not
set and the next boot performs a normal cold start. The user simply finds
themselves at the file browser root rather than where they left off.

## Boot Resume Sequence (`Application.main()`)

1. `clearBSS`, `disableWatchdogs`, `setupTrapVector`
2. `PowerManager.clearSleepState()` — release PAD_HOLD left over from sleep
3. `PowerManager.readAndClearWakeMarker()` → `isResume` flag
4. SPI / Battery / PowerManager / Buttons / Framebuffer / E-ink init
5. SD / FAT / file browser load / Font load (same in both cold-boot and
   resume paths). The e-ink panel keeps showing whatever was on screen at
   power-off (the sleep image, for resume) — no intermediate overlay is
   drawn here.
6. **If `isResume && fatOk`**:
   1. `ResumeStorage.load()` reads and validates `RESUME.DAT`
   2. `restoreFromResumeState()` reloads the saved directory and re-opens
      the saved file (text or image), looking it up by `(cluster, fileSize)`
   3. On any failure, falls back to file browser root
7. `eink.requestFullRefreshes(1)` → `redrawXxx(...)` for the chosen screen.
   This single full refresh replaces the sleep image with the live UI.
8. Enter main loop

## Restoration Logic

For each screen type, the restore path is:

| Screen | Lookup | Action |
|---|---|---|
| `fileBrowser` | dirStack → loadFromDirectory (or root) | restoreCursor(selectedIndex, scrollOffset) |
| `textViewer` | parentDirCluster → loadFromDirectory → indexOfEntry(cluster, fileSize) | textViewer.loadFile (auto-restores scroll via READHIST.DAT) |
| `imageViewer` | parentDirCluster → loadFromDirectory → indexOfEntry(cluster, fileSize) | imageViewer.loadFile |

If the entry can't be located (file deleted, size changed, or directory
gone), `restoreFromResumeState()` returns false and the caller resets to
the file browser root.

## Wakeup Source

Only the **Power button (GPIO3)** wakes the device. GPIO3 is RTC-capable
(GPIO0-5 are in the VDD3P3_RTC power domain). The button is active-LOW
with an internal pull-up. Configured in `enterDeepSleep()`:

- `RTC_CNTL_GPIO_WAKEUP` (offset `0x110`) — GPIO3 wakeup enable + low-level trigger
- `RTC_CNTL_EXT_WAKEUP_CONF` (offset `0x64`) — glitch filter enable
- `RTC_CNTL_WAKEUP_STATE` (offset `0x3C`) — `RTC_GPIO_TRIG_EN` (bit 17)

## PAD_HOLD During Sleep

SPI bus and display pins are latched via PAD_HOLD so they retain safe
levels through the deep sleep transition and so SD cards can be safely
inserted/removed:

- GPIO 3 (power button), 4 (DC), 5 (RST), 6 (BUSY), 7 (MISO),
  8 (SCLK), 10 (MOSI), 12 (SD_CS), 21 (E-ink_CS)

`preparePinsForSleep()` reclaims SCLK/MOSI from SPI2 (so they're driven
by GPIO output rather than the peripheral) before PAD_HOLD latches them.

`clearSleepState()` (PAD_HOLD = 0) is called early in `Application.main()`
to release the hold so peripherals can be re-initialized.

## Power Domain Configuration (`enterDeepSleep`)

| Register | Offset | Key bits | Purpose |
|---|---|---|---|
| DIG_ISO | 0x8C | Clear bits 29, 23 | Allow WiFi/BT isolation |
| DIG_PWC | 0x88 | **Set bit 31** (`DG_WRAP_PD_EN`) | Power down digital domain |
| DIG_PWC | 0x88 | Set bits 30, 27 | WiFi/BT power-down enable |
| DIG_PWC | 0x88 | Set bit 16, bit 4 | FASTMEM_FORCE_LPU + LSLP_MEM_FORCE_PU |
| BIAS_CONF | 0x7C | DBG_ATTEN_DEEP_SLP=15 | Maximum attenuation for lowest current |
| CLK_CONF | 0x70 | Clear bits 28, 26, 16 | Allow clock gating |
| OPTIONS0 | 0x00 | Clear bits 13, 7 | Allow XTAL/BB I2C power-down |

The crucial difference from light sleep: **DG_WRAP_PD_EN is SET** for deep
sleep (powering down the digital domain) but was *cleared* for light sleep
(keeping it powered).

Sleep entry trigger: `RTC_CNTL_STATE0.SLEEP_EN` (bit 31) at offset `0x18`.

## Pitfalls & Lessons Learned

1. **Wake marker must use RTC store, not SRAM.** Deep sleep wipes SRAM. The
   RTC_CNTL.store0..store7 registers (each 32-bit) survive because the RTC
   domain stays powered. Application.swift uses store0 only.

2. **RESUME.DAT alone is not enough.** Without a marker, manual reboots and
   battery-out scenarios would unexpectedly resume into the last session.
   The store0 marker disambiguates "deep sleep wake" from any other reset.

3. **The filename should not be stored.** Save `(parentDirCluster,
   fileCluster, fileSize)` instead. On restore, re-list the directory and
   match by cluster + size. This survives renames.

4. **`indexOfEntry` requires `fileSize` match.** Cluster numbers can be
   reused if the file was deleted and another created in its place. The
   size check is a cheap, effective integrity guard.

5. **`enterSleep` does not return.** All wake-handling code (peripheral
   reinit, button-state sync, idle-timer reset) must move to the cold-boot
   path. The previous light-sleep `reinitPeripherals()` was deleted entirely.

6. **The first refresh after wake must be a full refresh.** The e-ink
   controller loses its previous-frame state on chip reset, so partial
   refresh has nothing to diff against and displays nothing visible
   (resulting in a blank white panel). `eink.requestFullRefreshes(1)` is
   set immediately before the restore-time `redrawXxx()` call so the next
   `writeFramebuffer` is automatically upgraded to a pseudo full refresh,
   replacing the sleep image with the live UI in one shot.

   Earlier versions also drew an intermediate "Resuming..." overlay (a
   centered box on white) right after `eink.initialize()`, so the user got
   immediate feedback while SD/FAT/font initialized. That overlay was
   removed once the FAT-sector cache made the SD/FAT/font phase fast
   enough (~50 ms) that the throwaway full refresh it required (~1.4 s)
   cost more than the visual feedback was worth. The panel simply keeps
   showing the sleep image throughout boot until the live UI is rendered.

7. **`clearSleepState()` must run before peripherals are re-initialized.**
   PAD_HOLD survives reset (RTC domain), so without releasing it the GPIOs
   are stuck at their pre-sleep states and SPI re-init silently fails.

8. **Auto-sleep must save TextViewer scroll explicitly.** The `.power`
   button handler calls `textViewer.saveResumeState()` before
   `enterSleep`, but the auto-sleep path doesn't. `enterSleep` itself now
   calls it whenever `ui.currentScreen == .textViewer` to keep both paths
   consistent.
