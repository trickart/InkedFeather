# Battery ADC Calibration

## Overview

Battery voltage is monitored via a resistor divider (1:2 ratio) on GPIO0 (ADC1 channel 0).
The ADC reads half the actual battery voltage at 11dB attenuation.

Reference firmware: `/Users/trick/sample-firmware/open-x4-sdk/libs/hardware/BatteryMonitor/`

## ADC Voltage Conversion

### eFuse Calibration Data

ESP32-C3 stores chip-specific ADC calibration values in **eFuse BLOCK2** (SYS_DATA_PART1).

| Field | Register | Bits | Width | Description |
|-------|----------|------|-------|-------------|
| `BLK_VERSION_MAJOR` | DATA4 (`0x6000886C`) | [1:0] | 2 | Calibration version (valid when >= 1) |
| `ADC1_INIT_CODE_ATTEN3` | DATA5 (`0x60008870`) | [27:18] | 10 | ADC1 init code at 11dB |
| `ADC1_CAL_VOL_ATTEN3` | DATA6/7 (`0x60008874`/`0x60008878`) | D6[31:26]+D7[3:0] | 10 | Calibration voltage digi offset (signed) |

`CAL_VOL` is a signed 10-bit offset from default value **2000**.
This represents the ADC raw reading at the reference voltage of **1370mV**.

### Conversion Formula

Based on ESP-IDF's `esp_adc_cal_characterize` (curve fitting scheme):

```
digi = 2000 + signed_efuse_offset
voltage_mv = raw * 1370 / digi
```

- `raw` = 12-bit ADC reading (0-4095)
- `1370` = reference voltage in mV for ATTEN3 (11dB)
- `digi` = chip-specific ADC reading at the reference voltage

With default `digi=2000`, full scale is `4095 * 1370 / 2000 = 2805 mV`.

Falls back to default digi=2000 when eFuse is not programmed (`BLK_VERSION_MAJOR == 0`).
The digi value is cached after first read to avoid repeated eFuse access.

### Polynomial Error Correction (not implemented)

ESP-IDF applies a 5th-order polynomial for non-linearity correction after the linear
conversion. This is omitted here as the linear calibration alone provides sufficient
accuracy for battery monitoring (error < ~1%).

## Battery Percentage Curve

### LiPo Discharge Polynomial

LiPo cells have a non-linear discharge curve. The reference firmware uses a 3rd-order
polynomial fitted to real discharge data:

```
y = -144.939*v^3 + 1655.863*v^2 - 6158.852*v + 7501.320
```

### Piecewise Linear Approximation

Since the ESP32-C3 has no FPU, we use a piecewise linear approximation derived from
the polynomial above:

| Voltage (mV) | Percentage |
|--------------|------------|
| >= 4200 | 100% |
| 4100 | 95% |
| 4000 | 84% |
| 3900 | 79% |
| 3800 | 56% |
| 3700 | 43% |
| 3600 | 31% |
| 3500 | 15% |
| 3400 | 6% |
| 3300 | 1% |
| <= 3000 | 0% |

The steep drop around 3.8V-3.7V is characteristic of LiPo cell chemistry.

## Charging-State Compensation

The voltage-to-SOC curve above assumes the cell is at rest (open-circuit).
During USB charging the terminal voltage reads noticeably higher than the
resting voltage due to two effects:

- **IR drop**: charge current × internal resistance adds roughly 50–100mV
  at typical 0.5C charge rates.
- **CV-phase regulation**: once the cell hits ~4.2V the charger holds it
  there while current tapers — the measured voltage stays high even though
  the stored energy is still climbing.

Without compensation the displayed percentage jumps up on USB plug-in and
back down on unplug, even though the real SOC hasn't changed much.

### Detection

The hardware has no dedicated charge-status pin (no CHG/STAT from a
charging IC). `PowerManager.isUSBConnected()` reads GPIO20 (USB D-),
which is HIGH whenever USB is connected — this is used as a proxy for
"currently charging".

### Compensation

`BatteryMonitor.read()` subtracts a fixed offset from the raw voltage
before passing it through the SOC curve when USB is connected:

```
adjusted_mv = raw_mv - chargingOffsetMv   (only if USB connected)
percentage  = curve(adjusted_mv)
```

`chargingOffsetMv` defaults to **120mV**, covering a typical LiPo at
0.5C charge plus CV-phase headroom. Tune by logging `status.millivolts`
(raw, uncompensated) across a plug/unplug transition and picking a value
that keeps the percentage steady.

### API

`BatteryMonitor.read()` returns a `BatteryStatus`:

```swift
struct BatteryStatus {
    var millivolts: UInt32   // raw terminal voltage (uncompensated)
    var percentage: UInt32   // SOC after charging offset is applied
    var isCharging: Bool     // USB connected at time of read
}
```

The UI uses `isCharging` to overlay a ⚡ bolt on the battery icon.
The main loop re-renders when either `percentage` or `isCharging`
changes, so the bolt appears/disappears immediately on plug/unplug.

**Ordering requirement**: `PowerManager.initialize()` must run before
the first `BatteryMonitor.read()` so the USB-detect pin reports valid
state.

## Files

- `Sources/Application/Drivers/ADCDriver.swift` — eFuse reading and calibrated mV conversion
- `Sources/Application/Drivers/BatteryMonitor.swift` — voltage reading, SOC curve, charging offset
- `Sources/Application/PowerManager.swift` — `isUSBConnected()` (GPIO20) used as charge proxy
- `Sources/Application/UI/BatteryIcon.swift` — battery icon + charging bolt overlay
