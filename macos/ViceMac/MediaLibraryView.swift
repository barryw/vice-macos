import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct MediaLibraryView: View {
    @EnvironmentObject private var emulator: EmulatorSession
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
    }

    private var libraryList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "books.vertical")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                TextField("Search Library", text: $model.searchText)
                    .textFieldStyle(.roundedBorder)

                Button {
                    model.importMedia()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .frame(width: 18, height: 18)
                }
                .help("Import media")
            }
            .padding(12)

            Divider()

            if model.items.isEmpty {
                MediaLibraryEmptyListView {
                    model.importMedia()
                }
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
                                   onImport: model.importMedia,
                                   onToggleFavorite: { model.toggleFavorite(item) },
                                   onRemove: { model.confirmRemove(item) },
                                   onReveal: { model.reveal(item) },
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
}

@MainActor
private final class MediaLibraryViewModel: ObservableObject {
    @Published var items: [MediaLibraryItem] = []
    @Published var selectedItemID: UUID?
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published var removalCandidate: MediaLibraryItem?

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
        let panel = NSOpenPanel()
        panel.title = "Import Media"
        panel.prompt = "Import"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = Self.allowedContentTypes

        guard panel.runModal() == .OK else {
            return
        }

        do {
            let store = try libraryStore()
            let imported = try store.importURLs(panel.urls)
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

    func primaryFileURL(for item: MediaLibraryItem) -> URL? {
        do {
            return try libraryStore().primaryFileURL(for: item)
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

private struct MediaLibraryDetailView: View {
    let item: MediaLibraryItem
    let fileURL: URL?
    let onImport: () -> Void
    let onToggleFavorite: () -> Void
    let onRemove: () -> Void
    let onReveal: () -> Void
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
            Image(systemName: item.primaryFile.kind.systemImage)
                .font(.system(size: 32, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 44, height: 44)

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
