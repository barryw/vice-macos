import AppKit
import GameController
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @AppStorage("vice.settings.selectedPane") private var selectedPaneID = SettingsPaneID.machine.rawValue

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(panes: availablePanes,
                            selection: $selectedPaneID)

            Divider()

            selectedPaneContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 980, height: 700)
        .background(.regularMaterial)
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

    private var availablePanes: [SettingsPaneID] {
        SettingsPaneCatalog.availablePanes(showsControlSettings: showsControlSettings,
                                           showsNetworkSettings: showsNetworkSettings,
                                           aiAssistantEnabled: VMCFeatureFlags.aiAssistant)
    }

    private var selectedPane: SettingsPaneID {
        SettingsPaneCatalog.normalizedSelection(for: selectedPaneID,
                                                showsControlSettings: showsControlSettings,
                                                showsNetworkSettings: showsNetworkSettings,
                                                aiAssistantEnabled: VMCFeatureFlags.aiAssistant)
    }

    @ViewBuilder
    private var selectedPaneContent: some View {
        switch selectedPane {
        case .machine:
            MachineSettingsPane()
        case .media:
            MediaSettingsPane()
        case .metadata:
            MetadataSettingsPane()
        case .sound:
            SoundSettingsPane()
        case .controls:
            if showsControlSettings {
                ControlSettingsPane()
            } else {
                KeyboardSettingsPane()
            }
        case .keyboard:
            KeyboardSettingsPane()
        case .drives:
            DriveSettingsPane()
        case .printing:
            PrintingSettingsPane()
        case .network:
            if showsNetworkSettings {
                NetworkSettingsPane()
            } else {
                MediaSettingsPane()
            }
        case .display:
            DisplaySettingsPane()
        case .ai:
            if VMCFeatureFlags.aiAssistant {
                AIAssistantSettingsPane()
            } else {
                MachineSettingsPane()
            }
        }
    }

    private func normalizeSelectedPane() {
        let normalizedPane = SettingsPaneCatalog.normalizedSelection(for: selectedPaneID,
                                                                     showsControlSettings: showsControlSettings,
                                                                     showsNetworkSettings: showsNetworkSettings,
                                                                     aiAssistantEnabled: VMCFeatureFlags.aiAssistant)
        if selectedPaneID != normalizedPane.rawValue {
            selectedPaneID = normalizedPane.rawValue
        }
    }
}

