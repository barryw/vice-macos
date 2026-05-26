import AppKit
import Combine
import Foundation
import GameController

struct EmulatorStartupError: Identifiable, Equatable {
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

enum RAMExpansion: String, CaseIterable, Identifiable {
    case none
    case vic20_3k
    case vic20_8kBlock1
    case vic20_8kBlock2
    case vic20_8kBlock3
    case vic20_8kBlock5
    case vic20_11k
    case vic20_16k
    case vic20_19k
    case vic20_24k
    case vic20_27k
    case vic20_32k
    case vic20_35k
    case reu128
    case reu256
    case reu512
    case reu1024
    case reu2048
    case reu4096
    case reu8192
    case reu16384
    case georam512
    case georam1024
    case georam2048
    case georam4096
    case ramcart64
    case ramcart128
    case dqbb16
    case dqbb32
    case dqbb64
    case dqbb128
    case dqbb256
    case isepic
    case c64_256kDE00
    case c64_256kDE80
    case c64_256kDF00
    case c64_256kDF80
    case plus60kD040
    case plus60kD100
    case plus256k

    var id: String { rawValue }

    static let c64Options: [RAMExpansion] = [
        .none,
        .reu128,
        .reu256,
        .reu512,
        .reu1024,
        .reu2048,
        .reu4096,
        .reu8192,
        .reu16384,
        .georam512,
        .georam1024,
        .georam2048,
        .georam4096,
        .ramcart64,
        .ramcart128,
        .dqbb16,
        .dqbb32,
        .dqbb64,
        .dqbb128,
        .dqbb256,
        .isepic,
        .c64_256kDE00,
        .c64_256kDE80,
        .c64_256kDF00,
        .c64_256kDF80,
        .plus60kD040,
        .plus60kD100,
        .plus256k
    ]

    static let c128Options: [RAMExpansion] = [
        .none,
        .reu128,
        .reu256,
        .reu512,
        .reu1024,
        .reu2048,
        .reu4096,
        .reu8192,
        .reu16384,
        .georam512,
        .georam1024,
        .georam2048,
        .georam4096,
        .ramcart64,
        .ramcart128,
        .dqbb16,
        .dqbb32,
        .dqbb64,
        .dqbb128,
        .dqbb256,
        .isepic
    ]

    static let vic20Options: [RAMExpansion] = [
        .none,
        .vic20_3k,
        .vic20_8kBlock1,
        .vic20_8kBlock2,
        .vic20_8kBlock3,
        .vic20_8kBlock5,
        .vic20_11k,
        .vic20_16k,
        .vic20_19k,
        .vic20_24k,
        .vic20_27k,
        .vic20_32k,
        .vic20_35k
    ]

    var title: String {
        switch self {
        case .none:
            return "None"
        case .vic20_3k:
            return "VIC-20 3K"
        case .vic20_8kBlock1:
            return "VIC-20 8K BLK1"
        case .vic20_8kBlock2:
            return "VIC-20 8K BLK2"
        case .vic20_8kBlock3:
            return "VIC-20 8K BLK3"
        case .vic20_8kBlock5:
            return "VIC-20 8K BLK5"
        case .vic20_11k:
            return "VIC-20 11K"
        case .vic20_16k:
            return "VIC-20 16K"
        case .vic20_19k:
            return "VIC-20 19K"
        case .vic20_24k:
            return "VIC-20 24K"
        case .vic20_27k:
            return "VIC-20 27K"
        case .vic20_32k:
            return "VIC-20 32K"
        case .vic20_35k:
            return "VIC-20 35K"
        case .reu128, .reu256, .reu512, .reu1024, .reu2048, .reu4096, .reu8192, .reu16384:
            return "REU \(sizeTitle)"
        case .georam512, .georam1024, .georam2048, .georam4096:
            return "GeoRAM \(sizeTitle)"
        case .ramcart64, .ramcart128:
            return "RamCart \(sizeTitle)"
        case .dqbb16, .dqbb32, .dqbb64, .dqbb128, .dqbb256:
            return "DQBB \(sizeTitle)"
        case .isepic:
            return "ISEPIC 2K"
        case .c64_256kDE00:
            return "C64 256K @ $DE00"
        case .c64_256kDE80:
            return "C64 256K @ $DE80"
        case .c64_256kDF00:
            return "C64 256K @ $DF00"
        case .c64_256kDF80:
            return "C64 256K @ $DF80"
        case .plus60kD040:
            return "+60K @ $D040"
        case .plus60kD100:
            return "+60K @ $D100"
        case .plus256k:
            return "+256K"
        }
    }

    var statusTitle: String {
        self == .none ? "disabled" : title
    }

    func displayTitle(for machine: EmulatedMachine) -> String {
        guard machine.usesVIC20MemoryExpansion else {
            return title
        }

        switch self {
        case .none:
            return "VIC-20 5K (unexpanded)"
        case .vic20_3k:
            return "VIC-20 3K (BLK0)"
        case .vic20_8kBlock1:
            return "VIC-20 8K (BLK1)"
        case .vic20_8kBlock2:
            return "VIC-20 8K (BLK2)"
        case .vic20_8kBlock3:
            return "VIC-20 8K (BLK3)"
        case .vic20_8kBlock5:
            return "VIC-20 8K (BLK5)"
        case .vic20_11k:
            return "VIC-20 11K (BLK0 + BLK1)"
        case .vic20_16k:
            return "VIC-20 16K (BLK1 + BLK2)"
        case .vic20_19k:
            return "VIC-20 19K (BLK0 + BLK1 + BLK2)"
        case .vic20_24k:
            return "VIC-20 24K (BASIC max)"
        case .vic20_27k:
            return "VIC-20 27K (24K BASIC + BLK0)"
        case .vic20_32k:
            return "VIC-20 32K (24K BASIC + BLK5)"
        case .vic20_35k:
            return "VIC-20 35K (24K BASIC + BLK0 + BLK5)"
        default:
            return title
        }
    }

    var chipTitle: String {
        switch self {
        case .none:
            return ""
        case .vic20_3k:
            return "3K"
        case .vic20_8kBlock1:
            return "8K B1"
        case .vic20_8kBlock2:
            return "8K B2"
        case .vic20_8kBlock3:
            return "8K B3"
        case .vic20_8kBlock5:
            return "8K B5"
        case .vic20_11k:
            return "11K"
        case .vic20_16k:
            return "16K"
        case .vic20_19k:
            return "19K"
        case .vic20_24k:
            return "24K"
        case .vic20_27k:
            return "27K"
        case .vic20_32k:
            return "32K"
        case .vic20_35k:
            return "35K"
        case .c64_256kDE00, .c64_256kDE80, .c64_256kDF00, .c64_256kDF80:
            return "C64 256K"
        case .plus60kD040, .plus60kD100:
            return "+60K"
        default:
            return title
        }
    }

    fileprivate var device: RAMExpansionDevice {
        switch self {
        case .none:
            return .none
        case .vic20_3k, .vic20_8kBlock1, .vic20_8kBlock2, .vic20_8kBlock3, .vic20_8kBlock5,
             .vic20_11k, .vic20_16k, .vic20_19k, .vic20_24k, .vic20_27k, .vic20_32k,
             .vic20_35k:
            return .vic20Blocks
        case .reu128, .reu256, .reu512, .reu1024, .reu2048, .reu4096, .reu8192, .reu16384:
            return .reu
        case .georam512, .georam1024, .georam2048, .georam4096:
            return .georam
        case .ramcart64, .ramcart128:
            return .ramcart
        case .dqbb16, .dqbb32, .dqbb64, .dqbb128, .dqbb256:
            return .dqbb
        case .isepic:
            return .isepic
        case .c64_256kDE00, .c64_256kDE80, .c64_256kDF00, .c64_256kDF80,
             .plus60kD040, .plus60kD100, .plus256k:
            return .memoryHack
        }
    }

