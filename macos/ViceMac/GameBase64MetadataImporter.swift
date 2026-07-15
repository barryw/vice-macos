import Foundation
import zlib

enum GameBase64MetadataPackageKind: String, Equatable {
    case accessDatabase
    case innoSetupInstaller
    case zipArchive
}

struct GameBase64MetadataImportResult: Equatable {
    var databaseURL: URL
    var sourceURL: URL
    var packageKind: GameBase64MetadataPackageKind
}

protocol InnoSetupExtracting {
    func extractAccessDatabase(from installerURL: URL,
                               to temporaryDirectoryURL: URL) throws -> URL
}

enum GameBase64MetadataImportError: Error, LocalizedError, Equatable {
    case unsupportedPackage(String)
    case invalidAccessDatabase(String)
    case emptyZIPArchive(String)
    case noAccessDatabaseInPackage(String)
    case encryptedZIPEntry(String)
    case unsupportedZIPCompression(String)
    case invalidZIPArchive(String)
    case corruptZIPEntry(String)
    case nativeInnoExtractorUnavailable

    var errorDescription: String? {
        switch self {
        case .unsupportedPackage(let filename):
            return "\(filename) is not a GameBase64 MDB, ZIP archive, or Inno Setup installer."
        case .invalidAccessDatabase(let filename):
            return "\(filename) does not look like an Access MDB database."
        case .emptyZIPArchive(let filename):
            return "\(filename) does not contain any files."
        case .noAccessDatabaseInPackage(let filename):
            return "\(filename) does not contain a GameBase64 MDB database."
        case .encryptedZIPEntry(let filename):
            return "\(filename) is encrypted. Encrypted ZIP entries are not supported."
        case .unsupportedZIPCompression(let filename):
            return "\(filename) uses a ZIP compression method VICE Mac cannot read yet."
        case .invalidZIPArchive(let filename):
            return "\(filename) is not a readable ZIP archive."
        case .corruptZIPEntry(let filename):
            return "\(filename) could not be decompressed or did not pass its checksum."
        case .nativeInnoExtractorUnavailable:
            return "This build does not include the embedded Inno Setup extractor yet. Provide the extracted MDB file instead."
        }
    }
}

final class GameBase64MetadataImporter {
    private let extractor: InnoSetupExtracting?
    private let fileManager: FileManager

    init(extractor: InnoSetupExtracting? = nil,
         fileManager: FileManager = .default) {
        self.extractor = extractor
        self.fileManager = fileManager
    }

    func importPackage(at sourceURL: URL,
                       into destinationRootURL: URL) throws -> GameBase64MetadataImportResult {
        let packageKind = try Self.packageKind(for: sourceURL)
        let destinationDirectoryURL = destinationRootURL.appendingPathComponent("GameBase64", isDirectory: true)
        try fileManager.createDirectory(at: destinationDirectoryURL,
                                        withIntermediateDirectories: true)

        switch packageKind {
        case .accessDatabase:
            let databaseURL = try copyAccessDatabase(sourceURL,
                                                    to: destinationDirectoryURL,
                                                    preferredFilename: sourceURL.lastPathComponent)
            return GameBase64MetadataImportResult(databaseURL: databaseURL,
                                                 sourceURL: sourceURL,
                                                 packageKind: packageKind)
        case .zipArchive:
            let resultURL = try importZIPPackage(at: sourceURL,
                                                 into: destinationDirectoryURL)
            return GameBase64MetadataImportResult(databaseURL: resultURL,
                                                 sourceURL: sourceURL,
                                                 packageKind: packageKind)
        case .innoSetupInstaller:
            let resultURL = try importInnoSetupInstaller(at: sourceURL,
                                                        into: destinationDirectoryURL)
            return GameBase64MetadataImportResult(databaseURL: resultURL,
                                                 sourceURL: sourceURL,
                                                 packageKind: packageKind)
        }
    }

    static func packageKind(for url: URL) throws -> GameBase64MetadataPackageKind {
        switch url.pathExtension.lowercased() {
        case "mdb":
            return .accessDatabase
        case "zip":
            return .zipArchive
        case "exe":
            guard isLikelyInnoSetupInstaller(url) else {
                throw GameBase64MetadataImportError.unsupportedPackage(url.lastPathComponent)
            }
            return .innoSetupInstaller
        default:
            throw GameBase64MetadataImportError.unsupportedPackage(url.lastPathComponent)
        }
    }

