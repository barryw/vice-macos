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

private final class WeakUndoManagerReference {
    weak var undoManager: UndoManager?

    init(_ undoManager: UndoManager?) {
        self.undoManager = undoManager
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
        var entryID: DiskImageDirectoryEntry.ID
        var fileName: String
    }

    struct CloneReviewDraft: Identifiable {
        let id = UUID()
        var pane: Pane
        var imageName: String
        var format: CommodoreDiskImageFormat
        var analysis: CommodoreDiskRebuildAnalysis
        var sectors: [CommodoreDiskSector]
    }

    struct GEOSPackageDraft: Identifiable {
        let id = UUID()
        var pane: Pane
        var prgURL: URL?
        var prgData: Data?
        var entryAddress = ""
        var metadata = GEOSProgramMetadata()

        var prgValidation: GEOSProgramValidation {
            GEOSProgramValidator.validatePRG(prgData, entryAddressText: entryAddress)
        }

        var allIssues: [GEOSPackageIssue] {
            prgValidation.issues + metadata.validationIssues
        }

        var canBuildPackage: Bool {
            prgValidation.canPackage && metadata.canGenerate
        }

        var canExportGRC: Bool {
            canBuildPackage
        }

        var prgDisplayName: String {
            prgURL?.lastPathComponent ?? "No PRG selected"
        }

        func buildPackage() throws -> GEOSCVTFile {
            try GEOSPackageBuilder.buildCVT(prgData: prgData,
                                            entryAddressText: entryAddress,
                                            metadata: metadata)
        }
    }

    enum Pane: Hashable {
        case left
        case right

        var title: String {
            self == .left ? "Left Image" : "Right Image"
        }
    }

    struct PaneState {
        var image: DiskImageDocument?
        var entries: [DiskImageDirectoryEntry] = []
        var fileByteCounts: [DiskImageDirectoryEntry.ID: Int] = [:]
        var sectors: [CommodoreDiskSector] = []
        var rebuildAnalysis: CommodoreDiskRebuildAnalysis?
        var geosStatus: GEOSDiskStatus?
        var selectedEntryID: DiskImageDirectoryEntry.ID?
        var selectedAddress: CommodoreDiskAddress?
        var sectorEditorText = ""
        var searchText = ""
        var message: String?
        var errorMessage: String?

