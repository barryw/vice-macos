import CoreGraphics
import Foundation

enum MachineID: String, CaseIterable, Codable, Identifiable {
    case x64sc
    case x128
    case xvic
    case xpet
    case xplus4
    case xc16
    case xc232
    case xv364

    var id: String { rawValue }
}

enum MachineFamily: String, Codable, Equatable {
    case c64
    case c128
    case vic20
    case pet
    case ted
}

enum MachineModel: Equatable {
    case x64sc(C64MachineModel)
    case x128(C128MachineModel)
    case xvic
    case xpet(PETMachineModel)
    case ted(TEDMachineModel)

    var family: MachineFamily {
        switch self {
        case .x64sc:
            return .c64
        case .x128:
            return .c128
        case .xvic:
            return .vic20
        case .xpet:
            return .pet
        case .ted:
            return .ted
        }
    }

    var displayName: String? {
        switch self {
        case let .x64sc(model):
            return model.displayName
        case let .x128(model):
            return model.displayName
        case let .xpet(model):
            return model.displayName
        case let .ted(model):
            return model.displayName
        case .xvic:
            return nil
        }
    }

    var statusChipTitle: String? {
        switch self {
        case let .x64sc(model):
            return model.statusChipTitle
        case let .x128(model):
            return model.statusChipTitle
        case let .xpet(model):
            return model.statusChipTitle
        case .xvic, .ted:
            return nil
        }
    }

    var defaultSIDModel: EmulatorSession.SIDModel? {
        switch self {
        case let .x64sc(model):
            return model.defaultSIDModel
        case let .x128(model):
            return model.defaultSIDModel
        default:
            return nil
        }
    }

    var usesVIC20MemoryStartupOption: Bool {
        self == .xvic
    }

    var supportsRuntimeVideoStandardUpdates: Bool {
        family != .ted
    }

    var supportsRuntimeROMImageUpdates: Bool {
        family != .ted
    }

    var supportsRuntimeModelSelection: Bool {
        switch self {
        case .x64sc, .x128, .xpet:
            return true
        case .xvic, .ted:
            return false
        }
    }

    func viceModelName(for videoStandard: EmulatorSession.VideoStandard) -> String? {
        switch self {
        case let .x64sc(model):
            return model.viceModelName(for: videoStandard)
        case let .x128(model):
            return model.viceModelName(for: videoStandard)
        case let .xpet(model):
            return model.viceModelName
        case .xvic, .ted:
            return nil
        }
    }

    func startupOptions(for configuration: MachineStartupConfiguration,
                        baseOptions: [String]) -> [String] {
        switch self {
        case let .x64sc(model):
            return [
                "-model",
                model.viceModelName(for: configuration.videoStandard)
            ]
        case let .x128(model):
            return [
                "-model",
                model.startupModelName(for: configuration.videoStandard)
            ]
        case let .xpet(model):
            return [
                "-model",
                model.viceModelName
            ]
        case let .ted(model):
            return [
                "-model",
                model.viceModelName(for: configuration.videoStandard),
                "-TEDborders",
                "normal"
            ]
        default:
            return baseOptions
        }
    }

    func defaultROMFileName(for slot: MachineROMSlot,
                            videoStandard: EmulatorSession.VideoStandard) -> String {
        switch self {
        case let .x64sc(model):
            return model.defaultROMFileName(for: slot,
                                            videoStandard: videoStandard)
        case let .xpet(model):
            return model.defaultROMFileName(for: slot)
        case let .ted(model):
            return model.defaultROMFileName(for: slot,
                                            videoStandard: videoStandard)
        default:
            return slot.defaultFileName
        }
    }
}

enum C64MachineModel: String, Codable, Equatable, CaseIterable, Identifiable {
    case c64
    case c64c
    case earlyC64
    case sx64

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .c64:
            return "Commodore 64"
        case .c64c:
            return "Commodore 64C"
        case .earlyC64:
            return "Early Commodore 64"
        case .sx64:
            return "SX-64"
        }
    }

    var statusChipTitle: String {
        switch self {
        case .c64:
            return "C64"
        case .c64c:
            return "C64C"
        case .earlyC64:
            return "Early C64"
        case .sx64:
            return "SX-64"
        }
    }

    var defaultSIDModel: EmulatorSession.SIDModel {
        switch self {
        case .c64c:
            return .mos8580
        case .c64, .earlyC64, .sx64:
            return .mos6581
        }
    }

    func viceModelName(for videoStandard: EmulatorSession.VideoStandard) -> String {
        switch (self, videoStandard) {
        case (.c64, .pal):
            return "c64"
        case (.c64, .ntsc):
            return "c64ntsc"
        case (.c64c, .pal):
            return "c64c"
        case (.c64c, .ntsc):
            return "c64cntsc"
        case (.earlyC64, .pal):
            return "c64old"
        case (.earlyC64, .ntsc):
            return "c64oldntsc"
        case (.sx64, .pal):
            return "sx64pal"
        case (.sx64, .ntsc):
            return "sx64ntsc"
        }
    }

    func defaultROMFileName(for slot: MachineROMSlot,
                            videoStandard: EmulatorSession.VideoStandard) -> String {
        guard slot.id == MachineROMSlot.c64Kernal.id else {
            return slot.defaultFileName
        }

        switch self {
        case .earlyC64:
            return videoStandard == .ntsc ? "kernal-901227-01.bin" : "kernal-901227-02.bin"
        case .sx64:
            return "kernal-251104-04.bin"
        case .c64, .c64c:
            return slot.defaultFileName
        }
    }
}

