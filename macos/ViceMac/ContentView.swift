import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @EnvironmentObject private var aiSettings: AIAssistantSettings
    @State private var showingFilterPanel = false
    @State private var isFullScreen = false
    @State private var topChromeActive = false
    @State private var bottomChromeActive = false

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                EmulatorDisplaySurface()

                if !isFullScreen {
                    Divider()
                    EmulatorStatusBar()
                }
            }

            if isFullScreen {
                EmulatorStatusBar()
                    .background(.regularMaterial)
                    .overlay(alignment: .top) {
                        Divider()
                    }
                    .opacity(bottomChromeActive ? 1 : 0)
                    .offset(y: bottomChromeActive ? 0 : 38)
                    .animation(.easeOut(duration: 0.16), value: bottomChromeActive)
                    .allowsHitTesting(bottomChromeActive)
            }

            WindowChromeObserver(isFullScreen: $isFullScreen,
                                 topChromeActive: $topChromeActive,
                                 bottomChromeActive: $bottomChromeActive,
                                 machine: emulator.machine)
                .allowsHitTesting(false)
        }
        .toolbar {
            ToolbarItemGroup {
                MachineToolbarControls()

                InputToolbarControls()

                if emulator.machine.capabilities.supportsVideoStandardSelection {
                    Picker("Video", selection: $emulator.videoStandard) {
                        ForEach(EmulatorSession.VideoStandard.allCases) { standard in
                            Text(standard.rawValue).tag(standard)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 118)
                    .help("Video standard")
                }

                if emulator.machine.supportsDisplayOutputSelection {
                    DisplayOutputToolbarPicker()
                }

                if emulator.machine.usesVIC20MemoryExpansion {
                    VIC20MemoryToolbarMenu()
                }

                SoundToolbarControls()
            }

            ToolbarItemGroup {
                DisplaySettingsToolbarControls(showingFilterPanel: $showingFilterPanel)
            }

            if aiSettings.isConfigured {
                ToolbarItem {
                    AIAssistantToolbarButton()
                }
            }
        }
        .onAppear {
            emulator.start()
        }
        .onOpenURL { url in
            emulator.openMedia(url: url)
        }
        .alert(item: $emulator.startupError) { error in
            Alert(title: Text(error.title),
                  message: Text(error.message),
                  dismissButton: .default(Text("OK")))
        }
    }
}

private struct AIAssistantToolbarButton: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @EnvironmentObject private var aiSettings: AIAssistantSettings
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            Label("Assistant", systemImage: "sparkles")
        }
        .help("Ask or control \(emulator.machineDisplayName)")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            AIAssistantPanel()
                .environmentObject(emulator)
                .environmentObject(aiSettings)
        }
    }
}

private struct AIAssistantPanel: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @EnvironmentObject private var aiSettings: AIAssistantSettings
    @State private var mode = AIAssistantPanelMode.ask
    @State private var prompt = ""
    @State private var responseText = ""
    @State private var statusText = "Ready."
    @State private var isRunning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Assistant")
                        .font(.headline)

                    Text("\(aiSettings.providerSummary) - \(emulator.machineDisplayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Picker("Mode", selection: $mode) {
                ForEach(AIAssistantPanelMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            TextEditor(text: $prompt)
                .font(.body)
                .scrollContentBackground(.hidden)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .frame(height: 104)
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.separator.opacity(0.45))
                }

            if isRunning {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Working...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if !responseText.isEmpty {
                ScrollView {
                    Text(responseText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .frame(height: 132)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.separator.opacity(0.35))
                }
            }

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                Button {
                    prompt = ""
                    responseText = ""
                    statusText = "Ready."
                } label: {
                    Label("Clear", systemImage: "xmark")
                }
                .disabled(prompt.isEmpty && responseText.isEmpty)

                Spacer()

                Button {
                    Task {
                        await submitAssistantPrompt()
                    }
                } label: {
                    Label(mode.primaryActionTitle, systemImage: mode.primaryActionImage)
                }
                .disabled(!canActOnPrompt || isRunning)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(18)
        .frame(width: 420)
    }

    private var canActOnPrompt: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submitAssistantPrompt() async {
        let submittedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !submittedPrompt.isEmpty else {
            return
        }

        isRunning = true
        responseText = ""
        statusText = mode == .ask ? "Asking \(aiSettings.provider.title)..." : "Operating \(emulator.machine.shortName)..."

        do {
            let result = try await AIAssistantConversationService.run(prompt: submittedPrompt,
                                                                      mode: mode.interactionMode,
                                                                      settings: aiSettings,
                                                                      emulator: emulator)
            responseText = result.text
            if result.toolUseCount == 0 {
                statusText = "Done."
            } else {
                let noun = result.toolUseCount == 1 ? "tool" : "tools"
                statusText = "Done. Used \(result.toolUseCount) VM \(noun)."
            }
        } catch {
            statusText = error.localizedDescription
        }

        isRunning = false
    }
}

private enum AIAssistantPanelMode: String, CaseIterable, Identifiable {
    case ask
    case operate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ask:
            return "Ask"
        case .operate:
            return "Do"
        }
    }

    var interactionMode: AIAssistantInteractionMode {
        switch self {
        case .ask:
            return .ask
        case .operate:
            return .operate
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .ask:
            return "Ask"
        case .operate:
            return "Run"
        }
    }

    var primaryActionImage: String {
        switch self {
        case .ask:
            return "paperplane"
        case .operate:
            return "sparkles"
        }
    }
}

