import CMacVICEEngineBridge
import Foundation

/// Address space used by VICE monitor/debugger operations.
public enum MacVICEMemorySpace: UInt32, CaseIterable, Sendable {
    /// Main computer CPU address space.
    case computer = 1
    /// Drive 8 CPU address space.
    case drive8 = 2
    /// Drive 9 CPU address space.
    case drive9 = 3
    /// Drive 10 CPU address space.
    case drive10 = 4
    /// Drive 11 CPU address space.
    case drive11 = 5
}

/// Operation mask bits for VICE monitor checkpoints.
public enum MacVICECheckpointOperation: UInt32, Sendable {
    /// Trigger when memory is read.
    case load = 1
    /// Trigger when memory is written.
    case store = 2
    /// Trigger when code executes.
    case execute = 4
}

/// CPU register value reported by the VICE monitor.
public struct MacVICERegister: Sendable, Equatable {
    /// Raw VICE register identifier.
    public let id: UInt32
    /// Human-readable register name.
    public let name: String
    /// Register width in bits.
    public let bitWidth: UInt32
    /// Current register value.
    public let value: UInt32
    /// Raw VICE register flags.
    public let flags: UInt32

    /// Creates a register value.
    public init(id: UInt32,
                name: String,
                bitWidth: UInt32,
                value: UInt32,
                flags: UInt32 = 0) {
        self.id = id
        self.name = name
        self.bitWidth = bitWidth
        self.value = value
        self.flags = flags
    }
}

/// Point-in-time debugger state for a VICE CPU.
public struct MacVICEDebuggerSnapshot: Sendable, Equatable {
    /// Memory space captured by this snapshot.
    public let memorySpace: MacVICEMemorySpace
    /// Raw VICE CPU type identifier.
    public let cpuType: UInt32
    /// Active VICE bank, or `-1` when banked memory does not apply.
    public let bank: Int32
    /// Current CPU cycle count.
    public let cycle: UInt64
    /// Current program counter.
    public let programCounter: UInt32
    /// Raw VICE CPU identifiers supported by the selected memory space.
    public let supportedCPUTypes: [UInt32]
    /// CPU registers reported by VICE.
    public let registers: [MacVICERegister]

    /// Creates a debugger snapshot.
    public init(memorySpace: MacVICEMemorySpace,
                cpuType: UInt32,
                bank: Int32,
                cycle: UInt64,
                programCounter: UInt32,
                supportedCPUTypes: [UInt32],
                registers: [MacVICERegister]) {
        self.memorySpace = memorySpace
        self.cpuType = cpuType
        self.bank = bank
        self.cycle = cycle
        self.programCounter = programCounter
        self.supportedCPUTypes = supportedCPUTypes
        self.registers = registers
    }
}

/// One line of monitor disassembly.
public struct MacVICEDisassemblyLine: Sendable, Equatable {
    /// Instruction address.
    public let address: UInt32
    /// Instruction size in bytes.
    public let size: UInt32
    /// Raw instruction bytes.
    public let bytes: [UInt8]
    /// VICE-formatted disassembly text.
    public let text: String

    /// Creates a disassembly line.
    public init(address: UInt32,
                size: UInt32,
                bytes: [UInt8],
                text: String) {
        self.address = address
        self.size = size
        self.bytes = bytes
        self.text = text
    }
}

/// VICE monitor checkpoint or breakpoint.
public struct MacVICECheckpoint: Sendable, Equatable {
    /// VICE checkpoint identifier.
    public let id: UInt32
    /// Memory space watched by the checkpoint.
    public let memorySpace: MacVICEMemorySpace
    /// Inclusive start address.
    public let startAddress: UInt32
    /// Inclusive end address.
    public let endAddress: UInt32
    /// Raw operation mask built from `MacVICECheckpointOperation` values.
    public let operations: UInt32
    /// Whether the checkpoint is currently enabled.
    public let isEnabled: Bool
    /// Whether VICE should stop when the checkpoint triggers.
    public let stops: Bool
    /// Whether VICE should remove the checkpoint after it triggers.
    public let isTemporary: Bool
    /// Number of times the checkpoint has triggered.
    public let hitCount: UInt32
    /// Number of hits VICE should ignore before stopping.
    public let ignoreCount: UInt32

