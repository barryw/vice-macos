import Combine
import Foundation
import PDFKit
import SQLite3

struct AIDocumentMachine: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String

    static let all: [AIDocumentMachine] = [
        machine(EmulatedMachine.x64sc, systemImage: "desktopcomputer"),
        machine(EmulatedMachine.x128, systemImage: "desktopcomputer"),
        machine(EmulatedMachine.xvic, systemImage: "display"),
        machine(EmulatedMachine.xpet, systemImage: "terminal"),
        machine(EmulatedMachine.xplus4, systemImage: "desktopcomputer"),
        machine(EmulatedMachine.xc16, systemImage: "desktopcomputer"),
        machine(EmulatedMachine.xc232, systemImage: "desktopcomputer"),
        machine(EmulatedMachine.xv364, systemImage: "desktopcomputer")
    ]

    static func title(for machineID: String) -> String {
        all.first { $0.id == machineID }?.title ?? machineID
    }

    private static func machine(_ machine: EmulatedMachine, systemImage: String) -> AIDocumentMachine {
        AIDocumentMachine(id: machine.id.rawValue,
                          title: machine.displayName,
                          systemImage: systemImage)
    }
}

enum AIDocumentIndexStatus: String, Equatable {
    case indexed
    case failed

    var title: String {
        switch self {
        case .indexed:
            return "Indexed"
        case .failed:
            return "Failed"
        }
    }
}

struct AIDocumentRecord: Identifiable, Equatable {
    let id: UUID
    var machineID: String
    var title: String
    var originalFilename: String
    var relativePath: String
    var originalPath: String?
    var sha256: String
    var pageCount: Int
    var chunkCount: Int
    var status: AIDocumentIndexStatus
    var errorMessage: String?
    var importedAt: Date
    var updatedAt: Date

    var machineTitle: String {
        AIDocumentMachine.title(for: machineID)
    }
}

struct AIDocumentSearchResult: Equatable {
    var chunkID: String
    var documentID: UUID
    var title: String
    var machineID: String
    var chunkIndex: Int
    var pageStart: Int
    var pageEnd: Int
    var excerpt: String
    var score: Double
}

struct AIDocumentContextResult: Equatable {
    struct Chunk: Equatable {
        var chunkID: String
        var chunkIndex: Int
        var pageStart: Int
        var pageEnd: Int
        var text: String
    }

    var documentID: UUID
    var title: String
    var machineID: String
    var chunks: [Chunk]
}

enum AIDocumentLibraryImportError: Error, LocalizedError, Equatable {
    case unsupportedFile(String)
    case unreadablePDF(String)
    case noSearchableText(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFile(let filename):
            return "\(filename) is not a PDF."
        case .unreadablePDF(let filename):
            return "\(filename) could not be opened as a PDF."
        case .noSearchableText(let filename):
            return "\(filename) does not contain searchable PDF text."
        }
    }
}

struct AIDocumentLibraryImportBatchError: Error, LocalizedError, Equatable {
    let importedCount: Int
    let failures: [String]

    var errorDescription: String? {
        let prefix = importedCount > 0
            ? "Imported \(importedCount), rejected \(failures.count):"
            : "Rejected \(failures.count):"
        return ([prefix] + failures).joined(separator: "\n")
    }
}

@MainActor
final class AIDocumentLibraryStore: ObservableObject {
    static var defaultLibraryDirectoryURL: URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory,
                                               in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")