private struct EmulatorStatusBar: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        HStack(spacing: 14) {
            Label(emulator.machine.shortName, systemImage: "cpu")
            if emulator.machine.family == .pet {
                StatusPill(text: emulator.machineDisplayName)
            }
            if emulator.machine.capabilities.supportsVideoStandardSelection {
                StatusPill(text: emulator.videoStandard.rawValue)
            }
            if emulator.machine.capabilities.supportsSIDModelSelection {
                StatusPill(text: emulator.sidModel.title)
            }
            if emulator.machine.supportsDisplayOutputSelection {
                StatusPill(text: emulator.displayOutput.statusTitle)
            }
            StatusPill(text: emulator.isPaused ? "Paused" : "READY")
            StatusPill(text: emulator.filterSettings.preset.toolbarTitle)
            if emulator.isRAMExpansionConfigured {
                RAMExpansionStatusChip()
            }
            ForEach(emulator.availableControlPorts) { port in
                ControlPortStatusIndicator(port: port)
            }

            Spacer()

            if emulator.machine.capabilities.supportsCartridges {
                CartridgeIndicator()
            }

            ForEach(emulator.visibleDriveActivities) { drive in
                DriveIndicator(drive: drive)
            }
        }
        .font(.callout)
        .padding(.horizontal, 14)
        .frame(height: 36)
    }
}

private struct EmulatorDisplaySurface: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @State private var isDropTargeted = false

    var body: some View {
        GeometryReader { proxy in
            let displaySize = size(for: proxy.size)

            ZStack {
                Color.black

                EmulatorMetalView(frameSource: emulator.frameSource,
                                  filterSettings: emulator.filterSettings,
                                  preservesAspectRatio: emulator.displayMode.preservesAspectRatio,
                                  onKeyEvent: emulator.handleKeyEvent,
                                  onFlagsChanged: emulator.handleFlagsChanged,
                                  onPaste: { emulator.pasteFromPasteboard() },
                                  onFocusLost: emulator.releaseAllKeys)
                    .frame(width: displaySize.width,
                           height: displaySize.height)
                    .overlay {
                        if emulator.isPaused {
                            PausedDisplayOverlay()
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeOut(duration: 0.14), value: emulator.isPaused)

                if isDropTargeted {
                    MediaDropOverlay()
                        .transition(.opacity)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                handleMediaDrop(providers)
            }
        }
        .frame(minWidth: nativeSize.width, minHeight: nativeSize.height)
        .background(Color.black)
    }

    private var nativeSize: CGSize {
        emulator.frameSource.nativeDisplaySize()
    }

    private func size(for containerSize: CGSize) -> CGSize {
        switch emulator.displayMode {
        case .native:
            return nativeSize
        case .fit:
            return CGSize(width: max(containerSize.width, 1),
                          height: max(containerSize.height, 1))
        case .stretch:
            return CGSize(width: max(containerSize.width, 1),
                          height: max(containerSize.height, 1))
        }
    }

    private func handleMediaDrop(_ providers: [NSItemProvider]) -> Bool {
        let fileURLTypeIdentifier = UTType.fileURL.identifier
        let fileProviders = providers.filter {
            $0.hasItemConformingToTypeIdentifier(fileURLTypeIdentifier)
        }

        guard !fileProviders.isEmpty else {
            return false
        }

        for provider in fileProviders {
            provider.loadItem(forTypeIdentifier: fileURLTypeIdentifier, options: nil) { item, _ in
                guard let url = Self.fileURL(from: item) else {
                    return
                }

                DispatchQueue.main.async {
                    emulator.openMedia(url: url)
                }
            }
        }

        return true
    }

    nonisolated private static func fileURL(from item: NSSecureCoding?) -> URL? {
        if let url = item as? URL {
            return url
        }

        if let data = item as? Data {
            return URL(dataRepresentation: data, relativeTo: nil)
        }

        if let string = item as? String {
            return URL(string: string)
        }

        return nil
    }
}

private struct PausedDisplayOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.24))

            Image(systemName: "pause.fill")
                .font(.system(size: 54, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white.opacity(0.94))
                .frame(width: 112, height: 112)
                .background(.ultraThinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.36), radius: 24, y: 12)
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Paused")
    }
}

private struct MediaDropOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.32))

            VStack(spacing: 10) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.system(size: 34, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                Text("Open Media")
                    .font(.headline)
            }
            .foregroundStyle(.white.opacity(0.94))
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.34), radius: 22, y: 12)
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Drop media to open")
    }
}

private struct InputToolbarControls: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        HStack(spacing: 8) {
            ForEach(emulator.availableControlPorts) { port in
                ControlPortToolbarMenu(port: port)
            }

            if emulator.hasMultipleControlPorts {
                Button {
                    emulator.swapControlPorts()
                } label: {
                    ToolbarIconLabel(title: "Swap Control Ports",
                                     systemImage: "arrow.left.arrow.right")
                }
                .frame(width: 44)
                .buttonStyle(.plain)
                .help("Swap control ports")
            }
        }
        .fixedSize()
    }
}

private struct ControlPortStatusIndicator: View {
    @EnvironmentObject private var emulator: EmulatorSession

    let port: ControlPort

