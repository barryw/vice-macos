import AppKit
import Combine
import Foundation

struct DriveConfiguration: Identifiable, Codable, Equatable {
    let unit: Int
    var isAttached: Bool
    var driveType: DriveType
    var soundEnabled: Bool
    var soundVolume: Int

    var id: Int { unit }
}

enum DriveType: Int32, CaseIterable, Codable, Identifiable {
    case c1540 = 1540
    case c1541 = 1541
    case c1541II = 1542
    case c1570 = 1570
    case c1571 = 1571
    case c1581 = 1581
    case fd2000 = 2000
    case fd4000 = 4000
    case cmdHD = 4844

    var id: Int32 { rawValue }

    var title: String {
        switch self {
        case .c1540:
            return "1540"
        case .c1541:
            return "1541"
        case .c1541II:
            return "1541-II"
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
        case .cmdHD:
            return "CMD HD"
        }
    }

    var defaultLEDColor: DriveLEDColor {
        switch self {
        case .c1540, .c1541, .c1570:
            return .red
        case .c1541II, .c1571, .c1581, .fd2000, .fd4000, .cmdHD:
            return .green
        }
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
    var driveType: DriveType
    var ledColor: DriveLEDColor
    var ledIntensity: UInt32
    var errorIntensity: UInt32
    var driveStatusCode: Int32
    var driveStatusText: String?
    var imagePath: String?

    var id: Int { unit }
    var isActive: Bool { ledIntensity > 0 }
    var hasErrorStatus: Bool {
        errorIntensity > 0 || (driveStatusCode != DriveStatusCode.ok
            && driveStatusCode != DriveStatusCode.dosVersion)
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

private enum DriveStatusCode {
    static let ok: Int32 = 0
    static let dosVersion: Int32 = 73
}

enum MachineResetKind {
    case soft
    case hard

    var title: String {
        switch self {
        case .soft:
            return "Soft Reset"
        case .hard:
            return "Hard Reset"
        }
    }

    var statusText: String {
        switch self {
        case .soft:
            return "Soft reset queued"
        case .hard:
            return "Hard reset queued"
        }
    }
}

@MainActor
final class EmulatorSession: ObservableObject {
    @Published var isPaused = false {
        didSet {
            guard isPaused != oldValue else {
                return
            }

            applyPauseState()
        }
    }
    @Published var emulationSpeed: EmulationSpeed {
        didSet {
            guard emulationSpeed != oldValue else {
                return
            }

            EmulatorDefaults.saveEmulationSpeed(emulationSpeed)
            applyEmulationSpeed()
        }
    }
    @Published var displayMode: DisplayMode {
        didSet {
            guard displayMode != oldValue else {
                return
            }

            EmulatorDefaults.saveDisplayMode(displayMode)
            statusText = "Display \(displayMode.title)"
        }
    }
    @Published var videoStandard: VideoStandard {
        didSet {
            guard videoStandard != oldValue else {
                return
            }

            EmulatorDefaults.saveVideoStandard(videoStandard)
            applyVideoStandard()
        }
    }
    @Published var sidModel: SIDModel {
        didSet {
            guard sidModel != oldValue else {
                return
            }

            EmulatorDefaults.saveSIDModel(sidModel)
            applySIDModel()
        }
    }
    @Published var soundEnabled: Bool {
        didSet {
            guard soundEnabled != oldValue else {
                return
            }

            EmulatorDefaults.saveSoundEnabled(soundEnabled)
            applySoundSettings()
        }
    }
    @Published var soundVolume: Int {
        didSet {
            let clampedVolume = min(max(soundVolume, 0), 100)
            guard soundVolume == clampedVolume else {
                soundVolume = clampedVolume
                return
            }

            guard soundVolume != oldValue else {
                return
            }

            EmulatorDefaults.saveSoundVolume(soundVolume)
            applySoundSettings()
        }
    }
    @Published var driveConfigurations: [DriveConfiguration] {
        didSet {
            EmulatorDefaults.saveDriveConfigurations(driveConfigurations)
            applyDriveConfigurations()
        }
    }
    @Published private var driveActivities: [Int: DriveActivity] = [:]
    @Published var cartridgeStatus = CartridgeStatus.detached
    @Published var filterSettings = VideoFilterSettings()
    @Published var statusText = "Starting x64sc"

    let frameSource = EmulatorFrameSource.x64scReady()
    private var didStartEngine = false
    private var pressedKeys: [UInt16: PressedEmulatorKey] = [:]

    enum DisplayMode: String, CaseIterable, Identifiable {
        case native
        case fit
        case stretch

        var id: String { rawValue }

        var title: String {
            switch self {
            case .native:
                return "Actual Size"
            case .fit:
                return "Fit to Window"
            case .stretch:
                return "Stretch to Window"
            }
        }

        var toolbarTitle: String {
            switch self {
            case .native:
                return "Actual"
            case .fit:
                return "Fit"
            case .stretch:
                return "Stretch"
            }
        }

        var systemImage: String {
            switch self {
            case .native:
                return "rectangle.center.inset.filled"
            case .fit:
                return "arrow.up.left.and.arrow.down.right"
            case .stretch:
                return "arrow.left.and.right"
            }
        }

        var preservesAspectRatio: Bool {
            self != .stretch
        }
    }

    enum VideoStandard: String, CaseIterable, Identifiable {
        case ntsc = "NTSC"
        case pal = "PAL"

        var id: String { rawValue }

        var viciiModelResourceValue: Int32 {
            switch self {
            case .ntsc:
                return ViceVICIIModel.mos8562
            case .pal:
                return ViceVICIIModel.mos8565
            }
        }

        var powerFrequency: Int32 {
            switch self {
            case .ntsc:
                return 60
            case .pal:
                return 50
            }
        }
    }

    enum SIDModel: Int32, CaseIterable, Identifiable {
        case mos6581 = 0
        case mos8580 = 1

        var id: Int32 { rawValue }

        var title: String {
            switch self {
            case .mos6581:
                return "6581"
            case .mos8580:
                return "8580"
            }
        }
    }

    enum EmulationSpeed: String, CaseIterable, Identifiable {
        case normal
        case double
        case quadruple
        case octuple
        case uncapped

        var id: String { rawValue }

        var title: String {
            switch self {
            case .normal:
                return "100%"
            case .double:
                return "200%"
            case .quadruple:
                return "400%"
            case .octuple:
                return "800%"
            case .uncapped:
                return "Uncapped"
            }
        }

        var toolbarTitle: String {
            switch self {
            case .uncapped:
                return "Warp"
            default:
                return title
            }
        }

        var speedPercent: Int32 {
            switch self {
            case .normal, .uncapped:
                return 100
            case .double:
                return 200
            case .quadruple:
                return 400
            case .octuple:
                return 800
            }
        }

        var isWarpEnabled: Bool {
            self == .uncapped
        }
    }

    init() {
        videoStandard = EmulatorDefaults.loadVideoStandard()
        emulationSpeed = EmulatorDefaults.loadEmulationSpeed()
        displayMode = EmulatorDefaults.loadDisplayMode()
        sidModel = EmulatorDefaults.loadSIDModel()
        soundEnabled = EmulatorDefaults.loadSoundEnabled()
        soundVolume = EmulatorDefaults.loadSoundVolume()
        driveConfigurations = EmulatorDefaults.loadDriveConfigurations()
    }

    var visibleDriveActivities: [DriveActivity] {
        driveConfigurations.compactMap { configuration in
            guard configuration.isAttached else {
                return nil
            }

            if let activity = driveActivities[configuration.unit],
               activity.isConfigured {
                return activity
            }

            return DriveActivity(unit: configuration.unit,
                                 isConfigured: true,
                                 driveType: configuration.driveType,
                                 ledColor: configuration.driveType.defaultLEDColor,
                                 ledIntensity: 0,
                                 errorIntensity: 0,
                                 driveStatusCode: 0,
                                 driveStatusText: nil,
                                 imagePath: nil)
        }
    }

    func start() {
        guard !didStartEngine else {
            return
        }

        guard let executablePath = Bundle.main.executableURL?.path,
              let dataDirectory = Bundle.main.resourceURL?.appendingPathComponent("VICEData").path else {
            statusText = "Missing runtime paths"
            return
        }

        didStartEngine = true
        ViceEngineSetVideoFrameCallback(viceFrameCallback,
                                        Unmanaged.passUnretained(frameSource).toOpaque())
        ViceEngineSetDriveStatusCallback(viceDriveStatusCallback,
                                         Unmanaged.passUnretained(self).toOpaque())
        ViceEngineSetCartridgeStatusCallback(viceCartridgeStatusCallback,
                                             Unmanaged.passUnretained(self).toOpaque())

        let started = executablePath.withCString { executablePathPointer in
            dataDirectory.withCString { dataDirectoryPointer in
                ViceEngineStartX64SC(executablePathPointer,
                                      dataDirectoryPointer,
                                      sidModel.rawValue,
                                      soundEnabled,
                                      Int32(soundVolume),
                                      emulationSpeed.speedPercent,
                                      emulationSpeed.isWarpEnabled)
            }
        }

        if started || ViceEngineIsRunning() {
            applyRuntimeConfiguration()
        }

        statusText = started ? "x64sc running" : "x64sc already running"
    }

    func reset(kind: MachineResetKind = .soft) {
        guard ViceEngineIsRunning() else {
            return
        }

        if isPaused {
            isPaused = false
        }

        _ = ViceEngineTriggerMachineReset(kind == .hard)
        statusText = kind.statusText
    }

    func togglePause() {
        isPaused.toggle()
    }

    func applyFilterPreset(_ preset: VideoFilterPreset) {
        filterSettings = VideoFilterSettings.defaults(for: preset)
        statusText = "\(preset.rawValue) filter"
    }

    @discardableResult
    func handleKeyEvent(_ event: NSEvent, pressed: Bool) -> Bool {
        if !pressed, let existingKey = pressedKeys.removeValue(forKey: event.keyCode) {
            ViceEngineSendKeyEvent(existingKey.symbol, existingKey.modifiers, false)
            return true
        }

        if !pressed {
            return false
        }

        if event.isARepeat {
            return true
        }

        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command) {
            return false
        }

        guard let symbol = ViceMacKeyMapper.symbol(for: event) else {
            return false
        }

        let modifiers = ViceMacKeyMapper.modifiers(for: event)
        if let existingKey = pressedKeys.updateValue(PressedEmulatorKey(symbol: symbol, modifiers: modifiers),
                                                     forKey: event.keyCode) {
            ViceEngineSendKeyEvent(existingKey.symbol, existingKey.modifiers, false)
        }

        ViceEngineSendKeyEvent(symbol, modifiers, true)
        return true
    }

    @discardableResult
    func handleFlagsChanged(_ event: NSEvent) -> Bool {
        guard let modifierKey = ViceMacKeyMapper.modifierKey(for: event) else {
            return false
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command), pressedKeys[event.keyCode] == nil {
            return false
        }

        if modifierKey.isToggle {
            ViceEngineSendKeyEvent(modifierKey.symbol, modifierKey.modifiers, true)
            ViceEngineSendKeyEvent(modifierKey.symbol, modifierKey.modifiers, false)
            return true
        }

        if let existingKey = pressedKeys.removeValue(forKey: event.keyCode) {
            ViceEngineSendKeyEvent(existingKey.symbol, existingKey.modifiers, false)
        } else {
            pressedKeys[event.keyCode] = PressedEmulatorKey(symbol: modifierKey.symbol,
                                                            modifiers: modifierKey.modifiers)
            ViceEngineSendKeyEvent(modifierKey.symbol, modifierKey.modifiers, true)
        }

        return true
    }

    func releaseAllKeys() {
        pressedKeys.removeAll()
        ViceEngineReleaseAllKeys()
    }

    func handleDriveStatus(_ status: DriveStatusSnapshot) {
        guard let driveType = DriveType(rawValue: status.driveType) else {
            driveActivities.removeValue(forKey: status.unit)
            return
        }

        driveActivities[status.unit] = DriveActivity(unit: status.unit,
                                                          isConfigured: status.enabled,
                                                          driveType: driveType,
                                                          ledColor: DriveLEDColor(viceColor: status.ledColor),
                                                          ledIntensity: status.ledIntensity,
                                                          errorIntensity: status.errorIntensity,
                                                          driveStatusCode: status.driveStatusCode,
                                                          driveStatusText: status.driveStatusText,
                                                          imagePath: status.imagePath)
    }

    func handleCartridgeStatus(_ status: CartridgeStatusSnapshot) {
        cartridgeStatus = CartridgeStatus(isAttached: status.isAttached,
                                          cartridgeID: status.cartridgeID,
                                          cartridgeFlags: status.cartridgeFlags,
                                          romSize: status.romSize,
                                          chipCount: status.chipCount,
                                          bankCount: status.bankCount,
                                          cartridgeName: status.cartridgeName,
                                          imagePath: status.imagePath)
    }

    func resetDrive(_ unit: Int) {
        guard unit >= 8 && unit <= 11 else {
            return
        }

        _ = ViceEngineResetDrive(UInt32(unit))
    }

    func attachDisk(to unit: Int, url: URL, autorun: Bool) {
        guard unit >= 8 && unit <= 11 else {
            return
        }

        url.path.withCString { path in
            _ = ViceEngineAttachDisk(UInt32(unit), path, autorun)
        }
    }

    func attachCartridge(url: URL) {
        url.path.withCString { path in
            _ = ViceEngineAttachCartridge(path)
        }
    }

    func detachCartridge() {
        _ = ViceEngineDetachCartridge()
    }

    private func applyRuntimeConfiguration() {
        applyVideoStandard(updateStatus: false)
        applySIDModel(updateStatus: false)
        applySoundSettings(updateStatus: false)
        applyEmulationSpeed(updateStatus: false)
        applyPauseState(updateStatus: false)
        applyDriveConfigurations(updateStatus: false)
    }

    private func applyPauseState(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
            return
        }

        _ = ViceEngineSetPauseEnabled(isPaused)

        if updateStatus {
            statusText = isPaused ? "Paused" : "Running"
        }
    }

    private func applyVideoStandard(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
            return
        }

        setVICEIntResource(ViceResource.viciiModel, value: videoStandard.viciiModelResourceValue)
        setVICEIntResource(ViceResource.machinePowerFrequency, value: videoStandard.powerFrequency)

        if updateStatus {
            statusText = "Video \(videoStandard.rawValue)"
        }
    }

