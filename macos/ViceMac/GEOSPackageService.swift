import Foundation

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