    fileprivate var sizeKiB: Int32? {
        switch self {
        case .reu128, .dqbb128, .ramcart128:
            return 128
        case .reu256, .dqbb256:
            return 256
        case .reu512, .georam512:
            return 512
        case .reu1024, .georam1024:
            return 1024
        case .reu2048, .georam2048:
            return 2048
        case .reu4096, .georam4096:
            return 4096
        case .reu8192:
            return 8192
        case .reu16384:
            return 16384
        case .ramcart64, .dqbb64:
            return 64
        case .dqbb16:
            return 16
        case .dqbb32:
            return 32
        case .none, .isepic, .c64_256kDE00, .c64_256kDE80, .c64_256kDF00, .c64_256kDF80,
             .plus60kD040, .plus60kD100, .plus256k, .vic20_3k, .vic20_8kBlock1,
             .vic20_8kBlock2, .vic20_8kBlock3, .vic20_8kBlock5, .vic20_11k, .vic20_16k,
             .vic20_19k, .vic20_24k, .vic20_27k, .vic20_32k, .vic20_35k:
            return nil
        }
    }

    fileprivate var memoryHack: Int32 {
        switch self {
        case .c64_256kDE00, .c64_256kDE80, .c64_256kDF00, .c64_256kDF80:
            return 1
        case .plus60kD040, .plus60kD100:
            return 2
        case .plus256k:
            return 3
        case .none, .reu128, .reu256, .reu512, .reu1024, .reu2048, .reu4096, .reu8192, .reu16384,
             .georam512, .georam1024, .georam2048, .georam4096, .ramcart64, .ramcart128,
             .dqbb16, .dqbb32, .dqbb64, .dqbb128, .dqbb256, .isepic, .vic20_3k,
             .vic20_8kBlock1, .vic20_8kBlock2, .vic20_8kBlock3, .vic20_8kBlock5,
             .vic20_11k, .vic20_16k, .vic20_19k, .vic20_24k, .vic20_27k, .vic20_32k,
             .vic20_35k:
            return 0
        }
    }

    fileprivate var baseAddress: Int32? {
        switch self {
        case .c64_256kDE00:
            return 0xde00
        case .c64_256kDE80:
            return 0xde80
        case .c64_256kDF00:
            return 0xdf00
        case .c64_256kDF80:
            return 0xdf80
        case .plus60kD040:
            return 0xd040
        case .plus60kD100:
            return 0xd100
        case .none, .reu128, .reu256, .reu512, .reu1024, .reu2048, .reu4096, .reu8192, .reu16384,
             .georam512, .georam1024, .georam2048, .georam4096, .ramcart64, .ramcart128,
             .dqbb16, .dqbb32, .dqbb64, .dqbb128, .dqbb256, .isepic, .plus256k, .vic20_3k,
             .vic20_8kBlock1, .vic20_8kBlock2, .vic20_8kBlock3, .vic20_8kBlock5,
             .vic20_11k, .vic20_16k, .vic20_19k, .vic20_24k, .vic20_27k, .vic20_32k,
             .vic20_35k:
            return nil
        }
    }

    var detailTitle: String {
        switch self {
        case .none:
            return "Unexpanded"
        case .vic20_3k, .vic20_8kBlock1, .vic20_8kBlock2, .vic20_8kBlock3, .vic20_8kBlock5,
             .vic20_11k, .vic20_16k, .vic20_19k, .vic20_24k, .vic20_27k, .vic20_32k,
             .vic20_35k:
            return vic20BlockTitle
        default:
            return title
        }
    }

    func detailTitle(for machine: EmulatedMachine) -> String {
        guard machine.usesVIC20MemoryExpansion else {
            return detailTitle
        }

        switch self {
        case .vic20_24k:
            return "\(vic20BlockTitle); BASIC shows 28159 bytes free"
        case .vic20_27k, .vic20_32k, .vic20_35k:
            return "\(vic20BlockTitle); BASIC still shows 28159 bytes free"
        default:
            return detailTitle
        }
    }

    var vic20MemorySpec: String? {
        switch self {
        case .none:
            return "none"
        case .vic20_3k:
            return "3k"
        case .vic20_8kBlock1:
            return "8k"
        case .vic20_8kBlock2:
            return "2"
        case .vic20_8kBlock3:
            return "3"
        case .vic20_8kBlock5:
            return "5"
        case .vic20_11k:
            return "3k,8k"
        case .vic20_16k:
            return "16k"
        case .vic20_19k:
            return "3k,16k"
        case .vic20_24k:
            return "24k"
        case .vic20_27k:
            return "3k,24k"
        case .vic20_32k:
            return "1,2,3,5"
        case .vic20_35k:
            return "all"
        default:
            return nil
        }
    }

    fileprivate var vic20RAMBlocks: Set<Int> {
        switch self {
        case .vic20_3k:
            return [0]
        case .vic20_8kBlock1:
            return [1]
        case .vic20_8kBlock2:
            return [2]
        case .vic20_8kBlock3:
            return [3]
        case .vic20_8kBlock5:
            return [5]
        case .vic20_11k:
            return [0, 1]
        case .vic20_16k:
            return [1, 2]
        case .vic20_19k:
            return [0, 1, 2]
        case .vic20_24k:
            return [1, 2, 3]
        case .vic20_27k:
            return [0, 1, 2, 3]
        case .vic20_32k:
            return [1, 2, 3, 5]
        case .vic20_35k:
            return [0, 1, 2, 3, 5]
        default:
            return []
        }
    }

    private var sizeTitle: String {
        guard let sizeKiB else {
            return ""
        }

        if sizeKiB >= 1024 {
            return "\(sizeKiB / 1024)M"
        }

        return "\(sizeKiB)K"
    }

    private var vic20BlockTitle: String {
        let blocks = vic20RAMBlocks.sorted()

        guard !blocks.isEmpty else {
            return "Unexpanded"
        }

        let names = blocks.map { block in
            block == 0 ? "BLK0" : "BLK\(block)"
        }
        return names.joined(separator: " + ")
    }

    func resourcePlan(for machine: EmulatedMachine) -> RAMExpansionResourcePlan {
        RAMExpansionResourcePlan(disableAssignments: Self.disableAssignments(for: machine),
                                 enableAssignments: enableAssignments,
                                 requiresHardReset: machine.usesVIC20MemoryExpansion)
    }

    private static func disableAssignments(for machine: EmulatedMachine) -> [ViceIntResourceAssignment] {
        if machine.usesVIC20MemoryExpansion {
            return vic20BlockAssignments(for: [])
        }

        return [
            ViceIntResourceAssignment(name: ViceResource.reu, value: 0),
            ViceIntResourceAssignment(name: ViceResource.georam, value: 0),
            ViceIntResourceAssignment(name: ViceResource.ramCart, value: 0),
            ViceIntResourceAssignment(name: ViceResource.dqbb, value: 0),
            ViceIntResourceAssignment(name: ViceResource.isepicCartridgeEnabled, value: 0),
            ViceIntResourceAssignment(name: ViceResource.isepicSwitch, value: 0),
            ViceIntResourceAssignment(name: ViceResource.memoryHack, value: 0)
        ]
    }

