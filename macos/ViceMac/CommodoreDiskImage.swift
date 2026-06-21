import Foundation

enum CommodoreDiskImageError: Error, LocalizedError, Equatable {
    case unsupportedFormat(String)
    case invalidImage(String)
    case invalidAddress(CommodoreDiskAddress)
    case directoryLoop
    case fileLoop(String)
    case diskFull
    case fileExists(String)
    case fileNotFound(String)
    case invalidFileName(String)
    case noDirectorySlot
    case unsupportedNewImageFormat(String)
    case writeNotSupported(String)
    case invalidSectorLength(Int)
    case rebuildBlocked([String])

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let format):
            return "\(format) images are not supported by the disk manager yet."
        case .invalidImage(let reason):
            return reason
        case .invalidAddress(let address):
            return "Track \(address.track), sector \(address.sector) is not valid for this image."
        case .directoryLoop:
            return "The directory chain loops back on itself."
        case .fileLoop(let name):
            return "\(name) has a looping block chain."
        case .diskFull:
            return "The destination image does not have enough free blocks."
        case .fileExists(let name):
            return "A file named \(name) already exists in the destination image."
        case .fileNotFound(let name):
            return "\(name) could not be found in the image directory."
        case .invalidFileName(let name):
            return "\(name) is not a valid Commodore disk filename."
        case .noDirectorySlot:
            return "The destination directory has no free slot."
        case .unsupportedNewImageFormat(let format):
            return "New \(format) images are not supported yet."
        case .writeNotSupported(let format):
            return "Writing files to \(format) images is not supported yet."
        case .invalidSectorLength(let length):
            return "A disk sector must contain exactly 256 bytes, not \(length)."
        case .rebuildBlocked(let reasons):
            return "This image cannot be rebuilt yet: \(reasons.joined(separator: "; "))"
        }
    }
}

struct CommodoreDiskAddress: Hashable, Codable, Comparable {
    var track: Int
    var sector: Int

    static func < (lhs: CommodoreDiskAddress, rhs: CommodoreDiskAddress) -> Bool {
        lhs.track == rhs.track ? lhs.sector < rhs.sector : lhs.track < rhs.track
    }
}

enum CommodoreDiskSectorRole: Equatable {
    case free
    case allocated
    case directory
    case file(String)
    case header
    case unknown

    var label: String {
        switch self {
        case .free:
            return "Free"
        case .allocated:
            return "Allocated"
        case .directory:
            return "Directory"
        case .file(let name):
            return name
        case .header:
            return "Header/BAM"
        case .unknown:
            return "Unknown"
        }
    }
}

struct CommodoreDiskSector: Identifiable, Equatable {
    let address: CommodoreDiskAddress
    var role: CommodoreDiskSectorRole

    var id: CommodoreDiskAddress { address }
}

struct CommodoreDiskDirectoryEntry: Identifiable, Equatable {
    let id: String
    var name: String
    var rawName: [UInt8]
    var type: FileType
    var isClosed: Bool
    var isLocked: Bool
    var start: CommodoreDiskAddress
    var blocks: Int
    var directoryAddress: CommodoreDiskAddress
    var slotIndex: Int

    var typeText: String {
        let prefix = isClosed ? "" : "*"
        let suffix = isLocked ? "<" : ""
        return "\(prefix)\(type.rawValue)\(suffix)"
    }

    enum FileType: String, CaseIterable {
        case del = "DEL"
        case seq = "SEQ"
        case prg = "PRG"
        case usr = "USR"
        case rel = "REL"
        case cbm = "CBM"
        case dir = "DIR"
        case unknown = "???"

        init(directoryByte: UInt8) {
            switch directoryByte & 0x07 {
            case 0:
                self = .del
            case 1:
                self = .seq
            case 2:
                self = .prg
            case 3:
                self = .usr
            case 4:
                self = .rel
            case 5:
                self = .cbm
            case 6:
                self = .dir
            default:
                self = .unknown
            }
        }

        var directoryBits: UInt8 {
            switch self {
            case .del:
                return 0
            case .seq:
                return 1
            case .prg:
                return 2
            case .usr:
                return 3
            case .rel:
                return 4
            case .cbm:
                return 5
            case .dir:
                return 6
            case .unknown:
                return 2
            }
        }
    }
}

struct CommodoreDiskHeader: Equatable {
    var name: String
    var id: String
    var blocksFree: Int?
}

enum CommodoreDiskRebuildIssueSeverity: String, Equatable {
    case info
    case warning
    case blocked
}

struct CommodoreDiskRebuildIssue: Identifiable, Equatable {
    var severity: CommodoreDiskRebuildIssueSeverity
    var title: String
    var detail: String

    var id: String {
        "\(severity.rawValue):\(title):\(detail)"
    }
}

struct CommodoreDiskRebuildAnalysis: Equatable {
    var issues: [CommodoreDiskRebuildIssue]

    var blockingIssues: [CommodoreDiskRebuildIssue] {
        issues.filter { $0.severity == .blocked }
    }

    var warningIssues: [CommodoreDiskRebuildIssue] {
        issues.filter { $0.severity == .warning }
    }

    var canRebuild: Bool {
        blockingIssues.isEmpty
    }

    var statusTitle: String {
        if !blockingIssues.isEmpty {
            return "Rebuild blocked"
        }

        if !warningIssues.isEmpty {
            return "Rebuild with warnings"
        }

        return "Ready to optimize"
    }

    var statusDetail: String {
        if !blockingIssues.isEmpty {
            return "\(blockingIssues.count) issue\(blockingIssues.count == 1 ? "" : "s") must be fixed before this image can be rebuilt."
        }

        if !warningIssues.isEmpty {
            return "The original image will stay untouched. The rebuilt copy may not preserve loader-specific layout or hidden sectors."
        }

        return "This image looks like a standard block disk and can be cloned with drive-aware interleave."
    }
}

enum GEOSInputDeviceKind: Equatable {
    case joystick
    case mouse1351
    case mouse1351Accelerated

    var title: String {
        switch self {
        case .joystick:
            return "Joystick"
        case .mouse1351:
            return "1351 Mouse"
        case .mouse1351Accelerated:
            return "1351 Mouse (fast)"
        }
    }

    var isMouse1351: Bool {
        switch self {
        case .mouse1351, .mouse1351Accelerated:
            return true
        case .joystick:
            return false
        }
    }
}

struct GEOSInputDriver: Identifiable, Equatable {
    var directoryEntry: CommodoreDiskDirectoryEntry
    var device: GEOSInputDeviceKind
    var isDefault: Bool

    var id: String { directoryEntry.id }
    var name: String { directoryEntry.name }
}

struct GEOSDiskStatus: Equatable {
    var inputDrivers: [GEOSInputDriver]

    var defaultInputDriver: GEOSInputDriver? {
        inputDrivers.first { $0.isDefault } ?? inputDrivers.first
    }

    var preferred1351Driver: GEOSInputDriver? {
        inputDrivers.first { $0.device == .mouse1351 }
            ?? inputDrivers.first { $0.device == .mouse1351Accelerated }
    }

    var is1351Default: Bool {
        defaultInputDriver?.device.isMouse1351 == true
    }

    var canMake1351Default: Bool {
        preferred1351Driver != nil && !is1351Default
    }
}

enum CommodoreDiskImageFormat: String, CaseIterable, Identifiable {
    case d64
    case d67
    case d71
    case d80
    case d81
    case d82

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }

    init?(url: URL) {
        self.init(rawValue: url.pathExtension.lowercased())
    }

    var supportsBlankImageCreation: Bool {
        true
    }
}

struct CommodoreDiskGeometry: Equatable {
    let format: CommodoreDiskImageFormat
    let trackCount: Int
    let directoryStart: CommodoreDiskAddress
    let headerAddress: CommodoreDiskAddress
    let headerNameOffset: Int
    let headerIDOffset: Int

    var totalSectors: Int {
        (1...trackCount).reduce(0) { partialResult, track in
            partialResult + sectorsPerTrack(track)
        }
    }

    var dataByteCount: Int {
        totalSectors * CommodoreDiskImage.bytesPerSector
    }

    var supportsBAMFreeMap: Bool {
        true
    }

    var supportsFileWrites: Bool {
        true
    }

    init(format: CommodoreDiskImageFormat, fileSize: Int) throws {
        self.format = format

        switch format {
        case .d64:
            let tracks = try Self.variable1541TrackCount(fileSize: fileSize, usingD67Map: false)
            trackCount = tracks
            directoryStart = CommodoreDiskAddress(track: 18, sector: 1)
            headerAddress = CommodoreDiskAddress(track: 18, sector: 0)
            headerNameOffset = 144
            headerIDOffset = 162
        case .d67:
            try Self.requireSize(fileSize,
                                 matchesByteCountForTracks: 35,
                                 format: format)
            trackCount = 35
            directoryStart = CommodoreDiskAddress(track: 18, sector: 1)
            headerAddress = CommodoreDiskAddress(track: 18, sector: 0)
            headerNameOffset = 144
            headerIDOffset = 162
        case .d71:
            try Self.requireSize(fileSize,
                                 byteCount: Self.d71SectorCount * CommodoreDiskImage.bytesPerSector,
                                 errorMapBytes: Self.d71SectorCount,
                                 format: format)
            trackCount = 70
            directoryStart = CommodoreDiskAddress(track: 18, sector: 1)
            headerAddress = CommodoreDiskAddress(track: 18, sector: 0)
            headerNameOffset = 144
            headerIDOffset = 162
        case .d80:
            try Self.requireSize(fileSize,
                                 byteCount: Self.d80SectorCount * CommodoreDiskImage.bytesPerSector,
                                 errorMapBytes: 0,
                                 format: format)
            trackCount = 77
            directoryStart = CommodoreDiskAddress(track: 39, sector: 1)
            headerAddress = CommodoreDiskAddress(track: 39, sector: 0)
            headerNameOffset = 6
            headerIDOffset = 24
        case .d81:
            trackCount = try Self.d81TrackCount(fileSize: fileSize)
            directoryStart = CommodoreDiskAddress(track: 40, sector: 3)
            headerAddress = CommodoreDiskAddress(track: 40, sector: 0)
            headerNameOffset = 4
            headerIDOffset = 22
        case .d82:
            try Self.requireSize(fileSize,
                                 byteCount: Self.d82SectorCount * CommodoreDiskImage.bytesPerSector,
                                 errorMapBytes: 0,
                                 format: format)
            trackCount = 154
            directoryStart = CommodoreDiskAddress(track: 39, sector: 1)
            headerAddress = CommodoreDiskAddress(track: 39, sector: 0)
            headerNameOffset = 6
            headerIDOffset = 24
        }
    }

