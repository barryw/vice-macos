import Foundation

enum EmulatorMediaFile: Equatable {
    case disk(DiskImageFileType)
    case autostart(AutostartMediaFileType)
    case cartridge(CartridgeImageFileType)
    case snapshot(SnapshotFileType)

    init?(url: URL) {
        if let snapshotType = SnapshotFileType(url: url) {
            self = .snapshot(snapshotType)
            return
        }

        if let diskImageType = DiskImageFileType(url: url) {
            self = .disk(diskImageType)
            return
        }

        if let autostartMediaType = AutostartMediaFileType(url: url) {
            self = .autostart(autostartMediaType)
            return
        }

        if let cartridgeImageType = CartridgeImageFileType(url: url) {
            self = .cartridge(cartridgeImageType)
            return
        }

        return nil
    }

    var title: String {
        switch self {
        case let .disk(type):
            return "\(type.title) disk image"
        case let .autostart(type):
            return type.title
        case let .cartridge(type):
            return "\(type.title) cartridge"
        case let .snapshot(type):
            return "\(type.title) snapshot"
        }
    }

    static func supportedFilenameExtensions(for machine: EmulatedMachine) -> [String] {
        var extensions = Set(machine.capabilities.driveTypes
            .flatMap(\.supportedDiskImageTypes)
            .map(\.rawValue))

        extensions.formUnion(AutostartMediaFileType.allCases.map(\.rawValue))
        if machine.capabilities.supportsCartridges {
            extensions.formUnion(CartridgeImageFileType.allCases.map(\.rawValue))
        }
        extensions.formUnion(SnapshotFileType.allCases.map(\.rawValue))

        return extensions.sorted()
    }
}

enum MediaOpenBehavior: String, CaseIterable, Codable, Identifiable {
    case attach
    case load
    case run

    var id: String { rawValue }

    var title: String {
        switch self {
        case .attach:
            return "Attach"
        case .load:
            return "Load"
        case .run:
            return "Run"
        }
    }

    var detail: String {
        switch self {
        case .attach:
            return "Insert disks and tapes without typing a command."
        case .load:
            return "Load programs and leave them ready at the prompt."
        case .run:
            return "Load programs and start them automatically."
        }
    }

    var systemImage: String {
        switch self {
        case .attach:
            return "externaldrive"
        case .load:
            return "arrow.down.doc"
        case .run:
            return "play.fill"
        }
    }

    var viceRunMode: Int32 {
        switch self {
        case .attach:
            return -1
        case .run:
            return 0
        case .load:
            return 1
        }
    }

    var statusVerb: String {
        switch self {
        case .attach:
            return "attached"
        case .load:
            return "loading"
        case .run:
            return "started"
        }
    }
}

struct MediaBehaviorConfiguration: Codable, Equatable {
    var openBehavior: MediaOpenBehavior
    var warpDuringAutostart: Bool
    var useTrueDriveDuringAutostart: Bool

    static let standard = MediaBehaviorConfiguration(openBehavior: .attach,
                                                     warpDuringAutostart: true,
                                                     useTrueDriveDuringAutostart: false)

    init(openBehavior: MediaOpenBehavior,
         warpDuringAutostart: Bool,
         useTrueDriveDuringAutostart: Bool) {
        self.openBehavior = openBehavior
        self.warpDuringAutostart = warpDuringAutostart
        self.useTrueDriveDuringAutostart = useTrueDriveDuringAutostart
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.standard

        openBehavior = try container.decodeIfPresent(MediaOpenBehavior.self, forKey: .openBehavior)
            ?? defaults.openBehavior
        warpDuringAutostart = try container.decodeIfPresent(Bool.self, forKey: .warpDuringAutostart)
            ?? defaults.warpDuringAutostart
        useTrueDriveDuringAutostart = try container.decodeIfPresent(Bool.self, forKey: .useTrueDriveDuringAutostart)
            ?? defaults.useTrueDriveDuringAutostart
    }
}

struct SnapshotConfiguration: Codable, Equatable {
    var includesROMImages: Bool
    var includesAttachedDisks: Bool