enum C128MachineModel: String, Codable, Equatable, CaseIterable, Identifiable {
    case c128
    case c128d
    case c128dcr

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .c128:
            return "Commodore 128"
        case .c128d:
            return "Commodore 128D"
        case .c128dcr:
            return "Commodore 128DCR"
        }
    }

    var statusChipTitle: String {
        switch self {
        case .c128:
            return "C128"
        case .c128d:
            return "C128D"
        case .c128dcr:
            return "C128DCR"
        }
    }

    var defaultSIDModel: EmulatorSession.SIDModel {
        switch self {
        case .c128, .c128d:
            return .mos6581
        case .c128dcr:
            return .mos8580
        }
    }

    func viceModelName(for videoStandard: EmulatorSession.VideoStandard) -> String {
        switch (self, videoStandard) {
        case (.c128, .pal):
            return "c128pal"
        case (.c128, .ntsc):
            return "c128ntsc"
        case (.c128d, .pal):
            return "c128dpal"
        case (.c128d, .ntsc):
            return "c128dntsc"
        case (.c128dcr, .pal):
            return "c128dcrpal"
        case (.c128dcr, .ntsc):
            return "c128dcrntsc"
        }
    }

    func startupModelName(for videoStandard: EmulatorSession.VideoStandard) -> String {
        switch (self, videoStandard) {
        case (.c128, .pal):
            return "pal"
        case (.c128, .ntsc):
            return "ntsc"
        case (.c128dcr, .pal):
            return "c128dcr"
        default:
            return viceModelName(for: videoStandard)
        }
    }
}

enum PETMachineModel: String, Codable, Equatable, CaseIterable, Identifiable {
    case model2001 = "2001"
    case model3008 = "3008"
    case model3016 = "3016"
    case model3032 = "3032"
    case model3032B = "3032B"
    case model4016 = "4016"
    case model4032 = "4032"
    case model4032B = "4032B"
    case model8032 = "8032"
    case model8096 = "8096"
    case model8296 = "8296"
    case superPET = "SuperPET"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .model2001:
            return "PET 2001"
        case .model3008:
            return "PET 3008"
        case .model3016:
            return "PET 3016"
        case .model3032:
            return "PET 3032"
        case .model3032B:
            return "PET 3032B"
        case .model4016:
            return "PET 4016"
        case .model4032:
            return "PET 4032"
        case .model4032B:
            return "PET 4032B"
        case .model8032:
            return "PET 8032"
        case .model8096:
            return "PET 8096"
        case .model8296:
            return "PET 8296"
        case .superPET:
            return "SuperPET"
        }
    }

    var statusChipTitle: String {
        displayName
    }

    var viceModelName: String {
        rawValue
    }

    func defaultROMFileName(for slot: MachineROMSlot) -> String {
        switch slot.id {
        case MachineROMSlot.petBasic.id:
            return basicROMName
        case MachineROMSlot.petKernal.id:
            return kernalROMName
        case MachineROMSlot.petEditor.id:
            return editorROMName
        case MachineROMSlot.petCharacter.id:
            return characterROMName
        default:
            return slot.defaultFileName
        }
    }

    private var basicROMName: String {
        switch self {
        case .model2001:
            return "basic-1.901439-09-05-02-06.bin"
        case .model3008, .model3016, .model3032, .model3032B:
            return "basic-2.901465-01-02.bin"
        case .model4016, .model4032, .model4032B, .model8032, .model8096, .model8296, .superPET:
            return "basic-4.901465-23-20-21.bin"
        }
    }

    private var kernalROMName: String {
        switch self {
        case .model2001:
            return "kernal-1.901439-04-07.bin"
        case .model3008, .model3016, .model3032, .model3032B:
            return "kernal-2.901465-03.bin"
        case .model4016, .model4032, .model4032B, .model8032, .model8096, .model8296, .superPET:
            return "kernal-4.901465-22.bin"
        }
    }

    private var editorROMName: String {
        switch self {
        case .model2001:
            return "edit-1-n.901439-03.bin"
        case .model3008, .model3016, .model3032:
            return "edit-2-n.901447-24.bin"
        case .model3032B:
            return "edit-2-b.901474-01.bin"
        case .model4016, .model4032:
            return "edit-4-40-n-50Hz.901498-01.bin"
        case .model4032B:
            return "edit-4-40-b-50Hz.ts.bin"
        case .model8032, .model8096, .model8296, .superPET:
            return "edit-4-80-b-50Hz.901474-04_.bin"
        }
    }

    private var characterROMName: String {
        switch self {
        case .model2001:
            return "characters-1.901447-08.bin"
        case .superPET:
            return "characters.901640-01.bin"
        case .model3008, .model3016, .model3032, .model3032B, .model4016, .model4032,
             .model4032B, .model8032, .model8096, .model8296:
            return "characters-2.901447-10.bin"
        }
    }
}

enum TEDMachineModel: String, Codable, Equatable, CaseIterable {
    case plus4
    case c16
    case c232
    case v364