    static func blankImageByteCount(for format: CommodoreDiskImageFormat) throws -> Int {
        switch format {
        case .d64:
            return d64SectorCount * CommodoreDiskImage.bytesPerSector
        case .d67:
            return sectorCountFor1541Tracks(35, usingD67Map: true) * CommodoreDiskImage.bytesPerSector
        case .d71:
            return d71SectorCount * CommodoreDiskImage.bytesPerSector
        case .d80:
            return d80SectorCount * CommodoreDiskImage.bytesPerSector
        case .d81:
            return NUM_SECTORS_1581 * NUM_TRACKS_1581 * CommodoreDiskImage.bytesPerSector
        case .d82:
            return d82SectorCount * CommodoreDiskImage.bytesPerSector
        }
    }

    func sectorsPerTrack(_ track: Int) -> Int {
        switch format {
        case .d64, .d71:
            return Self.sectorsPer1541Track(track)
        case .d67:
            return Self.sectorsPer2040Track(track)
        case .d80, .d82:
            return Self.sectorsPer8050Track(track)
        case .d81:
            return 40
        }
    }

    func offset(for address: CommodoreDiskAddress) throws -> Int {
        guard address.track >= 1,
              address.track <= trackCount,
              address.sector >= 0,
              address.sector < sectorsPerTrack(address.track) else {
            throw CommodoreDiskImageError.invalidAddress(address)
        }

        var sectorOffset = 0
        switch format {
        case .d71 where address.track > 35:
            sectorOffset = Self.d64SectorCount
            for track in 1..<(address.track - 35) {
                sectorOffset += Self.sectorsPer1541Track(track)
            }
        case .d82 where address.track > 77:
            sectorOffset = Self.d80SectorCount
            for track in 1..<(address.track - 77) {
                sectorOffset += Self.sectorsPer8050Track(track)
            }
        default:
            for track in 1..<address.track {
                sectorOffset += sectorsPerTrack(track)
            }
        }

        return (sectorOffset + address.sector) * CommodoreDiskImage.bytesPerSector
    }

    func allSectors() -> [CommodoreDiskAddress] {
        (1...trackCount).flatMap { track in
            (0..<sectorsPerTrack(track)).map { sector in
                CommodoreDiskAddress(track: track, sector: sector)
            }
        }
    }

    private static let d64SectorCount = 683
    private static let d71SectorCount = 1_366
    private static let d80SectorCount = 2_083
    private static let d82SectorCount = 4_166
    private static let NUM_TRACKS_1581 = 80
    private static let NUM_SECTORS_1581 = 40

    private static func sectorsPer1541Track(_ track: Int) -> Int {
        let normalizedTrack = track > 35 ? track - 35 : track
        switch normalizedTrack {
        case 1...17:
            return 21
        case 18...24:
            return 19
        case 25...30:
            return 18
        default:
            return 17
        }
    }

    private static func sectorsPer2040Track(_ track: Int) -> Int {
        switch track {
        case 1...17:
            return 21
        case 18...24:
            return 20
        case 25...30:
            return 18
        default:
            return 17
        }
    }

    private static func sectorsPer8050Track(_ track: Int) -> Int {
        let normalizedTrack = track > 77 ? track - 77 : track
        switch normalizedTrack {
        case 1...39:
            return 29
        case 40...53:
            return 27
        case 54...64:
            return 25
        default:
            return 23
        }
    }

    private static func sectorCountFor1541Tracks(_ tracks: Int, usingD67Map: Bool) -> Int {
        (1...tracks).reduce(0) { partialResult, track in
            partialResult + (usingD67Map ? sectorsPer2040Track(track) : sectorsPer1541Track(track))
        }
    }

    private static func variable1541TrackCount(fileSize: Int, usingD67Map: Bool) throws -> Int {
        for tracks in stride(from: 42, through: 35, by: -1) {
            let sectors = sectorCountFor1541Tracks(tracks, usingD67Map: usingD67Map)
            let byteCount = sectors * CommodoreDiskImage.bytesPerSector
            if fileSize == byteCount || fileSize == byteCount + sectors {
                return tracks
            }
        }

        throw CommodoreDiskImageError.invalidImage("The image size does not match a supported D64 geometry.")
    }

    private static func d81TrackCount(fileSize: Int) throws -> Int {
        for tracks in 80...83 {
            let sectors = tracks * 40
            let byteCount = sectors * CommodoreDiskImage.bytesPerSector
            if fileSize == byteCount || fileSize == byteCount + sectors {
                return tracks
            }
        }

        throw CommodoreDiskImageError.invalidImage("The image size does not match a supported D81 geometry.")
    }

    private static func requireSize(_ fileSize: Int,
                                    matchesByteCountForTracks tracks: Int,
                                    format: CommodoreDiskImageFormat) throws {
        let sectors = sectorCountFor1541Tracks(tracks, usingD67Map: format == .d67)
        try requireSize(fileSize,
                        byteCount: sectors * CommodoreDiskImage.bytesPerSector,
                        errorMapBytes: 0,
                        format: format)
    }

    private static func requireSize(_ fileSize: Int,
                                    byteCount: Int,
                                    errorMapBytes: Int,
                                    format: CommodoreDiskImageFormat) throws {
        guard fileSize == byteCount || (errorMapBytes > 0 && fileSize == byteCount + errorMapBytes) else {
            throw CommodoreDiskImageError.invalidImage("The image size does not match a supported \(format.title) geometry.")
        }
    }
}

struct CommodoreDiskImage: Identifiable, Equatable {
    static let bytesPerSector = 256

    let id = UUID()
    var url: URL
    var format: CommodoreDiskImageFormat
    var geometry: CommodoreDiskGeometry
    private(set) var data: Data
    private(set) var isModified = false

    private enum FileAllocationStrategy {
        case firstAvailable
        case driveOptimized
    }

    private enum SectorAllocationPurpose {
        case fileData
        case directory
    }

    init(url: URL) throws {
        guard let format = CommodoreDiskImageFormat(url: url) else {
            throw CommodoreDiskImageError.unsupportedFormat(url.pathExtension.uppercased())
        }

        let loadedData = try Data(contentsOf: url)
        let geometry = try CommodoreDiskGeometry(format: format, fileSize: loadedData.count)
        guard loadedData.count >= geometry.dataByteCount else {
            throw CommodoreDiskImageError.invalidImage("The image is shorter than its declared geometry.")
        }

        self.url = url
        self.format = format
        self.geometry = geometry
        data = loadedData
    }

    init(blankImageAt url: URL,
         format: CommodoreDiskImageFormat,
         diskName: String,
         diskID: String) throws {
        let byteCount = try CommodoreDiskGeometry.blankImageByteCount(for: format)
        let geometry = try CommodoreDiskGeometry(format: format, fileSize: byteCount)

        self.url = url
        self.format = format
        self.geometry = geometry
        data = try Self.blankImageData(format: format,
                                       geometry: geometry,
                                       diskName: diskName,
                                       diskID: diskID)
        try data.write(to: url, options: .atomic)
    }

    var header: CommodoreDiskHeader {
        let sector = (try? readSector(geometry.headerAddress)) ?? Data()
        let bytes = Array(sector)
        let name = bytes.count > geometry.headerNameOffset
            ? CommodorePETSCII.decodeFilename(Array(bytes[geometry.headerNameOffset..<min(geometry.headerNameOffset + 16, bytes.count)]))
            : ""
        let id = bytes.count > geometry.headerIDOffset
            ? CommodorePETSCII.decodeFilename(Array(bytes[geometry.headerIDOffset..<min(geometry.headerIDOffset + 5, bytes.count)]))
            : ""

        return CommodoreDiskHeader(name: name,
                                   id: id,
                                   blocksFree: freeBlockCount())
    }

    func readSector(_ address: CommodoreDiskAddress) throws -> Data {
        let offset = try geometry.offset(for: address)
        guard offset + Self.bytesPerSector <= data.count else {
            throw CommodoreDiskImageError.invalidAddress(address)
        }

        return data.subdata(in: offset..<(offset + Self.bytesPerSector))
    }

    mutating func writeSector(_ bytes: Data, at address: CommodoreDiskAddress) throws {
        guard bytes.count == Self.bytesPerSector else {
            throw CommodoreDiskImageError.invalidSectorLength(bytes.count)
        }

        let offset = try geometry.offset(for: address)
        data.replaceSubrange(offset..<(offset + Self.bytesPerSector), with: bytes)
        isModified = true
    }

    mutating func save() throws {
        try data.write(to: url, options: .atomic)
        isModified = false
    }

    func directoryEntries() throws -> [CommodoreDiskDirectoryEntry] {
        try directorySectors().flatMap { sectorAddress, sector in
            (0..<8).compactMap { slotIndex in
                let base = slotIndex * 32
                guard sector[base + 2] != 0 else {
                    return nil
                }

                let typeByte = sector[base + 2]
                let rawName = Array(sector[(base + 5)..<(base + 21)])
                let name = CommodorePETSCII.decodeFilename(rawName)
                return CommodoreDiskDirectoryEntry(id: "\(sectorAddress.track):\(sectorAddress.sector):\(slotIndex)",
                                                   name: name,
                                                   rawName: rawName,
                                                   type: .init(directoryByte: typeByte),
                                                   isClosed: (typeByte & 0x80) != 0,
                                                   isLocked: (typeByte & 0x40) != 0,
                                                   start: CommodoreDiskAddress(track: Int(sector[base + 3]),
                                                                               sector: Int(sector[base + 4])),
                                                   blocks: Int(sector[base + 30]) + (Int(sector[base + 31]) << 8),
                                                   directoryAddress: sectorAddress,
                                                   slotIndex: slotIndex)
            }
        }
    }

