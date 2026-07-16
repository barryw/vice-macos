import Foundation

enum DiskImageFilesystemKind: String, Equatable {
    case cbmDOS = "CBM DOS"
    case cpm = "CP/M"
}

enum DiskImageServiceError: Error, LocalizedError, Equatable {
    case unsupportedOperation(String)
    case incompatibleEntry

    var errorDescription: String? {
        switch self {
        case .unsupportedOperation(let message):
            return message
        case .incompatibleEntry:
            return "That file entry does not belong to this disk image."
        }
    }
}

enum DiskImageDirectoryEntry: Identifiable, Equatable {
    case commodore(CommodoreDiskDirectoryEntry)
    case cpm(CPMDirectoryEntry)

    var id: String {
        switch self {
        case .commodore(let entry):
            return "cbm:\(entry.id)"
        case .cpm(let entry):
            return "cpm:\(entry.id)"
        }
    }

    var name: String {
        switch self {
        case .commodore(let entry):
            return entry.name
        case .cpm(let entry):
            return entry.displayName
        }
    }

    var typeText: String {
        switch self {
        case .commodore(let entry):
            return entry.typeText
        case .cpm(let entry):
            return entry.typeText
        }
    }

    var startAddress: CommodoreDiskAddress? {
        switch self {
        case .commodore(let entry):
            return entry.start
        case .cpm(let entry):
            return entry.startAddress
        }
    }

    var startText: String {
        guard let startAddress else {
            return "-"
        }

        return "\(startAddress.track):\(startAddress.sector)"
    }

    var blocks: Int {
        switch self {
        case .commodore(let entry):
            return entry.blocks
        case .cpm(let entry):
            return entry.blocks
        }
    }

    var isLocked: Bool {
        switch self {
        case .commodore(let entry):
            return entry.isLocked
        case .cpm(let entry):
            return entry.isReadOnly
        }
    }

    var statusBadges: [DiskImageDirectoryEntryBadge] {
        switch self {
        case .commodore(let entry):
            var badges: [DiskImageDirectoryEntryBadge] = []
            if !entry.isClosed {
                badges.append(.open)
            }
            if entry.isLocked {
                badges.append(.locked)
            }
            return badges
        case .cpm(let entry):
            var badges: [DiskImageDirectoryEntryBadge] = []
            if entry.isReadOnly {
                badges.append(.readOnly)
            }
            if entry.isSystem {
                badges.append(.system)
            }
            if entry.isArchived {
                badges.append(.archived)
            }
            return badges
        }
    }

    var exportFilename: String {
        switch self {
        case .commodore(let entry):
            let stem = DiskImageFilename.safe(entry.name)
            return "\(stem).\(entry.type.rawValue.lowercased())"
        case .cpm(let entry):
            return DiskImageFilename.safe(entry.hostFilename)
        }
    }

    var iconSystemName: String {
        switch self {
        case .commodore(let entry):
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
        case .cpm(let entry):
            switch entry.fileExtension.uppercased() {
            case "COM", "SUB":
                return "terminal"
            case "BAS", "ASM", "MAC", "H", "C":
                return "curlybraces"
            case "TXT", "DOC", "HLP", "ASC":
                return "doc.text"
            default:
                return "doc"
            }
        }
    }

    func detailText(byteCount: Int?) -> String {
        let bytes = byteCount.map {
            ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file)
        } ?? "unknown size"

        switch self {
        case .commodore(let entry):
            let lock = entry.isLocked ? "locked, " : ""
            return "\(entry.typeText), \(lock)\(entry.blocks) blocks, \(bytes), starts T\(entry.start.track):S\(entry.start.sector)"
        case .cpm(let entry):
            let attributes = entry.attributesText
            return "\(attributes), \(entry.records) records, \(entry.allocationBlocks.count) allocation blocks, \(bytes)"
        }
    }
}

enum DiskImageDirectoryEntryBadge: String, Identifiable, Equatable {
    case open = "Open"
    case locked = "Locked"
    case readOnly = "Read-only"
    case system = "System"
    case archived = "Archived"

    var id: String { rawValue }
}

enum DiskImageDocument: Identifiable, Equatable {
    case commodore(CommodoreDiskImage)
    case cpm(CPMDiskImage)

    var id: UUID {
        switch self {
        case .commodore(let image):
            return image.id
        case .cpm(let image):
            return image.id
        }
    }

