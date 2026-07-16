import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MediaLibraryView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var emulator: EmulatorSession
    @EnvironmentObject private var metadataSettings: MetadataIngestionSettings
    @EnvironmentObject private var diskImageManagerOpenRequests: DiskImageManagerOpenRequests
    @StateObject private var model = MediaLibraryViewModel()

    var body: some View {
        HStack(spacing: 0) {
            libraryList
                .frame(minWidth: 340, idealWidth: 380, maxWidth: 460)

            Divider()

            detailPane
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 860, minHeight: 560)
        .onAppear {
            model.reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .mediaLibraryDidChange)) { _ in
            model.reload()
        }
        .alert("Media Library", isPresented: model.errorPresentedBinding) {
            Button("OK") {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
        .confirmationDialog("Remove from library?",
                            isPresented: model.removalPresentedBinding,
                            titleVisibility: .visible,
                            presenting: model.removalCandidate) { item in
            Button("Remove from Library", role: .destructive) {
                model.remove(item)
            }

            Button("Cancel", role: .cancel) {
                model.removalCandidate = nil
            }
        } message: { item in
            Text("Remove \(item.title) and its managed library copy? The original source file is not changed.")
        }
        .sheet(item: $model.metadataUpdateItem) { item in
            MediaLibraryMetadataUpdateSheet(item: item,
                                            snapshots: metadataSettings.providerSnapshots,
                                            artworkPreference: metadataSettings.artworkPreference,
                                            credential: metadataSettings.credential(providerID:field:)) { update in
                try model.applyMetadataUpdate(update, to: item.id)
            }
        }
    }

    private var libraryList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "books.vertical")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                VMCSearchField("Search Library", text: $model.searchText)

                VMCIconButton("square.and.arrow.down",
                              help: "Import media",
                              width: 30,
                              height: 28) {
                    model.importMedia()
                }
            }
            .padding(12)

            Divider()

            if model.items.isEmpty {
                MediaLibraryEmptyListView {
                    model.importMedia()
                }
            } else if model.filteredItems.isEmpty {
                VMCEmptyState("No Matches",
                              systemImage: "magnifyingglass",
                              description: "Try a different title, file name, or disk entry.")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $model.selectedItemID) {
                    ForEach(model.filteredItems) { item in
                        MediaLibraryItemRow(item: item)
                            .tag(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.selectedItemID = item.id
                            }
                            .onTapGesture(count: 2) {
                                model.launch(item, behavior: .run, emulator: emulator)
                            }
                            .contextMenu {
                                mediaItemMenu(for: item)
                            }
                    }
                }
                .listStyle(.sidebar)
            }

            Divider()

            HStack {
                Text(model.librarySummary)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        if let item = model.selectedItem {
            MediaLibraryDetailView(item: item,
                                   fileURL: model.primaryFileURL(for: item),
                                   artworkURL: model.primaryArtworkURL(for: item),
                                   onImport: model.importMedia,
                                   onToggleFavorite: { model.toggleFavorite(item) },
                                   onRemove: { model.confirmRemove(item) },
                                   onReveal: { model.reveal(item) },
                                   onUpdateMetadata: metadataUpdateAction(for: item),
                                   onOpenDiskImageManager: item.primaryFile.kind == .disk ? {
                                       openDiskImageManager(for: item)
                                   } : nil,
                                   onLaunch: { behavior in
                                       model.launch(item, behavior: behavior, emulator: emulator)
                                   })
        } else {
            MediaLibraryEmptyDetailView {
                model.importMedia()
            }
        }
    }

    @ViewBuilder
    private func mediaItemMenu(for item: MediaLibraryItem) -> some View {
        Button("Run") {
            model.launch(item, behavior: .run, emulator: emulator)
        }

        Button("Load") {
            model.launch(item, behavior: .load, emulator: emulator)
        }

        Button("Attach") {
            model.launch(item, behavior: .attach, emulator: emulator)
        }

        if item.primaryFile.kind == .disk {
            Divider()

            Button {
                model.beginMetadataUpdate(item)
            } label: {
                Label("Update Metadata...", systemImage: "sparkle.magnifyingglass")
            }
            .disabled(!canUpdateMetadata)

            Button {
                openDiskImageManager(for: item)
            } label: {
                Label("Open in Disk Image Manager", systemImage: "externaldrive")
            }
        }

        Divider()

        Button(item.isFavorite ? "Remove Favorite" : "Favorite") {
            model.toggleFavorite(item)
        }

        Button("Reveal in Finder") {
            model.reveal(item)
        }

        Button("Remove from Library...", role: .destructive) {
            model.confirmRemove(item)
        }
    }

    private func openDiskImageManager(for item: MediaLibraryItem) {
        model.openInDiskImageManager(item,
                                     requests: diskImageManagerOpenRequests) {
            openWindow(id: DiskImageManagerWindow.id)
        }
    }

    private var canUpdateMetadata: Bool {
        metadataSettings.providerSnapshots.contains { snapshot in
            snapshot.configuration.isEnabled
                && snapshot.isReady
                && snapshot.providerID.supportsMediaLibraryMetadataSearch
        }
    }

    private func metadataUpdateAction(for item: MediaLibraryItem) -> (() -> Void)? {
        guard item.primaryFile.kind == .disk,
              canUpdateMetadata else {
            return nil
        }

        return {
            model.beginMetadataUpdate(item)
        }
    }
}