    /// Creates a checkpoint value.
    public init(id: UInt32,
                memorySpace: MacVICEMemorySpace,
                startAddress: UInt32,
                endAddress: UInt32,
                operations: UInt32,
                isEnabled: Bool,
                stops: Bool,
                isTemporary: Bool,
                hitCount: UInt32,
                ignoreCount: UInt32) {
        self.id = id
        self.memorySpace = memorySpace
        self.startAddress = startAddress
        self.endAddress = endAddress
        self.operations = operations
        self.isEnabled = isEnabled
        self.stops = stops
        self.isTemporary = isTemporary
        self.hitCount = hitCount
        self.ignoreCount = ignoreCount
    }
}

/// High-level monitor/debugger API for a running `MacVICEEngineSession`.
public final class MacVICEDebugger {
    private unowned let session: MacVICEEngineSession

    init(session: MacVICEEngineSession) {
        self.session = session
    }

    /// Reads bytes from a VICE memory space.
    public func peek(memorySpace: MacVICEMemorySpace = .computer,
                     bank: Int32 = -1,
                     address: UInt32,
                     length: Int) throws -> Data {
        guard length > 0,
              length <= Int(UInt32.max) else {
            throw MacVICEError.invalidConfiguration("Memory peek length must be greater than zero.")
        }

        var bytes = [UInt8](repeating: 0, count: length)
        let didPeek = bytes.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return false
            }

