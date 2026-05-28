// generate-registers.swift — Generate Swift register definitions from ESP32-C3 SVD.
// Usage: swift Tools/generate-registers.swift <svd-file> <output-dir> [--peripherals NAME1,NAME2,...]

import Foundation

// MARK: - SVD Data Model

struct SVDField {
    let name: String
    let description: String
    let bitOffset: Int
    let bitWidth: Int
    let access: String // read-write, read-only, write-only
}

struct SVDRegister {
    let name: String        // e.g. "PIN%s", "OUT", "FIFO"
    let description: String
    let addressOffset: UInt32
    let dim: Int?           // array count
    let dimIncrement: UInt32?
    let fields: [SVDField]
}

struct SVDPeripheral {
    let name: String
    let description: String
    let baseAddress: UInt32
    let derivedFrom: String?
    let registers: [SVDRegister]
}

// MARK: - SVD Parser

class SVDParser: NSObject, XMLParserDelegate {
    var peripherals: [SVDPeripheral] = []

    // Parser state
    private var currentElement = ""
    private var textBuffer = ""

    // Peripheral state
    private var pName = ""
    private var pDesc = ""
    private var pBase: UInt32 = 0
    private var pDerivedFrom: String?
    private var pRegisters: [SVDRegister] = []
    private var inPeripheral = false

    // Register state
    private var rName = ""
    private var rDesc = ""
    private var rOffset: UInt32 = 0
    private var rDim: Int?
    private var rDimIncrement: UInt32?
    private var rFields: [SVDField] = []
    private var inRegister = false

    // Field state
    private var fName = ""
    private var fDesc = ""
    private var fBitOffset = 0
    private var fBitWidth = 0
    private var fAccess = "read-write"
    private var inField = false

    // Depth tracking to distinguish nested elements
    private var elementStack: [String] = []

