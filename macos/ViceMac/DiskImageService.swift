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

enum GEOSPackageIssueSeverity: String, Equatable {
    case info
    case warning
    case error

    var blocksPackaging: Bool {
        self == .error
    }
}

struct GEOSPackageIssue: Identifiable, Equatable {
    var severity: GEOSPackageIssueSeverity
    var title: String
    var detail: String

    var id: String {
        "\(severity.rawValue):\(title):\(detail)"
    }
}

struct GEOSProgramValidation: Equatable {
    var sourceByteCount: Int
    var loadAddress: Int?
    var endAddress: Int?
    var entryAddress: Int?
    var payloadByteCount: Int
    var issues: [GEOSPackageIssue]

    var canPackage: Bool {
        !issues.contains { $0.severity.blocksPackaging }
    }

    var loadRangeText: String {
        guard let loadAddress,
              let endAddress else {
            return "-"
        }

        return "\(Self.hex(loadAddress))-\(Self.hex(endAddress))"
    }

    var entryAddressText: String {
        guard let entryAddress else {
            return "-"
        }

        return Self.hex(entryAddress)
    }

    static func hex(_ value: Int) -> String {
        String(format: "$%04X", value)
    }
}

enum GEOSProgramValidator {
    static let recommendedLoadAddress = 0x0400
    static let maximumGEOSPayloadEndExclusive = 0x8000

    static func validatePRG(_ data: Data?, entryAddressText: String = "") -> GEOSProgramValidation {
        let sourceByteCount = data?.count ?? 0
        var issues: [GEOSPackageIssue] = []

        guard let data else {
            return GEOSProgramValidation(sourceByteCount: 0,
                                         loadAddress: nil,
                                         endAddress: nil,
                                         entryAddress: nil,
                                         payloadByteCount: 0,
                                         issues: [
                                             GEOSPackageIssue(severity: .error,
                                                              title: "Choose a PRG",
                                                              detail: "Use a linked Commodore PRG payload. Raw object files still need a linker.")
                                         ])
        }

        guard data.count >= 2 else {
            return GEOSProgramValidation(sourceByteCount: sourceByteCount,
                                         loadAddress: nil,
                                         endAddress: nil,
                                         entryAddress: nil,
                                         payloadByteCount: 0,
                                         issues: [
                                             GEOSPackageIssue(severity: .error,
                                                              title: "Missing load address",
                                                              detail: "A PRG must begin with a two-byte little-endian load address.")
                                         ])
        }

        let loadAddress = Int(data[0]) | (Int(data[1]) << 8)
        let payloadByteCount = data.count - 2
        let endExclusive = loadAddress + payloadByteCount
        let endAddress = payloadByteCount > 0 ? endExclusive - 1 : nil

        if payloadByteCount == 0 {
            issues.append(GEOSPackageIssue(severity: .error,
                                           title: "Empty payload",
                                           detail: "The PRG has a load address but no program bytes."))
        }

        if endExclusive > 0x1_0000 {
            issues.append(GEOSPackageIssue(severity: .error,
                                           title: "Address range wraps",
                                           detail: "The payload extends past \(GEOSProgramValidation.hex(0xffff))."))
        }

        if loadAddress < recommendedLoadAddress {
            issues.append(GEOSPackageIssue(severity: .error,
                                           title: "Load address too low",
                                           detail: "GEOS payloads should load at or above \(GEOSProgramValidation.hex(recommendedLoadAddress))."))
        } else if loadAddress != recommendedLoadAddress {
            issues.append(GEOSPackageIssue(severity: .warning,
                                           title: "Unusual GEOS load address",
                                           detail: "cc65 GEOS payloads normally load at \(GEOSProgramValidation.hex(recommendedLoadAddress)); verify this was intentional."))
        }

        if endExclusive > maximumGEOSPayloadEndExclusive {
            issues.append(GEOSPackageIssue(severity: .error,
                                           title: "Payload overlaps GEOS workspace",
                                           detail: "Keep sequential GEOS payloads below \(GEOSProgramValidation.hex(maximumGEOSPayloadEndExclusive - 1))."))
        }

        let trimmedEntry = entryAddressText.trimmingCharacters(in: .whitespacesAndNewlines)
        let entryAddress: Int?
        if trimmedEntry.isEmpty {
            entryAddress = loadAddress
        } else if let parsed = parseAddress(trimmedEntry) {
            entryAddress = parsed
        } else {
            entryAddress = nil
            issues.append(GEOSPackageIssue(severity: .error,
                                           title: "Invalid entry address",
                                           detail: "Use a 16-bit hex address such as $0400."))
        }

        if let entryAddress {
            if entryAddress < loadAddress || entryAddress >= endExclusive {
                issues.append(GEOSPackageIssue(severity: .error,
                                               title: "Entry outside payload",
                                               detail: "The entry address must be inside the loaded PRG range."))
            }
        }

        if payloadByteCount > 0,
           data.dropFirst(2).allSatisfy({ $0 == 0 }) {
            issues.append(GEOSPackageIssue(severity: .warning,
                                           title: "Payload is all zeroes",
                                           detail: "This does not look like executable code."))
        }

        if issues.isEmpty {
            issues.append(GEOSPackageIssue(severity: .info,
                                           title: "PRG looks packageable",
                                           detail: "The load range and entry address are coherent."))
        }

        return GEOSProgramValidation(sourceByteCount: sourceByteCount,
                                     loadAddress: loadAddress,
                                     endAddress: endAddress,
                                     entryAddress: entryAddress,
                                     payloadByteCount: payloadByteCount,
                                     issues: issues)
    }

    static func parseAddress(_ text: String) -> Int? {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("$") {
            trimmed.removeFirst()
        } else if trimmed.lowercased().hasPrefix("0x") {
            trimmed.removeFirst(2)
        }

        guard !trimmed.isEmpty,
              trimmed.count <= 4,
              trimmed.unicodeScalars.allSatisfy({ CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0) }),
              let value = Int(trimmed, radix: 16),
              value >= 0,
              value <= 0xffff else {
            return nil
        }

