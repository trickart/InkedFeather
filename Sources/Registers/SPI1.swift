// Generated from esp32c3.svd — do not edit.

/// SPI (Serial Peripheral Interface) Controller 1
public struct SPI1 {
    @usableFromInline let _base: UInt

    @inline(__always)
    public init(unsafeAddress: UInt) {
        self._base = unsafeAddress
    }

    /// SPI1 memory command register
    public var cmd: Register<CMD> {
        @inline(__always) get {
            Register(unsafeAddress: _base)
        }
    }

    /// SPI1 address register
    public var addr: Register<ADDR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4)
        }
    }

    /// SPI1 control register.
    public var ctrl: Register<CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8)
        }
    }

    /// SPI1 control1 register.
    public var ctrl1: Register<CTRL1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc)
        }
    }

    /// SPI1 control2 register.
    public var ctrl2: Register<CTRL2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x10)
        }
    }

    /// SPI1 clock division control register.
    public var clock: Register<CLOCK> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x14)
        }
    }

    /// SPI1 user register.
    public var user: Register<USER> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x18)
        }
    }

    /// SPI1 user1 register.
    public var user1: Register<USER1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x1c)
        }
    }

    /// SPI1 user2 register.
    public var user2: Register<USER2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x20)
        }
    }

    /// SPI1 send data bit length control register.
    public var mosi_dlen: Register<MOSI_DLEN> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x24)
        }
    }

    /// SPI1 receive data bit length control register.
    public var miso_dlen: Register<MISO_DLEN> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x28)
        }
    }

    /// SPI1 status register.
    public var rd_status: Register<RD_STATUS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x2c)
        }
    }

    /// SPI1 misc register
    public var misc: Register<MISC> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x34)
        }
    }

    /// SPI1 TX CRC data register.
    public var tx_crc: Register<TX_CRC> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x38)
        }
    }

    /// SPI1 bit mode control register.
    public var cache_fctrl: Register<CACHE_FCTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x3c)
        }
    }

    /// SPI1 memory data buffer0
    public var w0: Register<W0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x58)
        }
    }

    /// SPI1 memory data buffer1
    public var w1: Register<W1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x5c)
        }
    }

    /// SPI1 memory data buffer2
    public var w2: Register<W2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x60)
        }
    }

    /// SPI1 memory data buffer3
    public var w3: Register<W3> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x64)
        }
    }

    /// SPI1 memory data buffer4
    public var w4: Register<W4> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x68)
        }
    }

    /// SPI1 memory data buffer5
    public var w5: Register<W5> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x6c)
        }
    }

    /// SPI1 memory data buffer6
    public var w6: Register<W6> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x70)
        }
    }

    /// SPI1 memory data buffer7
    public var w7: Register<W7> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x74)
        }
    }

    /// SPI1 memory data buffer8
    public var w8: Register<W8> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x78)
        }
    }

    /// SPI1 memory data buffer9
    public var w9: Register<W9> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x7c)
        }
    }

    /// SPI1 memory data buffer10
    public var w10: Register<W10> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x80)
        }
    }

    /// SPI1 memory data buffer11
    public var w11: Register<W11> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x84)
        }
    }

    /// SPI1 memory data buffer12
    public var w12: Register<W12> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x88)
        }
    }

    /// SPI1 memory data buffer13
    public var w13: Register<W13> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8c)
        }
    }

    /// SPI1 memory data buffer14
    public var w14: Register<W14> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x90)
        }
    }

    /// SPI1 memory data buffer15
    public var w15: Register<W15> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x94)
        }
    }

    /// SPI1 wait idle control register
    public var flash_waiti_ctrl: Register<FLASH_WAITI_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x98)
        }
    }

    /// SPI1 flash suspend control register
    public var flash_sus_ctrl: Register<FLASH_SUS_CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x9c)
        }
    }

    /// SPI1 flash suspend command register
    public var flash_sus_cmd: Register<FLASH_SUS_CMD> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xa0)
        }
    }

    /// SPI1 flash suspend status register
    public var sus_status: Register<SUS_STATUS> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xa4)
        }
    }

    /// SPI1 timing control register
    public var timing_cali: Register<TIMING_CALI> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xa8)
        }
    }

    /// SPI1 interrupt enable register
    public var int_ena: Register<INT_ENA> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc0)
        }
    }

    /// SPI1 interrupt clear register
    public var int_clr: Register<INT_CLR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc4)
        }
    }

    /// SPI1 interrupt raw register
    public var int_raw: Register<INT_RAW> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc8)
        }
    }

    /// SPI1 interrupt status register
    public var int_st: Register<INT_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xcc)
        }
    }

    /// SPI1 clk_gate register
    public var clock_gate: Register<CLOCK_GATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xdc)
        }
    }

    /// Version control register
    public var date: Register<DATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x3fc)
        }
    }

    // Phantom types
    public struct CMD {}
    public struct ADDR {}
    public struct CTRL {}
    public struct CTRL1 {}
    public struct CTRL2 {}
    public struct CLOCK {}
    public struct USER {}
    public struct USER1 {}
    public struct USER2 {}
    public struct MOSI_DLEN {}
    public struct MISO_DLEN {}
    public struct RD_STATUS {}
    public struct MISC {}
    public struct TX_CRC {}
    public struct CACHE_FCTRL {}
    public struct W0 {}
    public struct W1 {}
    public struct W2 {}
    public struct W3 {}
    public struct W4 {}
    public struct W5 {}
    public struct W6 {}
    public struct W7 {}
    public struct W8 {}
    public struct W9 {}
    public struct W10 {}
    public struct W11 {}
    public struct W12 {}
    public struct W13 {}
    public struct W14 {}
    public struct W15 {}
    public struct FLASH_WAITI_CTRL {}
    public struct FLASH_SUS_CTRL {}
    public struct FLASH_SUS_CMD {}
    public struct SUS_STATUS {}
    public struct TIMING_CALI {}
    public struct INT_ENA {}
    public struct INT_CLR {}
    public struct INT_RAW {}
    public struct INT_ST {}
    public struct CLOCK_GATE {}
    public struct DATE {}
}