    private func applySIDModel(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
            return
        }

        ViceResource.sidModel.withCString { resourceName in
            _ = ViceEngineSetIntResource(resourceName, sidModel.rawValue)
        }

        if updateStatus {
            statusText = "SID \(sidModel.title)"
        }
    }

    private func applyEmulationSpeed(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
            return
        }

        setVICEIntResource(ViceResource.speed, value: emulationSpeed.speedPercent)
        _ = ViceEngineSetWarpMode(emulationSpeed.isWarpEnabled)

        if updateStatus {
            statusText = emulationSpeed.isWarpEnabled ? "Warp enabled" : "Speed \(emulationSpeed.title)"
        }
    }

    private func applySoundSettings(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
            return
        }

        setVICEIntResource(ViceResource.sound, value: soundEnabled ? 1 : 0)
        setVICEIntResource(ViceResource.soundVolume, value: Int32(soundVolume))

        if updateStatus {
            statusText = soundEnabled ? "Volume \(soundVolume)" : "Muted"
        }
    }

    private func applyDriveConfigurations(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
            return
        }

        let driveSoundEnabled = driveConfigurations.contains { $0.soundEnabled }
        setVICEIntResource("DriveSoundEmulation", value: driveSoundEnabled ? 1 : 0)

        for configuration in driveConfigurations {
            let driveType = configuration.isAttached ? configuration.driveType.rawValue : 0
            setVICEIntResource("Drive\(configuration.unit)Type", value: driveType)
            setVICEIntResource("Drive\(configuration.unit)SoundEmulation", value: configuration.soundEnabled ? 1 : 0)
            setVICEIntResource("Drive\(configuration.unit)SoundEmulationVolume", value: Int32(configuration.soundVolume))
        }

        if updateStatus {
            statusText = "Drive settings updated"
        }
    }

    private func setVICEIntResource(_ name: String, value: Int32) {
        name.withCString { resourceName in
            _ = ViceEngineSetIntResource(resourceName, value)
        }
    }
}

