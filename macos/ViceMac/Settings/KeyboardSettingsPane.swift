import AppKit
import SwiftUI

struct KeyboardSettingsPane: View {
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