        return baseURL
            .appendingPathComponent("VICE Mac", isDirectory: true)
            .appendingPathComponent("AI Documents", isDirectory: true)
    }

    @Published private(set) var documents: [AIDocumentRecord] = []
    @Published private(set) var isImporting = false
    @Published private(set) var lastErrorMessage: String?

    let rootURL: URL
    let documentDirectoryURL: URL
    let databaseURL: URL

    nonisolated(unsafe) private var database: OpaquePointer?

    init(rootURL: URL = AIDocumentLibraryStore.defaultLibraryDirectoryURL) {
        self.rootURL = rootURL
        documentDirectoryURL = rootURL.appendingPathComponent("Documents", isDirectory: true)
        databaseURL = rootURL.appendingPathComponent("library.sqlite")

        do {
            try FileManager.default.createDirectory(at: documentDirectoryURL,
                                                    withIntermediateDirectories: true)
            try openDatabase()
            try migrate()
            try reload()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    deinit {
        sqlite3_close(database)
    }

    func documents(for machineID: String) -> [AIDocumentRecord] {
        documents.filter { $0.machineID == machineID }
    }

    @discardableResult
    func importPDFs(_ urls: [URL], machineID: String) async -> [AIDocumentRecord] {
        guard !urls.isEmpty else {
            return []
        }

        isImporting = true
        defer { isImporting = false }

        var imported: [AIDocumentRecord] = []
        var failures: [String] = []

        for url in urls {
            do {
                imported.append(try importPDF(url, machineID: machineID))
            } catch {
                let message = error.localizedDescription
                failures.append(message.contains(url.lastPathComponent) ? message : "\(url.lastPathComponent): \(message)")
            }
        }

        do {
            try reload()
        } catch {
            failures.append(error.localizedDescription)
        }

        if failures.isEmpty {
            lastErrorMessage = nil
        } else {
            lastErrorMessage = AIDocumentLibraryImportBatchError(importedCount: imported.count,
                                                                 failures: failures).localizedDescription
        }

        return imported
    }

    @discardableResult
    func removeDocuments(ids: Set<UUID>) -> Int {
        guard !ids.isEmpty else {
            return 0
        }

        var removedCount = 0
        for id in ids {
            do {
                if try removeDocument(id: id) {
                    removedCount += 1
                }
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }

        do {
            try reload()
        } catch {
            lastErrorMessage = error.localizedDescription
        }

        return removedCount
    }

    func clearLastError() {
        lastErrorMessage = nil
    }

    func search(machineID: String, query: String, limit: Int = 8) throws -> [AIDocumentSearchResult] {
        guard let ftsQuery = Self.ftsQuery(for: query) else {
            return []
        }

        let clampedLimit = min(max(limit, 1), 20)
        let sql = """
        SELECT
            ai_document_chunks_fts.chunk_id,
            ai_document_chunks_fts.document_id,
            d.title,
            ai_document_chunks_fts.machine_id,
            c.chunk_index,
            c.page_start,
            c.page_end,
            snippet(ai_document_chunks_fts, 4, '', '', ' ... ', 32),
            bm25(ai_document_chunks_fts) AS score
        FROM ai_document_chunks_fts
        JOIN ai_documents d ON d.id = ai_document_chunks_fts.document_id
        JOIN ai_document_chunks c ON c.id = ai_document_chunks_fts.chunk_id
        WHERE ai_document_chunks_fts MATCH ?
            AND ai_document_chunks_fts.machine_id = ?
            AND d.status = ?
        ORDER BY score
        LIMIT ?
        """

        return try withStatement(sql) { statement in
            bind(ftsQuery, to: statement, at: 1)
            bind(machineID, to: statement, at: 2)
            bind(AIDocumentIndexStatus.indexed.rawValue, to: statement, at: 3)
            sqlite3_bind_int(statement, 4, Int32(clampedLimit))

            var results: [AIDocumentSearchResult] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let chunkID = stringColumn(statement, 0),
                      let documentID = uuidColumn(statement, 1) else {
                    continue
                }

                results.append(AIDocumentSearchResult(
                    chunkID: chunkID,
                    documentID: documentID,
                    title: stringColumn(statement, 2) ?? "Untitled",
                    machineID: stringColumn(statement, 3) ?? machineID,
                    chunkIndex: Int(sqlite3_column_int(statement, 4)),
                    pageStart: Int(sqlite3_column_int(statement, 5)),
                    pageEnd: Int(sqlite3_column_int(statement, 6)),
                    excerpt: Self.normalizedExcerpt(stringColumn(statement, 7) ?? ""),
                    score: sqlite3_column_double(statement, 8)
                ))
            }

            return results
        }
    }

    func context(machineID: String, chunkID: String, before: Int = 1, after: Int = 1) throws -> AIDocumentContextResult? {
        let lookupSQL = """
        SELECT c.document_id, c.chunk_index, d.title, d.machine_id
        FROM ai_document_chunks c
        JOIN ai_documents d ON d.id = c.document_id
        WHERE c.id = ? AND d.machine_id = ? AND d.status = ?
        """

        let lookup = try withStatement(lookupSQL) { statement -> (UUID, Int, String, String)? in
            bind(chunkID, to: statement, at: 1)
            bind(machineID, to: statement, at: 2)
            bind(AIDocumentIndexStatus.indexed.rawValue, to: statement, at: 3)

            guard sqlite3_step(statement) == SQLITE_ROW,
                  let documentID = uuidColumn(statement, 0) else {
                return nil
            }

            return (documentID,
                    Int(sqlite3_column_int(statement, 1)),
                    stringColumn(statement, 2) ?? "Untitled",
                    stringColumn(statement, 3) ?? machineID)
        }

        guard let lookup else {
            return nil
        }

        let beforeCount = min(max(before, 0), 3)
        let afterCount = min(max(after, 0), 3)
        let minIndex = max(0, lookup.1 - beforeCount)
        let maxIndex = lookup.1 + afterCount
        let chunksSQL = """
        SELECT id, chunk_index, page_start, page_end, text
        FROM ai_document_chunks
        WHERE document_id = ? AND chunk_index BETWEEN ? AND ?
        ORDER BY chunk_index
        """

        let chunks = try withStatement(chunksSQL) { statement in
            bind(lookup.0.uuidString, to: statement, at: 1)
            sqlite3_bind_int(statement, 2, Int32(minIndex))
            sqlite3_bind_int(statement, 3, Int32(maxIndex))

            var chunks: [AIDocumentContextResult.Chunk] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = stringColumn(statement, 0) else {
                    continue
                }

                chunks.append(AIDocumentContextResult.Chunk(
                    chunkID: id,
                    chunkIndex: Int(sqlite3_column_int(statement, 1)),
                    pageStart: Int(sqlite3_column_int(statement, 2)),
                    pageEnd: Int(sqlite3_column_int(statement, 3)),
                    text: stringColumn(statement, 4) ?? ""
                ))
            }
            return chunks
        }

        return AIDocumentContextResult(documentID: lookup.0,
                                       title: lookup.2,
                                       machineID: lookup.3,
                                       chunks: chunks)
    }

    private func reload() throws {
        documents = try records()
    }

    private func importPDF(_ sourceURL: URL, machineID: String) throws -> AIDocumentRecord {
        guard sourceURL.pathExtension.lowercased() == "pdf" else {
            throw AIDocumentLibraryImportError.unsupportedFile(sourceURL.lastPathComponent)
        }

        let didStartAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let sha256 = try sourceURL.sha256HexString()
        if let existing = try document(matchingSHA256: sha256, machineID: machineID) {
            return existing
        }

        let extractedDocument = try Self.extractPDF(sourceURL)
        let documentID = UUID()
        let now = Date()
        let documentRootURL = documentDirectoryURL.appendingPathComponent(documentID.uuidString, isDirectory: true)
        let destinationFilename = Self.sanitizedFilename(sourceURL.lastPathComponent)
        let destinationURL = documentRootURL.appendingPathComponent(destinationFilename)
        let record = AIDocumentRecord(id: documentID,
                                      machineID: machineID,
                                      title: Self.title(for: sourceURL),
                                      originalFilename: sourceURL.lastPathComponent,
                                      relativePath: relativePath(for: destinationURL),
                                      originalPath: sourceURL.path,
                                      sha256: sha256,
                                      pageCount: extractedDocument.pageCount,
                                      chunkCount: extractedDocument.chunks.count,
                                      status: .indexed,
                                      errorMessage: nil,
                                      importedAt: now,
                                      updatedAt: now)

        do {
            try FileManager.default.createDirectory(at: documentRootURL,
                                                    withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            try insert(record, chunks: extractedDocument.chunks)
            return record
        } catch {
            try? FileManager.default.removeItem(at: documentRootURL)
            throw error
        }
    }

    private func records() throws -> [AIDocumentRecord] {
        let sql = """
        SELECT id, machine_id, title, original_filename, relative_path, original_path,
               sha256, page_count, chunk_count, status, error_message, imported_at, updated_at
        FROM ai_documents
        ORDER BY title COLLATE NOCASE, original_filename COLLATE NOCASE
        """

        return try withStatement(sql) { statement in
            var documents: [AIDocumentRecord] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                guard let id = uuidColumn(statement, 0),
                      let status = AIDocumentIndexStatus(rawValue: stringColumn(statement, 9) ?? "") else {
                    continue
                }

                documents.append(AIDocumentRecord(
                    id: id,
                    machineID: stringColumn(statement, 1) ?? "",
                    title: stringColumn(statement, 2) ?? "Untitled",
                    originalFilename: stringColumn(statement, 3) ?? "",
                    relativePath: stringColumn(statement, 4) ?? "",
                    originalPath: stringColumn(statement, 5),
                    sha256: stringColumn(statement, 6) ?? "",
                    pageCount: Int(sqlite3_column_int(statement, 7)),
                    chunkCount: Int(sqlite3_column_int(statement, 8)),
                    status: status,
                    errorMessage: stringColumn(statement, 10),
                    importedAt: dateColumn(statement, 11) ?? Date(timeIntervalSince1970: 0),
                    updatedAt: dateColumn(statement, 12) ?? Date(timeIntervalSince1970: 0)
                ))
            }
            return documents
        }
    }

    private func document(matchingSHA256 sha256: String, machineID: String) throws -> AIDocumentRecord? {
        try records().first { $0.sha256 == sha256 && $0.machineID == machineID }
    }

    private func insert(_ document: AIDocumentRecord, chunks: [ExtractedPDFChunk]) throws {
        try beginTransaction()
        do {
            try execute("""
            INSERT INTO ai_documents (
                id, machine_id, title, original_filename, relative_path, original_path,
                sha256, page_count, chunk_count, status, error_message, imported_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """) { statement in
                bind(document.id.uuidString, to: statement, at: 1)
                bind(document.machineID, to: statement, at: 2)
                bind(document.title, to: statement, at: 3)
                bind(document.originalFilename, to: statement, at: 4)
                bind(document.relativePath, to: statement, at: 5)
                bind(document.originalPath, to: statement, at: 6)
                bind(document.sha256, to: statement, at: 7)
                sqlite3_bind_int(statement, 8, Int32(document.pageCount))
                sqlite3_bind_int(statement, 9, Int32(document.chunkCount))
                bind(document.status.rawValue, to: statement, at: 10)
                bind(document.errorMessage, to: statement, at: 11)
                bind(document.importedAt, to: statement, at: 12)
                bind(document.updatedAt, to: statement, at: 13)
            }

            for chunk in chunks {
                let chunkID = UUID().uuidString
                try execute("""
                INSERT INTO ai_document_chunks (
                    id, document_id, machine_id, chunk_index, page_start, page_end, text
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
                """) { statement in
                    bind(chunkID, to: statement, at: 1)
                    bind(document.id.uuidString, to: statement, at: 2)
                    bind(document.machineID, to: statement, at: 3)
                    sqlite3_bind_int(statement, 4, Int32(chunk.index))
                    sqlite3_bind_int(statement, 5, Int32(chunk.pageStart))
                    sqlite3_bind_int(statement, 6, Int32(chunk.pageEnd))
                    bind(chunk.text, to: statement, at: 7)
                }

                try execute("""
                INSERT INTO ai_document_chunks_fts (
                    chunk_id, document_id, machine_id, title, text
                ) VALUES (?, ?, ?, ?, ?)
                """) { statement in
                    bind(chunkID, to: statement, at: 1)
                    bind(document.id.uuidString, to: statement, at: 2)
                    bind(document.machineID, to: statement, at: 3)
                    bind(document.title, to: statement, at: 4)
                    bind(chunk.text, to: statement, at: 5)
                }
            }

            try commitTransaction()
        } catch {
            try? rollbackTransaction()
            throw error
        }
    }

    private func removeDocument(id: UUID) throws -> Bool {
        let document: AIDocumentRecord?
        if let cachedDocument = documents.first(where: { $0.id == id }) {
            document = cachedDocument
        } else {
            document = try records().first { $0.id == id }
        }

        guard let document else {
            return false
        }

        try beginTransaction()
        do {
            try execute("DELETE FROM ai_document_chunks_fts WHERE document_id = ?") { statement in
                bind(id.uuidString, to: statement, at: 1)
            }
            let didDelete = try executeUpdate("DELETE FROM ai_documents WHERE id = ?") { statement in
                bind(id.uuidString, to: statement, at: 1)
            }
            try commitTransaction()

            guard didDelete else {
                return false
            }

            let documentRootURL = managedDocumentDirectoryURL(for: document)
            if FileManager.default.fileExists(atPath: documentRootURL.path) {
                try FileManager.default.removeItem(at: documentRootURL)
            }

            return true
        } catch {
            try? rollbackTransaction()
            throw error
        }
    }

    private func openDatabase() throws {
        var pointer: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(databaseURL.path, &pointer, flags, nil) == SQLITE_OK else {
            let message = pointer.flatMap { sqlite3_errmsg($0) }.map { String(cString: $0) }
                ?? "Unable to open AI document library database."
            sqlite3_close(pointer)
            throw AIDocumentLibrarySQLiteError(message)
        }

        database = pointer
        try executeRaw("PRAGMA foreign_keys = ON")
    }

    private func migrate() throws {
        try executeRaw("""
        PRAGMA user_version = 1;

        CREATE TABLE IF NOT EXISTS ai_documents (
            id TEXT PRIMARY KEY NOT NULL,
            machine_id TEXT NOT NULL,
            title TEXT NOT NULL,
            original_filename TEXT NOT NULL,
            relative_path TEXT NOT NULL,
            original_path TEXT,
            sha256 TEXT NOT NULL,
            page_count INTEGER NOT NULL,
            chunk_count INTEGER NOT NULL,
            status TEXT NOT NULL,
            error_message TEXT,
            imported_at REAL NOT NULL,
            updated_at REAL NOT NULL
        );

        CREATE UNIQUE INDEX IF NOT EXISTS ai_documents_machine_sha256_unique
            ON ai_documents(machine_id, sha256);
        CREATE INDEX IF NOT EXISTS ai_documents_machine_id_index
            ON ai_documents(machine_id);

        CREATE TABLE IF NOT EXISTS ai_document_chunks (
            id TEXT PRIMARY KEY NOT NULL,
            document_id TEXT NOT NULL REFERENCES ai_documents(id) ON DELETE CASCADE,
            machine_id TEXT NOT NULL,
            chunk_index INTEGER NOT NULL,
            page_start INTEGER NOT NULL,
            page_end INTEGER NOT NULL,
            text TEXT NOT NULL
        );

        CREATE INDEX IF NOT EXISTS ai_document_chunks_document_id_index
            ON ai_document_chunks(document_id, chunk_index);
        CREATE INDEX IF NOT EXISTS ai_document_chunks_machine_id_index
            ON ai_document_chunks(machine_id);

        CREATE VIRTUAL TABLE IF NOT EXISTS ai_document_chunks_fts USING fts5(
            chunk_id UNINDEXED,
            document_id UNINDEXED,
            machine_id UNINDEXED,
            title,
            text,
            tokenize = 'unicode61'
        );
        """)
    }

    private func executeRaw(_ sql: String) throws {
        guard let database else {
            throw AIDocumentLibrarySQLiteError("AI document library database is not open.")
        }

        var error: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(database, sql, nil, nil, &error) != SQLITE_OK {
            let message = error.map { String(cString: $0) } ?? "SQLite command failed."
            sqlite3_free(error)
            throw AIDocumentLibrarySQLiteError(message)
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
            throw AIDocumentLibrarySQLiteError("AI document library database is not open.")
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

    private func sqliteError() -> AIDocumentLibrarySQLiteError {
        guard let database,
              let message = sqlite3_errmsg(database) else {
            return AIDocumentLibrarySQLiteError("SQLite command failed.")
        }

        return AIDocumentLibrarySQLiteError(String(cString: message))
    }

    private func relativePath(for url: URL) -> String {
        let rootPath = rootURL.path + "/"
        let path = url.path
        guard path.hasPrefix(rootPath) else {
            return url.lastPathComponent
        }

        return String(path.dropFirst(rootPath.count))
    }

    private func managedDocumentDirectoryURL(for document: AIDocumentRecord) -> URL {
        documentDirectoryURL.appendingPathComponent(document.id.uuidString, isDirectory: true)
    }

    private func bind(_ value: String?, to statement: OpaquePointer?, at index: Int32) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }

        sqlite3_bind_text(statement, index, value, -1, aiDocumentSQLiteTransient)
    }

    private func bind(_ value: Date?, to statement: OpaquePointer?, at index: Int32) {
        guard let value else {
            sqlite3_bind_null(statement, index)
            return
        }

        sqlite3_bind_double(statement, index, value.timeIntervalSince1970)
    }

    private static func extractPDF(_ url: URL) throws -> ExtractedPDFDocument {
        guard let pdf = PDFDocument(url: url),
              pdf.pageCount > 0 else {
            throw AIDocumentLibraryImportError.unreadablePDF(url.lastPathComponent)
        }

        var chunks: [ExtractedPDFChunk] = []
        var buffer: [String] = []
        var bufferCount = 0
        var bufferStartPage: Int?
        var bufferEndPage: Int?
        var searchableCharacterCount = 0

        func flushBuffer() {
            let text = buffer.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty,
                  let pageStart = bufferStartPage,
                  let pageEnd = bufferEndPage else {
                buffer.removeAll()
                bufferCount = 0
                bufferStartPage = nil
                bufferEndPage = nil
                return
            }

            chunks.append(ExtractedPDFChunk(index: chunks.count,
                                            pageStart: pageStart,
                                            pageEnd: pageEnd,
                                            text: text))
            buffer.removeAll()
            bufferCount = 0
            bufferStartPage = nil
            bufferEndPage = nil
        }

        func append(_ segment: String, page: Int) {
            let cleaned = segment.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else {
                return
            }

            let pieces = splitText(cleaned, maxLength: hardChunkCharacterLimit)
            for piece in pieces {
                if bufferCount > 0,
                   bufferCount + piece.count + 1 > targetChunkCharacterCount {
                    flushBuffer()
                }

                if bufferStartPage == nil {
                    bufferStartPage = page
                }
                bufferEndPage = page
                buffer.append(piece)
                bufferCount += piece.count + 1
            }
        }

        for pageIndex in 0..<pdf.pageCount {
            guard let page = pdf.page(at: pageIndex) else {
                continue
            }

            let pageNumber = pageIndex + 1
            let text = normalizedPDFText(page.string ?? "")
            searchableCharacterCount += text.filter { !$0.isWhitespace }.count
            let segments = text.components(separatedBy: .newlines)
            for segment in segments {
                append(segment, page: pageNumber)
            }
        }

        flushBuffer()

        guard searchableCharacterCount >= minimumSearchableCharacterCount,
              !chunks.isEmpty else {
            throw AIDocumentLibraryImportError.noSearchableText(url.lastPathComponent)
        }

        return ExtractedPDFDocument(pageCount: pdf.pageCount,
                                    chunks: chunks)
    }

    private static func normalizedPDFText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: .newlines)
            .map { line in
                line
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: #"\s+"#,
                                          with: " ",
                                          options: .regularExpression)
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func splitText(_ text: String, maxLength: Int) -> [String] {
        guard text.count > maxLength else {
            return [text]
        }

        var pieces: [String] = []
        var current = ""
        for word in text.split(separator: " ") {
            let wordText = String(word)
            if wordText.count > maxLength {
                if !current.isEmpty {
                    pieces.append(current)
                    current = ""
                }
                pieces.append(contentsOf: stride(from: 0, to: wordText.count, by: maxLength).map { start in
                    let lower = wordText.index(wordText.startIndex, offsetBy: start)
                    let upper = wordText.index(lower,
                                               offsetBy: min(maxLength, wordText.distance(from: lower,
                                                                                         to: wordText.endIndex)))
                    return String(wordText[lower..<upper])
                })
                continue
            }

            if current.isEmpty {
                current = wordText
            } else if current.count + wordText.count + 1 <= maxLength {
                current += " " + wordText
            } else {
                pieces.append(current)
                current = wordText
            }
        }

        if !current.isEmpty {
            pieces.append(current)
        }
        return pieces
    }

    private static func ftsQuery(for query: String) -> String? {
        let allowedCharacters = CharacterSet.alphanumerics
        let terms = query
            .lowercased()
            .components(separatedBy: allowedCharacters.inverted)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count >= 2 }

        guard !terms.isEmpty else {
            return nil
        }

        var seenTerms = Set<String>()
        var uniqueTerms: [String] = []
        for term in terms where seenTerms.insert(term).inserted {
            uniqueTerms.append(term)
            if uniqueTerms.count == 10 {
                break
            }
        }
        return uniqueTerms.map { "\"\($0)\"" }.joined(separator: " OR ")
    }

    private static func normalizedExcerpt(_ excerpt: String) -> String {
        excerpt
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: #"\s+"#,
                                  with: " ",
                                  options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
            ? "document.pdf"
            : sanitized
    }

    private static let minimumSearchableCharacterCount = 100
    private static let targetChunkCharacterCount = 3_200
    private static let hardChunkCharacterLimit = 4_000
}

private struct ExtractedPDFDocument {
    var pageCount: Int
    var chunks: [ExtractedPDFChunk]
}

private struct ExtractedPDFChunk {
    var index: Int
    var pageStart: Int
    var pageEnd: Int
    var text: String
}

private struct AIDocumentLibrarySQLiteError: Error, LocalizedError, Equatable {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

private let aiDocumentSQLiteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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
