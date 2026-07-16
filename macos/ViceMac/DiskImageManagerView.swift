import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DiskImageManagerView: View {
    @Environment(\.undoManager) private var undoManager
    @EnvironmentObject private var openRequests: DiskImageManagerOpenRequests
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
        .onAppear {
            openPendingRequestIfNeeded(openRequests.pendingRequest)
        }
        .onChange(of: openRequests.pendingRequest) { _, request in
            openPendingRequestIfNeeded(request)
        }
    }

    private func openPendingRequestIfNeeded(_ request: DiskImageManagerOpenRequests.Request?) {
        guard let request else {
            return
        }

        model.openImage(request)
        openRequests.clear(request)
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
        SettingsSheetLayout(width: 420) {
            VMCSheetHeader(systemImage: "externaldrive.badge.plus",
                           title: "New Disk Image",
                           subtitle: "Create a blank Commodore disk for the \(draft.pane.title.lowercased()).")
        } content: {
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
        } actions: {
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
        SettingsSheetLayout(width: 620) {
            VMCSheetHeader(systemImage: "doc.text.magnifyingglass",
                           title: "GEOS Package Assistant",
                           subtitle: "Validate a linked PRG, export a CVT, or install it on the open GEOS disk.")
        } content: {
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

                        Button("Choose PRG…") {
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
        } actions: {
            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            Button("Export GRC…") {
                onExport(draft)
            }
            .disabled(!draft.canBuildPackage)

            Button("Export CVT…") {
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
        guard let url = AppFilePanel.chooseFiles(title: "Choose Linked PRG",
                                                  message: "Choose the built GEOS PRG payload. Raw object files are not accepted here.",
                                                  prompt: "Choose",
                                                  allowedContentTypes: [UTType(filenameExtension: "prg")].compactMap { $0 })?.first else {
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
        SettingsSheetLayout(width: 420) {
            VMCSheetHeader(systemImage: "character.cursor.ibeam",
                           title: "Rename File",
                           subtitle: "Commodore filenames are stored as PETSCII and limited to 16 characters.")
        } content: {
            TextField("Name", text: $draft.fileName)
                .textFieldStyle(.roundedBorder)
        } actions: {
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
                    Button("Clone Copy…") {
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
                    VMCStatusBadge("\(issues.count)")
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
                VMCEmptyState("No Disk Image",
                              systemImage: "externaldrive",
                              description: "Open a CBM DOS or CP/M D64, D67, D71, D80, D81, or D82 image.") {
                    Button("Open Image…") {
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
                VMCStatusBadge("Active")
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }

            Spacer(minLength: 8)

            HStack(spacing: 3) {
                VMCIconButton("document.badge.plus",
                              help: "Create a blank disk image") {
                    model.presentNewImage(in: pane)
                }

                VMCIconButton("folder",
                              help: "Open image") {
                    model.openImage(in: pane)
                }

                VMCIconButton("square.and.arrow.down",
                              help: "Save image") {
                    model.saveImage(in: pane)
                }
                .disabled(state.image?.isModified != true)

                VMCIconButton("wand.and.stars",
                              help: "Clone optimized copy") {
                    model.cloneOptimizedImage(in: pane)
                }
                .disabled(state.image?.supportsOptimizedClone != true)
            }
            .fixedSize(horizontal: true, vertical: false)
        }
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

                VMCStatusBadge(image.format.title)
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
                    VMCStatusBadge(defaultDriverTitle, color: statusTint)
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

                VMCSearchField("Filter", text: model.bindingForSearch(in: pane))
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

            if entries.isEmpty && !state.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VMCEmptyState("No Matches",
                              systemImage: "magnifyingglass",
                              description: "No directory entries match this filter.")
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                Table(entries, selection: model.bindingForSelection(in: pane)) {
                    TableColumn("Name") { entry in
                        HStack(spacing: 6) {
                            Text(entry.name.isEmpty ? "<unnamed>" : entry.name)
                                .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                                .lineLimit(1)

                            ForEach(entry.statusBadges) { badge in
                                VMCStatusBadge(badge.rawValue)
                            }
                        }
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
                    Button("Export File…") {
                        model.exportSelectedFile(from: pane)
                    }
                    .disabled(state.selectedEntry == nil)

                    Button("Rename File…") {
                        model.presentRenameSelectedFile(in: pane)
                    }
                    .disabled(state.selectedEntry == nil || state.image?.supportsFileWrites != true)

                    Divider()

                    Button("Delete File", role: .destructive) {
                        model.deleteSelectedFile(in: pane, undoManager: undoManager)
                    }
                    .disabled(state.selectedEntry == nil || state.image?.supportsFileWrites != true)
                }
            }

            SelectedFileInspectorView(model: model, pane: pane)
        }
        .padding(10)
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
                    HStack(spacing: 6) {
                        Text(entry.name.isEmpty ? "<unnamed>" : entry.name)
                            .font(.system(size: 12.5, weight: .semibold, design: .monospaced))
                            .lineLimit(1)

                        ForEach(entry.statusBadges) { badge in
                            VMCStatusBadge(badge.rawValue)
                        }
                    }

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
                    Button("Rename…") {
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
        let canWriteSector = state.image?.supportsSectorWrites == true && state.selectedAddress != nil

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
                .disabled(!canWriteSector)
            }

            TextEditor(text: model.bindingForSectorEditor(in: pane))
                .font(.system(size: 11, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(.black.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.separator.opacity(0.8), lineWidth: 1)
                }
                .disabled(state.image?.supportsSectorWrites != true)
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