    func sectorMap() -> [CommodoreDiskSector] {
        var roles = Dictionary(uniqueKeysWithValues: geometry.allSectors().map { address in
            (address, CommodoreDiskSectorRole.unknown)
        })

        if geometry.supportsBAMFreeMap {
            for address in geometry.allSectors() {
                roles[address] = isSectorFreeInBAM(address) == true ? .free : .allocated
            }
        }

        roles[geometry.headerAddress] = .header

        if let sectors = try? directorySectors() {
            for sector in sectors {
                roles[sector.address] = .directory
            }
        }

        if let entries = try? directoryEntries() {
            for entry in entries {
                guard let chain = try? fileSectorChain(for: entry) else {
                    continue
                }

                for address in chain {
                    roles[address] = .file(entry.name)
                }
            }
        }

        return geometry.allSectors().map { address in
            CommodoreDiskSector(address: address, role: roles[address] ?? .unknown)
        }
    }

    func fileData(for entry: CommodoreDiskDirectoryEntry) throws -> Data {
        var output = Data()
        var address = entry.start
        var seen = Set<CommodoreDiskAddress>()

        while address.track != 0 {
            guard !seen.contains(address) else {
                throw CommodoreDiskImageError.fileLoop(entry.name)
            }

            seen.insert(address)
            let sector = try readSector(address)
            let nextTrack = Int(sector[0])
            let nextSector = Int(sector[1])

            if nextTrack == 0 {
                let byteCount = min(max(nextSector - 1, 0), Self.bytesPerSector - 2)
                output.append(sector.subdata(in: 2..<(2 + byteCount)))
                break
            }

            output.append(sector.subdata(in: 2..<Self.bytesPerSector))
            address = CommodoreDiskAddress(track: nextTrack, sector: nextSector)
        }

        return output
    }

    var geosStatus: GEOSDiskStatus? {
        guard let entries = try? directoryEntries(),
              Self.looksLikeGEOSSystemDisk(entries) else {
            return nil
        }

        let detectedDrivers = entries.compactMap { entry -> GEOSInputDriver? in
            guard let device = Self.geosInputDevice(for: entry.name) else {
                return nil
            }

            return GEOSInputDriver(directoryEntry: entry,
                                   device: device,
                                   isDefault: false)
        }

        guard !detectedDrivers.isEmpty else {
            return GEOSDiskStatus(inputDrivers: [])
        }

        let drivers = detectedDrivers.enumerated().map { index, driver in
            GEOSInputDriver(directoryEntry: driver.directoryEntry,
                            device: driver.device,
                            isDefault: index == 0)
        }
        return GEOSDiskStatus(inputDrivers: drivers)
    }

    var geosBootProgramName: String? {
        guard let entries = try? directoryEntries(),
              Self.looksLikeGEOSSystemDisk(entries) else {
            return nil
        }

        return Self.geosBootEntry(in: entries)?.name
    }

    mutating func copyFile(_ entry: CommodoreDiskDirectoryEntry,
                           from source: CommodoreDiskImage) throws {
        let payload = try source.fileData(for: entry)
        try writeFile(named: entry.rawName,
                      type: entry.type,
                      isClosed: entry.isClosed,
                      isLocked: entry.isLocked,
                      payload: payload,
                      allocationStrategy: .firstAvailable)
    }

    mutating func importFile(named name: String,
                             type: CommodoreDiskDirectoryEntry.FileType = .prg,
                             payload: Data) throws {
        try writeFile(named: try validatedRawFilename(name),
                      type: type,
                      isLocked: false,
                      payload: payload)
    }

    mutating func installGEOSPackage(_ package: GEOSCVTFile) throws {
        guard geometry.supportsFileWrites else {
            throw CommodoreDiskImageError.writeNotSupported(format.title)
        }
        guard geosStatus != nil else {
            throw CommodoreDiskImageError.invalidImage("This does not look like a GEOS system disk.")
        }

        let rawName = try validatedRawFilename(package.diskName)
        let decodedName = CommodorePETSCII.decodeFilename(rawName)
        let destinationNames = try directoryEntries().map { $0.name.uppercased() }
        guard !destinationNames.contains(decodedName.uppercased()) else {
            throw CommodoreDiskImageError.fileExists(decodedName)
        }

        try writeGEOSPackage(package, rawName: rawName)
    }

    mutating func renameFile(_ entry: CommodoreDiskDirectoryEntry, to name: String) throws {
        let rawName = try validatedRawFilename(name)
        let decodedName = CommodorePETSCII.decodeFilename(rawName)
        let destinationNames = try directoryEntries()
            .filter { $0.id != entry.id }
            .map { $0.name.uppercased() }
        guard !destinationNames.contains(decodedName.uppercased()) else {
            throw CommodoreDiskImageError.fileExists(decodedName)
        }

        var sector = try directorySector(for: entry)
        let base = entry.slotIndex * 32
        for index in 0..<16 {
            sector[base + 5 + index] = rawName[index]
        }
        try writeSector(sector, at: entry.directoryAddress)
    }

    mutating func makeGEOS1351Default() throws {
        guard let status = geosStatus else {
            throw CommodoreDiskImageError.invalidImage("This does not look like a GEOS system disk.")
        }

        guard let currentDefault = status.defaultInputDriver else {
            throw CommodoreDiskImageError.invalidImage("No GEOS input driver was found on this disk.")
        }

        guard let mouseDriver = status.preferred1351Driver else {
            throw CommodoreDiskImageError.invalidImage("No GEOS 1351 mouse driver was found on this disk.")
        }

        guard currentDefault.id != mouseDriver.id else {
            return
        }

        try swapDirectoryEntryBodies(currentDefault.directoryEntry,
                                     mouseDriver.directoryEntry)
    }

    mutating func deleteFile(_ entry: CommodoreDiskDirectoryEntry) throws {
        guard geometry.supportsFileWrites else {
            throw CommodoreDiskImageError.writeNotSupported(format.title)
        }

        let chain = try fileSectorChain(for: entry)
        for address in chain {
            try markSectorInBAM(address, free: true)
        }

        var sector = try directorySector(for: entry)
        let base = entry.slotIndex * 32
        sector.replaceSubrange(base..<(base + 32),
                               with: Data(repeating: 0, count: 32))
        try writeSector(sector, at: entry.directoryAddress)
    }

    func rebuildAnalysis() -> CommodoreDiskRebuildAnalysis {
        var issues: [CommodoreDiskRebuildIssue] = []

        if !geometry.supportsFileWrites {
            issues.append(.init(severity: .blocked,
                                title: "\(format.title) writing is not supported",
                                detail: "The disk manager can inspect this image, but it cannot create a rebuilt copy yet."))
        }

        if !hasStandardWritableGeometry {
            issues.append(.init(severity: .blocked,
                                title: "Nonstandard geometry",
                                detail: "\(format.title) images with \(geometry.trackCount) tracks can be inspected, but optimized rebuilding currently supports standard geometry only."))
        }

        if data.count > geometry.dataByteCount {
            issues.append(.init(severity: .warning,
                                title: "Sector error map present",
                                detail: "The rebuilt copy will be a plain DOS image and will not preserve encoded sector errors."))
        }

        let entries: [CommodoreDiskDirectoryEntry]
        do {
            entries = try directoryEntries()
        } catch {
            issues.append(.init(severity: .blocked,
                                title: "Directory cannot be read",
                                detail: error.localizedDescription))
            return CommodoreDiskRebuildAnalysis(issues: issues)
        }

        let duplicateNames = Dictionary(grouping: entries, by: { $0.name.uppercased() })
            .filter { !$0.key.isEmpty && $0.value.count > 1 }
        for duplicate in duplicateNames.keys.sorted() {
            issues.append(.init(severity: .warning,
                                title: "Duplicate filename \(duplicate)",
                                detail: "The rebuilt copy will preserve directory order, but normal DOS file access may only reach the first matching name."))
        }

        for entry in entries {
            if entry.type == .rel {
                issues.append(.init(severity: .blocked,
                                    title: "\(entry.name) is a REL file",
                                    detail: "REL files use side-sector metadata that the rebuilt-image writer does not preserve yet."))
            } else if entry.type == .unknown {
                issues.append(.init(severity: .blocked,
                                    title: "\(entry.name) has an unknown file type",
                                    detail: "The rebuilt-image writer cannot preserve unknown directory type bits yet."))
            } else if [.del, .cbm, .dir].contains(entry.type) {
                issues.append(.init(severity: .warning,
                                    title: "\(entry.name) uses \(entry.typeText)",
                                    detail: "The file chain can be copied, but this is not a normal PRG/SEQ/USR entry."))
            }

            if !entry.isClosed {
                issues.append(.init(severity: .warning,
                                    title: "\(entry.name) is marked open",
                                    detail: "The rebuilt copy will preserve the open flag, but software may already treat this file as damaged."))
            }
        }

        var knownAllocated = systemSectors()
        if let directory = try? directorySectors() {
            for sector in directory {
                knownAllocated.insert(sector.address)
                if isSectorFreeInBAM(sector.address) == true {
                    issues.append(.init(severity: .warning,
                                        title: "Directory sector marked free",
                                        detail: "T\(sector.address.track):S\(sector.address.sector) is in the directory chain but is free in the BAM."))
                }
            }
        }

        var claimedFileSectors: [CommodoreDiskAddress: String] = [:]
        for entry in entries {
            do {
                let chain = try fileSectorChain(for: entry)
                if chain.isEmpty && entry.start.track != 0 {
                    issues.append(.init(severity: .warning,
                                        title: "\(entry.name) has no readable blocks",
                                        detail: "The directory entry points to T\(entry.start.track):S\(entry.start.sector), but no file data chain was found."))
                }

                for address in chain {
                    knownAllocated.insert(address)
                    if let previous = claimedFileSectors[address] {
                        issues.append(.init(severity: .warning,
                                            title: "Cross-linked file sector",
                                            detail: "T\(address.track):S\(address.sector) is used by both \(previous) and \(entry.name). The clone will duplicate the readable data into separate chains."))
                    } else {
                        claimedFileSectors[address] = entry.name
                    }

                    if isSectorFreeInBAM(address) == true {
                        issues.append(.init(severity: .warning,
                                            title: "\(entry.name) uses a free BAM sector",
                                            detail: "T\(address.track):S\(address.sector) is in the file chain but marked free."))
                    }
                }
            } catch {
                issues.append(.init(severity: .blocked,
                                    title: "\(entry.name) cannot be read",
                                    detail: error.localizedDescription))
            }
        }

        let orphaned = allocatedSectorsNotReferenced(by: knownAllocated)
        if !orphaned.isEmpty {
            issues.append(.init(severity: .warning,
                                title: "\(orphaned.count) orphaned allocated sector\(orphaned.count == 1 ? "" : "s")",
                                detail: "These sectors are allocated in the BAM but are not part of a visible file or directory chain. A rebuilt copy will omit them."))
        }

        let remnants = freeSectorsContainingData(excluding: knownAllocated)
        if !remnants.isEmpty {
            issues.append(.init(severity: .info,
                                title: "\(remnants.count) free sector\(remnants.count == 1 ? "" : "s") contain old data",
                                detail: "Free-sector remnants are normal on used disks. A rebuilt copy will leave them behind."))
        }

        return CommodoreDiskRebuildAnalysis(issues: issues)
    }