private struct SettingsSidebar: View {
    let panes: [SettingsPaneID]
    @Binding var selection: String

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(panes) { pane in
                    SettingsSidebarRow(pane: pane,
                                       isSelected: selection == pane.rawValue) {
                        selection = pane.rawValue
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
        .frame(width: 206)
        .background(.bar)
    }
}

private struct SettingsSidebarRow: View {
    let pane: SettingsPaneID
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: pane.systemImage)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isSelected ? .white : .secondary)
                    .frame(width: 22, height: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(pane.title)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : .primary)
                        .lineLimit(1)

                    Text(pane.subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.78) : .secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pane.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
                                VMCEmptyState("No Books",
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
    @State private var showsQLinkProfileManager = false
    @AppStorage("vice.qlink.captureProtocol") private var qlinkCaptureProtocol = false

    var body: some View {
        SettingsPane {
            modemSection
            if supportsQLinkReloaded {
                qLinkReloadedSection
            } else {
                dialingSection
            }
            testLineSection
            incomingCallsSection
        }
        .machineHardRestartConfirmation($hardRestartRequest)
        .onAppear {
            qLinkReloaded.refreshRegistrationProfiles()
            qLinkReloaded.refreshConfiguredDiskRegistrationProfile()
        }
        .onChange(of: emulator.networkModem) { _, _ in
            qLinkReloaded.resetConfigurationValidation()
        }
        .sheet(isPresented: $showsQLinkProfileManager) {
            QLinkProfileManagerSheet()
                .environmentObject(emulator)
                .environmentObject(qLinkReloaded)
        }
    }

    @ViewBuilder
    private var modemSection: some View {
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
                    Text(String(baudRate)).tag(baudRate)
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
    }

    private var dialingSection: some View {
        Section(NetworkSettingsPresentation.dialingSectionTitle(supportsQLinkReloaded: false)) {
            dialingRows
        }
    }

    private var testLineSection: some View {
        Section("Test Line") {
            LabeledContent("Dial") {
                SettingsValueText(emulator.networkModem.testDialCommand)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    private var incomingCallsSection: some View {
        Section("Incoming Calls") {
            Toggle("Accept incoming calls", isOn: $emulator.networkModem.acceptsIncomingCalls)
                .disabled(!emulator.networkModem.isEnabled)

            LabeledContent("Port") {
                SettingsPortField(value: incomingPortBinding,
                                  range: NetworkModemConfiguration.tcpPortRange)
                    .disabled(!emulator.networkModem.isEnabled
                              || !emulator.networkModem.acceptsIncomingCalls)
            }

            LabeledContent("Auto-answer") {
                Picker("Auto-answer", selection: $emulator.networkModem.autoAnswerRings) {
                    Text("Off").tag(0)
                    ForEach(1...9, id: \.self) { rings in
                        Text(NetworkSettingsPresentation.autoAnswerOptionTitle(for: rings)).tag(rings)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(!emulator.networkModem.isEnabled
                          || !emulator.networkModem.acceptsIncomingCalls)
            }
        }
    }

    @ViewBuilder
    private var qLinkReloadedSection: some View {
        Section(NetworkSettingsPresentation.dialingSectionTitle(supportsQLinkReloaded: true)) {
            dialingRows

            LabeledContent("Validation") {
                HStack(spacing: 8) {
                    Label(qLinkReloaded.configurationValidationStatus.title,
                          systemImage: qLinkReloaded.configurationValidationStatus.systemImage)
                        .foregroundStyle(qLinkValidationColor)
                        .lineLimit(4)
                        .multilineTextAlignment(.leading)
                        .help(qLinkReloaded.configurationValidationStatus.title)

                    Spacer(minLength: 8)

                    Button {
                        qLinkReloaded.validateConfiguration(emulator: emulator)
                    } label: {
                        Label("Validate", systemImage: "checkmark.shield")
                    }
                    .disabled(qLinkReloaded.configurationValidationStatus.isChecking
                              || qLinkReloaded.isConnecting)
                }
            }

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

            LabeledContent("Profiles") {
                HStack(spacing: 8) {
                    SettingsValueText(qLinkProfileSummary)

                    Button {
                        showsQLinkProfileManager = true
                    } label: {
                        Label("Manage Profiles", systemImage: "person.crop.circle.badge.gearshape")
                    }
                }
            }

            Toggle(isOn: $qlinkCaptureProtocol) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Capture protocol")
                    Text("Write a decoded .log for the viewer and a raw direction-tagged .cap beside it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(qLinkReloaded.isConnecting)
        }
    }

    @ViewBuilder
    private var dialingRows: some View {
        LabeledContent("Host") {
            TextField("Host", text: $emulator.networkModem.defaultDialHost)
                .labelsHidden()
                .textFieldStyle(.roundedBorder)
                .disabled(!emulator.networkModem.isEnabled)
        }

        LabeledContent("Port") {
            SettingsPortField(value: defaultDialPortBinding,
                              range: NetworkModemConfiguration.tcpPortRange)
                .disabled(!emulator.networkModem.isEnabled)
        }

        LabeledContent("Command") {
            SettingsValueText(emulator.networkModem.dialCommandPreview)
                .font(.system(.body, design: .monospaced))
        }
    }

    private var qLinkDiskTitle: String {
        NetworkSettingsPresentation.qLinkDiskTitle(configuredDiskTitle: qLinkReloaded.configuredDiskTitle,
                                                   configuredDiskVersionTitle: qLinkReloaded.configuredDiskVersionTitle)
    }

    private var qLinkProfileSummary: String {
        NetworkSettingsPresentation.qLinkProfileSummary(
            diskProfileCount: qLinkReloaded.configuredDiskRegistrationProfiles.count,
            keychainProfileCount: qLinkReloaded.registrationProfiles.count
        )
    }

    private var supportsQLinkReloaded: Bool {
        qLinkReloaded.supports(machine: emulator.machine)
    }

    private var qLinkValidationColor: Color {
        switch qLinkReloaded.configurationValidationStatus {
        case .valid:
            return .green
        case .invalid:
            return .red
        case .checking:
            return .accentColor
        case .idle:
            return .secondary
        }
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

    private var defaultDialPortBinding: Binding<Int> {
        Binding {
            emulator.networkModem.defaultDialPort
        } set: { port in
            var modem = emulator.networkModem
            modem.defaultDialPort = NetworkModemConfiguration.clampedTCPPort(port)
            emulator.networkModem = modem
        }
    }

    private var incomingPortBinding: Binding<Int> {
        Binding {
            emulator.networkModem.incomingPort
        } set: { port in
            var modem = emulator.networkModem
            modem.incomingPort = NetworkModemConfiguration.clampedTCPPort(port)
            emulator.networkModem = modem
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

}

private struct QLinkProfileManagerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var emulator: EmulatorSession
    @EnvironmentObject private var qLinkReloaded: QLinkReloadedService
    @State private var selectedDiskProfileID: String?
    @State private var selectedKeychainProfileID: String?
    @State private var pendingTransfer: QLinkProfileTransferConfirmation?
    @State private var pendingDeletion: QLinkProfileDeletionConfirmation?
    @State private var inspectedProfile: QLinkProfileInspection?

    var body: some View {
        SettingsSheetLayout(title: "Manage Q-Link Profiles",
                            width: 780,
                            minHeight: 520) {
            VStack(alignment: .leading, spacing: 14) {
                diskHeader
                profileTransferView
            }
        } actions: {
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .onAppear(perform: refreshProfiles)
        .onChange(of: qLinkReloaded.configuredDiskRegistrationProfiles) { _, _ in
            syncDiskProfileSelection()
        }
        .onChange(of: qLinkReloaded.registrationProfiles) { _, _ in
            syncKeychainProfileSelection()
        }
        .confirmationDialog(transferConfirmationTitle,
                            isPresented: transferConfirmationBinding,
                            titleVisibility: .visible) {
            if let pendingTransfer {
                Button(pendingTransfer.buttonTitle) {
                    performTransfer(pendingTransfer)
                    self.pendingTransfer = nil
                }
            }

            Button("Cancel", role: .cancel) {
                pendingTransfer = nil
            }
        } message: {
            Text(transferConfirmationMessage)
        }
        .confirmationDialog(deletionConfirmationTitle,
                            isPresented: deletionConfirmationBinding,
                            titleVisibility: .visible) {
            if let pendingDeletion {
                Button(pendingDeletion.buttonTitle, role: .destructive) {
                    performDeletion(pendingDeletion)
                    self.pendingDeletion = nil
                }
            }

            Button("Cancel", role: .cancel) {
                pendingDeletion = nil
            }
        } message: {
            Text(deletionConfirmationMessage)
        }
        .sheet(item: $inspectedProfile) { inspection in
            QLinkProfileDetailSheet(inspection: inspection)
        }
    }

    private var diskHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Label("Disk", systemImage: "externaldrive")
                .font(.headline)

            SettingsValueText(qLinkDiskTitle,
                              lineLimit: 2,
                              truncationMode: .middle)

            Spacer()

            Button {
                qLinkReloaded.chooseDisk(for: emulator.machine)
                refreshProfiles()
            } label: {
                Label("Choose Disk", systemImage: "externaldrive")
            }
            .disabled(qLinkReloaded.isConnecting)

            Button {
                refreshProfiles()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 18, height: 18)
            }
            .help("Refresh Q-Link profiles")
        }
    }

    private var profileTransferView: some View {
        HStack(alignment: .top, spacing: 12) {
            diskProfileList

            VStack(spacing: 10) {
                Spacer(minLength: 72)

                Button {
                    copyDiskProfileToKeychain()
                } label: {
                    Image(systemName: "arrow.right")
                        .frame(width: 20, height: 18)
                }
                .disabled(!canCopyDiskProfileToKeychain)
                .help(copyDiskToKeychainHelp)
                .accessibilityLabel("Copy to Keychain")

                Button {
                    copyKeychainProfileToDisk()
                } label: {
                    Image(systemName: "arrow.left")
                        .frame(width: 20, height: 18)
                }
                .disabled(!canCopyKeychainProfileToDisk)
                .help(copyKeychainToDiskHelp)
                .accessibilityLabel("Copy to Q-Link disk")

                Spacer()
            }
            .frame(width: 44)

            keychainProfileList
        }
    }

    private var diskProfileList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("On the Q-Link Disk")
                .font(.headline)

            SettingsTableContainer(minHeight: 290) {
                ZStack {
                    List(selection: $selectedDiskProfileID) {
                        ForEach(qLinkReloaded.configuredDiskRegistrationProfiles) { profile in
                            profileRow(profile, source: .disk)
                                .tag(profile.id)
                        }
                    }

                    if qLinkReloaded.configuredDiskRegistrationProfiles.isEmpty {
                        VMCEmptyState(diskProfilesEmptyTitle,
                                      systemImage: "person.crop.circle.badge.questionmark",
                                      description: diskProfilesEmptyDescription)
                    }
                }
            } footer: {
                HStack(spacing: 6) {
                    Text(diskProfileCountTitle)
                        .foregroundStyle(.secondary)

                    Spacer()

                    VMCIconButton("info.circle",
                                  help: "Show selected disk profile",
                                  width: 18,
                                  height: 18) {
                        inspectSelectedDiskProfile()
                    }
                    .disabled(selectedDiskProfile == nil)

                    VMCIconButton("trash",
                                  help: "Remove selected profile from the Q-Link disk",
                                  role: .destructive,
                                  width: 18,
                                  height: 18) {
                        if let selectedDiskProfile {
                            pendingDeletion = QLinkProfileDeletionConfirmation(location: .disk,
                                                                               profile: selectedDiskProfile)
                        }
                    }
                    .disabled(selectedDiskProfile == nil)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var keychainProfileList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("In Your Keychain")
                .font(.headline)

            SettingsTableContainer(minHeight: 290) {
                ZStack {
                    List(selection: $selectedKeychainProfileID) {
                        ForEach(qLinkReloaded.registrationProfiles) { profile in
                            profileRow(profile, source: .keychain)
                                .tag(profile.id)
                        }
                    }

                    if qLinkReloaded.registrationProfiles.isEmpty {
                        VMCEmptyState("No Profiles",
                                      systemImage: "key",
                                      description: "Saved Q-Link profiles will appear here.")
                    }
                }
            } footer: {
                HStack(spacing: 6) {
                    Text(keychainProfileCountTitle)
                        .foregroundStyle(.secondary)

                    Spacer()

                    VMCIconButton("info.circle",
                                  help: "Show selected Keychain profile",
                                  width: 18,
                                  height: 18) {
                        inspectSelectedKeychainProfile()
                    }
                    .disabled(selectedKeychainProfile == nil)

                    VMCIconButton("trash",
                                  help: "Delete selected profile from Keychain",
                                  role: .destructive,
                                  width: 18,
                                  height: 18) {
                        if let selectedKeychainProfile {
                            pendingDeletion = QLinkProfileDeletionConfirmation(location: .keychain,
                                                                               profile: selectedKeychainProfile)
                        }
                    }
                    .disabled(selectedKeychainProfile == nil)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func profileRow(_ profile: QLinkReloadedRegistrationProfile,
                            source: QLinkProfileLocation) -> some View {
        HStack(spacing: 8) {
            Label(profile.displayTitle, systemImage: source.systemImage)
                .lineLimit(1)

            Spacer()

            Text(profile.accountDisplayTitle)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .contentShape(Rectangle())
        .overlay {
            SettingsTableCellClickHandler {
                switch source {
                case .disk:
                    selectedDiskProfileID = profile.id
                case .keychain:
                    selectedKeychainProfileID = profile.id
                }
            } onDoubleClick: {
                inspect(profile, source: source)
            }
        }
    }

    private var selectedDiskProfile: QLinkReloadedRegistrationProfile? {
        guard let selectedDiskProfileID else {
            return nil
        }

        return qLinkReloaded.configuredDiskRegistrationProfiles.first { $0.id == selectedDiskProfileID }
    }

    private var selectedKeychainProfile: QLinkReloadedRegistrationProfile? {
        guard let selectedKeychainProfileID else {
            return nil
        }

        return qLinkReloaded.registrationProfiles.first { $0.id == selectedKeychainProfileID }
    }

    private var canCopyDiskProfileToKeychain: Bool {
        guard let selectedDiskProfile else {
            return false
        }

        if let matchingProfile = keychainProfile(matching: selectedDiskProfile),
           profilesMatch(selectedDiskProfile, matchingProfile) {
            return false
        }

        return true
    }

    private var canCopyKeychainProfileToDisk: Bool {
        guard qLinkReloaded.hasConfiguredDisk,
              let selectedKeychainProfile else {
            return false
        }

        if let matchingProfile = diskProfile(matching: selectedKeychainProfile) {
            return !profilesMatch(selectedKeychainProfile, matchingProfile)
        }

        return qLinkReloaded.configuredDiskRegistrationProfiles.count < QLinkReloadedDiskPatcher.maximumRegistrationProfileCount
    }

    private var copyDiskToKeychainHelp: String {
        guard let selectedDiskProfile else {
            return "Select a disk profile"
        }

        if let matchingProfile = keychainProfile(matching: selectedDiskProfile),
           profilesMatch(selectedDiskProfile, matchingProfile) {
            return "This profile is already saved in Keychain"
        }

        return "Copy selected disk profile to Keychain"
    }

    private var copyKeychainToDiskHelp: String {
        guard qLinkReloaded.hasConfiguredDisk else {
            return "Choose a Q-Link disk"
        }

        guard let selectedKeychainProfile else {
            return "Select a Keychain profile"
        }

        if let matchingProfile = diskProfile(matching: selectedKeychainProfile),
           profilesMatch(selectedKeychainProfile, matchingProfile) {
            return "This profile is already on the Q-Link disk"
        }

        if qLinkReloaded.configuredDiskRegistrationProfiles.count >= QLinkReloadedDiskPatcher.maximumRegistrationProfileCount,
           diskProfile(matching: selectedKeychainProfile) == nil {
            return "The Q-Link disk already has 10 profiles"
        }

        return "Copy selected Keychain profile to the Q-Link disk"
    }

    private var qLinkDiskTitle: String {
        QLinkProfileManagerPresentation.diskTitle(
            configuredDiskTitle: qLinkReloaded.configuredDiskTitle,
            configuredDiskVersionTitle: qLinkReloaded.configuredDiskVersionTitle
        )
    }

    private var diskProfilesEmptyTitle: String {
        QLinkProfileManagerPresentation.diskProfilesEmptyTitle(hasConfiguredDisk: qLinkReloaded.hasConfiguredDisk)
    }

    private var diskProfilesEmptyDescription: String {
        QLinkProfileManagerPresentation.diskProfilesEmptyDescription(
            hasConfiguredDisk: qLinkReloaded.hasConfiguredDisk
        )
    }

    private var diskProfileCountTitle: String {
        QLinkProfileManagerPresentation.diskProfileCapacityTitle(
            count: qLinkReloaded.configuredDiskRegistrationProfiles.count,
            maximum: QLinkReloadedDiskPatcher.maximumRegistrationProfileCount
        )
    }

    private var keychainProfileCountTitle: String {
        QLinkProfileManagerPresentation.keychainProfileCountTitle(count: qLinkReloaded.registrationProfiles.count)
    }

    private var transferConfirmationTitle: String {
        pendingTransfer?.title ?? "Replace Q-Link Profile?"
    }

    private var transferConfirmationMessage: String {
        pendingTransfer?.message ?? ""
    }

    private var transferConfirmationBinding: Binding<Bool> {
        Binding {
            pendingTransfer != nil
        } set: { isPresented in
            if !isPresented {
                pendingTransfer = nil
            }
        }
    }

    private var deletionConfirmationTitle: String {
        pendingDeletion?.title ?? "Remove Q-Link Profile?"
    }

    private var deletionConfirmationMessage: String {
        pendingDeletion?.message ?? ""
    }

    private var deletionConfirmationBinding: Binding<Bool> {
        Binding {
            pendingDeletion != nil
        } set: { isPresented in
            if !isPresented {
                pendingDeletion = nil
            }
        }
    }

    private func copyDiskProfileToKeychain() {
        guard let selectedDiskProfile else {
            return
        }

        if let matchingProfile = keychainProfile(matching: selectedDiskProfile) {
            guard !profilesMatch(selectedDiskProfile, matchingProfile) else {
                return
            }

            pendingTransfer = QLinkProfileTransferConfirmation(direction: .diskToKeychain,
                                                               profile: selectedDiskProfile,
                                                               reason: .profileMismatch)
            return
        }

        performDiskToKeychainTransfer(selectedDiskProfile)
    }

    private func copyKeychainProfileToDisk() {
        guard qLinkReloaded.hasConfiguredDisk,
              let selectedKeychainProfile else {
            return
        }

        if let matchingProfile = diskProfile(matching: selectedKeychainProfile) {
            guard !profilesMatch(selectedKeychainProfile, matchingProfile) else {
                return
            }

            pendingTransfer = QLinkProfileTransferConfirmation(direction: .keychainToDisk,
                                                               profile: selectedKeychainProfile,
                                                               reason: .profileMismatch)
            return
        }

        guard qLinkReloaded.configuredDiskRegistrationProfiles.count < QLinkReloadedDiskPatcher.maximumRegistrationProfileCount else {
            return
        }

        if let diskAccessCode = qLinkReloaded.configuredDiskRegistrationProfiles.first?.accessCode,
           diskAccessCode != selectedKeychainProfile.accessCode {
            pendingTransfer = QLinkProfileTransferConfirmation(direction: .keychainToDisk,
                                                               profile: selectedKeychainProfile,
                                                               reason: .sharedAccessCodeMismatch)
            return
        }

        performKeychainToDiskTransfer(selectedKeychainProfile)
    }

    private func performTransfer(_ transfer: QLinkProfileTransferConfirmation) {
        switch transfer.direction {
        case .diskToKeychain:
            performDiskToKeychainTransfer(transfer.profile)
        case .keychainToDisk:
            performKeychainToDiskTransfer(transfer.profile)
        }
    }

    private func performDiskToKeychainTransfer(_ profile: QLinkReloadedRegistrationProfile) {
        qLinkReloaded.copyRegistrationFromConfiguredDisk(id: profile.id,
                                                         presentsNotice: false)
        selectedKeychainProfileID = profile.id
        refreshProfiles()
    }

    private func performKeychainToDiskTransfer(_ profile: QLinkReloadedRegistrationProfile) {
        qLinkReloaded.addRegistrationToConfiguredDisk(id: profile.id,
                                                      presentsNotice: false)
        selectedDiskProfileID = profile.id
        refreshProfiles()
    }

    private func performDeletion(_ deletion: QLinkProfileDeletionConfirmation) {
        switch deletion.location {
        case .disk:
            qLinkReloaded.removeRegistrationFromConfiguredDisk(id: deletion.profile.id,
                                                               presentsNotice: false)
            if selectedDiskProfileID == deletion.profile.id {
                selectedDiskProfileID = nil
            }
            qLinkReloaded.refreshConfiguredDiskRegistrationProfile()
            syncDiskProfileSelection()
        case .keychain:
            qLinkReloaded.deleteRegistration(id: deletion.profile.id)
            if selectedKeychainProfileID == deletion.profile.id {
                selectedKeychainProfileID = nil
            }
            qLinkReloaded.refreshRegistrationProfiles()
            syncKeychainProfileSelection()
        }
    }

    private func inspectSelectedDiskProfile() {
        if let selectedDiskProfile {
            inspect(selectedDiskProfile, source: .disk)
        }
    }

    private func inspectSelectedKeychainProfile() {
        if let selectedKeychainProfile {
            inspect(selectedKeychainProfile, source: .keychain)
        }
    }

    private func inspect(_ profile: QLinkReloadedRegistrationProfile,
                         source: QLinkProfileLocation) {
        inspectedProfile = QLinkProfileInspection(location: source,
                                                  profile: profile)
    }

    private func refreshProfiles() {
        qLinkReloaded.refreshRegistrationProfiles()
        qLinkReloaded.refreshConfiguredDiskRegistrationProfile()
        syncDiskProfileSelection()
        syncKeychainProfileSelection()
    }

    private func syncDiskProfileSelection() {
        let profiles = qLinkReloaded.configuredDiskRegistrationProfiles
        guard !profiles.contains(where: { $0.id == selectedDiskProfileID }) else {
            return
        }

        selectedDiskProfileID = profiles.first?.id
    }

    private func syncKeychainProfileSelection() {
        let profiles = qLinkReloaded.registrationProfiles
        guard !profiles.contains(where: { $0.id == selectedKeychainProfileID }) else {
            return
        }

        selectedKeychainProfileID = profiles.first?.id
    }

    private func keychainProfile(matching profile: QLinkReloadedRegistrationProfile) -> QLinkReloadedRegistrationProfile? {
        qLinkReloaded.registrationProfiles.first { $0.id == profile.id }
    }

    private func diskProfile(matching profile: QLinkReloadedRegistrationProfile) -> QLinkReloadedRegistrationProfile? {
        qLinkReloaded.configuredDiskRegistrationProfiles.first { $0.id == profile.id }
    }

    private func profilesMatch(_ lhs: QLinkReloadedRegistrationProfile,
                               _ rhs: QLinkReloadedRegistrationProfile) -> Bool {
        if !lhs.userRecord.isEmpty || !rhs.userRecord.isEmpty {
            return lhs.accessCode == rhs.accessCode
                && lhs.accountID == rhs.accountID
                && lhs.userRecord == rhs.userRecord
        }

        return lhs == rhs
    }
}

private struct QLinkProfileDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let inspection: QLinkProfileInspection

    var body: some View {
        SettingsSheetLayout(title: "Q-Link Profile",
                            width: 420,
                            minHeight: 210) {
            Form {
                Section("Profile") {
                    LabeledContent("Location") {
                        SettingsValueText(inspection.location.detailTitle)
                    }

                    LabeledContent("Name") {
                        SettingsValueText(inspection.profile.displayTitle)
                    }

                    LabeledContent("Account") {
                        SettingsValueText(inspection.profile.fullAccountDisplayTitle)
                            .monospacedDigit()
                    }

                    LabeledContent("Access Code") {
                        SettingsValueText(inspection.profile.accessCode)
                            .monospacedDigit()
                    }

                    LabeledContent("Key") {
                        SettingsValueText(inspection.profile.id,
                                          truncationMode: .middle)
                    }
                }
            }
            .formStyle(.grouped)
        } actions: {
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
    }
}

private enum QLinkProfileLocation {
    case disk
    case keychain

    var detailTitle: String {
        switch self {
        case .disk:
            return "On the Q-Link disk"
        case .keychain:
            return "In your Keychain"
        }
    }

    var systemImage: String {
        switch self {
        case .disk:
            return "externaldrive"
        case .keychain:
            return "key"
        }
    }
}

private struct QLinkProfileInspection: Identifiable {
    let id = UUID()
    let location: QLinkProfileLocation
    let profile: QLinkReloadedRegistrationProfile
}

private enum QLinkProfileTransferDirection {
    case diskToKeychain
    case keychainToDisk
}

private enum QLinkProfileTransferReason {
    case profileMismatch
    case sharedAccessCodeMismatch
}

private struct QLinkProfileTransferConfirmation: Identifiable {
    let id = UUID()
    let direction: QLinkProfileTransferDirection
    let profile: QLinkReloadedRegistrationProfile
    let reason: QLinkProfileTransferReason

    var title: String {
        if reason == .sharedAccessCodeMismatch {
            return "Update Disk Access Code?"
        }

        switch direction {
        case .diskToKeychain:
            return "Replace Keychain Profile?"
        case .keychainToDisk:
            return "Replace Disk Profile?"
        }
    }

    var buttonTitle: String {
        if reason == .sharedAccessCodeMismatch {
            return "Copy and Update Disk"
        }

        switch direction {
        case .diskToKeychain:
            return "Replace in Keychain"
        case .keychainToDisk:
            return "Replace on Disk"
        }
    }

    var message: String {
        if reason == .sharedAccessCodeMismatch {
            return "This Q-Link disk already has profiles with a different shared access code. Copying \(profile.displayTitle) will replace that code for the disk and can affect the existing profiles on it."
        }

        switch direction {
        case .diskToKeychain:
            return "\(profile.displayTitle) already exists in Keychain, but its account or access code does not match the selected disk profile."
        case .keychainToDisk:
            return "\(profile.displayTitle) already exists on the Q-Link disk, but its account or access code does not match the selected Keychain profile."
        }
    }
}

private struct QLinkProfileDeletionConfirmation: Identifiable {
    let id = UUID()
    let location: QLinkProfileLocation
    let profile: QLinkReloadedRegistrationProfile

    var title: String {
        switch location {
        case .disk:
            return "Remove Disk Profile?"
        case .keychain:
            return "Delete Keychain Profile?"
        }
    }

    var buttonTitle: String {
        switch location {
        case .disk:
            return "Remove from Disk"
        case .keychain:
            return "Delete from Keychain"
        }
    }

    var message: String {
        switch location {
        case .disk:
            return "Remove \(profile.displayTitle) from the managed Q-Link disk copy. Saved Keychain profiles will not be changed."
        case .keychain:
            return "Delete \(profile.displayTitle) from Keychain. The Q-Link disk will not be changed."
        }
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
                SettingsTableCellClickHandler {
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

private struct SettingsTableCellClickHandler: NSViewRepresentable {
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
            if let enclosingSelectableView {
                window?.makeFirstResponder(enclosingSelectableView)
            }

            onSelect()

            if event.clickCount >= 2 {
                onDoubleClick()
            }
        }

        private var enclosingSelectableView: NSView? {
            var view = superview
            while let currentView = view {
                if currentView is NSTableView || currentView is NSOutlineView {
                    return currentView
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

#Preview {
    SettingsView()
        .environmentObject(EmulatorSession())
        .environmentObject(AIAssistantSettings())
        .environmentObject(AIDocumentLibraryStore(rootURL: FileManager.default.temporaryDirectory.appendingPathComponent("ViceMacPreviewAIDocuments", isDirectory: true)))
        .environmentObject(MetadataIngestionSettings())
        .environmentObject(QLinkReloadedService(registrationStore: QLinkReloadedRegistrationMemoryStore()))
}