    static let standard = SnapshotConfiguration(includesROMImages: true,
                                                includesAttachedDisks: true)

    init(includesROMImages: Bool,
         includesAttachedDisks: Bool) {
        self.includesROMImages = includesROMImages
        self.includesAttachedDisks = includesAttachedDisks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.standard

        includesROMImages = try container.decodeIfPresent(Bool.self, forKey: .includesROMImages)
            ?? defaults.includesROMImages
        includesAttachedDisks = try container.decodeIfPresent(Bool.self, forKey: .includesAttachedDisks)
            ?? defaults.includesAttachedDisks
    }

    var summaryTitle: String {
        switch (includesROMImages, includesAttachedDisks) {
        case (true, true):
            return "Machine state, ROM images, and attached disks"
        case (true, false):
            return "Machine state and ROM images"
        case (false, true):
            return "Machine state and attached disks"
        case (false, false):
            return "Machine state only"
        }
    }
}

struct SessionBehaviorConfiguration: Codable, Equatable {
    var pauseWhenAppInactive: Bool

    static let standard = SessionBehaviorConfiguration(pauseWhenAppInactive: false)

    init(pauseWhenAppInactive: Bool) {
        self.pauseWhenAppInactive = pauseWhenAppInactive
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pauseWhenAppInactive = try container.decodeIfPresent(Bool.self, forKey: .pauseWhenAppInactive)
            ?? Self.standard.pauseWhenAppInactive
    }
}

enum PrinterEmulationModel: String, CaseIterable, Codable, Identifiable {
    case mps803
    case nl10
    case ascii
    case raw

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mps803:
            return "Commodore MPS-803"
        case .nl10:
            return "Star NL-10"
        case .ascii:
            return "ASCII"
        case .raw:
            return "Raw"
        }
    }

    var shortTitle: String {
        switch self {
        case .mps803:
            return "MPS-803"
        case .nl10:
            return "NL-10"
        case .ascii:
            return "ASCII"
        case .raw:
            return "Raw"
        }
    }

    var geosDriverTitle: String {
        switch self {
        case .mps803:
            return "MPS-803"
        case .nl10:
            return "Star NL-10(com)"
        case .ascii:
            return "Commodore compatible"
        case .raw:
            return "Raw device output"
        }
    }

    var viceDriverName: String {
        rawValue
    }

    var outputMode: String {
        switch self {
        case .ascii, .raw:
            return "text"
        case .mps803, .nl10:
            return "graphics"
        }
    }

    var supportsPagePreview: Bool {
        outputMode == "graphics"
    }
}

struct PrinterConfiguration: Codable, Equatable {
    var isEnabled: Bool
    var deviceNumber: Int
    var model: PrinterEmulationModel

    static let standard = PrinterConfiguration(isEnabled: false,
                                               deviceNumber: 4,
                                               model: .mps803)

    init(isEnabled: Bool,
         deviceNumber: Int,
         model: PrinterEmulationModel) {
        self.isEnabled = isEnabled
        self.deviceNumber = Self.normalizedDeviceNumber(deviceNumber)
        self.model = model
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.standard

        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled)
            ?? defaults.isEnabled
        deviceNumber = Self.normalizedDeviceNumber(try container.decodeIfPresent(Int.self, forKey: .deviceNumber)
                                                   ?? defaults.deviceNumber)
        model = try container.decodeIfPresent(PrinterEmulationModel.self, forKey: .model)
            ?? defaults.model
    }

    var statusTitle: String {
        isEnabled ? "\(model.shortTitle) on device \(deviceNumber)" : "Off"
    }

    var geosDriverTitle: String {
        model.geosDriverTitle
    }

    var canPreviewPages: Bool {
        isEnabled && model.supportsPagePreview
    }

    private static func normalizedDeviceNumber(_ deviceNumber: Int) -> Int {
        switch deviceNumber {
        case 4...6:
            return deviceNumber
        default:
            return 4
        }
    }
}