    func cloneOptimized(to destinationURL: URL) throws -> CommodoreDiskImage {
        let destination = destinationURL.standardizedFileURL
        guard destination != url.standardizedFileURL else {
            throw CommodoreDiskImageError.invalidImage("Choose a different destination so the original image is never overwritten.")
        }

        let analysis = rebuildAnalysis()
        guard analysis.canRebuild else {
            throw CommodoreDiskImageError.rebuildBlocked(analysis.blockingIssues.map(\.title))
        }

        let entries = try directoryEntries()
        let temporaryURL = destination
            .deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString)-optimized.\(format.rawValue)")
        defer {
            try? FileManager.default.removeItem(at: temporaryURL)
        }

        var rebuilt = try CommodoreDiskImage(blankImageAt: temporaryURL,
                                             format: format,
                                             diskName: header.name.isEmpty ? "UNTITLED" : header.name,
                                             diskID: header.id.isEmpty ? "VM" : header.id)

        for entry in entries {
            let payload = try fileData(for: entry)
            try rebuilt.writeFile(named: entry.rawName,
                                  type: entry.type,
                                  isClosed: entry.isClosed,
                                  isLocked: entry.isLocked,
                                  payload: payload,
                                  allocationStrategy: .driveOptimized,
                                  allowDuplicateName: true)
        }