    static func isLikelyInnoSetupInstaller(_ url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              data.starts(with: [0x4d, 0x5a]) else {
            return false
        }

        return data.range(of: Data("Inno Setup Setup Data".utf8)) != nil
    }

    private func importZIPPackage(at sourceURL: URL,
                                  into destinationDirectoryURL: URL) throws -> URL {
        let archive = try SimpleZIPArchive(url: sourceURL)
        guard !archive.entries.isEmpty else {
            throw GameBase64MetadataImportError.emptyZIPArchive(sourceURL.lastPathComponent)
        }

        if let databaseEntry = archive.entries.first(where: { $0.filename.pathExtension.lowercased() == "mdb" }) {
            let extractedURL = destinationDirectoryURL
                .appendingPathComponent(Self.sanitizedFilename(databaseEntry.filename.lastPathComponent))
            try archive.extract(databaseEntry, to: extractedURL)
            return try copyAccessDatabase(extractedURL,
                                          to: destinationDirectoryURL,
                                          preferredFilename: databaseEntry.filename.lastPathComponent)
        }

        if let installerEntry = archive.entries.first(where: { $0.filename.pathExtension.lowercased() == "exe" }) {
            let temporaryDirectoryURL = try temporaryDirectoryURL()
            defer { try? fileManager.removeItem(at: temporaryDirectoryURL) }

            let installerURL = temporaryDirectoryURL
                .appendingPathComponent(Self.sanitizedFilename(installerEntry.filename.lastPathComponent))
            try archive.extract(installerEntry, to: installerURL)
            return try importInnoSetupInstaller(at: installerURL,
                                                into: destinationDirectoryURL)
        }

        throw GameBase64MetadataImportError.noAccessDatabaseInPackage(sourceURL.lastPathComponent)
    }

    private func importInnoSetupInstaller(at sourceURL: URL,
                                          into destinationDirectoryURL: URL) throws -> URL {
        guard Self.isLikelyInnoSetupInstaller(sourceURL) else {
            throw GameBase64MetadataImportError.unsupportedPackage(sourceURL.lastPathComponent)
        }

        guard let extractor else {
            throw GameBase64MetadataImportError.nativeInnoExtractorUnavailable
        }

        let temporaryDirectoryURL = try temporaryDirectoryURL()
        defer { try? fileManager.removeItem(at: temporaryDirectoryURL) }

        let extractedDatabaseURL = try extractor.extractAccessDatabase(from: sourceURL,
                                                                       to: temporaryDirectoryURL)
        return try copyAccessDatabase(extractedDatabaseURL,
                                      to: destinationDirectoryURL,
                                      preferredFilename: extractedDatabaseURL.lastPathComponent)
    }

