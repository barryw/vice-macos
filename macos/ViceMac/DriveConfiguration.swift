import Foundation

struct DriveConfiguration: Identifiable, Codable, Equatable {
    private static let viceSoundVolumeMax = 4000
    private static let viceSoundVolumePercentScale = viceSoundVolumeMax / 100

    let unit: Int
    var isAttached: Bool
    var storageKind: DriveStorageKind
    var driveType: DriveType
    var sharedFolderPath: String?
    var accessMode: DriveAccessMode
    var protectsInsertedDisks: Bool
    var soundEnabled: Bool
    var soundVolume: Int

    var id: Int { unit }

    init(unit: Int,
         isAttached: Bool,
         storageKind: DriveStorageKind = .diskImage,
         driveType: DriveType,
         sharedFolderPath: String? = nil,
         accessMode: DriveAccessMode = .native,
         protectsInsertedDisks: Bool = true,
         soundEnabled: Bool,
         soundVolume: Int) {
        self.unit = unit
        self.isAttached = isAttached
        self.storageKind = storageKind
        self.driveType = driveType
        self.sharedFolderPath = Self.normalizedSharedFolderPath(sharedFolderPath)
        self.accessMode = accessMode
        self.protectsInsertedDisks = protectsInsertedDisks
        self.soundEnabled = soundEnabled
        self.soundVolume = Self.normalizedSoundVolumePercent(soundVolume)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        unit = try container.decode(Int.self, forKey: .unit)
        isAttached = try container.decode(Bool.self, forKey: .isAttached)
        driveType = try container.decode(DriveType.self, forKey: .driveType)
        storageKind = try container.decodeIfPresent(DriveStorageKind.self, forKey: .storageKind)
            ?? driveType.defaultStorageKind
        sharedFolderPath = Self.normalizedSharedFolderPath(
            try container.decodeIfPresent(String.self, forKey: .sharedFolderPath)
        )
        accessMode = try container.decodeIfPresent(DriveAccessMode.self, forKey: .accessMode) ?? .native
        protectsInsertedDisks = try container.decodeIfPresent(Bool.self, forKey: .protectsInsertedDisks) ?? true
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? false
        soundVolume = Self.soundVolumePercent(fromStoredValue: try container.decodeIfPresent(Int.self, forKey: .soundVolume) ?? 25)
    }

    var viceSoundVolume: Int32 {
        Int32(Self.viceSoundVolume(fromPercent: soundVolume))
    }

    var hasSharedFolder: Bool {
        sharedFolderPath?.isEmpty == false
    }

    var isSharedFolderDrive: Bool {
        storageKind == .sharedFolder
    }

    var usesRealDriveModel: Bool {
        storageKind != .sharedFolder
    }

    var isEffectivelyAttached: Bool {
        isAttached && (!isSharedFolderDrive || hasSharedFolder)
    }

    var supportsDriveSounds: Bool {
        isAttached && usesRealDriveModel
    }

    var viceSharedFolderPath: String? {
        guard let sharedFolderPath,
              !sharedFolderPath.isEmpty else {
            return nil
        }

        if sharedFolderPath.hasSuffix("/") {
            return sharedFolderPath
        }

        return sharedFolderPath + "/"
    }

    static func normalizedSoundVolumePercent(_ volume: Int) -> Int {
        min(max(volume, 0), 100)
    }

    static func normalizedSharedFolderPath(_ path: String?) -> String? {
        guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private static func soundVolumePercent(fromStoredValue volume: Int) -> Int {
        if volume > 100 {
            return normalizedSoundVolumePercent((volume + (viceSoundVolumePercentScale / 2)) / viceSoundVolumePercentScale)
        }

        return normalizedSoundVolumePercent(volume)
    }

    private static func viceSoundVolume(fromPercent percent: Int) -> Int {
        min(max(percent, 0), 100) * viceSoundVolumePercentScale
    }
}

enum DriveStorageKind: String, CaseIterable, Codable, Identifiable {
    case diskImage
    case hardDriveImage
    case sharedFolder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .diskImage:
            return "Disk Image"
        case .hardDriveImage:
            return "Hard Drive Image"
        case .sharedFolder:
            return "Shared Mac Folder"
        }
    }

    var detail: String {
        switch self {
        case .diskImage:
            return "Use a real Commodore disk image with tracks, sectors, and disk metadata."
        case .hardDriveImage:
            return "Use a real Commodore hard-drive image for software that expects hard-drive behavior."
        case .sharedFolder:
            return "Use a Finder folder for simple LOAD, SAVE, and file transfer."
        }
    }

    var systemImage: String {
        switch self {
        case .diskImage:
            return "externaldrive"
        case .hardDriveImage:
            return "internaldrive"
        case .sharedFolder:
            return "folder"
        }
    }
}