        try rebuilt.save()
        let verified = try CommodoreDiskImage(url: temporaryURL)
        try verifyRebuild(verified, originalEntries: entries)

        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
        return try CommodoreDiskImage(url: destination)
    }

    private mutating func writeFile(named rawName: [UInt8],
                                    type: CommodoreDiskDirectoryEntry.FileType,
                                    isLocked: Bool,
                                    payload: Data) throws {
        try writeFile(named: rawName,
                      type: type,
                      isClosed: true,
                      isLocked: isLocked,
                      payload: payload,
                      allocationStrategy: .firstAvailable)
    }

    private mutating func writeFile(named rawName: [UInt8],
                                    type: CommodoreDiskDirectoryEntry.FileType,
                                    isClosed: Bool,
                                    isLocked: Bool,
                                    payload: Data,
                                    allocationStrategy: FileAllocationStrategy,
                                    allowDuplicateName: Bool = false) throws {
        guard geometry.supportsFileWrites else {
            throw CommodoreDiskImageError.writeNotSupported(format.title)
        }
        guard type != .rel else {
            throw CommodoreDiskImageError.invalidImage("REL files are not writable yet because their side-sector metadata must be preserved.")
        }
        guard type != .unknown else {
            throw CommodoreDiskImageError.invalidImage("Unknown Commodore file types are not writable yet.")
        }

        let decodedName = CommodorePETSCII.decodeFilename(rawName)
        let destinationNames = try directoryEntries().map { $0.name.uppercased() }
        guard allowDuplicateName || !destinationNames.contains(decodedName.uppercased()) else {
            throw CommodoreDiskImageError.fileExists(decodedName)
        }

        let sectorCount = max(1, Int(ceil(Double(payload.count) / Double(Self.bytesPerSector - 2))))
        let allocated = try allocateFreeSectors(count: sectorCount, strategy: allocationStrategy)

        for index in allocated.indices {
            var sector = Data(repeating: 0, count: Self.bytesPerSector)
            let chunkStart = index * (Self.bytesPerSector - 2)
            let chunkEnd = min(chunkStart + Self.bytesPerSector - 2, payload.count)
            let chunk = payload.subdata(in: chunkStart..<chunkEnd)

            if index == allocated.indices.last {
                sector[0] = 0
                sector[1] = UInt8(chunk.count + 1)
            } else {
                sector[0] = UInt8(allocated[index + 1].track)
                sector[1] = UInt8(allocated[index + 1].sector)
            }

            sector.replaceSubrange(2..<(2 + chunk.count), with: chunk)
            try writeSector(sector, at: allocated[index])
        }

        do {
            try writeDirectoryEntry(name: rawName,
                                    type: type,
                                    isClosed: isClosed,
                                    isLocked: isLocked,
                                    firstSector: allocated[0],
                                    blocks: allocated.count)
        } catch {
            for address in allocated {
                try? markSectorInBAM(address, free: true)
            }
            throw error
        }
    }

    private mutating func writeGEOSPackage(_ package: GEOSCVTFile,
                                           rawName: [UInt8]) throws {
        let dataSectorCount = max(1, Int(ceil(Double(package.programPayload.count) / Double(Self.bytesPerSector - 2))))
        let allocated = try allocateFreeSectors(count: dataSectorCount + 1, strategy: .firstAvailable)
        let headerAddress = allocated[0]
        let dataAddresses = Array(allocated.dropFirst())

        do {
            var headerSector = Data(repeating: 0, count: Self.bytesPerSector)
            headerSector[1] = 255
            headerSector.replaceSubrange(2..<Self.bytesPerSector, with: package.fileInfoRecord)
            try writeSector(headerSector, at: headerAddress)

            for index in dataAddresses.indices {
                var sector = Data(repeating: 0, count: Self.bytesPerSector)
                let chunkStart = index * (Self.bytesPerSector - 2)
                let chunkEnd = min(chunkStart + Self.bytesPerSector - 2, package.programPayload.count)
                let chunk = package.programPayload.subdata(in: chunkStart..<chunkEnd)

                if index == dataAddresses.indices.last {
                    sector[0] = 0
                    sector[1] = UInt8(chunk.count + 1)
                } else {
                    sector[0] = UInt8(dataAddresses[index + 1].track)
                    sector[1] = UInt8(dataAddresses[index + 1].sector)
                }

                sector.replaceSubrange(2..<(2 + chunk.count), with: chunk)
                try writeSector(sector, at: dataAddresses[index])
            }

            var directoryRecord = package.directoryRecord
            directoryRecord[1] = UInt8(dataAddresses[0].track)
            directoryRecord[2] = UInt8(dataAddresses[0].sector)
            directoryRecord[19] = UInt8(headerAddress.track)
            directoryRecord[20] = UInt8(headerAddress.sector)
            let blocks = dataAddresses.count + 1
            directoryRecord[28] = UInt8(blocks & 0xff)
            directoryRecord[29] = UInt8((blocks >> 8) & 0xff)
            try writeGEOSDirectoryEntry(record: directoryRecord,
                                        fallbackName: rawName)
        } catch {
            for address in allocated {
                try? markSectorInBAM(address, free: true)
            }
            throw error
        }
    }

    private func validatedRawFilename(_ name: String) throws -> [UInt8] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CommodoreDiskImageError.invalidFileName(name)
        }

        return CommodorePETSCII.encodeFilename(trimmed)
    }

    private func directorySector(for entry: CommodoreDiskDirectoryEntry) throws -> Data {
        let sector = try readSector(entry.directoryAddress)
        let base = entry.slotIndex * 32
        guard entry.slotIndex >= 0,
              entry.slotIndex < 8,
              sector[base + 2] != 0 else {
            throw CommodoreDiskImageError.fileNotFound(entry.name)
        }

        return sector
    }

    private mutating func swapDirectoryEntryBodies(_ first: CommodoreDiskDirectoryEntry,
                                                   _ second: CommodoreDiskDirectoryEntry) throws {
        var firstSector = try directorySector(for: first)
        let firstRange = Self.directoryEntryBodyRange(slotIndex: first.slotIndex)
        let secondRange = Self.directoryEntryBodyRange(slotIndex: second.slotIndex)
        let firstBody = firstSector.subdata(in: firstRange)

        if first.directoryAddress == second.directoryAddress {
            let secondBody = firstSector.subdata(in: secondRange)
            firstSector.replaceSubrange(firstRange, with: secondBody)
            firstSector.replaceSubrange(secondRange, with: firstBody)

            try writeSector(firstSector, at: first.directoryAddress)
        } else {
            var secondSector = try directorySector(for: second)
            let secondBody = secondSector.subdata(in: secondRange)
            firstSector.replaceSubrange(firstRange, with: secondBody)
            secondSector.replaceSubrange(secondRange, with: firstBody)

            try writeSector(firstSector, at: first.directoryAddress)
            try writeSector(secondSector, at: second.directoryAddress)
        }
    }

    private static func directoryEntryBodyRange(slotIndex: Int) -> Range<Int> {
        let base = slotIndex * 32
        return (base + 2)..<(base + 32)
    }

    private static func looksLikeGEOSSystemDisk(_ entries: [CommodoreDiskDirectoryEntry]) -> Bool {
        let names = Set(entries.map { normalizedGEOSName($0.name) })
        let hasBoot = geosBootEntry(in: entries) != nil
        let hasDesktop = names.contains("DESK TOP")
            || names.contains("DESKTOP")
            || names.contains("128 DESKTOP")

        return hasBoot && hasDesktop
    }

    private static func geosBootEntry(in entries: [CommodoreDiskDirectoryEntry]) -> CommodoreDiskDirectoryEntry? {
        for bootName in ["GEOS128", "GEOS", "GEOBOOT128", "GEOBOOT"] {
            if let entry = entries.first(where: { normalizedGEOSName($0.name) == bootName }) {
                return entry
            }
        }

        return nil
    }

    private static func geosInputDevice(for name: String) -> GEOSInputDeviceKind? {
        let normalized = normalizedGEOSName(name)

        if normalized.contains("1351") {
            return normalized.contains("(A)") ? .mouse1351Accelerated : .mouse1351
        }

        if normalized.contains("JOYSTICK") {
            return .joystick
        }

        return nil
    }

    private static func normalizedGEOSName(_ name: String) -> String {
        name.uppercased()
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func blankImageData(format: CommodoreDiskImageFormat,
                                       geometry: CommodoreDiskGeometry,
                                       diskName: String,
                                       diskID: String) throws -> Data {
        switch format {
        case .d64, .d67:
            return try blank1541LikeImageData(format: format,
                                             geometry: geometry,
                                             diskName: diskName,
                                             diskID: diskID)
        case .d71:
            return try blank1571ImageData(geometry: geometry,
                                          diskName: diskName,
                                          diskID: diskID)
        case .d80, .d82:
            return try blank8050LikeImageData(format: format,
                                             geometry: geometry,
                                             diskName: diskName,
                                             diskID: diskID)
        case .d81:
            return try blank1581ImageData(geometry: geometry,
                                          diskName: diskName,
                                          diskID: diskID)
        }
    }

    private static func blank1541LikeImageData(format: CommodoreDiskImageFormat,
                                               geometry: CommodoreDiskGeometry,
                                               diskName: String,
                                               diskID: String) throws -> Data {
        var data = Data(repeating: 0, count: geometry.dataByteCount)
        var bam = Data(repeating: 0, count: bytesPerSector)
        bam[0] = UInt8(geometry.directoryStart.track)
        bam[1] = UInt8(geometry.directoryStart.sector)
        bam[2] = format == .d67 ? 0x01 : 65

        for track in 1...35 {
            let entry = 4 + (track - 1) * 4
            let sectorCount = geometry.sectorsPerTrack(track)
            bam[entry] = UInt8(sectorCount)

            for sector in 0..<sectorCount {
                bam[entry + 1 + sector / 8] |= UInt8(1 << (sector % 8))
            }
        }

        writePETSCII(diskName, into: &bam, range: geometry.headerNameOffset..<(geometry.headerNameOffset + 16))
        writePETSCII(diskID, into: &bam, range: geometry.headerIDOffset..<(geometry.headerIDOffset + 5))
        if format == .d67 {
            bam[0xa4] = 0x20
            bam[0xa5] = 0x20
        } else {
            bam[165] = 50
            bam[166] = 65
        }
        mark1541Sector(geometry.headerAddress, free: false, in: &bam)
        mark1541Sector(geometry.directoryStart, free: false, in: &bam)

        var directory = Data(repeating: 0, count: bytesPerSector)
        directory[0] = 0
        directory[1] = 255

        try replaceSector(bam, at: geometry.headerAddress, geometry: geometry, data: &data)
        try replaceSector(directory, at: geometry.directoryStart, geometry: geometry, data: &data)
        return data
    }

    private static func blank1571ImageData(geometry: CommodoreDiskGeometry,
                                           diskName: String,
                                           diskID: String) throws -> Data {
        var data = Data(repeating: 0, count: geometry.dataByteCount)
        var primaryBAM = Data(repeating: 0, count: bytesPerSector)
        var secondaryBAM = Data(repeating: 0, count: bytesPerSector)
        primaryBAM[0] = UInt8(geometry.directoryStart.track)
        primaryBAM[1] = UInt8(geometry.directoryStart.sector)
        primaryBAM[2] = 65
        primaryBAM[3] = 0x80

        for track in 1...35 {
            let entry = 4 + (track - 1) * 4
            let sectorCount = geometry.sectorsPerTrack(track)
            primaryBAM[entry] = UInt8(sectorCount)

            for sector in 0..<sectorCount {
                primaryBAM[entry + 1 + sector / 8] |= UInt8(1 << (sector % 8))
            }
        }

        for track in 36...70 {
            let localTrack = track - 36
            let sectorCount = geometry.sectorsPerTrack(track)
            primaryBAM[221 + localTrack] = UInt8(sectorCount)

            for sector in 0..<sectorCount {
                secondaryBAM[localTrack * 3 + sector / 8] |= UInt8(1 << (sector % 8))
            }
        }

        writePETSCII(diskName, into: &primaryBAM, range: geometry.headerNameOffset..<(geometry.headerNameOffset + 16))
        writePETSCII(diskID, into: &primaryBAM, range: geometry.headerIDOffset..<(geometry.headerIDOffset + 5))
        primaryBAM[165] = 50
        primaryBAM[166] = 65

        mark1571Sector(geometry.headerAddress, free: false, primaryBAM: &primaryBAM, secondaryBAM: &secondaryBAM)
        mark1571Sector(geometry.directoryStart, free: false, primaryBAM: &primaryBAM, secondaryBAM: &secondaryBAM)
        mark1571Sector(CommodoreDiskAddress(track: 53, sector: 0), free: false, primaryBAM: &primaryBAM, secondaryBAM: &secondaryBAM)

        var directory = Data(repeating: 0, count: bytesPerSector)
        directory[0] = 0
        directory[1] = 255

        try replaceSector(primaryBAM, at: geometry.headerAddress, geometry: geometry, data: &data)
        try replaceSector(secondaryBAM, at: CommodoreDiskAddress(track: 53, sector: 0), geometry: geometry, data: &data)
        try replaceSector(directory, at: geometry.directoryStart, geometry: geometry, data: &data)
        return data
    }

    private static func blank1581ImageData(geometry: CommodoreDiskGeometry,
                                           diskName: String,
                                           diskID: String) throws -> Data {
        var data = Data(repeating: 0, count: geometry.dataByteCount)
        var header = Data(repeating: 0, count: bytesPerSector)
        var firstBAM = Data(repeating: 0, count: bytesPerSector)
        var secondBAM = Data(repeating: 0, count: bytesPerSector)

        header[0] = UInt8(geometry.directoryStart.track)
        header[1] = UInt8(geometry.directoryStart.sector)
        header[2] = 68
        writePETSCII(diskName, into: &header, range: geometry.headerNameOffset..<(geometry.headerNameOffset + 16))
        writePETSCII(diskID, into: &header, range: geometry.headerIDOffset..<(geometry.headerIDOffset + 5))
        header[25] = 51
        header[26] = 68

        firstBAM[0] = UInt8(geometry.headerAddress.track)
        firstBAM[1] = 2
        firstBAM[2] = 68
        firstBAM[3] = 0xbb
        firstBAM[4] = CommodorePETSCII.encodeFilename(diskID)[0]
        firstBAM[5] = CommodorePETSCII.encodeFilename(diskID)[1]
        firstBAM[6] = 0xc0

        secondBAM[0] = 0
        secondBAM[1] = 255
        secondBAM[2] = 68
        secondBAM[3] = 0xbb
        secondBAM[4] = firstBAM[4]
        secondBAM[5] = firstBAM[5]
        secondBAM[6] = 0xc0

        for track in 1...geometry.trackCount {
            let sectorCount = geometry.sectorsPerTrack(track)
            var bam = track <= 40 ? firstBAM : secondBAM
            let localTrack = track <= 40 ? track : track - 40
            let entry = 16 + (localTrack - 1) * 6
            bam[entry] = UInt8(sectorCount)

            for sector in 0..<sectorCount {
                bam[entry + 1 + sector / 8] |= UInt8(1 << (sector % 8))
            }

            if track <= 40 {
                firstBAM = bam
            } else {
                secondBAM = bam
            }
        }

        mark1581Sector(CommodoreDiskAddress(track: 40, sector: 0), free: false, firstBAM: &firstBAM, secondBAM: &secondBAM)
        mark1581Sector(CommodoreDiskAddress(track: 40, sector: 1), free: false, firstBAM: &firstBAM, secondBAM: &secondBAM)
        mark1581Sector(CommodoreDiskAddress(track: 40, sector: 2), free: false, firstBAM: &firstBAM, secondBAM: &secondBAM)
        mark1581Sector(geometry.directoryStart, free: false, firstBAM: &firstBAM, secondBAM: &secondBAM)

        var directory = Data(repeating: 0, count: bytesPerSector)
        directory[0] = 0
        directory[1] = 255

        try replaceSector(header, at: geometry.headerAddress, geometry: geometry, data: &data)
        try replaceSector(firstBAM, at: CommodoreDiskAddress(track: 40, sector: 1), geometry: geometry, data: &data)
        try replaceSector(secondBAM, at: CommodoreDiskAddress(track: 40, sector: 2), geometry: geometry, data: &data)
        try replaceSector(directory, at: geometry.directoryStart, geometry: geometry, data: &data)
        return data
    }

    private static func blank8050LikeImageData(format: CommodoreDiskImageFormat,
                                               geometry: CommodoreDiskGeometry,
                                               diskName: String,
                                               diskID: String) throws -> Data {
        var data = Data(repeating: 0, count: geometry.dataByteCount)
        var header = Data(repeating: 0, count: bytesPerSector)
        let blockDescriptors = bam8050BlockDescriptors(for: format)
        var bitmapBAMs = blockDescriptors.map { descriptor -> Data in
            var bam = Data(repeating: 0, count: bytesPerSector)
            bam[0] = UInt8(descriptor.next.track)
            bam[1] = UInt8(descriptor.next.sector)
            bam[2] = 67
            bam[4] = UInt8(descriptor.startTrack)
            bam[5] = UInt8(descriptor.endTrack)

            for track in descriptor.startTrack..<descriptor.endTrack {
                let sectorCount = geometry.sectorsPerTrack(track)
                let entry = 6 + 5 * (track - descriptor.startTrack)
                bam[entry] = UInt8(sectorCount)

                for sector in 0..<sectorCount {
                    bam[entry + 1 + sector / 8] |= UInt8(1 << (sector % 8))
                }
            }

            return bam
        }

        header[0] = 38
        header[1] = 0
        header[2] = 67
        writePETSCII(diskName, into: &header, range: geometry.headerNameOffset..<(geometry.headerNameOffset + 16))
        writePETSCII(diskID, into: &header, range: geometry.headerIDOffset..<(geometry.headerIDOffset + 5))
        header[27] = 50
        header[28] = 67

        let reserved = [geometry.headerAddress, geometry.directoryStart] + blockDescriptors.map(\.address)
        for address in reserved {
            mark8050Sector(address, free: false, descriptors: blockDescriptors, bams: &bitmapBAMs)
        }

        var directory = Data(repeating: 0, count: bytesPerSector)
        directory[0] = 0
        directory[1] = 255

        try replaceSector(header, at: geometry.headerAddress, geometry: geometry, data: &data)
        for (index, descriptor) in blockDescriptors.enumerated() {
            try replaceSector(bitmapBAMs[index], at: descriptor.address, geometry: geometry, data: &data)
        }
        try replaceSector(directory, at: geometry.directoryStart, geometry: geometry, data: &data)
        return data
    }

    private static func replaceSector(_ sector: Data,
                                      at address: CommodoreDiskAddress,
                                      geometry: CommodoreDiskGeometry,
                                      data: inout Data) throws {
        let offset = try geometry.offset(for: address)
        data.replaceSubrange(offset..<(offset + bytesPerSector), with: sector)
    }

    private static func writePETSCII(_ string: String, into data: inout Data, range: Range<Int>) {
        let bytes = CommodorePETSCII.encodeFilename(string)
        for (index, dataIndex) in range.enumerated() where data.indices.contains(dataIndex) {
            data[dataIndex] = index < bytes.count ? bytes[index] : 0xa0
        }
    }

    private struct BAM8050BlockDescriptor {
        var address: CommodoreDiskAddress
        var next: CommodoreDiskAddress
        var startTrack: Int
        var endTrack: Int
    }

    private static func bam8050BlockDescriptors(for format: CommodoreDiskImageFormat) -> [BAM8050BlockDescriptor] {
        switch format {
        case .d80:
            return [
                BAM8050BlockDescriptor(address: CommodoreDiskAddress(track: 38, sector: 0),
                                       next: CommodoreDiskAddress(track: 38, sector: 3),
                                       startTrack: 1,
                                       endTrack: 51),
                BAM8050BlockDescriptor(address: CommodoreDiskAddress(track: 38, sector: 3),
                                       next: CommodoreDiskAddress(track: 39, sector: 1),
                                       startTrack: 51,
                                       endTrack: 78)
            ]
        case .d82:
            return [
                BAM8050BlockDescriptor(address: CommodoreDiskAddress(track: 38, sector: 0),
                                       next: CommodoreDiskAddress(track: 38, sector: 3),
                                       startTrack: 1,
                                       endTrack: 51),
                BAM8050BlockDescriptor(address: CommodoreDiskAddress(track: 38, sector: 3),
                                       next: CommodoreDiskAddress(track: 38, sector: 6),
                                       startTrack: 51,
                                       endTrack: 101),
                BAM8050BlockDescriptor(address: CommodoreDiskAddress(track: 38, sector: 6),
                                       next: CommodoreDiskAddress(track: 38, sector: 9),
                                       startTrack: 101,
                                       endTrack: 151),
                BAM8050BlockDescriptor(address: CommodoreDiskAddress(track: 38, sector: 9),
                                       next: CommodoreDiskAddress(track: 39, sector: 1),
                                       startTrack: 151,
                                       endTrack: 155)
            ]
        case .d64, .d67, .d71, .d81:
            return []
        }
    }

    private static func mark1541Sector(_ address: CommodoreDiskAddress, free: Bool, in bam: inout Data) {
        let entry = 4 + (address.track - 1) * 4
        let countIndex = entry
        let byteIndex = entry + 1 + address.sector / 8
        let mask = UInt8(1 << (address.sector % 8))
        let currentlyFree = (bam[byteIndex] & mask) != 0

        guard currentlyFree != free else {
            return
        }

        if free {
            bam[byteIndex] |= mask
            bam[countIndex] = bam[countIndex] &+ 1
        } else {
            bam[byteIndex] &= ~mask
            bam[countIndex] = bam[countIndex] &- 1
        }
    }

    private static func mark1571Sector(_ address: CommodoreDiskAddress,
                                       free: Bool,
                                       primaryBAM: inout Data,
                                       secondaryBAM: inout Data) {
        if address.track <= 35 {
            mark1541Sector(address, free: free, in: &primaryBAM)
            return
        }

        let localTrack = address.track - 36
        let countIndex = 221 + localTrack
        let byteIndex = localTrack * 3 + address.sector / 8
        let mask = UInt8(1 << (address.sector % 8))
        let currentlyFree = (secondaryBAM[byteIndex] & mask) != 0

        guard currentlyFree != free else {
            return
        }

        if free {
            secondaryBAM[byteIndex] |= mask
            primaryBAM[countIndex] = primaryBAM[countIndex] &+ 1
        } else {
            secondaryBAM[byteIndex] &= ~mask
            primaryBAM[countIndex] = primaryBAM[countIndex] &- 1
        }
    }

    private static func mark1581Sector(_ address: CommodoreDiskAddress,
                                       free: Bool,
                                       firstBAM: inout Data,
                                       secondBAM: inout Data) {
        let localTrack = address.track <= 40 ? address.track : address.track - 40
        let entry = 16 + (localTrack - 1) * 6
        let byteIndex = entry + 1 + address.sector / 8
        let mask = UInt8(1 << (address.sector % 8))

        if address.track <= 40 {
            markBAMBit(byteIndex: byteIndex, countIndex: entry, mask: mask, free: free, in: &firstBAM)
        } else {
            markBAMBit(byteIndex: byteIndex, countIndex: entry, mask: mask, free: free, in: &secondBAM)
        }
    }

    private static func mark8050Sector(_ address: CommodoreDiskAddress,
                                       free: Bool,
                                       descriptors: [BAM8050BlockDescriptor],
                                       bams: inout [Data]) {
        guard let index = descriptors.firstIndex(where: { descriptor in
            address.track >= descriptor.startTrack && address.track < descriptor.endTrack
        }) else {
            return
        }

        let descriptor = descriptors[index]
        let entry = 6 + 5 * (address.track - descriptor.startTrack)
        let byteIndex = entry + 1 + address.sector / 8
        let mask = UInt8(1 << (address.sector % 8))
        markBAMBit(byteIndex: byteIndex, countIndex: entry, mask: mask, free: free, in: &bams[index])
    }

    private static func markBAMBit(byteIndex: Int,
                                   countIndex: Int,
                                   mask: UInt8,
                                   free: Bool,
                                   in bam: inout Data) {
        let currentlyFree = (bam[byteIndex] & mask) != 0

        guard currentlyFree != free else {
            return
        }

        if free {
            bam[byteIndex] |= mask
            bam[countIndex] = bam[countIndex] &+ 1
        } else {
            bam[byteIndex] &= ~mask
            bam[countIndex] = bam[countIndex] &- 1
        }
    }

    private func directorySectors() throws -> [(address: CommodoreDiskAddress, bytes: Data)] {
        var sectors: [(CommodoreDiskAddress, Data)] = []
        var address = geometry.directoryStart
        var seen = Set<CommodoreDiskAddress>()

        while address.track != 0 {
            guard !seen.contains(address) else {
                throw CommodoreDiskImageError.directoryLoop
            }

            seen.insert(address)
            let bytes = try readSector(address)
            sectors.append((address, bytes))

            let nextTrack = Int(bytes[0])
            let nextSector = Int(bytes[1])
            guard nextTrack != 0 else {
                break
            }

            address = CommodoreDiskAddress(track: nextTrack, sector: nextSector)
        }

        return sectors
    }

    private func fileSectorChain(for entry: CommodoreDiskDirectoryEntry) throws -> [CommodoreDiskAddress] {
        var chain: [CommodoreDiskAddress] = []
        var address = entry.start
        var seen = Set<CommodoreDiskAddress>()

        while address.track != 0 {
            guard !seen.contains(address) else {
                throw CommodoreDiskImageError.fileLoop(entry.name)
            }

            seen.insert(address)
            chain.append(address)
            let sector = try readSector(address)
            address = CommodoreDiskAddress(track: Int(sector[0]), sector: Int(sector[1]))
        }

        return chain
    }

    private var hasStandardWritableGeometry: Bool {
        switch format {
        case .d64, .d67:
            return geometry.trackCount == 35
        case .d71:
            return geometry.trackCount == 70
        case .d80:
            return geometry.trackCount == 77
        case .d81:
            return geometry.trackCount == 80
        case .d82:
            return geometry.trackCount == 154
        }
    }

    private var driveFileInterleave: Int {
        switch format {
        case .d64, .d67:
            return 10
        case .d71, .d80:
            return 6
        case .d81:
            return 1
        case .d82:
            return 5
        }
    }

    private var directoryInterleave: Int {
        format == .d81 ? 1 : 3
    }

    private func systemSectors() -> Set<CommodoreDiskAddress> {
        var sectors: Set<CommodoreDiskAddress> = [geometry.headerAddress]

        switch format {
        case .d64, .d67:
            break
        case .d71:
            sectors.insert(CommodoreDiskAddress(track: 53, sector: 0))
        case .d80, .d82:
            for descriptor in Self.bam8050BlockDescriptors(for: format) {
                sectors.insert(descriptor.address)
            }
        case .d81:
            sectors.insert(CommodoreDiskAddress(track: 40, sector: 1))
            sectors.insert(CommodoreDiskAddress(track: 40, sector: 2))
        }

        return sectors
    }

    private func allocatedSectorsNotReferenced(by knownAllocated: Set<CommodoreDiskAddress>) -> [CommodoreDiskAddress] {
        geometry.allSectors().filter { address in
            guard isSectorFreeInBAM(address) == false else {
                return false
            }

            return !knownAllocated.contains(address)
        }
    }

    private func freeSectorsContainingData(excluding knownAllocated: Set<CommodoreDiskAddress>) -> [CommodoreDiskAddress] {
        geometry.allSectors().filter { address in
            guard !knownAllocated.contains(address),
                  isSectorFreeInBAM(address) == true,
                  let sector = try? readSector(address) else {
                return false
            }

            return sector.contains { $0 != 0 }
        }
    }

    private func verifyRebuild(_ rebuilt: CommodoreDiskImage,
                               originalEntries: [CommodoreDiskDirectoryEntry]) throws {
        let rebuiltEntries = try rebuilt.directoryEntries()
        guard rebuiltEntries.count == originalEntries.count else {
            throw CommodoreDiskImageError.invalidImage("The rebuilt image did not preserve the directory entry count.")
        }

        for (original, copy) in zip(originalEntries, rebuiltEntries) {
            guard original.rawName == copy.rawName,
                  original.type == copy.type,
                  original.isClosed == copy.isClosed,
                  original.isLocked == copy.isLocked else {
                throw CommodoreDiskImageError.invalidImage("The rebuilt image did not preserve the directory entry for \(original.name).")
            }

            guard try fileData(for: original) == rebuilt.fileData(for: copy) else {
                throw CommodoreDiskImageError.invalidImage("The rebuilt image did not preserve the file data for \(original.name).")
            }
        }
    }

    private func freeBlockCount() -> Int? {
        guard geometry.supportsBAMFreeMap else {
            return nil
        }

        return geometry.allSectors().reduce(0) { partialResult, address in
            if excludesFreeBlockCount(address) {
                return partialResult
            }

            return partialResult + (isSectorFreeInBAM(address) == true ? 1 : 0)
        }
    }

    private func excludesFreeBlockCount(_ address: CommodoreDiskAddress) -> Bool {
        switch format {
        case .d71:
            return address.track == geometry.directoryStart.track || address.track == geometry.directoryStart.track + 35
        case .d64, .d67, .d80, .d81, .d82:
            return address.track == geometry.directoryStart.track
        }
    }

    private func isSectorFreeInBAM(_ address: CommodoreDiskAddress) -> Bool? {
        switch format {
        case .d64, .d67:
            return isSectorFreeIn1541BAM(address)
        case .d71:
            return isSectorFreeIn1571BAM(address)
        case .d81:
            return isSectorFreeIn1581BAM(address)
        case .d80, .d82:
            return isSectorFreeIn8050BAM(address)
        }
    }

    private func isSectorFreeIn1541BAM(_ address: CommodoreDiskAddress) -> Bool? {
        guard let bam = try? readSector(geometry.headerAddress),
              address.track >= 1,
              address.track <= 35 else {
            return nil
        }

        let entry = 4 + (address.track - 1) * 4
        let byteIndex = entry + 1 + (address.sector / 8)
        guard byteIndex < bam.count else {
            return nil
        }

        return (bam[byteIndex] & UInt8(1 << (address.sector % 8))) != 0
    }

    private func isSectorFreeIn1571BAM(_ address: CommodoreDiskAddress) -> Bool? {
        if address.track <= 35 {
            return isSectorFreeIn1541BAM(address)
        }

        guard let bam = try? readSector(CommodoreDiskAddress(track: 53, sector: 0)),
              address.track <= 70 else {
            return nil
        }

        let localTrack = address.track - 36
        let byteIndex = localTrack * 3 + (address.sector / 8)
        guard byteIndex < bam.count else {
            return nil
        }

        return (bam[byteIndex] & UInt8(1 << (address.sector % 8))) != 0
    }

    private func isSectorFreeIn1581BAM(_ address: CommodoreDiskAddress) -> Bool? {
        let bamAddress = address.track <= 40
            ? CommodoreDiskAddress(track: 40, sector: 1)
            : CommodoreDiskAddress(track: 40, sector: 2)
        guard let bam = try? readSector(bamAddress) else {
            return nil
        }

        let localTrack = address.track <= 40 ? address.track : address.track - 40
        let entry = 16 + (localTrack - 1) * 6
        let byteIndex = entry + 1 + (address.sector / 8)
        guard byteIndex < bam.count else {
            return nil
        }

        return (bam[byteIndex] & UInt8(1 << (address.sector % 8))) != 0
    }

    private func isSectorFreeIn8050BAM(_ address: CommodoreDiskAddress) -> Bool? {
        guard let (bam, entry) = try? bam8050Entry(for: address) else {
            return nil
        }

        let byteIndex = entry + 1 + (address.sector / 8)
        guard byteIndex < bam.count else {
            return nil
        }

        return (bam[byteIndex] & UInt8(1 << (address.sector % 8))) != 0
    }

    private mutating func allocateFreeSectors(count: Int,
                                              strategy: FileAllocationStrategy = .firstAvailable) throws -> [CommodoreDiskAddress] {
        switch strategy {
        case .firstAvailable:
            return try allocateFirstAvailableSectors(count: count)
        case .driveOptimized:
            return try allocateOptimizedFileSectors(count: count)
        }
    }

    private mutating func allocateFirstAvailableSectors(count: Int) throws -> [CommodoreDiskAddress] {
        var allocated: [CommodoreDiskAddress] = []

        for address in geometry.allSectors() {
            guard canAllocate(address, purpose: .fileData),
                  isSectorFreeInBAM(address) == true else {
                continue
            }

            try markSectorInBAM(address, free: false)
            allocated.append(address)

            if allocated.count == count {
                return allocated
            }
        }

        for address in allocated {
            try markSectorInBAM(address, free: true)
        }

        throw CommodoreDiskImageError.diskFull
    }

    private mutating func allocateOptimizedFileSectors(count: Int) throws -> [CommodoreDiskAddress] {
        var allocated: [CommodoreDiskAddress] = []

        do {
            guard let first = try allocateFirstOptimizedFileSector() else {
                throw CommodoreDiskImageError.diskFull
            }

            allocated.append(first)
            while allocated.count < count {
                guard let next = try allocateNextOptimizedFileSector(after: allocated[allocated.count - 1]) else {
                    throw CommodoreDiskImageError.diskFull
                }

                allocated.append(next)
            }

            return allocated
        } catch {
            for address in allocated {
                try? markSectorInBAM(address, free: true)
            }
            throw error
        }
    }

    private mutating func allocateFirstOptimizedFileSector() throws -> CommodoreDiskAddress? {
        for track in tracksByDistanceFromDirectory() {
            if let address = try allocateFreeSector(on: track, startingAt: 0, purpose: .fileData) {
                return address
            }
        }

        return nil
    }

    private mutating func allocateNextOptimizedFileSector(after previous: CommodoreDiskAddress) throws -> CommodoreDiskAddress? {
        let preferredSector = sector(afterAdding: driveFileInterleave, to: previous)
        if let address = try allocateFreeSector(on: previous.track,
                                                startingAt: preferredSector,
                                                purpose: .fileData) {
            return address
        }

        for track in fallbackTracks(after: previous.track) {
            if let address = try allocateFreeSector(on: track, startingAt: 0, purpose: .fileData) {
                return address
            }
        }

        return nil
    }

    private mutating func allocateDirectorySector(after previous: CommodoreDiskAddress) throws -> CommodoreDiskAddress {
        let preferredSector = sector(afterAdding: directoryInterleave, to: previous)
        if let address = try allocateFreeSector(on: geometry.directoryStart.track,
                                                startingAt: preferredSector,
                                                purpose: .directory) {
            return address
        }

        throw CommodoreDiskImageError.noDirectorySlot
    }

    private mutating func allocateFreeSector(on track: Int,
                                             startingAt startSector: Int,
                                             purpose: SectorAllocationPurpose) throws -> CommodoreDiskAddress? {
        guard track >= 1, track <= geometry.trackCount else {
            return nil
        }

        let sectorCount = geometry.sectorsPerTrack(track)
        guard sectorCount > 0 else {
            return nil
        }

        let normalizedStart = ((startSector % sectorCount) + sectorCount) % sectorCount
        for offset in 0..<sectorCount {
            let sector = (normalizedStart + offset) % sectorCount
            let address = CommodoreDiskAddress(track: track, sector: sector)
            guard canAllocate(address, purpose: purpose),
                  isSectorFreeInBAM(address) == true else {
                continue
            }

            try markSectorInBAM(address, free: false)
            return address
        }

        return nil
    }

    private func canAllocate(_ address: CommodoreDiskAddress,
                             purpose: SectorAllocationPurpose) -> Bool {
        guard address != geometry.headerAddress,
              !systemSectors().contains(address) else {
            return false
        }

        switch purpose {
        case .fileData:
            return !excludesFreeBlockCount(address)
        case .directory:
            return address.track == geometry.directoryStart.track
        }
    }

    private func tracksByDistanceFromDirectory() -> [Int] {
        let directoryTrack = geometry.directoryStart.track
        let maximumDistance = max(directoryTrack - 1, geometry.trackCount - directoryTrack)
        var tracks: [Int] = []

        guard maximumDistance > 0 else {
            return tracks
        }

        for distance in 1...maximumDistance {
            let lower = directoryTrack - distance
            if lower >= 1 {
                tracks.append(lower)
            }

            let upper = directoryTrack + distance
            if upper <= geometry.trackCount {
                tracks.append(upper)
            }
        }

        return tracks
    }

    private func fallbackTracks(after track: Int) -> [Int] {
        let directoryTrack = geometry.directoryStart.track
        var tracks: [Int] = []

        func append(_ track: Int) {
            guard track >= 1,
                  track <= geometry.trackCount,
                  track != directoryTrack,
                  !tracks.contains(track) else {
                return
            }

            tracks.append(track)
        }

        if track < directoryTrack {
            for next in stride(from: track - 1, through: 1, by: -1) {
                append(next)
            }
            if directoryTrack < geometry.trackCount {
                for next in (directoryTrack + 1)...geometry.trackCount {
                    append(next)
                }
            }
            for next in stride(from: directoryTrack - 1, through: 1, by: -1) {
                append(next)
            }
        } else {
            if track < geometry.trackCount {
                for next in (track + 1)...geometry.trackCount {
                    append(next)
                }
            }
            for next in stride(from: directoryTrack - 1, through: 1, by: -1) {
                append(next)
            }
            if directoryTrack < geometry.trackCount {
                for next in (directoryTrack + 1)...geometry.trackCount {
                    append(next)
                }
            }
        }

        return tracks
    }

    private func sector(afterAdding interleave: Int,
                        to address: CommodoreDiskAddress) -> Int {
        let sectorCount = geometry.sectorsPerTrack(address.track)
        var sector = address.sector + interleave
        if sector >= sectorCount {
            sector -= sectorCount
            if sector != 0 {
                sector -= 1
            }
        }

        return sector
    }

    private mutating func markSectorInBAM(_ address: CommodoreDiskAddress, free: Bool) throws {
        switch format {
        case .d64, .d67:
            try mark1541BAM(address, free: free)
        case .d71:
            try mark1571BAM(address, free: free)
        case .d81:
            try mark1581BAM(address, free: free)
        case .d80, .d82:
            try mark8050BAM(address, free: free)
        }
    }

    private mutating func mark1541BAM(_ address: CommodoreDiskAddress, free: Bool) throws {
        guard address.track >= 1, address.track <= 35 else {
            throw CommodoreDiskImageError.writeNotSupported(format.title)
        }

        var bam = try readSector(geometry.headerAddress)
        let entry = 4 + (address.track - 1) * 4
        let countIndex = entry
        let byteIndex = entry + 1 + (address.sector / 8)
        let mask = UInt8(1 << (address.sector % 8))
        let currentlyFree = (bam[byteIndex] & mask) != 0

        guard currentlyFree != free else {
            return
        }

        if free {
            bam[byteIndex] |= mask
            bam[countIndex] = bam[countIndex] &+ 1
        } else {
            bam[byteIndex] &= ~mask
            bam[countIndex] = bam[countIndex] &- 1
        }

        try writeSector(bam, at: geometry.headerAddress)
    }

    private mutating func mark1571BAM(_ address: CommodoreDiskAddress, free: Bool) throws {
        guard address.track >= 1, address.track <= 70 else {
            throw CommodoreDiskImageError.writeNotSupported(format.title)
        }

        if address.track <= 35 {
            try mark1541BAM(address, free: free)
            return
        }

        var primaryBAM = try readSector(geometry.headerAddress)
        var secondaryBAM = try readSector(CommodoreDiskAddress(track: 53, sector: 0))
        Self.mark1571Sector(address, free: free, primaryBAM: &primaryBAM, secondaryBAM: &secondaryBAM)
        try writeSector(primaryBAM, at: geometry.headerAddress)
        try writeSector(secondaryBAM, at: CommodoreDiskAddress(track: 53, sector: 0))
    }

    private mutating func mark1581BAM(_ address: CommodoreDiskAddress, free: Bool) throws {
        var firstBAM = try readSector(CommodoreDiskAddress(track: 40, sector: 1))
        var secondBAM = try readSector(CommodoreDiskAddress(track: 40, sector: 2))
        Self.mark1581Sector(address, free: free, firstBAM: &firstBAM, secondBAM: &secondBAM)
        try writeSector(firstBAM, at: CommodoreDiskAddress(track: 40, sector: 1))
        try writeSector(secondBAM, at: CommodoreDiskAddress(track: 40, sector: 2))
    }

    private mutating func mark8050BAM(_ address: CommodoreDiskAddress, free: Bool) throws {
        let (bamAddress, entry) = try bam8050AddressAndEntry(for: address)
        var bam = try readSector(bamAddress)
        let byteIndex = entry + 1 + (address.sector / 8)
        let mask = UInt8(1 << (address.sector % 8))
        Self.markBAMBit(byteIndex: byteIndex, countIndex: entry, mask: mask, free: free, in: &bam)
        try writeSector(bam, at: bamAddress)
    }

    private func bam8050Entry(for address: CommodoreDiskAddress) throws -> (Data, Int) {
        let (bamAddress, entry) = try bam8050AddressAndEntry(for: address)
        return (try readSector(bamAddress), entry)
    }

    private func bam8050AddressAndEntry(for address: CommodoreDiskAddress) throws -> (CommodoreDiskAddress, Int) {
        for descriptor in Self.bam8050BlockDescriptors(for: format) {
            let bam = try readSector(descriptor.address)
            let startTrack = Int(bam[4])
            let endTrack = Int(bam[5])
            if address.track >= startTrack && address.track < endTrack {
                return (descriptor.address, 6 + 5 * (address.track - startTrack))
            }
        }

        throw CommodoreDiskImageError.invalidAddress(address)
    }

    private mutating func writeDirectoryEntry(name rawName: [UInt8],
                                              type: CommodoreDiskDirectoryEntry.FileType,
                                              isClosed: Bool,
                                              isLocked: Bool,
                                              firstSector: CommodoreDiskAddress,
                                              blocks: Int) throws {
        let directory = try directorySectors()

        for (address, bytes) in directory {
            var sector = bytes
            for slot in 0..<8 {
                let base = slot * 32
                if sector[base + 2] == 0 {
                    writeDirectoryEntry(to: &sector,
                                        slot: slot,
                                        name: rawName,
                                        type: type,
                                        isClosed: isClosed,
                                        isLocked: isLocked,
                                        firstSector: firstSector,
                                        blocks: blocks)
                    try writeSector(sector, at: address)
                    return
                }
            }
        }

        guard let last = directory.last else {
            throw CommodoreDiskImageError.noDirectorySlot
        }

        let newDirectoryAddress = try allocateDirectorySector(after: last.address)

        var previous = last.bytes
        previous[0] = UInt8(newDirectoryAddress.track)
        previous[1] = UInt8(newDirectoryAddress.sector)
        try writeSector(previous, at: last.address)

        var newDirectorySector = Data(repeating: 0, count: Self.bytesPerSector)
        newDirectorySector[1] = 255
        writeDirectoryEntry(to: &newDirectorySector,
                            slot: 0,
                            name: rawName,
                            type: type,
                            isClosed: isClosed,
                            isLocked: isLocked,
                            firstSector: firstSector,
                            blocks: blocks)
        try writeSector(newDirectorySector, at: newDirectoryAddress)
    }

    private mutating func writeGEOSDirectoryEntry(record: Data,
                                                 fallbackName rawName: [UInt8]) throws {
        guard record.count == GEOSCVTFile.recordSize else {
            throw CommodoreDiskImageError.invalidImage("A GEOS directory record must contain exactly 254 bytes.")
        }

        let directory = try directorySectors()

        for (address, bytes) in directory {
            var sector = bytes
            for slot in 0..<8 {
                let base = slot * 32
                if sector[base + 2] == 0 {
                    writeGEOSDirectoryEntry(to: &sector,
                                            slot: slot,
                                            record: record,
                                            fallbackName: rawName)
                    try writeSector(sector, at: address)
                    return
                }
            }
        }

        guard let last = directory.last else {
            throw CommodoreDiskImageError.noDirectorySlot
        }

        let newDirectoryAddress = try allocateDirectorySector(after: last.address)

        var previous = last.bytes
        previous[0] = UInt8(newDirectoryAddress.track)
        previous[1] = UInt8(newDirectoryAddress.sector)
        try writeSector(previous, at: last.address)

        var newDirectorySector = Data(repeating: 0, count: Self.bytesPerSector)
        newDirectorySector[1] = 255
        writeGEOSDirectoryEntry(to: &newDirectorySector,
                                slot: 0,
                                record: record,
                                fallbackName: rawName)
        try writeSector(newDirectorySector, at: newDirectoryAddress)
    }

    private func writeGEOSDirectoryEntry(to sector: inout Data,
                                         slot: Int,
                                         record: Data,
                                         fallbackName rawName: [UInt8]) {
        let base = slot * 32
        for index in 0..<30 {
            sector[base + 2 + index] = record[index]
        }

        let paddedName = CommodorePETSCII.paddedFilename(rawName)
        for index in 0..<16 {
            sector[base + 5 + index] = paddedName[index]
        }
    }

    private func writeDirectoryEntry(to sector: inout Data,
                                     slot: Int,
                                     name rawName: [UInt8],
                                     type: CommodoreDiskDirectoryEntry.FileType,
                                     isClosed: Bool,
                                     isLocked: Bool,
                                     firstSector: CommodoreDiskAddress,
                                     blocks: Int) {
        let base = slot * 32
        sector[base + 2] = type.directoryBits | (isClosed ? 0x80 : 0) | (isLocked ? 0x40 : 0)
        sector[base + 3] = UInt8(firstSector.track)
        sector[base + 4] = UInt8(firstSector.sector)

        let paddedName = CommodorePETSCII.paddedFilename(rawName)
        for index in 0..<16 {
            sector[base + 5 + index] = paddedName[index]
        }

        sector[base + 30] = UInt8(blocks & 0xff)
        sector[base + 31] = UInt8((blocks >> 8) & 0xff)
    }
}

