import CoreGraphics
import Foundation

enum EmulatorDefaults {
    private static let videoStandardKey = "vice.videoStandard"
    private static let emulationSpeedKey = "vice.emulationSpeed"
    private static let displayModeKey = "vice.displayMode"
    private static let mainWindowFrameKey = "vice.mainWindowFrame"
    private static let videoFilterPresetKey = "vice.videoFilterPreset"
    private static let videoFilterSettingsKey = "vice.videoFilterSettings"
    private static let sidModelKey = "vice.sidModel"
    private static let soundEnabledKey = "vice.soundEnabled"
    private static let soundVolumeKey = "vice.soundVolume"
    private static let displayOutputKey = "vice.displayOutput"
    private static let c64ModelKey = "vice.c64Model"
    private static let c128ModelKey = "vice.c128Model"
    private static let petModelKey = "vice.petModel"
    private static let romImagesKey = "vice.romImages"
    private static let ramExpansionKey = "vice.ramExpansion"
    private static let controlPortsKey = "vice.controlPorts"
    private static let driveConfigurationsKey = "vice.driveConfigurations"
    private static let keyboardMappingKey = "vice.keyboardMapping"
    private static let syncSystemTimeKey = "vice.syncSystemTime"

    static func loadVideoStandard(for machine: EmulatedMachine) -> EmulatorSession.VideoStandard {
        guard let rawValue = UserDefaults.standard.string(forKey: key(videoStandardKey, machine: machine))
                ?? legacyString(forKey: videoStandardKey, machine: machine) else {
            return .ntsc
        }

        return EmulatorSession.VideoStandard(rawValue: rawValue) ?? .ntsc
    }

    static func saveVideoStandard(_ standard: EmulatorSession.VideoStandard, for machine: EmulatedMachine) {
        UserDefaults.standard.set(standard.rawValue, forKey: key(videoStandardKey, machine: machine))
    }

    static func loadEmulationSpeed(for machine: EmulatedMachine) -> EmulatorSession.EmulationSpeed {
        guard let rawValue = UserDefaults.standard.string(forKey: key(emulationSpeedKey, machine: machine))
                ?? legacyString(forKey: emulationSpeedKey, machine: machine) else {
            return .normal
        }

        return EmulatorSession.EmulationSpeed(rawValue: rawValue) ?? .normal
    }

    static func saveEmulationSpeed(_ speed: EmulatorSession.EmulationSpeed, for machine: EmulatedMachine) {
        UserDefaults.standard.set(speed.rawValue, forKey: key(emulationSpeedKey, machine: machine))
    }

    static func loadDisplayMode(for machine: EmulatedMachine) -> EmulatorSession.DisplayMode {
        guard let rawValue = UserDefaults.standard.string(forKey: key(displayModeKey, machine: machine))
                ?? legacyString(forKey: displayModeKey, machine: machine) else {
            return .native
        }

        return EmulatorSession.DisplayMode(rawValue: rawValue) ?? .native
    }

    static func saveDisplayMode(_ mode: EmulatorSession.DisplayMode, for machine: EmulatedMachine) {
        UserDefaults.standard.set(mode.rawValue, forKey: key(displayModeKey, machine: machine))
    }

    static func loadMainWindowFrame(for machine: EmulatedMachine) -> CGRect? {
        guard let values = UserDefaults.standard.array(forKey: mainWindowFrameDefaultsKey(for: machine)) as? [Double],
              values.count == 4 else {
            return nil
        }

        let frame = CGRect(x: values[0], y: values[1], width: values[2], height: values[3])
        guard frame.isValidPersistedWindowFrame else {
            return nil
        }

        return frame
    }

    static func saveMainWindowFrame(_ frame: CGRect, for machine: EmulatedMachine) {
        guard frame.isValidPersistedWindowFrame else {
            return
        }

        UserDefaults.standard.set([frame.origin.x,
                                   frame.origin.y,
                                   frame.size.width,
                                   frame.size.height],
                                  forKey: mainWindowFrameDefaultsKey(for: machine))
    }

    static func mainWindowFrameDefaultsKey(for machine: EmulatedMachine) -> String {
        key(mainWindowFrameKey, machine: machine)
    }

    static func loadVideoFilterPreset(for machine: EmulatedMachine) -> VideoFilterPreset {
        guard let rawValue = UserDefaults.standard.string(forKey: key(videoFilterPresetKey, machine: machine))
                ?? legacyString(forKey: videoFilterPresetKey, machine: machine) else {
            return .commodore1702
        }

        return VideoFilterPreset(rawValue: rawValue) ?? .commodore1702
    }