    var body: some View {
        let device = emulator.controlPortDevice(for: port)
        let connectionState = emulator.controlPortConnectionState(for: port)

        HStack(spacing: 6) {
            Text("P\(port.rawValue)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()

            Image(systemName: device?.systemImage ?? "slash.circle")
                .font(.system(size: 11, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconTint(for: connectionState, hasDevice: device != nil))

            ControlPortInputDots(activeActions: emulator.controlPortActiveActions(for: port),
                                 isEnabled: device != nil && connectionState.isConnected)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.7), in: Capsule())
        .help(helpText(device: device, connectionState: connectionState))
    }

    private func iconTint(for connectionState: ControlDeviceConnectionState,
                          hasDevice: Bool) -> Color {
        guard hasDevice else {
            return .secondary
        }

        return connectionState.isConnected ? .primary : .orange
    }

    private func helpText(device: ControlDeviceConfiguration?,
                          connectionState: ControlDeviceConnectionState) -> String {
        guard let device else {
            return "\(port.title): None"
        }

        guard connectionState.isConnected else {
            return "\(port.title): \(device.name) - \(connectionState.title)"
        }

        let activeActions = emulator.controlPortActiveActions(for: port)
        guard !activeActions.isEmpty else {
            return "\(port.title): \(device.name) - idle"
        }

        let actionText = JoystickAction.allCases
            .filter { activeActions.contains($0) }
            .map(\.title)
            .joined(separator: ", ")
        return "\(port.title): \(device.name) - \(actionText)"
    }
}

private struct ControlPortInputDots: View {
    let activeActions: Set<JoystickAction>
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(JoystickAction.allCases) { action in
                Image(systemName: systemImage(for: action))
                    .font(.system(size: action == .fire ? 6 : 7, weight: .semibold))
                    .frame(width: 8, height: 8)
                    .foregroundStyle(tint(for: action))
            }
        }
        .opacity(isEnabled ? 1 : 0.45)
    }

    private func systemImage(for action: JoystickAction) -> String {
        switch action {
        case .up:
            return "arrowtriangle.up.fill"
        case .down:
            return "arrowtriangle.down.fill"
        case .left:
            return "arrowtriangle.left.fill"
        case .right:
            return "arrowtriangle.right.fill"
        case .fire:
            return "circle.fill"
        }
    }

    private func tint(for action: JoystickAction) -> Color {
        guard isEnabled else {
            return .secondary.opacity(0.28)
        }

        return activeActions.contains(action) ? .accentColor : .secondary.opacity(0.28)
    }
}

private struct ControlPortToolbarMenu: View {
    @EnvironmentObject private var emulator: EmulatorSession

    let port: ControlPort

    var body: some View {
        Menu {
            Button {
                emulator.setControlPortDeviceID(nil, for: port)
            } label: {
                if emulator.controlPortDeviceID(for: port) == nil {
                    Label("None", systemImage: "checkmark")
                } else {
                    Label("None", systemImage: "slash.circle")
                }
            }

            if !emulator.controlDevices.isEmpty {
                Divider()
            }

            ForEach(emulator.controlDevices) { device in
                Button {
                    emulator.setControlPortDeviceID(device.id, for: port)
                } label: {
                    let connectionState = emulator.connectionState(for: device)
                    let title = connectionState.isConnected
                        ? device.name
                        : "\(device.name) - \(connectionState.title)"

                    if emulator.controlPortDeviceID(for: port) == device.id {
                        Label(title, systemImage: connectionState.isConnected ? "checkmark" : connectionState.systemImage)
                    } else {
                        Label(title, systemImage: connectionState.isConnected ? device.systemImage : connectionState.systemImage)
                    }
                }
            }

            if emulator.controlDevices.isEmpty {
                Text("No control devices")
            }
        } label: {
            HStack(spacing: 5) {
                Text("P\(port.rawValue)")
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()

                Image(systemName: toolbarSystemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 17, height: 17)
                    .foregroundStyle(toolbarTint)
            }
            .frame(width: 58)
        }
        .help(helpText)
    }

    private var toolbarSystemImage: String {
        guard let device = emulator.controlPortDevice(for: port) else {
            return "slash.circle"
        }

        let connectionState = emulator.connectionState(for: device)
        return connectionState.isConnected ? device.systemImage : connectionState.systemImage
    }

    private var toolbarTint: Color {
        guard let device = emulator.controlPortDevice(for: port) else {
            return .secondary
        }

        return emulator.connectionState(for: device).isConnected ? .primary : .orange
    }

    private var helpText: String {
        guard let device = emulator.controlPortDevice(for: port) else {
            return "\(port.title): None"
        }

        let connectionState = emulator.connectionState(for: device)
        if connectionState.isConnected {
            return "\(port.title): \(device.name)"
        }

        return "\(port.title): \(device.name) - \(connectionState.title)"
    }
}

private struct MachineToolbarControls: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        HStack(spacing: 8) {
            Button {
                emulator.togglePause()
            } label: {
                ToolbarIconLabel(title: emulator.isPaused ? "Resume" : "Pause",
                                 systemImage: emulator.isPaused ? "play.fill" : "pause.fill")
            }
            .frame(width: 44)
            .help(emulator.isPaused ? "Resume \(emulator.machine.shortName)" : "Pause \(emulator.machine.shortName)")

            Menu {
                Button {
                    emulator.reset(kind: .soft)
                } label: {
                    Label(MachineResetKind.soft.title, systemImage: "restart")
                }

                Button {
                    emulator.reset(kind: .hard)
                } label: {
                    Label(MachineResetKind.hard.title, systemImage: "power")
                }
            } label: {
                ToolbarIconLabel(title: "Reset", systemImage: "restart")
            }
            .frame(width: 58)
            .help("Reset \(emulator.machine.shortName)")

            Menu {
                ForEach(EmulatorSession.EmulationSpeed.allCases) { speed in
                    Button {
                        emulator.emulationSpeed = speed
                    } label: {
                        if emulator.emulationSpeed == speed {
                            Label(speed.title, systemImage: "checkmark")
                        } else {
                            Text(speed.title)
                        }
                    }
                }
            } label: {
                ToolbarIconLabel(title: emulator.emulationSpeed.toolbarTitle,
                                 systemImage: emulator.emulationSpeed.isWarpEnabled
                                    ? "forward.end.fill"
                                    : "gauge.with.dots.needle.67percent")
            }
            .frame(width: 58)
            .help("Emulation speed")
        }
        .fixedSize()
    }
}

private struct DisplayToolbarControls: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        Menu {
            ForEach(EmulatorSession.DisplayMode.allCases) { mode in
                Button {
                    emulator.displayMode = mode
                } label: {
                    if emulator.displayMode == mode {
                        Label(mode.title, systemImage: "checkmark")
                    } else {
                        Text(mode.title)
                    }
                }
            }

