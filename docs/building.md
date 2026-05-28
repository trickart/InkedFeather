# Building & Flashing

## Prerequisites

- **Swift toolchain**: `org.swift.630202603201a` (Swift 6.3 nightly with Embedded support)

All build tools (flashing, image conversion, partition table generation, serial monitor) are implemented in Swift under `Tools/` and require no additional dependencies.

## Build Commands

```bash
# Build application
make build

# Build bootloader
make bootloader

# Generate partition table
make partition-table

# Build and flash everything (bootloader + partition table + app)
make flash

# Inspect generated image
make image_info

# Reset device
make reset

# Clean all build artifacts
make clean
```

## Flashing

The device uses USB Serial/JTAG. Connect via USB and run:

```bash
make flash
```

This builds the bootloader, partition table, and application, then flashes them using `Tools/write-flash.swift`:

| Address | Binary |
|---------|--------|
| 0x0     | `build/bootloader.bin` |
| 0x8000  | `build/partition-table.bin` |
| 0x10000 | `build/app.bin` |

### Flash memory layout

| Address | Content |
|---------|---------|
| 0x0000 | Custom Swift bootloader (12KB) |
| 0x8000 | Partition table (3KB) |
| 0x9000 | NVS (20KB) |
| 0xE000 | OTA data (8KB) |
| 0x10000 | app0 — OTA slot 0 (6.25MB) |
| 0x650000 | app1 — OTA slot 1 (6.25MB) |
| 0xC90000 | SPIFFS (3.375MB) |
| 0xFF0000 | Coredump (64KB) |

## Serial Monitor

```bash
make monitor
```

## Backup & Restore Original Firmware

```bash
# Backup entire flash
esptool.py --chip esp32c3 --port /dev/cu.usbmodem1101 read_flash 0x0 0x1000000 firmware_backup.bin

# Restore
esptool.py --chip esp32c3 --port /dev/cu.usbmodem1101 write_flash 0x0 firmware_backup.bin
```
