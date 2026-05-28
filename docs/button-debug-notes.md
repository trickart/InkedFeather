# Button Driver Debug Notes

## Overview

Xteink X4 uses ADC resistor ladders for button input:
- **GPIO1 (ADC1 ch1)**: Back, Confirm, Left, Right (4 buttons)
- **GPIO2 (ADC1 ch2)**: Up, Down (2 buttons)
- **GPIO3**: Power button (digital, active LOW with pull-up)

Reference firmware: `/Users/trick/sample-firmware/open-x4-sdk/libs/hardware/InputManager/`

## Measured ADC Values (12-bit raw, 11dB attenuation)

### Channel 1 (GPIO1)

| Button  | Raw ADC | Hex    | Sample FW |
|---------|---------|--------|-----------|
| None    | 4095    | 0xFFF  | ~3800+    |
| Back    | ~3517   | 0xDBD  | 3512      |
| Confirm | ~2686   | 0xA7E  | 2694      |
| Left    | ~1487   | 0x5CF  | 1493      |
| Right   | ~5      | 0x005  | 5         |

### Channel 2 (GPIO2)

| Button | Raw ADC | Hex    | Sample FW |
|--------|---------|--------|-----------|
| None   | 4095    | 0xFFF  | ~3800+    |
| Up     | ~2234   | 0x8BA  | 2242      |
| Down   | ~3      | 0x003  | 5         |

### Decode Thresholds (midpoints)

Channel 1: `>3800` None, `>3100` Back, `>2090` Confirm, `>750` Left, else Right

Channel 2: `>3160` None, `>1120` Up, else Down

## Bugs Found and Fixed

### 1. ADC register addresses (all 4 wrong)

The `ADCDriver.read()` function used hardcoded register addresses that did not match the SVD-generated register layout.

| Register       | Wrong Address  | Correct Address | Offset | Actually Accessed     |
|----------------|----------------|-----------------|--------|-----------------------|
| int_raw        | `0x6004_0034`  | `0x6004_0044`   | 0x44   | thres0_ctrl           |
| int_clr        | `0x6004_0038`  | `0x6004_004c`   | 0x4c   | thres1_ctrl           |
| onetime_sample | `0x6004_0054`  | `0x6004_0020`   | 0x20   | clkm_conf (destroyed clock!) |
| sar1_status    | `0x6004_0028`  | `0x6004_002c`   | 0x2c   | filter_ctrl0          |

**Impact**: `onetime_sample` writes overwrote `clkm_conf`, destroying the ADC clock configuration. `read()` always timed out, returning `0xFFFF & 0xFFF = 4095` (no button).

**Fix**: Corrected all 4 addresses. Changed result register from `sar1_status` (0x10) to `sar1data_status` (0x2c) per ESP-IDF's `adc_ll_adc1_read()`.

### 2. Missing `fsm_wait` register configuration

`ADCDriver.initialize()` did not configure `APB_SARADC.fsm_wait`, which controls ADC power-up/reset/standby wait timing.

**Impact**: With default (zero) `fsm_wait` values, the ADC sampling phase was too short for high-impedance resistor ladder voltages. Back (~3517) and Confirm (~2686) always read as 4095 because the SAR internal capacitor retained charge from the previous read and couldn't discharge to the correct voltage in time. Lower-voltage buttons (Left, Right, Up, Down) had enough voltage difference to settle.

**Fix**: Added `fsm_wait` configuration matching ESP-IDF defaults:
```swift
apb_saradc.fsm_wait.write {
    $0.raw.storage = (8 << 0) | (100 << 8) | (100 << 16)
    // xpd_wait=8, rstb_wait=100, standby_wait=100
}
```

### 3. Button decode thresholds

Initial thresholds were incorrect (estimated from partially working ADC reads). Updated to midpoints calculated from verified measurements, matching sample firmware.

## Debounce Strategy

The button driver uses an **immediate-press, debounced-release** approach:

- **Press detection**: When a new button is read and the current state is `buttonNone`, the press is accepted **immediately** (single poll cycle = ~50ms worst case). This ensures quick taps are never missed.
- **Release detection**: Requires `debounceThreshold` (2) consecutive stable readings before the state transitions. This prevents false releases due to ADC noise mid-press.

Previous approach used symmetric debounce (3 stable readings for both press and release at 50ms polling = 150ms minimum hold time), which caused quick single-clicks to be ignored.

### Poll logic (`ButtonDriver.poll()`)

```
raw = readRaw()
if raw == lastButton: stableCount++
else:                 lastButton = raw, stableCount = 0

if raw != none AND debounced == none:    → immediate press
elif stableCount >= threshold:           → debounced state change (release, or button switch)
```

## Debugging Tips

### Debug ADC output

`Application.swift` main loop prints raw ADC values every 500ms:
```
0x00000DBD    ← ch1 raw (Back pressed)
0x00000FFF    ← ch2 raw (no button)
0x00000001    ← debounced button ID
--
```

Button IDs: 0=None, 1=Back, 2=Confirm, 3=Left, 4=Right, 5=Up, 6=Down, 7=Power

### ADC read sequence (oneshot mode)

Per ESP-IDF `adc_oneshot_hal_convert()`:
1. Clear ADC1 done interrupt (int_clr bit 31)
2. Configure channel + attenuation in onetime_sample
3. Enable saradc1_onetime_sample (bit 31)
4. Start conversion (bit 29)
5. Wait for ADC1 done (int_raw bit 31)
6. Read result from sar1data_status (lower 12 bits)
7. Stop (clear start bit)
8. Disable (clear enable bit)

### Key registers (APB_SARADC base `0x60040000`)

| Register         | Offset | Purpose                        |
|------------------|--------|--------------------------------|
| ctrl             | 0x00   | Clock gating, SAR power, etc.  |
| ctrl2            | 0x04   | Timer mode, inversion          |
| fsm_wait         | 0x0c   | Sampling timing (critical!)    |
| sar1_status      | 0x10   | SAR1 FSM state                 |
| onetime_sample   | 0x20   | Channel/atten/enable/start     |
| sar1data_status  | 0x2c   | Conversion result (12-bit)     |
| int_raw          | 0x44   | Interrupt flags (bit 31 = ADC1 done) |
| int_clr          | 0x4c   | Clear interrupt flags          |
| clkm_conf        | 0x54   | ADC clock source/divider       |
