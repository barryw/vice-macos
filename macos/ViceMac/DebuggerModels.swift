import Foundation
import MacVICEKit

struct DebuggerCPU: Identifiable, Hashable {
    let id: UInt32
    let title: String

    static let unknown = DebuggerCPU(id: UInt32.max, title: "Unknown")

    init(id: UInt32) {
        self.id = id
        switch id {
        case 0:
            title = "6502"
        case 1:
            title = "WDC 65C02"
        case 2:
            title = "R65C02"
        case 3:
            title = "65SC02"
        case 4:
            title = "65816"
        case 5:
            title = "Z80"
        case 6:
            title = "6502DTV"
        case 7:
            title = "6809"
        default:
            title = "CPU \(id)"
        }
    }

    private init(id: UInt32, title: String) {
        self.id = id
        self.title = title
    }
}

struct DebuggerSnapshot {
    let memorySpace: UInt32
    let cpu: DebuggerCPU
    let bank: Int32
    let cycle: UInt64
    let programCounter: UInt16
    let supportedCPUs: [DebuggerCPU]
    let registers: [DebuggerRegister]

    init(_ snapshot: MacVICEDebuggerSnapshot) {
        memorySpace = snapshot.memorySpace.rawValue
        cpu = DebuggerCPU(id: snapshot.cpuType)
        bank = snapshot.bank
        cycle = snapshot.cycle
        programCounter = UInt16(snapshot.programCounter & 0xffff)
        supportedCPUs = snapshot.supportedCPUTypes.map(DebuggerCPU.init)
        registers = snapshot.registers.map(DebuggerRegister.init)
    }

    var pcText: String { DebuggerFormatter.hex16(programCounter) }
    var cycleText: String { "\(cycle)" }
    var bankText: String { bank < 0 ? "Current" : "\(bank)" }
    var memorySpaceText: String { DebuggerFormatter.memorySpaceTitle(memorySpace) }

}

struct DebuggerRegister: Identifiable {
    let id: UInt32
    let name: String
    let bitWidth: UInt32
    let flags: UInt32
    let value: UInt32

    init(_ register: MacVICERegister) {
        id = register.id
        name = register.name
        bitWidth = register.bitWidth
        flags = register.flags
        value = register.value
    }

    var hexDigits: Int {
        max(2, Int((bitWidth + 3) / 4))
    }

    var maxValue: UInt32 {
        bitWidth >= 32 ? UInt32.max : ((1 << bitWidth) - 1)
    }

    var valueText: String {
        DebuggerFormatter.hex(value, digits: hexDigits)
    }

    var isFlags: Bool {
        flags & 0x01 != 0 || name == "FL" || name == "SR"
    }

    var flagsText: String {
        let labels = ["N", "V", "-", "B", "D", "I", "Z", "C"]
        return labels.enumerated().map { index, label in
            let mask = UInt32(1 << (7 - index))
            return (value & mask) == 0 ? label.lowercased() : label
        }.joined()
    }
}

struct DebuggerDisassemblyLine: Identifiable {
    let id: UInt16
    let address: UInt16
    let size: UInt32
    let bytes: [UInt8]
    let text: String
    let isProgramCounter: Bool
    let hasBreakpoint: Bool

    init(_ line: MacVICEDisassemblyLine,
         programCounter: UInt16?,
         activeBreakpoints: Set<UInt16>) {
        address = UInt16(line.address & 0xffff)
        id = address
        size = line.size
        bytes = line.bytes
        text = line.text
        isProgramCounter = programCounter == address
        hasBreakpoint = activeBreakpoints.contains(address)
    }

    var addressText: String { DebuggerFormatter.hex16(address) }
    var bytesText: String { bytes.map(DebuggerFormatter.hex8).joined(separator: " ") }
}

struct DebuggerCheckpoint: Identifiable {
    let id: UInt32
    let memorySpace: UInt32
    let startAddress: UInt16
    let endAddress: UInt16
    let operations: DebuggerOperations
    let enabled: Bool
    let stops: Bool
    let temporary: Bool
    let hitCount: UInt32
    let ignoreCount: UInt32