struct PrinterSpoolPage: Identifiable, Equatable {
    static let filenamePrefix = "geos-print"

    let url: URL
    let byteCount: Int
    let modifiedAt: Date

    var id: String {
        url.path
    }

    var displayName: String {
        url.deletingPathExtension().lastPathComponent
    }

    var detailTitle: String {
        "\(byteCount.formatted(.byteCount(style: .file))) - \(modifiedAt.formatted(date: .abbreviated, time: .shortened))"
    }
}

enum SIDLayout: String, CaseIterable, Codable, Identifiable {
    case single
    case stereo
    case triple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single:
            return "Single SID"
        case .stereo:
            return "Stereo SID"
        case .triple:
            return "Triple SID"
        }
    }

    var shortTitle: String {
        switch self {
        case .single:
            return "Single"
        case .stereo:
            return "Stereo"
        case .triple:
            return "Triple"
        }
    }

    var extraSIDCount: Int32 {
        switch self {
        case .single:
            return 0
        case .stereo:
            return 1
        case .triple:
            return 2
        }
    }
}

enum SIDAddressPreset: Int32, CaseIterable, Codable, Identifiable {
    case d420 = 0xd420
    case d500 = 0xd500
    case d600 = 0xd600
    case d700 = 0xd700
    case de00 = 0xde00
    case df00 = 0xdf00

    var id: Int32 { rawValue }

    var title: String {
        String(format: "$%04X", rawValue)
    }
}

struct SIDConfiguration: Codable, Equatable {
    var layout: SIDLayout
    var secondAddress: SIDAddressPreset
    var thirdAddress: SIDAddressPreset

    static let standard = SIDConfiguration(layout: .single,
                                           secondAddress: .d420,
                                           thirdAddress: .de00)

    init(layout: SIDLayout,
         secondAddress: SIDAddressPreset,
         thirdAddress: SIDAddressPreset) {
        self.layout = layout
        self.secondAddress = secondAddress
        self.thirdAddress = thirdAddress
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.standard

        layout = try container.decodeIfPresent(SIDLayout.self, forKey: .layout) ?? defaults.layout
        secondAddress = try container.decodeIfPresent(SIDAddressPreset.self, forKey: .secondAddress)
            ?? defaults.secondAddress
        thirdAddress = try container.decodeIfPresent(SIDAddressPreset.self, forKey: .thirdAddress)
            ?? defaults.thirdAddress
    }
}

enum TapeControlCommand: Int32, CaseIterable, Identifiable {
    case stop = 0
    case play = 1
    case fastForward = 2
    case rewind = 3
    case record = 4
    case reset = 5
    case resetCounter = 6

    var id: Int32 { rawValue }

    var title: String {
        switch self {
        case .stop:
            return "Stop"
        case .play:
            return "Play"
        case .fastForward:
            return "Fast Forward"
        case .rewind:
            return "Rewind"
        case .record:
            return "Record"
        case .reset:
            return "Reset"
        case .resetCounter:
            return "Reset Counter"
        }
    }

    var systemImage: String {
        switch self {
        case .stop:
            return "stop.fill"
        case .play:
            return "play.fill"
        case .fastForward:
            return "forward.fill"
        case .rewind:
            return "backward.fill"
        case .record:
            return "record.circle"
        case .reset:
            return "arrow.counterclockwise"
        case .resetCounter:
            return "gauge.with.dots.needle.33percent"
        }
    }
}

struct TapeConfiguration: Codable, Equatable {
    private static let viceSoundVolumeMax = 4096

    var isDatasetteEnabled: Bool
    var soundEnabled: Bool
    var soundVolume: Int

    static let standard = TapeConfiguration(isDatasetteEnabled: true,
                                            soundEnabled: false,
                                            soundVolume: 25)

