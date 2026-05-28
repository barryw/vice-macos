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
                    Label("Drives", systemImage: "externaldrive")
                }
                .tag(SettingsPaneID.drives.rawValue)

            PrintingSettingsPane()
                .tabItem {
                    Label("Printing", systemImage: "printer")
                }
                .tag(SettingsPaneID.printing.rawValue)

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
    }

    private var showsControlSettings: Bool {
        !emulator.availableControlPorts.isEmpty
    }

    private var selectedPane: SettingsPaneID {
        SettingsPaneID(rawValue: selectedPaneID) ?? .machine
    }

    private func normalizeSelectedPane() {
        guard selectedPane == .controls,
              !showsControlSettings else {
            return
        }

        selectedPaneID = SettingsPaneID.keyboard.rawValue
    }
}

private enum SettingsPaneID: String {
    case machine
    case media
    case sound
    case controls
    case keyboard
    case drives
    case printing
    case display
    case ai

    var title: String {
        switch self {
        case .machine:
            return "Machine"
        case .media:
            return "Media"
        case .sound:
            return "Sound"
        case .controls:
            return "Controls"
        case .keyboard:
            return "Keyboard"
        case .drives:
            return "Drives"
        case .printing:
            return "Printing"
        case .display:
            return "Display"
        case .ai:
            return "AI"
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

private struct SettingsCustomPane<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
    }
}

private struct SettingsTableContainer<Content: View, Footer: View>: View {
    let minHeight: CGFloat
    private let content: Content
    private let footer: Footer

    init(minHeight: CGFloat,
         @ViewBuilder content: () -> Content,
         @ViewBuilder footer: () -> Footer) {
        self.minHeight = minHeight
        self.content = content()
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .frame(minHeight: minHeight)

            Divider()

            footer
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator.opacity(0.55))
        }
    }
}

private struct SettingsSheetLayout<Content: View, Actions: View>: View {
    let title: String
    let width: CGFloat
    let height: CGFloat?
    let minHeight: CGFloat?
    private let content: Content
    private let actions: Actions

    init(title: String,
         width: CGFloat,
         height: CGFloat? = nil,
         minHeight: CGFloat? = nil,
         @ViewBuilder content: () -> Content,
         @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.width = width
        self.height = height
        self.minHeight = minHeight
        self.content = content()
        self.actions = actions()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title3.weight(.semibold))

            content

            HStack {
                Spacer()
                actions
            }
        }
        .padding(22)
        .frame(width: width)
        .frame(height: height)
        .frame(minHeight: minHeight)
    }
}

private struct SettingsValueText: View {
    let text: String
    let lineLimit: Int?
    let truncationMode: Text.TruncationMode
    let color: Color

    init(_ text: String,
         lineLimit: Int? = 1,
         truncationMode: Text.TruncationMode = .tail,
         color: Color = .secondary) {
        self.text = text
        self.lineLimit = lineLimit
        self.truncationMode = truncationMode
        self.color = color
    }

    var body: some View {
        Text(text)
            .foregroundStyle(color)
            .lineLimit(lineLimit)
            .truncationMode(truncationMode)
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

private struct SettingsSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let searchField = NSSearchField(frame: .zero)
        searchField.placeholderString = placeholder
        searchField.sendsSearchStringImmediately = true
        searchField.delegate = context.coordinator
        return searchField
    }

    func updateNSView(_ searchField: NSSearchField, context: Context) {
        if searchField.stringValue != text {
            searchField.stringValue = text
        }

        if searchField.placeholderString != placeholder {
            searchField.placeholderString = placeholder
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        private var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let searchField = notification.object as? NSSearchField else {
                return
            }

            text.wrappedValue = searchField.stringValue
        }
    }
}

private struct KeyboardSettingsPane: View {
    @EnvironmentObject private var emulator: EmulatorSession
    @State private var document: VICEKeymapDocument?
    @State private var selectedEntryID: Int?
    @State private var keyboardFilterKeyID: String?
    @State private var searchText = ""
    @State private var editorState: KeyboardMapEntryEditorState?
    @State private var removalCandidate: VICEKeymapEntry?
    @State private var errorMessage: String?

