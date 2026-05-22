import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DiskImageManagerFocusedActions {
    var createImage: @MainActor () -> Void
    var openImage: @MainActor () -> Void
    var canSaveActiveImage: Bool
    var saveActiveImage: @MainActor () -> Void
    var canImportProgram: Bool
    var importProgram: @MainActor () -> Void
    var canExportSelectedFile: Bool
    var exportSelectedFile: @MainActor () -> Void
    var canCloneOptimizedImage: Bool
    var cloneOptimizedImage: @MainActor () -> Void
    var canRenameSelectedFile: Bool
    var renameSelectedFile: @MainActor () -> Void
    var canDeleteSelectedFile: Bool
    var deleteSelectedFile: @MainActor () -> Void
}

private struct DiskImageManagerFocusedActionsKey: FocusedValueKey {
    typealias Value = DiskImageManagerFocusedActions
}

extension FocusedValues {
    var diskImageManagerActions: DiskImageManagerFocusedActions? {
        get { self[DiskImageManagerFocusedActionsKey.self] }
        set { self[DiskImageManagerFocusedActionsKey.self] = newValue }
    }
}

@MainActor
final class DiskImageManagerModel: ObservableObject {
    struct NewImageDraft: Identifiable {
        let id = UUID()
        var pane: Pane
        var format: CommodoreDiskImageFormat = .d64
        var diskName = "VICE MAC"
        var diskID = "VM"
    }

    struct RenameDraft: Identifiable {
        let id = UUID()
        var pane: Pane
        var entryID: CommodoreDiskDirectoryEntry.ID
        var fileName: String
    }

    enum Pane: Hashable {
        case left
        case right

        var opposite: Pane {
            self == .left ? .right : .left
        }

        var title: String {
            self == .left ? "Left Image" : "Right Image"
        }
    }

    struct PaneState {
        var image: CommodoreDiskImage?
        var entries: [CommodoreDiskDirectoryEntry] = []
        var fileByteCounts: [CommodoreDiskDirectoryEntry.ID: Int] = [:]
        var sectors: [CommodoreDiskSector] = []
        var selectedEntryID: CommodoreDiskDirectoryEntry.ID?
        var selectedAddress: CommodoreDiskAddress?
        var sectorEditorText = ""
        var searchText = ""
        var message: String?
        var errorMessage: String?

        var selectedEntry: CommodoreDiskDirectoryEntry? {
            entries.first { $0.id == selectedEntryID }
        }

        var selectedSector: CommodoreDiskSector? {
            guard let selectedAddress else {
                return nil
            }

            return sectors.first { $0.address == selectedAddress }
        }
    }

    @Published var left = PaneState()
    @Published var right = PaneState()
    @Published var activePane: Pane = .left
    @Published var newImageDraft: NewImageDraft?
    @Published var renameDraft: RenameDraft?

    var canCopyLeftToRight: Bool {
        canCopy(from: .left, to: .right)
    }

    var canCopyRightToLeft: Bool {
        canCopy(from: .right, to: .left)
    }

    func openImage(in pane: Pane) {
        let panel = NSOpenPanel()
        panel.title = "Open Disk Image"
        panel.message = "Choose a Commodore block disk image."
        panel.prompt = "Open"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = Self.openableContentTypes

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        do {
            try openImage(url: url, in: pane)
        } catch {
            setError(error.localizedDescription, for: pane)
        }
    }

    func openImage(url: URL, in pane: Pane) throws {
        let image = try CommodoreDiskImage(url: url)
        setState(for: pane) { state in
            state.image = image
            state.message = "Opened \(image.displayName)"
            state.errorMessage = nil
            refresh(&state)
        }
        activePane = pane
    }

    func presentNewImage(in pane: Pane) {
        activePane = pane
        newImageDraft = NewImageDraft(pane: pane)
    }

    func createImage(from draft: NewImageDraft) {
        let panel = NSSavePanel()
        panel.title = "Create Disk Image"
        panel.message = "Create a blank Commodore disk image."
        panel.prompt = "Create"
        panel.allowedContentTypes = [UTType(filenameExtension: draft.format.rawValue)].compactMap { $0 }
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(Self.safeFilename(draft.diskName)).\(draft.format.rawValue)"

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        do {
            let image = try CommodoreDiskImage(blankImageAt: url,
                                               format: draft.format,
                                               diskName: draft.diskName,
                                               diskID: draft.diskID)
            setState(for: draft.pane) { state in
                state.image = image
                state.message = "Created \(image.displayName)"
                state.errorMessage = nil
                refresh(&state)
            }
            activePane = draft.pane
        } catch {
            setError(error.localizedDescription, for: draft.pane)
        }
    }