    var url: URL {
        switch self {
        case .commodore(let image):
            return image.url
        case .cpm(let image):
            return image.url
        }
    }

    var format: CommodoreDiskImageFormat {
        switch self {
        case .commodore(let image):
            return image.format
        case .cpm(let image):
            return image.format
        }
    }

    var filesystemKind: DiskImageFilesystemKind {
        switch self {
        case .commodore:
            return .cbmDOS
        case .cpm:
            return .cpm
        }
    }

    var geometry: CommodoreDiskGeometry {
        switch self {
        case .commodore(let image):
            return image.geometry
        case .cpm(let image):
            return image.geometry
        }
    }

    var displayName: String {
        url.lastPathComponent
    }

    var isModified: Bool {
        switch self {
        case .commodore(let image):
            return image.isModified
        case .cpm(let image):
            return image.isModified
        }
    }

    var supportsFileWrites: Bool {
        switch self {
        case .commodore(let image):
            return image.geometry.supportsFileWrites
        case .cpm:
            return true
        }
    }

    var supportsOptimizedClone: Bool {
        switch self {
        case .commodore(let image):
            return image.geometry.supportsFileWrites
        case .cpm:
            return false
        }
    }

    var geosStatus: GEOSDiskStatus? {
        switch self {
        case .commodore(let image):
            return image.geosStatus
        case .cpm:
            return nil
        }
    }

    var supportsSectorWrites: Bool {
        true
    }

    var summaryText: String {
        switch self {
        case .commodore(let image):
            let header = image.header
            let free = header.blocksFree.map { "\($0) blocks free" } ?? "free map unavailable"
            return "\(image.format.title) - \(header.name.isEmpty ? "Untitled" : header.name) - \(header.id) - \(free)"
        case .cpm(let image):
            return "\(image.format.title) - \(image.variant.title) - \(image.entries.count) files - \(image.freeKilobytes) KB free"
        }
    }

    var usedFraction: Double? {
        switch self {
        case .commodore(let image):
            guard let freeBlocks = image.header.blocksFree,
                  image.geometry.totalSectors > 0 else {
                return nil
            }

            return max(0, min(1, Double(image.geometry.totalSectors - freeBlocks) / Double(image.geometry.totalSectors)))
        case .cpm(let image):
            guard image.variant.dpb.allocationBlockCount > 0 else {
                return nil
            }

            return max(0, min(1, Double(image.usedAllocationBlockCount) / Double(image.variant.dpb.allocationBlockCount)))
        }
    }

    var defaultSelectedAddress: CommodoreDiskAddress {
        switch self {
        case .commodore(let image):
            return image.geometry.directoryStart
        case .cpm(let image):
            return image.directoryStartAddress ?? image.geometry.headerAddress
        }
    }

    func directoryEntries() throws -> [DiskImageDirectoryEntry] {
        switch self {
        case .commodore(let image):
            return try image.directoryEntries().map(DiskImageDirectoryEntry.commodore)
        case .cpm(let image):
            return image.directoryEntries().map(DiskImageDirectoryEntry.cpm)
        }
    }

    func fileData(for entry: DiskImageDirectoryEntry) throws -> Data {
        switch (self, entry) {
        case (.commodore(let image), .commodore(let entry)):
            return try image.fileData(for: entry)
        case (.cpm(let image), .cpm(let entry)):
            return try image.fileData(for: entry)
        default:
            throw DiskImageServiceError.incompatibleEntry
        }
    }

    func sectorMap() -> [CommodoreDiskSector] {
        switch self {
        case .commodore(let image):
            return image.sectorMap()
        case .cpm(let image):
            return image.sectorMap()
        }
    }

    func rebuildAnalysis() -> CommodoreDiskRebuildAnalysis {
        switch self {
        case .commodore(let image):
            return image.rebuildAnalysis()
        case .cpm:
            return CommodoreDiskRebuildAnalysis(issues: [
                CommodoreDiskRebuildIssue(severity: .blocked,
                                          title: "CP/M optimized cloning is not implemented yet",
                                          detail: "CP/M images are opened through the filesystem adapter. Directory browsing, export, and raw sector inspection are available; filesystem writes need the CP/M backend next.")
            ])
        }
    }

