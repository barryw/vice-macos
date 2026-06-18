import AppKit
import GameController
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @AppStorage("vice.settings.selectedPane") private var selectedPaneID = SettingsPaneID.machine.rawValue

    var body: some View {
        TabView(selection: $selectedPaneID) {
            MachineSettingsPane()
                .tabItem {
                    Label("Machine", systemImage: "cpu")
                }
                .tag(SettingsPaneID.machine.rawValue)

            MediaSettingsPane()
                .tabItem {
                    Label("Media", systemImage: "externaldrive.badge.plus")
                }
                .tag(SettingsPaneID.media.rawValue)

            MetadataSettingsPane()
                .tabItem {
                    Label("Metadata", systemImage: "tag")
                }
                .tag(SettingsPaneID.metadata.rawValue)

            SoundSettingsPane()
                .tabItem {
                    Label("Sound", systemImage: "speaker.wave.2")
                }
                .tag(SettingsPaneID.sound.rawValue)

            if showsControlSettings {
                ControlSettingsPane()
                    .tabItem {
                        Label("Controls", systemImage: "gamecontroller")
                    }
                    .tag(SettingsPaneID.controls.rawValue)
            }

            KeyboardSettingsPane()
                .tabItem {
                    Label("Keyboard", systemImage: "keyboard")
                }
                .tag(SettingsPaneID.keyboard.rawValue)

            DriveSettingsPane()
                .tabItem {
                    Label("Storage", systemImage: "externaldrive")
                }
                .tag(SettingsPaneID.drives.rawValue)

            PrintingSettingsPane()
                .tabItem {
                    Label("Printing", systemImage: "printer")
                }
                .tag(SettingsPaneID.printing.rawValue)

            if showsNetworkSettings {
                NetworkSettingsPane()
                    .tabItem {
                        Label("Network", systemImage: "network")
                    }
                    .tag(SettingsPaneID.network.rawValue)
            }

            DisplaySettingsPane()
                .tabItem {
                    Label("Display", systemImage: "display")
                }
                .tag(SettingsPaneID.display.rawValue)

            AIAssistantSettingsPane()
                .tabItem {
                    Label("AI", systemImage: "sparkles")
                }
                .tag(SettingsPaneID.ai.rawValue)
        }
        .frame(width: 900, height: 700)
        .navigationTitle(selectedPane.title)
        .background(SettingsWindowConfigurator(title: selectedPane.title))
        .onAppear(perform: normalizeSelectedPane)
        .onChange(of: showsControlSettings) { _, _ in
            normalizeSelectedPane()
        }
        .onChange(of: showsNetworkSettings) { _, _ in
            normalizeSelectedPane()
        }
    }

    private var showsControlSettings: Bool {
        !emulator.availableControlPorts.isEmpty
    }

    private var showsNetworkSettings: Bool {
        emulator.machine.capabilities.supportsNetworking
    }

    private var selectedPane: SettingsPaneID {
        SettingsPaneID(rawValue: selectedPaneID) ?? .machine
    }

    private func normalizeSelectedPane() {
        if selectedPane == .controls,
           !showsControlSettings {
            selectedPaneID = SettingsPaneID.keyboard.rawValue
        }

        guard selectedPane == .network,
              !showsNetworkSettings else {
            return
        }

        selectedPaneID = SettingsPaneID.media.rawValue
    }
}

private enum SettingsPaneID: String {
    case machine
    case media
    case metadata
    case sound
    case controls
    case keyboard
    case drives
    case printing
    case network
    case display
    case ai

    var title: String {
        switch self {
        case .machine:
            return "Machine"
        case .media:
            return "Media"
        case .metadata:
            return "Metadata"
        case .sound:
            return "Sound"
        case .controls:
            return "Controls"
        case .keyboard:
            return "Keyboard"
        case .drives:
            return "Storage"
        case .printing:
            return "Printing"
        case .network:
            return "Network"
        case .display:
            return "Display"
        case .ai:
            return "AI"
        }
    }
}

private struct MachineHardRestartRequest: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let restartButtonTitle: String
    let applyChange: @MainActor () -> Void
}

private extension View {
    func machineHardRestartConfirmation(_ request: Binding<MachineHardRestartRequest?>) -> some View {
        alert(request.wrappedValue?.title ?? "Restart Machine?",
              isPresented: Binding {
                  request.wrappedValue != nil
              } set: { isPresented in
                  if !isPresented {
                      request.wrappedValue = nil
                  }
              },
              presenting: request.wrappedValue) { presentedRequest in
            Button(presentedRequest.restartButtonTitle, role: .destructive) {
                presentedRequest.applyChange()
                request.wrappedValue = nil
            }

            Button("Cancel", role: .cancel) {
                request.wrappedValue = nil
            }
        } message: { presentedRequest in
            Text(presentedRequest.message)
        }
    }
}

private struct SettingsWindowConfigurator: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        configureWhenReady(view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        configureWhenReady(nsView)
    }

    private func configureWhenReady(_ view: NSView) {
        DispatchQueue.main.async {
            guard let window = view.window else {
                return
            }

            window.title = title
            window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
            window.standardWindowButton(.zoomButton)?.isEnabled = false
        }
    }
}

private struct SettingsSliderControl: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueTitle: String
    var isEnabled = true
    var valueWidth: CGFloat = 48
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        HStack(spacing: 10) {
            Slider(value: $value,
                   in: range,
                   onEditingChanged: onEditingChanged)
                .disabled(!isEnabled)

            Text(valueTitle)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: valueWidth, alignment: .trailing)
        }
    }
}

private struct SettingsPercentSlider: View {
    @Binding var value: Int
    var isEnabled = true
    var valueWidth: CGFloat = 44
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        SettingsSliderControl(value: doubleBinding,
                              range: 0...100,
                              valueTitle: "\(value)%",
                              isEnabled: isEnabled,
                              valueWidth: valueWidth,
                              onEditingChanged: onEditingChanged)
    }

    private var doubleBinding: Binding<Double> {
        Binding {
            Double(value)
        } set: { newValue in
            value = min(max(Int(newValue.rounded()), 0), 100)
        }
    }
}