    init(isDatasetteEnabled: Bool,
         soundEnabled: Bool,
         soundVolume: Int) {
        self.isDatasetteEnabled = isDatasetteEnabled
        self.soundEnabled = soundEnabled
        self.soundVolume = Self.normalizedSoundVolumePercent(soundVolume)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = Self.standard

        isDatasetteEnabled = try container.decodeIfPresent(Bool.self, forKey: .isDatasetteEnabled)
            ?? defaults.isDatasetteEnabled
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled)
            ?? defaults.soundEnabled
        soundVolume = Self.soundVolumePercent(fromStoredValue: try container.decodeIfPresent(Int.self, forKey: .soundVolume)
                                              ?? defaults.soundVolume)
    }

    var viceSoundVolume: Int32 {
        Int32(Self.viceSoundVolume(fromPercent: soundVolume))
    }

    static func normalizedSoundVolumePercent(_ volume: Int) -> Int {
        min(max(volume, 0), 100)
    }

    private static func soundVolumePercent(fromStoredValue volume: Int) -> Int {
        if volume > 100 {
            return normalizedSoundVolumePercent((volume * 100 + (viceSoundVolumeMax / 2)) / viceSoundVolumeMax)
        }

        return normalizedSoundVolumePercent(volume)
    }

    private static func viceSoundVolume(fromPercent percent: Int) -> Int {
        min(max(percent, 0), 100) * viceSoundVolumeMax / 100
    }
}

enum AutostartMediaFileType: String, CaseIterable, Identifiable {
    case prg
    case t64
    case tap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .prg:
            return "PRG program"
        case .t64:
            return "T64 tape archive"
        case .tap:
            return "TAP tape image"
        }
    }

    init?(url: URL) {
        self.init(rawValue: url.pathExtension.lowercased())
    }
}

enum SnapshotFileType: String, CaseIterable, Identifiable {
    case vsf

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }

    init?(url: URL) {
        self.init(rawValue: url.pathExtension.lowercased())
    }
}

enum CartridgeImageFileType: String, CaseIterable, Identifiable {
    case crt

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }

    init?(url: URL) {
        self.init(rawValue: url.pathExtension.lowercased())
    }
}

struct ROMImageConfiguration: Codable, Equatable {
    private var paths: [String: String]

    static let standard = ROMImageConfiguration(paths: [:])

    init(paths: [String: String] = [:]) {
        self.paths = paths
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let paths = try container.decodeIfPresent([String: String].self, forKey: .paths) {
            self.paths = paths
            return
        }

        var legacyPaths: [String: String] = [:]
        if let basicPath = try container.decodeIfPresent(String.self, forKey: .basicPath) {
            legacyPaths[MachineROMSlot.c64Basic.id] = basicPath
        }
        if let kernalPath = try container.decodeIfPresent(String.self, forKey: .kernalPath) {
            legacyPaths[MachineROMSlot.c64Kernal.id] = kernalPath
        }
        if let characterPath = try container.decodeIfPresent(String.self, forKey: .characterPath) {
            legacyPaths[MachineROMSlot.c64Character.id] = characterPath
        }
        paths = legacyPaths
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(paths, forKey: .paths)
    }

    func path(for slot: MachineROMSlot) -> String? {
        paths[slot.id]
    }

    func resourceValue(for slot: MachineROMSlot) -> String {
        path(for: slot) ?? slot.defaultFileName
    }

    mutating func setPath(_ path: String?, for slot: MachineROMSlot) {
        let normalizedPath = path?.isEmpty == false ? path : nil
        paths[slot.id] = normalizedPath
    }

    private enum CodingKeys: String, CodingKey {
        case paths
        case basicPath
        case kernalPath
        case characterPath
    }
}

struct CartridgeStatus: Equatable {
    var isAttached: Bool
    var cartridgeID: Int32
    var cartridgeFlags: UInt32
    var romSize: UInt32
    var chipCount: UInt32
    var bankCount: UInt32
    var cartridgeName: String?
    var imagePath: String?

    static let detached = CartridgeStatus(isAttached: false,
                                          cartridgeID: -1,
                                          cartridgeFlags: 0,
                                          romSize: 0,
                                          chipCount: 0,
                                          bankCount: 0,
                                          cartridgeName: nil,
                                          imagePath: nil)
}
