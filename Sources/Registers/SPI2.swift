// Generated from esp32c3.svd — do not edit.

/// SPI (Serial Peripheral Interface) Controller 2
public struct SPI2 {
    @usableFromInline let _base: UInt

    @inline(__always)
    public init(unsafeAddress: UInt) {
        self._base = unsafeAddress
    }

    /// Command control register
    public var cmd: Register<CMD> {
        @inline(__always) get {
            Register(unsafeAddress: _base)
        }
    }

    /// Address value register
    public var addr: Register<ADDR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x4)
        }
    }

    /// SPI control register
    public var ctrl: Register<CTRL> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x8)
        }
    }

    /// SPI clock control register
    public var clock: Register<CLOCK> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc)
        }
    }

    /// SPI USER control register
    public var user: Register<USER> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x10)
        }
    }

    /// SPI USER control register 1
    public var user1: Register<USER1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x14)
        }
    }

    /// SPI USER control register 2
    public var user2: Register<USER2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x18)
        }
    }

    /// SPI data bit length control register
    public var ms_dlen: Register<MS_DLEN> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x1c)
        }
    }

    /// SPI misc register
    public var misc: Register<MISC> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x20)
        }
    }

    /// SPI input delay mode configuration
    public var din_mode: Register<DIN_MODE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x24)
        }
    }

    /// SPI input delay number configuration
    public var din_num: Register<DIN_NUM> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x28)
        }
    }

    /// SPI output delay mode configuration
    public var dout_mode: Register<DOUT_MODE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x2c)
        }
    }

    /// SPI DMA control register
    public var dma_conf: Register<DMA_CONF> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x30)
        }
    }

    /// SPI DMA interrupt enable register
    public var dma_int_ena: Register<DMA_INT_ENA> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x34)
        }
    }

    /// SPI DMA interrupt clear register
    public var dma_int_clr: Register<DMA_INT_CLR> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x38)
        }
    }

    /// SPI DMA interrupt raw register
    public var dma_int_raw: Register<DMA_INT_RAW> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x3c)
        }
    }

    /// SPI DMA interrupt status register
    public var dma_int_st: Register<DMA_INT_ST> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x40)
        }
    }

    /// SPI CPU-controlled buffer0
    public var w0: Register<W0> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x98)
        }
    }

    /// SPI CPU-controlled buffer1
    public var w1: Register<W1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0x9c)
        }
    }

    /// SPI CPU-controlled buffer2
    public var w2: Register<W2> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xa0)
        }
    }

    /// SPI CPU-controlled buffer3
    public var w3: Register<W3> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xa4)
        }
    }

    /// SPI CPU-controlled buffer4
    public var w4: Register<W4> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xa8)
        }
    }

    /// SPI CPU-controlled buffer5
    public var w5: Register<W5> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xac)
        }
    }

    /// SPI CPU-controlled buffer6
    public var w6: Register<W6> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xb0)
        }
    }

    /// SPI CPU-controlled buffer7
    public var w7: Register<W7> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xb4)
        }
    }

    /// SPI CPU-controlled buffer8
    public var w8: Register<W8> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xb8)
        }
    }

    /// SPI CPU-controlled buffer9
    public var w9: Register<W9> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xbc)
        }
    }

    /// SPI CPU-controlled buffer10
    public var w10: Register<W10> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc0)
        }
    }

    /// SPI CPU-controlled buffer11
    public var w11: Register<W11> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc4)
        }
    }

    /// SPI CPU-controlled buffer12
    public var w12: Register<W12> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xc8)
        }
    }

    /// SPI CPU-controlled buffer13
    public var w13: Register<W13> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xcc)
        }
    }

    /// SPI CPU-controlled buffer14
    public var w14: Register<W14> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xd0)
        }
    }

    /// SPI CPU-controlled buffer15
    public var w15: Register<W15> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xd4)
        }
    }

    /// SPI slave control register
    public var slave: Register<SLAVE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xe0)
        }
    }

    /// SPI slave control register 1
    public var slave1: Register<SLAVE1> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xe4)
        }
    }

    /// SPI module clock and register clock control
    public var clk_gate: Register<CLK_GATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xe8)
        }
    }

    /// Version control
    public var date: Register<DATE> {
        @inline(__always) get {
            Register(unsafeAddress: _base &+ 0xf0)
        }
    }

    // Phantom types
    public struct CMD {}
    public struct ADDR {}
    public struct CTRL {}
    public struct CLOCK {}
    public struct USER {}
    public struct USER1 {}
    public struct USER2 {}
    public struct MS_DLEN {}
    public struct MISC {}
    public struct DIN_MODE {}
    public struct DIN_NUM {}
    public struct DOUT_MODE {}
    public struct DMA_CONF {}
    public struct DMA_INT_ENA {}
    public struct DMA_INT_CLR {}
    public struct DMA_INT_RAW {}
    public struct DMA_INT_ST {}
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
    public struct SLAVE {}
    public struct SLAVE1 {}
    public struct CLK_GATE {}
    public struct DATE {}
}
