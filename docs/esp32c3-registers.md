# ESP32-C3 Register Reference

Peripheral base addresses and key register offsets used in InkedFeather.

## Peripheral Base Addresses

Generated from [espressif/svd](https://github.com/espressif/svd) ESP32-C3 SVD file via `Tools/generate-registers.swift`.
See [MMIO](mmio.md) for the register access library details.

| Peripheral | Base Address | Description |
|-----------|-------------|-------------|
| GPIO | `0x60004000` | General Purpose I/O |
| IO_MUX | `0x60009000` | I/O Multiplexer |
| SPI2 | `0x60024000` | GP-SPI (display + SD card) |
| SPI0 | `0x60003000` | Cache SPI (flash access) |
| SPI1 | `0x60002000` | Flash SPI |
| SYSTIMER | `0x60023000` | System Timer (16MHz) |
| TIMG0 | `0x6001F000` | Timer Group 0 |
| TIMG1 | `0x60020000` | Timer Group 1 |
| UART0 | `0x60000000` | UART Controller 0 |
| USB_DEVICE | `0x60043000` | USB Serial/JTAG Controller |
| RTC_CNTL | `0x60008000` | RTC Control |
| SYSTEM | `0x600C0000` | System Configuration |
| INTERRUPT_CORE0 | `0x600C2000` | Interrupt Matrix |
| EXTMEM | `0x600C4000` | External Memory (cache/MMU) |
| APB_SARADC | `0x60040000` | SAR ADC |

## Watchdog Registers

### TIMG0/1 Main Watchdog (MWDT)

| Register | Offset | Key Bits |
|----------|--------|----------|
| WDTCONFIG0 | `0x48` | [31] wdt_en, [14] flashboot_mod_en, [22] conf_update_en |
| WDTWPROTECT | `0x64` | Write `0x50D83AA1` to unlock |

### RTC Watchdog (RWDT)

Base: `0x60008000` (RTC_CNTL)

| Register | Offset | Key Bits |
|----------|--------|----------|
| WDTCONFIG0 | `0x90` | [31] wdt_en, [12] flashboot_mod_en |
| WDTFEED | `0xA4` | Write 1 to feed |
| WDTWPROTECT | `0xA8` | Write `0x50D83AA1` to unlock |

### Super Watchdog (SWD)

Base: `0x60008000` (RTC_CNTL)

| Register | Offset | Key Bits |
|----------|--------|----------|
| SWD_CONF | `0xAC` | [31] swd_auto_feed_en |
| SWD_WPROTECT | `0xB0` | Write `0x8F1D312A` to unlock (distinct from MWDT/RWDT key) |

## PLIC (Platform-Level Interrupt Controller)

Base: `0x20001000`

| Register | Offset | Description |
|----------|--------|-------------|
| MXINT_ENABLE | `0x000` | CPU interrupt enable bitmap |
| MXINT_TYPE | `0x004` | Edge (1) vs level (0) per interrupt |
| MXINT_CLEAR | `0x008` | Write 1 to clear pending |
| MXINT_PRI(n) | `0x010 + n*4` | Priority per CPU interrupt (0-15) |
| MXINT_THRESH | `0x090` | Priority threshold |

Interrupt Matrix at `0x600C2000` routes peripheral sources to CPU interrupt lines.
