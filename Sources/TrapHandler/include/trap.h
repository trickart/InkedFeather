#ifndef TRAP_H
#define TRAP_H

#include <stdint.h>

/* Vector table entry point (defined in trap.S, address used for mtvec) */
extern void _vector_table(void);

/* CSR accessor functions */
uint32_t csr_read_mstatus(void);
void     csr_write_mstatus(uint32_t value);
void     csr_write_mtvec(uint32_t value);
uint32_t csr_read_mie(void);
void     csr_write_mie(uint32_t value);
void     csr_fence(void);
void     nop_delay(uint32_t count);

#endif /* TRAP_H */