    private var enableAssignments: [ViceIntResourceAssignment] {
        switch device {
        case .none:
            return []
        case .vic20Blocks:
            return Self.vic20BlockAssignments(for: vic20RAMBlocks)
        case .reu:
            return sizedDeviceAssignments(sizeResource: ViceResource.reuSize,
                                          enableResource: ViceResource.reu)
        case .georam:
            return sizedDeviceAssignments(sizeResource: ViceResource.georamSize,
                                          enableResource: ViceResource.georam)
        case .ramcart:
            return sizedDeviceAssignments(sizeResource: ViceResource.ramCartSize,
                                          enableResource: ViceResource.ramCart)
        case .dqbb:
            var assignments = sizedDeviceAssignments(sizeResource: ViceResource.dqbbSize,
                                                     enableResource: ViceResource.dqbb)
            assignments.insert(ViceIntResourceAssignment(name: ViceResource.dqbbMode,
                                                        value: ViceDQBBMode.c64),
                               at: assignments.isEmpty ? 0 : assignments.count - 1)
            return assignments
        case .isepic:
            return [
                ViceIntResourceAssignment(name: ViceResource.isepicSwitch, value: 1),
                ViceIntResourceAssignment(name: ViceResource.isepicCartridgeEnabled, value: 1)
            ]
        case .memoryHack:
            var assignments: [ViceIntResourceAssignment] = []
            if let baseAddress {
                switch self {
                case .c64_256kDE00, .c64_256kDE80, .c64_256kDF00, .c64_256kDF80:
                    assignments.append(ViceIntResourceAssignment(name: ViceResource.c64_256kBase,
                                                                 value: baseAddress))
                case .plus60kD040, .plus60kD100:
                    assignments.append(ViceIntResourceAssignment(name: ViceResource.plus60kBase,
                                                                 value: baseAddress))
                default:
                    break
                }
            }
            assignments.append(ViceIntResourceAssignment(name: ViceResource.memoryHack,
                                                        value: memoryHack))
            return assignments
        }
    }

    private func sizedDeviceAssignments(sizeResource: String,
                                        enableResource: String) -> [ViceIntResourceAssignment] {
        var assignments: [ViceIntResourceAssignment] = []
        if let sizeKiB {
            assignments.append(ViceIntResourceAssignment(name: sizeResource, value: sizeKiB))
        }
        assignments.append(ViceIntResourceAssignment(name: enableResource, value: 1))
        return assignments
    }

    private static func vic20BlockAssignments(for blocks: Set<Int>) -> [ViceIntResourceAssignment] {
        ViceResource.vic20RAMBlocks.map { resource in
            ViceIntResourceAssignment(name: resource.name,
                                      value: blocks.contains(resource.block) ? 1 : 0)
        }
    }
}

fileprivate enum RAMExpansionDevice {
    case none
    case vic20Blocks
    case reu
    case georam
    case ramcart
    case dqbb
    case isepic
    case memoryHack
}

struct RAMExpansionResourcePlan: Equatable {
    let disableAssignments: [ViceIntResourceAssignment]
    let enableAssignments: [ViceIntResourceAssignment]
    let requiresHardReset: Bool
}

@MainActor
final class EmulatorSession: ObservableObject {
    let machine = EmulatedMachine.current

    @Published var petModel: PETMachineModel {
        didSet {
            guard petModel != oldValue,
                  machine.family == .pet else {
                return
            }

            EmulatorDefaults.savePETModel(petModel, for: machine)
            applyPETModel()
        }
    }
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