    var displayName: String {
        switch self {
        case .plus4:
            return "Plus/4"
        case .c16:
            return "C16"
        case .c232:
            return "C232"
        case .v364:
            return "V364"
        }
    }

    var shortName: String {
        switch self {
        case .plus4:
            return "xplus4"
        case .c16:
            return "xc16"
        case .c232:
            return "xc232"
        case .v364:
            return "xv364"
        }
    }

    var bootFrameResourceName: String {
        switch self {
        case .plus4:
            return "xplus4-ready"
        case .c16, .c232, .v364:
            return "xplus4-ready"
        }
    }

    var supportsVideoStandardSelection: Bool {
        switch self {
        case .plus4, .c16:
            return true
        case .c232, .v364:
            return false
        }
    }

    var romSlots: [MachineROMSlot] {
        switch self {
        case .plus4:
            return [.plus4Basic, .plus4Kernal, .plus4FunctionLow, .plus4FunctionHigh]
        case .c16, .c232:
            return [.plus4Basic, .plus4Kernal]
        case .v364:
            return [.plus4Basic, .plus4Kernal, .plus4FunctionLow, .plus4FunctionHigh, .plus4C2Low]
        }
    }

    func viceModelName(for videoStandard: EmulatorSession.VideoStandard) -> String {
        switch (self, videoStandard) {
        case (.plus4, .ntsc):
            return "plus4ntsc"
        case (.plus4, .pal):
            return "plus4pal"
        case (.c16, .ntsc):
            return "c16ntsc"
        case (.c16, .pal):
            return "c16pal"
        case (.c232, _):
            return "c232"
        case (.v364, _):
            return "v364"
        }
    }

    func defaultROMFileName(for slot: MachineROMSlot,
                            videoStandard: EmulatorSession.VideoStandard) -> String {
        guard slot.id == MachineROMSlot.plus4Kernal.id else {
            return slot.defaultFileName
        }

        switch self {
        case .plus4, .c16:
            return videoStandard == .ntsc ? "kernal-318005-05.bin" : slot.defaultFileName
        case .c232:
            return "kernal-318004-01.bin"
        case .v364:
            return "kernal-364.bin"
        }
    }
}

struct MachineBootFrame: Equatable {
    let resourceName: String
    let fileExtension: String
    let pixelSize: CGSize
}

struct MachineDisplayProfile: Equatable {
    let bootFrame: MachineBootFrame
    let nativeScale: CGFloat
    let pixelAspectRatio: CGFloat

    init(bootFrame: MachineBootFrame,
         nativeScale: CGFloat = 2,
         pixelAspectRatio: CGFloat = 1) {
        self.bootFrame = bootFrame
        self.nativeScale = nativeScale
        self.pixelAspectRatio = pixelAspectRatio
    }

    func presentationSize(for pixelSize: CGSize) -> CGSize {
        CGSize(width: pixelSize.width * pixelAspectRatio,
               height: pixelSize.height)
    }

    func nativeDisplaySize(for pixelSize: CGSize? = nil) -> CGSize {
        let sourceSize = pixelSize ?? bootFrame.pixelSize
        let presentedSize = presentationSize(for: sourceSize)
        return CGSize(width: presentedSize.width * nativeScale,
                      height: presentedSize.height * nativeScale)
    }
}

struct MachineROMSlot: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let resourceName: String
    let defaultFileName: String
    let startupOption: String
    let systemImage: String
}

struct MachineDisplayOutput: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let toolbarTitle: String
    let statusTitle: String
    let systemImage: String
    let startupOption: String?
    let resourceName: String?
    let resourceValue: Int32
}

struct MachineCapabilities: Equatable {
    let supportsVideoStandardSelection: Bool
    let supportsSIDModelSelection: Bool
    let supportsCartridges: Bool
    let supportsRAMExpansion: Bool
    var supportsSystemTimeSync = false
    var supportsTape = true
    let controlPorts: [ControlPort]
    let driveUnits: [Int]
    let driveTypes: [DriveType]
    let defaultDriveType: DriveType
}

struct MachineStartupConfiguration {
    let executablePath: String
    let dataDirectory: String
    let machineModel: MachineModel?
    let videoStandard: EmulatorSession.VideoStandard
    let sidModel: EmulatorSession.SIDModel
    let soundEnabled: Bool
    let soundVolume: Int
    let emulationSpeed: EmulatorSession.EmulationSpeed
    let displayOutput: MachineDisplayOutput
    let romImages: ROMImageConfiguration
    let ramExpansion: RAMExpansion
    let mediaBehavior: MediaBehaviorConfiguration
    let sidConfiguration: SIDConfiguration
    let tapeConfiguration: TapeConfiguration
    let printerConfiguration: PrinterConfiguration
    let printerOutputBasePath: String
    let driveConfigurations: [DriveConfiguration]
    let syncSystemTime: Bool
}

struct ViceIntResourceAssignment: Equatable {
    let name: String
    let value: Int32
}

