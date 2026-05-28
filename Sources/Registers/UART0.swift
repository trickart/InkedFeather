// Generated from esp32c3.svd — do not edit.

/// UART (Universal Asynchronous Receiver-Transmitter) Controller 0
public struct UART0 {
    @usableFromInline let _base: UInt

    @inline(__always)
    public init(unsafeAddress: UInt) {
        self._base = unsafeAddress
    }

    /// FIFO data register
    public var fifo: Register<FIFO> {
        @inline(__always) get {
            Register(unsafeAddress: _base)
        }
    }

    /// Raw interrupt status
    public var int_raw: Register<INT_RAW> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4)
        }
    }

    /// Masked interrupt status
    public var int_st: Register<INT_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8)
        }
    }

    /// Interrupt enable bits
    public var int_ena: Register<INT_ENA> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc)
        }
    }

    /// Interrupt clear bits
    public var int_clr: Register<INT_CLR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x10)
        }
    }

    /// Clock divider configuration
    public var clkdiv: Register<CLKDIV> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x14)
        }
    }

    /// Rx Filter configuration
    public var rx_filt: Register<RX_FILT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x18)
        }
    }

    /// UART status register
    public var status: Register<STATUS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x1c)
        }
    }

    /// a
    public var conf0: Register<CONF0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x20)
        }
    }

    /// Configuration register 1
    public var conf1: Register<CONF1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x24)
        }
    }

    /// Autobaud minimum low pulse duration register
    public var lowpulse: Register<LOWPULSE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x28)
        }
    }

    /// Autobaud minimum high pulse duration register
    public var highpulse: Register<HIGHPULSE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x2c)
        }
    }

    /// Autobaud edge change count register
    public var rxd_cnt: Register<RXD_CNT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x30)
        }
    }

    /// Software flow-control configuration
    public var flow_conf: Register<FLOW_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x34)
        }
    }

    /// Sleep-mode configuration
    public var sleep_conf: Register<SLEEP_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x38)
        }
    }

    /// Software flow-control character configuration
    public var swfc_conf0: Register<SWFC_CONF0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x3c)
        }
    }

    /// Software flow-control character configuration
    public var swfc_conf1: Register<SWFC_CONF1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x40)
        }
    }

    /// Tx Break character configuration
    public var txbrk_conf: Register<TXBRK_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x44)
        }
    }

    /// Frame-end idle configuration
    public var idle_conf: Register<IDLE_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x48)
        }
    }

    /// RS485 mode configuration
    public var rs485_conf: Register<RS485_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4c)
        }
    }

    /// Pre-sequence timing configuration
    public var at_cmd_precnt: Register<AT_CMD_PRECNT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x50)
        }
    }

    /// Post-sequence timing configuration
    public var at_cmd_postcnt: Register<AT_CMD_POSTCNT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x54)
        }
    }

    /// Timeout configuration
    public var at_cmd_gaptout: Register<AT_CMD_GAPTOUT> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x58)
        }
    }

    /// AT escape sequence detection configuration
    public var at_cmd_char: Register<AT_CMD_CHAR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x5c)
        }
    }

    /// UART threshold and allocation configuration
    public var mem_conf: Register<MEM_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x60)
        }
    }

    /// Tx-FIFO write and read offset address.
    public var mem_tx_status: Register<MEM_TX_STATUS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x64)
        }
    }

    /// Rx-FIFO write and read offset address.
    public var mem_rx_status: Register<MEM_RX_STATUS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x68)
        }
    }

    /// UART transmit and receive status.
    public var fsm_status: Register<FSM_STATUS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x6c)
        }
    }

    /// Autobaud high pulse register
    public var pospulse: Register<POSPULSE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x70)
        }
    }

    /// Autobaud low pulse register
    public var negpulse: Register<NEGPULSE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x74)
        }
    }

    /// UART core clock configuration
    public var clk_conf: Register<CLK_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x78)
        }
    }

    /// UART Version register
    public var date: Register<DATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x7c)
        }
    }

    /// UART ID register
    public var id: Register<ID> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x80)
        }
    }

    // Phantom types
    public struct FIFO {}
    public struct INT_RAW {}
    public struct INT_ST {}
    public struct INT_ENA {}
    public struct INT_CLR {}
    public struct CLKDIV {}
    public struct RX_FILT {}
    public struct STATUS {}
    public struct CONF0 {}
    public struct CONF1 {}
    public struct LOWPULSE {}
    public struct HIGHPULSE {}
    public struct RXD_CNT {}
    public struct FLOW_CONF {}
    public struct SLEEP_CONF {}
    public struct SWFC_CONF0 {}
    public struct SWFC_CONF1 {}
    public struct TXBRK_CONF {}
    public struct IDLE_CONF {}
    public struct RS485_CONF {}
    public struct AT_CMD_PRECNT {}
    public struct AT_CMD_POSTCNT {}
    public struct AT_CMD_GAPTOUT {}
    public struct AT_CMD_CHAR {}
    public struct MEM_CONF {}
    public struct MEM_TX_STATUS {}
    public struct MEM_RX_STATUS {}
    public struct FSM_STATUS {}
    public struct POSPULSE {}
    public struct NEGPULSE {}
    public struct CLK_CONF {}
    public struct DATE {}
    public struct ID {}
}
