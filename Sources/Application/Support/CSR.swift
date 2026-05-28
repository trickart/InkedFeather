import TrapHandler

enum CSR {
    @inline(__always)
    static func setTrapVector(_ address: UInt32) {
        // Vectored mode: MODE bits [1:0] = 01 (required by ESP32-C3 PLIC)
        csr_write_mtvec((address & ~UInt32(0x3)) | 1)
    }
}