        return value
    }
}

enum GEOSProgramKind: String, CaseIterable, Identifiable, Equatable {
    case application
    case autoExec

    var id: String { rawValue }

    var title: String {
        switch self {
        case .application:
            return "Application"
        case .autoExec:
            return "Auto-exec"
        }
    }

    var grcToken: String {
        switch self {
        case .application:
            return "APPLICATION"
        case .autoExec:
            return "AUTO_EXEC"
        }
    }

    var geosFileType: UInt8 {
        switch self {
        case .application:
            return 6
        case .autoExec:
            return 14
        }
    }
}

enum GEOSProgramDOSType: String, CaseIterable, Identifiable, Equatable {
    case seq
    case prg
    case usr

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }
    var grcToken: String { title }

    var cbmDirectoryType: CommodoreDiskDirectoryEntry.FileType {
        switch self {
        case .seq:
            return .seq
        case .prg:
            return .prg
        case .usr:
            return .usr
        }
    }

    var closedDirectoryByte: UInt8 {
        cbmDirectoryType.directoryBits | 0x80
    }
}

enum GEOSProgramMode: String, CaseIterable, Identifiable, Equatable {
    case any
    case fortyOnly
    case eightyOnly
    case c64Only

    var id: String { rawValue }

    var title: String {
        switch self {
        case .any:
            return "Any GEOS"
        case .fortyOnly:
            return "40-column"
        case .eightyOnly:
            return "80-column"
        case .c64Only:
            return "C64 only"
        }
    }

    var grcToken: String {
        switch self {
        case .any:
            return "any"
        case .fortyOnly:
            return "40only"
        case .eightyOnly:
            return "80only"
        case .c64Only:
            return "c64only"
        }
    }

    var geosModeByte: UInt8 {
        switch self {
        case .any:
            return 0x40
        case .fortyOnly:
            return 0x00
        case .eightyOnly:
            return 0xc0
        case .c64Only:
            return 0x80
        }
    }
}

struct GEOSProgramMetadata: Equatable {
    var kind: GEOSProgramKind = .autoExec
    var dosName = "MACVICE RTC"
    var className = "MacVICE RTC"
    var version = "V1.0"
    var author = "mac VICE"
    var info = "Synchronizes GEOS with the VICE DS1307 real-time clock."
    var dosType: GEOSProgramDOSType = .usr
    var mode: GEOSProgramMode = .any

    var validationIssues: [GEOSPackageIssue] {
        var issues: [GEOSPackageIssue] = []
        validateGRCString(dosName,
                          fieldName: "DOS name",
                          maximumLength: 16,
                          into: &issues)
        validateGRCString(className,
                          fieldName: "Class name",
                          maximumLength: 12,
                          into: &issues)
        validateGRCString(version,
                          fieldName: "Version",
                          maximumLength: 4,
                          into: &issues)
        validateGRCString(author,
                          fieldName: "Author",
                          maximumLength: 62,
                          into: &issues)
        validateGRCString(info,
                          fieldName: "Info",
                          maximumLength: 95,
                          into: &issues)

        if issues.isEmpty {
            issues.append(GEOSPackageIssue(severity: .info,
                                           title: "GRC metadata is valid",
                                           detail: "The generated header fits GEOS and grc65 field limits."))
        }

        return issues
    }

    var canGenerate: Bool {
        !validationIssues.contains { $0.severity.blocksPackaging }
    }

    var normalizedDOSName: String {
        normalized(dosName)
    }

    var normalizedClassName: String {
        normalized(className)
    }

    var normalizedVersion: String {
        normalized(version)
    }

    var normalizedAuthor: String {
        normalized(author)
    }

    var normalizedInfo: String {
        normalized(info)
    }

    var generatedGRC: String {
        let lines = [
            "HEADER \(kind.grcToken) \"\(normalizedDOSName)\" \"\(normalizedClassName)\" \"\(normalizedVersion)\" {",
            "dostype \(dosType.grcToken)",
            "mode \(mode.grcToken)",
            "structure SEQ",
            "author \"\(normalizedAuthor)\"",
            "info \"\(normalizedInfo)\"",
            "}"
        ]

        return lines.joined(separator: "\n") + "\n"
    }

    mutating func applySuggestedName(from url: URL) {
        let stem = url.deletingPathExtension().lastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !stem.isEmpty else {
            return
        }

        let dos = Self.safeASCII(stem, maximumLength: 16)
        let klass = Self.safeASCII(stem, maximumLength: 12)
        if dosName == Self().dosName {
            dosName = dos
        }
        if className == Self().className {
            className = klass
        }
    }

    private func validateGRCString(_ value: String,
                                   fieldName: String,
                                   maximumLength: Int,
                                   into issues: inout [GEOSPackageIssue]) {
        let trimmed = normalized(value)
        guard !trimmed.isEmpty else {
            issues.append(GEOSPackageIssue(severity: .error,
                                           title: "\(fieldName) is required",
                                           detail: "GEOS headers cannot store an empty \(fieldName.lowercased())."))
            return
        }

        guard trimmed.count <= maximumLength else {
            issues.append(GEOSPackageIssue(severity: .error,
                                           title: "\(fieldName) is too long",
                                           detail: "Keep it to \(maximumLength) characters or fewer."))
            return
        }

        let quote = UInt32(UInt8(ascii: "\""))
        let backslash = UInt32(UInt8(ascii: "\\"))
        let invalid = trimmed.unicodeScalars.first { scalar in
            scalar.value < 0x20 || scalar.value > 0x7e || scalar.value == quote || scalar.value == backslash
        }
        if invalid != nil {
            issues.append(GEOSPackageIssue(severity: .error,
                                           title: "\(fieldName) has unsupported characters",
                                           detail: "Use printable ASCII without quotes or backslashes."))
        }
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func safeASCII(_ value: String, maximumLength: Int) -> String {
        let scalars = value.unicodeScalars.compactMap { scalar -> UInt8? in
            let quote = UInt32(UInt8(ascii: "\""))
            let backslash = UInt32(UInt8(ascii: "\\"))
            guard scalar.value >= 0x20,
                  scalar.value <= 0x7e,
                  scalar.value != quote,
                  scalar.value != backslash else {
                return nil
            }
            return UInt8(scalar.value)
        }
        let text = String(bytes: scalars.prefix(maximumLength), encoding: .ascii) ?? ""
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "GEOS FILE" : text
    }
}

struct GEOSFileTimestamp: Equatable {
    var year: UInt8
    var month: UInt8
    var day: UInt8
    var hour: UInt8
    var minute: UInt8

    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        year = UInt8((components.year ?? 0) % 100)
        month = UInt8(max(1, min(12, components.month ?? 1)))
        day = UInt8(max(1, min(31, components.day ?? 1)))
        hour = UInt8(max(0, min(23, components.hour ?? 0)))
        minute = UInt8(max(0, min(59, components.minute ?? 0)))
    }