private struct PressedEmulatorKey {
    let symbol: Int64
    let modifiers: Int32
}

private struct EmulatorModifierKey {
    let symbol: Int64
    let modifiers: Int32
    let isToggle: Bool
}

struct DriveStatusSnapshot {
    let unit: Int
    let enabled: Bool
    let driveType: Int32
    let ledColor: UInt32
    let ledIntensity: UInt32
    let errorIntensity: UInt32
    let driveStatusCode: Int32
    let driveStatusText: String?
    let imagePath: String?
}

struct CartridgeStatusSnapshot {
    let isAttached: Bool
    let cartridgeID: Int32
    let cartridgeFlags: UInt32
    let romSize: UInt32
    let chipCount: UInt32
    let bankCount: UInt32
    let cartridgeName: String?
    let imagePath: String?
}

private enum ViceResource {
    static let viciiModel = "VICIIModel"
    static let machinePowerFrequency = "MachinePowerFrequency"
    static let speed = "Speed"
    static let sidModel = "SidModel"
    static let sound = "Sound"
    static let soundVolume = "SoundVolume"
}

private enum ViceVICIIModel {
    static let mos8565: Int32 = 1
    static let mos8562: Int32 = 4
}

private enum EmulatorDefaults {
    private static let videoStandardKey = "vice.videoStandard"
    private static let emulationSpeedKey = "vice.emulationSpeed"
    private static let displayModeKey = "vice.displayMode"
    private static let sidModelKey = "vice.sidModel"
    private static let soundEnabledKey = "vice.soundEnabled"
    private static let soundVolumeKey = "vice.soundVolume"
    private static let driveConfigurationsKey = "vice.driveConfigurations"

