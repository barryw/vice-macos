import CryptoKit
import Foundation
import SQLite3

enum MediaLibraryMediaKind: String, CaseIterable, Equatable, Identifiable {
    case disk
    case program
    case tape
    case cartridge
    case snapshot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .disk:
            return "Disk"
        case .program:
            return "Program"
        case .tape:
            return "Tape"
        case .cartridge:
            return "Cartridge"
        case .snapshot:
            return "Snapshot"
        }
    }

    var systemImage: String {
        switch self {
        case .disk:
            return "externaldrive"
        case .program:
            return "terminal"
        case .tape:
            return "recordingtape"
        case .cartridge:
            return "shippingbox"
        case .snapshot:
            return "camera.viewfinder"
        }
    }
}

struct MediaLibraryFile: Identifiable, Equatable {
    let id: UUID
    let itemID: UUID
    var relativePath: String
    var originalFilename: String
    var originalPath: String?
    var kind: MediaLibraryMediaKind
    var mediaType: String
    var typeTitle: String
    var sha256: String
    var byteCount: Int64
    var importedAt: Date

    func url(in libraryRootURL: URL) -> URL {
        libraryRootURL.appendingPathComponent(relativePath)
    }
}

struct MediaLibraryEntry: Identifiable, Equatable {
    let id: Int64
    var itemID: UUID
    var fileID: UUID
    var name: String
    var typeText: String
    var blocks: Int
    var sortOrder: Int
}

struct MediaLibraryItem: Identifiable, Equatable {
    let id: UUID
    var title: String
    var preferredBehavior: MediaOpenBehavior
    var isFavorite: Bool
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var lastPlayedAt: Date?
    var primaryFile: MediaLibraryFile
    var entries: [MediaLibraryEntry]

    var searchableText: String {
        ([title, primaryFile.originalFilename, primaryFile.typeTitle] + entries.map(\.name))
            .joined(separator: " ")
            .lowercased()
    }
}

enum MediaLibraryImportError: Error, LocalizedError, Equatable {
    case unsupportedMedia(String)
    case noSupportedMedia

    var errorDescription: String? {
        switch self {
        case .unsupportedMedia(let filename):
            return "\(filename) is not a supported media file."
        case .noSupportedMedia:
            return "No supported media files were found."
        }
    }
}

final class MediaLibraryStore {
    struct MediaDescriptor: Equatable {
        var kind: MediaLibraryMediaKind
        var mediaType: String
        var typeTitle: String
    }

    static var defaultLibraryDirectoryURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")

