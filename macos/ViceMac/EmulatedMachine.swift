import CoreGraphics
import Foundation

enum MachineID: String, CaseIterable, Codable, Identifiable {
    case x64sc
    case x128
    case xvic
    case xpet
    case xplus4

    var id: String { rawValue }
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
    let controlPorts: [ControlPort]
    let driveUnits: [Int]
    let driveTypes: [DriveType]
    let defaultDriveType: DriveType
}

struct MachineStartupConfiguration {
    let executablePath: String
    let dataDirectory: String
    let videoStandard: EmulatorSession.VideoStandard
    let sidModel: EmulatorSession.SIDModel
    let soundEnabled: Bool
    let soundVolume: Int
    let emulationSpeed: EmulatorSession.EmulationSpeed
    let displayOutput: MachineDisplayOutput
    let romImages: ROMImageConfiguration
    let ramExpansion: RAMExpansion
    let driveConfigurations: [DriveConfiguration]
}

struct ViceIntResourceAssignment: Equatable {
    let name: String
    let value: Int32
}

struct EmulatedMachine: Identifiable, Equatable {
    let id: MachineID
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

        if let startupOption = configuration.displayOutput.startupOption {
            arguments.append(startupOption)
        }

        if capabilities.supportsSIDModelSelection {
            arguments += [
                "-sidmodel",
                "\(configuration.sidModel.rawValue)"
            ]
        }

        if id == .xvic,
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
                                 videoStandard: configuration.videoStandard)
            ]
        }

        return arguments
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
        }

        return options
    }

    func romResourceValue(for slot: MachineROMSlot,
                          romImages: ROMImageConfiguration,
                          videoStandard: EmulatorSession.VideoStandard) -> String {
        romImages.path(for: slot) ?? defaultROMFileName(for: slot,
                                                        videoStandard: videoStandard)
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
        switch id {
        case .xplus4:
            return [
                "-model",
                configuration.videoStandard == .ntsc ? "plus4ntsc" : "plus4pal",
                "-TEDborders",
                "normal"
            ]
        case .x128:
            return [
                "-model",
                configuration.videoStandard == .ntsc ? "ntsc" : "pal"
            ]
        default:
            return startupOptions
        }
    }

    private func defaultROMFileName(for slot: MachineROMSlot,
                                    videoStandard: EmulatorSession.VideoStandard) -> String {
        if id == .xplus4 && slot.id == MachineROMSlot.plus4Kernal.id {
            return videoStandard == .ntsc ? "kernal-318005-05.bin" : slot.defaultFileName
        }

        return slot.defaultFileName
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
        EmulatedMachine(
            id: .xpet,
            displayName: "PET 4032",
            shortName: "xpet",
            viceTarget: "xpet",
            dynamicLibraryName: "libvicemacxpet.dylib",
            displayProfile: MachineDisplayProfile(
                bootFrame: MachineBootFrame(resourceName: "xpet-ready",
                                            fileExtension: "png",
                                            pixelSize: CGSize(width: 384, height: 272))
            ),
            startupOptions: ["-model", "4032"],
            displayOutputs: [.standard],
            romSlots: [.petBasic, .petKernal, .petEditor, .petCharacter],
            ramExpansions: [.none],
            capabilities: MachineCapabilities(supportsVideoStandardSelection: true,
                                              supportsSIDModelSelection: false,
                                              supportsCartridges: false,
                                              supportsRAMExpansion: false,
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

    static var xplus4: EmulatedMachine {
        EmulatedMachine(
            id: .xplus4,
            displayName: "Plus/4",
            shortName: "xplus4",
            viceTarget: "xplus4",
            dynamicLibraryName: "libvicemacxplus4.dylib",
            displayProfile: MachineDisplayProfile(
                bootFrame: MachineBootFrame(resourceName: "xplus4-ready",
                                            fileExtension: "png",
                                            pixelSize: CGSize(width: 384, height: 288))
            ),
            startupOptions: [],
            displayOutputs: [.standard],
            romSlots: [.plus4Basic, .plus4Kernal, .plus4FunctionLow, .plus4FunctionHigh],
            ramExpansions: [.none],
            capabilities: MachineCapabilities(supportsVideoStandardSelection: true,
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
        return [.x64sc, .xvic, .xpet, .xplus4, .x128]
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