    func parse(url: URL) -> [SVDPeripheral] {
        guard let parser = XMLParser(contentsOf: url) else {
            fatalError("Cannot open SVD file: \(url.path)")
        }
        parser.delegate = self
        parser.parse()
        return peripherals
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName: String?,
                attributes: [String: String]) {
        elementStack.append(elementName)
        textBuffer = ""

        switch elementName {
        case "peripheral":
            inPeripheral = true
            pName = ""
            pDesc = ""
            pBase = 0
            pDerivedFrom = attributes["derivedFrom"]
            pRegisters = []
        case "register" where inPeripheral:
            inRegister = true
            rName = ""
            rDesc = ""
            rOffset = 0
            rDim = nil
            rDimIncrement = nil
            rFields = []
        case "field" where inRegister:
            inField = true
            fName = ""
            fDesc = ""
            fBitOffset = 0
            fBitWidth = 0
            fAccess = "read-write"
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        textBuffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName: String?) {
        let text = textBuffer.trimmingCharacters(in: .whitespacesAndNewlines)

        if inField {
            switch elementName {
            case "name": fName = text
            case "description": fDesc = text
            case "bitOffset": fBitOffset = Int(text) ?? 0
            case "bitWidth": fBitWidth = Int(text) ?? 0
            case "access": fAccess = text
            case "field":
                rFields.append(SVDField(name: fName, description: fDesc,
                                        bitOffset: fBitOffset, bitWidth: fBitWidth,
                                        access: fAccess))
                inField = false
            default: break
            }
        } else if inRegister {
            switch elementName {
            case "name": rName = text
            case "description": rDesc = text
            case "addressOffset": rOffset = parseHex(text)
            case "dim": rDim = Int(text)
            case "dimIncrement": rDimIncrement = parseHex(text)
            case "register":
                pRegisters.append(SVDRegister(name: rName, description: rDesc,
                                              addressOffset: rOffset,
                                              dim: rDim, dimIncrement: rDimIncrement,
                                              fields: rFields))
                inRegister = false
            default: break
            }
        } else if inPeripheral {
            switch elementName {
            case "name":
                // Only set pName if we're directly inside <peripheral>, not nested
                // Stack: device > peripherals > peripheral > name (count=4)
                if elementStack.count == 4 {
                    pName = text
                }
            case "description":
                if elementStack.count == 4 {
                    pDesc = text
                }
            case "baseAddress": pBase = parseHex(text)
            case "peripheral":
                peripherals.append(SVDPeripheral(name: pName, description: pDesc,
                                                 baseAddress: pBase,
                                                 derivedFrom: pDerivedFrom,
                                                 registers: pRegisters))
                inPeripheral = false
            default: break
            }
        }

        elementStack.removeLast()
    }

    private func parseHex(_ s: String) -> UInt32 {
        if s.hasPrefix("0x") || s.hasPrefix("0X") {
            return UInt32(s.dropFirst(2), radix: 16) ?? 0
        }
        return UInt32(s) ?? 0
    }
}

// MARK: - Swift Code Generator

/// Swift keywords that need backticks when used as identifiers.
let swiftKeywords: Set<String> = [
    "in", "class", "struct", "enum", "protocol", "func", "var", "let",
    "if", "else", "for", "while", "do", "switch", "case", "default", "break",
    "continue", "return", "throw", "try", "catch", "import", "as", "is",
    "true", "false", "nil", "self", "super", "init", "deinit", "repeat",
    "guard", "where", "operator", "type", "associatedtype", "typealias",
]

func escapeKeyword(_ name: String) -> String {
    swiftKeywords.contains(name) ? "`\(name)`" : name
}

/// Convert SVD register name to Swift property name.
/// e.g. "FUNC%s_IN_SEL_CFG" → "func_in_sel_cfg", "PIN%s" → "pin"
func propertyName(from svdName: String) -> String {
    let cleaned = svdName.replacingOccurrences(of: "%s", with: "")
    // Remove leading/trailing underscores from %s removal
    let trimmed = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    return escapeKeyword(trimmed.lowercased())
}

/// Convert SVD register name to Swift type name (phantom type).
/// e.g. "FUNC%s_IN_SEL_CFG" → "FUNC_IN_SEL_CFG", "PIN%s" → "PIN"
func typeName(from svdName: String) -> String {
    let cleaned = svdName.replacingOccurrences(of: "%s", with: "")
    let trimmed = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    // Ensure first char is uppercase
    return trimmed.isEmpty ? "UNKNOWN" : trimmed
}

func generatePeripheralFile(_ peripheral: SVDPeripheral) -> String {
    var out = ""
    out += "// Generated from esp32c3.svd — do not edit.\n\n"

    // Struct definition
    out += "/// \(peripheral.description)\n"
    out += "public struct \(peripheral.name) {\n"
    out += "    @usableFromInline let _base: UInt\n\n"
    out += "    @inline(__always)\n"
    out += "    public init(unsafeAddress: UInt) {\n"
    out += "        self._base = unsafeAddress\n"
    out += "    }\n"

    // Collect type names for phantom type declarations
    var phantomTypes: [String] = []

    for reg in peripheral.registers {
        let tName = typeName(from: reg.name)
        let pName = propertyName(from: reg.name)

        out += "\n    /// \(reg.description)\n"

        let addr = "_base\(offsetExpr(reg.addressOffset))"

        if let _ = reg.dim, let inc = reg.dimIncrement {
            // RegisterArray
            out += "    public var \(pName): RegisterArray<\(tName)> {\n"
            out += "        @inline(__always) get {\n"
            out += "            RegisterArray(unsafeAddress: \(addr), stride: \(inc))\n"
            out += "        }\n"
            out += "    }\n"
        } else {
            // Single Register
            out += "    public var \(pName): Register<\(tName)> {\n"
            out += "        @inline(__always) get {\n"
            out += "            Register(unsafeAddress: \(addr))\n"
            out += "        }\n"
            out += "    }\n"
        }

        if !phantomTypes.contains(tName) {
            phantomTypes.append(tName)
        }
    }

    // Phantom type declarations
    if !phantomTypes.isEmpty {
        out += "\n    // Phantom types\n"
        for t in phantomTypes {
            out += "    public struct \(t) {}\n"
        }
    }

    out += "}\n"
    return out
}

func offsetExpr(_ offset: UInt32) -> String {
    if offset == 0 {
        return ""
    }
    return " &+ 0x\(String(offset, radix: 16))"
}

func generateDeviceFile(_ peripherals: [SVDPeripheral]) -> String {
    var out = ""
    out += "// Generated from esp32c3.svd — do not edit.\n\n"

    for p in peripherals.sorted(by: { $0.name < $1.name }) {
        if let derived = p.derivedFrom {
            out += "/// \(p.description)\n"
            out += "public typealias \(p.name) = \(derived)\n\n"
        }
    }

    for p in peripherals.sorted(by: { $0.name < $1.name }) {
        let varName = p.name.lowercased()
        out += "/// \(p.description)\n"
        out += "public nonisolated(unsafe) let \(escapeKeyword(varName)) = \(p.name)(unsafeAddress: 0x\(String(p.baseAddress, radix: 16)))\n\n"
    }

    return out
}

// MARK: - Main

guard CommandLine.arguments.count >= 3 else {
    print("Usage: swift Tools/generate-registers.swift <svd-file> <output-dir> [--peripherals NAME1,NAME2,...]")
    exit(1)
}

let svdPath = CommandLine.arguments[1]
let outputDir = CommandLine.arguments[2]

// Parse optional peripheral filter
var filterSet: Set<String>?
for i in 3..<CommandLine.arguments.count {
    if CommandLine.arguments[i] == "--peripherals" && i + 1 < CommandLine.arguments.count {
        let names = CommandLine.arguments[i + 1].split(separator: ",").map(String.init)
        filterSet = Set(names)
    }
}

let svdURL = URL(fileURLWithPath: svdPath)
let parser = SVDParser()
let allPeripherals = parser.parse(url: svdURL)

// Filter peripherals
let peripherals: [SVDPeripheral]
if let filter = filterSet {
    peripherals = allPeripherals.filter { filter.contains($0.name) }
} else {
    peripherals = allPeripherals
}

print("Found \(allPeripherals.count) peripherals, generating \(peripherals.count)")

let outputURL = URL(fileURLWithPath: outputDir)
let fm = FileManager.default
try! fm.createDirectory(at: outputURL, withIntermediateDirectories: true)

// Generate peripheral files
for p in peripherals {
    if p.derivedFrom != nil {
        // Skip derived peripherals — handled as typealias in Device.swift
        continue
    }
    if p.registers.isEmpty {
        print("  Skipping \(p.name) (no registers)")
        continue
    }
    let content = generatePeripheralFile(p)
    let fileURL = outputURL.appendingPathComponent("\(p.name).swift")
    try! content.write(to: fileURL, atomically: true, encoding: .utf8)
    print("  Generated \(p.name).swift (\(p.registers.count) registers)")
}

// Generate Device.swift
let deviceContent = generateDeviceFile(peripherals)
let deviceURL = outputURL.appendingPathComponent("Device.swift")
try! deviceContent.write(to: deviceURL, atomically: true, encoding: .utf8)
print("  Generated Device.swift")