    static func loadVideoStandard() -> EmulatorSession.VideoStandard {
        guard let rawValue = UserDefaults.standard.string(forKey: videoStandardKey) else {
            return .ntsc
        }

        return EmulatorSession.VideoStandard(rawValue: rawValue) ?? .ntsc
    }

    static func saveVideoStandard(_ standard: EmulatorSession.VideoStandard) {
        UserDefaults.standard.set(standard.rawValue, forKey: videoStandardKey)
    }

    static func loadEmulationSpeed() -> EmulatorSession.EmulationSpeed {
        guard let rawValue = UserDefaults.standard.string(forKey: emulationSpeedKey) else {
            return .normal
        }

        return EmulatorSession.EmulationSpeed(rawValue: rawValue) ?? .normal
    }

    static func saveEmulationSpeed(_ speed: EmulatorSession.EmulationSpeed) {
        UserDefaults.standard.set(speed.rawValue, forKey: emulationSpeedKey)
    }

    static func loadDisplayMode() -> EmulatorSession.DisplayMode {
        guard let rawValue = UserDefaults.standard.string(forKey: displayModeKey) else {
            return .native
        }

        return EmulatorSession.DisplayMode(rawValue: rawValue) ?? .native
    }

    static func saveDisplayMode(_ mode: EmulatorSession.DisplayMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: displayModeKey)
    }

    static func loadSIDModel() -> EmulatorSession.SIDModel {
        guard UserDefaults.standard.object(forKey: sidModelKey) != nil else {
            return .mos8580
        }

        let rawValue = Int32(UserDefaults.standard.integer(forKey: sidModelKey))
        return EmulatorSession.SIDModel(rawValue: rawValue) ?? .mos8580
    }

    static func saveSIDModel(_ model: EmulatorSession.SIDModel) {
        UserDefaults.standard.set(Int(model.rawValue), forKey: sidModelKey)
    }

    static func loadSoundEnabled() -> Bool {
        guard UserDefaults.standard.object(forKey: soundEnabledKey) != nil else {
            return true
        }

        return UserDefaults.standard.bool(forKey: soundEnabledKey)
    }

    static func saveSoundEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: soundEnabledKey)
    }

    static func loadSoundVolume() -> Int {
        guard UserDefaults.standard.object(forKey: soundVolumeKey) != nil else {
            return 100
        }

        return min(max(UserDefaults.standard.integer(forKey: soundVolumeKey), 0), 100)
    }

    static func saveSoundVolume(_ volume: Int) {
        UserDefaults.standard.set(min(max(volume, 0), 100), forKey: soundVolumeKey)
    }

    static func loadDriveConfigurations() -> [DriveConfiguration] {
        guard let data = UserDefaults.standard.data(forKey: driveConfigurationsKey),
              let configurations = try? JSONDecoder().decode([DriveConfiguration].self, from: data),
              configurations.map(\.unit) == [8, 9, 10, 11] else {
            return [
                DriveConfiguration(unit: 8, isAttached: true, driveType: .c1541, soundEnabled: false, soundVolume: 1000),
                DriveConfiguration(unit: 9, isAttached: false, driveType: .c1541, soundEnabled: false, soundVolume: 1000),
                DriveConfiguration(unit: 10, isAttached: false, driveType: .c1541, soundEnabled: false, soundVolume: 1000),
                DriveConfiguration(unit: 11, isAttached: false, driveType: .c1541, soundEnabled: false, soundVolume: 1000)
            ]
        }

        return configurations
    }

    static func saveDriveConfigurations(_ configurations: [DriveConfiguration]) {
        guard let data = try? JSONEncoder().encode(configurations) else {
            return
        }

        UserDefaults.standard.set(data, forKey: driveConfigurationsKey)
    }
}