    func saveImage(in pane: Pane) {
        do {
            try setImage(in: pane) { image in
                try image.save()
            }
            setMessage("Saved.", for: pane)
        } catch {
            setError(error.localizedDescription, for: pane)
        }
    }

    func copySelectedFile(from sourcePane: Pane, to destinationPane: Pane) {
        guard let source = state(for: sourcePane).image,
              let entry = state(for: sourcePane).selectedEntry else {
            return
        }

        do {
            try setImage(in: destinationPane) { destination in
                try destination.copyFile(entry, from: source)
            }
            setMessage("Copied \(entry.name). Save the image to keep the change.", for: destinationPane)
        } catch {
            setError(error.localizedDescription, for: destinationPane)
        }
    }

    func importProgram(into pane: Pane) {
        guard state(for: pane).image != nil else {
            return
        }

        let panel = NSOpenPanel()
        panel.title = "Import Program"
        panel.message = "Choose a PRG file to add to the disk image."
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = Self.programContentTypes

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        do {
            let payload = try Data(contentsOf: url)
            try setImage(in: pane) { image in
                try image.importFile(named: url.deletingPathExtension().lastPathComponent,
                                     payload: payload)
            }
            setMessage("Imported \(url.lastPathComponent). Save the image to keep the change.", for: pane)
        } catch {
            setError(error.localizedDescription, for: pane)
        }
    }

    func exportSelectedFile(from pane: Pane) {
        guard let image = state(for: pane).image,
              let entry = state(for: pane).selectedEntry else {
            return
        }

        let panel = NSSavePanel()
        panel.title = "Export File"
        panel.message = "Export \(entry.name) from the disk image."
        panel.prompt = "Export"
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = Self.exportFilename(for: entry)

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        do {
            let payload = try image.fileData(for: entry)
            try payload.write(to: url, options: .atomic)
            setMessage("Exported \(entry.name).", for: pane)
        } catch {
            setError(error.localizedDescription, for: pane)
        }
    }

    func cloneOptimizedImage(in pane: Pane) {
        guard let image = state(for: pane).image else {
            return
        }

        let analysis = image.rebuildAnalysis()
        guard confirmOptimizedClone(for: image, analysis: analysis) else {
            return
        }

        let panel = NSSavePanel()
        panel.title = "Clone Optimized Disk Image"
        panel.message = "Create a rebuilt copy with drive-aware sector interleave. The original image is not modified."
        panel.prompt = "Clone"
        panel.allowedContentTypes = [UTType(filenameExtension: image.format.rawValue)].compactMap { $0 }
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = Self.optimizedFilename(for: image)

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        do {
            let rebuilt = try image.cloneOptimized(to: url)
            setState(for: pane) { state in
                state.image = rebuilt
                state.message = "Created optimized copy \(rebuilt.displayName)."
                state.errorMessage = nil
                refresh(&state)
            }
            activePane = pane
        } catch {
            setError(error.localizedDescription, for: pane)
        }
    }

    func presentRenameSelectedFile(in pane: Pane) {
        guard let entry = state(for: pane).selectedEntry else {
            return
        }

        activePane = pane
        renameDraft = RenameDraft(pane: pane,
                                  entryID: entry.id,
                                  fileName: entry.name)
    }

    func renameSelectedFile(from draft: RenameDraft) {
        guard let entry = state(for: draft.pane).entries.first(where: { $0.id == draft.entryID }) else {
            setError(CommodoreDiskImageError.fileNotFound(draft.fileName).localizedDescription, for: draft.pane)
            return
        }

        do {
            try setImage(in: draft.pane) { image in
                try image.renameFile(entry, to: draft.fileName)
            }
            setMessage("Renamed file. Save the image to keep the change.", for: draft.pane)
        } catch {
            setError(error.localizedDescription, for: draft.pane)
        }
    }

    func deleteSelectedFile(in pane: Pane) {
        guard let entry = state(for: pane).selectedEntry else {
            return
        }

        let alert = NSAlert()
        alert.messageText = "Delete \(entry.name)?"
        alert.informativeText = "The file will be removed from the disk directory and its blocks will be marked free. Save the image to keep the change."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        do {
            try setImage(in: pane) { image in
                try image.deleteFile(entry)
            }
            setMessage("Deleted \(entry.name). Save the image to keep the change.", for: pane)
        } catch {
            setError(error.localizedDescription, for: pane)
        }
    }

