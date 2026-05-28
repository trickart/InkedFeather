# ADC Hardware Calibration via ROM I2C Functions

## Summary

The ESP32-C3 SAR ADC requires internal analog register configuration (DREF, INITIAL_CODE)
via an I2C analog master interface for correct readings. Without this, ADC values are
nonlinearly wrong, causing button detection to fail.

The I2C analog master **cannot** be operated by direct register manipulation of
`I2C_MST_I2C0_CTRL_REG` (0x6000_E040). The chip provides **ROM functions** that must be
used instead.

## Fix

`ADCDriver.initialize()` now:
1. Calls `rom_i2c_writeReg_Mask` (ROM at 0x40001960) to set SAR1_DREF = 4
2. Runs hardware calibration: connects ADC to internal ground, measures offset,
   writes result to INITIAL_CODE registers
3. Re-runs on every `initialize()` call (including after sleep wakeup)

ROM function symbols are provided via `linker/esp32c3.ld`.

## ROM I2C Functions

Addresses from `esp32c3.rom.ld` in the ESP-IDF framework:

| Function                | Address      | Prototype |
|-------------------------|--------------|-----------|
| `rom_i2c_readReg`       | `0x40001954` | `uint8_t (block, host_id, reg_add)` |
| `rom_i2c_readReg_Mask`  | `0x40001958` | `uint8_t (block, host_id, reg_add, msb, lsb)` |
| `rom_i2c_writeReg`      | `0x4000195c` | `void (block, host_id, reg_add, data)` |
| `rom_i2c_writeReg_Mask` | `0x40001960` | `void (block, host_id, reg_add, msb, lsb, data)` |

SAR ADC slave: `block=0x69, host_id=0`.

## SAR ADC Internal Registers (via I2C)

| Register | Addr | MSB:LSB | Value | Purpose |
|----------|------|---------|-------|---------|
| SAR1_INITIAL_CODE_LOW  | 0x00 | 7:0 | calibrated | Hardware offset low 8 bits |
| SAR1_INITIAL_CODE_HIGH | 0x01 | 3:0 | calibrated | Hardware offset high 4 bits |
| SAR1_DREF              | 0x02 | 6:4 | 4          | Internal reference voltage |
| SARADC1_ENCAL_REF      | 0x07 | 4:4 | 0          | Calibration reference (off) |
| SAR1_ENCAL_GND         | 0x07 | 5:5 | 0/1        | Internal ground (for cal) |

## Calibration Procedure

Matches ESP-IDF `adc_hal_calibration()`:

1. Set DREF = 4
2. Set ENCAL_GND = 1 (route ADC input to internal ground)
3. Clear INITIAL_CODE = 0
4. Take 10 ADC readings, average = ground offset
5. Write offset to INITIAL_CODE
6. Set ENCAL_GND = 0

## Why Direct Register I2C Is Impossible on ESP32-C3

Unlike ESP32-C6 and other newer variants, the ESP32-C3 does **not** expose an I2C
analog master CTRL register for user-space read/write operations. The address
`0x6000_E040` is `I2C_MST_ANA_CONF0_REG` (BBPLL stop control), **not** an I2C bus
control register.

ESP-IDF's `regi2c_ctrl_ll.h` for ESP32-C3 (confirmed in v5.4) contains only
enable/disable functions (`regi2c_ctrl_ll_i2c_saradc_enable` etc.) and **no**
`regi2c_ctrl_ll_i2c_read`/`regi2c_ctrl_ll_i2c_write` implementations. The HAL layer
falls through to ROM functions (`esp_rom_regi2c_read`/`esp_rom_regi2c_write`) via
`components/hal/platform_port/include/hal/regi2c_ctrl.h`.

This was verified by:
1. Reading the ESP-IDF v5.4 source for `regi2c_ctrl_ll.h` (ESP32-C3 variant) — no
   read/write register functions defined
2. Reading `regi2c_defs.h` — `0x6000_E040` is `I2C_MST_ANA_CONF0_REG`, not CTRL
3. Implementing a Swift direct-register driver with read-back verification — all
   non-zero writes read back as 0, confirming the register does not function as an
   I2C bus controller

ROM functions (`rom_i2c_writeReg_Mask` at `0x40001960` etc.) are the **only** way to
access SAR ADC internal registers on ESP32-C3. This is a hardware limitation, not a
software issue.

## Uncalibrated ADC Values (for reference)

With I2C registers at POR defaults (DREF=0, INITIAL_CODE=0):

| Button  | Channel | Expected (calibrated) | Observed (uncalibrated) |
|---------|---------|----------------------|------------------------|
| None    | CH1     | 4095                 | 4095                   |
| Back    | CH1     | ~3517                | ~3129                  |
| Confirm | CH1     | ~2686                | ~1627                  |
| None    | CH2     | 4095                 | 4095                   |
| Up      | CH2     | ~2234                | ~3870                  |
| Down    | CH2     | ~3                   | ~1628                  |
