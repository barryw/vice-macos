import Foundation

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

private extension Data {
    func prefixData(_ count: Int) -> Data {
        guard self.count > count else {
            return self
        }

        return subdata(in: startIndex..<(startIndex + count))
    }
}