enum DriveAccessMode: String, CaseIterable, Codable, Identifiable {
    case native
    case fast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .native:
            return "Native"
        case .fast:
            return "Fast"
        }
    }

    var detail: String {
        switch self {
        case .native:
            return "True drive emulation"
        case .fast:
            return "Fast disk access"
        }
    }

    var systemImage: String {
        switch self {
        case .native:
            return "externaldrive"
        case .fast:
            return "bolt.fill"
        }
    }

    var trueDriveEmulationResourceValue: Int32 {
        switch self {
        case .native:
            return 1
        case .fast:
            return 0
        }
    }

    var trapDeviceResourceValue: Int32 {
        switch self {
        case .native:
            return 0
        case .fast:
            return 1
        }
    }
}

enum DriveType: Int32, CaseIterable, Codable, Identifiable {
    case c1540 = 1540
    case c1541 = 1541
    case c1541II = 1542
    case c1551 = 1551
    case c1570 = 1570
    case c1571 = 1571
    case c1581 = 1581
    case fd2000 = 2000
    case fd4000 = 4000
    case c2031 = 2031
    case c2040 = 2040
    case c3040 = 3040
    case c4040 = 4040
    case sfd1001 = 1001
    case c8050 = 8050
    case c8250 = 8250
    case d9090d9060 = 9000
    case cmdHD = 4844

    var id: Int32 { rawValue }

    static let iecOptions: [DriveType] = [
        .c1540,
        .c1541,
        .c1541II,
        .c1570,
        .c1571,
        .c1581,
        .fd2000,
        .fd4000,
        .cmdHD
    ]

    static let c128Options: [DriveType] = iecOptions + petOptions

    static let plus4Options: [DriveType] = [
        .c1551
    ] + iecOptions

    static let petOptions: [DriveType] = [
        .c2031,
        .c2040,
        .c3040,
        .c4040,
        .sfd1001,
        .c8050,
        .c8250,
        .d9090d9060
    ]

    var title: String {
        switch self {
        case .c1540:
            return "1540"
        case .c1541:
            return "1541"
        case .c1541II:
            return "1541-II"
        case .c1551:
            return "1551"
        case .c1570:
            return "1570"
        case .c1571:
            return "1571"
        case .c1581:
            return "1581"
        case .fd2000:
            return "FD-2000"
        case .fd4000:
            return "FD-4000"
        case .c2031:
            return "2031"
        case .c2040:
            return "2040"
        case .c3040:
            return "3040"
        case .c4040:
            return "4040"
        case .sfd1001:
            return "SFD-1001"
        case .c8050:
            return "8050"
        case .c8250:
            return "8250"
        case .d9090d9060:
            return "D9090/D9060"
        case .cmdHD:
            return "CMD HD"
        }
    }

    var defaultStorageKind: DriveStorageKind {
        isHardDriveImage ? .hardDriveImage : .diskImage
    }

    var isHardDriveImage: Bool {
        switch self {
        case .d9090d9060, .cmdHD:
            return true
        default:
            return false
        }
    }

    var busTitle: String {
        switch self {
        case .c1551:
            return "TCBM"
        case .c2031, .c2040, .c3040, .c4040, .sfd1001, .c8050, .c8250, .d9090d9060:
            return "IEEE-488"
        default:
            return "IEC serial"
        }
    }

    var slotCount: Int {
        switch self {
        case .c2040, .c3040, .c4040, .c8050, .c8250:
            return 2
        default:
            return 1
        }
    }

    var driveNumbers: [Int] {
        Array(0..<slotCount)
    }

    var defaultLEDColor: DriveLEDColor {
        ledColor(forDriveNumber: 0)
    }

    func ledColor(forDriveNumber driveNumber: Int) -> DriveLEDColor {
        switch self {
        case .c1540, .c1541, .c1551, .c1570, .c2031, .c2040, .c3040, .c4040, .sfd1001, .d9090d9060:
            return .red
        case .c8050:
            return .green
        case .c8250:
            return driveNumber == 0 ? .red : .green
        case .c1541II, .c1571, .c1581, .fd2000, .fd4000, .cmdHD:
            return .green
        }
    }

    var supportedDiskImageTypes: [DiskImageFileType] {
        switch self {
        case .c1540, .c1541, .c1541II, .c1551, .c1570:
            return [.d64, .d67, .g64, .p64, .x64]
        case .c1571:
            return [.d64, .d67, .d71, .g64, .g71, .p64, .x64]
        case .c1581:
            return [.d81]
        case .fd2000, .fd4000:
            return [.d81, .d1m, .d2m, .d4m]
        case .c2031, .c2040, .c3040, .c4040:
            return [.d64, .d67]
        case .sfd1001, .c8050, .c8250:
            return [.d80, .d82]
        case .d9090d9060:
            return [.d90]
        case .cmdHD:
            return [.dhd]
        }
    }

    var supportedDiskImageDescription: String {
        supportedDiskImageTypes.map(\.title).joined(separator: ", ")
    }