            Divider()

            Button {
                WindowActions.toggleFullScreen()
            } label: {
                Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
            }
        } label: {
            ToolbarIconLabel(title: emulator.displayMode.toolbarTitle,
                             systemImage: emulator.displayMode.systemImage)
        }
        .frame(width: 58)
        .help("Display size")
    }
}

private struct DisplaySettingsToolbarControls: View {
    @Binding var showingFilterPanel: Bool

    var body: some View {
        HStack(spacing: 8) {
            DisplayToolbarControls()

            VideoFilterPresetPicker()
                .fixedSize()
                .help("Display profile")

            Button {
                showingFilterPanel.toggle()
            } label: {
                ToolbarIconLabel(title: "Tune Display", systemImage: "slider.horizontal.3")
            }
            .frame(width: 58)
            .help("Custom display settings")
            .popover(isPresented: $showingFilterPanel, arrowEdge: .bottom) {
                VideoFilterToolbarPanel()
            }
        }
        .fixedSize()
    }
}

private struct DisplayOutputToolbarPicker: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        Picker("Display Output", selection: $emulator.displayOutput) {
            ForEach(emulator.machine.displayOutputs) { output in
                Label(output.toolbarTitle, systemImage: output.systemImage)
                    .tag(output)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 96)
        .help("C128 display output")
    }
}

private struct VIC20MemoryToolbarMenu: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        Menu {
            ForEach(emulator.machine.ramExpansions) { expansion in
                Button {
                    emulator.ramExpansion = expansion
                } label: {
                    if emulator.ramExpansion == expansion {
                        Label(expansion.displayTitle(for: emulator.machine), systemImage: "checkmark")
                    } else {
                        Text(expansion.displayTitle(for: emulator.machine))
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "memorychip")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                Text(toolbarTitle)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
            }
            .frame(width: 78)
        }
        .help("VIC-20 memory")
    }

    private var toolbarTitle: String {
        emulator.ramExpansion == .none ? "5K" : emulator.ramExpansion.chipTitle
    }
}

enum WindowActions {
    @MainActor
    static func toggleFullScreen() {
        let window = NSApp.keyWindow ?? NSApp.mainWindow
        window?.toggleFullScreen(nil)
    }
}

enum WindowFrameRestoration {
    @MainActor
    static func saveOpenWindowFrames() {
        let machine = EmulatedMachine.current
        let autosaveName = NSWindow.FrameAutosaveName(machine.mainWindowFrameAutosaveName)

        for window in NSApp.windows
            where window.frameAutosaveName == autosaveName {
            saveFrame(for: window, machine: machine)
            window.saveFrame(usingName: window.frameAutosaveName)
        }

        UserDefaults.standard.synchronize()
    }

    @MainActor
    static func saveFrame(for window: NSWindow, machine: EmulatedMachine) {
        guard window.isVisible,
              !window.isMiniaturized,
              !window.styleMask.contains(.fullScreen),
              window.frame.width.isFinite,
              window.frame.height.isFinite,
              window.frame.width > 0,
              window.frame.height > 0 else {
            return
        }

        EmulatorDefaults.saveMainWindowFrame(window.frame, for: machine)
    }

    @MainActor
    static func restoreFrame(for window: NSWindow, machine: EmulatedMachine) {
        guard !window.styleMask.contains(.fullScreen),
              let frame = EmulatorDefaults.loadMainWindowFrame(for: machine) else {
            return
        }

        window.setFrame(clampedToVisibleScreens(frame), display: true)
    }

    private static func clampedToVisibleScreens(_ frame: CGRect) -> CGRect {
        guard let screenFrame = destinationScreen(for: frame)?.visibleFrame else {
            return frame
        }

        var clamped = frame
        clamped.size.width = min(clamped.width, screenFrame.width)
        clamped.size.height = min(clamped.height, screenFrame.height)

        if clamped.maxX > screenFrame.maxX {
            clamped.origin.x = screenFrame.maxX - clamped.width
        }
        if clamped.minX < screenFrame.minX {
            clamped.origin.x = screenFrame.minX
        }
        if clamped.maxY > screenFrame.maxY {
            clamped.origin.y = screenFrame.maxY - clamped.height
        }
        if clamped.minY < screenFrame.minY {
            clamped.origin.y = screenFrame.minY
        }

        return clamped
    }

    private static func destinationScreen(for frame: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            return nil
        }

        let center = CGPoint(x: frame.midX, y: frame.midY)
        if let containingScreen = screens.first(where: { $0.visibleFrame.contains(center) }) {
            return containingScreen
        }

        return screens.max { lhs, rhs in
            lhs.visibleFrame.intersection(frame).area < rhs.visibleFrame.intersection(frame).area
        } ?? NSScreen.main ?? screens[0]
    }
}

private struct WindowChromeObserver: NSViewRepresentable {
    @Binding var isFullScreen: Bool
    @Binding var topChromeActive: Bool
    @Binding var bottomChromeActive: Bool
    let machine: EmulatedMachine

    func makeCoordinator() -> Coordinator {
        Coordinator(observer: self)
    }

    func makeNSView(context: Context) -> WindowChromeObserverView {
        let view = WindowChromeObserverView()
        view.coordinator = context.coordinator
        return view
    }

    func updateNSView(_ view: WindowChromeObserverView, context: Context) {
        context.coordinator.update(observer: self)
        context.coordinator.attach(to: view.window)
    }

