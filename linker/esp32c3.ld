/*
 * ESP32-C3 Linker Script for Bare-Metal Swift (InkedFeather)
 *
 * ESP32-C3 memory architecture:
 *   - IRAM and DRAM are different address ranges aliasing the same physical SRAM.
 *     IRAM (0x4037C000) is accessed via I-bus (instruction fetch).
 *     DRAM (0x3FC80000) is accessed via D-bus (data load/store).
 *     Physical SRAM is 400KB shared between both.
 *
 *   - Flash-mapped regions:
 *     IROM (0x42000000+) for code via ICache
 *     DROM (0x3C000000+) for read-only data via DCache
 *
 * The bootloader loads flash-mapped segments and copies .data to RAM.
 * Code that must execute from RAM (trap handler) goes to IRAM.
 * All data (.data, .bss, stack, heap) goes to DRAM.
 */

/* ESP32-C3 ROM function addresses (from esp32c3.rom.ld) */
PROVIDE ( rom_i2c_readReg = 0x40001954 );
PROVIDE ( rom_i2c_readReg_Mask = 0x40001958 );
PROVIDE ( rom_i2c_writeReg = 0x4000195c );
PROVIDE ( rom_i2c_writeReg_Mask = 0x40001960 );

MEMORY
{
    /* Instruction RAM - for code that must run from RAM (trap handler) */
    iram (RWX) : ORIGIN = 0x4037C000, LENGTH = 0x60000  /* 384KB */

    /* Data RAM - alias of same physical SRAM, for data access */
    dram (RW)  : ORIGIN = 0x3FC80000, LENGTH = 0x60000  /* 384KB */

    /* Flash-mapped instruction ROM */
    irom (RX)  : ORIGIN = 0x42000020, LENGTH = 0x400000 - 0x20  /* up to 4MB */

    /* Flash-mapped data ROM
     * The ESP32-C3 MMU shares one 128-entry table between the I-bus and the
     * D-bus, and the entry index is computed as ((vaddr & 0x7FFFFF) >> 16).
     * That means DROM at 0x3C040000 (entry 4) collides with the 5th IROM page
     * at 0x42040000 (also entry 4). Whichever segment Bootloader.setupFlashMMU
     * writes last wins, and the other reads end up pointing at the other
     * segment's flash page — the symptom is garbled bytes from any
     * StaticString once .text grows past 4 pages.
     *
     * Putting DROM at virtual offset 0x400000 (entry 64) leaves entries 0..63
     * (4MB) free for IROM, so the two can never share an entry. */
    drom (R)   : ORIGIN = 0x3C400020, LENGTH = 0x400000 - 0x20  /* up to 4MB */
}

SECTIONS
{
    /* Trap handler in IRAM (must execute from RAM, not flash) */
    .trap_handler : {
        . = ALIGN(4);
        KEEP(*(.trap_handler))
        . = ALIGN(4);
    } > iram

    /* Code in flash-mapped IROM */
    .text : {
        _stext = .;
        *(.text .text.*)
        . = ALIGN(4);
        _etext = .;
    } > irom

    /* Read-only data in flash-mapped DROM */
    .rodata : {
        . = ALIGN(4);
        _srodata = .;
        *(.rodata .rodata.*)
        *(.srodata .srodata.*)
        *(.swift_modhash)
        . = ALIGN(4);
        _erodata = .;
    } > drom

    /* Initialized data in DRAM (loaded from flash by bootloader) */
    .data : {
        . = ALIGN(4);
        _sdata = .;
        *(.data .data.*)
        *(.sdata .sdata.*)
        *(.got .got.*)
        *(.got.plt)
        . = ALIGN(4);
        _edata = .;
    } > dram

    /* Uninitialized data in DRAM */
    .bss (NOLOAD) : {
        . = ALIGN(4);
        _sbss = .;
        *(.bss .bss.*)
        *(.sbss .sbss.*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > dram

    /* Stack in DRAM */
    .stack (NOLOAD) : {
        . = ALIGN(16);
        _stack_end = .;
        . += 0x4000;  /* 16KB stack */
        . = ALIGN(16);
        _stack_top = .;
    } > dram

    . = ALIGN(8);
    _heap_start = .;
    _heap_end = ORIGIN(dram) + LENGTH(dram);

    /DISCARD/ : {
        *(.comment)
        *(.note*)
        *(.eh_frame*)
        *(.ARM.*)
        *(.riscv.attributes)
    }
}