    var body: some View {
        SettingsCustomPane {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Mode")
                        .font(.body.weight(.medium))
                        .fixedSize()

                    Picker("", selection: modeBinding) {
                        ForEach(VICEKeyboardMappingMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 280)

                    Text("Profile")
                        .font(.body.weight(.medium))
                        .fixedSize()

                    Picker("", selection: profileBinding) {
                        ForEach(VICEKeyboardMappingProfile.allCases) { profile in
                            Text(profile.title).tag(profile)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 210)

                    Spacer()

                    ControlGroup {
                        Button {
                            duplicateDefaultMap()
                        } label: {
                            Label("Duplicate VICE map", systemImage: "doc.on.doc")
                        }
                        .disabled(emulator.keyboardMapping.profile == .custom)
                        .help("Duplicate VICE map")

                        Button {
                            resetToVICEDefault()
                        } label: {
                            Label("Use VICE default", systemImage: "arrow.counterclockwise")
                        }
                        .disabled(emulator.keyboardMapping.profile == .viceDefault)
                        .help("Use VICE default")
                    }
                    .labelStyle(.iconOnly)
                    .controlGroupStyle(.compactMenu)
                }

                HStack(spacing: 10) {
                    Label(emulator.keyboardMapping.mode.shortTitle, systemImage: "keyboard")
                        .foregroundStyle(.secondary)

                    SettingsValueText(activeFileTitle, truncationMode: .middle)
                        .font(.caption)

                    Spacer()

                    SettingsSearchField(text: $searchText, placeholder: "Search mappings")
                        .frame(width: 190, height: 24)
                }

                if let document {
                    MachineKeyboardView(machine: emulator.keyboardMappingMachine,
                                        document: document,
                                        focusedKeyID: focusedKeyboardKey?.targetID,
                                        filterKeyID: $keyboardFilterKeyID)

                    MachineKeyboardSelectionStrip(focusedKey: focusedKeyboardKey,
                                                  entries: focusedKeyboardEntries,
                                                  isFiltering: keyboardFilterKeyID != nil) {
                        keyboardFilterKeyID = nil
                        normalizeSelectedEntry()
                    }
                }

                SettingsTableContainer(minHeight: 255) {
                    Table(filteredEntries, selection: $selectedEntryID) {
                        TableColumn("Mac key") { entry in
                            Text(ViceMacKeyMapper.displayTitle(forKeySymbol: entry.symbol))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        TableColumn("VICE key") { entry in
                            Text(document?.targetDisplayTitle(for: entry) ?? "")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        TableColumn("Mac modifiers") { entry in
                            Text(entry.hostModifierTitle.isEmpty ? "-" : entry.hostModifierTitle)
                                .foregroundStyle(entry.hostModifierTitle.isEmpty ? .tertiary : .secondary)
                        }
                        .width(min: 105, ideal: 112)

                        TableColumn("VICE modifiers") { entry in
                            Text(entry.emulatedModifierTitle.isEmpty ? "-" : entry.emulatedModifierTitle)
                                .foregroundStyle(entry.emulatedModifierTitle.isEmpty ? .tertiary : .secondary)
                        }
                        .width(min: 105, ideal: 112)

                        TableColumn("Behavior") { entry in
                            Text(entry.behaviorTitle.isEmpty ? "-" : entry.behaviorTitle)
                                .foregroundStyle(entry.behaviorTitle.isEmpty ? .tertiary : .secondary)
                        }
                        .width(min: 110, ideal: 125)
                    }
                } footer: {
                    HStack(spacing: 8) {
                        Button {
                            beginAddingMapping()
                        } label: {
                            Label("Add mapping", systemImage: "plus")
                        }
                        .disabled(document == nil)

                        Button {
                            beginEditingSelectedEntry()
                        } label: {
                            Label("Edit mapping", systemImage: "pencil")
                        }
                        .disabled(selectedEntry == nil || document == nil)

                        Button(role: .destructive) {
                            removalCandidate = selectedEntry
                        } label: {
                            Label("Remove mapping", systemImage: "trash")
                        }
                        .disabled(selectedEntry == nil || document == nil)

                        Button {
                            reloadDocument()
                        } label: {
                            Label("Reload", systemImage: "arrow.clockwise")
                        }

                        Spacer()

                        Text(statusTitle)
                            .font(.caption)
                            .foregroundStyle(errorMessage == nil ? Color.secondary : Color.orange)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }
        }
        .onAppear(perform: reloadDocument)
        .onChange(of: emulator.keyboardMapping) { _, _ in
            reloadDocument()
        }
        .onChange(of: emulator.petModel) { _, _ in
            reloadDocument()
        }
        .onChange(of: keyboardFilterKeyID) { _, _ in
            normalizeSelectedEntry()
        }
        .onChange(of: searchText) { _, _ in
            normalizeSelectedEntry()
        }
        .sheet(item: $editorState) { state in
            KeyboardMapEntryEditorSheet(state: state) { entry in
                if emulator.saveKeyboardMapEntry(entry) {
                    reloadDocument()
                    selectedEntryID = entry.id
                }
            }
        }
        .confirmationDialog("Remove keyboard mapping?",
                            isPresented: removalConfirmationBinding,
                            titleVisibility: .visible,
                            presenting: removalCandidate) { entry in
            Button("Remove mapping", role: .destructive) {
                removeMapping(entry)
            }

            Button("Cancel", role: .cancel) {
                removalCandidate = nil
            }
        } message: { entry in
            Text("Remove \(ViceMacKeyMapper.displayTitle(forKeySymbol: entry.symbol)) from \(document?.targetDisplayTitle(for: entry) ?? "this VICE key")?")
        }
    }

    private var modeBinding: Binding<VICEKeyboardMappingMode> {
        Binding {
            emulator.keyboardMapping.mode
        } set: { mode in
            emulator.setKeyboardMappingMode(mode)
        }
    }

    private var profileBinding: Binding<VICEKeyboardMappingProfile> {
        Binding {
            emulator.keyboardMapping.profile
        } set: { profile in
            switch profile {
            case .viceDefault:
                emulator.useVICEKeyboardDefaults()
            case .custom:
                _ = emulator.useCustomKeyboardMapping()
            }
        }
    }

    private var filteredEntries: [VICEKeymapEntry] {
        guard let document else {
            return []
        }

        var entries = document.entries
        if let filteredKeyboardKey {
            entries = entries.filter { filteredKeyboardKey.matches($0) }
        }

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return entries
        }

        return entries.filter { entry in
            let keyTitle = ViceMacKeyMapper.displayTitle(forKeySymbol: entry.symbol).lowercased()
            let targetTitle = document.targetDisplayTitle(for: entry).lowercased()
            return keyTitle.contains(query)
                || entry.symbol.lowercased().contains(query)
                || targetTitle.contains(query)
                || document.targetTitle(for: entry).lowercased().contains(query)
                || entry.behaviorTitle.lowercased().contains(query)
                || entry.flagsTitle.lowercased().contains(query)
        }
    }

    private var selectedEntry: VICEKeymapEntry? {
        guard let selectedEntryID else {
            return nil
        }

        return document?.entries.first { $0.id == selectedEntryID }
    }

    private var filteredKeyboardKey: MachineKeyboardVisualKey? {
        guard let document,
              let keyboardFilterKeyID else {
            return nil
        }

        return MachineKeyboardVisualLayout.make(for: emulator.keyboardMappingMachine,
                                                document: document)
            .key(withID: keyboardFilterKeyID)
    }

    private var focusedKeyboardKey: MachineKeyboardVisualKey? {
        guard let document,
              let focusedKeyboardKeyID else {
            return nil
        }

        return MachineKeyboardVisualLayout.make(for: emulator.keyboardMappingMachine,
                                                document: document)
            .key(withID: focusedKeyboardKeyID)
    }

    private var focusedKeyboardKeyID: String? {
        if let keyboardFilterKeyID {
            return keyboardFilterKeyID
        }

        guard let selectedEntry else {
            return nil
        }

        return MachineKeyboardVisualKey.targetID(row: selectedEntry.row,
                                                 column: selectedEntry.column)
    }

    private var focusedKeyboardEntries: [VICEKeymapEntry] {
        guard let document,
              let focusedKeyboardKey else {
            return []
        }

        return document.entries.filter { focusedKeyboardKey.matches($0) }
    }

    private var activeFileTitle: String {
        switch emulator.keyboardMapping.profile {
        case .viceDefault:
            return VICEKeymapStore.bundledKeymapURL(for: emulator.keyboardMappingMachine,
                                                    mode: emulator.keyboardMapping.mode)?.lastPathComponent
                ?? "VICE map"
        case .custom:
            return VICEKeymapStore.customKeymapURL(for: emulator.keyboardMappingMachine,
                                                   mode: emulator.keyboardMapping.mode).path
        }
    }

    private var statusTitle: String {
        if let errorMessage {
            return errorMessage
        }

        let count = filteredEntries.count
        return "\(count) mapping\(count == 1 ? "" : "s")"
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

    private func reloadDocument() {
        do {
            document = try VICEKeymapStore.document(for: emulator.keyboardMappingMachine,
                                                    configuration: emulator.keyboardMapping)
            errorMessage = nil

            if let keyboardFilterKeyID,
               let document,
               MachineKeyboardVisualLayout.make(for: emulator.keyboardMappingMachine,
                                                document: document)
                   .key(withID: keyboardFilterKeyID) == nil {
                self.keyboardFilterKeyID = nil
            }

            if let selectedEntryID,
               document?.entries.contains(where: { $0.id == selectedEntryID }) != true {
                self.selectedEntryID = nil
            }
            normalizeSelectedEntry()
        } catch {
            document = nil
            selectedEntryID = nil
            keyboardFilterKeyID = nil
            errorMessage = error.localizedDescription
        }
    }

    private func duplicateDefaultMap() {
        if emulator.useCustomKeyboardMapping() {
            reloadDocument()
        }
    }

    private func resetToVICEDefault() {
        emulator.useVICEKeyboardDefaults()
        reloadDocument()
    }

    private func beginAddingMapping() {
        if emulator.keyboardMapping.profile == .viceDefault,
           !emulator.useCustomKeyboardMapping() {
            return
        }

        reloadDocument()
        guard let document else {
            return
        }

        let target = focusedKeyboardKey
            ?? document.matrixKeys.first.map {
                MachineKeyboardVisualKey(title: $0.title,
                                         row: $0.row,
                                         column: $0.column,
                                         unit: 1)
            }
        let entry = VICEKeymapEntry(id: document.nextEntryID,
                                    symbol: "",
                                    row: target?.row ?? 0,
                                    column: target?.column ?? 0,
                                    flags: VICEKeymapFlags.anyShiftState,
                                    trailingComment: nil)
        editorState = KeyboardMapEntryEditorState(entry: entry,
                                                  document: document,
                                                  machine: emulator.keyboardMappingMachine,
                                                  isNew: true)
    }

    private func beginEditingSelectedEntry() {
        guard let selectedEntry else {
            return
        }

        if emulator.keyboardMapping.profile == .viceDefault,
           !emulator.useCustomKeyboardMapping() {
            return
        }

        reloadDocument()
        let entry = document?.entries.first { $0.id == selectedEntry.id } ?? selectedEntry
        editorState = KeyboardMapEntryEditorState(entry: entry,
                                                  document: document ?? VICEKeymapDocument(lines: [],
                                                                                          matrixKeys: []),
                                                  machine: emulator.keyboardMappingMachine,
                                                  isNew: false)
    }

    private func removeMapping(_ entry: VICEKeymapEntry) {
        guard emulator.removeKeyboardMapEntry(entry) else {
            return
        }

        removalCandidate = nil
        reloadDocument()
        normalizeSelectedEntry()
    }

    private func normalizeSelectedEntry() {
        let entries = filteredEntries
        if let selectedEntryID,
           entries.contains(where: { $0.id == selectedEntryID }) {
            return
        }

        selectedEntryID = entries.first?.id
    }
}

private struct MachineKeyboardView: View {
    let machine: EmulatedMachine
    let document: VICEKeymapDocument
    let focusedKeyID: String?
    @Binding var filterKeyID: String?

    private var layout: MachineKeyboardVisualLayout {
        MachineKeyboardVisualLayout.make(for: machine, document: document)
    }

    var body: some View {
        GeometryReader { geometry in
            let horizontalSpacing: CGFloat = 5
            let rowSpacing: CGFloat = 5
            let keyHeight = layout.keyHeight
            let width = max(1, geometry.size.width)
            let keyWidth = max(24, (width - ((layout.maxUnits - 1) * horizontalSpacing)) / layout.maxUnits)

            VStack(alignment: .leading, spacing: rowSpacing) {
                ForEach(Array(layout.rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: horizontalSpacing) {
                        ForEach(Array(row.keys.enumerated()), id: \.offset) { _, key in
                            let itemWidth = keyWidth * key.unit
                                + horizontalSpacing * max(CGFloat.zero, key.unit - 1)
                            if key.isSpacer {
                                Color.clear
                                    .frame(width: itemWidth, height: keyHeight)
                            } else {
                                MachineKeyboardKeyButton(key: key,
                                                         mappingCount: mappingCount(for: key),
                                                         isFocused: key.targetID == focusedKeyID,
                                                         isFiltering: key.targetID == filterKeyID) {
                                    filterKeyID = key.targetID == filterKeyID ? nil : key.targetID
                                }
                                .frame(width: itemWidth, height: keyHeight)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: layout.height)
    }

    private func mappingCount(for key: MachineKeyboardVisualKey) -> Int {
        document.entries.filter { key.matches($0) }.count
    }
}

private struct MachineKeyboardKeyButton: View {
    let key: MachineKeyboardVisualKey
    let mappingCount: Int
    let isFocused: Bool
    let isFiltering: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                if mappingCount > 0 {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(mappingTint)
                        .frame(height: isFocused ? 4 : 3)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }

                Text(key.title)
                    .font(.caption2.weight(isFocused ? .semibold : .regular))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.62)
                    .foregroundColor(mappingCount == 0 ? Color.secondary.opacity(0.62) : Color.primary)
                    .padding(.horizontal, 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(keyBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(keyBorder, lineWidth: isFocused || isFiltering ? 1.5 : 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        .help(helpTitle)
    }

    private var keyBackground: Color {
        if isFocused {
            return Color.accentColor.opacity(0.26)
        }

        if mappingCount == 0 {
            return Color(nsColor: .windowBackgroundColor).opacity(0.5)
        }

        return Color(nsColor: .controlBackgroundColor)
    }

    private var keyBorder: Color {
        if isFiltering {
            return Color.accentColor
        }

        if isFocused {
            return Color.accentColor
        }

        return mappingCount == 0
            ? Color(nsColor: .separatorColor).opacity(0.35)
            : Color(nsColor: .separatorColor).opacity(0.65)
    }

    private var mappingTint: Color {
        isFocused ? Color.accentColor : Color.accentColor.opacity(0.58)
    }

    private var helpTitle: String {
        "\(key.title), \(key.detailTitle), \(mappingCount) Mac mapping\(mappingCount == 1 ? "" : "s")"
    }
}

private struct MachineKeyboardSelectionStrip: View {
    let focusedKey: MachineKeyboardVisualKey?
    let entries: [VICEKeymapEntry]
    let isFiltering: Bool
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            if let focusedKey {
                Label(focusedKey.title, systemImage: "keyboard")
                    .font(.caption.weight(.semibold))

                Text(focusedKey.detailTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Divider()
                    .frame(height: 14)

                Text(mappedKeysTitle)
                    .font(.caption)
                    .foregroundStyle(entries.isEmpty ? Color.orange : Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                if isFiltering {
                    Button(action: onClear) {
                        Label("Clear Key Filter", systemImage: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .help("Clear key filter")
                }
            } else {
                Label("All keys", systemImage: "keyboard")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .frame(height: 18)
    }

    private var mappedKeysTitle: String {
        guard !entries.isEmpty else {
            return "No Mac keys mapped"
        }

        let titles = entries.prefix(6)
            .map { ViceMacKeyMapper.displayTitle(forKeySymbol: $0.symbol) }
            .joined(separator: ", ")
        let overflow = entries.count > 6 ? " +\(entries.count - 6)" : ""
        return "Mapped from \(titles)\(overflow)"
    }
}

private struct MachineKeyboardVisualLayout {
    let rows: [MachineKeyboardVisualRow]

    var maxUnits: CGFloat {
        rows.map(\.unitCount).max() ?? 1
    }

    var keyHeight: CGFloat {
        rows.count > 6 ? 24 : 28
    }

    var height: CGFloat {
        CGFloat(rows.count) * keyHeight + CGFloat(max(rows.count - 1, 0)) * 5
    }

    func key(withID id: String) -> MachineKeyboardVisualKey? {
        rows.lazy
            .flatMap { $0.keys }
            .first { $0.targetID == id }
    }

    static func make(for machine: EmulatedMachine,
                     document: VICEKeymapDocument) -> MachineKeyboardVisualLayout {
        switch machine.family {
        case .c64:
            return c64(document: document)
        case .c128:
            return c128(document: document)
        case .vic20:
            return vic20(document: document)
        case .ted:
            return plus4(document: document)
        case .pet:
            return matrix(document: document)
        }
    }

    private static func c64(document: VICEKeymapDocument) -> MachineKeyboardVisualLayout {
        MachineKeyboardVisualLayout(rows: [
            row([
                key("<-", 7, 1, document), key("1 !", 7, 0, document), key("2 \"", 7, 3, document),
                key("3 #", 1, 0, document), key("4 $", 1, 3, document), key("5 %", 2, 0, document),
                key("6 &", 2, 3, document), key("7 '", 3, 0, document), key("8 (", 3, 3, document),
                key("9 )", 4, 0, document), key("0", 4, 3, document), key("+", 5, 0, document),
                key("-", 5, 3, document), key("POUND", 6, 0, document), key("HOME", 6, 3, document),
                key("DEL", 0, 0, document), spacer(0.55), key("F1", 0, 4, document),
                key("F3", 0, 5, document), key("F5", 0, 6, document), key("F7", 0, 3, document)
            ]),
            row([
                spacer(0.55), key("CTRL", 7, 2, document), key("Q", 7, 6, document),
                key("W", 1, 1, document), key("E", 1, 6, document), key("R", 2, 1, document),
                key("T", 2, 6, document), key("Y", 3, 1, document), key("U", 3, 6, document),
                key("I", 4, 1, document), key("O", 4, 6, document), key("P", 5, 1, document),
                key("@", 5, 6, document), key("*", 6, 1, document), key("^", 6, 6, document),
                special("RESTORE", -3, 0, unit: 1.3)
            ]),
            row([
                key("R/S", 7, 7, document), key("S LOCK", 1, 7, document), key("A", 1, 2, document),
                key("S", 1, 5, document), key("D", 2, 2, document), key("F", 2, 5, document),
                key("G", 3, 2, document), key("H", 3, 5, document), key("J", 4, 2, document),
                key("K", 4, 5, document), key("L", 5, 2, document), key(": [", 5, 5, document),
                key("; ]", 6, 2, document), key("=", 6, 5, document), key("RETURN", 0, 1, document, unit: 1.55)
            ]),
            row([
                key("CBM", 7, 5, document), key("SHIFT", 1, 7, document, unit: 1.35),
                key("Z", 1, 4, document), key("X", 2, 7, document), key("C", 2, 4, document),
                key("V", 3, 7, document), key("B", 3, 4, document), key("N", 4, 7, document),
                key("M", 4, 4, document), key(", <", 5, 7, document), key(". >", 5, 4, document),
                key("/ ?", 6, 7, document), key("SHIFT", 6, 4, document, unit: 1.35),
                key("U/D", 0, 7, document), key("L/R", 0, 2, document)
            ]),
            row([spacer(5.2), key("SPACE", 7, 4, document, unit: 6.8)])
        ])
    }

    private static func vic20(document: VICEKeymapDocument) -> MachineKeyboardVisualLayout {
        MachineKeyboardVisualLayout(rows: [
            row([
                key("<-", 0, 1, document), key("1 !", 0, 0, document), key("2 \"", 0, 7, document),
                key("3 #", 1, 0, document), key("4 $", 1, 7, document), key("5 %", 2, 0, document),
                key("6 &", 2, 7, document), key("7 '", 3, 0, document), key("8 (", 3, 7, document),
                key("9 )", 4, 0, document), key("0", 4, 7, document), key("+", 5, 0, document),
                key("-", 5, 7, document), key("POUND", 6, 0, document), key("HOME", 6, 7, document),
                key("DEL", 7, 0, document), spacer(0.55), key("F1", 7, 4, document),
                key("F3", 7, 5, document), key("F5", 7, 6, document), key("F7", 7, 7, document)
            ]),
            row([
                spacer(0.55), key("CTRL", 0, 2, document), key("Q", 0, 6, document),
                key("W", 1, 1, document), key("E", 1, 6, document), key("R", 2, 1, document),
                key("T", 2, 6, document), key("Y", 3, 1, document), key("U", 3, 6, document),
                key("I", 4, 1, document), key("O", 4, 6, document), key("P", 5, 1, document),
                key("@", 5, 6, document), key("*", 6, 1, document), key("^", 6, 6, document),
                special("RESTORE", -3, 0, unit: 1.3)
            ]),
            row([
                key("R/S", 0, 3, document), key("S LOCK", 1, 3, document), key("A", 1, 2, document),
                key("S", 1, 5, document), key("D", 2, 2, document), key("F", 2, 5, document),
                key("G", 3, 2, document), key("H", 3, 5, document), key("J", 4, 2, document),
                key("K", 4, 5, document), key("L", 5, 2, document), key(": [", 5, 5, document),
                key("; ]", 6, 2, document), key("=", 6, 5, document), key("RETURN", 7, 1, document, unit: 1.55)
            ]),
            row([
                key("CBM", 0, 5, document), key("SHIFT", 1, 3, document, unit: 1.35),
                key("Z", 1, 4, document), key("X", 2, 3, document), key("C", 2, 4, document),
                key("V", 3, 3, document), key("B", 3, 4, document), key("N", 4, 3, document),
                key("M", 4, 4, document), key(", <", 5, 3, document), key(". >", 5, 4, document),
                key("/ ?", 6, 3, document), key("SHIFT", 6, 4, document, unit: 1.35),
                key("U/D", 7, 3, document), key("L/R", 7, 2, document)
            ]),
            row([spacer(5.2), key("SPACE", 0, 4, document, unit: 6.8)])
        ])
    }

    private static func c128(document: VICEKeymapDocument) -> MachineKeyboardVisualLayout {
        MachineKeyboardVisualLayout(rows: [
            row([
                key("ESC", 9, 0, document), key("TAB", 8, 3, document), key("ALT", 10, 0, document),
                special("CAPS", -4, 1), key("HELP", 8, 0, document), key("L/F", 9, 3, document),
                special("40/80", -4, 0), key("NOSCRL", 10, 7, document), spacer(0.55),
                key("UP", 10, 3, document), key("DOWN", 10, 4, document),
                key("LEFT", 10, 5, document), key("RIGHT", 10, 6, document), spacer(0.55),
                key("F1", 0, 4, document), key("F3", 0, 5, document),
                key("F5", 0, 6, document), key("F7", 0, 3, document)
            ]),
            row([
                key("<-", 7, 1, document), key("1 !", 7, 0, document), key("2 \"", 7, 3, document),
                key("3 #", 1, 0, document), key("4 $", 1, 3, document), key("5 %", 2, 0, document),
                key("6 &", 2, 3, document), key("7 '", 3, 0, document), key("8 (", 3, 3, document),
                key("9 )", 4, 0, document), key("0", 4, 3, document), key("+", 5, 0, document),
                key("-", 5, 3, document), key("POUND", 6, 0, document), key("HOME", 6, 3, document),
                key("DEL", 0, 0, document), spacer(0.55), key("KP7", 8, 6, document),
                key("KP8", 8, 1, document), key("KP9", 9, 6, document), key("KP+", 9, 1, document)
            ]),
            row([
                key("CTRL", 7, 2, document), key("Q", 7, 6, document), key("W", 1, 1, document),
                key("E", 1, 6, document), key("R", 2, 1, document), key("T", 2, 6, document),
                key("Y", 3, 1, document), key("U", 3, 6, document), key("I", 4, 1, document),
                key("O", 4, 6, document), key("P", 5, 1, document), key("@", 5, 6, document),
                key("*", 6, 1, document), key("^", 6, 6, document), special("RESTORE", -3, 0, unit: 1.3),
                spacer(0.55), key("KP4", 8, 5, document), key("KP5", 8, 2, document),
                key("KP6", 9, 5, document), key("KP-", 9, 2, document)
            ]),
            row([
                key("R/S", 7, 7, document), key("S LOCK", 1, 7, document), key("A", 1, 2, document),
                key("S", 1, 5, document), key("D", 2, 2, document), key("F", 2, 5, document),
                key("G", 3, 2, document), key("H", 3, 5, document), key("J", 4, 2, document),
                key("K", 4, 5, document), key("L", 5, 2, document), key(": [", 5, 5, document),
                key("; ]", 6, 2, document), key("=", 6, 5, document), key("RETURN", 0, 1, document, unit: 1.55),
                spacer(0.55), key("KP1", 8, 7, document), key("KP2", 8, 4, document),
                key("KP3", 9, 7, document), key("ENTER", 9, 4, document)
            ]),
            row([
                key("CBM", 7, 5, document), key("SHIFT", 1, 7, document, unit: 1.35),
                key("Z", 1, 4, document), key("X", 2, 7, document), key("C", 2, 4, document),
                key("V", 3, 7, document), key("B", 3, 4, document), key("N", 4, 7, document),
                key("M", 4, 4, document), key(", <", 5, 7, document), key(". >", 5, 4, document),
                key("/ ?", 6, 7, document), key("SHIFT", 6, 4, document, unit: 1.35),
                key("U/D", 0, 7, document), key("L/R", 0, 2, document), spacer(0.55),
                key("KP0", 10, 1, document, unit: 2.05), key("KP.", 10, 2, document)
            ]),
            row([spacer(5.2), key("SPACE", 7, 4, document, unit: 6.8)])
        ])
    }

    private static func plus4(document: VICEKeymapDocument) -> MachineKeyboardVisualLayout {
        MachineKeyboardVisualLayout(rows: [
            row([
                spacer(12.5), key("F1/4", 0, 4, document), key("F2/5", 0, 5, document),
                key("F3/6", 0, 6, document), key("HELP/F7", 0, 3, document, unit: 1.3)
            ]),
            row([
                key("ESC", 6, 4, document), key("1 !", 7, 0, document), key("2 \"", 7, 3, document),
                key("3 #", 1, 0, document), key("4 $", 1, 3, document), key("5 %", 2, 0, document),
                key("6 &", 2, 3, document), key("7 '", 3, 0, document), key("8 (", 3, 3, document),
                key("9 )", 4, 0, document), key("0 ^", 4, 3, document), key("+", 6, 6, document),
                key("-", 5, 6, document), key("=/PI", 6, 5, document), key("CLR", 7, 1, document),
                key("DEL", 0, 0, document)
            ]),
            row([
                key("CTRL", 7, 2, document), key("Q", 7, 6, document), key("W", 1, 1, document),
                key("E", 1, 6, document), key("R", 2, 1, document), key("T", 2, 6, document),
                key("Y", 3, 1, document), key("U", 3, 6, document), key("I", 4, 1, document),
                key("O", 4, 6, document), key("P", 5, 1, document), key("@", 0, 7, document),
                key("POUND", 0, 2, document), key("*", 6, 1, document)
            ]),
            row([
                key("R/S", 7, 7, document), key("SHIFT", 1, 7, document, unit: 1.35),
                key("A", 1, 2, document), key("S", 1, 5, document), key("D", 2, 2, document),
                key("F", 2, 5, document), key("G", 3, 2, document), key("H", 3, 5, document),
                key("J", 4, 2, document), key("K", 4, 5, document), key("L", 5, 2, document),
                key(": [", 5, 5, document), key("; ]", 6, 2, document), key("RETURN", 0, 1, document, unit: 1.55)
            ]),
            row([
                key("CBM", 7, 5, document), key("SHIFT", 1, 7, document, unit: 1.35),
                key("Z", 1, 4, document), key("X", 2, 7, document), key("C", 2, 4, document),
                key("V", 3, 7, document), key("B", 3, 4, document), key("N", 4, 7, document),
                key("M", 4, 4, document), key(", <", 5, 7, document), key(". >", 5, 4, document),
                key("/ ?", 6, 7, document), key("SHIFT", 1, 7, document, unit: 1.35),
                key("UP", 5, 3, document)
            ]),
            row([
                spacer(4.6), key("SPACE", 7, 4, document, unit: 6.8), spacer(1.25),
                key("LEFT", 6, 0, document), key("RIGHT", 6, 3, document), key("DOWN", 5, 0, document)
            ])
        ])
    }

    private static func matrix(document: VICEKeymapDocument) -> MachineKeyboardVisualLayout {
        let groupedKeys = Dictionary(grouping: document.matrixKeys) { $0.row }
        let rows = groupedKeys.keys.sorted().map { rowNumber in
            row((0..<8).map { column in
                if let key = groupedKeys[rowNumber]?.first(where: { $0.column == column }) {
                    return MachineKeyboardVisualKey(title: displayTitle(key.title),
                                                    row: key.row,
                                                    column: key.column,
                                                    unit: 1)
                }

                return spacer()
            })
        }

        return MachineKeyboardVisualLayout(rows: rows)
    }

    private static func row(_ keys: [MachineKeyboardVisualKey]) -> MachineKeyboardVisualRow {
        MachineKeyboardVisualRow(keys: keys)
    }

    private static func key(_ title: String,
                            _ row: Int,
                            _ column: Int,
                            _ document: VICEKeymapDocument,
                            unit: CGFloat = 1) -> MachineKeyboardVisualKey {
        let matrixTitle = document.matrixKey(row: row, column: column)?.title
        return MachineKeyboardVisualKey(title: displayTitle(matrixTitle ?? title),
                                        row: row,
                                        column: column,
                                        unit: unit)
    }

    private static func special(_ title: String,
                                _ row: Int,
                                _ column: Int,
                                unit: CGFloat = 1) -> MachineKeyboardVisualKey {
        MachineKeyboardVisualKey(title: displayTitle(title),
                                 row: row,
                                 column: column,
                                 unit: unit)
    }

    private static func spacer(_ unit: CGFloat = 1) -> MachineKeyboardVisualKey {
        MachineKeyboardVisualKey(title: "",
                                 row: nil,
                                 column: nil,
                                 unit: unit)
    }

    private static func displayTitle(_ title: String) -> String {
        switch title.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "Retrn":
            return "RETURN"
        case "C_L/R":
            return "L/R"
        case "C_U/D":
            return "U/D"
        case "A_LFT":
            return "<-"
        case "A_UP":
            return "^"
        case "S_L", "S_R", "SHIFTs":
            return "SHIFT"
        case "C=":
            return "CBM"
        default:
            return title.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "   ", with: " ")
                .replacingOccurrences(of: "  ", with: " ")
        }
    }
}

private struct MachineKeyboardVisualRow {
    let keys: [MachineKeyboardVisualKey]

    var unitCount: CGFloat {
        keys.reduce(CGFloat.zero) { $0 + $1.unit }
    }
}

private struct MachineKeyboardVisualKey: Hashable {
    let title: String
    let row: Int?
    let column: Int?
    let unit: CGFloat

    var isSpacer: Bool {
        row == nil || column == nil
    }

    var targetID: String? {
        guard let row,
              let column else {
            return nil
        }

        return Self.targetID(row: row, column: column)
    }

    static func targetID(row: Int, column: Int) -> String {
        "\(row):\(column)"
    }

    var detailTitle: String {
        guard let row,
              let column else {
            return ""
        }

        switch row {
        case -3:
            return column == 0 ? "RESTORE" : "RESTORE alternate"
        case -4:
            return column == 0 ? "40/80 column key" : "CAPS key"
        default:
            return "row \(row), column \(column)"
        }
    }

    func matches(_ entry: VICEKeymapEntry) -> Bool {
        row == entry.row && column == entry.column
    }
}

private struct KeyboardMapEntryEditorState: Identifiable {
    let id = UUID()
    let entry: VICEKeymapEntry
    let document: VICEKeymapDocument
    let machine: EmulatedMachine
    let isNew: Bool
}

private struct KeyboardMapEntryEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var entry: VICEKeymapEntry
    @State private var flags: Int
    @State private var showsVICECompatibility = false

    let document: VICEKeymapDocument
    let machine: EmulatedMachine
    let isNew: Bool
    let onSave: (VICEKeymapEntry) -> Void

    init(state: KeyboardMapEntryEditorState,
         onSave: @escaping (VICEKeymapEntry) -> Void) {
        document = state.document
        machine = state.machine
        isNew = state.isNew
        self.onSave = onSave
        _entry = State(initialValue: state.entry)
        _flags = State(initialValue: state.entry.flags ?? VICEKeymapFlags.anyShiftState)
    }

    var body: some View {
        SettingsSheetLayout(title: isNew ? "Add keyboard mapping" : "Edit keyboard mapping",
                            width: 680,
                            height: 680) {
            Form {
                Section("Mac key") {
                    LabeledContent("Key") {
                        HStack(spacing: 10) {
                            KeySymbolCaptureButton(symbol: $entry.symbol)

                            Text(entry.symbol)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("VICE key") {
                    KeyboardTargetPicker(machine: machine,
                                         document: document,
                                         entry: $entry)
                }

                Section("Mac modifiers") {
                    Toggle("Shift must be held on the Mac", isOn: flagBinding(VICEKeymapFlags.hostShift))
                    Toggle("Option must be held on the Mac", isOn: flagBinding(VICEKeymapFlags.hostOption))
                    Toggle("Control must be held on the Mac", isOn: flagBinding(VICEKeymapFlags.hostControl))
                }

                Section("VICE modifiers") {
                    Toggle("Hold VICE Shift with this key", isOn: flagBinding(VICEKeymapFlags.emulatedShift))
                    Toggle("Hold Commodore with this key", isOn: flagBinding(VICEKeymapFlags.emulatedCBM))
                    Toggle("Hold VICE Control with this key", isOn: flagBinding(VICEKeymapFlags.emulatedControl))
                }

                Section("Behavior") {
                    Toggle("Works in either Mac shift state", isOn: flagBinding(VICEKeymapFlags.anyShiftState))
                    DisclosureGroup("VICE compatibility", isExpanded: $showsVICECompatibility) {
                        Toggle("Deshift when needed", isOn: flagBinding(VICEKeymapFlags.deshift))
                        Toggle("Alternate mapping continues below", isOn: flagBinding(VICEKeymapFlags.continues))
                        Toggle("This is Shift Lock", isOn: flagBinding(VICEKeymapFlags.shiftLock))

                        if machine.family == .c128 {
                            Toggle("Only in C64 mode", isOn: flagBinding(VICEKeymapFlags.c64Mode))
                        }

                        Toggle("This key is left Shift", isOn: flagBinding(VICEKeymapFlags.leftShiftKey))
                        Toggle("This key is right Shift", isOn: flagBinding(VICEKeymapFlags.rightShiftKey))
                        Toggle("This key is Commodore", isOn: flagBinding(VICEKeymapFlags.cbmKey))
                        Toggle("This key is VICE Control", isOn: flagBinding(VICEKeymapFlags.controlKey))

                        LabeledContent("VICE value") {
                            Text(String(format: "0x%04x", flags))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }

                    LabeledContent("Summary") {
                        Text(decodedFlagsTitle)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !conflictingEntries.isEmpty {
                    Section("Conflict") {
                        LabeledContent("Also mapped") {
                            Text(conflictTitle)
                                .foregroundStyle(.orange)
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

            Button("Save") {
                entry.flags = flags
                onSave(entry)
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!canSave)
        }
    }

    private var canSave: Bool {
        !entry.symbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var decodedFlagsTitle: String {
        let previewEntry = VICEKeymapEntry(id: entry.id,
                                           symbol: entry.symbol,
                                           row: entry.row,
                                           column: entry.column,
                                           flags: flags,
                                           trailingComment: entry.trailingComment)

        var decoded: [String] = []
        if !previewEntry.hostModifierTitle.isEmpty {
            decoded.append("Mac \(previewEntry.hostModifierTitle)")
        }
        if !previewEntry.emulatedModifierTitle.isEmpty {
            decoded.append("VICE \(previewEntry.emulatedModifierTitle)")
        }
        if !previewEntry.behaviorTitle.isEmpty {
            decoded.append(previewEntry.behaviorTitle)
        }

        return decoded.isEmpty ? "none" : decoded
            .joined(separator: "; ")
    }

    private func flagBinding(_ flag: Int) -> Binding<Bool> {
        Binding {
            flags & flag != 0
        } set: { isEnabled in
            if isEnabled {
                flags |= flag
            } else {
                flags &= ~flag
            }
        }
    }

    private var conflictingEntries: [VICEKeymapEntry] {
        document.entries.filter { candidate in
            candidate.id != entry.id && candidate.symbol == entry.symbol
        }
    }

    private var conflictTitle: String {
        conflictingEntries
            .prefix(3)
            .map { document.targetTitle(for: $0) }
            .joined(separator: ", ")
    }
}

private enum KeyboardTargetKind: String, CaseIterable, Identifiable {
    case keyboard
    case special

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keyboard:
            return "Keyboard"
        case .special:
            return "Special"
        }
    }
}

private struct KeyboardTargetPicker: View {
    let machine: EmulatedMachine
    let document: VICEKeymapDocument
    @Binding var entry: VICEKeymapEntry
    @State private var targetKind: KeyboardTargetKind

    init(machine: EmulatedMachine,
         document: VICEKeymapDocument,
         entry: Binding<VICEKeymapEntry>) {
        self.machine = machine
        self.document = document
        _entry = entry
        _targetKind = State(initialValue: entry.wrappedValue.row < 0 ? .special : .keyboard)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if specialTargets.isEmpty {
                MatrixKeyPicker(document: document, entry: $entry)
            } else {
                Picker("Target", selection: $targetKind) {
                    ForEach(KeyboardTargetKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                switch targetKind {
                case .keyboard:
                    MatrixKeyPicker(document: document, entry: $entry)
                case .special:
                    SpecialKeyPicker(targets: specialTargets, entry: $entry)
                }
            }
        }
    }

    private var specialTargets: [KeyboardSpecialTarget] {
        KeyboardSpecialTarget.targets(for: machine)
    }
}

private struct SpecialKeyPicker: View {
    let targets: [KeyboardSpecialTarget]
    @Binding var entry: VICEKeymapEntry

    private let columns = [
        GridItem(.adaptive(minimum: 128), spacing: 6)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(targets) { target in
                    Button {
                        entry.row = target.row
                        entry.column = target.column
                    } label: {
                        Text(target.title)
                            .font(.caption.weight(isSelected(target) ? .semibold : .regular))
                            .lineLimit(2)
                            .minimumScaleFactor(0.74)
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(isSelected(target) ? .accentColor : nil)
                    .help(target.detailTitle)
                }
            }
        }
        .frame(maxHeight: 245)
    }

    private func isSelected(_ target: KeyboardSpecialTarget) -> Bool {
        entry.row == target.row && entry.column == target.column
    }
}

private struct KeyboardSpecialTarget: Identifiable {
    let row: Int
    let column: Int
    let title: String

    var id: String {
        "\(row):\(column)"
    }

    var detailTitle: String {
        "row \(row), column \(column)"
    }

    static func targets(for machine: EmulatedMachine) -> [KeyboardSpecialTarget] {
        var targets: [KeyboardSpecialTarget] = []

        if machine.family == .c64 || machine.family == .c128 || machine.family == .vic20 || machine.family == .ted {
            targets.append(target(-3, 0))
            targets.append(target(-3, 1))
        }

        if machine.family == .c128 {
            targets.append(target(-4, 0))
            targets.append(target(-4, 1))
        }

        if !machine.capabilities.controlPorts.isEmpty {
            for row in [-1, -2] {
                for column in 0...8 {
                    targets.append(target(row, column))
                }
            }
        }

        if machine.family == .c64 || machine.family == .vic20 || machine.family == .ted {
            for column in 0...19 {
                targets.append(target(-5, column))
            }
        }

        return targets
    }

    private static func target(_ row: Int, _ column: Int) -> KeyboardSpecialTarget {
        KeyboardSpecialTarget(row: row,
                              column: column,
                              title: VICEKeymapDocument.specialTargetTitle(row: row,
                                                                           column: column))
    }
}

private struct MatrixKeyPicker: View {
    let document: VICEKeymapDocument
    @Binding var entry: VICEKeymapEntry

    private let columns = Array(repeating: GridItem(.flexible(minimum: 52), spacing: 5), count: 8)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if document.matrixKeys.isEmpty {
                Text(document.targetTitle(for: entry))
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 5) {
                        ForEach(document.matrixKeys) { key in
                            Button {
                                entry.row = key.row
                                entry.column = key.column
                            } label: {
                                Text(key.title)
                                    .font(.caption.weight(isSelected(key) ? .semibold : .regular))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                                    .frame(maxWidth: .infinity, minHeight: 28)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(isSelected(key) ? .accentColor : nil)
                            .help(key.detailTitle)
                        }
                    }
                }
                .frame(maxHeight: 245)
            }
        }
    }

    private func isSelected(_ key: VICEKeyboardMatrixKey) -> Bool {
        entry.row == key.row && entry.column == key.column
    }
}

private struct KeySymbolCaptureButton: View {
    @Binding var symbol: String
    @State private var isCapturing = false

    var body: some View {
        Button {
            isCapturing = true
        } label: {
            Text(buttonTitle)
                .frame(minWidth: 132)
        }
        .background {
            KeySymbolCaptureMonitor(isCapturing: $isCapturing) { capturedSymbol in
                symbol = capturedSymbol
            }
        }
    }

    private var buttonTitle: String {
        if isCapturing {
            return "Press a key"
        }

        let title = ViceMacKeyMapper.displayTitle(forKeySymbol: symbol)
        return title.isEmpty ? "Press a key" : title
    }
}

private struct KeySymbolCaptureMonitor: NSViewRepresentable {
    @Binding var isCapturing: Bool
    let onCapture: (String) -> Void

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
        private var onCapture: (String) -> Void
        private var monitor: Any?

        init(isCapturing: Binding<Bool>, onCapture: @escaping (String) -> Void) {
            self.isCapturing = isCapturing
            self.onCapture = onCapture
            updateMonitor()
        }

        deinit {
            removeMonitor()
        }

        func update(isCapturing: Binding<Bool>, onCapture: @escaping (String) -> Void) {
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

                guard let symbol = ViceMacKeyMapper.keySymbolName(for: event) else {
                    return event
                }

                onCapture(symbol)
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
                                Label("Clear API key", systemImage: "xmark.circle")
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
                                Label("Choose model", systemImage: "list.bullet")
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
                                Label("Fetch models", systemImage: "arrow.clockwise")
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
                        SettingsValueText("Hidden")
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
                    SettingsValueText("Input and memory tools enabled", lineLimit: nil)
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
                Section("ROM images") {
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
                        TextField("Name", text: $device.name)
                            .textFieldStyle(.roundedBorder)
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
            return 560
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

    var body: some View {
        Picker("Hardware", selection: preferredControllerBinding) {
            Text("Any connected controller").tag("")

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

            Toggle("Protect inserted disks", isOn: $drive.protectsInsertedDisks)
                .disabled(!drive.isAttached)

            Toggle("Drive sounds", isOn: $drive.soundEnabled)
                .disabled(!drive.isAttached)

            LabeledContent("Sound volume") {
                SettingsPercentSlider(value: $drive.soundVolume,
                                      isEnabled: drive.isAttached && drive.soundEnabled,
                                      onEditingChanged: handleVolumeEditingChanged)
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
}