    func readSector(_ address: CommodoreDiskAddress) throws -> Data {
        switch self {
        case .commodore(let image):
            return try image.readSector(address)
        case .cpm(let image):
            return try image.readSector(address)
        }
    }

    mutating func writeSector(_ bytes: Data, at address: CommodoreDiskAddress) throws {
        switch self {
        case .commodore(var image):
            try image.writeSector(bytes, at: address)
            self = .commodore(image)
        case .cpm(var image):
            try image.writeSector(bytes, at: address)
            self = .cpm(image)
        }
    }

    mutating func save() throws {
        switch self {
        case .commodore(var image):
            try image.save()
            self = .commodore(image)
        case .cpm(var image):
            try image.save()
            self = .cpm(image)
        }
    }

    mutating func copyFile(_ entry: DiskImageDirectoryEntry,
                           from source: DiskImageDocument) throws {
        switch (self, source, entry) {
        case (.commodore(var destination), .commodore(let source), .commodore(let entry)):
            try destination.copyFile(entry, from: source)
            self = .commodore(destination)
        case (.commodore(var destination), _, _):
            let payload = try source.fileData(for: entry)
            try destination.importFile(named: entry.name, payload: payload)
            self = .commodore(destination)
        case (.cpm(var destination), _, _):
            let payload = try source.fileData(for: entry)
            try destination.importFile(named: entry.name, payload: payload)
            self = .cpm(destination)
        }
    }

    mutating func importFile(named name: String, payload: Data) throws {
        switch self {
        case .commodore(var image):
            try image.importFile(named: name, payload: payload)
            self = .commodore(image)
        case .cpm(var image):
            try image.importFile(named: name, payload: payload)
            self = .cpm(image)
        }
    }

    mutating func renameFile(_ entry: DiskImageDirectoryEntry, to name: String) throws {
        switch (self, entry) {
        case (.commodore(var image), .commodore(let entry)):
            try image.renameFile(entry, to: name)
            self = .commodore(image)
        case (.cpm(var image), .cpm(let entry)):
            try image.renameFile(entry, to: name)
            self = .cpm(image)
        default:
            throw DiskImageServiceError.incompatibleEntry
        }
    }

    mutating func deleteFile(_ entry: DiskImageDirectoryEntry) throws {
        switch (self, entry) {
        case (.commodore(var image), .commodore(let entry)):
            try image.deleteFile(entry)
            self = .commodore(image)
        case (.cpm(var image), .cpm(let entry)):
            try image.deleteFile(entry)
            self = .cpm(image)
        default:
            throw DiskImageServiceError.incompatibleEntry
        }
    }

    mutating func makeGEOS1351Default() throws {
        switch self {
        case .commodore(var image):
            try image.makeGEOS1351Default()
            self = .commodore(image)
        case .cpm:
            throw DiskImageServiceError.unsupportedOperation("GEOS input-driver changes are only available for CBM DOS images.")
        }
    }

    mutating func installGEOSPackage(_ package: GEOSCVTFile) throws {
        switch self {
        case .commodore(var image):
            try image.installGEOSPackage(package)
            self = .commodore(image)
        case .cpm:
            throw DiskImageServiceError.unsupportedOperation("GEOS packages can only be installed on CBM DOS images.")
        }
    }

    func cloneOptimized(to destinationURL: URL) throws -> DiskImageDocument {
        switch self {
        case .commodore(let image):
            return .commodore(try image.cloneOptimized(to: destinationURL))
        case .cpm:
            throw DiskImageServiceError.unsupportedOperation("Optimized cloning is not implemented for CP/M images yet.")
        }
    }
}

enum DiskImageService {
    static func openImage(url: URL) throws -> DiskImageDocument {
        if let cpmImage = try? CPMDiskImage(url: url) {
            return .cpm(cpmImage)
        }

        return .commodore(try CommodoreDiskImage(url: url))
    }

    static func createBlankImage(at url: URL,
                                 format: CommodoreDiskImageFormat,
                                 diskName: String,
                                 diskID: String) throws -> DiskImageDocument {
        .commodore(try CommodoreDiskImage(blankImageAt: url,
                                          format: format,
                                          diskName: diskName,
                                          diskID: diskID))
    }
}

enum DiskImageFilename {
    static func safe(_ string: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:")
            .union(.controlCharacters)
        let cleaned = string
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "UNTITLED" : cleaned
    }
}