    func selectSector(_ address: CommodoreDiskAddress, in pane: Pane) {
        activePane = pane
        setState(for: pane) { state in
            guard let image = state.image,
                  let bytes = try? image.readSector(address) else {
                return
            }

            state.selectedAddress = address
            state.sectorEditorText = CommodoreHexDump.text(for: bytes)
            state.message = "Selected T\(address.track) S\(address.sector)"
            state.errorMessage = nil
        }
    }

    func reloadSelectedSector(in pane: Pane) {
        guard let address = state(for: pane).selectedAddress else {
            return
        }

        selectSector(address, in: pane)
    }

    func writeSelectedSector(in pane: Pane) {
        guard let address = state(for: pane).selectedAddress else {
            return
        }

        do {
            let bytes = try CommodoreHexDump.data(from: state(for: pane).sectorEditorText)
            try setImage(in: pane) { image in
                try image.writeSector(bytes, at: address)
            }
            setMessage("Wrote T\(address.track) S\(address.sector). Save the image to keep the change.", for: pane)
        } catch {
            setError(error.localizedDescription, for: pane)
        }
    }

    func bindingForSelection(in pane: Pane) -> Binding<CommodoreDiskDirectoryEntry.ID?> {
        Binding {
            self.state(for: pane).selectedEntryID
        } set: { selection in
            self.activePane = pane
            self.setState(for: pane) { state in
                state.selectedEntryID = selection
            }
        }
    }

    func bindingForSearch(in pane: Pane) -> Binding<String> {
        Binding {
            self.state(for: pane).searchText
        } set: { text in
            self.activePane = pane
            self.setState(for: pane) { state in
                state.searchText = text
            }
        }
    }

    func bindingForSectorEditor(in pane: Pane) -> Binding<String> {
        Binding {
            self.state(for: pane).sectorEditorText
        } set: { text in
            self.activePane = pane
            self.setState(for: pane) { state in
                state.sectorEditorText = text
            }
        }
    }

    func state(for pane: Pane) -> PaneState {
        switch pane {
        case .left:
            return left
        case .right:
            return right
        }
    }

    func filteredEntries(in pane: Pane) -> [CommodoreDiskDirectoryEntry] {
        let state = state(for: pane)
        let query = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return state.entries
        }