    init(year: UInt8, month: UInt8, day: UInt8, hour: UInt8, minute: UInt8) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
    }
}

struct GEOSCVTFile: Equatable {
    static let recordSize = 254
    static let magic = "PRG formatted GEOS file V1.0"

    var metadata: GEOSProgramMetadata
    var validation: GEOSProgramValidation
    var timestamp: GEOSFileTimestamp
    var directoryRecord: Data
    var fileInfoRecord: Data
    var programPayload: Data

    var data: Data {
        var output = Data()
        output.append(directoryRecord)
        output.append(fileInfoRecord)
        output.append(Self.paddedRecords(for: programPayload))
        return output
    }

    var diskName: String {
        metadata.normalizedDOSName
    }

    static func paddedRecords(for payload: Data) -> Data {
        var output = payload
        let remainder = output.count % recordSize
        if remainder != 0 {
            output.append(Data(repeating: 0, count: recordSize - remainder))
        }
        return output
    }
}

enum GEOSPackageBuilder {
    static func buildCVT(prgData: Data?,
                         entryAddressText: String = "",
                         metadata: GEOSProgramMetadata,
                         timestamp: GEOSFileTimestamp = GEOSFileTimestamp(date: Date())) throws -> GEOSCVTFile {
        let validation = GEOSProgramValidator.validatePRG(prgData, entryAddressText: entryAddressText)
        let issues = validation.issues + metadata.validationIssues
        let blockingIssues = issues.filter { $0.severity.blocksPackaging }
        guard blockingIssues.isEmpty else {
            throw CommodoreDiskImageError.rebuildBlocked(blockingIssues.map(\.title))
        }

        guard let prgData,
              prgData.count >= 2,
              let loadAddress = validation.loadAddress,
              let entryAddress = validation.entryAddress else {
            throw CommodoreDiskImageError.invalidImage("A linked PRG with a load address is required.")
        }

        let payload = prgData.subdata(in: 2..<prgData.count)
        let endAddress = loadAddress + payload.count - 1
        let directoryRecord = makeDirectoryRecord(metadata: metadata, timestamp: timestamp)
        let fileInfoRecord = makeFileInfoRecord(metadata: metadata,
                                                loadAddress: loadAddress,
                                                endAddress: endAddress,
                                                entryAddress: entryAddress)

        return GEOSCVTFile(metadata: metadata,
                           validation: validation,
                           timestamp: timestamp,
                           directoryRecord: directoryRecord,
                           fileInfoRecord: fileInfoRecord,
                           programPayload: payload)
    }

    private static func makeDirectoryRecord(metadata: GEOSProgramMetadata,
                                            timestamp: GEOSFileTimestamp) -> Data {
        var record = Data(repeating: 0, count: GEOSCVTFile.recordSize)
        record[0] = metadata.dosType.closedDirectoryByte
        writePETSCIIName(metadata.normalizedDOSName, into: &record, range: 3..<19)
        record[21] = 0
        record[22] = metadata.kind.geosFileType
        record[23] = timestamp.year
        record[24] = timestamp.month
        record[25] = timestamp.day
        record[26] = timestamp.hour
        record[27] = timestamp.minute

        let magic = Array(GEOSCVTFile.magic.utf8)
        for (index, byte) in magic.enumerated() where 30 + index < record.count {
            record[30 + index] = byte
        }
        return record
    }

    private static func makeFileInfoRecord(metadata: GEOSProgramMetadata,
                                           loadAddress: Int,
                                           endAddress: Int,
                                           entryAddress: Int) -> Data {
        var record = Data(repeating: 0, count: GEOSCVTFile.recordSize)
        record[0] = 3
        record[1] = 21
        record[2] = 63 | 0x80
        record[66] = metadata.dosType.closedDirectoryByte
        record[67] = metadata.kind.geosFileType
        record[68] = 0
        writeWord(loadAddress, into: &record, at: 69)
        writeWord(endAddress, into: &record, at: 71)
        writeWord(entryAddress, into: &record, at: 73)
        writeASCII(metadata.normalizedClassName, into: &record, range: 75..<87, pad: 0x20)
        writeASCII(metadata.normalizedVersion, into: &record, range: 87..<91, pad: 0x00)
        record[94] = metadata.mode.geosModeByte
        writeNullTerminatedASCII(metadata.normalizedAuthor, into: &record, range: 95..<158)
        writeNullTerminatedASCII(metadata.normalizedInfo, into: &record, range: 158..<254)
        return record
    }

    private static func writeWord(_ value: Int, into data: inout Data, at offset: Int) {
        data[offset] = UInt8(value & 0xff)
        data[offset + 1] = UInt8((value >> 8) & 0xff)
    }

    private static func writeASCII(_ text: String, into data: inout Data, range: Range<Int>, pad: UInt8) {
        let bytes = Array(text.utf8)
        for (position, index) in range.enumerated() {
            data[index] = position < bytes.count ? bytes[position] : pad
        }
    }