struct EmulatedMachine: Identifiable, Equatable {
    let id: MachineID
    let model: MachineModel
    let displayName: String
    let shortName: String
    let viceTarget: String
    let dynamicLibraryName: String
    let displayProfile: MachineDisplayProfile
    let startupOptions: [String]
    let displayOutputs: [MachineDisplayOutput]
    let romSlots: [MachineROMSlot]
    let ramExpansions: [RAMExpansion]
    let capabilities: MachineCapabilities
    let videoStandardResources: [EmulatorSession.VideoStandard: [ViceIntResourceAssignment]]

    var bootFrame: MachineBootFrame {
        displayProfile.bootFrame
    }

    var family: MachineFamily {
        model.family
    }

    var mainWindowFrameAutosaveName: String {
        "ViceMac.MainWindow.\(id.rawValue)"
    }

    var mainWindowIdentifier: String {
        "ViceMac.MainWindow.\(id.rawValue)"
    }

    var usesVIC20MemoryExpansion: Bool {
        model.usesVIC20MemoryStartupOption
    }

    var supportsRuntimeVideoStandardUpdates: Bool {
        model.supportsRuntimeVideoStandardUpdates
    }

    var supportsRuntimeROMImageUpdates: Bool {
        model.supportsRuntimeROMImageUpdates
    }

    func startupArguments(configuration: MachineStartupConfiguration) -> [String] {
        var arguments = [
            configuration.executablePath,
            "-default",
            "-directory",
            configuration.dataDirectory,
            configuration.emulationSpeed.isWarpEnabled ? "-warp" : "+warp",
            "-speed",
            "\(configuration.emulationSpeed.speedPercent)",
            configuration.soundEnabled ? "-sound" : "+sound",
            "-sounddev",
            "coreaudio",
            "-soundrate",
            "48000",
            "-soundbufsize",
            "20",
            "-soundfragsize",
            "0",
            "-soundoutput",
            "0",
            "-soundwarpmode",
            "1",
            "-soundvolume",
            "\(configuration.soundVolume)"
        ]

        arguments += startupOptions(for: configuration)
        arguments += mediaStartupOptions(for: configuration.mediaBehavior)
        arguments += printerStartupOptions(configuration: configuration.printerConfiguration,
                                           outputBasePath: configuration.printerOutputBasePath)

        if let startupOption = configuration.displayOutput.startupOption {
            arguments.append(startupOption)
        }

        if capabilities.supportsSIDModelSelection {
            arguments += [
                "-sidmodel",
                "\(configuration.sidModel.rawValue)"
            ]
            arguments += sidStartupOptions(for: configuration.sidConfiguration)
        }

        if capabilities.supportsTape {
            arguments += tapeStartupOptions(for: configuration.tapeConfiguration)
        }

        if capabilities.supportsSystemTimeSync && configuration.syncSystemTime {
            arguments += [
                "+userportrtcds1307save",
                "-userportdevice",
                "ds1307"
            ]
        }

        if usesVIC20MemoryExpansion,
           let memorySpec = configuration.ramExpansion.vic20MemorySpec {
            arguments += [
                "-memory",
                memorySpec
            ]
        }

        arguments += driveStartupOptions(for: configuration.driveConfigurations)

        for slot in romSlots {
            arguments += [
                slot.startupOption,
                romResourceValue(for: slot,
                                 romImages: configuration.romImages,
                                 videoStandard: configuration.videoStandard,
                                 machineModel: configuration.machineModel)
            ]
        }

        return arguments
    }

    private func mediaStartupOptions(for configuration: MediaBehaviorConfiguration) -> [String] {
        [
            configuration.useTrueDriveDuringAutostart ? "-autostart-handle-tde" : "+autostart-handle-tde",
            configuration.warpDuringAutostart ? "-autostart-warp" : "+autostart-warp"
        ]
    }

    private func sidStartupOptions(for configuration: SIDConfiguration) -> [String] {
        var options = [
            "-sidextra",
            "\(configuration.layout.extraSIDCount)"
        ]

        if configuration.layout.extraSIDCount >= 1 {
            options += [
                "-sid2address",
                "\(configuration.secondAddress.rawValue)"
            ]
        }

        if configuration.layout.extraSIDCount >= 2 {
            options += [
                "-sid3address",
                "\(configuration.thirdAddress.rawValue)"
            ]
        }

        return options
    }

    private func tapeStartupOptions(for configuration: TapeConfiguration) -> [String] {
        [
            "-tapeport1device",
            configuration.isDatasetteEnabled ? "1" : "0",
            configuration.soundEnabled ? "-datasettesound" : "+datasettesound",
            "-dssoundvolume",
            "\(configuration.viceSoundVolume)"
        ]
    }

    private func printerStartupOptions(configuration: PrinterConfiguration,
                                       outputBasePath: String) -> [String] {
        let device = configuration.deviceNumber
        let textDeviceOption = "-pr\(device)txtdev"
        let driverOption = "-pr\(device)drv"
        let outputOption = "-pr\(device)output"

        return [
            configuration.isEnabled ? "-busdevice\(device)" : "+busdevice\(device)",
            "-devicebackend\(device)",
            configuration.isEnabled ? "1" : "0",
            "-prtxtdev1",
            outputBasePath,
            textDeviceOption,
            "0",
            driverOption,
            configuration.model.viceDriverName,
            outputOption,
            configuration.model.outputMode
        ]
    }