        return state.entries.filter { entry in
            entry.name.localizedCaseInsensitiveContains(query)
                || entry.typeText.localizedCaseInsensitiveContains(query)
        }
    }

    private func canCopy(from sourcePane: Pane, to destinationPane: Pane) -> Bool {
        guard state(for: sourcePane).selectedEntry != nil,
              state(for: sourcePane).image != nil,
              let destination = state(for: destinationPane).image else {
            return false
        }

        return destination.geometry.supportsFileWrites
    }

    private func confirmOptimizedClone(for image: CommodoreDiskImage,
                                       analysis: CommodoreDiskRebuildAnalysis) -> Bool {
        if !analysis.canRebuild {
            let alert = NSAlert()
            alert.messageText = analysis.statusTitle
            alert.informativeText = issueText(for: analysis.blockingIssues)
            alert.alertStyle = .critical
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return false
        }

        let visibleIssues = analysis.issues.filter { $0.severity != .info }
        guard !visibleIssues.isEmpty else {
            return true
        }

        let alert = NSAlert()
        alert.messageText = "Clone \(image.displayName) with warnings?"
        alert.informativeText = "\(analysis.statusDetail)\n\n\(issueText(for: visibleIssues))"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clone Copy")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func issueText(for issues: [CommodoreDiskRebuildIssue]) -> String {
        let visible = issues.prefix(8).map { issue in
            "- \(issue.severity.label): \(issue.title). \(issue.detail)"
        }
        let suffix = issues.count > visible.count ? "\n- \(issues.count - visible.count) more issue\(issues.count - visible.count == 1 ? "" : "s")." : ""
        return visible.joined(separator: "\n") + suffix
    }

    private func setMessage(_ message: String, for pane: Pane) {
        setState(for: pane) { state in
            state.message = message
            state.errorMessage = nil
            refresh(&state)
        }
    }

    private func setError(_ message: String, for pane: Pane) {
        setState(for: pane) { state in
            state.errorMessage = message
            state.message = nil
        }
    }

    private func setImage(in pane: Pane, mutate: (inout CommodoreDiskImage) throws -> Void) throws {
        var state = state(for: pane)
        guard var image = state.image else {
            return
        }

        try mutate(&image)
        state.image = image
        refresh(&state)

        switch pane {
        case .left:
            left = state
        case .right:
            right = state
        }
    }

    private func setState(for pane: Pane, mutate: (inout PaneState) -> Void) {
        switch pane {
        case .left:
            mutate(&left)
        case .right:
            mutate(&right)
        }
    }

    private func refresh(_ state: inout PaneState) {
        guard let image = state.image else {
            state.entries = []
            state.fileByteCounts = [:]
            state.sectors = []
            state.selectedAddress = nil
            state.sectorEditorText = ""
            return
        }

        do {
            state.entries = try image.directoryEntries()
            state.fileByteCounts = Dictionary(uniqueKeysWithValues: state.entries.map { entry in
                (entry.id, (try? image.fileData(for: entry).count) ?? 0)
            })
            state.sectors = image.sectorMap()

            if state.selectedAddress == nil {
                state.selectedAddress = image.geometry.directoryStart
            }

            if let address = state.selectedAddress,
               let bytes = try? image.readSector(address) {
                state.sectorEditorText = CommodoreHexDump.text(for: bytes)
            }

            if let selectedEntryID = state.selectedEntryID,
               !state.entries.contains(where: { $0.id == selectedEntryID }) {
                state.selectedEntryID = nil
            }
        } catch {
            state.errorMessage = error.localizedDescription
        }
    }

    private static var openableContentTypes: [UTType] {
        CommodoreDiskImageFormat.allCases.compactMap { format in
            UTType(filenameExtension: format.rawValue)
        }
    }

    private static var programContentTypes: [UTType] {
        [UTType(filenameExtension: "prg")].compactMap { $0 }
    }

    private static func exportFilename(for entry: CommodoreDiskDirectoryEntry) -> String {
        let stem = safeFilename(entry.name)
        let suffix = entry.type.rawValue.lowercased()
        return "\(stem).\(suffix)"
    }

    private static func optimizedFilename(for image: CommodoreDiskImage) -> String {
        let stem = image.url.deletingPathExtension().lastPathComponent
        return "\(safeFilename(stem))-optimized.\(image.format.rawValue)"
    }

    private static func safeFilename(_ string: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:")
            .union(.controlCharacters)
        let cleaned = string
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "UNTITLED" : cleaned
    }
}

struct DiskImageManagerView: View {
    @StateObject private var model = DiskImageManagerModel()

    var body: some View {
        HStack(spacing: 0) {
            DiskImagePaneView(model: model, pane: .left)

            Divider()

            CopyRailView(model: model)
                .frame(width: 76)

            Divider()

            DiskImagePaneView(model: model, pane: .right)
        }
        .frame(minWidth: 1_080, idealWidth: 1_180, minHeight: 720, idealHeight: 780)
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.presentNewImage(in: model.activePane)
                } label: {
                    Label("New Disk Image", systemImage: "document.badge.plus")
                }
                .help("Create a blank disk image in the active pane")

                Button {
                    model.openImage(in: .left)
                } label: {
                    Label("Open Left Image", systemImage: "sidebar.left")
                }
                .help("Open left disk image")

                Button {
                    model.openImage(in: .right)
                } label: {
                    Label("Open Right Image", systemImage: "sidebar.right")
                }
                .help("Open right disk image")

                Divider()

                Button {
                    model.importProgram(into: model.activePane)
                } label: {
                    Label("Import PRG", systemImage: "tray.and.arrow.down")
                }
                .disabled(model.state(for: model.activePane).image?.geometry.supportsFileWrites != true)
                .help("Import a PRG into the active disk image")

                Button {
                    model.exportSelectedFile(from: model.activePane)
                } label: {
                    Label("Export File", systemImage: "tray.and.arrow.up")
                }
                .disabled(model.state(for: model.activePane).selectedEntry == nil)
                .help("Export selected file from the active disk image")

                Button {
                    model.cloneOptimizedImage(in: model.activePane)
                } label: {
                    Label("Clone Optimized", systemImage: "wand.and.stars")
                }
                .disabled(model.state(for: model.activePane).image == nil)
                .help("Create an optimized rebuilt copy of the active disk image")

                Divider()

