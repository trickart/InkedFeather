import _Volatile
import TrapHandler

enum InterruptController {
    // ESP32-C3 PLIC register addresses
    private static let plicBase: UInt32       = 0x200_01000
    private static let mxintEnable: UInt32    = plicBase + 0x000
    private static let mxintType: UInt32      = plicBase + 0x004
    private static let mxintClear: UInt32     = plicBase + 0x008
    private static let mxintPriBase: UInt32   = plicBase + 0x010
    private static let mxintThresh: UInt32    = plicBase + 0x090

    // ESP32-C3 Interrupt Matrix base address
    private static let intMatrixBase: UInt32  = 0x600C_2000

    /// Route a peripheral interrupt source to a CPU interrupt line.
    static func mapSource(_ sourceRegOffset: UInt32, toCpuInterrupt cpuInt: UInt32) {
        regStore(intMatrixBase + sourceRegOffset, cpuInt & 0x1F)
    }

    static func enableInterrupt(_ n: UInt32) {
        let current = regLoad(mxintEnable)
        regStore(mxintEnable, current | (1 << n))
    }

    static func setType(_ n: UInt32, edge: Bool) {
        let current = regLoad(mxintType)
        if edge {
            regStore(mxintType, current | (1 << n))
        } else {
            regStore(mxintType, current & ~(1 << n))
        }
    }

    static func setPriority(_ n: UInt32, priority: UInt32) {
        regStore(mxintPriBase + n * 4, priority & 0xF)
    }

    static func setThreshold(_ threshold: UInt32) {
        regStore(mxintThresh, threshold & 0xF)
    }

    static func clearPending(_ n: UInt32) {
        regStore(mxintClear, 1 << n)
    }

    static func enableCpuInterrupt(_ n: UInt32) {
        let mie = csr_read_mie()
        csr_write_mie(mie | (1 << n))
    }

    /// Configure a complete PLIC external interrupt path.
    static func configureInterrupt(
        cpuInterrupt: UInt32,
        sourceOffset: UInt32,
        priority: UInt32 = 1,
        edge: Bool = false
    ) {
        mapSource(sourceOffset, toCpuInterrupt: cpuInterrupt)
        setType(cpuInterrupt, edge: edge)
        setPriority(cpuInterrupt, priority: priority)
        setThreshold(0)
        clearPending(cpuInterrupt)
        enableInterrupt(cpuInterrupt)
        enableCpuInterrupt(cpuInterrupt)
        csr_fence()
    }
}