    private func driveStartupOptions(for configurations: [DriveConfiguration]) -> [String] {
        var options: [String] = []
        let activeConfigurations = configurations.filter { configuration in
            capabilities.driveUnits.contains(configuration.unit)
        }
        let driveSoundEnabled = activeConfigurations.contains { $0.isAttached && $0.soundEnabled }

        options.append(driveSoundEnabled ? "-drivesound" : "+drivesound")
        if driveSoundEnabled,
           let volume = activeConfigurations
            .filter({ $0.isAttached && $0.soundEnabled })
            .map(\.viceSoundVolume)
            .max() {
            options += ["-drivesoundvolume", "\(volume)"]
        }

        for configuration in activeConfigurations {
            let driveType = configuration.isAttached ? configuration.driveType.rawValue : 0
            let accessMode = configuration.isAttached ? configuration.accessMode : .native

            options += [
                "-drive\(configuration.unit)type",
                "\(driveType)",
                accessMode == .native ? "-drive\(configuration.unit)truedrive" : "+drive\(configuration.unit)truedrive",
                accessMode == .fast ? "-trapdevice\(configuration.unit)" : "+trapdevice\(configuration.unit)"
            ]

            for driveNumber in configuration.driveType.driveNumbers {
                let suffix = driveNumber == 0 ? "" : "d\(driveNumber)"
                options.append(configuration.protectsInsertedDisks
                               ? "-attach\(configuration.unit)\(suffix)ro"
                               : "-attach\(configuration.unit)\(suffix)rw")
            }
        }

        return options
    }

    func romResourceValue(for slot: MachineROMSlot,
                          romImages: ROMImageConfiguration,
                          videoStandard: EmulatorSession.VideoStandard,
                          machineModel: MachineModel? = nil) -> String {
        romImages.path(for: slot) ?? defaultROMFileName(for: slot,
                                                        videoStandard: videoStandard,
                                                        machineModel: machineModel)
    }

    func videoStandardAssignments(for standard: EmulatorSession.VideoStandard) -> [ViceIntResourceAssignment] {
        videoStandardResources[standard] ?? []
    }

    var defaultDisplayOutput: MachineDisplayOutput {
        displayOutputs.first ?? .standard
    }

    var supportsDisplayOutputSelection: Bool {
        displayOutputs.count > 1
    }

    func displayOutput(id: String?) -> MachineDisplayOutput {
        guard let id,
              let output = displayOutputs.first(where: { $0.id == id }) else {
            return defaultDisplayOutput
        }

        return output
    }

    func defaultDriveConfigurations() -> [DriveConfiguration] {
        capabilities.driveUnits.enumerated().map { index, unit in
            DriveConfiguration(unit: unit,
                               isAttached: index == 0,
                               driveType: capabilities.defaultDriveType,
                               soundEnabled: false,
                               soundVolume: 25)
        }
    }

    private func startupOptions(for configuration: MachineStartupConfiguration) -> [String] {
        activeModel(for: configuration).startupOptions(for: configuration,
                                                       baseOptions: startupOptions)
    }

    private func defaultROMFileName(for slot: MachineROMSlot,
                                    videoStandard: EmulatorSession.VideoStandard,
                                    machineModel: MachineModel? = nil) -> String {
        (validMachineModel(machineModel) ?? model).defaultROMFileName(for: slot,
                                                                      videoStandard: videoStandard)
    }

    private func activeModel(for configuration: MachineStartupConfiguration) -> MachineModel {
        validMachineModel(configuration.machineModel) ?? model
    }

    private func validMachineModel(_ override: MachineModel?) -> MachineModel? {
        guard let override,
              override.family == family else {
            return nil
        }

        return override
    }
}

extension MachineROMSlot {
    static let c64Basic = MachineROMSlot(id: "c64.basic",
                                         title: "BASIC",
                                         resourceName: "BasicName",
                                         defaultFileName: "basic-901226-01.bin",
                                         startupOption: "-basic",
                                         systemImage: "terminal")
    static let c64Kernal = MachineROMSlot(id: "c64.kernal",
                                          title: "KERNAL",
                                          resourceName: "KernalName",
                                          defaultFileName: "kernal-901227-03.bin",
                                          startupOption: "-kernal",
                                          systemImage: "cpu")
    static let c64Character = MachineROMSlot(id: "c64.character",
                                             title: "Character",
                                             resourceName: "ChargenName",
                                             defaultFileName: "chargen-901225-01.bin",
                                             startupOption: "-chargen",
                                             systemImage: "textformat")

    static let vic20Basic = MachineROMSlot(id: "vic20.basic",
                                           title: "BASIC",
                                           resourceName: "BasicName",
                                           defaultFileName: "basic-901486-01.bin",
                                           startupOption: "-basic",
                                           systemImage: "terminal")
    static let vic20Kernal = MachineROMSlot(id: "vic20.kernal",
                                            title: "KERNAL",
                                            resourceName: "KernalName",
                                            defaultFileName: "kernal.901486-07.bin",
                                            startupOption: "-kernal",
                                            systemImage: "cpu")
    static let vic20Character = MachineROMSlot(id: "vic20.character",
                                               title: "Character",
                                               resourceName: "ChargenName",
                                               defaultFileName: "chargen-901460-03.bin",
                                               startupOption: "-chargen",
                                               systemImage: "textformat")