            EmulatorDefaults.saveDriveConfigurations(driveConfigurations, for: machine)
            applyDriveConfigurationChanges(from: oldValue)
        }
    }
    @Published private var driveActivities: [Int: DriveActivity] = [:]
    @Published var cartridgeStatus = CartridgeStatus.detached
    @Published private(set) var gameControllerNames: [String] = []
    @Published private var controlPortValues: [ControlPort: UInt16] = [:]
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

    let frameSource: EmulatorFrameSource
    private var didStartEngine = false
    private var pressedKeys: [UInt16: PressedEmulatorKey] = [:]
    private var keyboardJoystickPressedKeys: [UUID: Set<UInt16>] = [:]
    private var lastJoystickValues: [UUID: UInt16] = [:]
    private var gameControllerObservers: [NSObjectProtocol] = []

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

        petModel = EmulatorDefaults.loadPETModel(for: machine)
        videoStandard = EmulatorDefaults.loadVideoStandard(for: machine)
        emulationSpeed = EmulatorDefaults.loadEmulationSpeed(for: machine)
        displayMode = EmulatorDefaults.loadDisplayMode(for: machine)
        filterSettings = EmulatorDefaults.loadVideoFilterSettings(for: machine)
        displayOutput = EmulatorDefaults.loadDisplayOutput(for: machine)
        sidModel = EmulatorDefaults.loadSIDModel(for: machine)
        soundEnabled = EmulatorDefaults.loadSoundEnabled()
        soundVolume = EmulatorDefaults.loadSoundVolume()
        romImages = EmulatorDefaults.loadROMImages(for: machine)
        ramExpansion = EmulatorDefaults.loadRAMExpansion(for: machine)
        controlPorts = EmulatorDefaults.loadControlPorts(for: machine)
        driveConfigurations = EmulatorDefaults.loadDriveConfigurations(for: machine)
        statusText = "Starting \(machine.shortName)"
        frameSource = EmulatorFrameSource.displaySource(for: machine)
        setupGameControllerMonitoring()
    }

    deinit {
        MainActor.assumeIsolated {
            for observer in gameControllerObservers {
                NotificationCenter.default.removeObserver(observer)
            }
            GCController.stopWirelessControllerDiscovery()
        }
    }

    var isRAMExpansionConfigured: Bool {
        machine.capabilities.supportsRAMExpansion && ramExpansion != .none
    }

    var activeMachineModel: MachineModel {
        guard machine.family == .pet else {
            return machine.model
        }

        return .xpet(petModel)
    }

    var machineDisplayName: String {
        switch activeMachineModel {
        case let .xpet(model):
            return model.displayName
        case let .ted(model):
            return model.displayName
        default:
            return machine.displayName
        }
    }

    var availableControlPorts: [ControlPort] {
        machine.capabilities.controlPorts
    }

    func romResourceValue(for slot: MachineROMSlot) -> String {
        machine.romResourceValue(for: slot,
                                 romImages: romImages,
                                 videoStandard: videoStandard,
                                 machineModel: activeMachineModel)
    }

    var hasMultipleControlPorts: Bool {
        availableControlPorts.count > 1
    }

    var visibleDriveActivities: [DriveActivity] {
        driveConfigurations.compactMap { configuration in
            guard configuration.isAttached else {
                return nil
            }

            if var activity = driveActivities[configuration.unit] {
                activity.isConfigured = true
                activity.driveType = configuration.driveType
                activity.accessMode = configuration.accessMode
                activity.slots = normalizedDriveSlots(activity.slots, for: configuration.driveType)
                return activity
            }

            return DriveActivity(unit: configuration.unit,
                                 isConfigured: true,
                                 driveType: configuration.driveType,
                                 accessMode: configuration.accessMode,
                                 activeDriveNumber: 0,
                                 slots: defaultDriveSlots(for: configuration.driveType),
                                 ledColor: configuration.driveType.defaultLEDColor,
                                 ledIntensity: 0,
                                 errorIntensity: 0,
                                 track: nil,
                                 halfTrack: nil,
                                 diskSide: 0,
                                 driveStatusCode: 0,
                                 driveStatusText: nil,
                                 imagePath: nil)
        }
    }

    func diskImagePath(for unit: Int, driveNumber: Int) -> String? {
        visibleDriveActivities
            .first { $0.unit == unit }?
            .slots
            .first { $0.driveNumber == driveNumber }?
            .imagePath
    }

    func hasDiskAttached(to unit: Int, driveNumber: Int) -> Bool {
        diskImagePath(for: unit, driveNumber: driveNumber)?.isEmpty == false
    }

    private func defaultDriveSlots(for driveType: DriveType) -> [DriveSlotActivity] {
        driveType.driveNumbers.map { driveNumber in
            DriveSlotActivity(driveNumber: driveNumber,
                              ledColor: driveType.ledColor(forDriveNumber: driveNumber),
                              ledIntensity: 0,
                              imagePath: nil)
        }
    }

    private func normalizedDriveSlots(_ slots: [DriveSlotActivity], for driveType: DriveType) -> [DriveSlotActivity] {
        driveType.driveNumbers.map { driveNumber in
            if var slot = slots.first(where: { $0.driveNumber == driveNumber }) {
                slot.ledColor = driveType.ledColor(forDriveNumber: driveNumber)
                return slot
            }

            return DriveSlotActivity(driveNumber: driveNumber,
                                     ledColor: driveType.ledColor(forDriveNumber: driveNumber),
                                     ledIntensity: 0,
                                     imagePath: nil)
        }
    }

    var hasGameControllers: Bool {
        !gameControllerNames.isEmpty
    }

    var sortedGameControllerNames: [String] {
        gameControllerNames.sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    func driveAccessMode(for unit: Int) -> DriveAccessMode {
        driveConfigurations.first { $0.unit == unit }?.accessMode ?? .native
    }

    func setDriveAccessMode(_ accessMode: DriveAccessMode, for unit: Int) {
        guard let index = driveConfigurations.firstIndex(where: { $0.unit == unit }) else {
            return
        }

        driveConfigurations[index].accessMode = accessMode
    }

    var controlDevices: [ControlDeviceConfiguration] {
        controlPorts.devices
    }

    func controlDevice(id: UUID) -> ControlDeviceConfiguration? {
        controlPorts.device(id: id)
    }

    func controlPortDevice(for port: ControlPort) -> ControlDeviceConfiguration? {
        controlPorts.assignedDevice(for: port)
    }

    func controlPortConnectionState(for port: ControlPort) -> ControlDeviceConnectionState {
        guard let device = controlPortDevice(for: port) else {
            return .connected
        }

        return connectionState(for: device)
    }

    func controlPortDeviceID(for port: ControlPort) -> UUID? {
        controlPorts.assignedDeviceID(for: port)
    }

    func connectionState(for device: ControlDeviceConfiguration) -> ControlDeviceConnectionState {
        switch device.kind {
        case .keyboard:
            return .connected
        case .joystick:
            if let preferredControllerName = device.joystick.preferredControllerName {
                return gameControllerNames.contains(preferredControllerName)
                    ? .connected
                    : .unavailable("Missing \(preferredControllerName)")
            }

            return hasGameControllers ? .connected : .unavailable("No controller connected")
        }
    }

    func setControlPortDeviceID(_ deviceID: UUID?, for port: ControlPort) {
        var updatedConfiguration = controlPorts
        updatedConfiguration.setAssignedDeviceID(deviceID, for: port)
        controlPorts = updatedConfiguration
    }

    func swapControlPorts() {
        guard hasMultipleControlPorts else {
            return
        }

        var updatedConfiguration = controlPorts
        let port1DeviceID = controlPorts.assignedDeviceID(for: .one)
        let port2DeviceID = controlPorts.assignedDeviceID(for: .two)

        updatedConfiguration.setAssignedDeviceID(port2DeviceID, for: .one)
        updatedConfiguration.setAssignedDeviceID(port1DeviceID, for: .two)
        controlPorts = updatedConfiguration
    }

    func controlPortJoystickValue(for port: ControlPort) -> UInt16 {
        controlPortValues[port] ?? 0
    }

    func controlPortActiveActions(for port: ControlPort) -> Set<JoystickAction> {
        let value = controlPortJoystickValue(for: port)
        var actions = Set<JoystickAction>()

        for action in JoystickAction.allCases where (value & action.bit) != 0 {
            actions.insert(action)
        }

        return actions
    }

    func makeControlDevice(kind: ControlDeviceKind) -> ControlDeviceConfiguration {
        switch kind {
        case .keyboard:
            return ControlDeviceConfiguration.keyboard(name: uniqueControlDeviceName(baseName: "Keyboard"))
        case .joystick:
            return ControlDeviceConfiguration.joystick(name: uniqueControlDeviceName(baseName: "Joystick"))
        }
    }

    @discardableResult
    func addControlDevice(kind: ControlDeviceKind) -> UUID {
        let device = makeControlDevice(kind: kind)
        saveControlDevice(device)
        return device.id
    }

    func saveControlDevice(_ device: ControlDeviceConfiguration) {
        var updatedConfiguration = controlPorts

        if updatedConfiguration.device(id: device.id) == nil {
            updatedConfiguration.devices.append(device.normalized())
        } else {
            updatedConfiguration.updateDevice(device)
        }

        controlPorts = updatedConfiguration
    }

    func updateControlDevice(_ device: ControlDeviceConfiguration) {
        var updatedConfiguration = controlPorts
        updatedConfiguration.updateDevice(device)
        controlPorts = updatedConfiguration
    }

    func removeControlDevice(id: UUID) {
        var updatedConfiguration = controlPorts
        updatedConfiguration.removeDevice(id: id)
        controlPorts = updatedConfiguration
    }

    func start() {
        guard !didStartEngine else {
            return
        }
        startupError = nil

        guard let executablePath = Bundle.main.executableURL?.path,
              let dataDirectory = Bundle.main.resourceURL?.appendingPathComponent("VICEData").path,
              let runtimeDirectory = Bundle.main.privateFrameworksURL?.path else {
            reportStartupFailure(
                status: "Missing runtime paths",
                detail: "The app bundle is missing its executable, resources, or Frameworks path."
            )
            return
        }
        let dynamicLibraryPath = URL(fileURLWithPath: runtimeDirectory)
            .appendingPathComponent(machine.dynamicLibraryName)
            .path

        didStartEngine = true
        ViceEngineSetVideoFrameCallback(viceFrameCallback,
                                        Unmanaged.passUnretained(frameSource).toOpaque())
        ViceEngineSetDriveStatusCallback(viceDriveStatusCallback,
                                         Unmanaged.passUnretained(self).toOpaque())
        ViceEngineSetCartridgeStatusCallback(viceCartridgeStatusCallback,
                                             Unmanaged.passUnretained(self).toOpaque())

        let startupConfiguration = MachineStartupConfiguration(executablePath: executablePath,
                                                               dataDirectory: dataDirectory,
                                                               machineModel: activeMachineModel,
                                                               videoStandard: videoStandard,
                                                               sidModel: sidModel,
                                                               soundEnabled: soundEnabled,
                                                               soundVolume: soundVolume,
                                                               emulationSpeed: emulationSpeed,
                                                               displayOutput: displayOutput,
                                                               romImages: romImages,
                                                               ramExpansion: ramExpansion,
                                                               driveConfigurations: driveConfigurations)
        let startupArguments = machine.startupArguments(configuration: startupConfiguration)
        let startResult = machine.id.rawValue.withCString { machineIDPointer in
            dynamicLibraryPath.withCString { dynamicLibraryPathPointer in
                startupArguments.withCStringArray { argumentCount, argumentPointers in
                    ViceEngineStartMachine(machineIDPointer,
                                           dynamicLibraryPathPointer,
                                           argumentCount,
                                           argumentPointers)
                }
            }
        }
        guard let started = startResult else {
            didStartEngine = false
            reportStartupFailure(
                status: "Unable to prepare startup arguments",
                detail: "VICE Mac could not build the emulator startup arguments."
            )
            return
        }

        let isRunning = started || ViceEngineIsRunning()
        didStartEngine = isRunning

        if isRunning {
            applyRuntimeConfiguration()
        }

        if started {
            statusText = "\(machine.shortName) running"
        } else if isRunning {
            statusText = "\(machine.shortName) already running"
        } else {
            reportStartupFailure(
                status: "Unable to start \(machine.shortName)",
                detail: lastEngineErrorMessage() ?? "The emulator engine did not start."
            )
        }
    }

    private func reportStartupFailure(status: String, detail: String) {
        statusText = status
        startupError = EmulatorStartupError(title: "Unable to Start \(machine.shortName)",
                                            message: detail)
    }

    private func lastEngineErrorMessage() -> String? {
        guard let error = ViceEngineGetLastError() else {
            return nil
        }

        let message = String(cString: error).trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? nil : message
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
        statusText = "\(preset.title) display"
    }

    @discardableResult
    func handleKeyEvent(_ event: NSEvent, pressed: Bool) -> Bool {
        if !pressed, let existingKey = pressedKeys.removeValue(forKey: event.keyCode) {
            ViceEngineSendKeyEvent(existingKey.symbol, existingKey.modifiers, false)
            return true
        }

        if !pressed {
            return handleKeyboardJoystickEvent(event, pressed: false)
        }

        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command) {
            return false
        }

        if handleKeyboardJoystickEvent(event, pressed: true) {
            return true
        }

        if event.isARepeat {
            return true
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
        keyboardJoystickPressedKeys.removeAll()
        ViceEngineReleaseAllKeys()

        for device in assignedControlDevices(kind: .keyboard) {
            lastJoystickValues[device.id] = 0
            publishJoystickValue(0, forDeviceID: device.id)
        }
    }

    func peekMemory(space: MemorySpace = .computer,
                    bank: Int32 = EmulatorSession.currentMemoryBank,
                    address: UInt16,
                    length: Int = 1) -> Data? {
        guard ViceEngineIsRunning(),
              length > 0,
              length <= Int(UInt16.max) + 1 - Int(address) else {
            return nil
        }

        var bytes = [UInt8](repeating: 0, count: length)
        let didPeek = bytes.withUnsafeMutableBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return false
            }

            return ViceEnginePeekMemory(space.rawValue,
                                        bank,
                                        UInt32(address),
                                        baseAddress,
                                        UInt32(length))
        }

        return didPeek ? Data(bytes) : nil
    }

    func peekByte(space: MemorySpace = .computer,
                  bank: Int32 = EmulatorSession.currentMemoryBank,
                  address: UInt16) -> UInt8? {
        peekMemory(space: space, bank: bank, address: address, length: 1)?.first
    }

    @discardableResult
    func pokeMemory(space: MemorySpace = .computer,
                    bank: Int32 = EmulatorSession.currentMemoryBank,
                    address: UInt16,
                    bytes: [UInt8]) -> Bool {
        guard ViceEngineIsRunning(),
              !bytes.isEmpty,
              bytes.count <= Int(UInt16.max) + 1 - Int(address) else {
            return false
        }

        return bytes.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else {
                return false
            }

            return ViceEnginePokeMemory(space.rawValue,
                                        bank,
                                        UInt32(address),
                                        baseAddress,
                                        UInt32(bytes.count))
        }
    }

    @discardableResult
    func pokeByte(space: MemorySpace = .computer,
                  bank: Int32 = EmulatorSession.currentMemoryBank,
                  address: UInt16,
                  byte: UInt8) -> Bool {
        pokeMemory(space: space, bank: bank, address: address, bytes: [byte])
    }

    @discardableResult
    func typeText(_ text: String) -> Bool {
        queueKeyboardText(text)
    }

    @discardableResult
    func submitLine(_ line: String) -> Bool {
        queueKeyboardText("\(line)\r")
    }

    @discardableResult
    func pasteFromPasteboard(_ pasteboard: NSPasteboard = .general) -> Bool {
        guard let text = pasteboard.string(forType: .string),
              !text.isEmpty else {
            statusText = "Clipboard has no text"
            return false
        }

        guard canReceiveKeyboardText else {
            statusText = isPaused ? "Resume before pasting" : "Emulator is not running"
            return false
        }

        let didPaste = queueKeyboardText(text)
        statusText = didPaste ? pasteStatusText(for: text) : "Unable to paste clipboard text"
        return didPaste
    }

    @discardableResult
    private func queueKeyboardText(_ text: String) -> Bool {
        guard canReceiveKeyboardText else {
            return false
        }

        let chunks = Self.keyboardTextChunks(for: text)
        guard !chunks.isEmpty else {
            return false
        }

        for chunk in chunks {
            let didQueue = chunk.withCString { pointer in
                ViceEngineFeedKeyboardText(pointer)
            }
            if !didQueue {
                return false
            }
        }

        return true
    }

    var canReceiveKeyboardText: Bool {
        ViceEngineIsRunning() && !isPaused
    }

    nonisolated static func keyboardTextChunks(for text: String) -> [String] {
        var chunks: [String] = []
        var chunkScalars = String.UnicodeScalarView()

        for scalar in normalizedKeyboardText(text).unicodeScalars {
            if chunkScalars.count >= maxKeyboardTextChunkLength {
                chunks.append(String(chunkScalars))
                chunkScalars.removeAll(keepingCapacity: true)
            }

            chunkScalars.append(scalar)
        }

        if !chunkScalars.isEmpty {
            chunks.append(String(chunkScalars))
        }

        return chunks
    }

    nonisolated private static func normalizedKeyboardText(_ text: String) -> String {
        var normalized = String.UnicodeScalarView()

        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0:
                continue
            case 0x09:
                normalized.append(" ")
            case 0x0a, 0x0d, 0x20...0x7e:
                normalized.append(scalar)
            default:
                normalized.append("?")
            }
        }

        return String(normalized)
    }

    private func pasteStatusText(for text: String) -> String {
        let lineCount = text.split(whereSeparator: \.isNewline).count
        if lineCount > 1 {
            return "Pasted \(lineCount) lines"
        }

        return "Pasted clipboard text"
    }

    func handleDriveStatus(_ status: DriveStatusSnapshot) {
        guard let driveType = DriveType(rawValue: status.driveType) else {
            driveActivities.removeValue(forKey: status.unit)
            return
        }

        let slots = driveType.driveNumbers.map { driveNumber in
            DriveSlotActivity(driveNumber: driveNumber,
                              ledColor: driveType.ledColor(forDriveNumber: driveNumber),
                              ledIntensity: driveNumber == 0 ? status.drive0LEDIntensity : status.drive1LEDIntensity,
                              imagePath: driveNumber == 0 ? status.drive0ImagePath : status.drive1ImagePath)
        }

        let activity = DriveActivity(unit: status.unit,
                                     isConfigured: status.enabled,
                                     driveType: driveType,
                                     accessMode: driveAccessMode(for: Int(status.unit)),
                                     activeDriveNumber: Int(status.activeDriveNumber),
                                     slots: slots,
                                     ledColor: DriveLEDColor(viceColor: status.ledColor),
                                     ledIntensity: status.ledIntensity,
                                     errorIntensity: status.errorIntensity,
                                     track: status.track,
                                     halfTrack: status.halfTrack,
                                     diskSide: status.diskSide,
                                     driveStatusCode: status.driveStatusCode,
                                     driveStatusText: status.driveStatusText,
                                     imagePath: status.imagePath)

        if driveActivities[status.unit] != activity {
            driveActivities[status.unit] = activity
        }
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

    func previewDriveSound(for configuration: DriveConfiguration) {
        guard ViceEngineIsRunning(),
              configuration.isAttached,
              configuration.soundEnabled,
              configuration.soundVolume > 0,
              configuration.unit >= 8,
              configuration.unit <= 11 else {
            return
        }

        applyDriveSoundSettings()
        _ = ViceEnginePreviewDriveSound(UInt32(configuration.unit))
    }

    @discardableResult
    func openMedia(url: URL, autorun: Bool = false) -> Bool {
        guard let mediaFile = EmulatorMediaFile(url: url) else {
            let title = url.lastPathComponent.isEmpty ? "Media" : url.lastPathComponent
            statusText = "\(title) is not a supported media file"
            return false
        }

        switch mediaFile {
        case let .disk(diskImageType):
            return attachDiskToFirstCompatibleDrive(url: url,
                                                    diskImageType: diskImageType,
                                                    autorun: autorun)
        case .autostart:
            return autostartMedia(url: url, autorun: autorun)
        case .cartridge:
            return attachCartridge(url: url)
        case .snapshot:
            return loadSnapshot(url: url)
        }
    }

    func openMedia(urls: [URL], autorun: Bool = false) {
        urls.forEach { url in
            openMedia(url: url, autorun: autorun)
        }
    }

    @discardableResult
    func attachDisk(to unit: Int, url: URL, autorun: Bool) -> Bool {
        attachDisk(to: unit, driveNumber: 0, url: url, autorun: autorun)
    }

    @discardableResult
    func attachDisk(to unit: Int, driveNumber: Int, url: URL, autorun: Bool) -> Bool {
        guard unit >= 8 && unit <= 11 else {
            return false
        }

        guard let configuration = driveConfigurations.first(where: { $0.unit == unit }),
              configuration.isAttached else {
            statusText = "Drive \(unit) is disabled"
            return false
        }

        guard configuration.driveType.driveNumbers.contains(driveNumber) else {
            statusText = "Drive \(unit):\(driveNumber) is not available on \(configuration.driveType.title)"
            return false
        }

        guard configuration.driveType.supportsDiskImage(url: url) else {
            let fileType = DiskImageFileType(url: url)?.title
                ?? (url.pathExtension.isEmpty ? "File" : url.pathExtension.uppercased())
            statusText = "\(fileType) is not supported by drive \(unit) (\(configuration.driveType.title))"
            return false
        }

        let didAttach = url.path.withCString { path in
            ViceEngineAttachDisk(UInt32(unit), UInt32(driveNumber), path, autorun)
        }

        if didAttach {
            rememberMedia(url)
            statusText = "\(url.lastPathComponent) attached to drive \(unit)"
        } else {
            statusText = "Unable to attach \(url.lastPathComponent)"
        }

        return didAttach
    }

    @discardableResult
    func detachDisk(from unit: Int, driveNumber: Int = 0) -> Bool {
        guard unit >= 8 && unit <= 11 else {
            return false
        }

        guard let configuration = driveConfigurations.first(where: { $0.unit == unit }),
              configuration.isAttached else {
            statusText = "Drive \(unit) is disabled"
            return false
        }

        guard configuration.driveType.driveNumbers.contains(driveNumber) else {
            statusText = "Drive \(unit):\(driveNumber) is not available on \(configuration.driveType.title)"
            return false
        }

        guard hasDiskAttached(to: unit, driveNumber: driveNumber) else {
            statusText = "No disk attached to \(driveAddress(unit: unit, driveNumber: driveNumber))"
            return false
        }

        let didDetach = ViceEngineDetachDisk(UInt32(unit), UInt32(driveNumber))
        if didDetach {
            statusText = "Disk detached from \(driveAddress(unit: unit, driveNumber: driveNumber))"
        } else {
            statusText = "Unable to detach disk from \(driveAddress(unit: unit, driveNumber: driveNumber))"
        }

        return didDetach
    }

    @discardableResult
    func autostartMedia(url: URL, autorun: Bool) -> Bool {
        let didStart = url.path.withCString { path in
            ViceEngineAutostartMedia(path, autorun)
        }

        if didStart {
            rememberMedia(url)
            statusText = autorun
                ? "\(url.lastPathComponent) started"
                : "\(url.lastPathComponent) loading"
        } else {
            statusText = "Unable to open \(url.lastPathComponent)"
        }

        return didStart
    }

    private func driveAddress(unit: Int, driveNumber: Int) -> String {
        guard let configuration = driveConfigurations.first(where: { $0.unit == unit }),
              configuration.driveType.slotCount > 1 else {
            return "drive \(unit)"
        }

        return "drive \(unit):\(driveNumber)"
    }

    func setROMImage(_ image: MachineROMSlot, path: String?) {
        guard machine.romSlots.contains(image) else {
            return
        }

        var updatedImages = romImages
        updatedImages.setPath(path, for: image)
        romImages = updatedImages
    }

    @discardableResult
    func attachCartridge(url: URL) -> Bool {
        guard machine.capabilities.supportsCartridges else {
            statusText = "\(machineDisplayName) does not support cartridges"
            return false
        }

        let didAttach = url.path.withCString { path in
            ViceEngineAttachCartridge(path)
        }

        if didAttach {
            rememberMedia(url)
            statusText = "\(url.lastPathComponent) attached"
        } else {
            statusText = "Unable to attach \(url.lastPathComponent)"
        }

        return didAttach
    }

    func detachCartridge() {
        guard machine.capabilities.supportsCartridges else {
            return
        }

        if ViceEngineDetachCartridge() {
            statusText = "Cartridge detached"
        } else {
            statusText = "Unable to detach cartridge"
        }
    }

    @discardableResult
    func saveSnapshot(url: URL) -> Bool {
        guard ViceEngineIsRunning() else {
            statusText = "\(machine.shortName) is not running"
            return false
        }

        let didSave = url.path.withCString { path in
            ViceEngineSaveSnapshot(path, true, true)
        }

        if didSave {
            rememberMedia(url)
            statusText = "Snapshot saved"
        } else {
            statusText = "Unable to save snapshot"
        }

        return didSave
    }

    @discardableResult
    func loadSnapshot(url: URL) -> Bool {
        guard ViceEngineIsRunning() else {
            statusText = "\(machine.shortName) is not running"
            return false
        }

        releaseAllKeys()

        let didLoad = url.path.withCString { path in
            ViceEngineLoadSnapshot(path)
        }

        if didLoad {
            rememberMedia(url)
            statusText = "Snapshot loaded"
        } else {
            statusText = "Unable to load snapshot"
        }

        return didLoad
    }

    private func attachDiskToFirstCompatibleDrive(url: URL,
                                                  diskImageType: DiskImageFileType,
                                                  autorun: Bool) -> Bool {
        guard let target = firstCompatibleDriveTarget(for: diskImageType) else {
            statusText = "No enabled drive supports \(diskImageType.title) images"
            return false
        }

        return attachDisk(to: target.unit,
                          driveNumber: target.driveNumber,
                          url: url,
                          autorun: autorun)
    }

    private func firstCompatibleDriveTarget(for diskImageType: DiskImageFileType) -> (unit: Int, driveNumber: Int)? {
        for configuration in driveConfigurations where configuration.isAttached {
            guard configuration.driveType.supportsDiskImage(diskImageType),
                  let driveNumber = configuration.driveType.driveNumbers.first else {
                continue
            }

            return (configuration.unit, driveNumber)
        }

        return nil
    }

    private func rememberMedia(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }

    private func applyRuntimeConfiguration() {
        if machine.supportsRuntimeVideoStandardUpdates {
            applyVideoStandard(updateStatus: false)
        }
        applySIDModel(updateStatus: false)
        applySoundSettings(updateStatus: false)
        applyEmulationSpeed(updateStatus: false)
        applyDisplayOutput(updateStatus: false)
        applyPauseState(updateStatus: false)
        if machine.supportsRuntimeROMImageUpdates {
            applyROMImages()
        }
        applyRAMExpansion(updateStatus: false)
        applyControlPorts()
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
        guard ViceEngineIsRunning(),
              machine.capabilities.supportsVideoStandardSelection else {
            return
        }

        for assignment in machine.videoStandardAssignments(for: videoStandard) {
            setVICEIntResource(assignment.name, value: assignment.value)
        }

        if updateStatus {
            statusText = "Video \(videoStandard.rawValue)"
        }
    }

    private func applySIDModel(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              machine.capabilities.supportsSIDModelSelection else {
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

    private func applyDisplayOutput(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              machine.supportsDisplayOutputSelection,
              let resourceName = displayOutput.resourceName else {
            return
        }

        setVICEIntResource(resourceName, value: displayOutput.resourceValue)

        if updateStatus {
            statusText = "Display \(displayOutput.statusTitle)"
        }
    }

    private func applyPETModel(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              machine.family == .pet else {
            return
        }

        let didQueueModel = petModel.viceModelName.withCString { modelName in
            ViceEngineSetMachineModel(modelName)
        }
        guard didQueueModel else {
            if updateStatus {
                statusText = "PET model unavailable"
            }
            return
        }
        applyROMImages()

        if updateStatus {
            statusText = petModel.displayName
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

    private func applyROMImages() {
        guard ViceEngineIsRunning() else {
            return
        }

        for slot in machine.romSlots {
            setVICEStringResource(slot.resourceName,
                                  value: romResourceValue(for: slot))
        }
    }

    private func applyRAMExpansion(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              machine.capabilities.supportsRAMExpansion,
              machine.ramExpansions.contains(ramExpansion) else {
            return
        }

        let plan = ramExpansion.resourcePlan(for: machine)
        for assignment in plan.disableAssignments + plan.enableAssignments {
            setVICEIntResource(assignment.name, value: assignment.value)
        }

        if updateStatus {
            if plan.requiresHardReset {
                _ = ViceEngineTriggerMachineReset(true)
            }
            statusText = "RAM expansion \(ramExpansion.statusTitle)"
        }
    }

    private func applyControlPorts() {
        guard ViceEngineIsRunning() else {
            return
        }

        for port in availableControlPorts {
            guard let controlDevice = controlPorts.assignedDevice(for: port) else {
                setVICEIntResource(port.resourceName, value: ViceJoyPortDevice.none)
                publishJoystickValue(0, to: port)
                continue
            }

            setVICEIntResource(port.resourceName, value: controlDevice.kind.viceJoyPortDevice)
            publishJoystickValue(currentJoystickValue(for: controlDevice), to: port)
        }
    }

    private func applyDriveConfigurations(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
            return
        }

        applyDriveSoundSettings()

        for configuration in driveConfigurations {
            let driveType = configuration.isAttached ? configuration.driveType.rawValue : 0

            setVICEIntResource("Drive\(configuration.unit)Type", value: driveType)
            applyDriveAccessMode(configuration)
        }

        if updateStatus {
            statusText = "Drive settings updated"
        }
    }

    private func applyDriveConfigurationChanges(from oldConfigurations: [DriveConfiguration]) {
        guard ViceEngineIsRunning() else {
            return
        }

        guard driveConfigurations.map(\.unit) == oldConfigurations.map(\.unit) else {
            applyDriveConfigurations()
            return
        }

        var accessModeUpdates: [DriveConfiguration] = []
        var driveSoundSettingsChanged = false

        for configuration in driveConfigurations {
            guard let oldConfiguration = oldConfigurations.first(where: { $0.unit == configuration.unit }) else {
                applyDriveConfigurations()
                return
            }

            guard configuration != oldConfiguration else {
                continue
            }

            let driveHardwareUnchanged = configuration.isAttached == oldConfiguration.isAttached
                && configuration.driveType == oldConfiguration.driveType
            let accessModeChanged = configuration.accessMode != oldConfiguration.accessMode
            let driveSoundChanged = configuration.soundEnabled != oldConfiguration.soundEnabled
                || configuration.soundVolume != oldConfiguration.soundVolume

            guard driveHardwareUnchanged else {
                applyDriveConfigurations()
                return
            }

            if accessModeChanged {
                accessModeUpdates.append(configuration)
            }

            if driveSoundChanged {
                driveSoundSettingsChanged = true
            }

            guard accessModeChanged || driveSoundChanged else {
                applyDriveConfigurations()
                return
            }
        }

        if driveSoundSettingsChanged {
            applyDriveSoundSettings()
        }

        for configuration in accessModeUpdates {
            applyDriveAccessMode(configuration)
        }
    }

    private func applyDriveSoundSettings() {
        let driveSoundEnabled = driveConfigurations.contains { $0.isAttached && $0.soundEnabled }
        setVICEIntResource("DriveSoundEmulation", value: driveSoundEnabled ? 1 : 0)
        if driveSoundEnabled,
           let volume = driveConfigurations
               .filter({ $0.isAttached && $0.soundEnabled })
               .map(\.viceSoundVolume)
               .max() {
            setVICEIntResource("DriveSoundEmulationVolume", value: volume)
        }
    }

    private func applyDriveAccessMode(_ configuration: DriveConfiguration) {
        let accessMode = configuration.isAttached ? configuration.accessMode : DriveAccessMode.native

        setVICEIntResource("Drive\(configuration.unit)TrueEmulation",
                           value: accessMode.trueDriveEmulationResourceValue)
        setVICEIntResource("TrapDevice\(configuration.unit)",
                           value: accessMode.trapDeviceResourceValue)
    }

    private func setVICEIntResource(_ name: String, value: Int32) {
        name.withCString { resourceName in
            _ = ViceEngineSetIntResource(resourceName, value)
        }
    }

    private func setVICEStringResource(_ name: String, value: String) {
        name.withCString { resourceName in
            value.withCString { resourceValue in
                _ = ViceEngineSetStringResource(resourceName, resourceValue)
            }
        }
    }

    private func handleKeyboardJoystickEvent(_ event: NSEvent, pressed: Bool) -> Bool {
        let matchingDevices = assignedControlDevices(kind: .keyboard).filter { device in
            device.keyboard.joystickBit(for: event.keyCode) != nil
        }

        guard !matchingDevices.isEmpty else {
            return false
        }

        if pressed, event.isARepeat {
            return true
        }

        for device in matchingDevices {
            if pressed {
                keyboardJoystickPressedKeys[device.id, default: []].insert(event.keyCode)
            } else {
                keyboardJoystickPressedKeys[device.id, default: []].remove(event.keyCode)
            }

            publishKeyboardJoystickValue(for: device, force: false)
        }

        return true
    }

    private func keyboardJoystickValue(for device: ControlDeviceConfiguration) -> UInt16 {
        var pressedBits: UInt16 = 0

        for keyCode in keyboardJoystickPressedKeys[device.id, default: []] {
            if let bit = device.keyboard.joystickBit(for: keyCode) {
                pressedBits |= bit
            }
        }

        return normalizedJoystickValue(pressedBits)
    }

    private func setupGameControllerMonitoring() {
        let connectObserver = NotificationCenter.default.addObserver(forName: .GCControllerDidConnect,
                                                                     object: nil,
                                                                     queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refreshGameControllers()
            }
        }
        let disconnectObserver = NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect,
                                                                        object: nil,
                                                                        queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refreshGameControllers()
            }
        }

        gameControllerObservers = [connectObserver, disconnectObserver]
        GCController.startWirelessControllerDiscovery()
        refreshGameControllers()
    }

    private func refreshGameControllers() {
        let controllers = GCController.controllers()
        gameControllerNames = Array(Set(controllers.map(Self.displayName(for:))))

        for controller in controllers {
            installGameControllerHandlers(controller)
        }

        publishGameControllerValues(force: true)
    }

    private func installGameControllerHandlers(_ controller: GCController) {
        controller.extendedGamepad?.valueChangedHandler = { [weak self, weak controller] _, _ in
            guard let controller else {
                return
            }

            Task { @MainActor in
                self?.handleGameControllerChanged(controller: controller)
            }
        }

        controller.microGamepad?.valueChangedHandler = { [weak self, weak controller] _, _ in
            guard let controller else {
                return
            }

            Task { @MainActor in
                self?.handleGameControllerChanged(controller: controller)
            }
        }
    }

    private func handleGameControllerChanged(controller: GCController) {
        guard assignedControlDevices(kind: .joystick).contains(where: { device in
            gameController(for: device) === controller
        }) else {
            return
        }

        publishGameControllerValues(force: false)
    }

    private func publishGameControllerValues(force: Bool) {
        for device in assignedControlDevices(kind: .joystick) {
            let value = gameControllerValue(for: device)
            publishJoystickValue(value, for: device, force: force)
        }
    }

    private func gameControllerValue(for device: ControlDeviceConfiguration) -> UInt16 {
        guard let controller = gameController(for: device) else {
            return 0
        }

        if let extendedGamepad = controller.extendedGamepad {
            return gameControllerValue(from: extendedGamepad, mapping: device.joystick)
        }
        if let microGamepad = controller.microGamepad {
            return gameControllerValue(from: microGamepad, mapping: device.joystick)
        }

        return 0
    }

    private func gameController(for device: ControlDeviceConfiguration) -> GCController? {
        let controllers = GCController.controllers()

        if let preferredControllerName = device.joystick.preferredControllerName {
            return controllers.first { Self.displayName(for: $0) == preferredControllerName }
        }

        return controllers.first
    }

    private func gameControllerValue(from gamepad: GCExtendedGamepad,
                                     mapping: GameControllerJoystickMapping) -> UInt16 {
        let deadZone = Float(mapping.deadZone)
        var value: UInt16 = 0

        for action in JoystickAction.allCases where mapping.control(for: action).isActive(on: gamepad, deadZone: deadZone) {
            value |= action.bit
        }

        return normalizedJoystickValue(value)
    }

    private func gameControllerValue(from gamepad: GCMicroGamepad,
                                     mapping: GameControllerJoystickMapping) -> UInt16 {
        let deadZone = Float(mapping.deadZone)
        var value: UInt16 = 0

        for action in JoystickAction.allCases where mapping.control(for: action).isActive(on: gamepad, deadZone: deadZone) {
            value |= action.bit
        }

        return normalizedJoystickValue(value)
    }

    private func normalizedJoystickValue(_ value: UInt16) -> UInt16 {
        var normalizedValue = value

        if (normalizedValue & JoystickBits.up) != 0,
           (normalizedValue & JoystickBits.down) != 0 {
            normalizedValue &= ~(JoystickBits.up | JoystickBits.down)
        }

        if (normalizedValue & JoystickBits.left) != 0,
           (normalizedValue & JoystickBits.right) != 0 {
            normalizedValue &= ~(JoystickBits.left | JoystickBits.right)
        }

        return normalizedValue
    }

    private func publishKeyboardJoystickValues(force: Bool) {
        for device in assignedControlDevices(kind: .keyboard) {
            publishKeyboardJoystickValue(for: device, force: force)
        }
    }

    private func publishKeyboardJoystickValue(for device: ControlDeviceConfiguration, force: Bool) {
        let value = keyboardJoystickValue(for: device)
        publishJoystickValue(value, for: device, force: force)
    }

    private func publishJoystickValue(_ value: UInt16, for device: ControlDeviceConfiguration, force: Bool) {
        if force || lastJoystickValues[device.id] != value {
            lastJoystickValues[device.id] = value
            publishJoystickValue(value, forDeviceID: device.id)
        }
    }

    private func publishJoystickValue(_ value: UInt16, forDeviceID deviceID: UUID) {
        for port in availableControlPorts where controlPorts.assignedDeviceID(for: port) == deviceID {
            publishJoystickValue(value, to: port)
        }
    }

    private func currentJoystickValue(for device: ControlDeviceConfiguration) -> UInt16 {
        switch device.kind {
        case .keyboard:
            return keyboardJoystickValue(for: device)
        case .joystick:
            return gameControllerValue(for: device)
        }
    }

    private func assignedControlDevices(kind: ControlDeviceKind) -> [ControlDeviceConfiguration] {
        var devices: [ControlDeviceConfiguration] = []

        for port in availableControlPorts {
            guard let device = controlPorts.assignedDevice(for: port),
                  device.kind == kind,
                  !devices.contains(where: { $0.id == device.id }) else {
                continue
            }

            devices.append(device)
        }

        return devices
    }

    private func publishJoystickValue(_ value: UInt16, to port: ControlPort) {
        let normalizedValue = value & JoystickBits.all
        if controlPortValues[port] != normalizedValue {
            controlPortValues[port] = normalizedValue
        }

        guard ViceEngineIsRunning() else {
            return
        }

        _ = ViceEngineSetJoystickValue(port.joystickIndex, UInt32(normalizedValue))
    }

    private func uniqueControlDeviceName(baseName: String) -> String {
        let existingNames = Set(controlPorts.devices.map(\.name))

        guard existingNames.contains(baseName) else {
            return baseName
        }

        for index in 2...99 {
            let candidate = "\(baseName) \(index)"
            if !existingNames.contains(candidate) {
                return candidate
            }
        }

        return "\(baseName) \(controlPorts.devices.count + 1)"
    }

    private static func displayName(for controller: GCController) -> String {
        controller.vendorName ?? "Game Controller"
    }

}

