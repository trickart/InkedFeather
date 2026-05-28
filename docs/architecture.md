# InkedFeather Architecture

Bare-metal Embedded Swift firmware for the Xteink X4 e-Reader (ESP32-C3).

## Target Hardware

| Component | Specification |
|-----------|--------------|
| SoC | ESP32-C3 (RISC-V RV32IMC, single core, 160MHz) |
| Flash | 16MB SPI |
| RAM | 400KB SRAM (shared IRAM/DRAM) |
| Display | 4.26" e-ink 800×480 (GDEQ0426T82, SSD1677), SPI @40MHz |
| SD Card | microSD via shared SPI bus |
| Battery | 650mAh, ADC monitoring on GPIO0 |
| Buttons | Resistor ladder on GPIO1/GPIO2 ADC, power button on GPIO3 |
| USB | USB Serial/JTAG (CDC) for debug output |

### Pin Map

| Function | GPIO | Interface |
|----------|------|-----------|
| SPI SCLK | 8 | SPI2 |
| SPI MOSI | 10 | SPI2 |
| SPI MISO (SD) | 7 | SPI2 |
| Display CS | 21 | GPIO |
| Display DC | 4 | GPIO |
| Display RST | 5 | GPIO |
| Display BUSY | 6 | GPIO |
| SD Card CS | 12 | GPIO |
| Battery ADC | 0 | ADC1 |
| Buttons (4) | 1 | ADC1 |
| Buttons (2) | 2 | ADC1 |
| Power Button | 3 | GPIO |
| USB Detect | 20 | GPIO |

## ESP32-C3 Memory Map

```
IRAM  0x4037C000 - 0x403DFFFF  (400KB, instruction bus)
DRAM  0x3FC80000 - 0x3FCFFFFF  (400KB, data bus — same physical SRAM as IRAM)
IROM  0x42000000+              (flash-mapped code via ICache)
DROM  0x3C000000+              (flash-mapped read-only data via ICache)
```

**Important**: IRAM and DRAM are different bus addresses aliasing the same physical memory.
The linker script places code (.trap_handler) in IRAM and data (.data/.bss/stack/heap) in DRAM.

### DROM Offset

The DROM origin must account for the app partition's flash offset.
App partition is at flash 0x10000 → DROM origin = `0x3C040020` (not `0x3C000020`).
The ESP-IDF bootloader maps DROM using absolute flash addresses, unlike IROM.

## Project Structure