@MainActor
private final class MediaLibraryViewModel: ObservableObject {
    @Published var items: [MediaLibraryItem] = []
    @Published var selectedItemID: UUID?
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published var removalCandidate: MediaLibraryItem?
    @Published var metadataUpdateItem: MediaLibraryItem?

    private var store: MediaLibraryStore?

    var errorPresentedBinding: Binding<Bool> {
        Binding {
            self.errorMessage != nil
        } set: { isPresented in
            if !isPresented {
                self.errorMessage = nil
            }
        }
    }

    var removalPresentedBinding: Binding<Bool> {
        Binding {
            self.removalCandidate != nil
        } set: { isPresented in
            if !isPresented {
                self.removalCandidate = nil
            }
        }
    }

    var selectedItem: MediaLibraryItem? {
        guard let selectedItemID else {
            return filteredItems.first
        }

        return items.first { $0.id == selectedItemID } ?? filteredItems.first
    }

    var filteredItems: [MediaLibraryItem] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else {
            return items
        }

        return items.filter { $0.searchableText.contains(query) }
    }

    var librarySummary: String {
        switch items.count {
        case 0:
            return "No media"
        case 1:
            return "1 item"
        default:
            return "\(items.count) items"
        }
    }

    func reload() {
        do {
            let store = try libraryStore()
            items = try store.items()

            if let selectedItemID,
               items.contains(where: { $0.id == selectedItemID }) {
                return
            }

            selectedItemID = items.first?.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func importMedia() {
        guard let urls = AppFilePanel.chooseFiles(title: "Import Media",
                                                   prompt: "Import",
                                                   canChooseDirectories: true,
                                                   allowsMultipleSelection: true,
                                                   allowedContentTypes: Self.allowedContentTypes) else {
            return
        }

        do {
            let store = try libraryStore()
            let imported = try store.importURLs(urls)
            items = try store.items()
            selectedItemID = imported.first?.id ?? selectedItemID ?? items.first?.id
        } catch {
            errorMessage = error.localizedDescription
            reload()
        }
    }

    func launch(_ item: MediaLibraryItem,
                behavior: MediaOpenBehavior,
                emulator: EmulatorSession) {
        do {
            let store = try libraryStore()
            let url = store.primaryFileURL(for: item)
            guard emulator.openMedia(url: url, behavior: behavior) else {
                return
            }

            try store.markPlayed(itemID: item.id)
            reload()
            selectedItemID = item.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleFavorite(_ item: MediaLibraryItem) {
        do {
            let store = try libraryStore()
            try store.setFavorite(!item.isFavorite, itemID: item.id)
            reload()
            selectedItemID = item.id
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func confirmRemove(_ item: MediaLibraryItem) {
        removalCandidate = item
    }

    func beginMetadataUpdate(_ item: MediaLibraryItem) {
        guard item.primaryFile.kind == .disk else {
            return
        }

        metadataUpdateItem = item
    }

    func applyMetadataUpdate(_ update: MediaLibraryMetadataUpdate,
                             to itemID: UUID) throws {
        let store = try libraryStore()
        try store.updateMetadata(itemID: itemID,
                                 title: update.title,
                                 notes: update.notes)

        if let artworkData = update.artworkData,
           let artworkKind = update.artworkKind {
            try store.cacheArtwork(artworkData,
                                   kind: artworkKind,
                                   itemID: itemID,
                                   sourceURL: update.artworkSourceURL,
                                   fileExtension: update.artworkFileExtension)
        }

        metadataUpdateItem = nil
        reload()
        selectedItemID = itemID
    }

    func remove(_ item: MediaLibraryItem) {
        do {
            let store = try libraryStore()
            try store.removeItem(id: item.id)
            removalCandidate = nil
            selectedItemID = nil
            reload()
        } catch {
            removalCandidate = nil
            errorMessage = error.localizedDescription
            reload()
        }
    }

    func reveal(_ item: MediaLibraryItem) {
        guard let url = primaryFileURL(for: item) else {
            return
        }

        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openInDiskImageManager(_ item: MediaLibraryItem,
                                requests: DiskImageManagerOpenRequests,
                                openWindow: () -> Void) {
        guard item.primaryFile.kind == .disk else {
            return
        }

        do {
            let url = try libraryStore().primaryFileURL(for: item)
            selectedItemID = item.id
            requests.open(url: url,
                          in: .left,
                          mediaLibraryItemID: item.id)
            openWindow()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func primaryFileURL(for item: MediaLibraryItem) -> URL? {
        do {
            return try libraryStore().primaryFileURL(for: item)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func primaryArtworkURL(for item: MediaLibraryItem) -> URL? {
        guard let artwork = Self.preferredArtwork(in: item) else {
            return nil
        }

        do {
            let url = try libraryStore().artworkURL(for: artwork)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return nil
            }

            return url
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    private func libraryStore() throws -> MediaLibraryStore {
        if let store {
            return store
        }

        let store = try MediaLibraryStore()
        self.store = store
        return store
    }

    private static var allowedContentTypes: [UTType] {
        MediaLibraryStore.supportedFilenameExtensions.compactMap { extensionName in
            UTType(filenameExtension: extensionName)
        }
    }

    private static func preferredArtwork(in item: MediaLibraryItem) -> MediaLibraryArtwork? {
        for kind in [MetadataArtworkPreference.boxFront, .titleScreen, .screenshot] {
            if let artwork = item.artwork.first(where: { $0.kind == kind }) {
                return artwork
            }
        }

        return item.artwork.first
    }
}

private struct MediaLibraryItemRow: View {
    let item: MediaLibraryItem

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.primaryFile.kind.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Text(item.title)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)

                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.yellow)
                    }
                }

                HStack(spacing: 5) {
                    VMCStatusBadge(item.primaryFile.kind.title,
                                   systemImage: item.primaryFile.kind.systemImage)
                    VMCStatusBadge(item.primaryFile.mediaType.uppercased())

                    if !item.entries.isEmpty {
                        VMCStatusBadge("\(item.entries.count) files",
                                       systemImage: "list.bullet")
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }
}

private struct MediaLibraryArtworkThumbnail: View {
    let url: URL?
    let fallbackSystemImage: String

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: fallbackSystemImage)
                    .font(.system(size: 32, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 54, height: 54)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 7))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(.separator.opacity(0.45))
        }
    }

    private var image: NSImage? {
        guard let url else {
            return nil
        }

        return NSImage(contentsOf: url)
    }
}

private struct MediaLibraryMetadataSearchRequest: Equatable {
    var providerID: MetadataProviderID?
    var query: String

    var canSearch: Bool {
        providerID != nil && !query.isEmpty
    }
}

private struct MediaLibraryMetadataUpdateSheet: View {
    @Environment(\.dismiss) private var dismiss

    let item: MediaLibraryItem
    let snapshots: [MetadataProviderSnapshot]
    let artworkPreference: MetadataArtworkPreference
    let credential: (MetadataProviderID, MetadataCredentialField) -> String
    let onApply: (MediaLibraryMetadataUpdate) throws -> Void

    @State private var selectedProviderID: MetadataProviderID?
    @State private var query: String
    @State private var results: [MediaLibraryMetadataSearchResult] = []
    @State private var selectedResultID: MediaLibraryMetadataSearchResult.ID?
    @State private var isSearching = false
    @State private var isApplying = false
    @State private var statusText = ""
    @State private var errorText: String?

    init(item: MediaLibraryItem,
         snapshots: [MetadataProviderSnapshot],
         artworkPreference: MetadataArtworkPreference,
         credential: @escaping (MetadataProviderID, MetadataCredentialField) -> String,
         onApply: @escaping (MediaLibraryMetadataUpdate) throws -> Void) {
        self.item = item
        self.snapshots = snapshots
        self.artworkPreference = artworkPreference
        self.credential = credential
        self.onApply = onApply

        let availableProviderID = snapshots.first { snapshot in
            snapshot.configuration.isEnabled
                && snapshot.isReady
                && snapshot.providerID.supportsMediaLibraryMetadataSearch
        }?.providerID
        _selectedProviderID = State(initialValue: availableProviderID)
        _query = State(initialValue: item.title)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if availableSnapshots.isEmpty {
                VMCEmptyState("No Metadata Provider",
                              systemImage: "network.slash",
                              description: "Enable TheGamesDB in Metadata settings before updating library metadata.")
                    .frame(width: 620, height: 300)
            } else {
                searchControls
                resultsList
                footer
            }
        }
        .padding(20)
        .frame(width: 680)
        .frame(minHeight: 500)
        .task(id: searchRequest) {
            await debouncedSearch(for: searchRequest)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.title2.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("Update Metadata")
                    .font(.title3.weight(.semibold))

                Text(item.title)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
    }

    private var searchControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Picker("Provider", selection: providerBinding) {
                    ForEach(availableSnapshots) { snapshot in
                        Label(snapshot.providerID.title, systemImage: snapshot.providerID.systemImage)
                            .tag(Optional(snapshot.providerID))
                    }
                }
                .frame(width: 210)

                VMCSearchField("Search", text: $query)
                    .disabled(isApplying)
            }

            if let errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            } else if !statusText.isEmpty {
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var resultsList: some View {
        Group {
            if isSearching {
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if results.isEmpty {
                VMCEmptyState("No Matches",
                              systemImage: "magnifyingglass",
                              description: "Try a different title or remove extra filename text.")
            } else {
                List(selection: $selectedResultID) {
                    ForEach(results) { result in
                        MediaLibraryMetadataResultRow(result: result)
                            .tag(Optional(result.id))
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                Task {
                                    await applySelectedResult(result)
                                }
                            }
                    }
                }
                .listStyle(.inset)
            }
        }
        .frame(minHeight: 300)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.separator.opacity(0.55))
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("Artwork: \(artworkPreference.title)")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Cancel", role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button {
                Task {
                    await applySelectedResult(nil)
                }
            } label: {
                if isApplying {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Apply")
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(selectedResult == nil || isSearching || isApplying)
        }
    }

    private var availableSnapshots: [MetadataProviderSnapshot] {
        snapshots.filter { snapshot in
            snapshot.configuration.isEnabled
                && snapshot.isReady
                && snapshot.providerID.supportsMediaLibraryMetadataSearch
        }
    }

    private var providerBinding: Binding<MetadataProviderID?> {
        Binding {
            selectedProviderID
        } set: { providerID in
            selectedProviderID = providerID
            results = []
            selectedResultID = nil
            errorText = nil
            statusText = ""
        }
    }

    private var selectedResult: MediaLibraryMetadataSearchResult? {
        guard let selectedResultID else {
            return nil
        }

        return results.first { $0.id == selectedResultID }
    }

    private var searchRequest: MediaLibraryMetadataSearchRequest {
        MediaLibraryMetadataSearchRequest(providerID: selectedProviderID,
                                          query: query.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private var canSearch: Bool {
        searchRequest.canSearch
    }

    @MainActor
    private func debouncedSearch(for request: MediaLibraryMetadataSearchRequest) async {
        guard request.canSearch else {
            results = []
            selectedResultID = nil
            isSearching = false
            errorText = nil
            statusText = ""
            return
        }

        results = []
        selectedResultID = nil
        isSearching = false
        errorText = nil
        statusText = ""

        try? await Task.sleep(nanoseconds: 500_000_000)
        guard !Task.isCancelled else {
            return
        }

        await search(for: request)
    }

    @MainActor
    private func search(for request: MediaLibraryMetadataSearchRequest) async {
        guard let providerID = request.providerID else {
            return
        }

        isSearching = true
        errorText = nil
        statusText = ""
        selectedResultID = nil

        do {
            let client = try metadataClient(for: providerID)
            let matches = try await client.searchGames(query: request.query,
                                                       artworkPreference: artworkPreference)
            guard request == searchRequest,
                  !Task.isCancelled else {
                return
            }

            results = matches
            selectedResultID = matches.first?.id
            statusText = matches.isEmpty ? "No matches found." : "\(matches.count) matches"
        } catch is CancellationError {
            guard request == searchRequest else {
                return
            }

            statusText = ""
        } catch {
            guard request == searchRequest else {
                return
            }

            results = []
            errorText = error.localizedDescription
        }

        if request == searchRequest {
            isSearching = false
        }
    }

    @MainActor
    private func applySelectedResult(_ explicitResult: MediaLibraryMetadataSearchResult?) async {
        guard let result = explicitResult ?? selectedResult,
              !isApplying else {
            return
        }

        isApplying = true
        errorText = nil
        statusText = "Applying metadata..."

        do {
            let client = try metadataClient(for: result.providerID)
            let update = try await client.metadataUpdate(for: result,
                                                         artworkPreference: artworkPreference)
            try onApply(update)
            dismiss()
        } catch {
            errorText = error.localizedDescription
            statusText = ""
        }

        isApplying = false
    }

    private func metadataClient(for providerID: MetadataProviderID) throws -> TheGamesDBMetadataClient {
        guard providerID == .theGamesDB else {
            throw MetadataLookupError.unsupportedProvider(providerID)
        }

        let apiKey = credential(.theGamesDB, .apiKey)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            throw MetadataLookupError.missingCredential(.theGamesDB)
        }

        return TheGamesDBMetadataClient(apiKey: apiKey)
    }
}

private struct MediaLibraryMetadataResultRow: View {
    let result: MediaLibraryMetadataSearchResult

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: result.artworkURL == nil ? "photo" : "photo.fill")
                .font(.system(size: 16, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.title)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)

                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let overview = result.overview,
                   !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)
        }
        .padding(.vertical, 4)
    }
}