                Button {
                    model.saveImage(in: model.activePane)
                } label: {
                    Label("Save Active Image", systemImage: "square.and.arrow.down")
                }
                .disabled(model.state(for: model.activePane).image?.isModified != true)
                .help("Save active disk image")
            }
        }
        .focusedValue(\.diskImageManagerActions,
                       DiskImageManagerFocusedActions(createImage: {
                                                          model.presentNewImage(in: model.activePane)
                                                      },
                                                      openImage: {
                                                          model.openImage(in: model.activePane)
                                                      },
                                                      canSaveActiveImage: model.state(for: model.activePane).image?.isModified == true,
                                                      saveActiveImage: {
                                                          model.saveImage(in: model.activePane)
                                                      },
                                                      canImportProgram: model.state(for: model.activePane).image?.geometry.supportsFileWrites == true,
                                                      importProgram: {
                                                          model.importProgram(into: model.activePane)
                                                      },
                                                      canExportSelectedFile: model.state(for: model.activePane).selectedEntry != nil,
                                                      exportSelectedFile: {
                                                          model.exportSelectedFile(from: model.activePane)
                                                      },
                                                      canCloneOptimizedImage: model.state(for: model.activePane).image != nil,
                                                      cloneOptimizedImage: {
                                                          model.cloneOptimizedImage(in: model.activePane)
                                                      },
                                                      canRenameSelectedFile: model.state(for: model.activePane).selectedEntry != nil
                                                          && model.state(for: model.activePane).image?.geometry.supportsFileWrites == true,
                                                      renameSelectedFile: {
                                                          model.presentRenameSelectedFile(in: model.activePane)
                                                      },
                                                      canDeleteSelectedFile: model.state(for: model.activePane).selectedEntry != nil
                                                          && model.state(for: model.activePane).image?.geometry.supportsFileWrites == true,
                                                      deleteSelectedFile: {
                                                          model.deleteSelectedFile(in: model.activePane)
                                                      }))
        .sheet(item: $model.newImageDraft) { draft in
            NewDiskImageSheet(draft: draft) { updatedDraft in
                model.newImageDraft = nil
                model.createImage(from: updatedDraft)
            } onCancel: {
                model.newImageDraft = nil
            }
        }
        .sheet(item: $model.renameDraft) { draft in
            RenameDiskFileSheet(draft: draft) { updatedDraft in
                model.renameDraft = nil
                model.renameSelectedFile(from: updatedDraft)
            } onCancel: {
                model.renameDraft = nil
            }
        }
    }
}

private struct NewDiskImageSheet: View {
    @State private var draft: DiskImageManagerModel.NewImageDraft
    let onCreate: (DiskImageManagerModel.NewImageDraft) -> Void
    let onCancel: () -> Void

    init(draft: DiskImageManagerModel.NewImageDraft,
         onCreate: @escaping (DiskImageManagerModel.NewImageDraft) -> Void,
         onCancel: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.onCreate = onCreate
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "externaldrive.badge.plus")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("New Disk Image")
                        .font(.title3.weight(.semibold))
                    Text("Create a blank Commodore disk for the \(draft.pane.title.lowercased()).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Form {
                Picker("Format", selection: $draft.format) {
                    ForEach(CommodoreDiskImageFormat.allCases.filter(\.supportsBlankImageCreation)) { format in
                        Text(format.title).tag(format)
                    }
                }

                TextField("Disk Name", text: $draft.diskName)
                TextField("Disk ID", text: $draft.diskID)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    onCreate(draft)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.diskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

private struct RenameDiskFileSheet: View {
    @State private var draft: DiskImageManagerModel.RenameDraft
    let onRename: (DiskImageManagerModel.RenameDraft) -> Void
    let onCancel: () -> Void

    init(draft: DiskImageManagerModel.RenameDraft,
         onRename: @escaping (DiskImageManagerModel.RenameDraft) -> Void,
         onCancel: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.onRename = onRename
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "character.cursor.ibeam")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Rename File")
                        .font(.title3.weight(.semibold))
                    Text("Commodore filenames are stored as PETSCII and limited to 16 characters.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            TextField("Name", text: $draft.fileName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Spacer()
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Rename") {
                    onRename(draft)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(draft.fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}

private struct CopyRailView: View {
    @ObservedObject var model: DiskImageManagerModel

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            Button {
                model.copySelectedFile(from: .left, to: .right)
            } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 40, height: 32)
            }
            .buttonStyle(.bordered)
            .disabled(!model.canCopyLeftToRight)
            .help("Copy selected file to the right image")

            Button {
                model.copySelectedFile(from: .right, to: .left)
            } label: {
                Image(systemName: "arrow.left")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 40, height: 32)
            }
            .buttonStyle(.bordered)
            .disabled(!model.canCopyRightToLeft)
            .help("Copy selected file to the left image")

            Spacer()
        }
        .padding(.vertical, 18)
        .background(.black.opacity(0.05))
    }
}

