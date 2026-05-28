// RegisterAccess.swift — Lightweight MMIO register access types.
// Replaces swift-mmio with zero-cost abstractions backed by _Volatile.

import _Volatile

public struct RawStorage {
    public var storage: UInt32

    @inline(__always)
    public init(_ value: UInt32) {
        self.storage = value
    }
}

public struct RegisterValue {
    public var raw: RawStorage

    @inline(__always)
    public init(_ value: UInt32) {
        self.raw = RawStorage(value)
    }
}

public struct Register<T> {
    @usableFromInline
    let _address: UInt

    @inline(__always)
    public init(unsafeAddress: UInt) {
        self._address = unsafeAddress
    }

    @inline(__always)
    public func read() -> RegisterValue {
        RegisterValue(VolatileMappedRegister<UInt32>(unsafeBitPattern: _address).load())
    }

    @inline(__always)
    public func write(_ body: (inout RegisterValue) -> Void) {
        var val = RegisterValue(0)
        body(&val)
        VolatileMappedRegister<UInt32>(unsafeBitPattern: _address).store(val.raw.storage)
    }

    @inline(__always)
    public func modify(_ body: (inout RegisterValue) -> Void) {
        var val = read()
        body(&val)
        VolatileMappedRegister<UInt32>(unsafeBitPattern: _address).store(val.raw.storage)
    }
}

public struct RegisterArray<T> {
    @usableFromInline
    let _base: UInt
    @usableFromInline
    let _stride: UInt

    @inline(__always)
    public init(unsafeAddress: UInt, stride: UInt) {
        self._base = unsafeAddress
        self._stride = stride
    }

    @inline(__always)
    public subscript(index: Int) -> Register<T> {
        Register<T>(unsafeAddress: _base &+ UInt(index) &* _stride)
    }
}