```
InkedFeather/
├── Package.swift                   # Swift 6.3, multi-target embedded package
├── Makefile                        # Build orchestration
├── toolset.json                    # Compiler flags (Application)
├── toolset-bootloader.json         # Compiler flags (Bootloader)
├── linker/
│   ├── esp32c3.ld                  # Application linker script
│   └── bootloader.ld               # Bootloader linker script
├── Tools/
│   ├── elf2image.swift             # ELF → ESP32-C3 flash image
│   ├── gen-partition-table.swift   # Partition table generator
│   ├── generate-registers.swift    # svd2swift register definition generator
│   ├── write-flash.swift           # Serial flash writer
│   ├── image-info.swift            # Image header inspector
│   ├── monitor.swift               # USB serial monitor
│   ├── reset.swift                 # Chip reset over serial
│   └── convert-bootlogo.swift      # BMP → BootLogo.swift converter
├── Sources/
│   ├── Application/                # Main firmware
│   │   ├── Application.swift       # Entry point (@main), main loop, input dispatch
│   │   ├── PowerManager.swift      # Deep sleep entry, wake marker, PAD_HOLD
│   │   ├── ResumeStorage.swift     # RESUME.DAT load/save (deep-sleep snapshot)
│   │   ├── Drivers/
│   │   │   ├── GPIO.swift          # GPIO pin abstraction (IO_MUX + GPIO Matrix)
│   │   │   ├── SPIDriver.swift     # SPI2 master (CPU FIFO, 64B/transaction)
│   │   │   ├── SDCard.swift        # SPI SD protocol (CMD0/8/41/58/17/24)
│   │   │   ├── FATFileSystem.swift # FAT16/FAT32 read/write + LFN + FAT sector cache
│   │   │   ├── EInkDisplay.swift   # SSD1677 display driver (init, refresh, sleep)
│   │   │   ├── EInkPins.swift      # SPI command/data protocol, BUSY, reset
│   │   │   ├── EInkLUT.swift       # Waveform LUT reference values
│   │   │   ├── Framebuffer.swift   # 48KB 1-bit buffer, 270° rotation, drawing
│   │   │   ├── ADCDriver.swift     # ADC1 12-bit reader
│   │   │   ├── BatteryMonitor.swift # ADC → voltage → percentage + charging offset
│   │   │   │                         #   (read() returns BatteryStatus: mv / pct / isCharging)
│   │   │   ├── ButtonDriver.swift  # ADC resistor ladder debounce
│   │   │   └── TimerDriver.swift   # SYSTIMER wrapper (10ms tick → millis)
│   │   ├── UI/
│   │   │   ├── UIRenderer.swift    # Screen state machine + draw dispatchers
│   │   │   ├── FileListView.swift  # File browser model + cursor / scroll
│   │   │   ├── TextViewer.swift    # Text reader, ring buffer, READHIST.DAT resume
│   │   │   ├── ImageViewer.swift   # BMP/PNG/JPEG viewer (dispatch by extension)
│   │   │   ├── BitmapFont.swift    # font.bin loader + glyph cache
│   │   │   ├── FontData.swift      # Built-in 8x16 ASCII fallback font
│   │   │   ├── UTF8Decoder.swift   # UTF-8 → code point decoder
│   │   │   ├── BatteryIcon.swift   # Battery indicator drawing (bolt overlay while charging)
│   │   │   └── BootLogo.swift      # Embedded boot logo bitmap
│   │   ├── Decoders/
│   │   │   ├── BMPDecoder.swift    # Streaming BMP decoder (1/4/8/24-bit)
│   │   │   ├── PNGDecoder.swift    # PNG decoder (uses Deflate + CRC32)
│   │   │   ├── JPEGDecoder.swift   # Baseline JPEG decoder (uses SoftFloat)
│   │   │   ├── Deflate.swift       # zlib/Deflate inflate
│   │   │   ├── CRC32.swift         # CRC32 (PNG chunk validation)
│   │   │   └── ImageDither.swift   # Floyd-Steinberg dither to 1-bit
│   │   └── Support/
│   │       ├── Startup.swift       # BSS clear, watchdog setup, trap vector
│   │       ├── Watchdog.swift      # WDT disable (TIMG0/1, RTC, SWD)
│   │       ├── TrapDispatcher.swift # Interrupt/exception dispatch
│   │       ├── InterruptController.swift  # PLIC + interrupt matrix
│   │       ├── CSR.swift           # RISC-V CSR helpers
│   │       ├── VolatileRegister.swift # MMIO read/write helpers
│   │       ├── Delay.swift         # SYSTIMER-based µs delay
│   │       ├── Serial.swift        # USB Serial/JTAG output (usbPrint, usbPrintNum)
│   │       ├── USBController.swift # USB CDC bus reset / re-enumeration handling
│   │       ├── Random.swift        # PRNG (seeded from SYSTIMER)
│   │       └── ChaCha20.swift      # ChaCha20 stream cipher
│   ├── Bootloader/                 # Pure Swift 2nd-stage bootloader
│   │   ├── Bootloader.swift        # Entry point, partition load, jump to app
│   │   ├── ClockConfig.swift       # PLL → 160 MHz CPU clock
│   │   ├── FlashConfig.swift       # SPI flash mode/speed setup
│   │   ├── FlashRead.swift         # Direct flash read (no MMU)
│   │   ├── MMU.swift               # IROM/DROM flash MMU mapping
│   │   ├── Watchdog.swift          # WDT feed during boot
│   │   └── Delay.swift             # Bootloader-local delay (no SYSTIMER yet)
│   ├── HeapAllocator/              # Free-list heap (posix_memalign/free)
│   ├── MemoryPrimitives/           # memset/memcpy/memmove implementations
│   ├── SoftFloat/                  # Software float / double (used by JPEG decoder)
│   ├── Registers/                  # MMIO register defs (svd2swift-generated)
│   └── TrapHandler/                # Assembly: vector table, CSR accessors
│       ├── trap.S
│       └── include/trap.h
├── build/                          # Build output
│   ├── app.bin
│   ├── bootloader.bin              # Custom Swift bootloader
│   └── partition-table.bin
└── docs/
```

## Build Targets

