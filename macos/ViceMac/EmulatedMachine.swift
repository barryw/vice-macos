import CoreGraphics
import Foundation

enum MachineID: String, CaseIterable, Codable, Identifiable {
    case x64sc
    case xvic
    case xpet

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

protocol MachineDisplayContract {
    var displayProfile: MachineDisplayProfile { get }
}

struct MachineROMSlot: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let resourceName: String
    let defaultFileName: String
    let startupOption: String
    let systemImage: String
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
    let romImages: ROMImageConfiguration
    let ramExpansion: RAMExpansion
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

        arguments += startupOptions

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

        for slot in romSlots {
            arguments += [
                slot.startupOption,
                configuration.romImages.resourceValue(for: slot)
            ]
        }

        return arguments
    }

    func videoStandardAssignments(for standard: EmulatorSession.VideoStandard) -> [ViceIntResourceAssignment] {
        videoStandardResources[standard] ?? []
    }

    func defaultDriveConfigurations() -> [DriveConfiguration] {
        capabilities.driveUnits.enumerated().map { index, unit in
            DriveConfiguration(unit: unit,
                               isAttached: index == 0,
                               driveType: capabilities.defaultDriveType,
                               soundEnabled: false,
                               soundVolume: 1000)
        }
    }
}

extension EmulatedMachine: MachineDisplayContract {}

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

    static var current: EmulatedMachine {
        #if VICE_MAC_MACHINE_XPET
        return .xpet
        #elseif VICE_MAC_MACHINE_XVIC
        return .xvic
        #else
        return .x64sc
        #endif
    }

    static var planned: [EmulatedMachine] {
        #if VICE_MAC_MACHINE_XVIC
        return [.x64sc, .xvic]
        #elseif VICE_MAC_MACHINE_XPET
        return [.x64sc, .xvic, .xpet]
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