enum CommodorePETSCII {
    static func decodeFilename(_ bytes: [UInt8]) -> String {
        let scalars = bytes.prefix { byte in
            byte != 0xa0 && byte != 0x00
        }.map { byte -> UnicodeScalar in
            switch byte {
            case 0x20...0x5f:
                return UnicodeScalar(byte)
            case 0xc1...0xda:
                return UnicodeScalar(byte - 0x80)
            default:
                return UnicodeScalar(".")
            }
        }

        return String(String.UnicodeScalarView(scalars)).trimmingCharacters(in: .whitespaces)
    }

    static func paddedFilename(_ rawName: [UInt8]) -> [UInt8] {
        var bytes = Array(rawName.prefix(16))
        while bytes.count < 16 {
            bytes.append(0xa0)
        }
        return bytes
    }

    static func encodeFilename(_ string: String) -> [UInt8] {
        var output: [UInt8] = []
        for scalar in string.uppercased().unicodeScalars.prefix(16) {
            output.append(UInt8(scalar.value & 0xff))
        }
        return paddedFilename(output)
    }
}

enum CommodoreHexDump {
    static func text(for data: Data) -> String {
        let bytes = Array(data.prefix(CommodoreDiskImage.bytesPerSector))
        return stride(from: 0, to: bytes.count, by: 16).map { offset in
            bytes[offset..<min(offset + 16, bytes.count)]
                .map { String(format: "%02X", $0) }
                .joined(separator: " ")
        }.joined(separator: "\n")
    }

    static func data(from text: String) throws -> Data {
        let tokens = text
            .split { character in
                character.isWhitespace || character == ","
            }

        var bytes = Data()
        bytes.reserveCapacity(CommodoreDiskImage.bytesPerSector)

        for token in tokens {
            guard token.count == 2,
                  let byte = UInt8(token, radix: 16) else {
                throw CommodoreDiskImageError.invalidImage("The sector editor accepts two-digit hex bytes only.")
            }

            bytes.append(byte)
        }

        guard bytes.count == CommodoreDiskImage.bytesPerSector else {
            throw CommodoreDiskImageError.invalidSectorLength(bytes.count)
        }

        return bytes
    }
}
