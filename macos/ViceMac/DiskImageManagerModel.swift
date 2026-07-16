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
final class DiskImageManagerOpenRequests: ObservableObject {
    struct Request: Identifiable, Equatable {
        let id = UUID()
        var url: URL
        var pane: DiskImageManagerModel.Pane
        var mediaLibraryItemID: UUID?
    }

    @Published private(set) var pendingRequest: Request?

    func open(url: URL,
              in pane: DiskImageManagerModel.Pane = .left,
              mediaLibraryItemID: UUID? = nil) {
        pendingRequest = Request(url: url,
                                 pane: pane,
                                 mediaLibraryItemID: mediaLibraryItemID)
    }

    func clear(_ request: Request) {
        guard pendingRequest?.id == request.id else {
            return
        }

        pendingRequest = nil
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
        var mediaLibraryItemID: UUID?

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
        guard let url = AppFilePanel.chooseFiles(title: "Open Disk Image",
                                                  message: "Choose a Commodore or CP/M disk image.",
                                                  prompt: "Open",
                                                  allowedContentTypes: Self.openableContentTypes)?.first else {
            return
        }

        do {
            try openImage(url: url, in: pane)
        } catch {
            setError(error.localizedDescription, for: pane)
        }
    }

    func openImage(url: URL, in pane: Pane) throws {
        try openImage(url: url, in: pane, mediaLibraryItemID: nil)
    }

    func openImage(_ request: DiskImageManagerOpenRequests.Request) {
        do {
            try openImage(url: request.url,
                          in: request.pane,
                          mediaLibraryItemID: request.mediaLibraryItemID)
        } catch {
            setError(error.localizedDescription, for: request.pane)
        }
    }

    private func openImage(url: URL,
                           in pane: Pane,
                           mediaLibraryItemID: UUID?) throws {
        let image = try DiskImageService.openImage(url: url)
        setState(for: pane) { state in
            state.image = image
            state.mediaLibraryItemID = mediaLibraryItemID
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
        guard let url = AppFilePanel.chooseSaveURL(title: "Create Disk Image",
                                                    message: "Create a blank Commodore disk image.",
                                                    prompt: "Create",
                                                    nameFieldStringValue: "\(DiskImageFilename.safe(draft.diskName)).\(draft.format.rawValue)",
                                                    allowedContentTypes: [UTType(filenameExtension: draft.format.rawValue)].compactMap { $0 },
                                                    canCreateDirectories: true) else {
            return
        }

        do {
            let image = try DiskImageService.createBlankImage(at: url,
                                                              format: draft.format,
                                                              diskName: draft.diskName,
                                                              diskID: draft.diskID)
            setState(for: draft.pane) { state in
                state.image = image
                state.mediaLibraryItemID = nil
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
        let mediaLibraryItemID = state(for: pane).mediaLibraryItemID
        do {
            try setImage(in: pane) { image in
                try image.save()
            }

            if let mediaLibraryItemID {
                do {
                    guard try MediaLibraryStore().refreshItemMetadata(id: mediaLibraryItemID) != nil else {
                        setMessage("Saved. The media library item no longer exists.", for: pane)
                        return
                    }
                } catch {
                    setError("Saved, but the media library could not be refreshed: \(error.localizedDescription)",
                             for: pane)
                    return
                }
            }

            setMessage(mediaLibraryItemID == nil ? "Saved." : "Saved to media library.", for: pane)
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

        guard let url = AppFilePanel.chooseFiles(title: "Import File",
                                                  message: activeImage.filesystemKind == .cpm
                                                      ? "Choose a host file to add to the CP/M disk image."
                                                      : "Choose a PRG file to add to the disk image.",
                                                  prompt: "Import",
                                                  allowedContentTypes: activeImage.filesystemKind == .cbmDOS ? Self.programContentTypes : [])?.first else {
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

        guard let url = AppFilePanel.chooseSaveURL(title: "Export GEOS Resource File",
                                                    message: "Save a generated GRC header for the validated PRG payload.",
                                                    prompt: "Export",
                                                    nameFieldStringValue: "\(DiskImageFilename.safe(draft.metadata.dosName)).grc",
                                                    allowedContentTypes: [UTType(filenameExtension: "grc")].compactMap { $0 },
                                                    canCreateDirectories: true) else {
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

        guard let url = AppFilePanel.chooseSaveURL(title: "Export GEOS Convert File",
                                                    message: "Save a GEOS CVT package that can be copied onto a GEOS disk.",
                                                    prompt: "Export",
                                                    nameFieldStringValue: "\(DiskImageFilename.safe(draft.metadata.dosName)).cvt",
                                                    allowedContentTypes: [UTType(filenameExtension: "cvt")].compactMap { $0 },
                                                    canCreateDirectories: true) else {
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

        guard let url = AppFilePanel.chooseSaveURL(title: "Export File",
                                                    message: "Export \(entry.name) from the disk image.",
                                                    prompt: "Export",
                                                    nameFieldStringValue: Self.exportFilename(for: entry),
                                                    canCreateDirectories: true) else {
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

        guard let url = AppFilePanel.chooseSaveURL(title: "Clone Optimized Disk Image",
                                                    message: "Create a rebuilt copy with drive-aware sector interleave. The original image is not modified.",
                                                    prompt: "Clone",
                                                    nameFieldStringValue: Self.optimizedFilename(for: image),
                                                    allowedContentTypes: [UTType(filenameExtension: image.format.rawValue)].compactMap { $0 },
                                                    canCreateDirectories: true) else {
            return
        }

        do {
            let rebuilt = try image.cloneOptimized(to: url)
            setState(for: pane) { state in
                state.image = rebuilt
                state.mediaLibraryItemID = nil
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
            state.mediaLibraryItemID = nil
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
            // A parse failure must not leave the pane describing a *different*
            // image: state.image has already been switched to the new disk, so
            // stale directory/sector coordinates here would make Export/Rename/
            // Delete operate on the wrong image. Clear everything derived.
            state.entries = []
            state.fileByteCounts = [:]
            state.sectors = []
            state.rebuildAnalysis = nil
            state.geosStatus = nil
            state.selectedEntryID = nil
            state.selectedAddress = nil
            state.sectorEditorText = ""
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
        return "\(DiskImageFilename.safe(stem))-optimized.\(image.format.rawValue)"
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