    static let petBasic = MachineROMSlot(id: "pet.basic",
                                         title: "BASIC",
                                         resourceName: "BasicName",
                                         defaultFileName: "basic-4.901465-23-20-21.bin",
                                         startupOption: "-basic",
                                         systemImage: "terminal")
    static let petKernal = MachineROMSlot(id: "pet.kernal",
                                          title: "KERNAL",
                                          resourceName: "KernalName",
                                          defaultFileName: "kernal-4.901465-22.bin",
                                          startupOption: "-kernal",
                                          systemImage: "cpu")
    static let petEditor = MachineROMSlot(id: "pet.editor",
                                          title: "Editor",
                                          resourceName: "EditorName",
                                          defaultFileName: "edit-4-40-n-50Hz.901498-01.bin",
                                          startupOption: "-editor",
                                          systemImage: "rectangle.and.pencil.and.ellipsis")
    static let petCharacter = MachineROMSlot(id: "pet.character",
                                             title: "Character",
                                             resourceName: "ChargenName",
                                             defaultFileName: "characters-2.901447-10.bin",
                                             startupOption: "-chargen",
                                             systemImage: "textformat")

    static let plus4Basic = MachineROMSlot(id: "plus4.basic",
                                           title: "BASIC",
                                           resourceName: "BasicName",
                                           defaultFileName: "basic-318006-01.bin",
                                           startupOption: "-basic",
                                           systemImage: "terminal")
    static let plus4Kernal = MachineROMSlot(id: "plus4.kernal",
                                            title: "KERNAL",
                                            resourceName: "KernalName",
                                            defaultFileName: "kernal-318004-05.bin",
                                            startupOption: "-kernal",
                                            systemImage: "cpu")
    static let plus4FunctionLow = MachineROMSlot(id: "plus4.functionLow",
                                                 title: "Function Low",
                                                 resourceName: "FunctionLowName",
                                                 defaultFileName: "3plus1-317053-01.bin",
                                                 startupOption: "-functionlo",
                                                 systemImage: "rectangle.on.rectangle")
    static let plus4FunctionHigh = MachineROMSlot(id: "plus4.functionHigh",
                                                  title: "Function High",
                                                  resourceName: "FunctionHighName",
                                                  defaultFileName: "3plus1-317054-01.bin",
                                                  startupOption: "-functionhi",
                                                  systemImage: "rectangle.stack")
    static let plus4C2Low = MachineROMSlot(id: "plus4.c2Low",
                                           title: "C2 Low",
                                           resourceName: "c2loName",
                                           defaultFileName: "c2lo-364.bin",
                                           startupOption: "-c2lo",
                                           systemImage: "waveform")

    static let c128BasicLow = MachineROMSlot(id: "c128.basicLow",
                                             title: "BASIC Low",
                                             resourceName: "BasicLoName",
                                             defaultFileName: "basiclo-318018-04.bin",
                                             startupOption: "-basiclo",
                                             systemImage: "terminal")
    static let c128BasicHigh = MachineROMSlot(id: "c128.basicHigh",
                                              title: "BASIC High",
                                              resourceName: "BasicHiName",
                                              defaultFileName: "basichi-318019-04.bin",
                                              startupOption: "-basichi",
                                              systemImage: "terminal")
    static let c128Kernal = MachineROMSlot(id: "c128.kernal",
                                           title: "KERNAL",
                                           resourceName: "KernalIntName",
                                           defaultFileName: "kernal-318020-05.bin",
                                           startupOption: "-kernal",
                                           systemImage: "cpu")
    static let c128Character = MachineROMSlot(id: "c128.character",
                                              title: "Character",
                                              resourceName: "ChargenIntName",
                                              defaultFileName: "chargen-390059-01.bin",
                                              startupOption: "-chargen",
                                              systemImage: "textformat")
    static let c128C64Basic = MachineROMSlot(id: "c128.c64Basic",
                                             title: "C64 BASIC",
                                             resourceName: "Basic64Name",
                                             defaultFileName: "basic64-901226-01.bin",
                                             startupOption: "-basic64",
                                             systemImage: "terminal")
    static let c128C64Kernal = MachineROMSlot(id: "c128.c64Kernal",
                                              title: "C64 KERNAL",
                                              resourceName: "Kernal64Name",
                                              defaultFileName: "kernal64-901227-03.bin",
                                              startupOption: "-kernal64",
                                              systemImage: "cpu")
}

extension MachineDisplayOutput {
    static let standard = MachineDisplayOutput(id: "standard",
                                               toolbarTitle: "Display",
                                               statusTitle: "Display",
                                               systemImage: "display",
                                               startupOption: nil,
                                               resourceName: nil,
                                               resourceValue: 0)
    static let c12840Column = MachineDisplayOutput(id: "c128.40Column",
                                                   toolbarTitle: "40",
                                                   statusTitle: "40 VIC-II",
                                                   systemImage: "display",
                                                   startupOption: "-40col",
                                                   resourceName: "C128ColumnKey",
                                                   resourceValue: 1)
    static let c12880Column = MachineDisplayOutput(id: "c128.80Column",
                                                   toolbarTitle: "80",
                                                   statusTitle: "80 VDC",
                                                   systemImage: "display.2",
                                                   startupOption: "-80col",
                                                   resourceName: "C128ColumnKey",
                                                   resourceValue: 0)
}

