import TrapHandler

@c(trap_handler_swift)
func trapHandlerSwift(_ mcause: UInt32) {
    let isInterrupt = (mcause & 0x8000_0000) != 0
    let code = mcause & 0x7FFF_FFFF

    if isInterrupt {
        switch code {
        default:
            break
        }
    } else {
        // Exception: print cause and halt
        usbPrint("TRAP!")
        usbPrintHex(mcause)
        while true {}
    }
}
