import AppKit
import Combine
import Darwin
import Foundation
import GameController
import ImageIO
import MacVICEKit
import UniformTypeIdentifiers

struct EmulatorStartupError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
}

/// A media problem the user must see, not merely a status-bar line —
/// e.g. a disk image the configured drive model cannot read.
struct MediaAttachError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
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

struct ViceMacTerminationPolicy {
    enum Decision: Equatable {
        case terminateNow
        case requestEngineQuitAndWait
        case keepWaitingForEngineQuit
    }

    private var didRequestEngineQuit = false

    mutating func decision(isEngineRunning: Bool,
                           requestEngineQuit: () -> Bool) -> Decision {
        guard isEngineRunning else {
            return .terminateNow
        }

        guard !didRequestEngineQuit else {
            return .keepWaitingForEngineQuit
        }

        didRequestEngineQuit = true
        return requestEngineQuit() ? .requestEngineQuitAndWait : .terminateNow
    }
}


@MainActor
final class EmulatorSession: ObservableObject {
    let machine = EmulatedMachine.current

    @Published var c64Model: C64MachineModel {
        didSet {
            guard c64Model != oldValue,
                  machine.family == .c64 else {
                return
            }

            EmulatorDefaults.saveC64Model(c64Model, for: machine)
            applyMachineModelChange(.x64sc(c64Model))
        }
    }
    @Published var c128Model: C128MachineModel {
        didSet {
            guard c128Model != oldValue,
                  machine.family == .c128 else {
                return
            }

            EmulatorDefaults.saveC128Model(c128Model, for: machine)
            applyMachineModelChange(.x128(c128Model))
        }
    }
    @Published var petModel: PETMachineModel {
        didSet {
            guard petModel != oldValue,
                  machine.family == .pet else {
                return
            }

            EmulatorDefaults.savePETModel(petModel, for: machine)
            applyMachineModel()
            applyROMImages()
            applyKeyboardMapping(forceReload: true)
        }
    }
    @Published var isPaused = false {
        didSet {
            guard isPaused != oldValue else {
                return
            }

            if !isPaused {
                pausedBecauseAppInactive = false
            }
            applyPauseState()
        }
    }
    @Published var emulationSpeed: EmulationSpeed {
        didSet {
            guard emulationSpeed != oldValue else {
                return
            }

            EmulatorDefaults.saveEmulationSpeed(emulationSpeed, for: machine)
            applyEmulationSpeed()
        }
    }
    @Published var displayMode: DisplayMode {
        didSet {
            guard displayMode != oldValue else {
                return
            }

            EmulatorDefaults.saveDisplayMode(displayMode, for: machine)
            statusText = "Display \(displayMode.title)"
        }
    }
    @Published var displayOutput: MachineDisplayOutput {
        didSet {
            let normalizedOutput = machine.displayOutput(id: displayOutput.id)
            guard displayOutput == normalizedOutput else {
                displayOutput = normalizedOutput
                return
            }

            guard displayOutput != oldValue else {
                return
            }

            EmulatorDefaults.saveDisplayOutput(displayOutput, for: machine)
            applyDisplayOutput()
        }
    }
    @Published var videoStandard: VideoStandard {
        didSet {
            guard videoStandard != oldValue else {
                return
            }

            EmulatorDefaults.saveVideoStandard(videoStandard, for: machine)
            applyVideoStandard()
        }
    }
    @Published var sidModel: SIDModel {
        didSet {
            guard sidModel != oldValue else {
                return
            }

            EmulatorDefaults.saveSIDModel(sidModel, for: machine)
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
    @Published var romImages: ROMImageConfiguration {
        didSet {
            guard romImages != oldValue else {
                return
            }

            EmulatorDefaults.saveROMImages(romImages, for: machine)
            applyROMImages()
        }
    }
    @Published var ramExpansion: RAMExpansion {
        didSet {
            guard ramExpansion != oldValue else {
                return
            }

            EmulatorDefaults.saveRAMExpansion(ramExpansion, for: machine)
            applyRAMExpansion()
        }
    }
    @Published var mediaBehavior: MediaBehaviorConfiguration {
        didSet {
            guard mediaBehavior != oldValue else {
                return
            }

            EmulatorDefaults.saveMediaBehavior(mediaBehavior, for: machine)
            applyMediaBehavior()
        }
    }
    @Published var snapshotConfiguration: SnapshotConfiguration {
        didSet {
            guard snapshotConfiguration != oldValue else {
                return
            }

            EmulatorDefaults.saveSnapshotConfiguration(snapshotConfiguration, for: machine)
        }
    }
    @Published var sessionBehavior: SessionBehaviorConfiguration {
        didSet {
            guard sessionBehavior != oldValue else {
                return
            }

            EmulatorDefaults.saveSessionBehavior(sessionBehavior, for: machine)
            applySessionBehavior(oldValue: oldValue)
        }
    }
    @Published var printerConfiguration: PrinterConfiguration {
        didSet {
            let normalizedConfiguration = PrinterConfiguration(isEnabled: printerConfiguration.isEnabled,
                                                               deviceNumber: printerConfiguration.deviceNumber,
                                                               model: printerConfiguration.model)
            guard printerConfiguration == normalizedConfiguration else {
                printerConfiguration = normalizedConfiguration
                return
            }

            guard printerConfiguration != oldValue else {
                return
            }

            EmulatorDefaults.savePrinterConfiguration(printerConfiguration, for: machine)
            applyPrinterConfiguration(previousDeviceNumber: oldValue.deviceNumber)
        }
    }
    @Published var sidConfiguration: SIDConfiguration {
        didSet {
            guard sidConfiguration != oldValue else {
                return
            }

            EmulatorDefaults.saveSIDConfiguration(sidConfiguration, for: machine)
            applySIDConfiguration()
        }
    }
    @Published var tapeConfiguration: TapeConfiguration {
        didSet {
            let normalizedConfiguration = TapeConfiguration(isDatasetteEnabled: tapeConfiguration.isDatasetteEnabled,
                                                            soundEnabled: tapeConfiguration.soundEnabled,
                                                            soundVolume: tapeConfiguration.soundVolume)
            guard tapeConfiguration == normalizedConfiguration else {
                tapeConfiguration = normalizedConfiguration
                return
            }

            guard tapeConfiguration != oldValue else {
                return
            }

            EmulatorDefaults.saveTapeConfiguration(tapeConfiguration, for: machine)
            applyTapeConfiguration()
        }
    }
    @Published var controlPorts: ControlPortConfiguration {
        didSet {
            let sanitizedConfiguration = controlPorts.sanitized()
            guard controlPorts == sanitizedConfiguration else {
                controlPorts = sanitizedConfiguration
                return
            }

            guard controlPorts != oldValue else {
                return
            }

            EmulatorDefaults.saveControlPorts(controlPorts, for: machine)
            applyControlPorts()
            publishKeyboardJoystickValues(force: true)
            publishGameControllerValues(force: true)
        }
    }
    @Published var driveConfigurations: [DriveConfiguration] {
        didSet {
            let normalizedConfigurations = Self.normalizedDriveConfigurations(driveConfigurations, for: machine)
            guard driveConfigurations == normalizedConfigurations else {
                driveConfigurations = normalizedConfigurations
                return
            }

            guard driveConfigurations != oldValue else {
                return
            }

            EmulatorDefaults.saveDriveConfigurations(driveConfigurations, for: machine)
            applyDriveConfigurationChanges(from: oldValue)
        }
    }
    @Published var keyboardMapping: VICEKeyboardMappingConfiguration {
        didSet {
            guard keyboardMapping != oldValue else {
                return
            }

            EmulatorDefaults.saveKeyboardMapping(keyboardMapping, for: machine)
            applyKeyboardMapping()
        }
    }
    @Published var networkModem: NetworkModemConfiguration {
        didSet {
            let normalizedConfiguration = networkModem.normalized(for: machine)
            guard networkModem == normalizedConfiguration else {
                networkModem = normalizedConfiguration
                return
            }

            guard networkModem != oldValue else {
                return
            }

            if networkModem.usesActiveUserPort && syncSystemTime {
                syncSystemTime = false
            }

            EmulatorDefaults.saveNetworkModem(networkModem, for: machine)
            applyNetworkModem()
        }
    }
    @Published var syncSystemTime: Bool {
        didSet {
            guard syncSystemTime != oldValue else {
                return
            }

            if syncSystemTime && networkModem.usesActiveUserPort {
                var updatedModem = networkModem
                updatedModem.isEnabled = false
                networkModem = updatedModem
            }

            EmulatorDefaults.saveSyncSystemTime(syncSystemTime, for: machine)
            applySystemTimeSync()
        }
    }
    @Published var driveActivities: [Int: DriveActivity] = [:]
    @Published var cartridgeStatus = CartridgeStatus.detached
    @Published var tapeImagePath: String?
    @Published var gameControllers: [ConnectedGameController] = []
    @Published var controlPortValues: [ControlPort: UInt16] = [:]
    @Published var filterSettings: VideoFilterSettings {
        didSet {
            guard filterSettings != oldValue else {
                return
            }

            EmulatorDefaults.saveVideoFilterSettings(filterSettings, for: machine)
        }
    }
    @Published var statusText: String
    @Published var startupError: EmulatorStartupError?
    @Published var mediaAttachError: MediaAttachError?
    @Published var printSpoolPages: [PrinterSpoolPage] = []
    @Published var networkModemStatus: NetworkModemRuntimeStatus = .disabled

    let engine: MacVICEEngineSession
    let frameSource: MacVICEFrameSource
    var didStartEngine = false

    var isMachineRunning: Bool {
        engine.isRunning
    }

    var pressedKeys: [UInt16: PressedEmulatorKey] = [:]
    var keyboardJoystickPressedKeys: [UUID: Set<UInt16>] = [:]
    var lastJoystickValues: [UUID: UInt16] = [:]
    var pressedMouseButtons = Set<UInt32>()
    var gameControllerObservers: [NSObjectProtocol] = []
    var pausedBecauseAppInactive = false
    var printQueueTimer: Timer?
    let hayesModemService = HayesModemService()

    nonisolated static func normalizedDriveConfigurations(_ configurations: [DriveConfiguration],
                                                          for machine: EmulatedMachine) -> [DriveConfiguration] {
        let defaults = machine.defaultDriveConfigurations()

        return machine.capabilities.driveUnits.enumerated().map { index, unit in
            guard var configuration = configurations.first(where: { $0.unit == unit }) else {
                return defaults[index]
            }

            if !machine.capabilities.driveTypes.contains(configuration.driveType) {
                configuration.driveType = defaults[index].driveType
            }

            if !machine.capabilities.supportedStorageKinds.contains(configuration.storageKind) {
                configuration.storageKind = configuration.driveType.defaultStorageKind
            }

            if !machine.capabilities.driveTypes(for: configuration.storageKind).contains(configuration.driveType) {
                configuration.driveType = machine.capabilities.defaultDriveType(for: configuration.storageKind,
                                                                                fallback: defaults[index].driveType)
            }

            configuration.sharedFolderPath = DriveConfiguration.normalizedSharedFolderPath(configuration.sharedFolderPath)
            configuration.soundVolume = DriveConfiguration.normalizedSoundVolumePercent(configuration.soundVolume)

            return configuration
        }
    }

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

        var macVICEVideoStandard: MacVICEVideoStandard {
            switch self {
            case .ntsc:
                return .ntsc
            case .pal:
                return .pal
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

    enum MemorySpace: UInt32, CaseIterable, Identifiable {
        case computer = 1
        case drive8 = 2
        case drive9 = 3
        case drive10 = 4
        case drive11 = 5

        var id: UInt32 { rawValue }

        var title: String {
            switch self {
            case .computer:
                return "Computer"
            case .drive8:
                return "Drive 8"
            case .drive9:
                return "Drive 9"
            case .drive10:
                return "Drive 10"
            case .drive11:
                return "Drive 11"
            }
        }
    }

    nonisolated static let currentMemoryBank: Int32 = -1
    nonisolated static let maxKeyboardTextChunkLength = 4000

    init() {
        let machine = EmulatedMachine.current
        let loadedC64Model = EmulatorDefaults.loadC64Model(for: machine)
        let loadedC128Model = EmulatorDefaults.loadC128Model(for: machine)
        let loadedNetworkModem = EmulatorDefaults.loadNetworkModem(for: machine)
        var loadedSyncSystemTime = EmulatorDefaults.loadSyncSystemTime(for: machine)
        let sidFallback: SIDModel

        switch machine.family {
        case .c64:
            sidFallback = loadedC64Model.defaultSIDModel
        case .c128:
            sidFallback = loadedC128Model.defaultSIDModel
        default:
            sidFallback = .mos8580
        }

        c64Model = loadedC64Model
        c128Model = loadedC128Model
        petModel = EmulatorDefaults.loadPETModel(for: machine)
        videoStandard = EmulatorDefaults.loadVideoStandard(for: machine)
        emulationSpeed = EmulatorDefaults.loadEmulationSpeed(for: machine)
        displayMode = EmulatorDefaults.loadDisplayMode(for: machine)
        filterSettings = EmulatorDefaults.loadVideoFilterSettings(for: machine)
        displayOutput = EmulatorDefaults.loadDisplayOutput(for: machine)
        sidModel = EmulatorDefaults.loadSIDModel(for: machine,
                                                 fallback: sidFallback)
        soundEnabled = EmulatorDefaults.loadSoundEnabled()
        soundVolume = EmulatorDefaults.loadSoundVolume()
        romImages = EmulatorDefaults.loadROMImages(for: machine)
        ramExpansion = EmulatorDefaults.loadRAMExpansion(for: machine)
        mediaBehavior = EmulatorDefaults.loadMediaBehavior(for: machine)
        snapshotConfiguration = EmulatorDefaults.loadSnapshotConfiguration(for: machine)
        sessionBehavior = EmulatorDefaults.loadSessionBehavior(for: machine)
        printerConfiguration = EmulatorDefaults.loadPrinterConfiguration(for: machine)
        sidConfiguration = EmulatorDefaults.loadSIDConfiguration(for: machine)
        tapeConfiguration = EmulatorDefaults.loadTapeConfiguration(for: machine)
        controlPorts = EmulatorDefaults.loadControlPorts(for: machine)
        driveConfigurations = EmulatorDefaults.loadDriveConfigurations(for: machine)
        keyboardMapping = EmulatorDefaults.loadKeyboardMapping(for: machine)
        if loadedSyncSystemTime && loadedNetworkModem.usesActiveUserPort {
            loadedSyncSystemTime = false
        }
        networkModem = loadedNetworkModem
        syncSystemTime = loadedSyncSystemTime
        statusText = "Starting \(machine.shortName)"
        let frameSource = MacVICEFrameSource(displayProfile: machine.macVICEDisplayProfile,
                                             bootImageURL: machine.bootImageURL)
        self.frameSource = frameSource
        engine = MacVICEEngineSession(configuration: MacVICEMachineConfiguration(machine: machine.macVICEKitMachine),
                                      videoSource: frameSource)
        if !loadedSyncSystemTime && loadedNetworkModem.usesActiveUserPort {
            EmulatorDefaults.saveSyncSystemTime(false, for: machine)
        }
        configureEngineCallbacks()
        setupGameControllerMonitoring()
        refreshPrintQueue()
        startPrintQueueMonitoring()
    }

    deinit {
        MainActor.assumeIsolated {
            hayesModemService.stop()
            printQueueTimer?.invalidate()
            for observer in gameControllerObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            GCController.stopWirelessControllerDiscovery()
        }
    }

    private func configureEngineCallbacks() {
        engine.callbacks.driveStatus = { [weak self] status in
            Task { @MainActor in
                self?.handleDriveStatus(status)
            }
        }
        engine.callbacks.cartridgeStatus = { [weak self] status in
            Task { @MainActor in
                self?.handleCartridgeStatus(status)
            }
        }
    }
}
