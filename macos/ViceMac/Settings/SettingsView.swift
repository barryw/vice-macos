import AppKit
import GameController
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        TabView {
            MachineSettingsPane()
                .tabItem {
                    Label("Machine", systemImage: "cpu")
                }

            SoundSettingsPane()
                .tabItem {
                    Label("Sound", systemImage: "speaker.wave.2")
                }

            if showsControlSettings {
                ControlSettingsPane()
                    .tabItem {
                        Label("Controls", systemImage: "gamecontroller")
                    }
            }

            DriveSettingsPane()
                .tabItem {
                    Label("Drives", systemImage: "externaldrive")
                }

            DisplaySettingsPane()
                .tabItem {
                    Label("Display", systemImage: "display")
                }

            AIAssistantSettingsPane()
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
        }
        .frame(width: 580, height: 540)
    }

    private var showsControlSettings: Bool {
        !emulator.availableControlPorts.isEmpty
    }
}

private struct AIAssistantSettingsPane: View {
    @EnvironmentObject private var aiSettings: AIAssistantSettings

    var body: some View {
        SettingsPane {
            Section("Provider") {
                Picker("Provider", selection: $aiSettings.provider) {
                    ForEach(AIAssistantProvider.allCases) { provider in
                        Label(provider.title, systemImage: provider.systemImage)
                            .tag(provider)
                    }
                }
            }

            if aiSettings.provider.isServiceProvider {
                Section("Authentication") {
                    LabeledContent("Method") {
                        Label("Provider API key", systemImage: "key")
                            .foregroundStyle(.secondary)
                    }

                    LabeledContent("Account") {
                        Button {
                            openAuthenticationPage()
                        } label: {
                            Label(aiSettings.provider.authenticationButtonTitle,
                                  systemImage: "person.crop.circle.badge.checkmark")
                        }
                        .disabled(aiSettings.provider.authenticationURL == nil)
                    }

                    LabeledContent("API key") {
                        HStack(spacing: 8) {
                            SecureField("API key", text: $aiSettings.apiKey)
                                .textFieldStyle(.roundedBorder)

                            Button {
                                aiSettings.apiKey = ""
                            } label: {
                                Label("Clear API Key", systemImage: "xmark.circle")
                            }
                            .labelStyle(.iconOnly)
                            .disabled(aiSettings.apiKey.isEmpty)
                            .help("Clear API key")
                        }
                    }
                }

                Section("Model") {
                    LabeledContent("Model") {
                        HStack(spacing: 8) {
                            TextField("Model ID", text: $aiSettings.model)
                                .textFieldStyle(.roundedBorder)

                            Menu {
                                ForEach(modelOptions) { model in
                                    Button(model.menuTitle) {
                                        aiSettings.model = model.id
                                    }
                                }
                            } label: {
                                Label("Choose Model", systemImage: "list.bullet")
                            }
                            .labelStyle(.iconOnly)
                            .disabled(aiSettings.availableModels.isEmpty)
                            .help("Choose fetched model")
                        }
                    }

                    LabeledContent("Models") {
                        HStack(spacing: 10) {
                            Button {
                                Task {
                                    await aiSettings.fetchAvailableModels()
                                }
                            } label: {
                                Label("Fetch Models", systemImage: "arrow.clockwise")
                            }
                            .disabled(!aiSettings.canFetchModels)

                            if aiSettings.isFetchingModels {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            if let message = aiSettings.modelFetchMessage {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(modelStatusColor)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                        }
                    }
                }
            } else {
                Section("Assistant") {
                    LabeledContent("Toolbar") {
                        Label("Hidden", systemImage: "eye.slash")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Availability") {
                LabeledContent("Toolbar") {
                    Label(toolbarStatusTitle, systemImage: toolbarStatusImage)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(aiSettings.isConfigured ? .green : .secondary)
                }

                LabeledContent("VM tools") {
                    Text("Input, no-side-effect memory reads, no-side-effect memory writes, and bulk memory reads.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var modelOptions: [AIAssistantModel] {
        let selectedModel = aiSettings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        var options = aiSettings.availableModels
        if !selectedModel.isEmpty,
           !options.contains(where: { $0.id == selectedModel }) {
            options.insert(AIAssistantModel(id: selectedModel), at: 0)
        }

        return options
    }

    private var toolbarStatusTitle: String {
        aiSettings.isConfigured ? "Assistant visible" : "Hidden until provider, API key, and model are set"
    }

    private var toolbarStatusImage: String {
        aiSettings.isConfigured ? "checkmark.circle.fill" : "eye.slash"
    }

    private var modelStatusColor: Color {
        guard let message = aiSettings.modelFetchMessage else {
            return .secondary
        }

        return message.hasPrefix("Fetched") ? .green : .secondary
    }

    private func openAuthenticationPage() {
        guard let url = aiSettings.provider.authenticationURL else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

private struct MachineSettingsPane: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        SettingsPane {
            Section("Machine") {
                LabeledContent("Model") {
                    if emulator.machine.family == .pet {
                        Picker("Model", selection: $emulator.petModel) {
                            ForEach(PETMachineModel.allCases) { model in
                                Text(model.displayName).tag(model)
                            }
                        }
                        .labelsHidden()
                    } else {
                        Label(emulator.machineDisplayName, systemImage: "cpu")
                            .foregroundStyle(.secondary)
                    }
                }

                if emulator.machine.capabilities.supportsVideoStandardSelection {
                    Picker("Video standard", selection: $emulator.videoStandard) {
                        ForEach(EmulatorSession.VideoStandard.allCases) { standard in
                            Text(standard.rawValue).tag(standard)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Picker("Speed", selection: $emulator.emulationSpeed) {
                    ForEach(EmulatorSession.EmulationSpeed.allCases) { speed in
                        Text(speed.title).tag(speed)
                    }
                }

                Toggle("Paused", isOn: $emulator.isPaused)
            }

            if emulator.machine.capabilities.supportsRAMExpansion {
                Section("Memory") {
                    Picker("RAM expansion", selection: $emulator.ramExpansion) {
                        ForEach(emulator.machine.ramExpansions) { expansion in
                            Text(expansion.displayTitle(for: emulator.machine)).tag(expansion)
                        }
                    }

                    if emulator.machine.usesVIC20MemoryExpansion {
                        LabeledContent("Blocks") {
                            Text(emulator.ramExpansion.detailTitle(for: emulator.machine))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if !emulator.machine.romSlots.isEmpty {
                Section("ROM Images") {
                    ForEach(emulator.machine.romSlots) { image in
                        ROMImageSettingsRow(image: image)
                    }
                }
            }
        }
    }
}

private struct ROMImageSettingsRow: View {
    @EnvironmentObject private var emulator: EmulatorSession

    let image: MachineROMSlot

    var body: some View {
        LabeledContent {
            HStack(spacing: 10) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(displayName)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(displayDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                ControlGroup {
                    Button {
                        chooseROM()
                    } label: {
                        Label("Choose \(image.title) ROM", systemImage: "folder")
                    }
                    .help("Choose \(image.title) ROM")

                    Button {
                        emulator.setROMImage(image, path: nil)
                    } label: {
                        Label("Use Default \(image.title) ROM", systemImage: "arrow.counterclockwise")
                    }
                    .disabled(!isCustom)
                    .help("Use VICE default")
                }
                .labelStyle(.iconOnly)
                .controlGroupStyle(.compactMenu)
            }
        } label: {
            Label(image.title, systemImage: image.systemImage)
        }
    }

    private var path: String? {
        emulator.romImages.path(for: image)
    }

    private var isCustom: Bool {
        path != nil
    }

    private var displayName: String {
        guard let path else {
            return "VICE default"
        }

        return URL(fileURLWithPath: path).lastPathComponent
    }

    private var displayDetail: String {
        path ?? emulator.romResourceValue(for: image)
    }

    private func chooseROM() {
        let panel = NSOpenPanel()
        panel.title = "Choose \(image.title) ROM"
        panel.message = "Choose a \(image.title) ROM image."
        panel.prompt = "Choose"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        if let path {
            panel.directoryURL = URL(fileURLWithPath: path).deletingLastPathComponent()
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        emulator.setROMImage(image, path: url.path)
    }
}

private struct SoundSettingsPane: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        SettingsPane {
            Section("Playback") {
                LabeledContent("Output") {
                    Label("CoreAudio", systemImage: "checkmark.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }

                Toggle("Sound", isOn: $emulator.soundEnabled)

                LabeledContent("Volume") {
                    HStack(spacing: 10) {
                        Slider(value: volumeBinding, in: 0...100)
                            .disabled(!emulator.soundEnabled)

                        Text("\(emulator.soundVolume)%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }

            if emulator.machine.capabilities.supportsSIDModelSelection {
                Section("SID") {
                    Picker("Model", selection: $emulator.sidModel) {
                        ForEach(EmulatorSession.SIDModel.allCases) { model in
                            Text(model.title).tag(model)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var volumeBinding: Binding<Double> {
        Binding {
            Double(emulator.soundVolume)
        } set: { value in
            emulator.soundVolume = Int(value.rounded())
        }
    }
}

private struct ControlSettingsPane: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @State private var selectedDeviceID: UUID?
    @State private var editorState: ControlDeviceEditorState?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Devices")
                .font(.headline)

            VStack(spacing: 0) {
                Table(emulator.controlDevices, selection: selectedDeviceIDBinding) {
                    TableColumn("Name") { device in
                        HStack(spacing: 6) {
                            Label(device.name, systemImage: device.systemImage)

                            if !emulator.connectionState(for: device).isConnected {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                                    .help(emulator.connectionState(for: device).title)
                            }
                        }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                editDevice(device)
                            }
                    }

                    TableColumn("Type") { device in
                        Text(device.kind.title)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                editDevice(device)
                            }
                    }
                }
                .frame(minHeight: 280)

                Divider()

                HStack(spacing: 6) {
                    Menu {
                        Button {
                            beginAddingDevice(kind: .keyboard)
                        } label: {
                            Label("Keyboard", systemImage: ControlDeviceKind.keyboard.systemImage)
                        }

                        Button {
                            beginAddingDevice(kind: .joystick)
                        } label: {
                            Label("Joystick", systemImage: ControlDeviceKind.joystick.systemImage)
                        }
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 18, height: 18)
                    }
                    .menuStyle(.button)
                    .help("Add control device")

                    Button {
                        removeSelectedDevice()
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 18, height: 18)
                    }
                    .disabled(selectedDevice == nil)
                    .help("Remove selected device")

                    Button {
                        editSelectedDevice()
                    } label: {
                        Image(systemName: "pencil")
                            .frame(width: 18, height: 18)
                    }
                    .disabled(selectedDevice == nil)
                    .help("Edit selected device")

                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(.separator.opacity(0.55))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .sheet(item: $editorState) { state in
            ControlDeviceEditorSheet(state: state) { device in
                emulator.saveControlDevice(device)
                selectedDeviceID = device.id
            }
            .environmentObject(emulator)
        }
        .onChange(of: emulator.controlDevices) { _, devices in
            if let selectedDeviceID,
               devices.contains(where: { $0.id == selectedDeviceID }) {
                return
            }

            selectedDeviceID = devices.first?.id
        }
    }

    private var selectedDeviceIDBinding: Binding<UUID?> {
        Binding {
            if let selectedDeviceID,
               emulator.controlDevice(id: selectedDeviceID) != nil {
                return selectedDeviceID
            }

            return emulator.controlDevices.first?.id
        } set: { id in
            selectedDeviceID = id
        }
    }

    private var selectedDevice: ControlDeviceConfiguration? {
        guard let id = selectedDeviceIDBinding.wrappedValue else {
            return nil
        }

        return emulator.controlDevice(id: id)
    }

    private func beginAddingDevice(kind: ControlDeviceKind) {
        editorState = ControlDeviceEditorState(mode: .add,
                                               device: emulator.makeControlDevice(kind: kind))
    }

    private func editSelectedDevice() {
        guard let selectedDevice else {
            return
        }

        editDevice(selectedDevice)
    }

    private func editDevice(_ device: ControlDeviceConfiguration) {
        selectedDeviceID = device.id
        editorState = ControlDeviceEditorState(mode: .edit, device: device)
    }

    private func removeSelectedDevice() {
        guard let selectedDevice else {
            return
        }

        emulator.removeControlDevice(id: selectedDevice.id)
        selectedDeviceID = emulator.controlDevices.first?.id
    }
}

private struct ControlDeviceEditorState: Identifiable {
    enum Mode {
        case add
        case edit
    }

    let id = UUID()
    let mode: Mode
    let device: ControlDeviceConfiguration

    var title: String {
        switch mode {
        case .add:
            return "Add \(device.kind.title)"
        case .edit:
            return "Edit \(device.name)"
        }
    }

    var primaryButtonTitle: String {
        switch mode {
        case .add:
            return "Add"
        case .edit:
            return "Save"
        }
    }
}

private struct ControlDeviceEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var emulator: EmulatorSession
    @State private var device: ControlDeviceConfiguration

    let mode: ControlDeviceEditorState.Mode
    let title: String
    let primaryButtonTitle: String
    let onSave: (ControlDeviceConfiguration) -> Void

    init(state: ControlDeviceEditorState,
         onSave: @escaping (ControlDeviceConfiguration) -> Void) {
        mode = state.mode
        title = state.title
        primaryButtonTitle = state.primaryButtonTitle
        self.onSave = onSave
        _device = State(initialValue: state.device)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.semibold))

            Form {
                Section("Device") {
                    LabeledContent("Name") {
                        TextField("Name", text: $device.name)
                            .textFieldStyle(.roundedBorder)
                    }

                    LabeledContent("Type") {
                        Label(device.kind.title, systemImage: device.kind.systemImage)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Mapping") {
                    switch device.kind {
                    case .keyboard:
                        KeyboardJoystickMappingEditor(mapping: $device.keyboard)
                    case .joystick:
                        GameControllerJoystickMappingEditor(mapping: $device.joystick)
                            .environmentObject(emulator)
                    }
                }
            }
            .formStyle(.grouped)

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(primaryButtonTitle) {
                    onSave(device.normalized())
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 520)
        .frame(minHeight: device.kind == .joystick ? 560 : 460)
    }
}

private struct KeyboardJoystickMappingEditor: View {
    @Binding var mapping: KeyboardJoystickMapping

    var body: some View {
        ForEach(JoystickAction.allCases) { action in
            LabeledContent(action.title) {
                KeyCaptureButton(keyCode: keyCodeBinding(for: action))
            }
        }
    }

    private func keyCodeBinding(for action: JoystickAction) -> Binding<UInt16> {
        Binding {
            mapping.keyCode(for: action)
        } set: { keyCode in
            mapping.setKeyCode(keyCode, for: action)
        }
    }
}

private struct GameControllerJoystickMappingEditor: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @Binding var mapping: GameControllerJoystickMapping

    var body: some View {
        Picker("Hardware", selection: preferredControllerBinding) {
            Text("Any Connected Controller").tag("")

            ForEach(emulator.sortedGameControllerNames, id: \.self) { name in
                Text(name).tag(name)
            }
        }

        if !connectionState.isConnected {
            LabeledContent("Status") {
                Label(connectionState.title, systemImage: connectionState.systemImage)
                    .foregroundStyle(.orange)
            }
        }

        LabeledContent("Dead zone") {
            HStack(spacing: 10) {
                Slider(value: $mapping.deadZone, in: 0.05...0.95)

                Text(deadZoneText)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .trailing)
            }
        }

        ForEach(JoystickAction.allCases) { action in
            LabeledContent(action.title) {
                JoystickControlCaptureButton(control: controlBinding(for: action),
                                             preferredControllerName: mapping.preferredControllerName,
                                             deadZone: mapping.deadZone)
            }
        }
    }

    private var preferredControllerBinding: Binding<String> {
        Binding {
            mapping.preferredControllerName ?? ""
        } set: { name in
            mapping.preferredControllerName = name.isEmpty ? nil : name
        }
    }

    private func controlBinding(for action: JoystickAction) -> Binding<GameControllerControl> {
        Binding {
            mapping.control(for: action)
        } set: { control in
            mapping.setControl(control, for: action)
        }
    }

    private var deadZoneText: String {
        "\(Int((mapping.deadZone * 100).rounded()))%"
    }

    private var connectionState: ControlDeviceConnectionState {
        if let preferredControllerName = mapping.preferredControllerName {
            return emulator.gameControllerNames.contains(preferredControllerName)
                ? .connected
                : .unavailable("Missing \(preferredControllerName)")
        }

        return emulator.hasGameControllers ? .connected : .unavailable("No controller connected")
    }
}

private struct JoystickControlCaptureButton: View {
    @Binding var control: GameControllerControl

    let preferredControllerName: String?
    let deadZone: Double

    @State private var isCapturing = false
    @State private var captureTask: Task<Void, Never>?

    var body: some View {
        Button {
            startCapturing()
        } label: {
            Text(isCapturing ? "Press control" : control.title)
                .frame(minWidth: 150)
        }
        .onDisappear {
            stopCapturing()
        }
    }

    private func startCapturing() {
        guard !isCapturing else {
            return
        }

        isCapturing = true
        captureTask = Task { @MainActor in
            while !Task.isCancelled {
                if let capturedControl = capturedControl() {
                    control = capturedControl
                    stopCapturing()
                    return
                }

                try? await Task.sleep(for: .milliseconds(25))
            }
        }
    }

    private func stopCapturing() {
        isCapturing = false
        captureTask?.cancel()
        captureTask = nil
    }

    private func capturedControl() -> GameControllerControl? {
        let deadZone = Float(deadZone)
        let controllers = GCController.controllers()
        let preferredControllers: [GCController]

        if let preferredControllerName {
            preferredControllers = controllers.filter { displayName(for: $0) == preferredControllerName }
        } else {
            preferredControllers = controllers
        }

        for controller in preferredControllers {
            if let control = GameControllerControl.capturedControl(from: controller, deadZone: deadZone) {
                return control
            }
        }

        return nil
    }

    private func displayName(for controller: GCController) -> String {
        controller.vendorName ?? "Game Controller"
    }
}

private struct KeyCaptureButton: View {
    @Binding var keyCode: UInt16
    @State private var isCapturing = false

    var body: some View {
        Button {
            isCapturing = true
        } label: {
            Text(isCapturing ? "Press a key" : KeyboardKeyName.title(for: keyCode))
                .monospacedDigit()
                .frame(minWidth: 112)
        }
        .background {
            KeyCaptureMonitor(isCapturing: $isCapturing) { capturedKeyCode in
                keyCode = capturedKeyCode
            }
        }
    }
}

private struct KeyCaptureMonitor: NSViewRepresentable {
    @Binding var isCapturing: Bool
    let onCapture: (UInt16) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isCapturing: $isCapturing, onCapture: onCapture)
    }

    func makeNSView(context: Context) -> NSView {
        NSView(frame: .zero)
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.update(isCapturing: $isCapturing, onCapture: onCapture)
    }

    final class Coordinator {
        private var isCapturing: Binding<Bool>
        private var onCapture: (UInt16) -> Void
        private var monitor: Any?

        init(isCapturing: Binding<Bool>, onCapture: @escaping (UInt16) -> Void) {
            self.isCapturing = isCapturing
            self.onCapture = onCapture
            updateMonitor()
        }

        deinit {
            removeMonitor()
        }

        func update(isCapturing: Binding<Bool>, onCapture: @escaping (UInt16) -> Void) {
            self.isCapturing = isCapturing
            self.onCapture = onCapture
            updateMonitor()
        }

        private func updateMonitor() {
            if isCapturing.wrappedValue {
                installMonitor()
            } else {
                removeMonitor()
            }
        }

        private func installMonitor() {
            guard monitor == nil else {
                return
            }

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self else {
                    return event
                }

                onCapture(event.keyCode)
                isCapturing.wrappedValue = false
                removeMonitor()
                return nil
            }
        }

        private func removeMonitor() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
        }
    }
}

private struct DisplaySettingsPane: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        SettingsPane {
            Section("Window") {
                Picker("Display size", selection: $emulator.displayMode) {
                    ForEach(EmulatorSession.DisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }

            Section("Display Chain") {
                VideoFilterPresetPicker()
                VideoFilterSliders()
            }
        }
    }
}

private struct DriveSettingsPane: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        SettingsPane {
            ForEach(emulator.driveConfigurations.indices, id: \.self) { index in
                DriveSettingsSection(drive: $emulator.driveConfigurations[index])
            }
        }
    }
}

private struct DriveSettingsSection: View {
    @EnvironmentObject private var emulator: EmulatorSession

    @Binding var drive: DriveConfiguration
    @State private var volumeBeforeEdit: Int?

    var body: some View {
        Section("Drive \(drive.unit)") {
            Toggle("Attached", isOn: $drive.isAttached)

            Picker("Type", selection: $drive.driveType) {
                ForEach(emulator.machine.capabilities.driveTypes) { type in
                    Text(type.title).tag(type)
                }
            }
            .disabled(!drive.isAttached)

            LabeledContent("Hardware") {
                Text(hardwareDetail)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .disabled(!drive.isAttached)

            LabeledContent("Formats") {
                Text(drive.driveType.supportedDiskImageDescription)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .disabled(!drive.isAttached)

            Picker("Access", selection: $drive.accessMode) {
                ForEach(DriveAccessMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .disabled(!drive.isAttached)

            Toggle("Drive sounds", isOn: $drive.soundEnabled)
                .disabled(!drive.isAttached)

            HStack(spacing: 12) {
                Text("Sound volume")

                Slider(value: volumeBinding,
                       in: 0...100,
                       onEditingChanged: handleVolumeEditingChanged)
                    .disabled(!drive.isAttached || !drive.soundEnabled)

                Text("\(drive.soundVolume)%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }

    private var volumeBinding: Binding<Double> {
        Binding {
            Double(drive.soundVolume)
        } set: { value in
            drive.soundVolume = min(max(Int(value.rounded()), 0), 100)
        }
    }

    private func handleVolumeEditingChanged(_ isEditing: Bool) {
        if isEditing {
            volumeBeforeEdit = drive.soundVolume
            return
        }

        defer {
            volumeBeforeEdit = nil
        }

        guard let volumeBeforeEdit,
              volumeBeforeEdit != drive.soundVolume else {
            return
        }

        emulator.previewDriveSound(for: drive)
    }

    private var hardwareDetail: String {
        let mechanism = drive.driveType.slotCount == 1 ? "single drive" : "\(drive.driveType.slotCount) drives"
        return "\(drive.driveType.busTitle), \(mechanism)"
    }
}

private struct SettingsPane<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        Form {
            content
        }
        .formStyle(.grouped)
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }
}

#Preview {
    SettingsView()
        .environmentObject(EmulatorSession())
        .environmentObject(AIAssistantSettings())
}