    static func saveVideoFilterPreset(_ preset: VideoFilterPreset, for machine: EmulatedMachine) {
        UserDefaults.standard.set(preset.rawValue, forKey: key(videoFilterPresetKey, machine: machine))
    }

    static func loadVideoFilterSettings(for machine: EmulatedMachine) -> VideoFilterSettings {
        guard let data = UserDefaults.standard.data(forKey: key(videoFilterSettingsKey, machine: machine))
                ?? legacyData(forKey: videoFilterSettingsKey, machine: machine),
              let settings = try? JSONDecoder().decode(VideoFilterSettings.self, from: data) else {
            return VideoFilterSettings.defaults(for: loadVideoFilterPreset(for: machine))
        }

        return settings
    }

    static func saveVideoFilterSettings(_ settings: VideoFilterSettings, for machine: EmulatedMachine) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key(videoFilterSettingsKey, machine: machine))
        saveVideoFilterPreset(settings.preset, for: machine)
    }

    static func loadDisplayOutput(for machine: EmulatedMachine) -> MachineDisplayOutput {
        let rawValue = UserDefaults.standard.string(forKey: key(displayOutputKey, machine: machine))
        return machine.displayOutput(id: rawValue)
    }

    static func saveDisplayOutput(_ output: MachineDisplayOutput, for machine: EmulatedMachine) {
        UserDefaults.standard.set(output.id, forKey: key(displayOutputKey, machine: machine))
    }

    static func loadC64Model(for machine: EmulatedMachine) -> C64MachineModel {
        guard machine.family == .c64,
              let rawValue = UserDefaults.standard.string(forKey: key(c64ModelKey, machine: machine)) else {
            return .c64
        }

        return C64MachineModel(rawValue: rawValue) ?? .c64
    }

    static func saveC64Model(_ model: C64MachineModel, for machine: EmulatedMachine) {
        guard machine.family == .c64 else {
            return
        }

        UserDefaults.standard.set(model.rawValue, forKey: key(c64ModelKey, machine: machine))
    }

    static func loadC128Model(for machine: EmulatedMachine) -> C128MachineModel {
        guard machine.family == .c128,
              let rawValue = UserDefaults.standard.string(forKey: key(c128ModelKey, machine: machine)) else {
            return .c128
        }

        return C128MachineModel(rawValue: rawValue) ?? .c128
    }

    static func saveC128Model(_ model: C128MachineModel, for machine: EmulatedMachine) {
        guard machine.family == .c128 else {
            return
        }

        UserDefaults.standard.set(model.rawValue, forKey: key(c128ModelKey, machine: machine))
    }

    static func loadPETModel(for machine: EmulatedMachine) -> PETMachineModel {
        guard machine.family == .pet,
              let rawValue = UserDefaults.standard.string(forKey: key(petModelKey, machine: machine)) else {
            return .model4032
        }

        return PETMachineModel(rawValue: rawValue) ?? .model4032
    }

    static func savePETModel(_ model: PETMachineModel, for machine: EmulatedMachine) {
        guard machine.family == .pet else {
            return
        }

        UserDefaults.standard.set(model.rawValue, forKey: key(petModelKey, machine: machine))
    }

    static func loadSIDModel(for machine: EmulatedMachine,
                             fallback: EmulatorSession.SIDModel = .mos8580) -> EmulatorSession.SIDModel {
        let defaultsKey = key(sidModelKey, machine: machine)
        let legacyKey = machine.id == .x64sc ? sidModelKey : defaultsKey
        let activeKey = UserDefaults.standard.object(forKey: defaultsKey) != nil ? defaultsKey : legacyKey

        guard UserDefaults.standard.object(forKey: activeKey) != nil else {
            return fallback
        }

        let rawValue = Int32(UserDefaults.standard.integer(forKey: activeKey))
        return EmulatorSession.SIDModel(rawValue: rawValue) ?? fallback
    }

    static func saveSIDModel(_ model: EmulatorSession.SIDModel, for machine: EmulatedMachine) {
        UserDefaults.standard.set(Int(model.rawValue), forKey: key(sidModelKey, machine: machine))
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

    static func loadROMImages(for machine: EmulatedMachine) -> ROMImageConfiguration {
        guard let data = UserDefaults.standard.data(forKey: key(romImagesKey, machine: machine))
                ?? legacyData(forKey: romImagesKey, machine: machine),
              let images = try? JSONDecoder().decode(ROMImageConfiguration.self, from: data) else {
            return .standard
        }

        return images
    }

    static func saveROMImages(_ images: ROMImageConfiguration, for machine: EmulatedMachine) {
        guard let data = try? JSONEncoder().encode(images) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key(romImagesKey, machine: machine))
    }

    static func loadRAMExpansion(for machine: EmulatedMachine) -> RAMExpansion {
        guard machine.capabilities.supportsRAMExpansion,
              let rawValue = UserDefaults.standard.string(forKey: key(ramExpansionKey, machine: machine))
                ?? legacyString(forKey: ramExpansionKey, machine: machine) else {
            return .none
        }

        guard let expansion = RAMExpansion(rawValue: rawValue),
              machine.ramExpansions.contains(expansion) else {
            return .none
        }

        return expansion
    }

    static func saveRAMExpansion(_ expansion: RAMExpansion, for machine: EmulatedMachine) {
        UserDefaults.standard.set(expansion.rawValue, forKey: key(ramExpansionKey, machine: machine))
    }

    static func loadControlPorts(for machine: EmulatedMachine) -> ControlPortConfiguration {
        guard let data = UserDefaults.standard.data(forKey: key(controlPortsKey, machine: machine))
                ?? legacyData(forKey: controlPortsKey, machine: machine),
              let configuration = try? JSONDecoder().decode(ControlPortConfiguration.self, from: data) else {
            return .standard
        }

        return configuration.sanitized()
    }

    static func saveControlPorts(_ configuration: ControlPortConfiguration, for machine: EmulatedMachine) {
        guard let data = try? JSONEncoder().encode(configuration) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key(controlPortsKey, machine: machine))
    }

    static func loadDriveConfigurations(for machine: EmulatedMachine) -> [DriveConfiguration] {
        guard let data = UserDefaults.standard.data(forKey: key(driveConfigurationsKey, machine: machine))
                ?? legacyData(forKey: driveConfigurationsKey, machine: machine),
              let configurations = try? JSONDecoder().decode([DriveConfiguration].self, from: data),
              configurations.map(\.unit) == machine.capabilities.driveUnits else {
            return machine.defaultDriveConfigurations()
        }

        return EmulatorSession.normalizedDriveConfigurations(configurations, for: machine)
    }

    static func saveDriveConfigurations(_ configurations: [DriveConfiguration], for machine: EmulatedMachine) {
        guard let data = try? JSONEncoder().encode(configurations) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key(driveConfigurationsKey, machine: machine))
    }

    static func loadKeyboardMapping(for machine: EmulatedMachine) -> VICEKeyboardMappingConfiguration {
        guard let data = UserDefaults.standard.data(forKey: key(keyboardMappingKey, machine: machine))
                ?? legacyData(forKey: keyboardMappingKey, machine: machine),
              let configuration = try? JSONDecoder().decode(VICEKeyboardMappingConfiguration.self, from: data) else {
            return .standard
        }

        return configuration
    }

    static func saveKeyboardMapping(_ configuration: VICEKeyboardMappingConfiguration,
                                    for machine: EmulatedMachine) {
        guard let data = try? JSONEncoder().encode(configuration) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key(keyboardMappingKey, machine: machine))
    }

    static func loadSyncSystemTime(for machine: EmulatedMachine) -> Bool {
        guard machine.capabilities.supportsSystemTimeSync else {
            return false
        }

        let defaultsKey = key(syncSystemTimeKey, machine: machine)
        guard UserDefaults.standard.object(forKey: defaultsKey) != nil else {
            return false
        }

        return UserDefaults.standard.bool(forKey: defaultsKey)
    }

    static func saveSyncSystemTime(_ enabled: Bool, for machine: EmulatedMachine) {
        guard machine.capabilities.supportsSystemTimeSync else {
            return
        }

        UserDefaults.standard.set(enabled, forKey: key(syncSystemTimeKey, machine: machine))
    }

    private static func key(_ baseKey: String, machine: EmulatedMachine) -> String {
        "\(baseKey).\(machine.id.rawValue)"
    }

    private static func legacyData(forKey baseKey: String, machine: EmulatedMachine) -> Data? {
        guard machine.id == .x64sc else {
            return nil
        }

        return UserDefaults.standard.data(forKey: baseKey)
    }

    private static func legacyString(forKey baseKey: String, machine: EmulatedMachine) -> String? {
        guard machine.id == .x64sc else {
            return nil
        }

        return UserDefaults.standard.string(forKey: baseKey)
    }
}

private extension CGRect {
    var isValidPersistedWindowFrame: Bool {
        origin.x.isFinite
            && origin.y.isFinite
            && size.width.isFinite
            && size.height.isFinite
            && size.width > 0
            && size.height > 0
    }
}