private enum ViceResource {
    static let speed = "Speed"
    static let sidModel = "SidModel"
    static let sound = "Sound"
    static let soundVolume = "SoundVolume"
    static let reu = "REU"
    static let reuSize = "REUsize"
    static let georam = "GEORAM"
    static let georamSize = "GEORAMsize"
    static let ramCart = "RAMCART"
    static let ramCartSize = "RAMCARTsize"
    static let dqbb = "DQBB"
    static let dqbbSize = "DQBBSize"
    static let dqbbMode = "DQBBMode"
    static let isepicCartridgeEnabled = "IsepicCartridgeEnabled"
    static let isepicSwitch = "IsepicSwitch"
    static let memoryHack = "MemoryHack"
    static let c64_256kBase = "C64_256Kbase"
    static let plus60kBase = "PLUS60Kbase"
    static let vic20RAMBlocks: [(block: Int, name: String)] = [
        (0, "RAMBlock0"),
        (1, "RAMBlock1"),
        (2, "RAMBlock2"),
        (3, "RAMBlock3"),
        (5, "RAMBlock5")
    ]
}

private enum ViceDQBBMode {
    static let c64: Int32 = 1
}

private extension Array where Element == String {
    func withCStringArray<Result>(
        _ body: (Int32, UnsafePointer<UnsafePointer<CChar>?>?) -> Result
    ) -> Result? {
        guard count <= Int(Int32.max) else {
            return nil
        }

        var cStrings: [UnsafeMutablePointer<CChar>] = []
        cStrings.reserveCapacity(count)

        for string in self {
            guard let cString = strdup(string) else {
                for cString in cStrings {
                    free(cString)
                }
                return nil
            }
            cStrings.append(cString)
        }
        defer {
            for cString in cStrings {
                free(cString)
            }
        }

        var pointers = cStrings.map { Optional(UnsafePointer<CChar>($0)) }
        pointers.append(nil)

        return pointers.withUnsafeBufferPointer { buffer in
            body(Int32(count), buffer.baseAddress)
        }
    }
}