private struct DiskImagePaneView: View {
    @ObservedObject var model: DiskImageManagerModel
    let pane: DiskImageManagerModel.Pane

    var body: some View {
        let state = model.state(for: pane)

        VStack(alignment: .leading, spacing: 12) {
            DiskImagePaneHeader(model: model, pane: pane)

            if let image = state.image {
                DiskImageSummaryView(image: image)

                TabView {
                    DirectoryBrowserView(model: model, pane: pane)
                        .tabItem {
                            Label("Files", systemImage: "list.bullet.rectangle")
                        }

                    SectorBrowserView(model: model, pane: pane)
                        .tabItem {
                            Label("Sectors", systemImage: "square.grid.3x3")
                        }
                }
            } else {
                ContentUnavailableView {
                    Label("No Disk Image", systemImage: "externaldrive")
                } description: {
                    Text("Open a D64, D67, D71, D80, D81, or D82 image.")
                } actions: {
                    Button("Open Image...") {
                        model.openImage(in: pane)
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            StatusLineView(message: state.errorMessage ?? state.message,
                           isError: state.errorMessage != nil)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(model.activePane == pane ? Color.accentColor.opacity(0.55) : .clear,
                        lineWidth: 1.5)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            model.activePane = pane
        }
    }
}

private struct DiskImagePaneHeader: View {
    @ObservedObject var model: DiskImageManagerModel
    let pane: DiskImageManagerModel.Pane

    var body: some View {
        let state = model.state(for: pane)

        HStack(spacing: 10) {
            Label(pane.title, systemImage: pane == .left ? "sidebar.left" : "sidebar.right")
                .font(.headline)

            if model.activePane == pane {
                Text("Active")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.secondary.opacity(0.14), in: Capsule())
            }

            Spacer()

            Button {
                model.presentNewImage(in: pane)
            } label: {
                Label("New", systemImage: "document.badge.plus")
            }
            .help("Create a blank disk image")

            Button {
                model.openImage(in: pane)
            } label: {
                Label("Open", systemImage: "folder")
            }
            .help("Open image")

            Button {
                model.saveImage(in: pane)
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .disabled(state.image?.isModified != true)
            .help("Save image")

            Button {
                model.cloneOptimizedImage(in: pane)
            } label: {
                Label("Clone", systemImage: "wand.and.stars")
            }
            .disabled(state.image == nil)
            .help("Clone optimized copy")
        }
    }
}

private struct DiskImageSummaryView: View {
    let image: CommodoreDiskImage

    var body: some View {
        let header = image.header
        let freeBlocks = header.blocksFree
        let usedFraction = freeBlocks.map { free in
            guard image.geometry.totalSectors > 0 else {
                return 0.0
            }
            return max(0, min(1, Double(image.geometry.totalSectors - free) / Double(image.geometry.totalSectors)))
        }

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "externaldrive.fill")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(image.displayName)
                            .font(.system(size: 12.5, weight: .semibold))
                            .lineLimit(1)

                        if image.isModified {
                            Label("Modified", systemImage: "circle.fill")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                                .labelStyle(.titleAndIcon)
                        }
                    }

                    Text(summaryText(header: header))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(image.format.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.secondary.opacity(0.14), in: Capsule())
            }

            if let usedFraction {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.secondary.opacity(0.16))
                        Capsule()
                            .fill(Color.accentColor.opacity(0.58))
                            .frame(width: proxy.size.width * usedFraction)
                    }
                }
                .frame(height: 5)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }

    private func summaryText(header: CommodoreDiskHeader) -> String {
        let free = header.blocksFree.map { "\($0) blocks free" } ?? "free map unavailable"
        return "\(image.format.title) - \(header.name.isEmpty ? "Untitled" : header.name) - \(header.id) - \(free)"
    }
}

private struct DirectoryBrowserView: View {
    @ObservedObject var model: DiskImageManagerModel
    let pane: DiskImageManagerModel.Pane