private enum ViceMacKeyMapper {
    private enum Modifier {
        static let leftShift: Int32 = 1 << 0
        static let rightShift: Int32 = 1 << 1
        static let leftControl: Int32 = 1 << 2
        static let leftOption: Int32 = 1 << 4
        static let rightOption: Int32 = 1 << 5
    }

    private enum Key {
        static let backspace: Int64 = 0xff08
        static let tab: Int64 = 0xff09
        static let returnKey: Int64 = 0xff0d
        static let escape: Int64 = 0xff1b
        static let insert: Int64 = 0xff63
        static let delete: Int64 = 0xffff
        static let home: Int64 = 0xff50
        static let left: Int64 = 0xff51
        static let up: Int64 = 0xff52
        static let right: Int64 = 0xff53
        static let down: Int64 = 0xff54
        static let pageUp: Int64 = 0xff55
        static let pageDown: Int64 = 0xff56
        static let end: Int64 = 0xff57
        static let shiftLeft: Int64 = 0xffe1
        static let shiftRight: Int64 = 0xffe2
        static let controlLeft: Int64 = 0xffe3
        static let capsLock: Int64 = 0xffe5
        static let f1: Int64 = 0xffbe
    }

    private enum MacKeyCode {
        static let tab: UInt16 = 48
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let escape: UInt16 = 53
        static let delete: UInt16 = 51
        static let forwardDelete: UInt16 = 117
        static let home: UInt16 = 115
        static let end: UInt16 = 119
        static let pageUp: UInt16 = 116
        static let pageDown: UInt16 = 121
        static let leftArrow: UInt16 = 123
        static let rightArrow: UInt16 = 124
        static let downArrow: UInt16 = 125
        static let upArrow: UInt16 = 126
        static let leftShift: UInt16 = 56
        static let rightShift: UInt16 = 60
        static let capsLock: UInt16 = 57
        static let leftControl: UInt16 = 59
        static let f1: UInt16 = 122
        static let f2: UInt16 = 120
        static let f3: UInt16 = 99
        static let f4: UInt16 = 118
        static let f5: UInt16 = 96
        static let f6: UInt16 = 97
        static let f7: UInt16 = 98
        static let f8: UInt16 = 100
        static let f9: UInt16 = 101
        static let f10: UInt16 = 109
        static let f11: UInt16 = 103
        static let f12: UInt16 = 111
    }