    init(_ checkpoint: MacVICECheckpoint) {
        id = checkpoint.id
        memorySpace = checkpoint.memorySpace.rawValue
        startAddress = UInt16(checkpoint.startAddress & 0xffff)
        endAddress = UInt16(checkpoint.endAddress & 0xffff)
        operations = DebuggerOperations(rawValue: checkpoint.operations)
        enabled = checkpoint.isEnabled
        stops = checkpoint.stops
        temporary = checkpoint.isTemporary
        hitCount = checkpoint.hitCount
        ignoreCount = checkpoint.ignoreCount
    }

    var rangeText: String {
        startAddress == endAddress
            ? DebuggerFormatter.hex16(startAddress)
            : "\(DebuggerFormatter.hex16(startAddress))-\(DebuggerFormatter.hex16(endAddress))"
    }

    var addresses: [UInt16] {
        guard startAddress <= endAddress else {
            return []
        }
        return (UInt32(startAddress)...UInt32(endAddress)).map { UInt16($0) }
    }

    var memorySpaceText: String { DebuggerFormatter.memorySpaceTitle(memorySpace) }

    var detailText: String {
        var components = [memorySpaceText, stops ? "Stops" : "Logs"]
        if temporary {
            components.append("Temporary")
        }
        if ignoreCount > 0 {
            components.append("Ignore \(ignoreCount)")
        }
        return components.joined(separator: " - ")
    }
}

struct DebuggerMemoryCell: Identifiable {
    let id: UInt16
    let address: UInt16
    var value: UInt8
    var text: String

    init(address: UInt16, value: UInt8) {
        id = address
        self.address = address
        self.value = value
        text = DebuggerFormatter.hex8(value)
    }
}

struct DebuggerOperations: OptionSet, Hashable {
    let rawValue: UInt32

    static let read = DebuggerOperations(rawValue: 0x01)
    static let write = DebuggerOperations(rawValue: 0x02)
    static let execute = DebuggerOperations(rawValue: 0x04)
}

enum DebuggerFormatter {
    static func hex(_ value: UInt32, digits: Int) -> String {
        String(format: "%0\(digits)X", value)
    }

    static func hex16(_ value: UInt16) -> String {
        hex(UInt32(value), digits: 4)
    }

    static func hex8(_ value: UInt8) -> String {
        hex(UInt32(value), digits: 2)
    }

    static func parseAddress(_ text: String) -> UInt16? {
        guard let value = parseHex(text), value <= UInt16.max else {
            return nil
        }
        return UInt16(value)
    }

    static func parseByte(_ text: String) -> UInt8? {
        guard let value = parseHex(text), value <= UInt8.max else {
            return nil
        }
        return UInt8(value)
    }

    static func memorySpaceTitle(_ rawValue: UInt32) -> String {
        switch rawValue {
        case 1:
            return "Computer"
        case 2:
            return "Drive 8"
        case 3:
            return "Drive 9"
        case 4:
            return "Drive 10"
        case 5:
            return "Drive 11"
        default:
            return "Memory \(rawValue)"
        }
    }

    static func parseHex(_ text: String) -> UInt32? {
        var normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        normalized = normalized.replacingOccurrences(of: "$", with: "")
        if normalized.lowercased().hasPrefix("0x") {
            normalized.removeFirst(2)
        }
        normalized = normalized.replacingOccurrences(of: "_", with: "")
        guard !normalized.isEmpty else {
            return nil
        }
        return UInt32(normalized, radix: 16)
    }

    static func cString<T>(_ storage: T) -> String {
        withUnsafeBytes(of: storage) { rawBuffer in
            let bytes = rawBuffer.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }
    }

    static func bytes<T>(_ storage: T, count: Int) -> [UInt8] {
        withUnsafeBytes(of: storage) { rawBuffer in
            Array(rawBuffer.prefix(max(0, min(count, rawBuffer.count))))
        }
    }
}
