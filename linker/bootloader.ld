/*
 * ESP32-C3 Bootloader Linker Script
 *
 * All sections placed in IRAM since the bootloader runs before
 * Flash MMU is configured. The ROM bootloader loads all segments
 * into RAM before jumping to the entry point.
 *
 * Placed at top of IRAM to avoid overlap with app's regions.
 * ESP32-C3 IRAM range: 0x4037C000 - 0x403DFFFF (400KB)
 */

/* ESP32-C3 ROM function addresses (mask ROM, always available) */
PROVIDE ( rom_i2c_readReg = 0x40001954 );
PROVIDE ( rom_i2c_readReg_Mask = 0x40001958 );
PROVIDE ( rom_i2c_writeReg = 0x4000195c );
PROVIDE ( rom_i2c_writeReg_Mask = 0x40001960 );

MEMORY
{
    /* 64KB at top of IRAM for bootloader */
    iram (RWX) : ORIGIN = 0x403D0000, LENGTH = 0x10000
}

SECTIONS
{
    /* Code */
    .text : {
        *(.text .text.*)
        . = ALIGN(4);
    } > iram

    /* Read-only data (placed in IRAM for bootloader) */
    .rodata : {
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
        *(.swift_modhash)
        . = ALIGN(4);
    } > iram

    /* Initialized data */
    .data : {
        _sdata = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        *(.got .got.*)
        *(.got.plt)
        . = ALIGN(4);
        _edata = .;
    } > iram

    /* Uninitialized data */
    .bss (NOLOAD) : {
        . = ALIGN(4);
        _sbss = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > iram

    /* Stack (4KB for bootloader) */
    .stack (NOLOAD) : {
        . = ALIGN(16);
        _stack_end = .;
        . += 0x1000;
        . = ALIGN(16);
        _stack_top = .;
    } > iram

    _heap_start = .;
    _heap_end = ORIGIN(iram) + LENGTH(iram);

    /DISCARD/ : {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
        *(.ARM.*)
        *(.riscv.attributes)
    }
}