    private func copyAccessDatabase(_ sourceURL: URL,
                                    to destinationDirectoryURL: URL,
                                    preferredFilename: String) throws -> URL {
        guard Self.looksLikeAccessDatabase(sourceURL) else {
            throw GameBase64MetadataImportError.invalidAccessDatabase(sourceURL.lastPathComponent)
        }

        let destinationFilename = Self.sanitizedFilename(preferredFilename).isEmpty
            ? "GameBase64.mdb"
            : Self.sanitizedFilename(preferredFilename)
        let destinationURL = destinationDirectoryURL.appendingPathComponent(destinationFilename)

        if sourceURL.standardizedFileURL == destinationURL.standardizedFileURL {
            return destinationURL
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    private func temporaryDirectoryURL() throws -> URL {
        let url = fileManager.temporaryDirectory
            .appendingPathComponent("ViceMac-GameBase64-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func looksLikeAccessDatabase(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer { try? handle.close() }

        let signature = handle.readData(ofLength: 8)
        return signature == Data([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1])
    }

    private static func sanitizedFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:")
        let sanitized = String(filename.unicodeScalars.map { scalar in
            invalidCharacters.contains(scalar) ? "-" : Character(scalar).description
        }.joined())

        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct SimpleZIPArchive {
    struct Entry {
        var filename: String
        var generalPurposeFlags: UInt16
        var compressionMethod: UInt16
        var crc32: UInt32
        var compressedSize: UInt32
        var uncompressedSize: UInt32
        var localHeaderOffset: UInt32
    }

    let url: URL
    let data: Data
    let entries: [Entry]

    init(url: URL) throws {
        self.url = url
        data = try Data(contentsOf: url)
        entries = try Self.readEntries(from: data, archiveFilename: url.lastPathComponent)
    }

    func extract(_ entry: Entry, to destinationURL: URL) throws {
        let filename = entry.filename.lastPathComponent
        guard entry.generalPurposeFlags & 0x0001 == 0 else {
            throw GameBase64MetadataImportError.encryptedZIPEntry(filename)
        }

        let localOffset = Int(entry.localHeaderOffset)
        guard try data.uint32LE(at: localOffset) == 0x04034b50 else {
            throw GameBase64MetadataImportError.invalidZIPArchive(url.lastPathComponent)
        }

        let localNameLength = Int(try data.uint16LE(at: localOffset + 26))
        let localExtraLength = Int(try data.uint16LE(at: localOffset + 28))
        let compressedStart = localOffset + 30 + localNameLength + localExtraLength
        let compressedEnd = compressedStart + Int(entry.compressedSize)
        guard compressedStart >= 0,
              compressedEnd <= data.count,
              compressedStart <= compressedEnd else {
            throw GameBase64MetadataImportError.invalidZIPArchive(url.lastPathComponent)
        }

        let compressedData = data.subdata(in: compressedStart..<compressedEnd)
        let outputData: Data
        switch entry.compressionMethod {
        case 0:
            outputData = compressedData
        case 8:
            outputData = try Self.inflateRaw(compressedData,
                                             uncompressedSize: Int(entry.uncompressedSize),
                                             filename: filename)
        default:
            throw GameBase64MetadataImportError.unsupportedZIPCompression(filename)
        }

        guard outputData.count == Int(entry.uncompressedSize) else {
            throw GameBase64MetadataImportError.corruptZIPEntry(filename)
        }

        let checksum = outputData.withUnsafeBytes { buffer -> UInt32 in
            guard let baseAddress = buffer.bindMemory(to: Bytef.self).baseAddress else {
                return UInt32(crc32(0, nil, 0))
            }

            return UInt32(crc32(0, baseAddress, uInt(outputData.count)))
        }
        guard checksum == entry.crc32 else {
            throw GameBase64MetadataImportError.corruptZIPEntry(filename)
        }

        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try outputData.write(to: destinationURL, options: .atomic)
    }

    private static func readEntries(from data: Data,
                                    archiveFilename: String) throws -> [Entry] {
        guard let endRecordOffset = findEndOfCentralDirectory(in: data) else {
            throw GameBase64MetadataImportError.invalidZIPArchive(archiveFilename)
        }

        let entryCount = Int(try data.uint16LE(at: endRecordOffset + 10))
        let centralDirectoryOffset = Int(try data.uint32LE(at: endRecordOffset + 16))
        guard centralDirectoryOffset >= 0,
              centralDirectoryOffset < data.count else {
            throw GameBase64MetadataImportError.invalidZIPArchive(archiveFilename)
        }

        var entries: [Entry] = []
        var offset = centralDirectoryOffset
        for _ in 0..<entryCount {
            guard try data.uint32LE(at: offset) == 0x02014b50 else {
                throw GameBase64MetadataImportError.invalidZIPArchive(archiveFilename)
            }

            let flags = try data.uint16LE(at: offset + 8)
            let method = try data.uint16LE(at: offset + 10)
            let checksum = try data.uint32LE(at: offset + 16)
            let compressedSize = try data.uint32LE(at: offset + 20)
            let uncompressedSize = try data.uint32LE(at: offset + 24)
            let nameLength = Int(try data.uint16LE(at: offset + 28))
            let extraLength = Int(try data.uint16LE(at: offset + 30))
            let commentLength = Int(try data.uint16LE(at: offset + 32))
            let localHeaderOffset = try data.uint32LE(at: offset + 42)
            let nameStart = offset + 46
            let nameEnd = nameStart + nameLength
            guard nameEnd <= data.count else {
                throw GameBase64MetadataImportError.invalidZIPArchive(archiveFilename)
            }

            guard compressedSize != UInt32.max,
                  uncompressedSize != UInt32.max,
                  localHeaderOffset != UInt32.max else {
                throw GameBase64MetadataImportError.unsupportedZIPCompression(archiveFilename)
            }

            let nameData = data.subdata(in: nameStart..<nameEnd)
            let filename = String(data: nameData, encoding: .utf8)
                ?? String(data: nameData, encoding: .isoLatin1)
                ?? ""

            if !filename.isEmpty,
               !filename.hasSuffix("/") {
                entries.append(Entry(filename: filename,
                                     generalPurposeFlags: flags,
                                     compressionMethod: method,
                                     crc32: checksum,
                                     compressedSize: compressedSize,
                                     uncompressedSize: uncompressedSize,
                                     localHeaderOffset: localHeaderOffset))
            }

            offset = nameEnd + extraLength + commentLength
            guard offset <= data.count else {
                throw GameBase64MetadataImportError.invalidZIPArchive(archiveFilename)
            }
        }

        return entries
    }

    private static func findEndOfCentralDirectory(in data: Data) -> Int? {
        guard data.count >= 22 else {
            return nil
        }

        let minimumOffset = max(0, data.count - 65_557)
        var offset = data.count - 22
        while offset >= minimumOffset {
            if (try? data.uint32LE(at: offset)) == 0x06054b50 {
                return offset
            }
            offset -= 1
        }

        return nil
    }

    private static func inflateRaw(_ data: Data,
                                   uncompressedSize: Int,
                                   filename: String) throws -> Data {
        var stream = z_stream()
        let version = String(cString: zlibVersion())
        let initStatus = inflateInit2_(&stream,
                                       -MAX_WBITS,
                                       version,
                                       Int32(MemoryLayout<z_stream>.size))
        guard initStatus == Z_OK else {
            throw GameBase64MetadataImportError.corruptZIPEntry(filename)
        }
        defer { inflateEnd(&stream) }

        // Guard against a corrupt/malicious central-directory size forcing a
        // huge up-front allocation before any inflate or CRC validation.
        guard uncompressedSize <= 512 * 1024 * 1024 else {
            throw GameBase64MetadataImportError.corruptZIPEntry(filename)
        }

        var outputData = Data(count: uncompressedSize)
        let outputCapacity = outputData.count
        let result = data.withUnsafeBytes { sourceBuffer -> Int32 in
            outputData.withUnsafeMutableBytes { outputBuffer -> Int32 in
                guard let sourceBaseAddress = sourceBuffer.bindMemory(to: Bytef.self).baseAddress,
                      let outputBaseAddress = outputBuffer.bindMemory(to: Bytef.self).baseAddress else {
                    return Z_DATA_ERROR
                }

                stream.next_in = UnsafeMutablePointer<Bytef>(mutating: sourceBaseAddress)
                stream.avail_in = uInt(data.count)
                stream.next_out = outputBaseAddress
                stream.avail_out = uInt(outputCapacity)
                return inflate(&stream, Z_FINISH)
            }
        }

        guard result == Z_STREAM_END else {
            throw GameBase64MetadataImportError.corruptZIPEntry(filename)
        }

        return Data(outputData.prefix(Int(stream.total_out)))
    }
}

private extension String {
    var pathExtension: String {
        (self as NSString).pathExtension
    }

    var lastPathComponent: String {
        (self as NSString).lastPathComponent
    }
}

private extension Data {
    func uint16LE(at offset: Int) throws -> UInt16 {
        guard offset >= 0,
              offset + 2 <= count else {
            throw GameBase64MetadataImportError.invalidZIPArchive("ZIP archive")
        }

        return withUnsafeBytes { buffer in
            let bytes = buffer.bindMemory(to: UInt8.self)
            return UInt16(bytes[offset])
                | (UInt16(bytes[offset + 1]) << 8)
        }
    }

    func uint32LE(at offset: Int) throws -> UInt32 {
        guard offset >= 0,
              offset + 4 <= count else {
            throw GameBase64MetadataImportError.invalidZIPArchive("ZIP archive")
        }

        return withUnsafeBytes { buffer in
            let bytes = buffer.bindMemory(to: UInt8.self)
            return UInt32(bytes[offset])
                | (UInt32(bytes[offset + 1]) << 8)
                | (UInt32(bytes[offset + 2]) << 16)
                | (UInt32(bytes[offset + 3]) << 24)
        }
    }
}