private struct MediaLibraryDetailView: View {
    let item: MediaLibraryItem
    let fileURL: URL?
    let artworkURL: URL?
    let onImport: () -> Void
    let onToggleFavorite: () -> Void
    let onRemove: () -> Void
    let onReveal: () -> Void
    let onUpdateMetadata: (() -> Void)?
    let onOpenDiskImageManager: (() -> Void)?
    let onLaunch: (MediaOpenBehavior) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    MediaLibraryMetadataSection(item: item, fileURL: fileURL)

                    if !item.entries.isEmpty {
                        MediaLibraryDirectorySection(entries: item.entries)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            MediaLibraryArtworkThumbnail(url: artworkURL,
                                         fallbackSystemImage: item.primaryFile.kind.systemImage)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 7) {
                    Text(item.title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)

                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                    }
                }

                HStack(spacing: 6) {
                    VMCStatusBadge(item.primaryFile.typeTitle,
                                   systemImage: item.primaryFile.kind.systemImage)
                    if let lastPlayedText {
                        VMCStatusBadge(lastPlayedText,
                                       systemImage: "clock")
                    }
                }
            }

            Spacer()

            HStack(spacing: 6) {
                ForEach(MediaOpenBehavior.allCases) { behavior in
                    Button {
                        onLaunch(behavior)
                    } label: {
                        Label(behavior.title, systemImage: behavior.systemImage)
                    }
                }
            }

            Button {
                onToggleFavorite()
            } label: {
                Image(systemName: item.isFavorite ? "star.fill" : "star")
                    .frame(width: 18, height: 18)
            }
            .help(item.isFavorite ? "Remove favorite" : "Favorite")

            Menu {
                Button("Import Media...") {
                    onImport()
                }

                Button("Reveal in Finder") {
                    onReveal()
                }

                if let onUpdateMetadata {
                    Button {
                        onUpdateMetadata()
                    } label: {
                        Label("Update Metadata...", systemImage: "sparkle.magnifyingglass")
                    }
                }

                if let onOpenDiskImageManager {
                    Button {
                        onOpenDiskImageManager()
                    } label: {
                        Label("Open in Disk Image Manager", systemImage: "externaldrive")
                    }
                }

                Button("Remove from Library...", role: .destructive) {
                    onRemove()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .frame(width: 18, height: 18)
            }
            .menuStyle(.button)
        }
        .buttonStyle(.borderless)
        .padding(16)
    }

    private var lastPlayedText: String? {
        guard let lastPlayedAt = item.lastPlayedAt else {
            return nil
        }

        return "Played \(lastPlayedAt.formatted(date: .abbreviated, time: .omitted))"
    }
}

