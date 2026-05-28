// Generated from esp32c3.svd — do not edit.

/// Input/Output Multiplexer
public struct IO_MUX {
    @usableFromInline let _base: UInt

    @inline(__always)
    public init(unsafeAddress: UInt) {
        self._base = unsafeAddress
    }

    /// Clock Output Configuration Register
    public var pin_ctrl: Register<PIN_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base)
        }
    }

    /// IO MUX Configure Register for pad XTAL_32K_P
    public var gpio: RegisterArray<GPIO> {
        @inline(__always) get {
            RegisterArray(unsafeAddress: _base &+ 0x4, stride: 4)
        }
    }

    /// IO MUX Version Control Register
    public var date: Register<DATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xfc)
        }
    }

    // Phantom types
    public struct PIN_CTRL {}
    public struct GPIO {}
    public struct DATE {}
}