    var body: some View {
        let state = model.state(for: pane)
        let entries = model.filteredEntries(in: pane)

        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Label("\(state.entries.count) files", systemImage: "doc.text")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                SearchField(text: model.bindingForSearch(in: pane))
                    .frame(width: 170)

                Button {
                    model.importProgram(into: pane)
                } label: {
                    Label("Import", systemImage: "tray.and.arrow.down")
                }
                .disabled(state.image?.geometry.supportsFileWrites != true)
                .help("Import PRG")
            }

            Table(entries, selection: model.bindingForSelection(in: pane)) {
                TableColumn("Name") { entry in
                    Text(entry.name.isEmpty ? "<unnamed>" : entry.name)
                        .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                }

                TableColumn("Type") { entry in
                    Text(entry.typeText)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                }
                .width(54)

                TableColumn("Start") { entry in
                    Text("\(entry.start.track):\(entry.start.sector)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .width(58)

                TableColumn("Blocks") { entry in
                    Text("\(entry.blocks)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(54)
            }
            .contextMenu {
                Button("Export File...") {
                    model.exportSelectedFile(from: pane)
                }
                .disabled(state.selectedEntry == nil)

                Button("Rename File...") {
                    model.presentRenameSelectedFile(in: pane)
                }
                .disabled(state.selectedEntry == nil || state.image?.geometry.supportsFileWrites != true)

                Divider()

                Button("Delete File", role: .destructive) {
                    model.deleteSelectedFile(in: pane)
                }
                .disabled(state.selectedEntry == nil || state.image?.geometry.supportsFileWrites != true)
            }

            SelectedFileInspectorView(model: model, pane: pane)
        }
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.8), lineWidth: 1)
        }
        .onTapGesture {
            model.activePane = pane
        }
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Filter", text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Clear filter")
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 7))
    }
}

private struct SelectedFileInspectorView: View {
    @ObservedObject var model: DiskImageManagerModel
    let pane: DiskImageManagerModel.Pane

    var body: some View {
        let state = model.state(for: pane)

        if let entry = state.selectedEntry {
            HStack(spacing: 10) {
                Image(systemName: entryIcon(for: entry))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name.isEmpty ? "<unnamed>" : entry.name)
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                        .lineLimit(1)

                    Text(detailText(for: entry, state: state))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    model.exportSelectedFile(from: pane)
                } label: {
                    Label("Export", systemImage: "tray.and.arrow.up")
                }
                .help("Export file")

                Menu {
                    Button("Rename...") {
                        model.presentRenameSelectedFile(in: pane)
                    }
                    .disabled(state.image?.geometry.supportsFileWrites != true)

                    Divider()

                    Button("Delete", role: .destructive) {
                        model.deleteSelectedFile(in: pane)
                    }
                    .disabled(state.image?.geometry.supportsFileWrites != true)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .help("More file actions")
            }
            .padding(10)
            .background(.quaternary.opacity(0.38), in: RoundedRectangle(cornerRadius: 8))
        } else {
            HStack(spacing: 8) {
                Image(systemName: "cursorarrow.click.2")
                    .foregroundStyle(.secondary)
                Text("Select a file to inspect, export, rename, or delete it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(10)
            .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func detailText(for entry: CommodoreDiskDirectoryEntry,
                            state: DiskImageManagerModel.PaneState) -> String {
        let bytes = state.fileByteCounts[entry.id].map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) } ?? "unknown size"
        let lock = entry.isLocked ? "locked, " : ""
        return "\(entry.typeText), \(lock)\(entry.blocks) blocks, \(bytes), starts T\(entry.start.track):S\(entry.start.sector)"
    }

    private func entryIcon(for entry: CommodoreDiskDirectoryEntry) -> String {
        switch entry.type {
        case .prg:
            return "terminal"
        case .seq, .usr, .rel:
            return "doc.text"
        case .del:
            return "trash"
        case .cbm, .dir:
            return "folder"
        case .unknown:
            return "questionmark.app"
        }
    }
}

private struct SectorBrowserView: View {
    @ObservedObject var model: DiskImageManagerModel
    let pane: DiskImageManagerModel.Pane

    var body: some View {
        let state = model.state(for: pane)

        VStack(spacing: 10) {
            if let image = state.image {
                SectorLegendView(sectors: state.sectors)

                SectorGridView(model: model, pane: pane, image: image, sectors: state.sectors)
                    .frame(minHeight: 210, idealHeight: 260)

                Divider()

                SectorEditorView(model: model, pane: pane)
                    .frame(minHeight: 260)
            }
        }
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.8), lineWidth: 1)
        }
    }
}

