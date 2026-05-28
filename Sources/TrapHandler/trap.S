/*
 * Minimal RISC-V trap handler and CSR accessors for ESP32-C3.
 * This is the only non-Swift code in the project.
 *
 * ESP32-C3 PLIC uses vectored mode (mtvec MODE=1).
 * In vectored mode:
 *   - Exception:       jumps to BASE + 0
 *   - Interrupt cause N: jumps to BASE + 4*N
 * Each vector table entry is one 32-bit jump instruction.
 *
 * Note: ESP32-C3 is RV32IMC (no Atomic extension).
 */

    .section .trap_handler, "ax"

/* ---- Vector table (must be 64-byte aligned) ---- */
/* Each entry must be exactly 4 bytes (disable compressed instructions) */
    .global _vector_table
    .align 6
    .option push
    .option norvc
_vector_table:
    j _exception_handler     /*  0: exceptions */
    j _interrupt_handler     /*  1: CPU interrupt 1 */
    j _interrupt_handler     /*  2 */
    j _interrupt_handler     /*  3 */
    j _interrupt_handler     /*  4 */
    j _interrupt_handler     /*  5 */
    j _interrupt_handler     /*  6 */
    j _interrupt_handler     /*  7 */
    j _interrupt_handler     /*  8 */
    j _interrupt_handler     /*  9 */
    j _interrupt_handler     /* 10 */
    j _interrupt_handler     /* 11 */
    j _interrupt_handler     /* 12 */
    j _interrupt_handler     /* 13 */
    j _interrupt_handler     /* 14 */
    j _interrupt_handler     /* 15 */
    j _interrupt_handler     /* 16 */
    j _interrupt_handler     /* 17 */
    j _interrupt_handler     /* 18 */
    j _interrupt_handler     /* 19 */
    j _interrupt_handler     /* 20 */
    j _interrupt_handler     /* 21 */
    j _interrupt_handler     /* 22 */
    j _interrupt_handler     /* 23 */
    j _interrupt_handler     /* 24 */
    j _interrupt_handler     /* 25 */
    j _interrupt_handler     /* 26 */
    j _interrupt_handler     /* 27 */
    j _interrupt_handler     /* 28 */
    j _interrupt_handler     /* 29 */
    j _interrupt_handler     /* 30 */
    j _interrupt_handler     /* 31 */
    .option pop

/* ---- Exception handler ---- */
    .align 2
_exception_handler:
    csrr a0, mcause
    call trap_handler_swift
    mret

/* ---- Interrupt handler ---- */
    .align 2
_interrupt_handler:
    /* Save caller-saved registers (16 regs = 64 bytes) */
    addi sp, sp, -64
    sw   ra,  0(sp)
    sw   t0,  4(sp)
    sw   t1,  8(sp)
    sw   t2, 12(sp)
    sw   a0, 16(sp)
    sw   a1, 20(sp)
    sw   a2, 24(sp)
    sw   a3, 28(sp)
    sw   a4, 32(sp)
    sw   a5, 36(sp)
    sw   a6, 40(sp)
    sw   a7, 44(sp)
    sw   t3, 48(sp)
    sw   t4, 52(sp)
    sw   t5, 56(sp)
    sw   t6, 60(sp)

    /* Pass mcause as first argument to Swift handler */
    csrr a0, mcause
    call trap_handler_swift

    /* Restore caller-saved registers */
    lw   ra,  0(sp)
    lw   t0,  4(sp)
    lw   t1,  8(sp)
    lw   t2, 12(sp)
    lw   a0, 16(sp)
    lw   a1, 20(sp)
    lw   a2, 24(sp)
    lw   a3, 28(sp)
    lw   a4, 32(sp)
    lw   a5, 36(sp)
    lw   a6, 40(sp)
    lw   a7, 44(sp)
    lw   t3, 48(sp)
    lw   t4, 52(sp)
    lw   t5, 56(sp)
    lw   t6, 60(sp)
    addi sp, sp, 64

    mret

/* ---- CSR accessor functions (each 2 instructions) ---- */

    .text

    .global csr_read_mstatus
    .align 2
csr_read_mstatus:
    csrr a0, mstatus
    ret

    .global csr_write_mstatus
    .align 2
csr_write_mstatus:
    csrw mstatus, a0
    ret

    .global csr_write_mtvec
    .align 2
csr_write_mtvec:
    csrw mtvec, a0
    ret

    .global csr_read_mie
    .align 2
csr_read_mie:
    csrr a0, mie
    ret

    .global csr_write_mie
    .align 2
csr_write_mie:
    csrw mie, a0
    ret

    .global csr_fence
    .align 2
csr_fence:
    fence
    ret

/* ---- NOP delay loop (a0 = iteration count) ---- */
    .global nop_delay
    .align 2
nop_delay:
1:  nop
    addi a0, a0, -1
    bnez a0, 1b
    ret