    private static func writeNullTerminatedASCII(_ text: String, into data: inout Data, range: Range<Int>) {
        let bytes = Array(text.utf8)
        for (position, index) in range.enumerated() {
            if position < bytes.count {
                data[index] = bytes[position]
            } else if position == bytes.count {
                data[index] = 0
            } else {
                data[index] = 0
            }
        }
    }

    private static func writePETSCIIName(_ text: String, into data: inout Data, range: Range<Int>) {
        let bytes = CommodorePETSCII.encodeFilename(text)
        for (position, index) in range.enumerated() {
            data[index] = position < bytes.count ? bytes[position] : 0xa0
        }
    }
}

struct CPMDirectoryEntry: Identifiable, Equatable {
    var id: String
    var user: Int
    var fileName: String
    var fileExtension: String
    var records: Int
    var allocationBlocks: [Int]
    var directorySlots: [Int]
    var isReadOnly: Bool
    var isSystem: Bool
    var isArchived: Bool
    var startAddress: CommodoreDiskAddress?

    var displayName: String {
        fileExtension.isEmpty ? fileName : "\(fileName).\(fileExtension)"
    }

    var hostFilename: String {
        displayName
    }

    var typeText: String {
        fileExtension.isEmpty ? "CP/M" : fileExtension
    }

    var byteCount: Int {
        records * 128
    }

    var blocks: Int {
        allocationBlocks.count
    }

    var attributesText: String {
        var attributes = [isSystem ? "Sys" : "Dir", isReadOnly ? "RO" : "RW"]
        if isArchived {
            attributes.append("A")
        }
        return attributes.joined(separator: " ")
    }

    func matches(_ name: CPMDirectoryName) -> Bool {
        user == name.user
            && fileName.caseInsensitiveCompare(name.fileName) == .orderedSame
            && fileExtension.caseInsensitiveCompare(name.fileExtension) == .orderedSame
    }
}

struct CPMDirectoryName: Equatable {
    var user: Int
    var fileName: String
    var fileExtension: String
    var nameBytes: [UInt8]
    var extensionBytes: [UInt8]

    var displayName: String {
        fileExtension.isEmpty ? fileName : "\(fileName).\(fileExtension)"
    }