private struct SectorLegendView: View {
    let sectors: [CommodoreDiskSector]

    var body: some View {
        HStack(spacing: 10) {
            legendItem("Free", color: .green.opacity(0.50), count: count(.free))
            legendItem("File", color: .orange.opacity(0.72), count: countFileSectors())
            legendItem("Directory", color: .blue.opacity(0.78), count: count(.directory))
            legendItem("BAM", color: .purple.opacity(0.78), count: count(.header))
            legendItem("Allocated", color: .secondary.opacity(0.45), count: count(.allocated))

            Spacer()

            Text("\(sectors.count) sectors")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func legendItem(_ title: String, color: Color, count: Int) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 10, height: 10)

            Text(title)
                .foregroundStyle(.secondary)

            Text("\(count)")
                .fontWeight(.semibold)
        }
        .font(.caption)
    }

    private func count(_ role: CommodoreDiskSectorRole) -> Int {
        sectors.filter { $0.role == role }.count
    }

    private func countFileSectors() -> Int {
        sectors.filter { sector in
            if case .file = sector.role {
                return true
            }
            return false
        }.count
    }
}

private struct SectorGridView: View {
    @ObservedObject var model: DiskImageManagerModel
    let pane: DiskImageManagerModel.Pane
    let image: CommodoreDiskImage
    let sectors: [CommodoreDiskSector]

    var body: some View {
        let byAddress = Dictionary(uniqueKeysWithValues: sectors.map { ($0.address, $0) })
        let selectedAddress = model.state(for: pane).selectedAddress

        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(1...image.geometry.trackCount, id: \.self) { track in
                    HStack(spacing: 4) {
                        Text(String(format: "%02d", track))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)

                        ForEach(0..<image.geometry.sectorsPerTrack(track), id: \.self) { sector in
                            let address = CommodoreDiskAddress(track: track, sector: sector)
                            let diskSector = byAddress[address] ?? CommodoreDiskSector(address: address, role: .unknown)
                            SectorCell(sector: diskSector,
                                       isSelected: selectedAddress == address)
                                .onTapGesture {
                                    model.selectSector(address, in: pane)
                                }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct SectorCell: View {
    let sector: CommodoreDiskSector
    let isSelected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(fillColor)
            .frame(width: 10, height: 10)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(.white, lineWidth: 2)
                }
            }
            .help("T\(sector.address.track) S\(sector.address.sector) - \(sector.role.label)")
    }

    private var fillColor: Color {
        switch sector.role {
        case .free:
            return .green.opacity(0.50)
        case .allocated:
            return .secondary.opacity(0.45)
        case .directory:
            return .blue.opacity(0.78)
        case .file:
            return .orange.opacity(0.72)
        case .header:
            return .purple.opacity(0.78)
        case .unknown:
            return .secondary.opacity(0.22)
        }
    }
}

private struct SectorEditorView: View {
    @ObservedObject var model: DiskImageManagerModel
    let pane: DiskImageManagerModel.Pane

    var body: some View {
        let state = model.state(for: pane)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let sector = state.selectedSector {
                    Label("T\(sector.address.track) S\(sector.address.sector)", systemImage: "square.grid.3x3.fill")
                        .font(.system(size: 12.5, weight: .semibold, design: .monospaced))

                    Text(sector.role.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No sector selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    model.reloadSelectedSector(in: pane)
                } label: {
                    Label("Reload", systemImage: "arrow.clockwise")
                }
                .disabled(state.selectedAddress == nil)

                Button {
                    model.writeSelectedSector(in: pane)
                } label: {
                    Label("Write Sector", systemImage: "square.and.pencil")
                }
                .disabled(state.selectedAddress == nil)
            }

            TextEditor(text: model.bindingForSectorEditor(in: pane))
                .font(.system(size: 11, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.separator.opacity(0.8), lineWidth: 1)
                }
        }
    }
}

private struct StatusLineView: View {
    let message: String?
    let isError: Bool

    var body: some View {
        HStack(spacing: 6) {
            if let message {
                Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(isError ? .orange : .secondary)

                Text(message)
                    .foregroundStyle(isError ? .primary : .secondary)
                    .lineLimit(1)
            } else {
                Text(" ")
            }
        }
        .font(.caption)
        .frame(height: 16)
    }
}