    @MainActor
    final class Coordinator {
        private var observer: WindowChromeObserver
        private weak var window: NSWindow?
        private var mouseMonitor: Any?
        private var notificationObservers: [NSObjectProtocol] = []
        private var previousToolbarVisibility: Bool?
        private var previousAcceptsMouseMovedEvents: Bool?
        private var configuredFrameAutosaveName: String?
        private var deferredRestoreTask: Task<Void, Never>?
        private let revealThreshold: CGFloat = 74

        init(observer: WindowChromeObserver) {
            self.observer = observer
        }

        deinit {
            MainActor.assumeIsolated {
                detach()
            }
        }

        func update(observer: WindowChromeObserver) {
            self.observer = observer
            configureFrameRestoration()
            updateWindowChrome()
        }

        func attach(to window: NSWindow?) {
            guard self.window !== window else {
                configureFrameRestoration()
                updateFullScreenState()
                return
            }

            detach()
            self.window = window

            guard let window else {
                setFullScreen(false)
                return
            }

            configureFrameRestoration()

            let center = NotificationCenter.default
            notificationObservers = [
                center.addObserver(forName: NSWindow.didEnterFullScreenNotification,
                                   object: window,
                                   queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.setFullScreen(true)
                    }
                },
                center.addObserver(forName: NSWindow.didExitFullScreenNotification,
                                   object: window,
                                   queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.setFullScreen(false)
                    }
                },
                center.addObserver(forName: NSWindow.didMoveNotification,
                                   object: window,
                                   queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.saveCurrentFrame()
                    }
                },
                center.addObserver(forName: NSWindow.didResizeNotification,
                                   object: window,
                                   queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.saveCurrentFrame()
                    }
                },
                center.addObserver(forName: NSWindow.didEndLiveResizeNotification,
                                   object: window,
                                   queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.saveCurrentFrame()
                    }
                },
                center.addObserver(forName: NSWindow.willCloseNotification,
                                   object: window,
                                   queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated {
                        self?.saveCurrentFrame()
                    }
                }
            ]

            mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
                MainActor.assumeIsolated {
                    self?.handleMouseMoved(event)
                }
                return event
            }

            updateFullScreenState()
        }

        private func detach() {
            if let mouseMonitor {
                NSEvent.removeMonitor(mouseMonitor)
                self.mouseMonitor = nil
            }

            for observer in notificationObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            notificationObservers.removeAll()

            if let window,
               let previousToolbarVisibility {
                window.toolbar?.isVisible = previousToolbarVisibility
            }
            if let window,
               let previousAcceptsMouseMovedEvents {
                window.acceptsMouseMovedEvents = previousAcceptsMouseMovedEvents
            }
            previousToolbarVisibility = nil
            previousAcceptsMouseMovedEvents = nil
            configuredFrameAutosaveName = nil
            deferredRestoreTask?.cancel()
            deferredRestoreTask = nil
            window = nil
        }

        private func configureFrameRestoration() {
            let frameAutosaveName = observer.machine.mainWindowFrameAutosaveName
            guard let window,
                  configuredFrameAutosaveName != frameAutosaveName else {
                return
            }

            let autosaveName = NSWindow.FrameAutosaveName(frameAutosaveName)
            configuredFrameAutosaveName = frameAutosaveName
            window.isRestorable = true
            window.setFrameAutosaveName(autosaveName)

            if EmulatorDefaults.loadMainWindowFrame(for: observer.machine) == nil {
                window.setFrameUsingName(autosaveName, force: true)
            }
            restorePersistedFrame()
            restorePersistedFrameAfterSwiftUILayout()
        }

        private func restorePersistedFrame() {
            guard let window else {
                return
            }

            WindowFrameRestoration.restoreFrame(for: window, machine: observer.machine)
        }

        private func restorePersistedFrameAfterSwiftUILayout() {
            deferredRestoreTask?.cancel()
            deferredRestoreTask = Task { @MainActor [weak self] in
                await Task.yield()
                guard !Task.isCancelled else {
                    return
                }
                self?.restorePersistedFrame()

                try? await Task.sleep(nanoseconds: 150_000_000)
                guard !Task.isCancelled else {
                    return
                }
                self?.restorePersistedFrame()
            }
        }

        private func saveCurrentFrame() {
            guard let window else {
                return
            }

            WindowFrameRestoration.saveFrame(for: window, machine: observer.machine)
        }

        private func updateFullScreenState() {
            setFullScreen(window?.styleMask.contains(.fullScreen) == true)
        }

        private func setFullScreen(_ active: Bool) {
            if observer.isFullScreen != active {
                observer.isFullScreen = active
            }

            if active {
                if previousToolbarVisibility == nil {
                    previousToolbarVisibility = window?.toolbar?.isVisible ?? true
                }
                if previousAcceptsMouseMovedEvents == nil {
                    previousAcceptsMouseMovedEvents = window?.acceptsMouseMovedEvents ?? false
                }
                window?.acceptsMouseMovedEvents = true
                updateWindowChrome()
            } else {
                if let previousToolbarVisibility {
                    window?.toolbar?.isVisible = previousToolbarVisibility
                } else {
                    window?.toolbar?.isVisible = true
                }
                if let previousAcceptsMouseMovedEvents {
                    window?.acceptsMouseMovedEvents = previousAcceptsMouseMovedEvents
                }
                previousToolbarVisibility = nil
                previousAcceptsMouseMovedEvents = nil
                setTopChromeActive(false)
                setBottomChromeActive(false)
            }
        }

        private func handleMouseMoved(_ event: NSEvent) {
            guard observer.isFullScreen,
                  let window,
                  event.window === window,
                  let contentView = window.contentView else {
                return
            }

            let location = contentView.convert(event.locationInWindow, from: nil)
            let bounds = contentView.bounds
            let nearTop = location.y >= bounds.maxY - revealThreshold
            let nearBottom = location.y <= bounds.minY + revealThreshold

            setTopChromeActive(nearTop)
            setBottomChromeActive(nearBottom)
        }

        private func setTopChromeActive(_ active: Bool) {
            if observer.topChromeActive != active {
                observer.topChromeActive = active
            }
            updateWindowChrome()
        }

        private func setBottomChromeActive(_ active: Bool) {
            if observer.bottomChromeActive != active {
                observer.bottomChromeActive = active
            }
        }

        private func updateWindowChrome() {
            guard observer.isFullScreen else {
                return
            }

            window?.toolbar?.isVisible = observer.topChromeActive
        }
    }
}