    static func symbol(for event: NSEvent) -> Int64? {
        if let special = specialSymbol(for: event.keyCode) {
            return special
        }

        guard let scalar = event.characters?.unicodeScalars.first,
              scalar.value >= 0x20,
              scalar.value <= 0x7e else {
            return nil
        }

        return Int64(scalar.value)
    }

    static func modifiers(for event: NSEvent) -> Int32 {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: Int32 = 0

        if flags.contains(.shift) {
            modifiers |= Modifier.leftShift
        }
        if flags.contains(.control) {
            modifiers |= Modifier.leftControl
        }
        if flags.contains(.option) {
            modifiers |= Modifier.leftOption
        }

        return modifiers
    }

    static func modifierKey(for event: NSEvent) -> EmulatorModifierKey? {
        switch event.keyCode {
        case MacKeyCode.leftShift:
            return EmulatorModifierKey(symbol: Key.shiftLeft,
                                       modifiers: Modifier.leftShift,
                                       isToggle: false)
        case MacKeyCode.rightShift:
            return EmulatorModifierKey(symbol: Key.shiftRight,
                                       modifiers: Modifier.rightShift,
                                       isToggle: false)
        case MacKeyCode.leftControl:
            return EmulatorModifierKey(symbol: Key.controlLeft,
                                       modifiers: Modifier.leftControl,
                                       isToggle: false)
        case MacKeyCode.capsLock:
            return EmulatorModifierKey(symbol: Key.capsLock,
                                       modifiers: 0,
                                       isToggle: true)
        default:
            return nil
        }
    }