private struct AIAssistantSettingsPane: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @EnvironmentObject private var aiSettings: AIAssistantSettings
    @EnvironmentObject private var aiDocumentLibrary: AIDocumentLibraryStore
    @State private var selectedDocumentIDs: Set<UUID> = []
    @State private var importErrorMessage: String?

    var body: some View {
        SettingsCustomPane {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    modelSettingsForm
                    documentLibraryForm
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            aiSettings.refreshAvailability()
        }
        .onChange(of: currentMachineID) { _, _ in
            selectedDocumentIDs = []
        }
        .alert("Import Failed",
               isPresented: Binding {
                   importErrorMessage != nil
               } set: { isPresented in
                   if !isPresented {
                       importErrorMessage = nil
                       aiDocumentLibrary.clearLastError()
                   }
               }) {
            Button("OK", role: .cancel) {
                importErrorMessage = nil
                aiDocumentLibrary.clearLastError()
            }
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    private var modelSettingsForm: some View {
        Form {
            Section("AI Agent") {
                LabeledContent("AI features") {
                    Toggle("Enable assistant", isOn: enabledBinding)
                }

                if aiSettings.isEnabled {
                    LabeledContent("Model type") {
                        Picker("Model type", selection: modelBackendBinding) {
                            Label(AIAssistantModelBackend.openAICompatible.title,
                                  systemImage: AIAssistantModelBackend.openAICompatible.systemImage)
                                .tag(AIAssistantModelBackend.openAICompatible)

                            Label(AIAssistantModelBackend.foundation.title,
                                  systemImage: AIAssistantModelBackend.foundation.systemImage)
                                .tag(AIAssistantModelBackend.foundation)
                                .disabled(true)
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }

                    if aiSettings.modelBackend == .foundation {
                        LabeledContent("Status") {
                            Label("Paused", systemImage: "pause.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            if aiSettings.isEnabled,
               aiSettings.modelBackend == .openAICompatible {
                Section("Provider") {
                    LabeledContent("Provider") {
                        Picker("Provider", selection: remoteProviderBinding) {
                            ForEach(AIAssistantRemoteProvider.allCases) { provider in
                                Label(provider.title, systemImage: provider.systemImage)
                                    .tag(provider)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 220)
                    }

                    LabeledContent("Base URL") {
                        TextField("Base URL", text: remoteBaseURLBinding)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 320)
                    }

                    LabeledContent(aiSettings.remoteProviderRequiresAPIKey ? "API key" : "API key") {
                        SecureField(aiSettings.remoteProviderRequiresAPIKey ? "Required" : "Optional",
                                    text: remoteAPIKeyBinding)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 320)
                    }

                    LabeledContent("Models") {
                        HStack(spacing: 8) {
                            Picker("Models", selection: selectedRemoteModelBinding) {
                                if aiSettings.selectedRemoteModelID.isEmpty {
                                    Text("No model selected").tag("")
                                }

                                ForEach(aiSettings.remoteModels) { model in
                                    Text(model.displayName).tag(model.id)
                                }
                            }
                            .labelsHidden()
                            .frame(minWidth: 260)
                            .disabled(aiSettings.remoteModels.isEmpty && aiSettings.selectedRemoteModelID.isEmpty)

                            Button {
                                Task {
                                    await aiSettings.fetchRemoteModels()
                                }
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            .disabled(aiSettings.isFetchingRemoteModels)

                            if aiSettings.isFetchingRemoteModels {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }

                    LabeledContent("Connection") {
                        Label(aiSettings.remoteConnectionStatus.title,
                              systemImage: aiSettings.remoteConnectionStatus.systemImage)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(remoteConnectionColor)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            Section("Availability") {
                LabeledContent("Toolbar") {
                    Label(toolbarStatusTitle, systemImage: toolbarStatusImage)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(aiSettings.isConfigured ? .green : .secondary)
                }

                LabeledContent("VICE tools") {
                    SettingsValueText("Input, memory, debugger, display color, VICE resource, and indexed document tools available to the selected model", lineLimit: nil)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LabeledContent("Foundation") {
                    HStack(spacing: 10) {
                        Label(foundationAvailabilityTitle,
                              systemImage: foundationAvailabilityImage)
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)

                        Button {
                            aiSettings.refreshAvailability()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var documentLibraryForm: some View {
        Form {
            Section("Document Library") {
                LabeledContent("Machine") {
                    Label(emulator.machineDisplayName, systemImage: "cpu")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text("Books")
                            .font(.callout.weight(.medium))

                        Spacer()

                        Button {
                            chooseDocuments()
                        } label: {
                            Label("Add", systemImage: "plus")
                        }
                        .disabled(aiDocumentLibrary.isImporting)

                        Button {
                            removeSelectedDocuments()
                        } label: {
                            Label("Remove", systemImage: "minus")
                        }
                        .disabled(selectedDocumentIDs.isEmpty || aiDocumentLibrary.isImporting)
                    }

                    SettingsTableContainer(minHeight: 250) {
                        List(selection: $selectedDocumentIDs) {
                            ForEach(filteredDocuments) { document in
                                AIDocumentLibrarySettingsRow(document: document)
                                    .tag(document.id)
                            }
                        }
                        .listStyle(.inset)
                        .overlay {
                            if filteredDocuments.isEmpty {
                                ContentUnavailableView("No Books",
                                                       systemImage: "book.closed")
                            }
                        }
                    } footer: {
                        AIDocumentLibraryFooter(documents: filteredDocuments,
                                                isImporting: aiDocumentLibrary.isImporting)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var enabledBinding: Binding<Bool> {
        Binding {
            aiSettings.isEnabled
        } set: { enabled in
            aiSettings.setEnabled(enabled)
        }
    }

    private var modelBackendBinding: Binding<AIAssistantModelBackend> {
        Binding {
            aiSettings.modelBackend
        } set: { backend in
            aiSettings.setModelBackend(backend)
        }
    }

    private var remoteProviderBinding: Binding<AIAssistantRemoteProvider> {
        Binding {
            aiSettings.remoteProvider
        } set: { provider in
            aiSettings.setRemoteProvider(provider)
        }
    }

    private var remoteBaseURLBinding: Binding<String> {
        Binding {
            aiSettings.remoteBaseURLString
        } set: { baseURLString in
            aiSettings.setRemoteBaseURLString(baseURLString)
        }
    }

    private var remoteAPIKeyBinding: Binding<String> {
        Binding {
            aiSettings.credential(for: aiSettings.remoteProvider)
        } set: { apiKey in
            aiSettings.setCredential(apiKey, for: aiSettings.remoteProvider)
        }
    }

    private var selectedRemoteModelBinding: Binding<String> {
        Binding {
            aiSettings.selectedRemoteModelID
        } set: { modelID in
            aiSettings.setSelectedRemoteModelID(modelID)
        }
    }

    private var toolbarStatusTitle: String {
        if aiSettings.isConfigured {
            return "Assistant visible"
        }

        if !aiSettings.isEnabled {
            return "Hidden until AI features are enabled"
        }

        switch aiSettings.modelBackend {
        case .foundation:
            return "Hidden because Foundation is paused"
        case .openAICompatible:
            if aiSettings.remoteProviderRequiresAPIKey,
               aiSettings.credential(for: aiSettings.remoteProvider).isEmpty {
                return "Hidden until an API key is saved"
            }

            if aiSettings.selectedRemoteModelID.isEmpty {
                return "Hidden until a model is selected"
            }

            return "Hidden until the provider is configured"
        }
    }

    private var toolbarStatusImage: String {
        aiSettings.isConfigured ? "checkmark.circle.fill" : "eye.slash"
    }

    private var remoteConnectionColor: Color {
        if aiSettings.remoteConnectionStatus.isConnected {
            return .green
        }

        if aiSettings.remoteConnectionStatus.isFailed {
            return .orange
        }

        return .secondary
    }

    private var foundationAvailabilityTitle: String {
        "Paused; \(aiSettings.availability.title)"
    }

    private var foundationAvailabilityImage: String {
        aiSettings.availability.systemImage
    }

    private var filteredDocuments: [AIDocumentRecord] {
        aiDocumentLibrary.documents(for: currentMachineID)
    }

    private var currentMachineID: String {
        emulator.machine.id.rawValue
    }

    private func chooseDocuments() {
        let panel = NSOpenPanel()
        panel.title = "Add Documentation"
        panel.prompt = "Add"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.pdf]

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              !panel.urls.isEmpty else {
            return
        }

        Task {
            await aiDocumentLibrary.importPDFs(panel.urls,
                                               machineID: currentMachineID)
            if let message = aiDocumentLibrary.lastErrorMessage {
                importErrorMessage = message
            }
        }
    }

    private func removeSelectedDocuments() {
        aiDocumentLibrary.removeDocuments(ids: selectedDocumentIDs)
        selectedDocumentIDs = []
    }
}

private struct AIDocumentLibrarySettingsRow: View {
    let document: AIDocumentRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusSystemImage)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(statusColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(document.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(document.originalFilename)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 10)

            Label(statusTitle, systemImage: statusSystemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(statusColor)
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .frame(width: 132, alignment: .leading)

            Text("\(document.pageCount) pages")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)

            Text("\(document.chunkCount) chunks")
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.vertical, 4)
        .help(helpText)
    }

    private var statusTitle: String {
        switch document.status {
        case .indexed:
            return "Ready to search"
        case .failed:
            return "Failed"
        }
    }

    private var statusSystemImage: String {
        switch document.status {
        case .indexed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var statusColor: Color {
        switch document.status {
        case .indexed:
            return .green
        case .failed:
            return .orange
        }
    }

    private var helpText: String {
        if let errorMessage = document.errorMessage,
           !errorMessage.isEmpty {
            return errorMessage
        }

        return "\(document.title) indexed and ready to search."
    }
}

private struct AIDocumentLibraryFooter: View {
    let documents: [AIDocumentRecord]
    let isImporting: Bool

    var body: some View {
        HStack(spacing: 8) {
            if isImporting {
                ProgressView()
                    .controlSize(.small)
                Text("Indexing")
                    .foregroundStyle(.secondary)
            } else {
                Label("\(readyCount) ready", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Label("\(chunkCount) chunks", systemImage: "text.page")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    private var readyCount: Int {
        documents.filter { $0.status == .indexed }.count
    }

    private var chunkCount: Int {
        documents.reduce(0) { $0 + $1.chunkCount }
    }
}

private struct MachineSettingsPane: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @State private var hardRestartRequest: MachineHardRestartRequest?

    var body: some View {
        SettingsPane {
            Section("Machine") {
                LabeledContent("Model") {
                    switch emulator.machine.family {
                    case .c64:
                        Picker("Model", selection: $emulator.c64Model) {
                            ForEach(C64MachineModel.allCases) { model in
                                Text(model.displayName).tag(model)
                            }
                        }
                        .labelsHidden()
                    case .c128:
                        Picker("Model", selection: $emulator.c128Model) {
                            ForEach(C128MachineModel.allCases) { model in
                                Text(model.displayName).tag(model)
                            }
                        }
                        .labelsHidden()
                    case .pet:
                        Picker("Model", selection: $emulator.petModel) {
                            ForEach(PETMachineModel.allCases) { model in
                                Text(model.displayName).tag(model)
                            }
                        }
                        .labelsHidden()
                    case .vic20, .ted:
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

                if emulator.machine.capabilities.supportsSystemTimeSync {
                    Toggle("Sync system time with machine", isOn: $emulator.syncSystemTime)
                }
            }

            Section("Behavior") {
                Picker("Speed", selection: $emulator.emulationSpeed) {
                    ForEach(EmulatorSession.EmulationSpeed.allCases) { speed in
                        Text(speed.title).tag(speed)
                    }
                }

                Toggle("Pause when app is inactive", isOn: $emulator.sessionBehavior.pauseWhenAppInactive)
                Toggle("Paused", isOn: $emulator.isPaused)
            }

            if emulator.machine.capabilities.supportsRAMExpansion {
                Section("Memory") {
                    Picker("RAM expansion", selection: ramExpansionBinding) {
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
                Section("ROM images") {
                    ForEach(emulator.machine.romSlots) { image in
                        ROMImageSettingsRow(image: image)
                    }
                }
            }
        }
        .machineHardRestartConfirmation($hardRestartRequest)
    }

    private var ramExpansionBinding: Binding<RAMExpansion> {
        Binding {
            emulator.ramExpansion
        } set: { expansion in
            guard expansion != emulator.ramExpansion else {
                return
            }

            let plan = expansion.resourcePlan(for: emulator.machine)
            guard emulator.isMachineRunning,
                  plan.requiresHardReset else {
                emulator.ramExpansion = expansion
                return
            }

            hardRestartRequest = MachineHardRestartRequest(
                title: "Restart to Change RAM Expansion?",
                message: "Changing RAM expansion rewires the machine memory map. Restarting the machine will lose unsaved work inside the emulator.",
                restartButtonTitle: "Change and Restart"
            ) {
                emulator.ramExpansion = expansion
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
                        Label("Use default \(image.title) ROM", systemImage: "arrow.counterclockwise")
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

private struct MediaSettingsPane: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        SettingsPane {
            Section("Opening media") {
                Picker("Dropped files", selection: $emulator.mediaBehavior.openBehavior) {
                    ForEach(MediaOpenBehavior.allCases) { behavior in
                        Text(behavior.title).tag(behavior)
                    }
                }
                .pickerStyle(.segmented)

                LabeledContent("Default action") {
                    Label(emulator.mediaBehavior.openBehavior.detail,
                          systemImage: emulator.mediaBehavior.openBehavior.systemImage)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                }

                Toggle("Warp while loading media", isOn: $emulator.mediaBehavior.warpDuringAutostart)

                Toggle("Let VICE manage true drive emulation during autostart",
                       isOn: $emulator.mediaBehavior.useTrueDriveDuringAutostart)
            }

            if emulator.machine.capabilities.supportsCartridges {
                Section("Cartridge") {
                    LabeledContent("Status") {
                        SettingsValueText(cartridgeStatusTitle, truncationMode: .middle)
                    }

                    LabeledContent("Image") {
                        HStack(spacing: 8) {
                            SettingsValueText(cartridgeImageTitle, truncationMode: .middle)

                            Spacer(minLength: 8)

                            Button("Choose...") {
                                chooseCartridge()
                            }

                            Button("Eject") {
                                emulator.detachCartridge()
                            }
                            .disabled(!emulator.cartridgeStatus.isAttached)
                        }
                    }
                }
            }

            if emulator.machine.capabilities.supportsTape {
                TapeSettingsSection()
            }

            Section("Snapshots") {
                LabeledContent("Saved contents") {
                    SettingsValueText(emulator.snapshotConfiguration.summaryTitle,
                                      lineLimit: 2)
                }

                Toggle("Include ROM images", isOn: $emulator.snapshotConfiguration.includesROMImages)

                Toggle("Include attached disks", isOn: $emulator.snapshotConfiguration.includesAttachedDisks)
            }
        }
    }

    private var cartridgeStatusTitle: String {
        guard emulator.cartridgeStatus.isAttached else {
            return "No cartridge inserted"
        }

        if let cartridgeName = emulator.cartridgeStatus.cartridgeName,
           !cartridgeName.isEmpty {
            return cartridgeName
        }

        return "Cartridge inserted"
    }

    private var cartridgeImageTitle: String {
        guard let path = emulator.cartridgeStatus.imagePath,
              !path.isEmpty else {
            return "None"
        }

        return URL(fileURLWithPath: path).lastPathComponent
    }

    private func chooseCartridge() {
        let panel = NSOpenPanel()
        panel.title = "Choose Cartridge"
        panel.message = "Choose a CRT cartridge image."
        panel.prompt = "Choose"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = CartridgeImageFileType.allCases
            .compactMap { UTType(filenameExtension: $0.rawValue) }

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        emulator.attachCartridge(url: url)
    }
}

private struct TapeSettingsSection: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        Section("Tape") {
            Toggle("Datasette", isOn: $emulator.tapeConfiguration.isDatasetteEnabled)

            LabeledContent("Tape image") {
                HStack(spacing: 8) {
                    SettingsValueText(tapeImageTitle, truncationMode: .middle)

                    Spacer(minLength: 8)

                    Button("Choose...") {
                        chooseTape()
                    }
                    .disabled(!emulator.tapeConfiguration.isDatasetteEnabled)

                    Button("Eject") {
                        emulator.detachTape()
                    }
                    .disabled(emulator.tapeImagePath == nil)
                }
            }
            .disabled(!emulator.tapeConfiguration.isDatasetteEnabled)

            LabeledContent("Transport") {
                HStack(spacing: 6) {
                    ForEach(transportCommands) { command in
                        Button {
                            emulator.controlTape(command)
                        } label: {
                            Image(systemName: command.systemImage)
                                .frame(width: 18, height: 18)
                        }
                        .help(command.title)
                    }
                }
                .buttonStyle(.borderless)
            }
            .disabled(!emulator.tapeConfiguration.isDatasetteEnabled)

            Toggle("Datasette sound", isOn: $emulator.tapeConfiguration.soundEnabled)
                .disabled(!emulator.tapeConfiguration.isDatasetteEnabled)

            LabeledContent("Sound volume") {
                SettingsPercentSlider(value: $emulator.tapeConfiguration.soundVolume,
                                      isEnabled: emulator.tapeConfiguration.isDatasetteEnabled
                                      && emulator.tapeConfiguration.soundEnabled)
            }
        }
    }

    private var transportCommands: [TapeControlCommand] {
        [.rewind, .play, .stop, .fastForward, .resetCounter]
    }

    private var tapeImageTitle: String {
        guard let path = emulator.tapeImagePath,
              !path.isEmpty else {
            return "None"
        }

        return URL(fileURLWithPath: path).lastPathComponent
    }

    private func chooseTape() {
        let panel = NSOpenPanel()
        panel.title = "Choose Tape"
        panel.message = "Choose a TAP tape image."
        panel.prompt = "Choose"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: AutostartMediaFileType.tap.rawValue)]
            .compactMap { $0 }

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        emulator.attachTape(url: url)
    }
}

private struct PrintingSettingsPane: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        SettingsPane {
            Section("Printer") {
                Toggle("Printer on device \(emulator.printerConfiguration.deviceNumber)",
                       isOn: $emulator.printerConfiguration.isEnabled)

                Picker("Model", selection: $emulator.printerConfiguration.model) {
                    ForEach(PrinterEmulationModel.allCases) { model in
                        Text(model.shortTitle).tag(model)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!emulator.printerConfiguration.isEnabled)

                Picker("Device", selection: $emulator.printerConfiguration.deviceNumber) {
                    Text("4").tag(4)
                    Text("5").tag(5)
                    Text("6").tag(6)
                }
                .pickerStyle(.segmented)
                .disabled(!emulator.printerConfiguration.isEnabled)

                LabeledContent("GEOS driver") {
                    SettingsValueText(emulator.printerConfiguration.geosDriverTitle)
                }

                LabeledContent("Output") {
                    SettingsValueText(emulator.printerConfiguration.model.supportsPagePreview
                                      ? "Page images"
                                      : "Text stream")
                }
            }

            Section("Queue") {
                LabeledContent("Printed pages") {
                    HStack(spacing: 8) {
                        SettingsValueText(emulator.printQueueStatusTitle)

                        Spacer(minLength: 8)

                        Button("Open Queue...") {
                            openWindow(id: "print-queue")
                            emulator.refreshPrintQueue()
                        }

                        Button("Clear") {
                            emulator.clearPrintQueue()
                        }
                        .disabled(emulator.printSpoolPages.isEmpty)
                    }
                }

                LabeledContent("Spool folder") {
                    HStack(spacing: 8) {
                        SettingsValueText(emulator.printSpoolDirectoryURL.path,
                                          truncationMode: .middle)

                        Button("Reveal") {
                            NSWorkspace.shared.activateFileViewerSelecting([emulator.printSpoolDirectoryURL])
                        }
                    }
                }
            }
        }
    }
}

private struct NetworkSettingsPane: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @EnvironmentObject private var qLinkReloaded: QLinkReloadedService
    @State private var hardRestartRequest: MachineHardRestartRequest?
    @State private var selectedQLinkProfileID = ""
    @State private var qLinkProfilePendingDeletion: QLinkReloadedRegistrationProfile?
    @State private var confirmsQLinkDiskProfileRemoval = false

    var body: some View {
        SettingsPane {
            Section("Modem") {
                Toggle("Modem", isOn: modemEnabledBinding)

                Picker("Interface", selection: modemInterfaceBinding) {
                    ForEach(emulator.availableModemInterfaces) { modemInterface in
                        Label(modemInterface.title,
                              systemImage: modemInterface.systemImage)
                            .tag(modemInterface)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!emulator.networkModem.isEnabled)

                LabeledContent("Hardware") {
                    SettingsValueText(emulator.networkModem.interface.detailTitle)
                }

                if emulator.networkModem.interface.requiresACIAAddress {
                    Picker("Address", selection: modemACIAAddressBinding) {
                        ForEach(emulator.availableModemACIAAddresses) { address in
                            Text(address.title).tag(address)
                        }
                    }
                    .disabled(!emulator.networkModem.isEnabled)

                    if let terminalHint = emulator.networkModem.terminalSelectionHint(for: emulator.machine) {
                        LabeledContent("Terminal") {
                            SettingsValueText(terminalHint,
                                              lineLimit: 2)
                        }
                    }
                }

                if !emulator.networkModem.interface.requiresACIAAddress,
                   let terminalHint = emulator.networkModem.terminalSelectionHint(for: emulator.machine) {
                    LabeledContent("Terminal") {
                        SettingsValueText(terminalHint,
                                          lineLimit: 2)
                    }
                }

                Picker("Speed", selection: $emulator.networkModem.baudRate) {
                    ForEach(emulator.networkModem.supportedBaudRates, id: \.self) { baudRate in
                        Text("\(baudRate)").tag(baudRate)
                    }
                }
                .disabled(!emulator.networkModem.isEnabled)

                Picker("Connection", selection: $emulator.networkModem.transportMode) {
                    ForEach(NetworkTransportMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!emulator.networkModem.isEnabled)

                Toggle("Echo commands", isOn: $emulator.networkModem.echoCommands)
                    .disabled(!emulator.networkModem.isEnabled)

                Toggle("Verbose result codes", isOn: $emulator.networkModem.verboseResultCodes)
                    .disabled(!emulator.networkModem.isEnabled)

                LabeledContent("Status") {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(emulator.networkModemStatus.title)
                            .foregroundStyle(statusColor)
                        SettingsValueText(emulator.networkModemStatus.detailTitle,
                                          lineLimit: 2)
                    }
                }

                if emulator.networkModem.usesActiveUserPort {
                    LabeledContent("User port") {
                        SettingsValueText("System time sync is off while the modem uses the user port.",
                                          lineLimit: 2)
                    }
                }
            }

            Section("Dialing") {
                LabeledContent("Default host") {
                    TextField("Host", text: $emulator.networkModem.defaultDialHost)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!emulator.networkModem.isEnabled)
                }

                LabeledContent("Default port") {
                    TextField("Port",
                              value: $emulator.networkModem.defaultDialPort,
                              format: .number)
                        .frame(width: 86)
                        .disabled(!emulator.networkModem.isEnabled)
                }

                LabeledContent("Command") {
                    SettingsValueText(emulator.networkModem.dialCommandPreview)
                        .font(.system(.body, design: .monospaced))
                }
            }

            if qLinkReloaded.supports(machine: emulator.machine) {
                Section("Q-Link Reloaded") {
                    LabeledContent("Disk") {
                        HStack(spacing: 8) {
                            SettingsValueText(qLinkDiskTitle,
                                              lineLimit: 2,
                                              truncationMode: .middle)
                            Button {
                                qLinkReloaded.chooseDisk(for: emulator.machine)
                            } label: {
                                Label("Choose Disk", systemImage: "externaldrive")
                            }
                            .disabled(qLinkReloaded.isConnecting)
                        }
                    }

                    LabeledContent("Disk Profile") {
                        if let diskProfile = qLinkReloaded.configuredDiskRegistrationProfile {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(diskProfile.displayTitle)
                                SettingsValueText("Access \(diskProfile.accessNumber)")
                            }
                        } else {
                            SettingsValueText("No profile on disk")
                        }
                    }

                    if qLinkReloaded.registrationProfiles.isEmpty {
                        LabeledContent("Saved Profile") {
                            SettingsValueText("No saved profiles")
                        }
                    } else {
                        Picker("Saved Profile", selection: qLinkProfileSelection) {
                            ForEach(qLinkReloaded.registrationProfiles) { profile in
                                Text(profile.displayTitle).tag(profile.id)
                            }
                        }

                        if let selectedQLinkProfile {
                            LabeledContent("Access") {
                                SettingsValueText(selectedQLinkProfile.accessNumber)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Button {
                                qLinkReloaded.copyRegistrationFromConfiguredDisk()
                                syncSelectedQLinkProfile()
                            } label: {
                                Label("Copy from Disk", systemImage: "square.and.arrow.down")
                            }
                            .disabled(qLinkReloaded.configuredDiskRegistrationProfile == nil)

                            Button {
                                if let selectedQLinkProfile {
                                    qLinkReloaded.restoreRegistration(accessNumber: selectedQLinkProfile.accessNumber)
                                }
                            } label: {
                                Label("Restore to Disk", systemImage: "arrow.down.doc")
                            }
                            .disabled(selectedQLinkProfile == nil || !qLinkReloaded.hasConfiguredDisk)

                            Button(role: .destructive) {
                                confirmsQLinkDiskProfileRemoval = true
                            } label: {
                                Label("Remove from Disk", systemImage: "externaldrive.badge.minus")
                            }
                            .disabled(qLinkReloaded.configuredDiskRegistrationProfile == nil)
                        }

                        HStack(spacing: 8) {
                            Button(role: .destructive) {
                                qLinkProfilePendingDeletion = selectedQLinkProfile
                            } label: {
                                Label("Delete Saved", systemImage: "trash")
                            }
                            .disabled(selectedQLinkProfile == nil)

                            Button {
                                qLinkReloaded.refreshRegistrationProfiles()
                                qLinkReloaded.refreshConfiguredDiskRegistrationProfile()
                                syncSelectedQLinkProfile()
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                        }
                    }
                }
            }

            Section("Test Line") {
                LabeledContent("Dial") {
                    SettingsValueText(emulator.networkModem.testDialCommand)
                        .font(.system(.body, design: .monospaced))
                }
            }

            Section("Incoming Calls") {
                Toggle("Accept incoming calls", isOn: $emulator.networkModem.acceptsIncomingCalls)
                    .disabled(!emulator.networkModem.isEnabled)

                LabeledContent("Port") {
                    TextField("Port",
                              value: $emulator.networkModem.incomingPort,
                              format: .number)
                        .frame(width: 86)
                        .disabled(!emulator.networkModem.isEnabled
                                  || !emulator.networkModem.acceptsIncomingCalls)
                }

                Stepper(value: $emulator.networkModem.autoAnswerRings,
                        in: 0...9) {
                    Text(autoAnswerTitle)
                }
                .disabled(!emulator.networkModem.isEnabled
                          || !emulator.networkModem.acceptsIncomingCalls)
            }
        }
        .machineHardRestartConfirmation($hardRestartRequest)
        .onAppear {
            qLinkReloaded.refreshRegistrationProfiles()
            qLinkReloaded.refreshConfiguredDiskRegistrationProfile()
            syncSelectedQLinkProfile()
        }
        .onChange(of: qLinkReloaded.registrationProfiles) { _, _ in
            syncSelectedQLinkProfile()
        }
        .confirmationDialog("Remove Q-Link profile?",
                            isPresented: qLinkProfileRemovalConfirmationBinding,
                            titleVisibility: .visible,
                            presenting: qLinkProfilePendingDeletion) { profile in
            Button("Remove \(profile.displayTitle)", role: .destructive) {
                qLinkReloaded.deleteRegistration(accessNumber: profile.accessNumber)
                syncSelectedQLinkProfile()
            }
            Button("Cancel", role: .cancel) {
                qLinkProfilePendingDeletion = nil
            }
        } message: { profile in
            Text("This removes the saved profile from Keychain. It does not change any disk image.")
        }
        .confirmationDialog("Remove Q-Link profile from disk?",
                            isPresented: $confirmsQLinkDiskProfileRemoval,
                            titleVisibility: .visible) {
            Button("Remove from Disk", role: .destructive) {
                qLinkReloaded.removeRegistrationFromConfiguredDisk()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This clears the profile from the managed Q-Link disk copy. It does not delete saved Keychain profiles.")
        }
    }

    private var selectedQLinkProfile: QLinkReloadedRegistrationProfile? {
        qLinkReloaded.registrationProfiles.first { $0.id == selectedQLinkProfileID }
            ?? qLinkReloaded.registrationProfiles.first
    }

    private var qLinkProfileSelection: Binding<String> {
        Binding {
            if selectedQLinkProfileID.isEmpty {
                qLinkReloaded.registrationProfiles.first?.id ?? ""
            } else {
                selectedQLinkProfileID
            }
        } set: { profileID in
            selectedQLinkProfileID = profileID
        }
    }

    private var qLinkProfileRemovalConfirmationBinding: Binding<Bool> {
        Binding {
            qLinkProfilePendingDeletion != nil
        } set: { isPresented in
            if !isPresented {
                qLinkProfilePendingDeletion = nil
            }
        }
    }

    private var qLinkDiskTitle: String {
        guard let configuredDiskTitle = qLinkReloaded.configuredDiskTitle else {
            return "No disk selected"
        }

        if let configuredDiskVersionTitle = qLinkReloaded.configuredDiskVersionTitle {
            return "\(configuredDiskTitle) (\(configuredDiskVersionTitle))"
        }

        return configuredDiskTitle
    }

    private func syncSelectedQLinkProfile() {
        let profiles = qLinkReloaded.registrationProfiles
        guard !profiles.contains(where: { $0.id == selectedQLinkProfileID }) else {
            return
        }

        selectedQLinkProfileID = profiles.first?.id ?? ""
    }

    private var modemEnabledBinding: Binding<Bool> {
        Binding {
            emulator.networkModem.isEnabled
        } set: { isEnabled in
            guard isEnabled != emulator.networkModem.isEnabled else {
                return
            }

            let actionTitle = isEnabled ? "Turn On and Restart" : "Turn Off and Restart"
            confirmModemHardwareChange(title: isEnabled ? "Restart to Turn On Modem?" : "Restart to Turn Off Modem?",
                                       message: "Changing modem hardware while the machine is running requires a hard restart. Restarting the machine will lose unsaved work inside the emulator.",
                                       restartButtonTitle: actionTitle,
                                       requiresRestart: emulator.networkModem.isEnabled || isEnabled) {
                var modem = emulator.networkModem
                modem.isEnabled = isEnabled
                emulator.networkModem = modem
            }
        }
    }

    private var modemInterfaceBinding: Binding<NetworkModemInterface> {
        Binding {
            emulator.networkModem.interface
        } set: { modemInterface in
            guard modemInterface != emulator.networkModem.interface else {
                return
            }

            confirmModemHardwareChange(title: "Restart to Change Modem Interface?",
                                       message: "Changing the modem interface swaps the emulated hardware. Restarting the machine will lose unsaved work inside the emulator.",
                                       restartButtonTitle: "Change and Restart",
                                       requiresRestart: emulator.networkModem.isEnabled) {
                var modem = emulator.networkModem
                modem.interface = modemInterface
                emulator.networkModem = modem
            }
        }
    }

    private var modemACIAAddressBinding: Binding<NetworkModemACIAAddress> {
        Binding {
            emulator.networkModem.aciaBaseAddress
        } set: { address in
            guard address != emulator.networkModem.aciaBaseAddress else {
                return
            }

            confirmModemHardwareChange(title: "Restart to Change Modem Address?",
                                       message: "Changing the ACIA address moves the emulated modem hardware. Restarting the machine will lose unsaved work inside the emulator.",
                                       restartButtonTitle: "Change and Restart",
                                       requiresRestart: emulator.networkModem.isEnabled) {
                var modem = emulator.networkModem
                modem.aciaBaseAddress = address
                emulator.networkModem = modem
            }
        }
    }

    private func confirmModemHardwareChange(title: String,
                                            message: String,
                                            restartButtonTitle: String,
                                            requiresRestart: Bool,
                                            applyChange: @escaping @MainActor () -> Void) {
        guard emulator.isMachineRunning,
              requiresRestart else {
            applyChange()
            return
        }

        hardRestartRequest = MachineHardRestartRequest(title: title,
                                                       message: message,
                                                       restartButtonTitle: restartButtonTitle) {
            applyChange()
            emulator.reset(kind: .hard)
        }
    }

    private var statusColor: Color {
        switch emulator.networkModemStatus.state {
        case .ready, .connected:
            return .green
        case .ringing:
            return .accentColor
        case .error:
            return .red
        case .disabled, .waitingForMachine:
            return .secondary
        }
    }

    private var autoAnswerTitle: String {
        let rings = emulator.networkModem.autoAnswerRings
        guard rings > 0 else {
            return "Auto-answer off"
        }

        return rings == 1 ? "Auto-answer after 1 ring" : "Auto-answer after \(rings) rings"
    }
}

private struct SoundSettingsPane: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        SettingsPane {
            Section("Playback") {
                LabeledContent("Output") {
                    SettingsValueText("CoreAudio")
                }

                Toggle("Sound", isOn: $emulator.soundEnabled)

                LabeledContent("Volume") {
                    SettingsPercentSlider(value: $emulator.soundVolume,
                                          isEnabled: emulator.soundEnabled)
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

                    Picker("Layout", selection: $emulator.sidConfiguration.layout) {
                        ForEach(SIDLayout.allCases) { layout in
                            Text(layout.shortTitle).tag(layout)
                        }
                    }
                    .pickerStyle(.segmented)

                    if emulator.sidConfiguration.layout.extraSIDCount >= 1 {
                        Picker("Second SID", selection: $emulator.sidConfiguration.secondAddress) {
                            ForEach(SIDAddressPreset.allCases) { address in
                                Text(address.title).tag(address)
                            }
                        }
                    }

                    if emulator.sidConfiguration.layout.extraSIDCount >= 2 {
                        Picker("Third SID", selection: $emulator.sidConfiguration.thirdAddress) {
                            ForEach(SIDAddressPreset.allCases) { address in
                                Text(address.title).tag(address)
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct ControlSettingsPane: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @State private var selectedDeviceID: UUID?
    @State private var editorState: ControlDeviceEditorState?
    @State private var removalCandidate: ControlDeviceConfiguration?

    var body: some View {
        SettingsCustomPane {
            VStack(alignment: .leading, spacing: 10) {
                PointerControlSettingsSection()

                Text("Devices")
                    .font(.headline)

                SettingsTableContainer(minHeight: 245) {
                    Table(emulator.controlDevices, selection: selectedDeviceIDBinding) {
                        TableColumn("Name") { device in
                            controlDeviceTableCell(for: device) {
                                HStack(spacing: 6) {
                                    Label(device.name, systemImage: device.systemImage)

                                    if !emulator.connectionState(for: device).isConnected {
                                        Image(systemName: "exclamationmark.triangle")
                                            .foregroundStyle(.orange)
                                            .help(emulator.connectionState(for: device).title)
                                    }
                                }
                            }
                        }

                        TableColumn("Type") { device in
                            controlDeviceTableCell(for: device) {
                                Text(device.kind.title)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        TableColumn("Hardware") { device in
                            controlDeviceTableCell(for: device) {
                                SettingsValueText(emulator.hardwareTitle(for: device),
                                                  truncationMode: .middle)
                            }
                        }
                    }
                } footer: {
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

                            Button {
                                beginAddingDevice(kind: .mouse1351)
                            } label: {
                                Label("Mouse (1351)", systemImage: ControlDeviceKind.mouse1351.systemImage)
                            }
                        } label: {
                            Image(systemName: "plus")
                                .frame(width: 18, height: 18)
                        }
                        .menuStyle(.button)
                        .help("Add control device")

                        Button {
                            removalCandidate = selectedDevice
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
                }

                Spacer(minLength: 0)
            }
        }
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
        .confirmationDialog("Remove control device?",
                            isPresented: removalConfirmationBinding,
                            titleVisibility: .visible,
                            presenting: removalCandidate) { device in
            Button("Remove device", role: .destructive) {
                removeDevice(device)
            }

            Button("Cancel", role: .cancel) {
                removalCandidate = nil
            }
        } message: { device in
            Text("Remove \(device.name)?")
        }
    }

    private func controlDeviceTableCell<Content: View>(
        for device: ControlDeviceConfiguration,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .overlay {
                ControlDeviceCellClickHandler {
                    selectedDeviceID = device.id
                } onDoubleClick: {
                    editDevice(device)
                }
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

    private var removalConfirmationBinding: Binding<Bool> {
        Binding {
            removalCandidate != nil
        } set: { isPresented in
            if !isPresented {
                removalCandidate = nil
            }
        }
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

    private func removeDevice(_ device: ControlDeviceConfiguration) {
        emulator.removeControlDevice(id: device.id)
        selectedDeviceID = emulator.controlDevices.first?.id
        removalCandidate = nil
    }
}

private struct ControlDeviceCellClickHandler: NSViewRepresentable {
    let onSelect: () -> Void
    let onDoubleClick: () -> Void

    func makeNSView(context: Context) -> ClickView {
        let view = ClickView()
        view.onSelect = onSelect
        view.onDoubleClick = onDoubleClick
        return view
    }

    func updateNSView(_ nsView: ClickView, context: Context) {
        nsView.onSelect = onSelect
        nsView.onDoubleClick = onDoubleClick
    }

    final class ClickView: NSView {
        var onSelect: () -> Void = {}
        var onDoubleClick: () -> Void = {}

        override func mouseDown(with event: NSEvent) {
            if let tableView = enclosingTableView {
                window?.makeFirstResponder(tableView)
            }

            onSelect()

            if event.clickCount >= 2 {
                onDoubleClick()
            }
        }

        private var enclosingTableView: NSTableView? {
            var view = superview
            while let currentView = view {
                if let tableView = currentView as? NSTableView {
                    return tableView
                }

                view = currentView.superview
            }

            return nil
        }
    }
}

private struct PointerControlSettingsSection: View {
    @EnvironmentObject private var emulator: EmulatorSession

    var body: some View {
        Form {
            Section("Pointer") {
                Picker("Mac pointer", selection: pointerBinding) {
                    ForEach(pointerAssignments) { assignment in
                        Text(assignment.title).tag(assignment)
                    }
                }

                LabeledContent("Behavior") {
                    SettingsValueText(emulator.pointerControlAssignment.detail,
                                      lineLimit: 2)
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 118)
    }

    private var pointerAssignments: [PointerControlAssignment] {
        PointerControlAssignment.allCases.filter { assignment in
            guard let port = assignment.port else {
                return true
            }

            return emulator.availableControlPorts.contains(port)
        }
    }

    private var pointerBinding: Binding<PointerControlAssignment> {
        Binding {
            emulator.pointerControlAssignment
        } set: { assignment in
            emulator.setPointerControlAssignment(assignment)
        }
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
        SettingsSheetLayout(title: title,
                            width: 520,
                            minHeight: sheetMinHeight) {
            Form {
                Section("Device") {
                    LabeledContent("Name") {
                        TextField("", text: $device.name)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Name")
                    }

                    LabeledContent("Type") {
                        Label(device.kind.title, systemImage: device.kind.systemImage)
                            .foregroundStyle(.secondary)
                    }
                }

                if device.kind != .mouse1351 {
                    Section("Mapping") {
                        switch device.kind {
                        case .keyboard:
                            KeyboardJoystickMappingEditor(mapping: $device.keyboard)
                        case .joystick:
                            GameControllerJoystickMappingEditor(mapping: $device.joystick)
                                .environmentObject(emulator)
                        case .mouse1351:
                            EmptyView()
                        }
                    }
                }
            }
            .formStyle(.grouped)
        } actions: {
            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button(primaryButtonTitle) {
                onSave(device.normalized())
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canSave)
        }
    }

    private var canSave: Bool {
        !device.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var sheetMinHeight: CGFloat {
        switch device.kind {
        case .keyboard:
            return 460
        case .joystick:
            return 610
        case .mouse1351:
            return 260
        }
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

    private static let legacyControllerTagPrefix = "legacy:"

    var body: some View {
        Picker("Hardware", selection: preferredControllerBinding) {
            Text("Any connected controller").tag("")

            if let missingControllerSelection {
                Text(missingControllerSelection.title).tag(missingControllerSelection.tag)
            }

            ForEach(emulator.sortedGameControllers) { controller in
                Text(controller.title).tag(controller.id)
            }
        }
        .onAppear(perform: upgradeLegacyControllerSelection)
        .onChange(of: emulator.gameControllers) { _, _ in
            upgradeLegacyControllerSelection()
        }

        LabeledContent("Identify") {
            HStack(spacing: 8) {
                GameControllerHardwareCaptureButton(mapping: $mapping,
                                                    deadZone: mapping.deadZone)

                if let selectedController {
                    SettingsValueText(selectedController.detailTitle)
                }
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
                                             preferredControllerIdentifier: mapping.preferredControllerIdentifier,
                                             preferredControllerName: mapping.preferredControllerName,
                                             deadZone: mapping.deadZone)
            }
        }
    }

    private var preferredControllerBinding: Binding<String> {
        Binding {
            preferredControllerTag
        } set: { tag in
            if tag.isEmpty {
                mapping.setPreferredController(nil)
                return
            }

            if let controller = emulator.connectedGameController(id: tag) {
                mapping.setPreferredController(controller)
                return
            }

            if let legacyName = legacyControllerName(from: tag) {
                mapping.preferredControllerIdentifier = nil
                mapping.preferredControllerName = legacyName
            }
        }
    }

    private var preferredControllerTag: String {
        if let selectedController {
            return selectedController.id
        }

        if let preferredControllerIdentifier = mapping.preferredControllerIdentifier {
            return preferredControllerIdentifier
        }

        if let preferredControllerName = mapping.preferredControllerName {
            return legacyControllerTag(for: preferredControllerName)
        }

        return ""
    }

    private var selectedController: ConnectedGameController? {
        emulator.preferredGameController(for: mapping)
    }

    private var missingControllerSelection: (tag: String, title: String)? {
        guard selectedController == nil,
              let preferredControllerName = mapping.preferredControllerName else {
            return nil
        }

        return (preferredControllerTag, "Missing \(preferredControllerName)")
    }

    private func upgradeLegacyControllerSelection() {
        guard mapping.preferredControllerIdentifier == nil,
              mapping.preferredControllerName != nil,
              let controller = emulator.preferredGameController(for: mapping) else {
            return
        }

        mapping.setPreferredController(controller)
    }

    private func legacyControllerTag(for name: String) -> String {
        "\(Self.legacyControllerTagPrefix)\(name)"
    }

    private func legacyControllerName(from tag: String) -> String? {
        guard tag.hasPrefix(Self.legacyControllerTagPrefix) else {
            return nil
        }

        return String(tag.dropFirst(Self.legacyControllerTagPrefix.count))
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
        emulator.connectionState(for: mapping)
    }
}

private struct GameControllerHardwareCaptureButton: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @Binding var mapping: GameControllerJoystickMapping

    let deadZone: Double

    @State private var isCapturing = false
    @State private var captureTask: Task<Void, Never>?

    var body: some View {
        Button {
            startCapturing()
        } label: {
            Label(isCapturing ? "Press a Button" : "Select by Input",
                  systemImage: isCapturing ? "record.circle" : "gamecontroller")
                .frame(minWidth: 150)
        }
        .disabled(!emulator.hasGameControllers && !isCapturing)
        .help("Press any connected controller button or direction to select that hardware")
        .onDisappear {
            stopCapturing()
        }
    }

    private func startCapturing() {
        guard !isCapturing,
              emulator.hasGameControllers else {
            return
        }

        isCapturing = true
        captureTask = Task { @MainActor in
            while !Task.isCancelled {
                if let controller = capturedController() {
                    mapping.setPreferredController(controller)
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

    private func capturedController() -> ConnectedGameController? {
        let deadZone = Float(deadZone)
        let controllers = EmulatorSession.connectedGameControllers(for: GCController.controllers())

        for controller in controllers {
            if GameControllerControl.capturedControl(from: controller.controller, deadZone: deadZone) != nil {
                return controller.descriptor
            }
        }

        return nil
    }
}

private struct JoystickControlCaptureButton: View {
    @Binding var control: GameControllerControl

    let preferredControllerIdentifier: String?
    let preferredControllerName: String?
    let deadZone: Double

    @State private var isCapturing = false
    @State private var captureTask: Task<Void, Never>?

    var body: some View {
        Button {
            startCapturing()
        } label: {
            Text(isCapturing ? "Press a control" : control.title)
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
        let controllers = EmulatorSession.connectedGameControllers(for: GCController.controllers())
        let preferredControllers: [(controller: GCController, descriptor: ConnectedGameController)]

        if let preferredControllerIdentifier {
            preferredControllers = controllers.filter { $0.descriptor.id == preferredControllerIdentifier }
        } else if let preferredControllerName {
            preferredControllers = controllers.filter { $0.descriptor.vendorName == preferredControllerName }
        } else {
            preferredControllers = controllers
        }

        for controller in preferredControllers {
            if let control = GameControllerControl.capturedControl(from: controller.controller, deadZone: deadZone) {
                return control
            }
        }

        return nil
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

            Section("Display chain") {
                VideoFilterPresetPicker(labelTitle: "Profile", labelSystemImage: "camera.filters")
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
            Toggle("Enabled", isOn: $drive.isAttached)

            Picker("Storage", selection: $drive.storageKind) {
                ForEach(emulator.machine.capabilities.supportedStorageKinds) { kind in
                    Label(kind.title, systemImage: kind.systemImage).tag(kind)
                }
            }
            .disabled(!drive.isAttached)
            .onChange(of: drive.storageKind) { _, storageKind in
                normalizeDriveType(for: storageKind)
            }

            LabeledContent("Best for") {
                Text(drive.storageKind.detail)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .disabled(!drive.isAttached)

            if drive.storageKind == .sharedFolder {
                sharedFolderControls
            } else {
                Picker("Model", selection: $drive.driveType) {
                    ForEach(availableDriveTypes) { type in
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

                Toggle(protectToggleTitle, isOn: $drive.protectsInsertedDisks)
                    .disabled(!drive.isAttached)

                Toggle("Drive sounds", isOn: $drive.soundEnabled)
                    .disabled(!drive.supportsDriveSounds)

                LabeledContent("Sound volume") {
                    SettingsPercentSlider(value: $drive.soundVolume,
                                          isEnabled: drive.supportsDriveSounds && drive.soundEnabled,
                                          onEditingChanged: handleVolumeEditingChanged)
                }
            }
        }
    }

    private var sharedFolderControls: some View {
        Group {
            LabeledContent("Folder") {
                HStack(spacing: 8) {
                    SettingsValueText(sharedFolderTitle, truncationMode: .middle)

                    Spacer(minLength: 8)

                    Button("Choose...") {
                        chooseSharedFolder()
                    }

                    Button("Reveal") {
                        revealSharedFolder()
                    }
                    .disabled(drive.sharedFolderPath == nil)

                    Button("Clear") {
                        drive.sharedFolderPath = nil
                    }
                    .disabled(drive.sharedFolderPath == nil)
                }
            }
            .disabled(!drive.isAttached)

            LabeledContent("Machine sees") {
                HStack(spacing: 6) {
                    VMCStatusBadge("LOAD/SAVE", systemImage: "checkmark.circle", color: .green)
                    VMCStatusBadge("65535 blocks free", systemImage: "number", color: .secondary)
                    VMCStatusBadge("No raw blocks", systemImage: "exclamationmark.triangle", color: .orange)
                }
            }
            .disabled(!drive.isAttached)

            if let visibleFileCount {
                LabeledContent("Visible files") {
                    Text("\(visibleFileCount)")
                        .foregroundStyle(.secondary)
                }
                .disabled(!drive.isAttached)

                if visibleFileCount > 500 {
                    LabeledContent("Large folder") {
                        Text("Very large directories can be awkward from BASIC. Use a smaller shared folder when software loads \"$\".")
                            .foregroundStyle(.orange)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .disabled(!drive.isAttached)
                }
            }
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

    private var availableDriveTypes: [DriveType] {
        emulator.machine.capabilities.driveTypes(for: drive.storageKind)
    }

    private var protectToggleTitle: String {
        drive.storageKind == .hardDriveImage ? "Protect inserted image" : "Protect inserted disks"
    }

    private var hardwareDetail: String {
        let mechanism = drive.driveType.slotCount == 1 ? "single drive" : "\(drive.driveType.slotCount) drives"
        return "\(drive.driveType.busTitle), \(mechanism)"
    }

    private var sharedFolderTitle: String {
        guard let path = drive.sharedFolderPath else {
            return "Choose a folder"
        }

        return path
    }

    private var visibleFileCount: Int? {
        guard let path = drive.sharedFolderPath else {
            return nil
        }

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        return urls.reduce(0) { count, url in
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            return count + ((values?.isRegularFile ?? false) ? 1 : 0)
        }
    }

    private func normalizeDriveType(for storageKind: DriveStorageKind) {
        guard !emulator.machine.capabilities.driveTypes(for: storageKind).contains(drive.driveType) else {
            return
        }

        drive.driveType = emulator.machine.capabilities.defaultDriveType(for: storageKind,
                                                                         fallback: drive.driveType)
    }

    private func chooseSharedFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Shared Mac Folder"
        panel.message = "Choose the Finder folder this machine sees as drive \(drive.unit)."
        panel.prompt = "Choose"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        if let path = drive.sharedFolderPath {
            panel.directoryURL = URL(fileURLWithPath: path)
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        drive.sharedFolderPath = url.path
    }

    private func revealSharedFolder() {
        guard let path = drive.sharedFolderPath else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
}

private struct SettingsPane<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        SettingsCustomPane {
            Form {
                content
            }
            .formStyle(.grouped)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(EmulatorSession())
        .environmentObject(AIAssistantSettings())
        .environmentObject(AIDocumentLibraryStore(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent("ViceMacPreviewAIDocuments", isDirectory: true)))
        .environmentObject(MetadataIngestionSettings())
        .environmentObject(QLinkReloadedService(registrationStore: QLinkReloadedRegistrationMemoryStore()))
}