private final class WindowChromeObserverView: NSView {
    weak var coordinator: WindowChromeObserver.Coordinator?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        coordinator?.attach(to: window)
    }
}

private extension CGRect {
    var area: CGFloat {
        guard !isNull && !isInfinite else {
            return 0
        }

        return width * height
    }
}

private struct ToolbarIconLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 18, height: 18)
        }
        .labelStyle(.iconOnly)
        .accessibilityLabel(title)
    }
}

private struct SoundToolbarControls: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @State private var showingVolumePopover = false

    var body: some View {
        HStack(spacing: 8) {
            if emulator.machine.capabilities.supportsSIDModelSelection {
                Picker("SID", selection: $emulator.sidModel) {
                    ForEach(EmulatorSession.SIDModel.allCases) { model in
                        Text(model.title).tag(model)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 104)
                .help("SID model")
            }

            Button {
                showingVolumePopover.toggle()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: volumeSymbol)
                    Text("\(emulator.soundVolume)%")
                        .monospacedDigit()
                }
            }
            .help("Master volume")
            .popover(isPresented: $showingVolumePopover, arrowEdge: .bottom) {
                VolumePopoverContent(soundEnabled: $emulator.soundEnabled,
                                     volume: volumeBinding)
            }
            .frame(width: 78)
        }
        .fixedSize()
    }

    private var volumeSymbol: String {
        if !emulator.soundEnabled || emulator.soundVolume == 0 {
            return "speaker.slash.fill"
        }

        if emulator.soundVolume < 45 {
            return "speaker.wave.1.fill"
        }

        return "speaker.wave.2.fill"
    }

    private var volumeBinding: Binding<Double> {
        Binding {
            Double(emulator.soundVolume)
        } set: { value in
            emulator.soundVolume = Int(value.rounded())
        }
    }
}

private struct VolumePopoverContent: View {
    @Binding var soundEnabled: Bool
    @Binding var volume: Double

    var body: some View {
        VStack(spacing: 10) {
            Button {
                soundEnabled.toggle()
            } label: {
                Label(soundEnabled ? "Mute" : "Unmute",
                      systemImage: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help(soundEnabled ? "Mute audio" : "Unmute audio")

            VerticalVolumeSlider(value: $volume, range: 0...100)
                .frame(width: 38, height: 132)
                .disabled(!soundEnabled)
                .accessibilityLabel("Master volume")

            Text("\(Int(volume.rounded()))%")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 86)
    }
}

private struct VerticalVolumeSlider: NSViewRepresentable {
    @Environment(\.isEnabled) private var isEnabled
    @Binding var value: Double

    let range: ClosedRange<Double>

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(value: value,
                              minValue: range.lowerBound,
                              maxValue: range.upperBound,
                              target: context.coordinator,
                              action: #selector(Coordinator.valueChanged(_:)))
        slider.isContinuous = true
        slider.isVertical = true
        slider.numberOfTickMarks = 0
        slider.allowsTickMarkValuesOnly = false
        return slider
    }

    func updateNSView(_ slider: NSSlider, context: Context) {
        context.coordinator.value = $value
        slider.minValue = range.lowerBound
        slider.maxValue = range.upperBound
        slider.isEnabled = isEnabled
        slider.isVertical = true
        slider.numberOfTickMarks = 0
        slider.allowsTickMarkValuesOnly = false

        if abs(slider.doubleValue - value) > 0.5 {
            slider.doubleValue = value
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value)
    }

    @MainActor
    final class Coordinator: NSObject {
        var value: Binding<Double>

        init(value: Binding<Double>) {
            self.value = value
        }

        @objc func valueChanged(_ sender: NSSlider) {
            value.wrappedValue = sender.doubleValue
        }
    }
}

private struct StatusPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.quaternary, in: Capsule())
    }
}

private struct RAMExpansionStatusChip: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "memorychip")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(activityColor)
                .symbolRenderingMode(.hierarchical)

            Text(emulator.ramExpansion.chipTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.13), in: Capsule())
        .help(helpText)
    }

    private var activityColor: Color {
        .secondary.opacity(0.55)
    }

    private var helpText: String {
        "\(emulator.ramExpansion.displayTitle(for: emulator.machine)) configured"
    }
}

private struct CartridgeIndicator: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(emulator.cartridgeStatus.isAttached ? .green : Color.secondary.opacity(0.32))
                    .frame(width: 8, height: 8)
                    .shadow(color: emulator.cartridgeStatus.isAttached ? .green.opacity(0.45) : .clear,
                            radius: 4)

                Image(systemName: "memorychip")
                    .foregroundStyle(.secondary)

                Text("Cart")
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .background(isPresented ? Color.secondary.opacity(0.18) : Color.clear, in: Capsule())
        .help(emulator.cartridgeStatus.isAttached ? "Cartridge attached" : "No cartridge attached")
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            CartridgePopover(isPresented: $isPresented)
        }
    }
}