private struct MediaLibraryMetadataSection: View {
    let item: MediaLibraryItem
    let fileURL: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Media")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                VMCInfoRow("Type", labelWidth: 86) {
                    Text(item.primaryFile.typeTitle)
                }

                VMCInfoRow("File", labelWidth: 86) {
                    Text(item.primaryFile.originalFilename)
                        .truncationMode(.middle)
                }

                VMCInfoRow("Size", labelWidth: 86) {
                    Text(Self.byteCountFormatter.string(fromByteCount: item.primaryFile.byteCount))
                }

                VMCInfoRow("SHA-256", labelWidth: 86) {
                    Text(item.primaryFile.sha256)
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if let fileURL {
                    VMCInfoRow("Library", labelWidth: 86) {
                        Text(fileURL.path)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                if let originalPath = item.primaryFile.originalPath {
                    VMCInfoRow("Source", labelWidth: 86) {
                        Text(originalPath)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                if !item.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VMCInfoRow("Notes", labelWidth: 86) {
                        Text(item.notes)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private static let byteCountFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()
}

private struct MediaLibraryDirectorySection: View {
    let entries: [MediaLibraryEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Directory")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(entries) { entry in
                    HStack(spacing: 10) {
                        Text(entry.name)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(entry.typeText)
                            .foregroundStyle(.secondary)
                            .frame(width: 54, alignment: .leading)

                        Text("\(entry.blocks)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 42, alignment: .trailing)
                    }
                    .font(.callout)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)

                    if entry.id != entries.last?.id {
                        Divider()
                    }
                }
            }
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 6))
        }
    }
}

private struct MediaLibraryEmptyListView: View {
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Spacer()

            Image(systemName: "externaldrive.badge.plus")
                .font(.system(size: 34, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            Text("No Media")
                .font(.headline)

            Button("Import Media...") {
                onImport()
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MediaLibraryEmptyDetailView: View {
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical")
                .font(.system(size: 42, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            Text("Media Library")
                .font(.title3.weight(.semibold))

            Button("Import Media...") {
                onImport()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