        var selectedEntry: DiskImageDirectoryEntry? {
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
    @Published var cloneReviewDraft: CloneReviewDraft?
    @Published var geosPackageDraft: GEOSPackageDraft?

    var canCopyLeftToRight: Bool {
        canCopy(from: .left, to: .right)
    }

    var canCopyRightToLeft: Bool {
        canCopy(from: .right, to: .left)
    }

    func openImage(in pane: Pane) {
        let panel = NSOpenPanel()
        panel.title = "Open Disk Image"
        panel.message = "Choose a Commodore or CP/M disk image."
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
        let image = try DiskImageService.openImage(url: url)
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
            let image = try DiskImageService.createBlankImage(at: url,
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

    func copySelectedFile(from sourcePane: Pane, to destinationPane: Pane, undoManager: UndoManager? = nil) {
        guard let source = state(for: sourcePane).image,
              let entry = state(for: sourcePane).selectedEntry else {
            return
        }

        do {
            try setImage(in: destinationPane,
                         undoManager: undoManager,
                         actionName: "Copy File") { destination in
                try destination.copyFile(entry, from: source)
            }
            setMessage("Copied \(entry.name). Save the image to keep the change.", for: destinationPane)
        } catch {
            setError(error.localizedDescription, for: destinationPane)
        }
    }

    func importProgram(into pane: Pane, undoManager: UndoManager? = nil) {
        guard let activeImage = state(for: pane).image else {
            return
        }

        let panel = NSOpenPanel()
        panel.title = "Import File"
        panel.message = activeImage.filesystemKind == .cpm
            ? "Choose a host file to add to the CP/M disk image."
            : "Choose a PRG file to add to the disk image."
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if activeImage.filesystemKind == .cbmDOS {
            panel.allowedContentTypes = Self.programContentTypes
        }

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        do {
            let payload = try Data(contentsOf: url)
            try setImage(in: pane,
                         undoManager: undoManager,
                         actionName: "Import File") { image in
                let fileName = image.filesystemKind == .cpm
                    ? url.lastPathComponent
                    : url.deletingPathExtension().lastPathComponent
                try image.importFile(named: fileName,
                                     payload: payload)
            }
            setMessage("Imported \(url.lastPathComponent). Save the image to keep the change.", for: pane)
        } catch {
            setError(error.localizedDescription, for: pane)
        }
    }

    func presentGEOSPackageAssistant(in pane: Pane) {
        guard let image = state(for: pane).image,
              image.filesystemKind == .cbmDOS,
              image.supportsFileWrites else {
            return
        }

        activePane = pane
        geosPackageDraft = GEOSPackageDraft(pane: pane)
    }

    @discardableResult
    func exportGEOSGRC(from draft: GEOSPackageDraft) -> Bool {
        guard draft.canExportGRC else {
            setError("Fix the GEOS package validation issues before exporting a GRC file.", for: draft.pane)
            return false
        }

        let panel = NSSavePanel()
        panel.title = "Export GEOS Resource File"
        panel.message = "Save a generated GRC header for the validated PRG payload."
        panel.prompt = "Export"
        panel.allowedContentTypes = [UTType(filenameExtension: "grc")].compactMap { $0 }
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(Self.safeFilename(draft.metadata.dosName)).grc"

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return false
        }

        do {
            try draft.metadata.generatedGRC.write(to: url, atomically: true, encoding: .utf8)
            setMessage("Exported \(url.lastPathComponent).", for: draft.pane)
            return true
        } catch {
            setError(error.localizedDescription, for: draft.pane)
            return false
        }
    }

    @discardableResult
    func exportGEOSCVT(from draft: GEOSPackageDraft) -> Bool {
        guard draft.canBuildPackage else {
            setError("Fix the GEOS package validation issues before exporting a CVT file.", for: draft.pane)
            return false
        }

        let panel = NSSavePanel()
        panel.title = "Export GEOS Convert File"
        panel.message = "Save a GEOS CVT package that can be copied onto a GEOS disk."
        panel.prompt = "Export"
        panel.allowedContentTypes = [UTType(filenameExtension: "cvt")].compactMap { $0 }
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(Self.safeFilename(draft.metadata.dosName)).cvt"

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return false
        }

        do {
            let package = try draft.buildPackage()
            try package.data.write(to: url, options: .atomic)
            setMessage("Exported \(url.lastPathComponent).", for: draft.pane)
            return true
        } catch {
            setError(error.localizedDescription, for: draft.pane)
            return false
        }
    }

    @discardableResult
    func installGEOSPackage(from draft: GEOSPackageDraft,
                            undoManager: UndoManager? = nil) -> Bool {
        guard draft.canBuildPackage else {
            setError("Fix the GEOS package validation issues before installing.", for: draft.pane)
            return false
        }

        do {
            let package = try draft.buildPackage()
            try setImage(in: draft.pane,
                         undoManager: undoManager,
                         actionName: "Install GEOS Package") { image in
                try image.installGEOSPackage(package)
            }
            setMessage("Installed \(package.diskName). Save the image to keep the change.", for: draft.pane)
            return true
        } catch {
            setError(error.localizedDescription, for: draft.pane)
            return false
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

        let analysis = state(for: pane).rebuildAnalysis ?? image.rebuildAnalysis()
        let requiresReview = !analysis.canRebuild || analysis.issues.contains { $0.severity != .info }
        guard !requiresReview else {
            cloneReviewDraft = CloneReviewDraft(pane: pane,
                                                imageName: image.displayName,
                                                format: image.format,
                                                analysis: analysis,
                                                sectors: state(for: pane).sectors)
            return
        }

        chooseOptimizedCloneDestination(in: pane)
    }

    func cloneReviewedImage(from draft: CloneReviewDraft) {
        cloneReviewDraft = nil
        DispatchQueue.main.async { [weak self] in
            self?.chooseOptimizedCloneDestination(in: draft.pane)
        }
    }

    private func chooseOptimizedCloneDestination(in pane: Pane) {
        guard let image = state(for: pane).image else {
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

    func renameSelectedFile(from draft: RenameDraft, undoManager: UndoManager? = nil) {
        guard let entry = state(for: draft.pane).entries.first(where: { $0.id == draft.entryID }) else {
            setError(CommodoreDiskImageError.fileNotFound(draft.fileName).localizedDescription, for: draft.pane)
            return
        }

        do {
            try setImage(in: draft.pane,
                         undoManager: undoManager,
                         actionName: "Rename File") { image in
                try image.renameFile(entry, to: draft.fileName)
            }
            setMessage("Renamed file. Save the image to keep the change.", for: draft.pane)
        } catch {
            setError(error.localizedDescription, for: draft.pane)
        }
    }

    func deleteSelectedFile(in pane: Pane, undoManager: UndoManager? = nil) {
        guard let entry = state(for: pane).selectedEntry else {
            return
        }

        do {
            try setImage(in: pane,
                         undoManager: undoManager,
                         actionName: "Delete File") { image in
                try image.deleteFile(entry)
            }
            setMessage("Deleted \(entry.name). Save the image to keep the change.", for: pane)
        } catch {
            setError(error.localizedDescription, for: pane)
        }
    }

    func makeGEOS1351Default(in pane: Pane, undoManager: UndoManager? = nil) {
        do {
            try setImage(in: pane,
                         undoManager: undoManager,
                         actionName: "Set GEOS 1351 Default") { image in
                try image.makeGEOS1351Default()
            }
            setMessage("GEOS will use the 1351 mouse after you save and reboot from this disk.", for: pane)
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

    func writeSelectedSector(in pane: Pane, undoManager: UndoManager? = nil) {
        guard let address = state(for: pane).selectedAddress else {
            return
        }

        do {
            let bytes = try CommodoreHexDump.data(from: state(for: pane).sectorEditorText)
            try setImage(in: pane,
                         undoManager: undoManager,
                         actionName: "Write Sector") { image in
                try image.writeSector(bytes, at: address)
            }
            setMessage("Wrote T\(address.track) S\(address.sector). Save the image to keep the change.", for: pane)
        } catch {
            setError(error.localizedDescription, for: pane)
        }
    }

    func bindingForSelection(in pane: Pane) -> Binding<DiskImageDirectoryEntry.ID?> {
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

    func filteredEntries(in pane: Pane) -> [DiskImageDirectoryEntry] {
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

        return destination.supportsFileWrites
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

    private func setImage(in pane: Pane,
                          undoManager: UndoManager? = nil,
                          actionName: String? = nil,
                          mutate: (inout DiskImageDocument) throws -> Void) throws {
        var state = state(for: pane)
        guard let originalImage = state.image else {
            return
        }

        var image = originalImage
        try mutate(&image)
        state.image = image
        refresh(&state)

        switch pane {
        case .left:
            left = state
        case .right:
            right = state
        }

        if let actionName,
           image != originalImage {
            registerUndo(undoManager,
                         pane: pane,
                         restoreImage: originalImage,
                         redoImage: image,
                         actionName: actionName)
        }
    }

    private func registerUndo(_ undoManager: UndoManager?,
                              pane: Pane,
                              restoreImage: DiskImageDocument,
                              redoImage: DiskImageDocument,
                              actionName: String) {
        guard let undoManager else {
            return
        }

        let undoManagerReference = WeakUndoManagerReference(undoManager)
        undoManager.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated {
                model.restoreImage(restoreImage,
                                   in: pane,
                                   undoManager: undoManagerReference.undoManager,
                                   inverseImage: redoImage,
                                   actionName: actionName)
            }
        }
        undoManager.setActionName(actionName)
    }

    private func restoreImage(_ image: DiskImageDocument,
                              in pane: Pane,
                              undoManager: UndoManager?,
                              inverseImage: DiskImageDocument,
                              actionName: String) {
        setState(for: pane) { state in
            state.image = image
            state.message = nil
            state.errorMessage = nil
            refresh(&state)
        }
        activePane = pane

        guard let undoManager else {
            return
        }

        let undoManagerReference = WeakUndoManagerReference(undoManager)
        undoManager.registerUndo(withTarget: self) { model in
            MainActor.assumeIsolated {
                model.restoreImage(inverseImage,
                                   in: pane,
                                   undoManager: undoManagerReference.undoManager,
                                   inverseImage: image,
                                   actionName: actionName)
            }
        }
        undoManager.setActionName(actionName)
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
            state.rebuildAnalysis = nil
            state.geosStatus = nil
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
            state.rebuildAnalysis = image.rebuildAnalysis()
            state.geosStatus = image.geosStatus

            if state.selectedAddress == nil {
                state.selectedAddress = image.defaultSelectedAddress
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

    private static func exportFilename(for entry: DiskImageDirectoryEntry) -> String {
        entry.exportFilename
    }

    private static func optimizedFilename(for image: DiskImageDocument) -> String {
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

    #if DEBUG
    func openScreenshotImagesFromEnvironmentIfRequested() {
        let environment = ProcessInfo.processInfo.environment
        guard environment["VICE_MAC_DISK_MANAGER_SCREENSHOT"] == "1" else {
            return
        }

        if let leftPath = environment["VICE_MAC_DISK_MANAGER_LEFT"],
           !leftPath.isEmpty {
            openScreenshotImage(at: leftPath, in: .left)
        }

        if let rightPath = environment["VICE_MAC_DISK_MANAGER_RIGHT"],
           !rightPath.isEmpty {
            openScreenshotImage(at: rightPath, in: .right)
        }

        activePane = .left
    }

    private func openScreenshotImage(at path: String, in pane: Pane) {
        do {
            try openImage(url: URL(fileURLWithPath: path), in: pane)
            setState(for: pane) { state in
                state.selectedEntryID = state.entries.first?.id
            }
        } catch {
            setError(error.localizedDescription, for: pane)
        }
    }
    #endif
}

struct DiskImageManagerView: View {
    @Environment(\.undoManager) private var undoManager
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
                    model.importProgram(into: model.activePane, undoManager: undoManager)
                } label: {
                    Label("Import File", systemImage: "tray.and.arrow.down")
                }
                .disabled(model.state(for: model.activePane).image?.supportsFileWrites != true)
                .help("Import a file into the active disk image")

                Button {
                    model.presentGEOSPackageAssistant(in: model.activePane)
                } label: {
                    Label("GEOS Package", systemImage: "doc.badge.gearshape")
                }
                .disabled(model.state(for: model.activePane).image?.filesystemKind != .cbmDOS
                          || model.state(for: model.activePane).image?.supportsFileWrites != true)
                .help("Create a validated GEOS resource header for a linked PRG")

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
                .disabled(model.state(for: model.activePane).image?.supportsOptimizedClone != true)
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
                                                      canImportProgram: model.state(for: model.activePane).image?.supportsFileWrites == true,
                                                      importProgram: {
                                                          model.importProgram(into: model.activePane, undoManager: undoManager)
                                                      },
                                                      canExportSelectedFile: model.state(for: model.activePane).selectedEntry != nil,
                                                      exportSelectedFile: {
                                                          model.exportSelectedFile(from: model.activePane)
                                                      },
                                                      canCloneOptimizedImage: model.state(for: model.activePane).image?.supportsOptimizedClone == true,
                                                      cloneOptimizedImage: {
                                                          model.cloneOptimizedImage(in: model.activePane)
                                                      },
                                                      canRenameSelectedFile: model.state(for: model.activePane).selectedEntry != nil
                                                          && model.state(for: model.activePane).image?.supportsFileWrites == true,
                                                      renameSelectedFile: {
                                                          model.presentRenameSelectedFile(in: model.activePane)
                                                      },
                                                      canDeleteSelectedFile: model.state(for: model.activePane).selectedEntry != nil
                                                          && model.state(for: model.activePane).image?.supportsFileWrites == true,
                                                      deleteSelectedFile: {
                                                          model.deleteSelectedFile(in: model.activePane, undoManager: undoManager)
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
                model.renameSelectedFile(from: updatedDraft, undoManager: undoManager)
            } onCancel: {
                model.renameDraft = nil
            }
        }
        .sheet(item: $model.cloneReviewDraft) { draft in
            CloneOptimizedReviewSheet(draft: draft) {
                model.cloneReviewDraft = nil
            } onClone: {
                model.cloneReviewedImage(from: draft)
            }
        }
        .sheet(item: $model.geosPackageDraft) { draft in
            GEOSPackageAssistantSheet(draft: draft) { updatedDraft in
                if model.exportGEOSGRC(from: updatedDraft) {
                    model.geosPackageDraft = nil
                }
            } onExportCVT: { updatedDraft in
                if model.exportGEOSCVT(from: updatedDraft) {
                    model.geosPackageDraft = nil
                }
            } onInstall: { updatedDraft in
                if model.installGEOSPackage(from: updatedDraft, undoManager: undoManager) {
                    model.geosPackageDraft = nil
                }
            } onCancel: {
                model.geosPackageDraft = nil
            }
        }
        #if DEBUG
        .task {
            model.openScreenshotImagesFromEnvironmentIfRequested()
        }
        #endif
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

private struct GEOSPackageAssistantSheet: View {
    @State private var draft: DiskImageManagerModel.GEOSPackageDraft
    @State private var localError: String?
    let onExport: (DiskImageManagerModel.GEOSPackageDraft) -> Void
    let onExportCVT: (DiskImageManagerModel.GEOSPackageDraft) -> Void
    let onInstall: (DiskImageManagerModel.GEOSPackageDraft) -> Void
    let onCancel: () -> Void

    init(draft: DiskImageManagerModel.GEOSPackageDraft,
         onExport: @escaping (DiskImageManagerModel.GEOSPackageDraft) -> Void,
         onExportCVT: @escaping (DiskImageManagerModel.GEOSPackageDraft) -> Void,
         onInstall: @escaping (DiskImageManagerModel.GEOSPackageDraft) -> Void,
         onCancel: @escaping () -> Void) {
        _draft = State(initialValue: draft)
        self.onExport = onExport
        self.onExportCVT = onExportCVT
        self.onInstall = onInstall
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            Form {
                Section("Payload") {
                    HStack(spacing: 10) {
                        Image(systemName: draft.prgData == nil ? "doc.badge.plus" : "doc.text")
                            .foregroundStyle(draft.prgData == nil ? .secondary : Color.accentColor)
                            .frame(width: 22)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(draft.prgDisplayName)
                                .lineLimit(1)
                            Text(payloadDetailText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button("Choose PRG...") {
                            choosePRG()
                        }
                    }

                    TextField("Entry Address", text: $draft.entryAddress)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                }

                Section("GEOS Header") {
                    Picker("Type", selection: $draft.metadata.kind) {
                        ForEach(GEOSProgramKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("DOS Name", text: $draft.metadata.dosName)
                    TextField("Class Name", text: $draft.metadata.className)
                    TextField("Version", text: $draft.metadata.version)

                    Picker("DOS Type", selection: $draft.metadata.dosType) {
                        ForEach(GEOSProgramDOSType.allCases) { type in
                            Text(type.title).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Mode", selection: $draft.metadata.mode) {
                        ForEach(GEOSProgramMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    TextField("Author", text: $draft.metadata.author)
                    TextField("Info", text: $draft.metadata.info, axis: .vertical)
                        .lineLimit(2...3)
                }

                Section("Preflight") {
                    GEOSPackageIssueList(issues: visibleIssues)
                }

                Section("Generated GRC") {
                    ScrollView {
                        Text(draft.metadata.generatedGRC)
                            .font(.system(size: 11.5, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(height: 118)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 7))
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(.separator.opacity(0.6), lineWidth: 1)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(height: 590)

            if let localError {
                Label(localError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack {
                Spacer()

                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Button("Export GRC...") {
                    onExport(draft)
                }
                .disabled(!draft.canBuildPackage)

                Button("Export CVT...") {
                    onExportCVT(draft)
                }
                .disabled(!draft.canBuildPackage)

                Button("Install") {
                    onInstall(draft)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!draft.canExportGRC)
            }
        }
        .padding(24)
        .frame(width: 620)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("GEOS Package Assistant")
                    .font(.title3.weight(.semibold))
                Text("Validate a linked PRG, export a CVT, or install it on the open GEOS disk.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var payloadDetailText: String {
        let validation = draft.prgValidation
        guard validation.loadAddress != nil else {
            return "Choose a linked Commodore PRG, not a raw object file."
        }

        return "\(validation.payloadByteCount) bytes, loads \(validation.loadRangeText), entry \(validation.entryAddressText)"
    }

    private var visibleIssues: [GEOSPackageIssue] {
        let issues = draft.allIssues
        let errorsAndWarnings = issues.filter { $0.severity != .info }
        return errorsAndWarnings.isEmpty ? issues : errorsAndWarnings
    }

    private func choosePRG() {
        let panel = NSOpenPanel()
        panel.title = "Choose Linked PRG"
        panel.message = "Choose the built GEOS PRG payload. Raw object files are not accepted here."
        panel.prompt = "Choose"
        panel.allowedContentTypes = [UTType(filenameExtension: "prg")].compactMap { $0 }
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false

        NSApp.activate(ignoringOtherApps: true)
        panel.center()

        guard panel.runModal() == .OK,
              let url = panel.url else {
            return
        }

        do {
            draft.prgData = try Data(contentsOf: url)
            draft.prgURL = url
            draft.entryAddress = ""
            draft.metadata.applySuggestedName(from: url)
            localError = nil
        } catch {
            localError = error.localizedDescription
        }
    }
}

private struct GEOSPackageIssueList: View {
    let issues: [GEOSPackageIssue]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(issues) { issue in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: issue.severity.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(issue.severity.tint)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(issue.title)
                            .font(.caption.weight(.semibold))
                        Text(issue.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

private struct CloneOptimizedReviewSheet: View {
    let draft: DiskImageManagerModel.CloneReviewDraft
    let onCancel: () -> Void
    let onClone: () -> Void

    var body: some View {
        let analysis = draft.analysis

        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: analysis.statusSymbolName)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(analysis.statusColor)
                    .frame(width: 40, height: 40)
                    .background(analysis.statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 4) {
                    Text(analysis.canRebuild ? "Review Optimized Clone" : "Clone Blocked")
                        .font(.title3.weight(.semibold))
                    Text(draft.imageName)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(analysis.statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 10) {
                        CloneReviewFactView(title: "Source",
                                            value: "Untouched",
                                            systemImage: "lock.shield")
                        CloneReviewFactView(title: "Output",
                                            value: "\(draft.format.title) copy",
                                            systemImage: "doc.on.doc")
                        CloneReviewFactView(title: "Layout",
                                            value: "Drive interleave",
                                            systemImage: "arrow.triangle.branch")
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        HStack {
                            Text("Sector Layout")
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text("\(draft.sectors.count) sectors")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        SectorActivityRibbonView(sectors: draft.sectors)
                            .frame(height: 16)
                    }

                    if analysis.issues.isEmpty {
                        CleanCloneSummaryView()
                    } else {
                        RebuildIssueGroupView(title: "Must Fix",
                                              issues: analysis.blockingIssues)
                        RebuildIssueGroupView(title: "Warnings",
                                              issues: analysis.warningIssues)
                        RebuildIssueGroupView(title: "Notes",
                                              issues: analysis.noteIssues)
                    }
                }
                .padding(24)
            }
            .frame(maxHeight: 430)

            Divider()

            HStack(spacing: 12) {
                Text(analysis.canRebuild
                     ? "The original image is never modified."
                     : "Resolve the blocked items, then run clone again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(analysis.canRebuild ? "Cancel" : "Done") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                if analysis.canRebuild {
                    Button("Clone Copy...") {
                        onClone()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
        }
        .frame(width: 660)
    }
}

private struct CloneReviewFactView: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.5), lineWidth: 1)
        }
    }
}

private struct CleanCloneSummaryView: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 3) {
                Text("No rebuild issues found")
                    .font(.caption.weight(.semibold))
                Text("The copy can be rebuilt with optimized sector placement and no known loss of directory-visible data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .background(.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct RebuildIssueGroupView: View {
    let title: String
    let issues: [CommodoreDiskRebuildIssue]

    var body: some View {
        if !issues.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                    Text("\(issues.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary.opacity(0.13), in: Capsule())
                }

                VStack(spacing: 6) {
                    ForEach(issues.prefix(6)) { issue in
                        RebuildIssueReviewRow(issue: issue)
                    }

                    if issues.count > 6 {
                        Text("\(issues.count - 6) more issue\(issues.count - 6 == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                    }
                }
            }
        }
    }
}

private struct RebuildIssueReviewRow: View {
    let issue: CommodoreDiskRebuildIssue

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: issue.severity.symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(issue.severity.tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(issue.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(issue.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(9)
        .background(.quaternary.opacity(0.30), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CopyRailView: View {
    @Environment(\.undoManager) private var undoManager
    @ObservedObject var model: DiskImageManagerModel

    var body: some View {
        VStack(spacing: 14) {
            Spacer()

            Button {
                model.copySelectedFile(from: .left, to: .right, undoManager: undoManager)
            } label: {
                Image(systemName: "arrow.right")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 40, height: 32)
            }
            .buttonStyle(.bordered)
            .disabled(!model.canCopyLeftToRight)
            .help("Copy selected file to the right image")

            Button {
                model.copySelectedFile(from: .right, to: .left, undoManager: undoManager)
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
    @Environment(\.undoManager) private var undoManager
    @ObservedObject var model: DiskImageManagerModel
    let pane: DiskImageManagerModel.Pane

    var body: some View {
        let state = model.state(for: pane)

        VStack(alignment: .leading, spacing: 12) {
            DiskImagePaneHeader(model: model, pane: pane)

            if let image = state.image {
                DiskImageSummaryView(image: image)
                if let geosStatus = state.geosStatus {
                    GEOSDiskToolsView(status: geosStatus) {
                        model.makeGEOS1351Default(in: pane, undoManager: undoManager)
                    }
                }
                if image.supportsOptimizedClone {
                    DiskImageRebuildAnalysisView(image: image,
                                                 analysis: state.rebuildAnalysis,
                                                 sectors: state.sectors) {
                        model.cloneOptimizedImage(in: pane)
                    }
                }

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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
            } else {
                ContentUnavailableView {
                    Label("No Disk Image", systemImage: "externaldrive")
                } description: {
                    Text("Open a CBM DOS or CP/M D64, D67, D71, D80, D81, or D82 image.")
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

        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: pane == .left ? "sidebar.left" : "sidebar.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                Text(pane.title)
                    .font(.headline)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .layoutPriority(3)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(pane.title)

            if model.activePane == pane {
                Text("Active")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.secondary.opacity(0.14), in: Capsule())
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 3) {
                DiskImagePaneHeaderButton(systemImage: "document.badge.plus",
                                          title: "Create a blank disk image") {
                    model.presentNewImage(in: pane)
                }

                DiskImagePaneHeaderButton(systemImage: "folder",
                                          title: "Open image") {
                    model.openImage(in: pane)
                }

                DiskImagePaneHeaderButton(systemImage: "square.and.arrow.down",
                                          title: "Save image",
                                          isDisabled: state.image?.isModified != true) {
                    model.saveImage(in: pane)
                }

                DiskImagePaneHeaderButton(systemImage: "wand.and.stars",
                                          title: "Clone optimized copy",
                                          isDisabled: state.image?.supportsOptimizedClone != true) {
                    model.cloneOptimizedImage(in: pane)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }
}

private struct DiskImagePaneHeaderButton: View {
    var systemImage: String
    var title: String
    var isDisabled = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(isDisabled)
        .help(title)
        .accessibilityLabel(title)
    }
}

private struct DiskImageSummaryView: View {
    let image: DiskImageDocument

    var body: some View {
        let usedFraction = image.usedFraction

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

                    Text(image.summaryText)
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
}

private struct GEOSDiskToolsView: View {
    let status: GEOSDiskStatus
    let onMake1351Default: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "cursorarrow.motionlines")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(statusTint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("GEOS Input")
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(defaultDriverTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(statusTint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(statusTint.opacity(0.12), in: Capsule())
                }

                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button {
                onMake1351Default()
            } label: {
                Label("Use 1351", systemImage: "computermouse")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!status.canMake1351Default)
            .help("Move the 1351 mouse driver ahead of joystick drivers in the GEOS directory")
        }
        .padding(10)
        .background(statusTint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(statusTint.opacity(0.22), lineWidth: 1)
        }
    }

    private var defaultDriverTitle: String {
        status.defaultInputDriver?.device.title ?? "No driver"
    }

    private var detailText: String {
        if status.inputDrivers.isEmpty {
            return "This looks like GEOS, but no input drivers were found in the directory."
        }

        if status.is1351Default {
            return "The 1351 mouse driver is already first. Save the disk and boot with Mac Mouse 1351 on control port 1."
        }

        if status.preferred1351Driver != nil {
            return "The joystick driver is first. Put the 1351 driver first so GEOS chooses it at startup."
        }

        return "No 1351 driver was found on this disk. Copy one from a GEOS 1351 utility disk first."
    }

    private var statusTint: Color {
        if status.is1351Default {
            return .green
        }

        if status.preferred1351Driver != nil {
            return .orange
        }

        return .secondary
    }
}

private struct DiskImageRebuildAnalysisView: View {
    let image: DiskImageDocument
    let analysis: CommodoreDiskRebuildAnalysis?
    let sectors: [CommodoreDiskSector]
    let onClone: () -> Void

    var body: some View {
        let analysis = analysis ?? CommodoreDiskRebuildAnalysis(issues: [])
        let primaryIssue = analysis.primaryIssue

        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: analysis.statusSymbolName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(analysis.statusColor)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(analysis.statusTitle)
                        .font(.system(size: 12.5, weight: .semibold))
                    Text(analysis.statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    onClone()
                } label: {
                    Label(analysis.canRebuild ? "Clone" : "Review", systemImage: "wand.and.stars")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!image.supportsOptimizedClone)
                .help("Review and create an optimized rebuilt copy")
            }

            SectorActivityRibbonView(sectors: sectors)
                .frame(height: 13)

            HStack(spacing: 6) {
                RebuildMetricPill(title: "Blocks", value: "\(image.geometry.totalSectors)")
                RebuildMetricPill(title: "Warnings", value: "\(analysis.warningIssues.count)", tint: .orange)
                RebuildMetricPill(title: "Notes", value: "\(analysis.noteIssues.count)", tint: .secondary)

                Spacer()
            }

            if let primaryIssue {
                RebuildIssueDigestRow(issue: primaryIssue)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.38), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(analysis.statusColor.opacity(0.28), lineWidth: 1)
        }
    }
}

private struct RebuildMetricPill: View {
    let title: String
    let value: String
    var tint: Color = .accentColor

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .fontWeight(.semibold)
                .foregroundStyle(tint)
        }
        .font(.caption2)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.secondary.opacity(0.12), in: Capsule())
    }
}

private struct RebuildIssueDigestRow: View {
    let issue: CommodoreDiskRebuildIssue

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: issue.severity.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(issue.severity.tint)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 1) {
                Text(issue.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(issue.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

private struct SectorActivityRibbonView: View {
    let sectors: [CommodoreDiskSector]

    var body: some View {
        let sampled = sampledSectors()

        GeometryReader { proxy in
            let width = cellWidth(for: proxy.size.width, count: sampled.count)

            HStack(spacing: 1) {
                ForEach(Array(sampled.enumerated()), id: \.offset) { _, sector in
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(color(for: sector.role))
                        .frame(width: width)
                }
            }
        }
        .accessibilityLabel("Disk sector layout")
    }

    private func sampledSectors(limit: Int = 128) -> [CommodoreDiskSector] {
        guard sectors.count > limit else {
            return sectors
        }

        return (0..<limit).map { index in
            sectors[min(sectors.count - 1, index * sectors.count / limit)]
        }
    }

    private func cellWidth(for availableWidth: CGFloat, count: Int) -> CGFloat {
        guard count > 0 else {
            return 0
        }

        return max(1.5, (availableWidth - CGFloat(max(0, count - 1))) / CGFloat(count))
    }

    private func color(for role: CommodoreDiskSectorRole) -> Color {
        switch role {
        case .free:
            return .green.opacity(0.62)
        case .allocated:
            return .secondary.opacity(0.48)
        case .directory:
            return .blue.opacity(0.82)
        case .file:
            return .orange.opacity(0.78)
        case .header:
            return .purple.opacity(0.82)
        case .unknown:
            return .secondary.opacity(0.24)
        }
    }
}

private struct DirectoryBrowserView: View {
    @Environment(\.undoManager) private var undoManager
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
                    model.importProgram(into: pane, undoManager: undoManager)
                } label: {
                    Label("Import", systemImage: "tray.and.arrow.down")
                }
                .disabled(state.image?.supportsFileWrites != true)
                .help("Import a file")

                Button {
                    model.presentGEOSPackageAssistant(in: pane)
                } label: {
                    Label("GEOS", systemImage: "doc.badge.gearshape")
                }
                .disabled(state.image?.filesystemKind != .cbmDOS || state.image?.supportsFileWrites != true)
                .help("Create a validated GEOS resource header")
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
                    Text(entry.startText)
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
                .disabled(state.selectedEntry == nil || state.image?.supportsFileWrites != true)

                Divider()

                Button("Delete File", role: .destructive) {
                    model.deleteSelectedFile(in: pane, undoManager: undoManager)
                }
                .disabled(state.selectedEntry == nil || state.image?.supportsFileWrites != true)
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
    @Environment(\.undoManager) private var undoManager
    @ObservedObject var model: DiskImageManagerModel
    let pane: DiskImageManagerModel.Pane

    var body: some View {
        let state = model.state(for: pane)

        if let entry = state.selectedEntry {
            HStack(spacing: 10) {
                Image(systemName: entry.iconSystemName)
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
                    .disabled(state.image?.supportsFileWrites != true)

                    Divider()

                    Button("Delete", role: .destructive) {
                        model.deleteSelectedFile(in: pane, undoManager: undoManager)
                    }
                    .disabled(state.image?.supportsFileWrites != true)
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

    private func detailText(for entry: DiskImageDirectoryEntry,
                            state: DiskImageManagerModel.PaneState) -> String {
        entry.detailText(byteCount: state.fileByteCounts[entry.id])
    }
}

private struct SectorBrowserView: View {
    @ObservedObject var model: DiskImageManagerModel
    let pane: DiskImageManagerModel.Pane

    var body: some View {
        let state = model.state(for: pane)

        GeometryReader { proxy in
            let layout = SectorBrowserLayout(availableHeight: proxy.size.height)

            VStack(spacing: 8) {
                if let image = state.image {
                    SectorLegendView(sectors: state.sectors)
                        .frame(height: layout.legendHeight)

                    SectorGridView(model: model, pane: pane, image: image, sectors: state.sectors)
                        .frame(height: layout.gridHeight)

                    Divider()

                    SectorEditorView(model: model, pane: pane)
                        .frame(height: layout.editorHeight)
                }
            }
            .padding(10)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .frame(minHeight: 0)
        .background(.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.8), lineWidth: 1)
        }
    }
}

private struct SectorBrowserLayout {
    var availableHeight: CGFloat

    var legendHeight: CGFloat {
        22
    }

    var gridHeight: CGFloat {
        guard contentHeight > 0 else {
            return 0
        }

        return min(220, max(90, contentHeight * 0.54))
    }

    var editorHeight: CGFloat {
        max(0, contentHeight - gridHeight)
    }

    private var contentHeight: CGFloat {
        max(0, availableHeight - 20 - legendHeight - 8 - 1 - 8)
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
    let image: DiskImageDocument
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
    @Environment(\.undoManager) private var undoManager
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
                    model.writeSelectedSector(in: pane, undoManager: undoManager)
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

private extension CommodoreDiskRebuildAnalysis {
    var noteIssues: [CommodoreDiskRebuildIssue] {
        issues.filter { $0.severity == .info }
    }

    var primaryIssue: CommodoreDiskRebuildIssue? {
        blockingIssues.first ?? warningIssues.first ?? noteIssues.first
    }

    var statusSymbolName: String {
        if !blockingIssues.isEmpty {
            return "xmark.octagon.fill"
        }

        if !warningIssues.isEmpty {
            return "exclamationmark.triangle.fill"
        }

        return "checkmark.seal.fill"
    }

    var statusColor: Color {
        if !blockingIssues.isEmpty {
            return .red
        }

        if !warningIssues.isEmpty {
            return .orange
        }

        return .green
    }
}

private extension CommodoreDiskRebuildIssueSeverity {
    var symbolName: String {
        switch self {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .blocked:
            return "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .blocked:
            return .red
        }
    }
}

private extension GEOSPackageIssueSeverity {
    var systemImage: String {
        switch self {
        case .info:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.octagon.fill"
        }
    }

    var tint: Color {
        switch self {
        case .info:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        }
    }
}