extension EmulatedMachine {
    static var x64sc: EmulatedMachine {
        EmulatedMachine(
            id: .x64sc,
            model: .x64sc(.c64),
            displayName: "Commodore 64",
            shortName: "x64sc",
            viceTarget: "x64sc",
            dynamicLibraryName: "libvicemacx64sc.dylib",
            displayProfile: MachineDisplayProfile(
                bootFrame: MachineBootFrame(resourceName: "x64sc-ready",
                                            fileExtension: "png",
                                            pixelSize: CGSize(width: 384, height: 272))
            ),
            startupOptions: [],
            displayOutputs: [.standard],
            romSlots: [.c64Basic, .c64Kernal, .c64Character],
            ramExpansions: RAMExpansion.c64Options,
            capabilities: MachineCapabilities(supportsVideoStandardSelection: true,
                                              supportsSIDModelSelection: true,
                                              supportsCartridges: true,
                                              supportsRAMExpansion: true,
                                              supportsSystemTimeSync: true,
                                              controlPorts: [.one, .two],
                                              driveUnits: [8, 9, 10, 11],
                                              driveTypes: DriveType.iecOptions,
                                              defaultDriveType: .c1541),
            videoStandardResources: [
                .ntsc: [
                    ViceIntResourceAssignment(name: "VICIIModel", value: ViceVICIIModel.mos8562),
                    ViceIntResourceAssignment(name: "MachinePowerFrequency", value: 60)
                ],
                .pal: [
                    ViceIntResourceAssignment(name: "VICIIModel", value: ViceVICIIModel.mos8565),
                    ViceIntResourceAssignment(name: "MachinePowerFrequency", value: 50)
                ]
            ]
        )
    }

    static var x128: EmulatedMachine {
        EmulatedMachine(
            id: .x128,
            model: .x128(.c128),
            displayName: "Commodore 128",
            shortName: "x128",
            viceTarget: "x128",
            dynamicLibraryName: "libvicemacx128.dylib",
            displayProfile: MachineDisplayProfile(
                bootFrame: MachineBootFrame(resourceName: "x64sc-ready",
                                            fileExtension: "png",
                                            pixelSize: CGSize(width: 384, height: 272))
            ),
            startupOptions: [],
            displayOutputs: [.c12840Column, .c12880Column],
            romSlots: [.c128BasicLow, .c128BasicHigh, .c128Kernal, .c128Character, .c128C64Basic, .c128C64Kernal],
            ramExpansions: RAMExpansion.c128Options,
            capabilities: MachineCapabilities(supportsVideoStandardSelection: true,
                                              supportsSIDModelSelection: true,
                                              supportsCartridges: true,
                                              supportsRAMExpansion: true,
                                              supportsSystemTimeSync: true,
                                              controlPorts: [.one, .two],
                                              driveUnits: [8, 9, 10, 11],
                                              driveTypes: DriveType.c128Options,
                                              defaultDriveType: .c1571),
            videoStandardResources: [
                .ntsc: [
                    ViceIntResourceAssignment(name: "MachineVideoStandard",
                                              value: ViceMachineVideoStandard.ntsc),
                    ViceIntResourceAssignment(name: "MachinePowerFrequency",
                                              value: 60)
                ],
                .pal: [
                    ViceIntResourceAssignment(name: "MachineVideoStandard",
                                              value: ViceMachineVideoStandard.pal),
                    ViceIntResourceAssignment(name: "MachinePowerFrequency",
                                              value: 50)
                ]
            ]
        )
    }

    static var xvic: EmulatedMachine {
        EmulatedMachine(
            id: .xvic,
            model: .xvic,
            displayName: "VIC-20",
            shortName: "xvic",
            viceTarget: "xvic",
            dynamicLibraryName: "libvicemacxvic.dylib",
            displayProfile: MachineDisplayProfile(
                bootFrame: MachineBootFrame(resourceName: "xvic-ready",
                                            fileExtension: "png",
                                            pixelSize: CGSize(width: 400, height: 234))
            ),
            startupOptions: ["-VICborders", "normal"],
            displayOutputs: [.standard],
            romSlots: [.vic20Basic, .vic20Kernal, .vic20Character],
            ramExpansions: RAMExpansion.vic20Options,
            capabilities: MachineCapabilities(supportsVideoStandardSelection: true,
                                              supportsSIDModelSelection: false,
                                              supportsCartridges: true,
                                              supportsRAMExpansion: true,
                                              supportsSystemTimeSync: true,
                                              controlPorts: [.one],
                                              driveUnits: [8, 9, 10, 11],
                                              driveTypes: DriveType.iecOptions,
                                              defaultDriveType: .c1541),
            videoStandardResources: [
                .ntsc: [
                    ViceIntResourceAssignment(name: "MachineVideoStandard",
                                              value: ViceMachineVideoStandard.ntsc)
                ],
                .pal: [
                    ViceIntResourceAssignment(name: "MachineVideoStandard",
                                              value: ViceMachineVideoStandard.pal)
                ]
            ]
        )
    }

    static var xpet: EmulatedMachine {
        pet(.model4032, id: .xpet)
    }

    static var xplus4: EmulatedMachine {
        ted(.plus4, id: .xplus4)
    }