            return ViceEnginePeekMemory(memorySpace.rawValue,
                                        bank,
                                        address,
                                        baseAddress,
                                        UInt32(length))
        }

        guard didPeek else {
            throw MacVICEError.engineFailure(MacVICEEngineSession.lastErrorMessage)
        }

        return Data(bytes)
    }

    /// Reads one byte from a VICE memory space.
    public func peekByte(memorySpace: MacVICEMemorySpace = .computer,
                         bank: Int32 = -1,
                         address: UInt32) throws -> UInt8 {
        guard let byte = try peek(memorySpace: memorySpace,
                                  bank: bank,
                                  address: address,
                                  length: 1).first else {
            throw MacVICEError.engineFailure("VICE returned no data for memory peek.")
        }
        return byte
    }

    /// Writes bytes into a VICE memory space.
    public func poke(memorySpace: MacVICEMemorySpace = .computer,
                     bank: Int32 = -1,
                     address: UInt32,
                     bytes: Data) throws {
        guard !bytes.isEmpty else {
            throw MacVICEError.invalidConfiguration("Memory poke data must not be empty.")
        }

        let didPoke = bytes.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.bindMemory(to: UInt8.self).baseAddress else {
                return false
            }

            return ViceEnginePokeMemory(memorySpace.rawValue,
                                        bank,
                                        address,
                                        baseAddress,
                                        UInt32(bytes.count))
        }

        guard didPoke else {
            throw MacVICEError.engineFailure(MacVICEEngineSession.lastErrorMessage)
        }
    }

    /// Writes one byte into a VICE memory space.
    public func pokeByte(_ byte: UInt8,
                         memorySpace: MacVICEMemorySpace = .computer,
                         bank: Int32 = -1,
                         address: UInt32) throws {
        try poke(memorySpace: memorySpace,
                 bank: bank,
                 address: address,
                 bytes: Data([byte]))
    }

    /// Captures current CPU state for a memory space.
    public func snapshot(memorySpace: MacVICEMemorySpace = .computer) throws -> MacVICEDebuggerSnapshot {
        var raw = ViceEngineDebuggerSnapshot()
        guard ViceEngineDebuggerCaptureSnapshot(memorySpace.rawValue, &raw),
              raw.valid != 0 else {
            throw MacVICEError.engineFailure(MacVICEEngineSession.lastErrorMessage)
        }

        return MacVICEDebuggerSnapshot(raw: raw)
    }

    /// Disassembles instructions starting at an address.
    public func disassemble(memorySpace: MacVICEMemorySpace = .computer,
                            bank: Int32 = -1,
                            address: UInt32,
                            count: Int = 16) throws -> [MacVICEDisassemblyLine] {
        guard count > 0 else {
            return []
        }

        var rawLines = [ViceEngineDebuggerDisassemblyLine](repeating: ViceEngineDebuggerDisassemblyLine(),
                                                           count: count)
        var rawCount: UInt32 = 0
        let didDisassemble = rawLines.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return false
            }

            return ViceEngineDebuggerDisassemble(memorySpace.rawValue,
                                                 bank,
                                                 address,
                                                 baseAddress,
                                                 UInt32(count),
                                                 &rawCount)
        }

        guard didDisassemble else {
            throw MacVICEError.engineFailure(MacVICEEngineSession.lastErrorMessage)
        }

        return rawLines.prefix(Int(rawCount)).map(MacVICEDisassemblyLine.init(raw:))
    }

    /// Sets a breakpoint at one address and returns its VICE checkpoint identifier.
    @discardableResult
    public func setBreakpoint(memorySpace: MacVICEMemorySpace = .computer,
                              address: UInt32,
                              operations: [MacVICECheckpointOperation] = [.execute],
                              stops: Bool = true,
                              enabled: Bool = true,
                              temporary: Bool = false) throws -> UInt32 {
        try setCheckpoint(memorySpace: memorySpace,
                          startAddress: address,
                          endAddress: address,
                          operationsMask: operations.reduce(UInt32(0)) { $0 | $1.rawValue },
                          stops: stops,
                          enabled: enabled,
                          temporary: temporary)
    }

    /// Sets a VICE checkpoint over an address range and returns its identifier.
    @discardableResult
    public func setCheckpoint(memorySpace: MacVICEMemorySpace = .computer,
                              startAddress: UInt32,
                              endAddress: UInt32,
                              operationsMask: UInt32,
                              stops: Bool = true,
                              enabled: Bool = true,
                              temporary: Bool = false) throws -> UInt32 {
        guard operationsMask != 0 else {
            throw MacVICEError.invalidConfiguration("Checkpoint operations must not be empty.")
        }

        var checkpointID: UInt32 = 0
        guard ViceEngineDebuggerSetCheckpoint(memorySpace.rawValue,
                                              startAddress,
                                              endAddress,
                                              operationsMask,
                                              stops,
                                              enabled,
                                              temporary,
                                              &checkpointID) else {
            throw MacVICEError.engineFailure(MacVICEEngineSession.lastErrorMessage)
        }
        return checkpointID
    }

    /// Lists current VICE checkpoints and breakpoints.
    public func listBreakpoints() throws -> [MacVICECheckpoint] {
        let capacity = 256
        var rawCheckpoints = [ViceEngineDebuggerCheckpoint](repeating: ViceEngineDebuggerCheckpoint(),
                                                           count: capacity)
        var rawCount: UInt32 = 0
        let didList = rawCheckpoints.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return false
            }

            return ViceEngineDebuggerListCheckpoints(baseAddress, UInt32(capacity), &rawCount)
        }

        guard didList else {
            throw MacVICEError.engineFailure(MacVICEEngineSession.lastErrorMessage)
        }

        return rawCheckpoints.prefix(Int(rawCount)).compactMap(MacVICECheckpoint.init(raw:))
    }

    /// Removes a checkpoint or breakpoint by identifier.
    public func removeBreakpoint(id: UInt32) throws {
        guard ViceEngineDebuggerDeleteCheckpoint(id) else {
            throw MacVICEError.engineFailure(MacVICEEngineSession.lastErrorMessage)
        }
    }

    /// Enables or disables a checkpoint or breakpoint by identifier.
    public func setBreakpoint(id: UInt32, enabled: Bool) throws {
        guard ViceEngineDebuggerSetCheckpointEnabled(id, enabled) else {
            throw MacVICEError.engineFailure(MacVICEEngineSession.lastErrorMessage)
        }
    }

    /// Sets a CPU register value.
    public func setRegister(memorySpace: MacVICEMemorySpace = .computer,
                            registerID: UInt32,
                            value: UInt32) throws {
        guard ViceEngineDebuggerSetRegister(memorySpace.rawValue, registerID, value) else {
            throw MacVICEError.engineFailure(MacVICEEngineSession.lastErrorMessage)
        }
    }

    /// Selects the active CPU for a memory space when VICE exposes more than one.
    public func setCPU(memorySpace: MacVICEMemorySpace = .computer,
                       cpuType: UInt32) throws {
        guard ViceEngineDebuggerSetCPU(memorySpace.rawValue, cpuType) else {
            throw MacVICEError.engineFailure(MacVICEEngineSession.lastErrorMessage)
        }
    }

    /// Steps the debugger by one or more instructions.
    public func step(count: UInt32 = 1, over: Bool = false) throws {
        guard ViceEngineDebuggerStep(count, over) else {
            throw MacVICEError.engineFailure(MacVICEEngineSession.lastErrorMessage)
        }
    }

    /// Continues execution until the current routine returns.
    public func stepOut() throws {
        guard ViceEngineDebuggerReturn() else {
            throw MacVICEError.engineFailure(MacVICEEngineSession.lastErrorMessage)
        }
    }

    /// Resumes machine execution from the debugger.
    public func resume() throws {
        guard ViceEngineDebuggerContinue() else {
            throw MacVICEError.engineFailure(MacVICEEngineSession.lastErrorMessage)
        }
    }
}