    private static func specialSymbol(for keyCode: UInt16) -> Int64? {
        switch keyCode {
        case MacKeyCode.tab:
            return Key.tab
        case MacKeyCode.returnKey, MacKeyCode.keypadEnter:
            return Key.returnKey
        case MacKeyCode.escape:
            return Key.escape
        case MacKeyCode.delete:
            return Key.backspace
        case MacKeyCode.forwardDelete:
            return Key.delete
        case MacKeyCode.home:
            return Key.home
        case MacKeyCode.end:
            return Key.end
        case MacKeyCode.pageUp:
            return Key.pageUp
        case MacKeyCode.pageDown:
            return Key.pageDown
        case MacKeyCode.leftArrow:
            return Key.left
        case MacKeyCode.rightArrow:
            return Key.right
        case MacKeyCode.downArrow:
            return Key.down
        case MacKeyCode.upArrow:
            return Key.up
        default:
            return functionSymbol(for: keyCode)
        }
    }

    private static func functionSymbol(for keyCode: UInt16) -> Int64? {
        switch keyCode {
        case MacKeyCode.f1:
            return Key.f1
        case MacKeyCode.f2:
            return Key.f1 + 1
        case MacKeyCode.f3:
            return Key.f1 + 2
        case MacKeyCode.f4:
            return Key.f1 + 3
        case MacKeyCode.f5:
            return Key.f1 + 4
        case MacKeyCode.f6:
            return Key.f1 + 5
        case MacKeyCode.f7:
            return Key.f1 + 6
        case MacKeyCode.f8:
            return Key.f1 + 7
        case MacKeyCode.f9:
            return Key.f1 + 8
        case MacKeyCode.f10:
            return Key.f1 + 9
        case MacKeyCode.f11:
            return Key.f1 + 10
        case MacKeyCode.f12:
            return Key.f1 + 11
        default:
            return nil
        }
    }
}