| Target | Description | Dependencies |
|--------|-------------|-------------|
| Application | Main firmware executable | Registers, MemoryPrimitives, HeapAllocator, TrapHandler, SoftFloat |
| Bootloader | Custom Swift 2nd-stage bootloader | Registers, MemoryPrimitives, HeapAllocator |
| Registers | MMIO register definitions (svd2swift) | — (uses swift-mmio macros) |
| TrapHandler | Assembly vector table + CSR accessors | — |
| HeapAllocator | Bare-metal heap allocator | — |
| MemoryPrimitives | memset/memcpy/memmove replacements | — |
| SoftFloat | Software float / double for the JPEG decoder | — |

## Application Subsystems

`Application.main()` wires the modules below into a single boot path that is
shared between cold-boot and deep-sleep wake. The wake marker (RTC store0)
flips a single `isResume` flag at the very top, after which the same
SD/FAT/font initialization runs in both cases.

| Subsystem | Files | Role |
|---|---|---|
| Boot / main loop | `Application.swift`, `Support/Startup.swift` | Peripheral init order, button polling, redraw on `ui.consumeRedraw()`, auto-sleep / battery / resume-save tickers |
| Display stack | `Drivers/EInkDisplay.swift`, `Drivers/Framebuffer.swift`, `UI/UIRenderer.swift` | Framebuffer drawing → SSD1677 partial / pseudo-full refresh |
| Storage stack | `Drivers/SDCard.swift`, `Drivers/FATFileSystem.swift` | SPI SD card driver + FAT16/32 read/write with a 1-sector FAT cache |
| File browser | `UI/FileListView.swift`, `UI/UIRenderer.swift` | Directory listing, navigation stack, action menu |
| Text viewer | `UI/TextViewer.swift`, `UI/BitmapFont.swift`, `UI/UTF8Decoder.swift`, `UI/FontData.swift` | Streaming text reader with ring buffer + per-file resume (`READHIST.DAT`) |
| Image viewer | `UI/ImageViewer.swift`, `Decoders/*` | BMP / PNG / JPEG decode → 1-bit dither → framebuffer |
| Sleep / resume | `PowerManager.swift`, `ResumeStorage.swift` | Deep-sleep entry, RTC wake marker, `RESUME.DAT` snapshot of the active screen |
| USB serial | `Support/Serial.swift`, `Support/USBController.swift` | USB CDC output for `usbPrint`, bus-reset / re-enumeration recovery |

### Sleep / Resume Flow

The deep-sleep / resume design is documented in detail in
[`docs/sleep.md`](sleep.md). The short summary:

- `enterSleep()` writes `RESUME.DAT` (active screen, dirStack, open file's
  cluster + size, etc.) and sets the `"INKD"` wake marker in `RTC_CNTL.store0`
  before calling `PowerManager.enterDeepSleep()`. Deep sleep wipes SRAM but
  the RTC domain (and the marker) survives.
- On wake, the chip resets and re-enters `Application.main()`. The wake
  marker is read once via `PowerManager.readAndClearWakeMarker()`. If set,
  the same boot path that runs on a cold start now also calls
  `ResumeStorage.load()` and `restoreFromResumeState()` after FAT/font init
  to re-open the previously active screen.
- The e-ink panel keeps showing the sleep image throughout the SD/FAT/font
  phase — there is no separate "Resuming…" overlay. The first (and only)
  full refresh on the wake path is the live UI redraw, requested via
  `eink.requestFullRefreshes(1)` immediately before the final `redrawXxx()`
  call.

The `TextViewer` has its own `READHIST.DAT` LRU cache for *per-file* scroll
positions plus the most recent checkpoints — see
[`docs/text-viewer.md`](text-viewer.md). On a deep-sleep wake the two
cooperate: `RESUME.DAT` says "this file was open", `READHIST.DAT` says "you
were on line N of it, and here are the recent checkpoints so you can resume
the scan from line N − a few hundred instead of from offset 0".

## Compiler Configuration

Key flags in `toolset.json`:

- `-enable-experimental-feature Embedded` — Embedded Swift mode
- `-Osize` — Optimize for size
- `-wmo` — Whole module optimization
- `-nostartfiles -nostdlib -static` — No C runtime
- `-use-ld=lld` — LLVM linker
- `-e main` — Entry point

Triple: `riscv32-none-none-eabi`
