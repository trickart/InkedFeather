# USB Reconnection Handling

## Problem

The ESP32-C3's built-in USB Serial/JTAG controller handles USB protocol enumeration
in hardware. However, when the USB cable is unplugged and replugged after boot,
`/dev/cu.usbmodem` disappears and JTAG stops working. This happens because:

1. The firmware does not detect or handle the USB bus reset event triggered by replug.
2. The JTAG FIFO retains stale data from before the disconnect.
3. Serial FIFO writes that were in progress during disconnect can leave the endpoint
   in an inconsistent state.

## Solution

`USBController.pollBusReset()` (in `Sources/Application/Support/USBController.swift`)
is called from the main loop every 50 ms. It polls the `USB_DEVICE_INT_RAW` register
for the `USB_BUS_RESET` flag (bit 9), which the hardware sets whenever the host
issues a bus reset — including after a cable replug.

When a bus reset is detected, the handler performs three recovery steps:

### 1. Clear all USB interrupt flags

```
USB_DEVICE_INT_CLR = 0xFFFF_FFFF
```

Prevents stale interrupt state from interfering with subsequent operations.

### 2. Reset JTAG FIFOs

```
JFIFO_ST |=  (IN_FIFO_RESET | OUT_FIFO_RESET)   // assert reset
JFIFO_ST &= ~(IN_FIFO_RESET | OUT_FIFO_RESET)   // deassert reset
```

- `IN_FIFO_RESET` — bit 8 of `USB_DEVICE_JFIFO_ST_REG`
- `OUT_FIFO_RESET` — bit 9 of `USB_DEVICE_JFIFO_ST_REG`

This flushes any stale JTAG data and resets the FIFO read/write pointers.

### 3. Re-assert USB PHY configuration

```
CONF0 |= USB_PAD_ENABLE | DP_PULLUP
```

- `USB_PAD_ENABLE` — bit 14 of `USB_DEVICE_CONF0_REG`, enables the internal USB PHY
- `DP_PULLUP` — bit 9, pulls D+ high to signal full-speed device presence to the host

These bits should already be set (they are part of the reset default `0x00004200`),
but re-asserting them guarantees the host can detect the device after reconnection.

## Key Registers

| Register | Offset | Relevant Bits |
|----------|--------|---------------|
| `USB_DEVICE_INT_RAW` | 0x60043008 | bit 9: `USB_BUS_RESET_INT_RAW` |
| `USB_DEVICE_INT_CLR` | 0x60043014 | write-1-to-clear for all interrupt flags |
| `USB_DEVICE_JFIFO_ST` | 0x60043020 | bit 8: `IN_FIFO_RESET`, bit 9: `OUT_FIFO_RESET` |
| `USB_DEVICE_CONF0` | 0x60043018 | bit 9: `DP_PULLUP`, bit 14: `USB_PAD_ENABLE` |

## Files

- `Sources/Application/Support/USBController.swift` — bus reset polling and recovery
- `Sources/Application/Application.swift` — calls `USBController.pollBusReset()` in main loop
- `Sources/Application/Support/Serial.swift` — USB serial FIFO write (consumer of the recovered state)