private struct CartridgePopover: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @Binding var isPresented: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "memorychip")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Cartridge")
                        .font(.headline)
                    Text(statusTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                DriveInfoRow(title: "Image") {
                    Text(imageTitle)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                DriveInfoRow(title: "Type") {
                    Text(typeTitle)
                        .lineLimit(1)
                }

                DriveInfoRow(title: "Class") {
                    Text(classTitle)
                        .lineLimit(1)
                }

                DriveInfoRow(title: "ROM") {
                    Text(romTitle)
                        .lineLimit(1)
                }

                DriveInfoRow(title: "Banks") {
                    Text(bankTitle)
                        .lineLimit(1)
                }
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    emulator.detachCartridge()
                    isPresented = false
                } label: {
                    Label("Detach", systemImage: "eject")
                }
                .disabled(!emulator.cartridgeStatus.isAttached)

                Button {
                    openCartridgePanel()
                } label: {
                    Label(emulator.cartridgeStatus.isAttached ? "Replace..." : "Attach...",
                          systemImage: "memorychip")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 300)
    }

    private var statusTitle: String {
        emulator.cartridgeStatus.isAttached ? "Attached" : "No cartridge attached"
    }

    private var imageTitle: String {
        guard let imagePath = emulator.cartridgeStatus.imagePath,
              !imagePath.isEmpty else {
            return "No image"
        }

        return URL(fileURLWithPath: imagePath).lastPathComponent
    }

    private var typeTitle: String {
        if let cartridgeName = emulator.cartridgeStatus.cartridgeName,
           !cartridgeName.isEmpty {
            return cartridgeName
        }

        return emulator.cartridgeStatus.isAttached ? "Cartridge" : "None"
    }

    private var classTitle: String {
        guard emulator.cartridgeStatus.isAttached else {
            return "None"
        }

        let flags = emulator.cartridgeStatus.cartridgeFlags
        var classes: [String] = []

        if flags & CartridgeInfoFlag.game != 0 {
            classes.append("Game")
        }
        if flags & CartridgeInfoFlag.freezer != 0 {
            classes.append("Freezer")
        }
        if flags & CartridgeInfoFlag.utility != 0 {
            classes.append("Utility")
        }
        if flags & CartridgeInfoFlag.ramExpansion != 0 {
            classes.append("RAM expansion")
        }
        if flags & CartridgeInfoFlag.generic != 0 {
            classes.append("Generic")
        }

        return classes.isEmpty ? "Cartridge" : classes.joined(separator: ", ")
    }

    private var romTitle: String {
        guard emulator.cartridgeStatus.isAttached else {
            return "None"
        }

        guard emulator.cartridgeStatus.romSize > 0 else {
            return "Unknown"
        }

        return ByteCountFormatter.string(fromByteCount: Int64(emulator.cartridgeStatus.romSize),
                                         countStyle: .memory)
    }

    private var bankTitle: String {
        guard emulator.cartridgeStatus.isAttached else {
            return "None"
        }

        let bankCount = emulator.cartridgeStatus.bankCount
        let chipCount = emulator.cartridgeStatus.chipCount
        guard bankCount > 0 else {
            return "Unknown"
        }

        let bankUnit = bankCount == 1 ? "bank" : "banks"
        let chipUnit = chipCount == 1 ? "chip" : "chips"
        return "\(bankCount) \(bankUnit), \(chipCount) \(chipUnit)"
    }

    private func openCartridgePanel() {
        let panel = NSOpenPanel()
        panel.title = "Attach Cartridge"
        panel.message = "Choose a CRT cartridge image."
        panel.prompt = "Attach"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = Self.cartridgeImageTypes

        isPresented = false
        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        emulator.attachCartridge(url: url)
    }

    private static let cartridgeImageTypes: [UTType] = {
        let types = ["crt"].compactMap { UTType(filenameExtension: $0) }
        return types.isEmpty ? [.data] : types
    }()
}

private enum CartridgeInfoFlag {
    static let generic: UInt32 = 0x0001
    static let ramExpansion: UInt32 = 0x0002
    static let freezer: UInt32 = 0x0004
    static let game: UInt32 = 0x0008
    static let utility: UInt32 = 0x0010
}

private struct DriveIndicator: View {
    @State private var isPresented = false

    let drive: DriveActivity

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.35)) { context in
            let blinkOn = Int(context.date.timeIntervalSinceReferenceDate / 0.35).isMultiple(of: 2)

            Button {
                isPresented.toggle()
            } label: {
                HStack(spacing: 6) {
                    if drive.hasMultipleSlots {
                        DriveSlotLEDStack(drive: drive, blinkOn: blinkOn)
                    } else {
                        let color = indicatorColor(blinkOn: blinkOn)

                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                            .shadow(color: color.opacity(drive.isActive ? 0.45 : 0),
                                    radius: 4)
                    }

                    Text("\(drive.unit)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    if drive.isFastAccessEnabled {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.yellow)
                    }

                    if let headPositionText = drive.headPositionText {
                        Text(headPositionText)
                            .font(.system(.caption2, design: .monospaced).weight(.medium))
                            .foregroundStyle(headPositionColor)
                            .frame(minWidth: 24, alignment: .leading)
                            .baselineOffset(-1)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .background(isPresented ? Color.secondary.opacity(0.18) : Color.clear, in: Capsule())
            .help("Drive \(drive.unit)")
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                DrivePopover(isPresented: $isPresented, drive: drive)
            }
        }
    }

    private func indicatorColor(blinkOn: Bool) -> Color {
        if drive.hasErrorStatus {
            return blinkOn ? .red : .red.opacity(0.25)
        }

        let color = drive.ledColor.displayColor
        return drive.isActive ? color : color.opacity(0.28)
    }

    private var headPositionColor: Color {
        if drive.hasErrorStatus {
            return .red.opacity(0.9)
        }

        return .secondary
    }
}