        return baseURL
            .appendingPathComponent("VICE Mac", isDirectory: true)
            .appendingPathComponent("Media Library", isDirectory: true)
    }

    static var supportedFilenameExtensions: [String] {
        var extensions = Set(DiskImageFileType.allCases.map(\.rawValue))
        extensions.formUnion(AutostartMediaFileType.allCases.map(\.rawValue))
        extensions.formUnion(CartridgeImageFileType.allCases.map(\.rawValue))
        extensions.formUnion(SnapshotFileType.allCases.map(\.rawValue))
        return extensions.sorted()
    }

    let rootURL: URL
    let mediaDirectoryURL: URL
    let artworkDirectoryURL: URL
    let databaseURL: URL

    private var database: OpaquePointer?

    init(rootURL: URL = MediaLibraryStore.defaultLibraryDirectoryURL) throws {
        self.rootURL = rootURL
        mediaDirectoryURL = rootURL.appendingPathComponent("Media", isDirectory: true)
        artworkDirectoryURL = rootURL.appendingPathComponent("Artwork", isDirectory: true)
        databaseURL = rootURL.appendingPathComponent("library.sqlite")

        try FileManager.default.createDirectory(at: mediaDirectoryURL,
                                                withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: artworkDirectoryURL,
                                                withIntermediateDirectories: true)

        try openDatabase()
        try migrate()
    }

    deinit {
        sqlite3_close(database)
    }

    static func descriptor(for url: URL) -> MediaDescriptor? {
        guard let mediaFile = EmulatorMediaFile(url: url) else {
            return nil
        }

        switch mediaFile {
        case let .disk(type):
            return MediaDescriptor(kind: .disk,
                                   mediaType: type.rawValue,
                                   typeTitle: "\(type.title) disk image")
        case let .autostart(type):
            switch type {
            case .prg:
                return MediaDescriptor(kind: .program,
                                       mediaType: type.rawValue,
                                       typeTitle: type.title)
            case .t64, .tap:
                return MediaDescriptor(kind: .tape,
                                       mediaType: type.rawValue,
                                       typeTitle: type.title)
            }
        case let .cartridge(type):
            return MediaDescriptor(kind: .cartridge,
                                   mediaType: type.rawValue,
                                   typeTitle: "\(type.title) cartridge")
        case let .snapshot(type):
            return MediaDescriptor(kind: .snapshot,
                                   mediaType: type.rawValue,
                                   typeTitle: "\(type.title) snapshot")
        }
    }

    func items() throws -> [MediaLibraryItem] {
        let sql = """
        SELECT
            i.id, i.title, i.preferred_behavior, i.favorite, i.notes,
            i.created_at, i.updated_at, i.last_played_at,
            f.id, f.relative_path, f.original_filename, f.original_path,
            f.media_kind, f.media_type, f.type_title, f.sha256,
            f.byte_count, f.imported_at
        FROM media_items i
        JOIN media_files f ON f.item_id = i.id AND f.is_primary = 1
        ORDER BY i.title COLLATE NOCASE, f.original_filename COLLATE NOCASE
        """

        return try withStatement(sql) { statement in
            var items: [MediaLibraryItem] = []

            while sqlite3_step(statement) == SQLITE_ROW {
                guard let itemID = uuidColumn(statement, 0),
                      let preferredBehavior = MediaOpenBehavior(rawValue: stringColumn(statement, 2) ?? ""),
                      let fileID = uuidColumn(statement, 8),
                      let mediaKind = MediaLibraryMediaKind(rawValue: stringColumn(statement, 12) ?? "") else {
                    continue
                }

                let file = MediaLibraryFile(
                    id: fileID,
                    itemID: itemID,
                    relativePath: stringColumn(statement, 9) ?? "",
                    originalFilename: stringColumn(statement, 10) ?? "",
                    originalPath: stringColumn(statement, 11),
                    kind: mediaKind,
                    mediaType: stringColumn(statement, 13) ?? "",
                    typeTitle: stringColumn(statement, 14) ?? "",
                    sha256: stringColumn(statement, 15) ?? "",
                    byteCount: sqlite3_column_int64(statement, 16),
                    importedAt: dateColumn(statement, 17) ?? Date(timeIntervalSince1970: 0)
                )

                items.append(MediaLibraryItem(
                    id: itemID,
                    title: stringColumn(statement, 1) ?? file.originalFilename,
                    preferredBehavior: preferredBehavior,
                    isFavorite: sqlite3_column_int(statement, 3) != 0,
                    notes: stringColumn(statement, 4) ?? "",
                    createdAt: dateColumn(statement, 5) ?? Date(timeIntervalSince1970: 0),
                    updatedAt: dateColumn(statement, 6) ?? Date(timeIntervalSince1970: 0),
                    lastPlayedAt: dateColumn(statement, 7),
                    primaryFile: file,
                    entries: []
                ))
            }

            return try items.map { item in
                var item = item
                item.entries = try entries(for: item.id)
                return item
            }
        }
    }

    func importURLs(_ urls: [URL]) throws -> [MediaLibraryItem] {
        let mediaURLs = try urls.flatMap(mediaURLs(for:))
        guard !mediaURLs.isEmpty else {
            throw MediaLibraryImportError.noSupportedMedia
        }

        var imported: [MediaLibraryItem] = []
        for url in mediaURLs {
            imported.append(try importMediaFile(url))
        }

        return imported
    }

    @discardableResult
    func markPlayed(itemID: UUID, at date: Date = Date()) throws -> Bool {
        try executeUpdate("""
        UPDATE media_items
        SET last_played_at = ?, updated_at = ?
        WHERE id = ?
        """) { statement in
            bind(date, to: statement, at: 1)
            bind(date, to: statement, at: 2)
            bind(itemID.uuidString, to: statement, at: 3)
        }
    }

    @discardableResult
    func setFavorite(_ isFavorite: Bool, itemID: UUID) throws -> Bool {
        try executeUpdate("""
        UPDATE media_items
        SET favorite = ?, updated_at = ?
        WHERE id = ?
        """) { statement in
            sqlite3_bind_int(statement, 1, isFavorite ? 1 : 0)
            bind(Date(), to: statement, at: 2)
            bind(itemID.uuidString, to: statement, at: 3)
        }
    }

    func primaryFileURL(for item: MediaLibraryItem) -> URL {
        item.primaryFile.url(in: rootURL)
    }

    @discardableResult
    func removeItem(id: UUID) throws -> Bool {
        guard let item = try items().first(where: { $0.id == id }) else {
            return false
        }

        let didDelete = try executeUpdate("DELETE FROM media_items WHERE id = ?") { statement in
            bind(id.uuidString, to: statement, at: 1)
        }
        guard didDelete else {
            return false
        }

        let itemDirectoryURL = managedMediaDirectoryURL(for: item)
        if FileManager.default.fileExists(atPath: itemDirectoryURL.path) {
            try FileManager.default.removeItem(at: itemDirectoryURL)
        }

        return true
    }

    private func mediaURLs(for url: URL) throws -> [URL] {
        if isDirectory(url) {
            let urls = FileManager.default.enumerator(at: url,
                                                     includingPropertiesForKeys: [.isRegularFileKey],
                                                     options: [.skipsHiddenFiles])?
                .compactMap { $0 as? URL }
                .filter { MediaLibraryStore.descriptor(for: $0) != nil }
                ?? []
            return urls.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        }

        return MediaLibraryStore.descriptor(for: url) == nil ? [] : [url]
    }

    private func importMediaFile(_ sourceURL: URL) throws -> MediaLibraryItem {
        guard let descriptor = Self.descriptor(for: sourceURL) else {
            throw MediaLibraryImportError.unsupportedMedia(sourceURL.lastPathComponent)
        }

        let sha256 = try Self.sha256Hex(for: sourceURL)
        if let existing = try item(matchingSHA256: sha256) {
            try restoreManagedFileIfNeeded(for: existing,
                                           from: sourceURL)
            return existing
        }

        let itemID = UUID()
        let fileID = UUID()
        let now = Date()
        let itemDirectoryURL = mediaDirectoryURL.appendingPathComponent(itemID.uuidString, isDirectory: true)
        let destinationFilename = Self.sanitizedFilename(sourceURL.lastPathComponent)
        let destinationURL = itemDirectoryURL.appendingPathComponent(destinationFilename)
        let relativePath = relativePath(for: destinationURL)

        do {
            try FileManager.default.createDirectory(at: itemDirectoryURL,
                                                    withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

            let file = MediaLibraryFile(id: fileID,
                                        itemID: itemID,
                                        relativePath: relativePath,
                                        originalFilename: sourceURL.lastPathComponent,
                                        originalPath: sourceURL.path,
                                        kind: descriptor.kind,
                                        mediaType: descriptor.mediaType,
                                        typeTitle: descriptor.typeTitle,
                                        sha256: sha256,
                                        byteCount: try Self.byteCount(for: destinationURL),
                                        importedAt: now)
            let entries = directoryEntries(itemID: itemID, fileID: fileID, url: destinationURL, descriptor: descriptor)
            let item = MediaLibraryItem(id: itemID,
                                        title: Self.title(for: sourceURL),
                                        preferredBehavior: .run,
                                        isFavorite: false,
                                        notes: "",
                                        createdAt: now,
                                        updatedAt: now,
                                        lastPlayedAt: nil,
                                        primaryFile: file,
                                        entries: entries)

            try insert(item)
            return item
        } catch {
            try? FileManager.default.removeItem(at: itemDirectoryURL)
            throw error
        }
    }

    private func item(matchingSHA256 sha256: String) throws -> MediaLibraryItem? {
        try items().first { $0.primaryFile.sha256 == sha256 }
    }

    private func restoreManagedFileIfNeeded(for item: MediaLibraryItem,
                                            from sourceURL: URL) throws {
        let destinationURL = primaryFileURL(for: item)
        guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
            return
        }

        let now = Date()
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        let byteCount = try Self.byteCount(for: destinationURL)

        _ = try executeUpdate("""
        UPDATE media_files
        SET original_path = ?, byte_count = ?, imported_at = ?
        WHERE id = ?
        """) { statement in
            bind(sourceURL.path, to: statement, at: 1)
            sqlite3_bind_int64(statement, 2, byteCount)
            bind(now, to: statement, at: 3)
            bind(item.primaryFile.id.uuidString, to: statement, at: 4)
        }
    }

    private func insert(_ item: MediaLibraryItem) throws {
        try beginTransaction()
        do {
            try execute("""
            INSERT INTO media_items (
                id, title, preferred_behavior, favorite, notes,
                created_at, updated_at, last_played_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """) { statement in
                bind(item.id.uuidString, to: statement, at: 1)
                bind(item.title, to: statement, at: 2)
                bind(item.preferredBehavior.rawValue, to: statement, at: 3)
                sqlite3_bind_int(statement, 4, item.isFavorite ? 1 : 0)
                bind(item.notes, to: statement, at: 5)
                bind(item.createdAt, to: statement, at: 6)
                bind(item.updatedAt, to: statement, at: 7)
                bind(item.lastPlayedAt, to: statement, at: 8)
            }

            try execute("""
            INSERT INTO media_files (
                id, item_id, relative_path, original_filename, original_path,
                media_kind, media_type, type_title, sha256, byte_count,
                imported_at, is_primary
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)
            """) { statement in
                bind(item.primaryFile.id.uuidString, to: statement, at: 1)
                bind(item.id.uuidString, to: statement, at: 2)
                bind(item.primaryFile.relativePath, to: statement, at: 3)
                bind(item.primaryFile.originalFilename, to: statement, at: 4)
                bind(item.primaryFile.originalPath, to: statement, at: 5)
                bind(item.primaryFile.kind.rawValue, to: statement, at: 6)
                bind(item.primaryFile.mediaType, to: statement, at: 7)
                bind(item.primaryFile.typeTitle, to: statement, at: 8)
                bind(item.primaryFile.sha256, to: statement, at: 9)
                sqlite3_bind_int64(statement, 10, item.primaryFile.byteCount)
                bind(item.primaryFile.importedAt, to: statement, at: 11)
            }

            for entry in item.entries {
                try execute("""
                INSERT INTO media_entries (
                    item_id, file_id, name, type_text, blocks, sort_order
                ) VALUES (?, ?, ?, ?, ?, ?)
                """) { statement in
                    bind(item.id.uuidString, to: statement, at: 1)
                    bind(item.primaryFile.id.uuidString, to: statement, at: 2)
                    bind(entry.name, to: statement, at: 3)
                    bind(entry.typeText, to: statement, at: 4)
                    sqlite3_bind_int(statement, 5, Int32(entry.blocks))
                    sqlite3_bind_int(statement, 6, Int32(entry.sortOrder))
                }
            }

            try commitTransaction()
        } catch {
            try? rollbackTransaction()
            throw error
        }
    }

    private func entries(for itemID: UUID) throws -> [MediaLibraryEntry] {
        let sql = """
        SELECT id, item_id, file_id, name, type_text, blocks, sort_order
        FROM media_entries
        WHERE item_id = ?
        ORDER BY sort_order, name COLLATE NOCASE
        """

        return try withStatement(sql) { statement in
            bind(itemID.uuidString, to: statement, at: 1)

            var entries: [MediaLibraryEntry] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let itemID = uuidColumn(statement, 1),
                      let fileID = uuidColumn(statement, 2) else {
                    continue
                }

                entries.append(MediaLibraryEntry(id: sqlite3_column_int64(statement, 0),
                                                 itemID: itemID,
                                                 fileID: fileID,
                                                 name: stringColumn(statement, 3) ?? "",
                                                 typeText: stringColumn(statement, 4) ?? "",
                                                 blocks: Int(sqlite3_column_int(statement, 5)),
                                                 sortOrder: Int(sqlite3_column_int(statement, 6))))
            }

            return entries
        }
    }

    private func directoryEntries(itemID: UUID,
                                  fileID: UUID,
                                  url: URL,
                                  descriptor: MediaDescriptor) -> [MediaLibraryEntry] {
        guard descriptor.kind == .disk,
              let image = try? DiskImageService.openImage(url: url),
              let entries = try? image.directoryEntries() else {
            return []
        }

        return entries.enumerated().map { index, entry in
            MediaLibraryEntry(id: Int64(index),
                              itemID: itemID,
                              fileID: fileID,
                              name: entry.name,
                              typeText: entry.typeText,
                              blocks: entry.blocks,
                              sortOrder: index)
        }
    }

    private func openDatabase() throws {
        var pointer: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &pointer, flags, nil) == SQLITE_OK else {
            let message = pointer.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) }
                ?? "Unable to open media library database."
            sqlite3_close(pointer)
            throw SQLiteError(message)
        }

        database = pointer
        try executeRaw("PRAGMA foreign_keys = ON")
    }

    private func migrate() throws {
        try executeRaw("""
        PRAGMA user_version = 1;

        CREATE TABLE IF NOT EXISTS media_items (
            id TEXT PRIMARY KEY NOT NULL,
            title TEXT NOT NULL,
            preferred_behavior TEXT NOT NULL,
            favorite INTEGER NOT NULL DEFAULT 0,
            notes TEXT NOT NULL DEFAULT '',
            created_at REAL NOT NULL,
            updated_at REAL NOT NULL,
            last_played_at REAL
        );

        CREATE TABLE IF NOT EXISTS media_files (
            id TEXT PRIMARY KEY NOT NULL,
            item_id TEXT NOT NULL REFERENCES media_items(id) ON DELETE CASCADE,
            relative_path TEXT NOT NULL,
            original_filename TEXT NOT NULL,
            original_path TEXT,
            media_kind TEXT NOT NULL,
            media_type TEXT NOT NULL,
            type_title TEXT NOT NULL,
            sha256 TEXT NOT NULL,
            byte_count INTEGER NOT NULL,
            imported_at REAL NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 0
        );

        CREATE UNIQUE INDEX IF NOT EXISTS media_files_sha256_unique
            ON media_files(sha256);
        CREATE INDEX IF NOT EXISTS media_files_item_id_index
            ON media_files(item_id);

        CREATE TABLE IF NOT EXISTS media_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            item_id TEXT NOT NULL REFERENCES media_items(id) ON DELETE CASCADE,
            file_id TEXT NOT NULL REFERENCES media_files(id) ON DELETE CASCADE,
            name TEXT NOT NULL,
            type_text TEXT NOT NULL,
            blocks INTEGER NOT NULL DEFAULT 0,
            sort_order INTEGER NOT NULL DEFAULT 0
        );

        CREATE INDEX IF NOT EXISTS media_entries_item_id_index
            ON media_entries(item_id);
        """)
    }

    private func executeRaw(_ sql: String) throws {
        guard let database else {
            throw SQLiteError("Media library database is not open.")
        }

        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(database, sql, nil, nil, &error) != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "SQLite command failed."
            sqlite3_free(error)
            throw SQLiteError(message)
        }
    }

    private func execute(_ sql: String,
                         bindings: (OpaquePointer?) -> Void) throws {
        try withStatement(sql) { statement in
            bindings(statement)
            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw sqliteError()
            }
        }
    }

    private func executeUpdate(_ sql: String,
                               bindings: (OpaquePointer?) -> Void) throws -> Bool {
        try execute(sql, bindings: bindings)
        guard let database else {
            return false
        }

        return sqlite3_changes(database) > 0
    }

    private func withStatement<T>(_ sql: String,
                                  _ body: (OpaquePointer?) throws -> T) throws -> T {
        guard let database else {
            throw SQLiteError("Media library database is not open.")
        }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK else {
            throw sqliteError()
        }
        defer { sqlite3_finalize(statement) }

        return try body(statement)
    }

    private func beginTransaction() throws {
        try executeRaw("BEGIN IMMEDIATE TRANSACTION")
    }

    private func commitTransaction() throws {
        try executeRaw("COMMIT")
    }

    private func rollbackTransaction() throws {
        try executeRaw("ROLLBACK")
    }

    private func sqliteError() -> SQLiteError {
        guard let database,
              let message = sqlite3_errmsg(database) else {
            return SQLiteError("SQLite command failed.")
        }

        return SQLiteError(String(cString: message))
    }

    private func relativePath(for url: URL) -> String {
        let rootPath = rootURL.path + "/"
        let path = url.path
        guard path.hasPrefix(rootPath) else {
            return url.lastPathComponent
        }

        return String(path.dropFirst(rootPath.count))
    }

    private func managedMediaDirectoryURL(for item: MediaLibraryItem) -> URL {
        mediaDirectoryURL.appendingPathComponent(item.id.uuidString, isDirectory: true)
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private static func title(for url: URL) -> String {
        let stem = url.deletingPathExtension().lastPathComponent
        let cleaned = stem
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return cleaned.isEmpty ? url.lastPathComponent : cleaned
    }

    private static func sanitizedFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:")
        let sanitized = String(filename.unicodeScalars.map { scalar in
            invalidCharacters.contains(scalar) ? "-" : Character(scalar).description
        }.joined())

        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "media"
            : sanitized
    }

    private static func byteCount(for url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    private static func sha256Hex(for url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func bind(_ value: String?, to statement: OpaquePointer?, at index: Int32) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }

        sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
    }

    private func bind(_ value: Date?, to statement: OpaquePointer?, at index: Int32) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }

        sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
    }
}

private struct SQLiteError: Error, LocalizedError, Equatable {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func stringColumn(_ statement: OpaquePointer?, _ index: Int32) -> String? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL,
          let text = sqlite3_column_text(statement, index) else {
        return nil
    }

    return String(cString: text)
}

private func uuidColumn(_ statement: OpaquePointer?, _ index: Int32) -> UUID? {
    stringColumn(statement, index).flatMap(UUID.init(uuidString:))
}

private func dateColumn(_ statement: OpaquePointer?, _ index: Int32) -> Date? {
    guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
        return nil
    }

    return Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
}