private let viceFrameCallback: @convention(c) (
    UnsafePointer<ViceEngineVideoFrame>?,
    UnsafeMutableRawPointer?
) -> Void = { framePointer, context in
    guard let framePointer,
          let context,
          framePointer.pointee.pixelFormat == 1,
          framePointer.pointee.width > 0,
          framePointer.pointee.height > 0,
          framePointer.pointee.stride >= framePointer.pointee.width * 4,
          let pixels = framePointer.pointee.pixels else {
        return
    }

    let frame = framePointer.pointee
    let byteCount = Int(frame.stride * frame.height)
    let source = Unmanaged<EmulatorFrameSource>.fromOpaque(context).takeUnretainedValue()
    let pixelData = Data(bytes: pixels, count: byteCount)

    source.publish(EmulatorVideoFrame(width: Int(frame.width),
                                      height: Int(frame.height),
                                      bytesPerRow: Int(frame.stride),
                                      sequence: frame.sequence,
                                      pixels: pixelData))
}

private let viceDriveStatusCallback: @convention(c) (
    UnsafePointer<ViceEngineDriveStatus>?,
    UnsafeMutableRawPointer?
) -> Void = { statusPointer, context in
    guard let statusPointer,
          let context else {
        return
    }

    let status = statusPointer.pointee
    let session = Unmanaged<EmulatorSession>.fromOpaque(context).takeUnretainedValue()
    let imagePath: String?
    let driveStatusText: String?

    if let imagePathPointer = status.imagePath, imagePathPointer.pointee != 0 {
        imagePath = String(cString: imagePathPointer)
    } else {
        imagePath = nil
    }

    if let driveStatusTextPointer = status.driveStatusText, driveStatusTextPointer.pointee != 0 {
        driveStatusText = String(cString: driveStatusTextPointer)
    } else {
        driveStatusText = nil
    }

    let snapshot = DriveStatusSnapshot(unit: Int(status.unit),
                                       enabled: status.enabled,
                                       driveType: status.driveType,
                                       ledColor: status.ledColor,
                                       ledIntensity: status.ledIntensity,
                                       errorIntensity: status.errorIntensity,
                                       driveStatusCode: status.driveStatusCode,
                                       driveStatusText: driveStatusText,
                                       imagePath: imagePath)

    Task { @MainActor in
        session.handleDriveStatus(snapshot)
    }
}

private let viceCartridgeStatusCallback: @convention(c) (
    UnsafePointer<ViceEngineCartridgeStatus>?,
    UnsafeMutableRawPointer?
) -> Void = { statusPointer, context in
    guard let statusPointer,
          let context else {
        return
    }

    let status = statusPointer.pointee
    let session = Unmanaged<EmulatorSession>.fromOpaque(context).takeUnretainedValue()
    let cartridgeName: String?
    let imagePath: String?

    if let cartridgeNamePointer = status.cartridgeName, cartridgeNamePointer.pointee != 0 {
        cartridgeName = String(cString: cartridgeNamePointer)
    } else {
        cartridgeName = nil
    }

    if let imagePathPointer = status.imagePath, imagePathPointer.pointee != 0 {
        imagePath = String(cString: imagePathPointer)
    } else {
        imagePath = nil
    }

    let snapshot = CartridgeStatusSnapshot(isAttached: status.attached,
                                           cartridgeID: status.cartridgeID,
                                           cartridgeFlags: status.cartridgeFlags,
                                           romSize: status.romSize,
                                           chipCount: status.chipCount,
                                           bankCount: status.bankCount,
                                           cartridgeName: cartridgeName,
                                           imagePath: imagePath)

    Task { @MainActor in
        session.handleCartridgeStatus(snapshot)
    }
}