private struct DriveSlotLEDStack: View {
    let drive: DriveActivity
    let blinkOn: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(drive.slots) { slot in
                let color = indicatorColor(for: slot)

                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .shadow(color: color.opacity(slot.isActive ? 0.5 : 0),
                            radius: 3)
            }
        }
        .frame(width: 14, alignment: .leading)
    }

    private func indicatorColor(for slot: DriveSlotActivity) -> Color {
        if drive.hasErrorStatus {
            return blinkOn ? .red : .red.opacity(0.25)
        }

        let color = slot.ledColor.displayColor
        return slot.isActive ? color : color.opacity(0.28)
    }
}

private struct DrivePopover: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @Binding var isPresented: Bool
    @State private var autorun = false

    let drive: DriveActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "externaldrive")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Drive \(drive.unit)")
                        .font(.headline)
                    Text("\(drive.driveType.title) • \(drive.driveType.busTitle)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                VStack(spacing: 6) {
                    ForEach(drive.slots) { slot in
                        DriveSlotPopoverRow(slot: slot,
                                            unit: drive.unit,
                                            showsDriveNumber: drive.hasMultipleSlots,
                                            isActive: slot.isActive,
                                            hasError: drive.hasErrorStatus) {
                            openDiskPanel(for: slot.driveNumber)
                        } onDetach: {
                            emulator.detachDisk(from: drive.unit, driveNumber: slot.driveNumber)
                        }
                    }
                }

                DriveInfoRow(title: "Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 7, height: 7)
                        Text(statusTitle)
                    }
                }

                DriveInfoRow(title: "Formats") {
                    Text(diskImageFormatDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                DriveInfoRow(title: "Access") {
                    Picker("Access", selection: accessModeBinding) {
                        ForEach(DriveAccessMode.allCases) { mode in
                            Label(mode.title, systemImage: mode.systemImage).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .help(accessModeHelp)
                }

                if let headPositionText = drive.headPositionText {
                    DriveInfoRow(title: "Track") {
                        Text(headPositionText)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }

            Divider()

            Toggle("Run after attach", isOn: $autorun)

            HStack(spacing: 8) {
                Button {
                    emulator.resetDrive(drive.unit)
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private var statusTitle: String {
        if let driveStatusText = drive.driveStatusText,
           !driveStatusText.isEmpty {
            if !drive.hasErrorStatus {
                return "Ready"
            }

            return driveStatusText
        }

        if drive.hasErrorStatus {
            return "Error \(drive.driveStatusCode)"
        }

        return hasDiskImage ? "Ready" : "No disk"
    }

    private var statusColor: Color {
        if drive.hasErrorStatus {
            return .red
        }

        return hasDiskImage ? .green : Color.secondary.opacity(0.45)
    }

    private var hasDiskImage: Bool {
        drive.slots.contains { $0.hasDiskImage }
    }

    private var accessModeBinding: Binding<DriveAccessMode> {
        Binding {
            emulator.driveAccessMode(for: drive.unit)
        } set: { accessMode in
            emulator.setDriveAccessMode(accessMode, for: drive.unit)
        }
    }

    private var accessModeHelp: String {
        switch emulator.driveAccessMode(for: drive.unit) {
        case .native:
            return "Use true drive emulation without virtual traps"
        case .fast:
            return "Enable virtual traps and disable true drive emulation for faster disk access"
        }
    }

    private func openDiskPanel(for driveNumber: Int) {
        let panel = NSOpenPanel()
        panel.title = "Attach Disk"
        panel.message = "Choose a \(diskImageFormatDescription) image for \(driveAddress(for: driveNumber))."
        panel.prompt = "Attach"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = allowedDiskImageTypes

        isPresented = false
        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        emulator.attachDisk(to: drive.unit, driveNumber: driveNumber, url: url, autorun: autorun)
    }

    private func driveAddress(for driveNumber: Int) -> String {
        drive.hasMultipleSlots ? "drive \(drive.unit):\(driveNumber)" : "drive \(drive.unit)"
    }

    private var diskImageFormatDescription: String {
        drive.driveType.supportedDiskImageDescription
    }

    private var allowedDiskImageTypes: [UTType] {
        let types = drive.driveType.supportedDiskImageTypes.compactMap { type in
            UTType(filenameExtension: type.rawValue)
        }

        return types.isEmpty ? [.data] : types
    }
}

private struct DriveSlotPopoverRow: View {
    let slot: DriveSlotActivity
    let unit: Int
    let showsDriveNumber: Bool
    let isActive: Bool
    let hasError: Bool
    let onAttach: () -> Void
    let onDetach: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)
                .shadow(color: indicatorColor.opacity(isActive ? 0.45 : 0),
                        radius: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))

                Text(diskTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if let diskKind {
                Text(diskKind)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            Button {
                onAttach()
            } label: {
                Label("Attach", systemImage: "externaldrive.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Attach disk to \(title.lowercased())")

            Button {
                onDetach()
            } label: {
                Label("Eject", systemImage: "eject")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!slot.hasDiskImage)
            .help("Detach disk from \(title.lowercased())")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
    }

    private var title: String {
        showsDriveNumber ? "Drive \(unit):\(slot.driveNumber)" : "Disk"
    }

    private var diskTitle: String {
        guard let imagePath = slot.imagePath,
              !imagePath.isEmpty else {
            return "No disk attached"
        }

        return URL(fileURLWithPath: imagePath).lastPathComponent
    }

    private var diskKind: String? {
        guard let imagePath = slot.imagePath else {
            return nil
        }

        let pathExtension = URL(fileURLWithPath: imagePath).pathExtension
        return pathExtension.isEmpty ? nil : pathExtension.uppercased()
    }

    private var indicatorColor: Color {
        if hasError {
            return .red
        }

        let color = slot.ledColor.displayColor
        return isActive ? color : color.opacity(0.28)
    }
}

private struct DriveInfoRow<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
    }
}

private extension DriveLEDColor {
    var displayColor: Color {
        switch self {
        case .red:
            return .red
        case .green:
            return .green
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(EmulatorSession())
}
