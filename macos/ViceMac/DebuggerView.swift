import AppKit
import Foundation
import MacVICEKit
import SwiftUI

struct DebuggerView: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @StateObject private var session = DebuggerSession()
    @FocusState private var commandFocused: Bool
    private let autoRefreshTimer = Timer.publish(every: 0.75, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HSplitView {
                executionRail
                    .frame(minWidth: 210, idealWidth: 235, maxWidth: 290)

                VStack(spacing: 0) {
                    disassemblyPanel
                    Divider()
                    bottomPanel
                        .frame(minHeight: 255, idealHeight: 300)
                }
                .frame(minWidth: 620)

                registerPanel
                    .frame(minWidth: 250, idealWidth: 280, maxWidth: 340)
            }
        }
        .frame(minWidth: 1_080, minHeight: 680)
        .task {
            session.refresh(emulator: emulator, followProgramCounterIfNeeded: true)
        }
        .onChange(of: session.memorySpace) {
            session.refresh(emulator: emulator, followProgramCounterIfNeeded: true)
        }
        .onChange(of: emulator.isPaused) {
            session.refresh(emulator: emulator, followProgramCounterIfNeeded: false)
        }
        .onReceive(autoRefreshTimer) { _ in
            session.autosync(emulator: emulator)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Picker("Memory", selection: $session.memorySpace) {
                    ForEach(EmulatorSession.MemorySpace.allCases) { space in
                        Text(space.title).tag(space)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 145)

                if session.supportedCPUs.count > 1 {
                    Picker("CPU", selection: $session.selectedCPUType) {
                        ForEach(session.supportedCPUs) { cpu in
                            Text(cpu.title).tag(cpu.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 120)
                    .onChange(of: session.selectedCPUType) { _, cpuType in
                        session.setCPU(cpuType, emulator: emulator)
                    }
                } else {
                    DebuggerStatusPill(title: session.activeCPU.title, value: "CPU")
                }

                DebuggerToolbarButton("Pause", systemImage: "pause.fill") {
                    emulator.isPaused = true
                    session.refresh(emulator: emulator, followProgramCounterIfNeeded: false)
                }
                .disabled(!emulator.isMachineRunning || emulator.isPaused)

                DebuggerToolbarButton("Run", systemImage: "play.fill") {
                    session.continueExecution(emulator: emulator)
                }
                .disabled(!emulator.isMachineRunning)

                Divider()
                    .frame(height: 22)

                DebuggerToolbarButton("Step", systemImage: "arrow.turn.down.right") {
                    session.step(emulator: emulator, over: false)
                }
                .disabled(!emulator.isMachineRunning)

                DebuggerToolbarButton("Next", systemImage: "arrow.right.to.line") {
                    session.step(emulator: emulator, over: true)
                }
                .disabled(!emulator.isMachineRunning)

                DebuggerToolbarButton("Return", systemImage: "return") {
                    session.stepOut(emulator: emulator)
                }
                .disabled(!emulator.isMachineRunning)

                Spacer(minLength: 8)
            }

            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .foregroundStyle(.secondary)
                TextField("goto $c000, mem $0400, break $c000, watch $d020", text: $session.commandText)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .focused($commandFocused)
                    .onSubmit {
                        session.runCommand(emulator: emulator)
                    }

                Button("Run Command") {
                    session.runCommand(emulator: emulator)
                }
                .disabled(session.commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var executionRail: some View {
        DebuggerPanel(title: "Execution") {
            VStack(alignment: .leading, spacing: 12) {
                DebuggerMetric(label: "State", value: emulator.isPaused ? "Paused" : "Running")
                DebuggerMetric(label: "Machine", value: emulator.machineDisplayName)
                DebuggerMetric(label: "CPU", value: session.activeCPU.title)
                DebuggerMetric(label: "Memory", value: session.snapshot?.memorySpaceText ?? session.memorySpace.title)
                DebuggerMetric(label: "PC", value: session.snapshot?.pcText ?? "--")
                DebuggerMetric(label: "Cycle", value: session.snapshot?.cycleText ?? "--")
                DebuggerMetric(label: "Bank", value: session.snapshot?.bankText ?? "--")

                Divider()

                Toggle("Follow PC", isOn: $session.followProgramCounter)
                    .toggleStyle(.checkbox)

                HStack(spacing: 6) {
                    TextField("Address", text: $session.disassemblyAddressText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit {
                            session.jumpToDisassemblyAddress(emulator: emulator)
                        }

                    Button {
                        session.jumpToDisassemblyAddress(emulator: emulator)
                    } label: {
                        Image(systemName: "arrow.right")
                    }
                    .buttonStyle(.bordered)
                    .help("Jump disassembly")
                }

                Button {
                    session.syncDisassemblyToProgramCounter(emulator: emulator)
                } label: {
                    Label("Center on PC", systemImage: "scope")
                }
                .buttonStyle(.bordered)
                .disabled(session.snapshot == nil)

                if !session.statusText.isEmpty {
                    Divider()
                    Text(session.statusText)
                        .font(.callout)
                        .foregroundStyle(session.statusKind.color)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var disassemblyPanel: some View {
        DebuggerPanel(title: "Disassembly") {
            ScrollViewReader { proxy in
                List(session.disassembly, selection: $session.selectedDisassemblyAddress) { line in
                    HStack(spacing: 10) {
                        Text(line.addressText)
                            .foregroundStyle(line.isProgramCounter ? .blue : .secondary)
                            .frame(width: 58, alignment: .trailing)

                        Text(line.bytesText)
                            .foregroundStyle(.secondary)
                            .frame(width: 104, alignment: .leading)

                        Text(line.text)
                            .foregroundStyle(line.isProgramCounter ? .primary : .primary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        if line.hasBreakpoint {
                            Image(systemName: "octagon.fill")
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.system(.body, design: .monospaced))
                    .contentShape(Rectangle())
                    .tag(line.address)
                    .onTapGesture {
                        session.selectDisassemblyAddress(line.address)
                    }
                    .contextMenu {
                        Button("Add Breakpoint") {
                            session.addBreakpoint(address: line.address,
                                                  operations: .execute,
                                                  emulator: emulator)
                        }
                        Button("Show Memory Here") {
                            session.setMemoryAddress(line.address, emulator: emulator)
                        }
                    }
                    .id(line.address)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .onChange(of: session.snapshot?.programCounter) { _, pc in
                    guard let pc else {
                        return
                    }
                    proxy.scrollTo(pc, anchor: .center)
                }
            }
        }
    }

    private var registerPanel: some View {
        DebuggerPanel(title: "Registers") {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(session.registers) { register in
                        HStack(spacing: 8) {
                            Text(register.name)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(register.isFlags ? .orange : .secondary)
                                .frame(width: 48, alignment: .leading)

                            TextField("", text: registerEditBinding(for: register))
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .frame(width: register.bitWidth > 8 ? 78 : 54)
                                .onSubmit {
                                    session.commitRegister(register, emulator: emulator)
                                }

                            if register.isFlags {
                                Text(register.flagsText)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            } else {
                                Spacer(minLength: 0)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(register.id == 3 ? Color.accentColor.opacity(0.10) : Color.clear)

                        Divider()
                    }
                }
            }
        }
    }

    private var bottomPanel: some View {
        HSplitView {
            memoryPanel
                .frame(minWidth: 485, idealWidth: 560)
            checkpointPanel
                .frame(minWidth: 420, idealWidth: 500)
        }
    }

    private var memoryPanel: some View {
        DebuggerPanel(title: "Memory") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Address", text: $session.memoryAddressText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 104)
                        .onSubmit {
                            session.jumpToMemoryAddress(emulator: emulator)
                        }

                    Button {
                        session.jumpToMemoryAddress(emulator: emulator)
                    } label: {
                        Image(systemName: "arrow.right")
                    }
                    .buttonStyle(.bordered)
                    .help("Show memory")

                    Button {
                        session.setMemoryAddress(session.snapshot?.programCounter ?? 0, emulator: emulator)
                    } label: {
                        Label("PC", systemImage: "scope")
                    }
                    .buttonStyle(.bordered)

                    Spacer()
                }

                ScrollView([.vertical, .horizontal]) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(0..<16, id: \.self) { row in
                            memoryRow(row)
                        }
                    }
                    .padding(2)
                }
            }
        }
    }

    private func memoryRow(_ row: Int) -> some View {
        let rowBase = row * 16
        return HStack(spacing: 5) {
            if rowBase < session.memoryCells.count {
                Text(DebuggerFormatter.hex16(session.memoryCells[rowBase].address))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .trailing)
            }

            ForEach(0..<16, id: \.self) { column in
                let index = rowBase + column
                if index < session.memoryCells.count {
                    TextField("", text: $session.memoryCells[index].text)
                        .textFieldStyle(.plain)
                        .font(.system(.caption, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .frame(width: 26, height: 22)
                        .background(Color(nsColor: .textBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                        }
                        .onSubmit {
                            session.commitMemoryCell(at: index, emulator: emulator)
                        }
                }
            }
        }
    }

    private var checkpointPanel: some View {
        DebuggerPanel(title: "Breakpoints and Watchpoints") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    TextField("Start", text: $session.checkpointStartText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 92)
                    TextField("End", text: $session.checkpointEndText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 92)

                    Toggle("Exec", isOn: $session.checkpointExecute)
                        .toggleStyle(.checkbox)
                    Toggle("Read", isOn: $session.checkpointRead)
                        .toggleStyle(.checkbox)
                    Toggle("Write", isOn: $session.checkpointWrite)
                        .toggleStyle(.checkbox)

                    Spacer(minLength: 0)

                    Button {
                        session.addCheckpointFromFields(emulator: emulator)
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(session.checkpoints) { checkpoint in
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Button {
                                        session.setCheckpointEnabled(checkpoint, enabled: !checkpoint.enabled, emulator: emulator)
                                    } label: {
                                        Image(systemName: checkpoint.enabled ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(checkpoint.enabled ? .green : .secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .help(checkpoint.enabled ? "Disable" : "Enable")

                                    Text("#\(checkpoint.id)")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 38, alignment: .leading)

                                    Text(checkpoint.rangeText)
                                        .font(.system(.body, design: .monospaced))
                                        .frame(width: 112, alignment: .leading)

                                    DebuggerOperationChips(operations: checkpoint.operations)

                                    Spacer(minLength: 0)

                                    Text("\(checkpoint.hitCount)")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 44, alignment: .trailing)

                                    Button {
                                        session.deleteCheckpoint(checkpoint, emulator: emulator)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Delete")
                                }

                                Text(checkpoint.detailText)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 84)
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal, 6)
                            .background(checkpoint.enabled ? Color.clear : Color.secondary.opacity(0.06))

                            Divider()
                        }

                        if session.checkpoints.isEmpty {
                            Text("No breakpoints or watchpoints")
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, minHeight: 90)
                        }
                    }
                }
            }
        }
    }

    private func registerEditBinding(for register: DebuggerRegister) -> Binding<String> {
        Binding {
            session.registerEdits[register.id] ?? register.valueText
        } set: { newValue in
            session.registerEdits[register.id] = newValue.uppercased()
        }
    }
}

@MainActor
final class DebuggerSession: ObservableObject {
    @Published var memorySpace: EmulatorSession.MemorySpace = .computer
    @Published var snapshot: DebuggerSnapshot?
    @Published var activeCPU: DebuggerCPU = .unknown
    @Published var supportedCPUs: [DebuggerCPU] = [.unknown]
    @Published var selectedCPUType: UInt32 = DebuggerCPU.unknown.id
    @Published var registers: [DebuggerRegister] = []
    @Published var registerEdits: [UInt32: String] = [:]
    @Published var disassembly: [DebuggerDisassemblyLine] = []
    @Published var selectedDisassemblyAddress: UInt16?
    @Published var checkpoints: [DebuggerCheckpoint] = []
    @Published var memoryCells: [DebuggerMemoryCell] = []
    @Published var followProgramCounter = true
    @Published var disassemblyAddressText = "0000"
    @Published var memoryAddressText = "0000"
    @Published var commandText = ""
    @Published var checkpointStartText = "0000"
    @Published var checkpointEndText = "0000"
    @Published var checkpointExecute = true
    @Published var checkpointRead = false
    @Published var checkpointWrite = false
    @Published var statusText = ""
    @Published var statusKind: DebuggerStatusKind = .neutral

    private var disassemblyAddress: UInt16 = 0
    private var memoryAddress: UInt16 = 0

    private var macVICEMemorySpace: MacVICEMemorySpace {
        MacVICEMemorySpace(rawValue: memorySpace.rawValue) ?? .computer
    }

    func refresh(emulator: EmulatorSession, followProgramCounterIfNeeded: Bool) {
        guard emulator.isMachineRunning else {
            snapshot = nil
            registers = []
            disassembly = []
            checkpoints = []
            memoryCells = []
            setStatus("Machine is not running", kind: .warning)
            return
        }

        loadSnapshot(emulator: emulator)

        if followProgramCounter && followProgramCounterIfNeeded, let programCounter = snapshot?.programCounter {
            disassemblyAddress = programCounter
            disassemblyAddressText = DebuggerFormatter.hex16(programCounter)
        }

        // Checkpoints must load before disassembly: the disassembly rows read
        // the checkpoint list to mark which addresses have breakpoints.
        loadCheckpoints(emulator: emulator)
        loadDisassembly(emulator: emulator)
        loadMemory(emulator: emulator)
    }

    func autosync(emulator: EmulatorSession) {
        guard emulator.isMachineRunning else {
            return
        }

        refresh(emulator: emulator,
                followProgramCounterIfNeeded: followProgramCounter && emulator.isPaused)
    }

    func setCPU(_ cpuType: UInt32, emulator: EmulatorSession) {
        do {
            try emulator.engine.debugger.setCPU(memorySpace: macVICEMemorySpace, cpuType: cpuType)
        } catch {
            setStatus("Unable to switch CPU", kind: .error)
            return
        }
        refresh(emulator: emulator, followProgramCounterIfNeeded: true)
    }

    func continueExecution(emulator: EmulatorSession) {
        do {
            try emulator.engine.debugger.resume()
            emulator.isPaused = false
            setStatus("Running", kind: .neutral)
        } catch {
            setStatus("Unable to continue", kind: .error)
        }
        refresh(emulator: emulator, followProgramCounterIfNeeded: false)
    }

    func step(emulator: EmulatorSession, over: Bool) {
        emulator.isPaused = true
        do {
            try emulator.engine.debugger.step(count: 1, over: over)
            setStatus(over ? "Stepped over" : "Stepped", kind: .neutral)
        } catch {
            setStatus("Unable to step", kind: .error)
        }
        refresh(emulator: emulator, followProgramCounterIfNeeded: true)
    }

    func stepOut(emulator: EmulatorSession) {
        emulator.isPaused = true
        do {
            try emulator.engine.debugger.stepOut()
            setStatus("Running until return", kind: .neutral)
        } catch {
            setStatus("Unable to step out", kind: .error)
        }
        refresh(emulator: emulator, followProgramCounterIfNeeded: true)
    }

    func syncDisassemblyToProgramCounter(emulator: EmulatorSession) {
        guard let programCounter = snapshot?.programCounter else {
            return
        }
        followProgramCounter = true
        disassemblyAddress = programCounter
        disassemblyAddressText = DebuggerFormatter.hex16(programCounter)
        refresh(emulator: emulator, followProgramCounterIfNeeded: false)
    }

    func jumpToDisassemblyAddress(emulator: EmulatorSession) {
        guard let address = DebuggerFormatter.parseAddress(disassemblyAddressText) else {
            setStatus("Invalid disassembly address", kind: .error)
            return
        }
        followProgramCounter = false
        disassemblyAddress = address
        disassemblyAddressText = DebuggerFormatter.hex16(address)
        loadDisassembly(emulator: emulator)
        setStatus("Disassembly at \(DebuggerFormatter.hex16(address))", kind: .neutral)
    }

    func selectDisassemblyAddress(_ address: UInt16) {
        selectedDisassemblyAddress = address
        checkpointStartText = DebuggerFormatter.hex16(address)
        checkpointEndText = DebuggerFormatter.hex16(address)
    }

    func setMemoryAddress(_ address: UInt16, emulator: EmulatorSession) {
        memoryAddress = address
        memoryAddressText = DebuggerFormatter.hex16(address)
        loadMemory(emulator: emulator)
    }

    func jumpToMemoryAddress(emulator: EmulatorSession) {
        guard let address = DebuggerFormatter.parseAddress(memoryAddressText) else {
            setStatus("Invalid memory address", kind: .error)
            return
        }
        setMemoryAddress(address, emulator: emulator)
    }

    func commitRegister(_ register: DebuggerRegister, emulator: EmulatorSession) {
        guard let text = registerEdits[register.id],
              let value = DebuggerFormatter.parseHex(text),
              value <= register.maxValue else {
            setStatus("Invalid value for \(register.name)", kind: .error)
            return
        }

        do {
            try emulator.engine.debugger.setRegister(memorySpace: macVICEMemorySpace,
                                                     registerID: register.id,
                                                     value: value)
        } catch {
            setStatus("Unable to write \(register.name)", kind: .error)
            return
        }

        setStatus("\(register.name) = \(DebuggerFormatter.hex(value, digits: register.hexDigits))", kind: .neutral)
        refresh(emulator: emulator, followProgramCounterIfNeeded: false)
    }

    func commitMemoryCell(at index: Int, emulator: EmulatorSession) {
        guard memoryCells.indices.contains(index) else {
            return
        }

        let cell = memoryCells[index]
        guard let value = DebuggerFormatter.parseByte(cell.text) else {
            setStatus("Invalid byte at \(DebuggerFormatter.hex16(cell.address))", kind: .error)
            return
        }

        guard emulator.pokeByte(space: memorySpace,
                                bank: EmulatorSession.currentMemoryBank,
                                address: cell.address,
                                byte: value) else {
            setStatus("Unable to write \(DebuggerFormatter.hex16(cell.address))", kind: .error)
            return
        }

        memoryCells[index].value = value
        memoryCells[index].text = DebuggerFormatter.hex8(value)
        setStatus("\(DebuggerFormatter.hex16(cell.address)) = \(DebuggerFormatter.hex8(value))", kind: .neutral)
    }

    func addCheckpointFromFields(emulator: EmulatorSession) {
        guard let start = DebuggerFormatter.parseAddress(checkpointStartText),
              let end = DebuggerFormatter.parseAddress(checkpointEndText) else {
            setStatus("Invalid checkpoint address", kind: .error)
            return
        }

        var operations = DebuggerOperations()
        if checkpointExecute {
            operations.insert(.execute)
        }
        if checkpointRead {
            operations.insert(.read)
        }
        if checkpointWrite {
            operations.insert(.write)
        }

        addBreakpoint(address: start,
                      endAddress: end,
                      operations: operations,
                      emulator: emulator)
    }

    func addBreakpoint(address: UInt16,
                       endAddress: UInt16? = nil,
                       operations: DebuggerOperations,
                       emulator: EmulatorSession) {
        guard !operations.isEmpty else {
            setStatus("Choose Exec, Read, or Write", kind: .error)
            return
        }

        let resolvedEnd = endAddress ?? address
        let checkpointID: UInt32
        do {
            checkpointID = try emulator.engine.debugger.setCheckpoint(memorySpace: macVICEMemorySpace,
                                                                      startAddress: UInt32(address),
                                                                      endAddress: UInt32(resolvedEnd),
                                                                      operationsMask: operations.rawValue)
        } catch {
            setStatus("Unable to add checkpoint", kind: .error)
            return
        }

        setStatus("Added checkpoint #\(checkpointID)", kind: .neutral)
        loadCheckpoints(emulator: emulator)
        loadDisassembly(emulator: emulator)
    }

    func setCheckpointEnabled(_ checkpoint: DebuggerCheckpoint,
                              enabled: Bool,
                              emulator: EmulatorSession) {
        do {
            try emulator.engine.debugger.setBreakpoint(id: checkpoint.id, enabled: enabled)
        } catch {
            setStatus("Unable to update checkpoint #\(checkpoint.id)", kind: .error)
            return
        }
        setStatus(enabled ? "Enabled checkpoint #\(checkpoint.id)" : "Disabled checkpoint #\(checkpoint.id)",
                  kind: .neutral)
        refresh(emulator: emulator, followProgramCounterIfNeeded: false)
    }

    func deleteCheckpoint(_ checkpoint: DebuggerCheckpoint, emulator: EmulatorSession) {
        do {
            try emulator.engine.debugger.removeBreakpoint(id: checkpoint.id)
        } catch {
            setStatus("Unable to delete checkpoint #\(checkpoint.id)", kind: .error)
            return
        }
        setStatus("Deleted checkpoint #\(checkpoint.id)", kind: .neutral)
        refresh(emulator: emulator, followProgramCounterIfNeeded: false)
    }

    func runCommand(emulator: EmulatorSession) {
        let trimmed = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
        let command = parts[0].lowercased()
        let argument = parts.count > 1 ? parts[1] : ""

        switch command {
        case "g", "go", "goto", "d", "disasm":
            guard let address = DebuggerFormatter.parseAddress(argument) else {
                setStatus("Command needs an address", kind: .error)
                return
            }
            disassemblyAddressText = DebuggerFormatter.hex16(address)
            jumpToDisassemblyAddress(emulator: emulator)
        case "m", "mem", "memory":
            guard let address = DebuggerFormatter.parseAddress(argument) else {
                setStatus("Command needs an address", kind: .error)
                return
            }
            setMemoryAddress(address, emulator: emulator)
        case "b", "break", "breakpoint":
            guard let address = DebuggerFormatter.parseAddress(argument) else {
                setStatus("Command needs an address", kind: .error)
                return
            }
            addBreakpoint(address: address, operations: .execute, emulator: emulator)
        case "w", "watch", "watchpoint":
            guard let address = DebuggerFormatter.parseAddress(argument) else {
                setStatus("Command needs an address", kind: .error)
                return
            }
            addBreakpoint(address: address, operations: [.read, .write], emulator: emulator)
        case "pc":
            syncDisassemblyToProgramCounter(emulator: emulator)
        default:
            setStatus("Unknown command: \(command)", kind: .error)
            return
        }

        commandText = ""
    }

    private func loadSnapshot(emulator: EmulatorSession) {
        let debuggerSnapshot: MacVICEDebuggerSnapshot
        do {
            debuggerSnapshot = try emulator.engine.debugger.snapshot(memorySpace: macVICEMemorySpace)
        } catch {
            snapshot = nil
            registers = []
            supportedCPUs = [.unknown]
            activeCPU = .unknown
            setStatus("Unable to read debugger state", kind: .error)
            return
        }

        let resolvedSnapshot = DebuggerSnapshot(debuggerSnapshot)
        snapshot = resolvedSnapshot
        activeCPU = resolvedSnapshot.cpu
        supportedCPUs = resolvedSnapshot.supportedCPUs.isEmpty ? [resolvedSnapshot.cpu] : resolvedSnapshot.supportedCPUs
        selectedCPUType = resolvedSnapshot.cpu.id
        registers = resolvedSnapshot.registers
        for register in resolvedSnapshot.registers {
            registerEdits[register.id] = register.valueText
        }

        if disassemblyAddressText == "0000" {
            disassemblyAddress = resolvedSnapshot.programCounter
            disassemblyAddressText = DebuggerFormatter.hex16(resolvedSnapshot.programCounter)
        }
        if memoryAddressText == "0000" {
            memoryAddress = resolvedSnapshot.programCounter
            memoryAddressText = DebuggerFormatter.hex16(resolvedSnapshot.programCounter)
        }
    }

    private func loadDisassembly(emulator: EmulatorSession) {
        let lines: [MacVICEDisassemblyLine]
        do {
            lines = try emulator.engine.debugger.disassemble(memorySpace: macVICEMemorySpace,
                                                             bank: EmulatorSession.currentMemoryBank,
                                                             address: UInt32(disassemblyAddress),
                                                             count: 96)
        } catch {
            disassembly = []
            return
        }

        let pc = snapshot?.programCounter
        let activeBreakpoints = Set(checkpoints.filter { $0.operations.contains(.execute) && $0.enabled }
            .flatMap { checkpoint in checkpoint.addresses })
        disassembly = lines.map {
            DebuggerDisassemblyLine($0,
                                    programCounter: pc,
                                    activeBreakpoints: activeBreakpoints)
        }
    }

    private func loadCheckpoints(emulator: EmulatorSession) {
        do {
            checkpoints = try emulator.engine.debugger.listBreakpoints().map(DebuggerCheckpoint.init)
        } catch {
            checkpoints = []
        }
    }

    private func loadMemory(emulator: EmulatorSession) {
        let length = min(256, Int(UInt16.max) + 1 - Int(memoryAddress))
        guard let data = emulator.peekMemory(space: memorySpace,
                                             bank: EmulatorSession.currentMemoryBank,
                                             address: memoryAddress,
                                             length: length) else {
            memoryCells = []
            return
        }

        memoryCells = data.enumerated().map { offset, value in
            let address = UInt16(Int(memoryAddress) + offset)
            return DebuggerMemoryCell(address: address, value: value)
        }
    }

    private func setStatus(_ text: String, kind: DebuggerStatusKind) {
        statusText = text
        statusKind = kind
    }
}

enum DebuggerStatusKind {
    case neutral
    case warning
    case error

    var color: Color {
        switch self {
        case .neutral:
            return .secondary
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}

private struct DebuggerPanel<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            content
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct DebuggerToolbarButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(.bordered)
    }
}

private struct DebuggerStatusPill: View {
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.body)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

private struct DebuggerMetric: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}

private struct DebuggerOperationChips: View {
    let operations: DebuggerOperations

    var body: some View {
        HStack(spacing: 4) {
            if operations.contains(.execute) {
                DebuggerOperationChip(title: "EXEC", color: .red)
            }
            if operations.contains(.read) {
                DebuggerOperationChip(title: "READ", color: .blue)
            }
            if operations.contains(.write) {
                DebuggerOperationChip(title: "WRITE", color: .purple)
            }
        }
    }
}

private struct DebuggerOperationChip: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