private extension MacVICEDebuggerSnapshot {
    init(raw: ViceEngineDebuggerSnapshot) {
        var cpuStorage = raw.supportedCPUTypes
        let cpuCount = min(Int(raw.supportedCPUCount), Int(VICE_ENGINE_DEBUGGER_MAX_CPUS))
        let cpus = withUnsafeBytes(of: &cpuStorage) { rawBytes in
            Array(rawBytes.bindMemory(to: UInt32.self).prefix(cpuCount))
        }

        var registerStorage = raw.registers
        let registerCount = min(Int(raw.registerCount), Int(VICE_ENGINE_DEBUGGER_MAX_REGISTERS))
        let registers = withUnsafeBytes(of: &registerStorage) { rawBytes in
            Array(rawBytes.bindMemory(to: ViceEngineDebuggerRegister.self).prefix(registerCount))
        }.map(MacVICERegister.init(raw:))

        self.init(memorySpace: MacVICEMemorySpace(rawValue: raw.memorySpace) ?? .computer,
                  cpuType: raw.cpuType,
                  bank: raw.bank,
                  cycle: raw.cycle,
                  programCounter: raw.programCounter,
                  supportedCPUTypes: cpus,
                  registers: registers)
    }
}

private extension MacVICERegister {
    init(raw: ViceEngineDebuggerRegister) {
        var nameStorage = raw.name
        let name = withUnsafeBytes(of: &nameStorage) { rawBytes in
            let bytes = rawBytes.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }

        self.init(id: raw.id,
                  name: name,
                  bitWidth: raw.bitWidth,
                  value: raw.value,
                  flags: raw.flags)
    }
}

private extension MacVICEDisassemblyLine {
    init(raw: ViceEngineDebuggerDisassemblyLine) {
        var textStorage = raw.text
        let text = withUnsafeBytes(of: &textStorage) { rawBytes in
            let bytes = rawBytes.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }

        var byteStorage = raw.bytes
        let bytes = withUnsafeBytes(of: &byteStorage) { rawBytes in
            Array(rawBytes.prefix(Int(raw.size)))
        }

        self.init(address: raw.address,
                  size: raw.size,
                  bytes: bytes,
                  text: text)
    }
}

private extension MacVICECheckpoint {
    init?(raw: ViceEngineDebuggerCheckpoint) {
        guard let memorySpace = MacVICEMemorySpace(rawValue: raw.memorySpace) else {
            return nil
        }

        self.init(id: raw.id,
                  memorySpace: memorySpace,
                  startAddress: raw.startAddress,
                  endAddress: raw.endAddress,
                  operations: raw.operations,
                  isEnabled: raw.enabled != 0,
                  stops: raw.stops != 0,
                  isTemporary: raw.temporary != 0,
                  hitCount: raw.hitCount,
                  ignoreCount: raw.ignoreCount)
    }
}