    init(_ rawValue: String, defaultUser: Int = 0) throws {
        var text = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        var user = defaultUser

        if let colon = text.firstIndex(of: ":") {
            let prefix = String(text[..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
            text = String(text[text.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if prefix.count == 1,
               let scalar = prefix.uppercased().unicodeScalars.first,
               scalar.value >= UInt32(UInt8(ascii: "A")),
               scalar.value <= UInt32(UInt8(ascii: "P")) {
                user = Int(scalar.value - UInt32(UInt8(ascii: "A")))
            } else if let parsed = Int(prefix),
                      parsed >= 0,
                      parsed <= 15 {
                user = parsed
            } else {
                throw CommodoreDiskImageError.invalidFileName(rawValue)
            }
        }

        guard user >= 0,
              user <= 15,
              !text.isEmpty else {
            throw CommodoreDiskImageError.invalidFileName(rawValue)
        }

        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count <= 2,
              let stem = parts.first,
              !stem.isEmpty else {
            throw CommodoreDiskImageError.invalidFileName(rawValue)
        }

        let extensionPart = parts.count == 2 ? String(parts[1]) : ""
        let normalizedStem = String(stem).uppercased()
        let normalizedExtension = extensionPart.uppercased()
        guard normalizedStem.count <= 8,
              normalizedExtension.count <= 3,
              Self.isValidComponent(normalizedStem),
              Self.isValidComponent(normalizedExtension) else {
            throw CommodoreDiskImageError.invalidFileName(rawValue)
        }

        self.user = user
        fileName = normalizedStem
        fileExtension = normalizedExtension
        nameBytes = Self.paddedBytes(normalizedStem, count: 8)
        extensionBytes = Self.paddedBytes(normalizedExtension, count: 3)
    }

    private static func isValidComponent(_ string: String) -> Bool {
        string.unicodeScalars.allSatisfy { scalar in
            guard scalar.isASCII,
                  let value = UInt8(exactly: scalar.value),
                  value > 0x20 else {
                return false
            }

            return ![0x3c, 0x3e, 0x2e, 0x3b, 0x3a, 0x3d, 0x3f, 0x2a, 0x5f].contains(value)
        }
    }

    private static func paddedBytes(_ string: String, count: Int) -> [UInt8] {
        var bytes = Array(string.utf8.prefix(count))
        while bytes.count < count {
            bytes.append(0x20)
        }
        return bytes
    }
}

struct CPMDiskImage: Identifiable, Equatable {
    let id = UUID()
    var url: URL
    var format: CommodoreDiskImageFormat
    var geometry: CommodoreDiskGeometry
    var variant: CPMDiskVariant
    private(set) var data: Data
    private(set) var entries: [CPMDirectoryEntry]
    private(set) var isModified = false

    init(url: URL) throws {
        guard let format = CommodoreDiskImageFormat(url: url),
              [.d64, .d71].contains(format) else {
            throw CommodoreDiskImageError.unsupportedFormat(url.pathExtension.uppercased())
        }

        let loadedData = try Data(contentsOf: url)
        let geometry = try CommodoreDiskGeometry(format: format, fileSize: loadedData.count)
        guard loadedData.count >= geometry.dataByteCount else {
            throw CommodoreDiskImageError.invalidImage("The image is shorter than its declared geometry.")
        }

        let variant = try CPMDiskVariant.detect(in: loadedData,
                                                format: format,
                                                geometry: geometry)
        let entries = try Self.parseDirectory(data: loadedData,
                                              geometry: geometry,
                                              variant: variant)
        guard !entries.isEmpty else {
            throw CommodoreDiskImageError.invalidImage("No CP/M directory entries were found.")
        }

        self.url = url
        self.format = format
        self.geometry = geometry
        self.variant = variant
        data = loadedData
        self.entries = entries
    }

    var freeKilobytes: Int {
        max(0, (variant.dpb.allocationBlockCount - usedAllocationBlockCount) * variant.dpb.logicalBlockRecords / 8)
    }

    var usedAllocationBlockCount: Int {
        Set(entries.flatMap(\.allocationBlocks)).count + directoryBlockCount
    }

    var directoryStartAddress: CommodoreDiskAddress? {
        addresses(forCPMBlock: 0).first
    }

    func directoryEntries() -> [CPMDirectoryEntry] {
        entries
    }

    func fileData(for entry: CPMDirectoryEntry) throws -> Data {
        var output = Data()
        for block in entry.allocationBlocks {
            output.append(try readCPMBlock(block))
        }

        return output.prefixData(entry.byteCount)
    }

    func sectorMap() -> [CommodoreDiskSector] {
        var roles = Dictionary(uniqueKeysWithValues: geometry.allSectors().map { address in
            (address, CommodoreDiskSectorRole.free)
        })

        roles[CommodoreDiskAddress(track: 1, sector: 0)] = .header
        roles[geometry.headerAddress] = .header

        for block in 0..<directoryBlockCount {
            for address in addresses(forCPMBlock: block) {
                roles[address] = .directory
            }
        }

        for entry in entries {
            for block in entry.allocationBlocks {
                for address in addresses(forCPMBlock: block) {
                    roles[address] = .file(entry.displayName)
                }
            }
        }

        return geometry.allSectors().map { address in
            CommodoreDiskSector(address: address, role: roles[address] ?? .unknown)
        }
    }

    func readSector(_ address: CommodoreDiskAddress) throws -> Data {
        let offset = try geometry.offset(for: address)
        guard offset + CommodoreDiskImage.bytesPerSector <= data.count else {
            throw CommodoreDiskImageError.invalidAddress(address)
        }

        return data.subdata(in: offset..<(offset + CommodoreDiskImage.bytesPerSector))
    }

    mutating func writeSector(_ bytes: Data, at address: CommodoreDiskAddress) throws {
        guard bytes.count == CommodoreDiskImage.bytesPerSector else {
            throw CommodoreDiskImageError.invalidSectorLength(bytes.count)
        }

        try writeRawSector(bytes, at: address)
        isModified = true
        entries = try Self.parseDirectory(data: data, geometry: geometry, variant: variant)
    }

    mutating func save() throws {
        try data.write(to: url, options: .atomic)
        isModified = false
    }

    mutating func importFile(named name: String, payload: Data) throws {
        let destination = try CPMDirectoryName(name)
        guard !entries.contains(where: { $0.matches(destination) }) else {
            throw CommodoreDiskImageError.fileExists(destination.displayName)
        }

        let records = payload.isEmpty ? 0 : Int(ceil(Double(payload.count) / 128.0))
        let requiredBlocks = Int(ceil(Double(records) / Double(variant.dpb.logicalBlockRecords)))
        let requiredSlots = max(1, Int(ceil(Double(records) / Double(variant.dpb.maxRecordsPerDirectoryEntry))))

        let allocatedBlocks = try allocateBlocks(count: requiredBlocks)
        let slots = try freeDirectorySlots(count: requiredSlots)

        var filePayload = payload
        let paddedByteCount = records * 128
        if filePayload.count < paddedByteCount {
            filePayload.append(Data(repeating: 0x1a, count: paddedByteCount - filePayload.count))
        }

        for (blockIndex, block) in allocatedBlocks.enumerated() {
            let byteStart = blockIndex * variant.dpb.logicalBlockByteCount
            let byteEnd = min(byteStart + variant.dpb.logicalBlockByteCount, filePayload.count)
            var blockPayload = Data(repeating: 0x1a, count: variant.dpb.logicalBlockByteCount)
            if byteStart < byteEnd {
                blockPayload.replaceSubrange(0..<(byteEnd - byteStart),
                                             with: filePayload.subdata(in: byteStart..<byteEnd))
            }
            try writeCPMBlock(blockPayload, to: block)
        }

        for slotIndex in 0..<requiredSlots {
            let recordStart = slotIndex * variant.dpb.maxRecordsPerDirectoryEntry
            let recordCount = max(0, min(records - recordStart, variant.dpb.maxRecordsPerDirectoryEntry))
            let firstBlock = slotIndex * 16
            let blockCount = min(16, max(0, allocatedBlocks.count - firstBlock))
            let blockRefs = blockCount > 0 ? Array(allocatedBlocks[firstBlock..<(firstBlock + blockCount)]) : []
            let extentBase = slotIndex * variant.dpb.extentsPerDirectoryEntry
            let fcb = CPMFileControlBlock.bytes(user: destination.user,
                                                nameBytes: destination.nameBytes,
                                                extensionBytes: destination.extensionBytes,
                                                extentBase: extentBase,
                                                recordsInEntry: recordCount,
                                                blockReferences: blockRefs,
                                                dpb: variant.dpb)
            try writeDirectorySlot(slots[slotIndex], bytes: fcb)
        }

        isModified = true
        entries = try Self.parseDirectory(data: data, geometry: geometry, variant: variant)
    }

    mutating func renameFile(_ entry: CPMDirectoryEntry, to name: String) throws {
        guard entries.contains(where: { $0.id == entry.id }) else {
            throw CommodoreDiskImageError.fileNotFound(entry.displayName)
        }

        let destination = try CPMDirectoryName(name, defaultUser: entry.user)
        guard !entries.contains(where: { other in
            other.id != entry.id && other.matches(destination)
        }) else {
            throw CommodoreDiskImageError.fileExists(destination.displayName)
        }

        for slot in entry.directorySlots {
            var bytes = try directorySlotBytes(slot)
            bytes[0] = UInt8(destination.user)
            for index in 0..<8 {
                bytes[1 + index] = destination.nameBytes[index]
            }
            for index in 0..<3 {
                bytes[9 + index] = (bytes[9 + index] & 0x80) | destination.extensionBytes[index]
            }
            try writeDirectorySlot(slot, bytes: bytes)
        }

        isModified = true
        entries = try Self.parseDirectory(data: data, geometry: geometry, variant: variant)
    }

    mutating func deleteFile(_ entry: CPMDirectoryEntry) throws {
        guard entries.contains(where: { $0.id == entry.id }) else {
            throw CommodoreDiskImageError.fileNotFound(entry.displayName)
        }

        for slot in entry.directorySlots {
            var bytes = try directorySlotBytes(slot)
            bytes[0] = 0xe5
            try writeDirectorySlot(slot, bytes: bytes)
        }

        isModified = true
        entries = try Self.parseDirectory(data: data, geometry: geometry, variant: variant)
    }

    private var directoryBlockCount: Int {
        Int(ceil(Double(variant.dpb.directoryEntryCount) / Double(4 * variant.dpb.logicalBlockRecords)))
    }

    private func readCPMBlock(_ block: Int) throws -> Data {
        guard block >= 0,
              block < variant.dpb.allocationBlockCount else {
            throw CommodoreDiskImageError.invalidImage("CP/M block \(block) is outside the disk allocation range.")
        }

        var blockData = Data()
        for address in addresses(forCPMBlock: block) {
            blockData.append(try readSector(address))
        }
        return blockData
    }

    private mutating func writeCPMBlock(_ bytes: Data, to block: Int) throws {
        guard bytes.count == variant.dpb.logicalBlockByteCount else {
            throw CommodoreDiskImageError.invalidImage("A CP/M allocation block must contain \(variant.dpb.logicalBlockByteCount) bytes.")
        }

        let addresses = addresses(forCPMBlock: block)
        guard addresses.count == variant.dpb.physicalSectorsPerBlock else {
            throw CommodoreDiskImageError.invalidImage("CP/M block \(block) is outside the disk allocation range.")
        }

        for (index, address) in addresses.enumerated() {
            let start = index * CommodoreDiskImage.bytesPerSector
            try writeRawSector(bytes.subdata(in: start..<(start + CommodoreDiskImage.bytesPerSector)),
                               at: address)
        }
    }

    private mutating func writeRawSector(_ bytes: Data, at address: CommodoreDiskAddress) throws {
        guard bytes.count == CommodoreDiskImage.bytesPerSector else {
            throw CommodoreDiskImageError.invalidSectorLength(bytes.count)
        }

        let offset = try geometry.offset(for: address)
        guard offset + CommodoreDiskImage.bytesPerSector <= data.count else {
            throw CommodoreDiskImageError.invalidAddress(address)
        }

        data.replaceSubrange(offset..<(offset + CommodoreDiskImage.bytesPerSector), with: bytes)
    }

    private func directorySlotBytes(_ slot: Int) throws -> [UInt8] {
        guard let address = directorySlotAddress(slot) else {
            throw CommodoreDiskImageError.invalidImage("CP/M directory slot \(slot) is outside the directory area.")
        }

        let sector = try readSector(address.sector)
        return Array(sector[address.offset..<(address.offset + 32)])
    }

    private mutating func writeDirectorySlot(_ slot: Int, bytes: [UInt8]) throws {
        guard bytes.count == 32 else {
            throw CommodoreDiskImageError.invalidImage("A CP/M directory entry must contain exactly 32 bytes.")
        }
        guard let address = directorySlotAddress(slot) else {
            throw CommodoreDiskImageError.invalidImage("CP/M directory slot \(slot) is outside the directory area.")
        }

        var sector = try readSector(address.sector)
        sector.replaceSubrange(address.offset..<(address.offset + 32), with: bytes)
        try writeRawSector(sector, at: address.sector)
    }

    private func directorySlotAddress(_ slot: Int) -> (sector: CommodoreDiskAddress, offset: Int)? {
        guard slot >= 0,
              slot < variant.dpb.directoryEntryCount else {
            return nil
        }

        let byteOffset = slot * 32
        let physicalSector = byteOffset / CommodoreDiskImage.bytesPerSector
        guard let address = variant.translate(physicalSector: physicalSector) else {
            return nil
        }

        return (address, byteOffset % CommodoreDiskImage.bytesPerSector)
    }

    private func freeDirectorySlots(count: Int) throws -> [Int] {
        guard count > 0 else {
            return []
        }

        var slots: [Int] = []
        for slot in 0..<variant.dpb.directoryEntryCount {
            let bytes = try directorySlotBytes(slot)
            if bytes.first == 0xe5 {
                slots.append(slot)
                if slots.count == count {
                    return slots
                }
            }
        }

        throw CommodoreDiskImageError.noDirectorySlot
    }

    private func allocateBlocks(count: Int) throws -> [Int] {
        guard count > 0 else {
            return []
        }

        let reserved = Set(0..<directoryBlockCount)
        let used = Set(entries.flatMap(\.allocationBlocks)).union(reserved)
        let available = (0..<variant.dpb.allocationBlockCount).filter { !used.contains($0) }
        guard available.count >= count else {
            throw CommodoreDiskImageError.diskFull
        }

        return Array(available.prefix(count))
    }

    private func addresses(forCPMBlock block: Int) -> [CommodoreDiskAddress] {
        let firstPhysicalSector = block * variant.dpb.physicalSectorsPerBlock
        return (0..<variant.dpb.physicalSectorsPerBlock).compactMap { offset in
            variant.translate(physicalSector: firstPhysicalSector + offset)
        }
    }

    private static func parseDirectory(data: Data,
                                       geometry: CommodoreDiskGeometry,
                                       variant: CPMDiskVariant) throws -> [CPMDirectoryEntry] {
        let reader = CPMBlockReader(data: data, geometry: geometry, variant: variant)
        let directoryBlockCount = Int(ceil(Double(variant.dpb.directoryEntryCount) / Double(4 * variant.dpb.logicalBlockRecords)))
        var fcbs: [CPMFileControlBlock] = []

        for block in 0..<directoryBlockCount {
            let blockData = try reader.readCPMBlock(block)
            let slotBase = block * 4 * variant.dpb.logicalBlockRecords
            let slotCount = min(4 * variant.dpb.logicalBlockRecords,
                                variant.dpb.directoryEntryCount - slotBase)
            for slotOffset in 0..<slotCount {
                let start = slotOffset * 32
                let bytes = Array(blockData[start..<(start + 32)])
                let slot = slotBase + slotOffset
                guard let fcb = try CPMFileControlBlock(slot: slot, bytes: bytes, dpb: variant.dpb) else {
                    continue
                }
                fcbs.append(fcb)
            }
        }

        let grouped = Dictionary(grouping: fcbs, by: \.fileKey)
        return grouped.values
            .compactMap { group in
                let sorted = group.sorted { lhs, rhs in
                    lhs.extent == rhs.extent ? lhs.slot < rhs.slot : lhs.extent < rhs.extent
                }
                guard let first = sorted.first else {
                    return nil
                }

                let allocationBlocks = sorted.flatMap(\.allocationBlocks)
                let firstAddress = allocationBlocks.first.flatMap { block in
                    reader.addresses(forCPMBlock: block).first
                }
                let records = sorted.map(\.records).max() ?? 0
                let slots = sorted.map(\.slot)
                let id = "\(first.user):\(first.fileName).\(first.fileExtension):\(slots.map(String.init).joined(separator: ","))"

                return CPMDirectoryEntry(id: id,
                                         user: first.user,
                                         fileName: first.fileName,
                                         fileExtension: first.fileExtension,
                                         records: records,
                                         allocationBlocks: allocationBlocks,
                                         directorySlots: slots,
                                         isReadOnly: first.isReadOnly,
                                         isSystem: first.isSystem,
                                         isArchived: first.isArchived,
                                         startAddress: firstAddress)
            }
            .sorted { lhs, rhs in
                (lhs.directorySlots.first ?? Int.max) < (rhs.directorySlots.first ?? Int.max)
            }
    }
}

struct CPMDiskParameterBlock: Equatable {
    var physicalSectorsPerBlock: Int
    var logicalBlockRecords: Int
    var extentsPerDirectoryEntry: Int
    var allocationBlockCount: Int
    var directoryEntryCount: Int

    var logicalBlockByteCount: Int {
        logicalBlockRecords * 128
    }

    var maxRecordsPerDirectoryEntry: Int {
        extentsPerDirectoryEntry * 128
    }
}

enum CPMDiskVariant: Equatable {
    case c64
    case c128SingleSided
    case c128DoubleSided

    var title: String {
        switch self {
        case .c64:
            return "C64 CP/M"
        case .c128SingleSided:
            return "C128 CP/M"
        case .c128DoubleSided:
            return "C128 CP/M double-sided"
        }
    }

    var dpb: CPMDiskParameterBlock {
        // Commodore CP/M DPBs and sector translations are ported from ctools
        // bios.cc, kept in Swift so the app never depends on external tools.
        switch self {
        case .c64:
            return CPMDiskParameterBlock(physicalSectorsPerBlock: 4,
                                         logicalBlockRecords: 8,
                                         extentsPerDirectoryEntry: 1,
                                         allocationBlockCount: 136,
                                         directoryEntryCount: 64)
        case .c128SingleSided:
            return CPMDiskParameterBlock(physicalSectorsPerBlock: 4,
                                         logicalBlockRecords: 8,
                                         extentsPerDirectoryEntry: 1,
                                         allocationBlockCount: 170,
                                         directoryEntryCount: 64)
        case .c128DoubleSided:
            return CPMDiskParameterBlock(physicalSectorsPerBlock: 8,
                                         logicalBlockRecords: 16,
                                         extentsPerDirectoryEntry: 2,
                                         allocationBlockCount: 170,
                                         directoryEntryCount: 128)
        }
    }

    static func detect(in data: Data,
                       format: CommodoreDiskImageFormat,
                       geometry: CommodoreDiskGeometry) throws -> CPMDiskVariant {
        let reader = RawSectorReader(data: data, geometry: geometry)
        let bam = try reader.readSector(CommodoreDiskAddress(track: 18, sector: 0))
        guard bam.count > 166,
              bam[2] == 0x41,
              bam[165] == 0x32,
              bam[166] == 0x41 else {
            throw CommodoreDiskImageError.invalidImage("The image does not have a Commodore CP/M-compatible BAM.")
        }

        let boot = try reader.readSector(CommodoreDiskAddress(track: 1, sector: 0))
        let startsWithCBM = boot.count >= 3
            && boot[0] == UInt8(ascii: "C")
            && boot[1] == UInt8(ascii: "B")
            && boot[2] == UInt8(ascii: "M")

        if startsWithCBM {
            if boot[255] != 0xff {
                return .c128SingleSided
            }

            if format == .d71 {
                return .c128DoubleSided
            }

            throw CommodoreDiskImageError.invalidImage("This looks like a double-sided C128 CP/M boot disk stored in a single-sided image.")
        }

        return .c64
    }

    func translate(physicalSector nr: Int) -> CommodoreDiskAddress? {
        switch self {
        case .c64:
            return translateC64(physicalSector: nr)
        case .c128SingleSided:
            return translateC128SingleSided(physicalSector: nr)
        case .c128DoubleSided:
            if nr < 680 {
                return translateC128SingleSided(physicalSector: nr)
            }

            guard let address = translateC128SingleSided(physicalSector: nr - 680) else {
                return nil
            }
            return CommodoreDiskAddress(track: address.track + 35, sector: address.sector)
        }
    }

    private func translateC64(physicalSector nr: Int) -> CommodoreDiskAddress? {
        guard nr >= 0,
              nr < 544 else {
            return nil
        }

        var track = nr / 17 + 3
        if track >= 18 {
            track += 1
        }
        return CommodoreDiskAddress(track: track, sector: nr % 17)
    }

    private func translateC128SingleSided(physicalSector nr: Int) -> CommodoreDiskAddress? {
        struct Zone {
            var firstTrack: Int
            var sectorsPerTrack: Int
            var sectorCount: Int
            var reservedSectors: Int
        }

        let zones = [
            Zone(firstTrack: 1, sectorsPerTrack: 21, sectorCount: 357, reservedSectors: 2),
            Zone(firstTrack: 18, sectorsPerTrack: 19, sectorCount: 133, reservedSectors: 1),
            Zone(firstTrack: 25, sectorsPerTrack: 18, sectorCount: 108, reservedSectors: 0),
            Zone(firstTrack: 31, sectorsPerTrack: 17, sectorCount: 85, reservedSectors: 0)
        ]

        guard nr >= 0,
              nr < 680 else {
            return nil
        }

        var sectorIndex = nr
        for zone in zones {
            sectorIndex += zone.reservedSectors
            if sectorIndex < zone.sectorCount {
                return CommodoreDiskAddress(track: zone.firstTrack + sectorIndex / zone.sectorsPerTrack,
                                            sector: (5 * sectorIndex) % zone.sectorsPerTrack)
            }
            sectorIndex -= zone.sectorCount
        }

        return nil
    }
}

private struct CPMBlockReader {
    var data: Data
    var geometry: CommodoreDiskGeometry
    var variant: CPMDiskVariant

    func readCPMBlock(_ block: Int) throws -> Data {
        var blockData = Data()
        for address in addresses(forCPMBlock: block) {
            blockData.append(try RawSectorReader(data: data, geometry: geometry).readSector(address))
        }
        return blockData
    }

    func addresses(forCPMBlock block: Int) -> [CommodoreDiskAddress] {
        let firstPhysicalSector = block * variant.dpb.physicalSectorsPerBlock
        return (0..<variant.dpb.physicalSectorsPerBlock).compactMap { offset in
            variant.translate(physicalSector: firstPhysicalSector + offset)
        }
    }
}

private struct RawSectorReader {
    var data: Data
    var geometry: CommodoreDiskGeometry

    func readSector(_ address: CommodoreDiskAddress) throws -> Data {
        let offset = try geometry.offset(for: address)
        guard offset + CommodoreDiskImage.bytesPerSector <= data.count else {
            throw CommodoreDiskImageError.invalidAddress(address)
        }

        return data.subdata(in: offset..<(offset + CommodoreDiskImage.bytesPerSector))
    }
}

private struct CPMFileControlBlock: Equatable {
    var slot: Int
    var user: Int
    var fileName: String
    var fileExtension: String
    var extent: Int
    var records: Int
    var allocationBlocks: [Int]
    var isReadOnly: Bool
    var isSystem: Bool
    var isArchived: Bool

    var fileKey: String {
        "\(user):\(fileName).\(fileExtension)"
    }

    static func bytes(user: Int,
                      nameBytes: [UInt8],
                      extensionBytes: [UInt8],
                      extentBase: Int,
                      recordsInEntry: Int,
                      blockReferences: [Int],
                      dpb: CPMDiskParameterBlock) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 32)
        bytes[0] = UInt8(user & 0x0f)
        for index in 0..<8 {
            bytes[1 + index] = nameBytes[index]
        }
        for index in 0..<3 {
            bytes[9 + index] = extensionBytes[index]
        }

        let fullEntry = recordsInEntry >= dpb.maxRecordsPerDirectoryEntry
        let extent = fullEntry
            ? extentBase + dpb.extentsPerDirectoryEntry - 1
            : extentBase + recordsInEntry / 128
        let recordCount = fullEntry ? 0x80 : recordsInEntry % 128
        bytes[12] = UInt8(extent & 0xff)
        bytes[13] = 0
        bytes[14] = 0
        bytes[15] = UInt8(recordCount & 0xff)

        for (index, block) in blockReferences.prefix(16).enumerated() {
            bytes[16 + index] = UInt8(block & 0xff)
        }

        return bytes
    }

    init?(slot: Int,
          bytes: [UInt8],
          dpb: CPMDiskParameterBlock) throws {
        guard bytes.count == 32 else {
            return nil
        }

        let userByte = bytes[0]
        guard userByte != 0xe5 else {
            return nil
        }
        guard userByte <= 0x0f else {
            throw CommodoreDiskImageError.invalidImage("CP/M directory entry \(slot) has an unsupported user byte.")
        }

        let name = Self.decodeName(bytes[1..<9])
        let fileExtension = Self.decodeName(bytes[9..<12])
        guard !name.isEmpty else {
            throw CommodoreDiskImageError.invalidImage("CP/M directory entry \(slot) has an empty filename.")
        }

        let rc = Int(bytes[15])
        guard rc <= 0x80 else {
            throw CommodoreDiskImageError.invalidImage("CP/M directory entry \(slot) has an invalid record count.")
        }

        let allocationBlocks = try bytes[16..<32].compactMap { byte -> Int? in
            guard byte != 0 else {
                return nil
            }

            let block = Int(byte)
            guard block < dpb.allocationBlockCount else {
                throw CommodoreDiskImageError.invalidImage("CP/M directory entry \(slot) references allocation block \(block), outside the disk range.")
            }

            return block
        }

        self.slot = slot
        user = Int(userByte)
        fileName = name
        self.fileExtension = fileExtension
        extent = Int(bytes[12])
        records = rc >= 0x80 ? 0x80 * (extent + 1) : 0x80 * extent + rc
        self.allocationBlocks = allocationBlocks
        isReadOnly = (bytes[9] & 0x80) != 0
        isSystem = (bytes[10] & 0x80) != 0
        isArchived = (bytes[11] & 0x80) != 0
    }

    private static func decodeName(_ bytes: ArraySlice<UInt8>) -> String {
        let scalars = bytes.map { byte -> UInt8 in
            let ascii = byte & 0x7f
            return ascii == 0 ? 0x20 : ascii
        }
        let text = String(bytes: scalars, encoding: .ascii) ?? ""
        return text.trimmingCharacters(in: .whitespaces)
    }
}

private enum DiskImageFilename {
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

private extension Data {
    func prefixData(_ count: Int) -> Data {
        guard self.count > count else {
            return self
        }

        return subdata(in: startIndex..<(startIndex + count))
    }
}