    func supportsDiskImage(_ type: DiskImageFileType) -> Bool {
        supportedDiskImageTypes.contains(type)
    }

    func supportsDiskImage(url: URL) -> Bool {
        guard let fileType = DiskImageFileType(url: url) else {
            return false
        }

        return supportsDiskImage(fileType)
    }
}

extension MachineCapabilities {
    var supportedStorageKinds: [DriveStorageKind] {
        var kinds: [DriveStorageKind] = [.diskImage]

        if !hardDriveImageTypes.isEmpty {
            kinds.append(.hardDriveImage)
        }

        kinds.append(.sharedFolder)
        return kinds
    }

    var diskImageTypes: [DriveType] {
        driveTypes.filter { !$0.isHardDriveImage }
    }

    var hardDriveImageTypes: [DriveType] {
        driveTypes.filter(\.isHardDriveImage)
    }

    func driveTypes(for storageKind: DriveStorageKind) -> [DriveType] {
        switch storageKind {
        case .diskImage:
            return diskImageTypes
        case .hardDriveImage:
            return hardDriveImageTypes
        case .sharedFolder:
            return driveTypes
        }
    }

    func defaultDriveType(for storageKind: DriveStorageKind, fallback: DriveType) -> DriveType {
        let candidates = driveTypes(for: storageKind)

        if candidates.contains(fallback) {
            return fallback
        }

        return candidates.first ?? defaultDriveType
    }
}

enum DiskImageFileType: String, CaseIterable, Identifiable {
    case d64
    case d67
    case d71
    case d80
    case d81
    case d82
    case d90
    case d1m
    case d2m
    case d4m
    case dhd
    case g64
    case g71
    case p64
    case x64

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }

    init?(url: URL) {
        self.init(rawValue: url.pathExtension.lowercased())
    }
}

enum DriveLEDColor: Equatable {
    case red
    case green

    init(viceColor: UInt32) {
        self = (viceColor & 1) == 1 ? .green : .red
    }
}

struct DriveActivity: Identifiable, Equatable {
    let unit: Int
    var isConfigured: Bool
    var storageKind: DriveStorageKind = .diskImage
    var sharedFolderPath: String?
    var driveType: DriveType
    var accessMode: DriveAccessMode
    var activeDriveNumber: Int
    var slots: [DriveSlotActivity]
    var ledColor: DriveLEDColor
    var ledIntensity: UInt32
    var errorIntensity: UInt32
    var track: UInt32?
    var halfTrack: UInt32?
    var diskSide: UInt32
    var driveStatusCode: Int32
    var driveStatusText: String?
    var imagePath: String?

    var id: Int { unit }
    var isActive: Bool { ledIntensity > 0 }
    var isSharedFolder: Bool { storageKind == .sharedFolder }
    var isFastAccessEnabled: Bool { !isSharedFolder && accessMode == .fast }
    var hasErrorStatus: Bool {
        driveStatusCode != DriveStatusCode.ok
            && driveStatusCode != DriveStatusCode.dosVersion
    }
    var hasMultipleSlots: Bool { !isSharedFolder && driveType.slotCount > 1 }
    var sharedFolderURL: URL? {
        guard let sharedFolderPath else {
            return nil
        }

        return URL(fileURLWithPath: sharedFolderPath)
    }

    var headPositionText: String? {
        guard let track else {
            return nil
        }

        return "T\(Self.paddedHeadValue(track))"
    }

    var headDetailText: String? {
        guard let track else {
            return nil
        }

        var components = ["Track \(Self.paddedHeadValue(track))"]
        if let halfTrack, halfTrack != 0 {
            components.append("+\(halfTrack)/2")
        }
        if diskSide > 0 {
            components.append("Side \(diskSide + 1)")
        }
        return components.joined(separator: " ")
    }

    var resolvedStatusText: String {
        if isSharedFolder {
            return sharedFolderPath == nil ? "Choose folder" : "Shared folder ready"
        }

        if let driveStatusText,
           !driveStatusText.isEmpty {
            if !hasErrorStatus {
                return "Ready"
            }

            return driveStatusText
        }

        if hasErrorStatus {
            return "Error \(driveStatusCode)"
        }

        return hasDiskImage ? "Ready" : "No disk"
    }

    var hasDiskImage: Bool {
        slots.contains { $0.hasDiskImage }
    }

    private static func paddedHeadValue(_ value: UInt32) -> String {
        String(format: "%02u", value)
    }
}

struct DriveSlotActivity: Identifiable, Equatable {
    let driveNumber: Int
    var ledColor: DriveLEDColor
    var ledIntensity: UInt32
    var imagePath: String?

    var id: Int { driveNumber }
    var isActive: Bool { ledIntensity > 0 }
    var hasDiskImage: Bool { imagePath?.isEmpty == false }
}

private enum DriveStatusCode {
    static let ok: Int32 = 0
    static let dosVersion: Int32 = 73
}
