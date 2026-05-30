import AppKit
import Combine
import Darwin
import Foundation
import GameController
import ImageIO
@preconcurrency import Network
import UniformTypeIdentifiers

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
    @Published private var driveActivities: [Int: DriveActivity] = [:]
    @Published var cartridgeStatus = CartridgeStatus.detached
    @Published private(set) var tapeImagePath: String?
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
    @Published private(set) var printSpoolPages: [PrinterSpoolPage] = []
    @Published private(set) var networkModemStatus: NetworkModemRuntimeStatus = .disabled

    let frameSource: EmulatorFrameSource
    private var didStartEngine = false

    var isMachineRunning: Bool {
        ViceEngineIsRunning()
    }

    private var pressedKeys: [UInt16: PressedEmulatorKey] = [:]
    private var keyboardJoystickPressedKeys: [UUID: Set<UInt16>] = [:]
    private var lastJoystickValues: [UUID: UInt16] = [:]
    private var pressedMouseButtons = Set<UInt32>()
    private var gameControllerObservers: [NSObjectProtocol] = []
    private var pausedBecauseAppInactive = false
    private var printQueueTimer: Timer?
    private let hayesModemService = HayesModemService()

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

    nonisolated static func printSpoolDirectoryURL(for machine: EmulatedMachine) -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        return baseURL
            .appendingPathComponent("mac VICE", isDirectory: true)
            .appendingPathComponent("Print Spool", isDirectory: true)
            .appendingPathComponent(machine.id.rawValue, isDirectory: true)
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
        frameSource = EmulatorFrameSource.displaySource(for: machine)
        if !loadedSyncSystemTime && loadedNetworkModem.usesActiveUserPort {
            EmulatorDefaults.saveSyncSystemTime(false, for: machine)
        }
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

    var isRAMExpansionConfigured: Bool {
        machine.capabilities.supportsRAMExpansion && ramExpansion != .none
    }

    var activeMachineModel: MachineModel {
        switch machine.family {
        case .c64:
            return .x64sc(c64Model)
        case .c128:
            return .x128(c128Model)
        case .pet:
            return .xpet(petModel)
        case .vic20, .ted:
            return machine.model
        }
    }

    var keyboardMappingMachine: EmulatedMachine {
        guard machine.family == .pet else {
            return machine
        }

        return EmulatedMachine(id: machine.id,
                               model: .xpet(petModel),
                               displayName: petModel.displayName,
                               shortName: machine.shortName,
                               viceTarget: machine.viceTarget,
                               dynamicLibraryName: machine.dynamicLibraryName,
                               displayProfile: machine.displayProfile,
                               startupOptions: machine.startupOptions,
                               displayOutputs: machine.displayOutputs,
                               romSlots: machine.romSlots,
                               ramExpansions: machine.ramExpansions,
                               capabilities: machine.capabilities,
                               videoStandardResources: machine.videoStandardResources)
    }

    var machineDisplayName: String {
        activeMachineModel.displayName ?? machine.displayName
    }

    var machineModelStatusTitle: String? {
        guard activeMachineModel.supportsRuntimeModelSelection else {
            return nil
        }

        return activeMachineModel.statusChipTitle
    }

    var availableControlPorts: [ControlPort] {
        machine.capabilities.controlPorts
    }

    var availableModemInterfaces: [NetworkModemInterface] {
        machine.capabilities.supportedModemInterfaces
    }

    var availableModemACIAAddresses: [NetworkModemACIAAddress] {
        NetworkModemACIAAddress.supportedAddresses(for: machine)
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

    var isMacMouseInputActive: Bool {
        isMouse1351Assigned
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

    var printSpoolDirectoryURL: URL {
        Self.printSpoolDirectoryURL(for: machine)
    }

    var printSpoolBaseURL: URL {
        printSpoolDirectoryURL.appendingPathComponent(PrinterSpoolPage.filenamePrefix)
    }

    var printSpoolBasePath: String {
        printSpoolBaseURL.path
    }

    var printQueueStatusTitle: String {
        switch printSpoolPages.count {
        case 0:
            return "No pages"
        case 1:
            return "1 page"
        default:
            return "\(printSpoolPages.count) pages"
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

    var pointerControlAssignment: PointerControlAssignment {
        let assignedPort = availableControlPorts.first { port in
            controlPorts.assignedDevice(for: port)?.kind == .mouse1351
        }

        return PointerControlAssignment(port: assignedPort)
    }

    func setPointerControlAssignment(_ assignment: PointerControlAssignment) {
        var updatedConfiguration = controlPorts

        for port in availableControlPorts where updatedConfiguration.assignedDevice(for: port)?.kind == .mouse1351 {
            updatedConfiguration.setAssignedDeviceID(nil, for: port)
        }

        if let port = assignment.port,
           availableControlPorts.contains(port) {
            let mouseID = existingMacMouseDeviceID(in: updatedConfiguration)
                ?? makeDefaultMacMouseDevice(in: &updatedConfiguration)
            updatedConfiguration.setAssignedDeviceID(mouseID, for: port)
        }

        controlPorts = updatedConfiguration
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
        case .mouse1351:
            return .connected
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
        case .mouse1351:
            return ControlDeviceConfiguration.mouse1351(name: uniqueControlDeviceName(baseName: "Mac Mouse 1351"))
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

    private func existingMacMouseDeviceID(in configuration: ControlPortConfiguration) -> UUID? {
        configuration.devices.first { $0.kind == .mouse1351 }?.id
    }

    private func makeDefaultMacMouseDevice(in configuration: inout ControlPortConfiguration) -> UUID {
        let device = ControlDeviceConfiguration.mouse1351(name: uniqueControlDeviceName(baseName: "Mac Mouse 1351"))
        configuration.devices.append(device)
        return device.id
    }

    func setKeyboardMappingMode(_ mode: VICEKeyboardMappingMode) {
        guard keyboardMapping.mode != mode else {
            return
        }

        keyboardMapping = VICEKeyboardMappingConfiguration(mode: mode,
                                                           profile: keyboardMapping.profile)
    }

    func useVICEKeyboardDefaults() {
        keyboardMapping = VICEKeyboardMappingConfiguration(mode: keyboardMapping.mode,
                                                           profile: .viceDefault)
    }

    @discardableResult
    func useCustomKeyboardMapping() -> Bool {
        do {
            try VICEKeymapStore.ensureCustomKeymap(for: keyboardMappingMachine, mode: keyboardMapping.mode)
            keyboardMapping = VICEKeyboardMappingConfiguration(mode: keyboardMapping.mode,
                                                               profile: .custom)
            return true
        } catch {
            statusText = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func saveKeyboardMapEntry(_ entry: VICEKeymapEntry) -> Bool {
        do {
            let document = try VICEKeymapStore.ensureCustomKeymap(for: keyboardMappingMachine,
                                                                  mode: keyboardMapping.mode)
                .updating(entry: entry)
                .syncingModifierDirectives(for: entry)
            let url = VICEKeymapStore.customKeymapURL(for: keyboardMappingMachine,
                                                      mode: keyboardMapping.mode)
            try VICEKeymapStore.save(document,
                                     to: url,
                                     title: "Custom \(machine.shortName) \(keyboardMapping.mode.shortTitle) map")
            keyboardMapping = VICEKeyboardMappingConfiguration(mode: keyboardMapping.mode,
                                                               profile: .custom)
            applyKeyboardMapping(forceReload: true)
            statusText = "Keyboard map updated"
            return true
        } catch {
            statusText = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func removeKeyboardMapEntry(_ entry: VICEKeymapEntry) -> Bool {
        do {
            let document = try VICEKeymapStore.ensureCustomKeymap(for: keyboardMappingMachine,
                                                                  mode: keyboardMapping.mode)
                .removingEntry(id: entry.id)
            let url = VICEKeymapStore.customKeymapURL(for: keyboardMappingMachine,
                                                      mode: keyboardMapping.mode)
            try VICEKeymapStore.save(document,
                                     to: url,
                                     title: "Custom \(machine.shortName) \(keyboardMapping.mode.shortTitle) map")
            keyboardMapping = VICEKeyboardMappingConfiguration(mode: keyboardMapping.mode,
                                                               profile: .custom)
            applyKeyboardMapping(forceReload: true)
            statusText = "Keyboard mapping removed"
            return true
        } catch {
            statusText = error.localizedDescription
            return false
        }
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

        preparePrintSpoolDirectory()
        let networkLocalPort: Int?
        do {
            networkLocalPort = try prepareNetworkModemForStartup()
        } catch {
            reportStartupFailure(
                status: "Unable to start modem",
                detail: error.localizedDescription
            )
            return
        }

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
                                                               mediaBehavior: mediaBehavior,
                                                               sidConfiguration: sidConfiguration,
                                                               tapeConfiguration: tapeConfiguration,
                                                               printerConfiguration: printerConfiguration,
                                                               printerOutputBasePath: printSpoolBasePath,
                                                               driveConfigurations: driveConfigurations,
                                                               syncSystemTime: syncSystemTime,
                                                               networkModem: networkModem,
                                                               networkLocalPort: networkLocalPort)
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
            hayesModemService.stop()
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
            hayesModemService.stop()
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
        pausedBecauseAppInactive = false
        isPaused.toggle()
    }

    func handleApplicationActivationChanged(isActive: Bool) {
        guard sessionBehavior.pauseWhenAppInactive else {
            return
        }

        if isActive {
            guard pausedBecauseAppInactive else {
                return
            }

            pausedBecauseAppInactive = false
            if isPaused {
                isPaused = false
            }
            return
        }

        guard !isPaused else {
            pausedBecauseAppInactive = false
            return
        }

        pausedBecauseAppInactive = true
        isPaused = true
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

    @discardableResult
    func handleMouseMoved(deltaX: CGFloat, deltaY: CGFloat) -> Bool {
        guard isMouse1351Assigned,
              ViceEngineIsRunning() else {
            return false
        }

        return ViceEngineMoveMouse(Float(deltaX), Float(deltaY))
    }

    @discardableResult
    func handleMouseButton(_ button: UInt32, pressed: Bool) -> Bool {
        guard isMouse1351Assigned,
              ViceEngineIsRunning() else {
            return false
        }

        if pressed {
            pressedMouseButtons.insert(button)
        } else {
            pressedMouseButtons.remove(button)
        }
        updateMouseControlPortValues()

        return ViceEngineSetMouseButton(button, pressed)
    }

    func handleMouseCaptureChanged(_ captured: Bool) {
        guard ViceEngineIsRunning() else {
            return
        }

        if !captured {
            releaseMouseButtons()
            _ = ViceEngineResetMouse()
        }
    }

    func releaseAllKeys() {
        pressedKeys.removeAll()
        keyboardJoystickPressedKeys.removeAll()
        ViceEngineReleaseAllKeys()
        releaseMouseButtons()

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
        openMedia(url: url, behavior: autorun ? .run : nil)
    }

    @discardableResult
    func openMedia(url: URL, behavior: MediaOpenBehavior?) -> Bool {
        guard let mediaFile = EmulatorMediaFile(url: url) else {
            let title = url.lastPathComponent.isEmpty ? "Media" : url.lastPathComponent
            statusText = "\(title) is not a supported media file"
            return false
        }

        let openBehavior = behavior ?? mediaBehavior.openBehavior

        switch mediaFile {
        case let .disk(diskImageType):
            return attachDiskToFirstCompatibleDrive(url: url,
                                                    diskImageType: diskImageType,
                                                    behavior: openBehavior)
        case let .autostart(type):
            if type == .tap,
               openBehavior == .attach {
                return attachTape(url: url)
            }

            let didOpen = autostartMedia(url: url, behavior: openBehavior == .attach ? .load : openBehavior)
            if didOpen,
               type == .tap {
                tapeImagePath = url.path
            }
            return didOpen
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
        attachDisk(to: unit, driveNumber: 0, url: url, behavior: autorun ? .run : .attach)
    }

    @discardableResult
    func attachDisk(to unit: Int, driveNumber: Int, url: URL, autorun: Bool) -> Bool {
        attachDisk(to: unit, driveNumber: driveNumber, url: url, behavior: autorun ? .run : .attach)
    }

    @discardableResult
    func attachDisk(to unit: Int, driveNumber: Int, url: URL, behavior: MediaOpenBehavior) -> Bool {
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

        applyDiskWriteProtection(configuration)
        applyMediaBehavior(updateStatus: false)

        let didAttach = url.path.withCString { path in
            ViceEngineAttachDisk(UInt32(unit), UInt32(driveNumber), path, behavior.viceRunMode)
        }

        if didAttach {
            rememberMedia(url)
            statusText = "\(url.lastPathComponent) \(behavior.statusVerb) on \(driveAddress(unit: unit, driveNumber: driveNumber))"
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
        autostartMedia(url: url, behavior: autorun ? .run : .load)
    }

    @discardableResult
    func autostartMedia(url: URL, behavior: MediaOpenBehavior) -> Bool {
        let runBehavior = behavior == .attach ? MediaOpenBehavior.load : behavior
        applyMediaBehavior(updateStatus: false)

        let didStart = url.path.withCString { path in
            ViceEngineAutostartMedia(path, runBehavior.viceRunMode)
        }

        if didStart {
            rememberMedia(url)
            statusText = "\(url.lastPathComponent) \(runBehavior.statusVerb)"
        } else {
            statusText = "Unable to open \(url.lastPathComponent)"
        }

        return didStart
    }

    @discardableResult
    func attachTape(url: URL) -> Bool {
        guard machine.capabilities.supportsTape else {
            statusText = "\(machineDisplayName) does not support tape media"
            return false
        }

        applyTapeConfiguration(updateStatus: false)

        let didAttach = url.path.withCString { path in
            ViceEngineAttachTape(1, path)
        }

        if didAttach {
            tapeImagePath = url.path
            rememberMedia(url)
            statusText = "\(url.lastPathComponent) attached to Datasette"
        } else {
            statusText = "Unable to attach \(url.lastPathComponent)"
        }

        return didAttach
    }

    func detachTape() {
        guard machine.capabilities.supportsTape else {
            return
        }

        if ViceEngineDetachTape(1) {
            tapeImagePath = nil
            statusText = "Tape ejected"
        } else {
            statusText = "Unable to eject tape"
        }
    }

    func controlTape(_ command: TapeControlCommand) {
        guard machine.capabilities.supportsTape else {
            return
        }

        if ViceEngineControlTape(1, command.rawValue) {
            statusText = "Datasette \(command.title.lowercased())"
        }
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
            ViceEngineSaveSnapshot(path,
                                   snapshotConfiguration.includesROMImages,
                                   snapshotConfiguration.includesAttachedDisks)
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
    func exportScreenshot(url: URL) -> Bool {
        guard let frame = frameSource.copyLatestFrame() else {
            statusText = "No emulator frame is available yet"
            return false
        }

        do {
            try Self.writePNG(frame: frame, to: url)
            rememberMedia(url)
            statusText = "Screenshot exported"
            return true
        } catch {
            statusText = "Unable to export screenshot"
            return false
        }
    }

    func refreshPrintQueue() {
        preparePrintSpoolDirectory()
        let pages = Self.loadPrintSpoolPages(from: printSpoolDirectoryURL)
        if pages != printSpoolPages {
            printSpoolPages = pages
        }
    }

    func clearPrintQueue() {
        for page in printSpoolPages {
            try? FileManager.default.removeItem(at: page.url)
        }
        refreshPrintQueue()
        statusText = "Print queue cleared"
    }

    @discardableResult
    func exportPrintQueuePDF(to url: URL) -> Bool {
        refreshPrintQueue()
        guard !printSpoolPages.isEmpty else {
            statusText = "No printed pages"
            return false
        }

        do {
            try Self.writePDF(pages: printSpoolPages, to: url)
            rememberMedia(url)
            statusText = "Printout saved"
            return true
        } catch {
            statusText = "Unable to save printout"
            return false
        }
    }

    func printQueuedPages() {
        refreshPrintQueue()
        guard !printSpoolPages.isEmpty else {
            statusText = "No printed pages"
            return
        }

        let view = PrinterSpoolPrintView(pageURLs: printSpoolPages.map(\.url))
        let printInfo = NSPrintInfo.shared.copy() as? NSPrintInfo ?? NSPrintInfo.shared
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .fit
        printInfo.isHorizontallyCentered = true
        printInfo.isVerticallyCentered = true

        let operation = NSPrintOperation(view: view, printInfo: printInfo)
        operation.jobTitle = "\(machine.shortName) Printout"
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
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
                                                  behavior: MediaOpenBehavior) -> Bool {
        guard let target = firstCompatibleDriveTarget(for: diskImageType) else {
            statusText = "No enabled drive supports \(diskImageType.title) images"
            return false
        }

        return attachDisk(to: target.unit,
                          driveNumber: target.driveNumber,
                          url: url,
                          behavior: behavior)
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

    private func startPrintQueueMonitoring() {
        printQueueTimer?.invalidate()
        printQueueTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPrintQueue()
            }
        }
    }

    private func preparePrintSpoolDirectory() {
        try? FileManager.default.createDirectory(at: printSpoolDirectoryURL,
                                                 withIntermediateDirectories: true)
    }

    private static func loadPrintSpoolPages(from directoryURL: URL) -> [PrinterSpoolPage] {
        guard let urls = try? FileManager.default.contentsOfDirectory(at: directoryURL,
                                                                      includingPropertiesForKeys: [
                                                                        .contentModificationDateKey,
                                                                        .fileSizeKey,
                                                                        .isRegularFileKey
                                                                      ],
                                                                      options: [.skipsHiddenFiles]) else {
            return []
        }

        return urls
            .filter { url in
                url.pathExtension.lowercased() == "bmp"
                    && url.deletingPathExtension().lastPathComponent.hasPrefix(PrinterSpoolPage.filenamePrefix)
            }
            .compactMap { url -> PrinterSpoolPage? in
                guard let values = try? url.resourceValues(forKeys: [
                    .contentModificationDateKey,
                    .fileSizeKey,
                    .isRegularFileKey
                ]),
                      values.isRegularFile == true else {
                    return nil
                }

                return PrinterSpoolPage(url: url,
                                        byteCount: values.fileSize ?? 0,
                                        modifiedAt: values.contentModificationDate ?? .distantPast)
            }
            .sorted { lhs, rhs in
                if lhs.modifiedAt == rhs.modifiedAt {
                    return lhs.url.lastPathComponent < rhs.url.lastPathComponent
                }
                return lhs.modifiedAt < rhs.modifiedAt
            }
    }

    private static func writePNG(frame: EmulatorVideoFrame, to url: URL) throws {
        guard frame.width > 0,
              frame.height > 0,
              frame.bytesPerRow >= frame.width * 4,
              frame.pixels.count >= frame.bytesPerRow * frame.height else {
            throw CocoaError(.fileWriteUnknown)
        }

        guard let provider = CGDataProvider(data: frame.pixels as CFData),
              let image = CGImage(width: frame.width,
                                  height: frame.height,
                                  bitsPerComponent: 8,
                                  bitsPerPixel: 32,
                                  bytesPerRow: frame.bytesPerRow,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider,
                                  decode: nil,
                                  shouldInterpolate: false,
                                  intent: .defaultIntent),
              let destination = CGImageDestinationCreateWithURL(url as CFURL,
                                                               UTType.png.identifier as CFString,
                                                               1,
                                                               nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }

    private static func writePDF(pages: [PrinterSpoolPage], to url: URL) throws {
        let renderedPages = try pages.map { page -> (image: CGImage, box: CGRect) in
            let source = try imageSource(for: page.url)
            let image = try cgImage(from: source)
            return (image, pdfPageBox(for: source, image: image))
        }

        guard let firstPage = renderedPages.first else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        var mediaBox = firstPage.box
        guard let context = CGContext(url as CFURL, mediaBox: &mediaBox, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        for page in renderedPages {
            context.beginPDFPage(nil)
            context.interpolationQuality = .none
            context.draw(page.image, in: mediaBox)
            context.endPDFPage()
        }
        context.closePDF()
    }

    private static func imageSource(for url: URL) throws -> CGImageSource {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, [
            kCGImageSourceShouldCache: true
        ] as CFDictionary) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return source
    }

    private static func cgImage(from source: CGImageSource) throws -> CGImage {
        guard let image = CGImageSourceCreateImageAtIndex(source, 0, [
            kCGImageSourceShouldCache: true
        ] as CFDictionary) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        return image
    }

    private static func pdfPageBox(for source: CGImageSource, image: CGImage) -> CGRect {
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let dpiX = properties?[kCGImagePropertyDPIWidth] as? CGFloat ?? 72
        let dpiY = properties?[kCGImagePropertyDPIHeight] as? CGFloat ?? 72
        let width = CGFloat(image.width) * 72 / max(dpiX, 1)
        let height = CGFloat(image.height) * 72 / max(dpiY, 1)

        return CGRect(x: 0, y: 0, width: max(width, 1), height: max(height, 1))
    }

    private func applyRuntimeConfiguration() {
        if machine.supportsRuntimeVideoStandardUpdates {
            applyVideoStandard(updateStatus: false)
        }
        applySessionBehavior(oldValue: sessionBehavior)
        applyMediaBehavior(updateStatus: false)
        applyPrinterConfiguration(updateStatus: false)
        applySIDModel(updateStatus: false)
        applySIDConfiguration(updateStatus: false)
        applySoundSettings(updateStatus: false)
        applyTapeConfiguration(updateStatus: false)
        applyEmulationSpeed(updateStatus: false)
        applyDisplayOutput(updateStatus: false)
        applyPauseState(updateStatus: false)
        applyNetworkModem(updateStatus: false)
        if machine.supportsRuntimeROMImageUpdates {
            applyROMImages()
        }
        applyRAMExpansion(updateStatus: false)
        applyKeyboardMapping(updateStatus: false)
        applyControlPorts()
        applySystemTimeSync(updateStatus: false)
    }

    private func prepareNetworkModemForStartup() throws -> Int? {
        let configuration = networkModem.normalized(for: machine)
        guard configuration.isEnabled,
              machine.capabilities.supportsNetworking else {
            hayesModemService.stop()
            networkModemStatus = .disabled
            return nil
        }

        return try hayesModemService.start(configuration: configuration) { [weak self] status in
            Task { @MainActor [weak self] in
                self?.networkModemStatus = status
            }
        }
    }

    private func applySessionBehavior(oldValue: SessionBehaviorConfiguration) {
        guard oldValue.pauseWhenAppInactive,
              !sessionBehavior.pauseWhenAppInactive,
              pausedBecauseAppInactive else {
            return
        }

        pausedBecauseAppInactive = false
        if isPaused {
            isPaused = false
        }
    }

    private func applySystemTimeSync(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              machine.capabilities.supportsSystemTimeSync else {
            return
        }

        if ViceEngineSetSystemTimeSyncEnabled(syncSystemTime), updateStatus {
            statusText = syncSystemTime ? "System time synced" : "System time sync off"
        }
    }

    private func applyNetworkModem(updateStatus: Bool = true) {
        guard machine.capabilities.supportsNetworking else {
            hayesModemService.stop()
            networkModemStatus = .disabled
            return
        }

        let configuration = networkModem.normalized(for: machine)
        guard configuration.isEnabled else {
            hayesModemService.stop()
            networkModemStatus = .disabled
            if ViceEngineIsRunning() {
                setVICEIntResource("Acia1Enable", value: 0)
                if !syncSystemTime {
                    setVICEIntResource("UserportDevice", value: 0)
                }
            }
            if updateStatus {
                statusText = "Modem off"
            }
            return
        }

        do {
            let localPort = try hayesModemService.start(configuration: configuration) { [weak self] status in
                Task { @MainActor [weak self] in
                    self?.networkModemStatus = status
                }
            }

            guard ViceEngineIsRunning() else {
                return
            }

            applyNetworkModemResources(configuration: configuration,
                                       localPort: localPort)

            if updateStatus {
                statusText = "Modem \(configuration.interface.shortTitle.lowercased()) ready"
            }
        } catch {
            networkModemStatus = NetworkModemRuntimeStatus(state: .error,
                                                           localPort: nil,
                                                           incomingPort: configuration.acceptsIncomingCalls
                                                           ? configuration.incomingPort
                                                           : nil,
                                                           remoteDescription: nil,
                                                           message: error.localizedDescription)
            if updateStatus {
                statusText = "Modem unavailable"
            }
        }
    }

    private func applyNetworkModemResources(configuration: NetworkModemConfiguration,
                                            localPort: Int) {
        setVICEStringResource("RsDevice3", value: "127.0.0.1:\(localPort)")
        setVICEIntResource("RsDevice3ip232", value: configuration.interface.usesIP232Control ? 1 : 0)

        switch configuration.interface {
        case .userPort:
            setVICEIntResource("Acia1Enable", value: 0)
            setVICEIntResource("UserportDevice", value: 2)
            setVICEIntResource("RsUserDev", value: 2)
            setVICEIntResource("RsUserBaud", value: Int32(configuration.baudRate))
        case .swiftLink, .turbo232:
            if !syncSystemTime {
                setVICEIntResource("UserportDevice", value: 0)
            }
            setVICEIntResource("Acia1Dev", value: 2)
            setVICEIntResource("Acia1Mode", value: configuration.interface.aciaMode ?? 1)
            setVICEIntResource("Acia1Base", value: configuration.aciaBaseAddress.rawValue)
            setVICEIntResource("Acia1Enable", value: 1)
        }
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

        if case .x64sc = activeMachineModel {
            applyMachineModel(updateStatus: false)
            applySIDModel(updateStatus: false)
            applySIDConfiguration(updateStatus: false)
            applyROMImages()
            applyDriveConfigurations(updateStatus: false)
        } else {
            for assignment in machine.videoStandardAssignments(for: videoStandard) {
                setVICEIntResource(assignment.name, value: assignment.value)
            }
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

    private func applySIDConfiguration(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              machine.capabilities.supportsSIDModelSelection else {
            return
        }

        setVICEIntResource("Sid2AddressStart", value: sidConfiguration.secondAddress.rawValue)
        setVICEIntResource("Sid3AddressStart", value: sidConfiguration.thirdAddress.rawValue)
        setVICEIntResource("SidStereo", value: sidConfiguration.layout.extraSIDCount)

        if updateStatus {
            statusText = sidConfiguration.layout.title
        }
    }

    private func applyMediaBehavior(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
            return
        }

        setVICEIntResource("AutostartWarp", value: mediaBehavior.warpDuringAutostart ? 1 : 0)
        setVICEIntResource("AutostartHandleTrueDriveEmulation",
                           value: mediaBehavior.useTrueDriveDuringAutostart ? 1 : 0)

        if updateStatus {
            statusText = "Media opens with \(mediaBehavior.openBehavior.title.lowercased())"
        }
    }

    private func applyPrinterConfiguration(updateStatus: Bool = true,
                                           previousDeviceNumber: Int? = nil) {
        guard ViceEngineIsRunning() else {
            return
        }

        preparePrintSpoolDirectory()

        let device = printerConfiguration.deviceNumber
        if let previousDeviceNumber,
           previousDeviceNumber != device {
            setVICEIntResource("Printer\(previousDeviceNumber)", value: 0)
            setVICEIntResource("BusDevice\(previousDeviceNumber)", value: 0)
        }

        setVICEStringResource("PrinterTextDevice1", value: printSpoolBasePath)
        setVICEIntResource("Printer\(device)TextDevice", value: 0)
        setVICEStringResource("Printer\(device)Driver", value: printerConfiguration.model.viceDriverName)
        setVICEStringResource("Printer\(device)Output", value: printerConfiguration.model.outputMode)
        setVICEIntResource("Printer\(device)", value: printerConfiguration.isEnabled ? 1 : 0)
        setVICEIntResource("BusDevice\(device)", value: printerConfiguration.isEnabled ? 1 : 0)

        if updateStatus {
            statusText = "Printer \(printerConfiguration.statusTitle.lowercased())"
        }
    }

    private func applyTapeConfiguration(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              machine.capabilities.supportsTape else {
            return
        }

        setVICEIntResource("TapePort1Device", value: tapeConfiguration.isDatasetteEnabled ? 1 : 0)
        setVICEIntResource("DatasetteSound", value: tapeConfiguration.soundEnabled ? 1 : 0)
        setVICEIntResource("DatasetteSoundVolume", value: tapeConfiguration.viceSoundVolume)

        if updateStatus {
            statusText = tapeConfiguration.isDatasetteEnabled ? "Datasette connected" : "Datasette disconnected"
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

    private func applyMachineModelChange(_ model: MachineModel) {
        if let defaultSIDModel = model.defaultSIDModel,
           sidModel != defaultSIDModel {
            sidModel = defaultSIDModel
        }

        applyMachineModel()
        applySIDModel(updateStatus: false)
        applySIDConfiguration(updateStatus: false)
        applyROMImages()
        applyDriveConfigurations(updateStatus: false)
    }

    private func applyMachineModel(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              activeMachineModel.supportsRuntimeModelSelection,
              let modelName = activeMachineModel.viceModelName(for: videoStandard) else {
            return
        }

        let didQueueModel = modelName.withCString { modelNamePointer in
            ViceEngineSetMachineModel(modelNamePointer)
        }
        guard didQueueModel else {
            if updateStatus {
                statusText = "\(machineDisplayName) model unavailable"
            }
            return
        }

        if updateStatus {
            statusText = machineDisplayName
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

    private func applyKeyboardMapping(updateStatus: Bool = true, forceReload: Bool = false) {
        guard ViceEngineIsRunning() else {
            return
        }

        if keyboardMapping.profile == .custom {
            do {
                try VICEKeymapStore.ensureCustomKeymap(for: keyboardMappingMachine,
                                                       mode: keyboardMapping.mode)
                setVICEStringResource(keyboardMapping.mode.userResourceName,
                                      value: VICEKeymapStore.customKeymapURL(for: keyboardMappingMachine,
                                                                             mode: keyboardMapping.mode).path)
                if forceReload {
                    setVICEIntResource("KeymapIndex", value: keyboardMapping.mode.defaultKeymapIndex)
                }
            } catch {
                statusText = error.localizedDescription
                return
            }
        }

        setVICEIntResource("KeymapIndex", value: keyboardMapping.keymapIndex)

        if updateStatus {
            statusText = "Keyboard \(keyboardMapping.statusTitle)"
        }
    }

    private func applyControlPorts() {
        guard ViceEngineIsRunning() else {
            return
        }

        var hasMouse1351 = false

        for port in availableControlPorts {
            guard let controlDevice = controlPorts.assignedDevice(for: port) else {
                setVICEIntResource(port.resourceName, value: ViceJoyPortDevice.none)
                publishJoystickValue(0, to: port)
                continue
            }

            setVICEIntResource(port.resourceName, value: controlDevice.kind.viceJoyPortDevice)
            if controlDevice.kind == .mouse1351 {
                hasMouse1351 = true
                controlPortValues[port] = mouseButtonJoystickValue
            } else {
                publishJoystickValue(currentJoystickValue(for: controlDevice), to: port)
            }
        }

        setVICEIntResource("Mouse", value: hasMouse1351 ? 1 : 0)
        if !hasMouse1351 {
            releaseMouseButtons()
            _ = ViceEngineResetMouse()
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
            applyDiskWriteProtection(configuration)
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
        var driveProtectionUpdates: [DriveConfiguration] = []
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
            let driveProtectionChanged = configuration.protectsInsertedDisks != oldConfiguration.protectsInsertedDisks
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

            if driveProtectionChanged {
                driveProtectionUpdates.append(configuration)
            }

            guard accessModeChanged || driveSoundChanged || driveProtectionChanged else {
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

        for configuration in driveProtectionUpdates {
            applyDiskWriteProtection(configuration)
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

    private func applyDiskWriteProtection(_ configuration: DriveConfiguration) {
        for driveNumber in configuration.driveType.driveNumbers {
            setVICEIntResource("AttachDevice\(configuration.unit)d\(driveNumber)Readonly",
                               value: configuration.protectsInsertedDisks ? 1 : 0)
        }
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
        case .mouse1351:
            return 0
        }
    }

    private var isMouse1351Assigned: Bool {
        availableControlPorts.contains { port in
            controlPorts.assignedDevice(for: port)?.kind == .mouse1351
        }
    }

    private var mouseButtonJoystickValue: UInt16 {
        var value: UInt16 = 0

        if pressedMouseButtons.contains(0) {
            value |= JoystickBits.fire
        }
        if pressedMouseButtons.contains(2) {
            value |= JoystickBits.up
        }

        return value
    }

    private func updateMouseControlPortValues() {
        for port in availableControlPorts where controlPorts.assignedDevice(for: port)?.kind == .mouse1351 {
            controlPortValues[port] = mouseButtonJoystickValue
        }
    }

    private func releaseMouseButtons() {
        guard !pressedMouseButtons.isEmpty else {
            return
        }

        let buttons = pressedMouseButtons
        pressedMouseButtons.removeAll()
        for button in buttons {
            _ = ViceEngineSetMouseButton(button, false)
        }
        updateMouseControlPortValues()
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

private final class PrinterSpoolPrintView: NSView {
    private let images: [NSImage]
    private let paperSize: NSSize

    init(pageURLs: [URL]) {
        images = pageURLs.compactMap(NSImage.init(contentsOf:))
        let printInfo = NSPrintInfo.shared
        paperSize = printInfo.paperSize
        super.init(frame: NSRect(x: 0,
                                 y: 0,
                                 width: max(printInfo.paperSize.width, 1),
                                 height: max(printInfo.paperSize.height * CGFloat(max(images.count, 1)), 1)))
    }

    required init?(coder: NSCoder) {
        images = []
        paperSize = NSPrintInfo.shared.paperSize
        super.init(coder: coder)
    }

    override var isFlipped: Bool {
        true
    }

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        range.pointee = NSRange(location: 1, length: max(images.count, 1))
        return true
    }

    override func rectForPage(_ page: Int) -> NSRect {
        NSRect(x: 0,
               y: CGFloat(max(page - 1, 0)) * paperSize.height,
               width: paperSize.width,
               height: paperSize.height)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill()
        dirtyRect.fill()

        for (index, image) in images.enumerated() {
            let pageRect = rectForPage(index + 1)
            guard dirtyRect.intersects(pageRect) else {
                continue
            }

            let destination = image.size.scaledToFit(in: pageRect.insetBy(dx: 36, dy: 36))
            image.draw(in: destination,
                       from: .zero,
                       operation: .sourceOver,
                       fraction: 1)
        }
    }
}

private extension NSSize {
    func scaledToFit(in rect: NSRect) -> NSRect {
        guard width > 0,
              height > 0,
              rect.width > 0,
              rect.height > 0 else {
            return rect
        }

        let scale = min(rect.width / width, rect.height / height)
        let scaledSize = NSSize(width: width * scale, height: height * scale)

        return NSRect(x: rect.midX - scaledSize.width / 2,
                      y: rect.midY - scaledSize.height / 2,
                      width: scaledSize.width,
                      height: scaledSize.height)
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

extension Array where Element == String {
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

private enum HayesModemServiceError: LocalizedError {
    case portReservationUnavailable
    case invalidIncomingPort(Int)
    case listenerUnavailable

    var errorDescription: String? {
        switch self {
        case .portReservationUnavailable:
            return "A local modem port could not be reserved."
        case let .invalidIncomingPort(port):
            return "Port \(port) is not available for incoming calls."
        case .listenerUnavailable:
            return "The local modem socket could not be created."
        }
    }
}

private enum HayesModemResult {
    case ok
    case connect(Int)
    case ring
    case noCarrier
    case error

    var numericCode: String {
        switch self {
        case .ok:
            return "0"
        case .connect:
            return "1"
        case .ring:
            return "2"
        case .noCarrier:
            return "3"
        case .error:
            return "4"
        }
    }

    var text: String {
        switch self {
        case .ok:
            return "OK"
        case let .connect(baudRate):
            return "CONNECT \(baudRate)"
        case .ring:
            return "RING"
        case .noCarrier:
            return "NO CARRIER"
        case .error:
            return "ERROR"
        }
    }
}

private enum HayesDialTarget {
    case testLine
    case tcp(host: String, port: NWEndpoint.Port)
}

final class HayesModemService: @unchecked Sendable {
    private static let defaultDialTimeout: DispatchTimeInterval = .seconds(15)
    private static let ip232Magic: UInt8 = 0xff
    private static let ip232CarrierDetect: UInt8 = 0x01
    private static let ip232RingIndicator: UInt8 = 0x02
    private static let telnetIAC: UInt8 = 255
    private static let telnetWILL: UInt8 = 251
    private static let telnetWONT: UInt8 = 252
    private static let telnetDO: UInt8 = 253
    private static let telnetDONT: UInt8 = 254
    private static let commandDeleteBytes: Set<UInt8> = [8, 20, 127]

    private let queue = DispatchQueue(label: "com.barrywalker.vicemac.hayes-modem")
    private var configuration = NetworkModemConfiguration.standard
    private var statusHandler: ((NetworkModemRuntimeStatus) -> Void)?
    private var localListener: NWListener?
    private var incomingListener: NWListener?
    private var localPort: Int?
    private var serialConnection: NWConnection?
    private var remoteConnection: NWConnection?
    private var pendingIncomingConnection: NWConnection?
    private var activeTestLine = false
    private var remoteDescription: String?
    private var commandBuffer = ""
    private var testLineBuffer = ""
    private var waitingForIP232Byte = false
    private var waitingForTelnetCommand: UInt8?
    private var waitingForTelnetOption = false
    private var carrierDetect = false
    private var ringIndicator = false
    private var online = false
    private var echoMode = true
    private var verboseMode = true
    private var quietMode = false
    private var autoAnswerRings = 0
    private var ringCount = 0
    private var ringTimer: DispatchSourceTimer?
    private var dialTimer: DispatchSourceTimer?
    private let dialTimeout: DispatchTimeInterval

    init(dialTimeout: DispatchTimeInterval = HayesModemService.defaultDialTimeout) {
        self.dialTimeout = dialTimeout
    }

    @discardableResult
    static func applyCommandEditingByte(_ byte: UInt8, to buffer: inout String) -> Bool {
        if commandDeleteBytes.contains(byte) {
            if !buffer.isEmpty {
                buffer.removeLast()
            }
            return true
        }

        guard buffer.count < 512,
              let scalar = UnicodeScalar(Int(byte)) else {
            return false
        }

        buffer.append(Character(scalar))
        return true
    }

    func start(configuration: NetworkModemConfiguration,
               statusHandler: @escaping (NetworkModemRuntimeStatus) -> Void) throws -> Int {
        try queue.sync {
            if let localListener,
               let localPort,
               self.configuration == configuration {
                self.statusHandler = statusHandler
                publishCurrentStatus()
                _ = localListener
                return localPort
            }

            stopOnQueue(publish: false)
            self.configuration = configuration
            self.statusHandler = statusHandler
            echoMode = configuration.echoCommands
            verboseMode = configuration.verboseResultCodes
            quietMode = false
            autoAnswerRings = configuration.autoAnswerRings

            let reservedPort = try Self.reserveLocalPort()
            let listener = try NWListener(using: .tcp, on: reservedPort)
            listener.newConnectionHandler = { [weak self] connection in
                guard let service = self else {
                    return
                }

                service.queue.async {
                    service.acceptSerialConnection(connection)
                }
            }
            listener.stateUpdateHandler = { [weak self] state in
                guard let service = self else {
                    return
                }

                service.queue.async {
                    service.handleLocalListenerState(state)
                }
            }
            listener.start(queue: queue)

            localListener = listener
            localPort = Int(reservedPort.rawValue)

            if configuration.acceptsIncomingCalls {
                incomingListener = try makeIncomingListener(port: configuration.incomingPort)
            }

            publishCurrentStatus(message: "Local modem socket on port \(reservedPort.rawValue)")
            return Int(reservedPort.rawValue)
        }
    }

    func stop() {
        queue.sync {
            stopOnQueue(publish: true)
        }
    }

    private static func reserveLocalPort() throws -> NWEndpoint.Port {
        let descriptor = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard descriptor >= 0 else {
            throw HayesModemServiceError.portReservationUnavailable
        }
        defer {
            close(descriptor)
        }

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        var bindAddress = address
        let bindResult = withUnsafePointer(to: &bindAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                Darwin.bind(descriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            throw HayesModemServiceError.portReservationUnavailable
        }

        var boundAddress = sockaddr_in()
        var boundAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                getsockname(descriptor, socketAddress, &boundAddressLength)
            }
        }
        guard nameResult == 0 else {
            throw HayesModemServiceError.portReservationUnavailable
        }

        let port = UInt16(bigEndian: boundAddress.sin_port)
        guard let endpointPort = NWEndpoint.Port(rawValue: port),
              port != 0 else {
            throw HayesModemServiceError.portReservationUnavailable
        }

        return endpointPort
    }

    private func stopOnQueue(publish: Bool) {
        ringTimer?.cancel()
        dialTimer?.cancel()
        ringTimer = nil
        dialTimer = nil
        localListener?.cancel()
        incomingListener?.cancel()
        serialConnection?.cancel()
        remoteConnection?.cancel()
        pendingIncomingConnection?.cancel()
        localListener = nil
        incomingListener = nil
        localPort = nil
        serialConnection = nil
        remoteConnection = nil
        pendingIncomingConnection = nil
        activeTestLine = false
        remoteDescription = nil
        commandBuffer = ""
        testLineBuffer = ""
        waitingForIP232Byte = false
        waitingForTelnetCommand = nil
        waitingForTelnetOption = false
        carrierDetect = false
        ringIndicator = false
        online = false
        ringCount = 0

        if publish {
            statusHandler?(.disabled)
        }
    }

    private func makeIncomingListener(port: Int) throws -> NWListener {
        guard let rawPort = UInt16(exactly: port),
              let endpointPort = NWEndpoint.Port(rawValue: rawPort) else {
            throw HayesModemServiceError.invalidIncomingPort(port)
        }

        let listener = try NWListener(using: .tcp, on: endpointPort)
        listener.newConnectionHandler = { [weak self] connection in
            guard let service = self else {
                return
            }

            service.queue.async {
                service.acceptIncomingCall(connection)
            }
        }
        listener.stateUpdateHandler = { [weak self] state in
            guard let service = self else {
                return
            }

            service.queue.async {
                service.handleIncomingListenerState(state)
            }
        }
        listener.start(queue: queue)
        return listener
    }

    private func handleLocalListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            publishCurrentStatus()
        case let .failed(error):
            publishError(error.localizedDescription)
        default:
            break
        }
    }

    private func handleIncomingListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            publishCurrentStatus()
        case let .failed(error):
            publishError(error.localizedDescription)
        default:
            break
        }
    }

    private func acceptSerialConnection(_ connection: NWConnection) {
        serialConnection?.cancel()
        serialConnection = connection
        commandBuffer = ""
        waitingForIP232Byte = false

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let service = self,
                  let connection else {
                return
            }

            service.queue.async {
                service.handleSerialState(state, connection: connection)
            }
        }
        connection.start(queue: queue)
        receiveSerial(on: connection)
        sendIP232Status()
        publishCurrentStatus()

        if pendingIncomingConnection != nil {
            beginRinging()
        }
    }

    private func handleSerialState(_ state: NWConnection.State,
                                   connection: NWConnection) {
        guard serialConnection === connection else {
            return
        }

        switch state {
        case .ready:
            publishCurrentStatus()
            sendIP232Status()
        case .cancelled, .failed:
            serialConnection = nil
            publishCurrentStatus()
        default:
            break
        }
    }

    private func acceptIncomingCall(_ connection: NWConnection) {
        guard pendingIncomingConnection == nil,
              remoteConnection == nil else {
            connection.cancel()
            return
        }

        pendingIncomingConnection = connection
        remoteDescription = endpointDescription(connection.endpoint)
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let service = self,
                  let connection else {
                return
            }

            service.queue.async {
                service.handlePendingIncomingState(state, connection: connection)
            }
        }
        connection.start(queue: queue)
        beginRinging()
    }

    private func handlePendingIncomingState(_ state: NWConnection.State,
                                            connection: NWConnection) {
        guard pendingIncomingConnection === connection else {
            return
        }

        switch state {
        case .failed, .cancelled:
            pendingIncomingConnection = nil
            stopRinging()
            publishCurrentStatus()
        default:
            break
        }
    }

    private func receiveSerial(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1,
                           maximumLength: 4096) { [weak self, weak connection] data, _, isComplete, error in
            guard let self,
                  let connection else {
                return
            }

            self.queue.async {
                guard self.serialConnection === connection else {
                    return
                }

                if let data,
                   !data.isEmpty {
                    self.handleSerialBytes(Array(data))
                }

                if isComplete || error != nil {
                    self.serialConnection = nil
                    self.publishCurrentStatus()
                } else {
                    self.receiveSerial(on: connection)
                }
            }
        }
    }

    private func receiveRemote(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1,
                           maximumLength: 4096) { [weak self, weak connection] data, _, isComplete, error in
            guard let self,
                  let connection else {
                return
            }

            self.queue.async {
                guard self.remoteConnection === connection else {
                    return
                }

                if let data,
                   !data.isEmpty {
                    let bytes = self.bytesForSerial(fromRemoteBytes: Array(data))
                    self.sendSerialData(bytes)
                }

                if isComplete || error != nil {
                    self.disconnectRemote(sendNoCarrier: true)
                } else {
                    self.receiveRemote(on: connection)
                }
            }
        }
    }

    private func handleSerialBytes(_ bytes: [UInt8]) {
        for byte in bytes {
            if configuration.interface.usesIP232Control {
                if waitingForIP232Byte {
                    handleIP232Byte(byte)
                    waitingForIP232Byte = false
                    continue
                }

                if byte == Self.ip232Magic {
                    waitingForIP232Byte = true
                    continue
                }
            }

            if online {
                sendRemoteData([byte])
            } else {
                handleCommandByte(byte)
            }
        }
    }

    private func handleIP232Byte(_ byte: UInt8) {
        guard byte != Self.ip232Magic else {
            if online {
                sendRemoteData([Self.ip232Magic])
            } else {
                handleCommandByte(Self.ip232Magic)
            }
            return
        }

        let dataTerminalReady = (byte & 0x01) != 0
        if !dataTerminalReady,
           carrierDetect || online {
            disconnectRemote(sendNoCarrier: true)
        }
    }

    private func handleCommandByte(_ byte: UInt8) {
        switch byte {
        case _ where Self.commandDeleteBytes.contains(byte):
            Self.applyCommandEditingByte(byte, to: &commandBuffer)
            if echoMode {
                sendSerialData([byte])
            }
        case 10:
            break
        case 13:
            if echoMode {
                sendSerialData([13, 10])
            }
            executeCommand(commandBuffer)
            commandBuffer = ""
        default:
            if echoMode {
                sendSerialData([byte])
            }
            Self.applyCommandEditingByte(byte, to: &commandBuffer)
        }
    }

    private func executeCommand(_ command: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCommand.uppercased().hasPrefix("AT") else {
            sendResult(.error)
            return
        }

        var body = String(trimmedCommand.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else {
            sendResult(.ok)
            return
        }

        while let first = body.uppercased().first {
            switch first {
            case "Z":
                resetCommandModeSettings()
                body.removeFirst()
            case "E":
                let value = consumeNumericSuffix(from: &body, afterCommand: "E")
                echoMode = value != 0
            case "Q":
                let value = consumeNumericSuffix(from: &body, afterCommand: "Q")
                quietMode = value != 0
            case "V":
                let value = consumeNumericSuffix(from: &body, afterCommand: "V")
                verboseMode = value != 0
            case "I":
                body.removeFirst()
                sendLine("mac VICE Hayes modem")
            case "H":
                _ = consumeNumericSuffix(from: &body, afterCommand: "H")
                disconnectRemote(sendNoCarrier: false)
            case "O":
                body.removeFirst()
                guard remoteConnection != nil || activeTestLine else {
                    sendResult(.noCarrier)
                    return
                }
                online = true
                sendResult(.connect(configuration.baudRate))
                return
            case "A":
                body.removeFirst()
                answerIncomingCall()
                return
            case "D":
                body.removeFirst()
                dial(String(body))
                return
            case "S":
                handleRegisterCommand(&body)
            default:
                body.removeFirst()
                while let next = body.first,
                      next.isNumber {
                    body.removeFirst()
                }
            }
        }

        sendResult(.ok)
    }

    private func consumeNumericSuffix(from body: inout String,
                                      afterCommand command: Character) -> Int {
        guard body.uppercased().first == command else {
            return 0
        }

        body.removeFirst()
        var digits = ""
        while let next = body.first,
              next.isNumber {
            digits.append(next)
            body.removeFirst()
        }

        return Int(digits) ?? 1
    }

    private func handleRegisterCommand(_ body: inout String) {
        guard body.uppercased().hasPrefix("S") else {
            return
        }

        body.removeFirst()
        var registerDigits = ""
        while let next = body.first,
              next.isNumber {
            registerDigits.append(next)
            body.removeFirst()
        }

        guard registerDigits == "0" else {
            return
        }

        if body.first == "=" {
            body.removeFirst()
            var valueDigits = ""
            while let next = body.first,
                  next.isNumber {
                valueDigits.append(next)
                body.removeFirst()
            }
            autoAnswerRings = min(max(Int(valueDigits) ?? 0, 0), 9)
        }
    }

    private func resetCommandModeSettings() {
        echoMode = configuration.echoCommands
        verboseMode = configuration.verboseResultCodes
        quietMode = false
        autoAnswerRings = configuration.autoAnswerRings
    }

    private func dial(_ rawTarget: String) {
        guard let target = parseDialTarget(rawTarget) else {
            sendResult(.error)
            return
        }

        switch target {
        case .testLine:
            connectTestLine()
        case let .tcp(host, port):
            dialTCP(host: host, port: port)
        }
    }

    private func dialTCP(host: String, port: NWEndpoint.Port) {
        disconnectRemote(sendNoCarrier: false)
        let connection = NWConnection(host: NWEndpoint.Host(host),
                                      port: port,
                                      using: .tcp)
        remoteConnection = connection
        remoteDescription = "\(host):\(port.rawValue)"
        online = false
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let service = self,
                  let connection else {
                return
            }

            service.queue.async {
                service.handleRemoteState(state, connection: connection)
            }
        }
        connection.start(queue: queue)
        scheduleDialTimeout(for: connection,
                            host: host,
                            port: port)
        publishCurrentStatus(message: "Dialing \(host):\(port.rawValue)")
    }

    private func scheduleDialTimeout(for connection: NWConnection,
                                     host: String,
                                     port: NWEndpoint.Port) {
        dialTimer?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + dialTimeout)
        timer.setEventHandler { [weak self, weak connection] in
            guard let self,
                  let connection,
                  self.remoteConnection === connection,
                  !self.online else {
                return
            }

            self.remoteConnection = nil
            self.remoteDescription = nil
            self.dialTimer = nil
            connection.cancel()
            self.setCarrierDetect(false)
            self.sendResult(.noCarrier)
            self.publishCurrentStatus(message: "Dial timed out calling \(host):\(port.rawValue)")
        }
        dialTimer = timer
        timer.resume()
    }

    private func connectTestLine() {
        disconnectRemote(sendNoCarrier: false)
        activeTestLine = true
        remoteDescription = "mac VICE test line"
        online = true
        testLineBuffer = ""
        setCarrierDetect(true)
        sendResult(.connect(configuration.baudRate))
        sendTestLineLines([
            "mac VICE MODEM TEST LINE",
            "TYPE HELP FOR COMMANDS.",
            "TYPE BYE TO HANG UP."
        ])
        publishCurrentStatus()
    }

    private func handleRemoteState(_ state: NWConnection.State,
                                   connection: NWConnection) {
        guard remoteConnection === connection else {
            return
        }

        switch state {
        case .ready:
            dialTimer?.cancel()
            dialTimer = nil
            online = true
            setCarrierDetect(true)
            sendResult(.connect(configuration.baudRate))
            receiveRemote(on: connection)
            publishCurrentStatus()
        case let .failed(error):
            dialTimer?.cancel()
            dialTimer = nil
            remoteConnection = nil
            online = false
            setCarrierDetect(false)
            sendResult(.noCarrier)
            publishCurrentStatus(message: error.localizedDescription)
        case .cancelled:
            dialTimer?.cancel()
            dialTimer = nil
            remoteConnection = nil
            online = false
            setCarrierDetect(false)
            sendResult(.noCarrier)
            publishCurrentStatus()
        default:
            break
        }
    }

    private func answerIncomingCall() {
        guard let connection = pendingIncomingConnection else {
            sendResult(.noCarrier)
            return
        }

        pendingIncomingConnection = nil
        remoteConnection = connection
        stopRinging()
        online = true
        setCarrierDetect(true)
        receiveRemote(on: connection)
        sendResult(.connect(configuration.baudRate))
        publishCurrentStatus()
    }

    private func disconnectRemote(sendNoCarrier: Bool) {
        dialTimer?.cancel()
        dialTimer = nil
        let connection = remoteConnection
        remoteConnection = nil
        pendingIncomingConnection?.cancel()
        pendingIncomingConnection = nil
        connection?.cancel()
        activeTestLine = false
        testLineBuffer = ""
        remoteDescription = nil
        stopRinging()
        online = false
        setCarrierDetect(false)

        if sendNoCarrier {
            sendResult(.noCarrier)
        }

        publishCurrentStatus()
    }

    private func parseDialTarget(_ rawTarget: String) -> HayesDialTarget? {
        var target = rawTarget.trimmingCharacters(in: .whitespacesAndNewlines)
        if isTestLineTarget(target) {
            return .testLine
        }

        if let first = target.first,
           first == "T" || first == "t" || first == "P" || first == "p" {
            target.removeFirst()
            target = target.trimmingCharacters(in: .whitespaces)
        }
        if isTestLineTarget(target) {
            return .testLine
        }

        if target.uppercased().hasPrefix("TELNET://") {
            target.removeFirst("telnet://".count)
        }

        if let terminatorIndex = target.firstIndex(where: { $0 == ";" || $0 == "," || $0 == " " }) {
            target = String(target[..<terminatorIndex])
        }

        target = target.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        guard !target.isEmpty else {
            return nil
        }

        let host: String
        let portNumber: Int
        if let separator = target.lastIndex(of: ":"),
           let parsedPort = Int(target[target.index(after: separator)...]) {
            host = String(target[..<separator])
            portNumber = parsedPort
        } else {
            host = target
            portNumber = configuration.defaultDialPort
        }

        guard !host.isEmpty,
              let rawPort = UInt16(exactly: portNumber),
              let port = NWEndpoint.Port(rawValue: rawPort) else {
            return nil
        }

        return .tcp(host: host, port: port)
    }

    private func isTestLineTarget(_ target: String) -> Bool {
        let normalizedTarget = target
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            .uppercased()

        return normalizedTarget == "TEST"
            || normalizedTarget == "MACVICE"
            || normalizedTarget == "MACVICE.TEST"
    }

    private func beginRinging() {
        guard pendingIncomingConnection != nil else {
            return
        }

        ringCount = 0
        ringTimer?.cancel()
        ringTimer = DispatchSource.makeTimerSource(queue: queue)
        ringTimer?.schedule(deadline: .now(),
                            repeating: .seconds(3),
                            leeway: .milliseconds(250))
        ringTimer?.setEventHandler { [weak self] in
            self?.sendRing()
        }
        ringTimer?.resume()
    }

    private func sendRing() {
        guard pendingIncomingConnection != nil else {
            stopRinging()
            return
        }

        ringCount += 1
        setRingIndicator(true)
        sendResult(.ring)
        queue.asyncAfter(deadline: .now() + .milliseconds(850)) { [weak self] in
            self?.setRingIndicator(false)
        }
        publishCurrentStatus()

        if autoAnswerRings > 0,
           ringCount >= autoAnswerRings {
            answerIncomingCall()
        }
    }

    private func stopRinging() {
        ringTimer?.cancel()
        ringTimer = nil
        ringCount = 0
        setRingIndicator(false)
    }

    private func setCarrierDetect(_ enabled: Bool) {
        guard carrierDetect != enabled else {
            return
        }

        carrierDetect = enabled
        sendIP232Status()
    }

    private func setRingIndicator(_ enabled: Bool) {
        guard ringIndicator != enabled else {
            return
        }

        ringIndicator = enabled
        sendIP232Status()
    }

    private func sendResult(_ result: HayesModemResult) {
        guard !quietMode else {
            return
        }

        sendLine(verboseMode ? result.text : result.numericCode)
    }

    private func sendLine(_ line: String) {
        guard let data = "\r\n\(line)\r\n".data(using: .ascii) else {
            return
        }

        sendSerialData(Array(data))
    }

    private func sendSerialData(_ bytes: [UInt8]) {
        guard configuration.interface.usesIP232Control else {
            sendSerialRaw(bytes)
            return
        }

        var escapedBytes: [UInt8] = []
        escapedBytes.reserveCapacity(bytes.count)

        for byte in bytes {
            escapedBytes.append(byte)
            if byte == Self.ip232Magic {
                escapedBytes.append(Self.ip232Magic)
            }
        }

        sendSerialRaw(escapedBytes)
    }

    private func sendIP232Status() {
        guard configuration.interface.usesIP232Control else {
            return
        }

        var status: UInt8 = 0
        if carrierDetect {
            status |= Self.ip232CarrierDetect
        }
        if ringIndicator {
            status |= Self.ip232RingIndicator
        }

        sendSerialRaw([Self.ip232Magic, status])
    }

    private func sendSerialRaw(_ bytes: [UInt8]) {
        guard let serialConnection,
              !bytes.isEmpty else {
            return
        }

        serialConnection.send(content: Data(bytes), completion: .contentProcessed { _ in })
    }

    private func sendRemoteData(_ bytes: [UInt8]) {
        if activeTestLine {
            handleTestLineBytes(bytes)
            return
        }

        guard let remoteConnection,
              !bytes.isEmpty else {
            return
        }

        let payload: [UInt8]
        if configuration.transportMode == .telnet {
            payload = bytes.flatMap { byte in
                byte == Self.telnetIAC ? [Self.telnetIAC, Self.telnetIAC] : [byte]
            }
        } else {
            payload = bytes
        }

        remoteConnection.send(content: Data(payload), completion: .contentProcessed { _ in })
    }

    private func handleTestLineBytes(_ bytes: [UInt8]) {
        for byte in bytes {
            switch byte {
            case 8, 127:
                if !testLineBuffer.isEmpty {
                    testLineBuffer.removeLast()
                }
                sendSerialData([8, 32, 8])
            case 10:
                break
            case 13:
                sendSerialData([13, 10])
                executeTestLineCommand(testLineBuffer)
                testLineBuffer = ""
            default:
                guard let scalar = UnicodeScalar(Int(byte)),
                      byte >= 32,
                      byte <= 126 else {
                    continue
                }

                if testLineBuffer.count < 512 {
                    testLineBuffer.append(Character(scalar))
                }
                sendSerialData([byte])
            }
        }
    }

    private func executeTestLineCommand(_ command: String) {
        let trimmedCommand = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let uppercasedCommand = trimmedCommand.uppercased()

        switch uppercasedCommand {
        case "":
            sendTestLinePrompt()
        case "HELP", "?":
            sendTestLineLines([
                "COMMANDS:",
                "  HELP  SHOW THIS MENU",
                "  PING  CHECK ROUND TRIP DATA",
                "  TIME  SHOW MAC HOST TIME",
                "  ECHO TEXT  ECHO TEXT BACK",
                "  BYE   HANG UP"
            ])
        case "PING":
            sendTestLineLines(["PONG"])
        case "TIME":
            let timestamp = ISO8601DateFormatter().string(from: Date())
            sendTestLineLines(["MAC TIME \(timestamp)"])
        case "BYE", "QUIT", "LOGOFF", "HANGUP":
            sendLine("DISCONNECTING.")
            disconnectRemote(sendNoCarrier: true)
        default:
            if uppercasedCommand.hasPrefix("ECHO ") {
                let echoText = String(trimmedCommand.dropFirst(5))
                sendTestLineLines([echoText])
            } else {
                sendTestLineLines(["YOU TYPED: \(trimmedCommand)"])
            }
        }
    }

    private func sendTestLinePrompt() {
        sendSerialData(Array(">".utf8))
    }

    private func sendTestLineLines(_ lines: [String]) {
        for line in lines {
            sendLine(line)
        }
        sendTestLinePrompt()
    }

    private func bytesForSerial(fromRemoteBytes bytes: [UInt8]) -> [UInt8] {
        guard configuration.transportMode == .telnet else {
            return bytes
        }

        var output: [UInt8] = []

        for byte in bytes {
            if waitingForTelnetOption {
                if let command = waitingForTelnetCommand {
                    sendTelnetRefusal(command: command, option: byte)
                }
                waitingForTelnetOption = false
                waitingForTelnetCommand = nil
                continue
            }

            if byte == Self.telnetIAC {
                waitingForTelnetCommand = Self.telnetIAC
                continue
            }

            if let command = waitingForTelnetCommand {
                if command == Self.telnetIAC {
                    switch byte {
                    case Self.telnetIAC:
                        output.append(byte)
                        waitingForTelnetCommand = nil
                    case Self.telnetWILL, Self.telnetWONT, Self.telnetDO, Self.telnetDONT:
                        waitingForTelnetCommand = byte
                        waitingForTelnetOption = true
                    default:
                        waitingForTelnetCommand = nil
                    }
                }
                continue
            }

            output.append(byte)
        }

        return output
    }

    private func sendTelnetRefusal(command: UInt8, option: UInt8) {
        let responseCommand: UInt8
        switch command {
        case Self.telnetDO:
            responseCommand = Self.telnetWONT
        case Self.telnetWILL:
            responseCommand = Self.telnetDONT
        default:
            return
        }

        remoteConnection?.send(content: Data([Self.telnetIAC, responseCommand, option]),
                               completion: .contentProcessed { _ in })
    }

    private func publishCurrentStatus(message: String? = nil) {
        let state: NetworkModemRuntimeState
        if (remoteConnection != nil || activeTestLine),
           carrierDetect {
            state = .connected
        } else if pendingIncomingConnection != nil {
            state = .ringing
        } else if serialConnection == nil {
            state = .waitingForMachine
        } else {
            state = .ready
        }

        statusHandler?(NetworkModemRuntimeStatus(state: state,
                                                 localPort: localPort,
                                                 incomingPort: configuration.acceptsIncomingCalls
                                                 ? configuration.incomingPort
                                                 : nil,
                                                 remoteDescription: remoteDescription,
                                                 message: message))
    }

    private func publishError(_ message: String) {
        statusHandler?(NetworkModemRuntimeStatus(state: .error,
                                                 localPort: localPort,
                                                 incomingPort: configuration.acceptsIncomingCalls
                                                 ? configuration.incomingPort
                                                 : nil,
                                                 remoteDescription: nil,
                                                 message: message))
    }

    private func endpointDescription(_ endpoint: NWEndpoint) -> String {
        switch endpoint {
        case let .hostPort(host, port):
            return "\(host):\(port.rawValue)"
        default:
            return "\(endpoint)"
        }
    }
}