    static var xc16: EmulatedMachine {
        ted(.c16, id: .xc16)
    }

    static var xc232: EmulatedMachine {
        ted(.c232, id: .xc232)
    }

    static var xv364: EmulatedMachine {
        ted(.v364, id: .xv364)
    }

    private static func pet(_ model: PETMachineModel,
                            id: MachineID) -> EmulatedMachine {
        EmulatedMachine(
            id: id,
            model: .xpet(model),
            displayName: model.displayName,
            shortName: "xpet",
            viceTarget: "xpet",
            dynamicLibraryName: "libvicemacxpet.dylib",
            displayProfile: MachineDisplayProfile(
                bootFrame: MachineBootFrame(resourceName: "xpet-ready",
                                            fileExtension: "png",
                                            pixelSize: CGSize(width: 384, height: 272))
            ),
            startupOptions: [],
            displayOutputs: [.standard],
            romSlots: [.petBasic, .petKernal, .petEditor, .petCharacter],
            ramExpansions: [.none],
            capabilities: MachineCapabilities(supportsVideoStandardSelection: true,
                                              supportsSIDModelSelection: false,
                                              supportsCartridges: false,
                                              supportsRAMExpansion: false,
                                              supportsSystemTimeSync: true,
                                              controlPorts: [],
                                              driveUnits: [8, 9, 10, 11],
                                              driveTypes: DriveType.petOptions,
                                              defaultDriveType: .c4040),
            videoStandardResources: [
                .ntsc: [
                    ViceIntResourceAssignment(name: "MachineVideoStandard",
                                              value: ViceMachineVideoStandard.ntsc)
                ],
                .pal: [
                    ViceIntResourceAssignment(name: "MachineVideoStandard",
                                              value: ViceMachineVideoStandard.pal)
                ]
            ]
        )
    }

    private static func ted(_ model: TEDMachineModel,
                            id: MachineID) -> EmulatedMachine {
        EmulatedMachine(
            id: id,
            model: .ted(model),
            displayName: model.displayName,
            shortName: model.shortName,
            viceTarget: "xplus4",
            dynamicLibraryName: "libvicemacxplus4.dylib",
            displayProfile: MachineDisplayProfile(
                bootFrame: MachineBootFrame(resourceName: model.bootFrameResourceName,
                                            fileExtension: "png",
                                            pixelSize: CGSize(width: 384, height: 288))
            ),
            startupOptions: [],
            displayOutputs: [.standard],
            romSlots: model.romSlots,
            ramExpansions: [.none],
            capabilities: MachineCapabilities(supportsVideoStandardSelection: model.supportsVideoStandardSelection,
                                              supportsSIDModelSelection: false,
                                              supportsCartridges: false,
                                              supportsRAMExpansion: false,
                                              controlPorts: [.one, .two],
                                              driveUnits: [8, 9, 10, 11],
                                              driveTypes: DriveType.plus4Options,
                                              defaultDriveType: .c1551),
            videoStandardResources: [
                .ntsc: [
                    ViceIntResourceAssignment(name: "MachineVideoStandard",
                                              value: ViceMachineVideoStandard.ntsc)
                ],
                .pal: [
                    ViceIntResourceAssignment(name: "MachineVideoStandard",
                                              value: ViceMachineVideoStandard.pal)
                ]
            ]
        )
    }

    static var current: EmulatedMachine {
        #if VICE_MAC_MACHINE_X128
        return .x128
        #elseif VICE_MAC_MACHINE_XV364
        return .xv364
        #elseif VICE_MAC_MACHINE_XC232
        return .xc232
        #elseif VICE_MAC_MACHINE_XC16
        return .xc16
        #elseif VICE_MAC_MACHINE_XPLUS4
        return .xplus4
        #elseif VICE_MAC_MACHINE_XPET
        return .xpet
        #elseif VICE_MAC_MACHINE_XVIC
        return .xvic
        #else
        return .x64sc
        #endif
    }

    static var planned: [EmulatedMachine] {
        #if VICE_MAC_MACHINE_X128
        return [.x64sc, .xvic, .xpet, .xplus4, .xc16, .xc232, .xv364, .x128]
        #elseif VICE_MAC_MACHINE_XV364
        return [.x64sc, .xvic, .xpet, .xplus4, .xc16, .xc232, .xv364]
        #elseif VICE_MAC_MACHINE_XC232
        return [.x64sc, .xvic, .xpet, .xplus4, .xc16, .xc232]
        #elseif VICE_MAC_MACHINE_XC16
        return [.x64sc, .xvic, .xpet, .xplus4, .xc16]
        #elseif VICE_MAC_MACHINE_XPLUS4
        return [.x64sc, .xvic, .xpet, .xplus4]
        #elseif VICE_MAC_MACHINE_XPET
        return [.x64sc, .xvic, .xpet]
        #elseif VICE_MAC_MACHINE_XVIC
        return [.x64sc, .xvic]
        #else
        return [.x64sc]
        #endif
    }
}

private enum ViceVICIIModel {
    static let mos8565: Int32 = 1
    static let mos8562: Int32 = 4
}

private enum ViceMachineVideoStandard {
    static let pal: Int32 = 1
    static let ntsc: Int32 = 2
}
