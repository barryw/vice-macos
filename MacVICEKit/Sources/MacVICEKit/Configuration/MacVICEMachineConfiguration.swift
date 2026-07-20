import CoreGraphics
import Foundation

/// A VICE machine target supported by MacVICEKit.
public enum MacVICEMachine: String, CaseIterable, Sendable {
    /// Cycle-accurate Commodore 64.
    case c64sc = "x64sc"
    /// Commodore 128.
    case c128 = "x128"
    /// Commodore VIC-20.
    case vic20 = "xvic"
    /// Commodore PET family.
    case pet = "xpet"
    /// Commodore Plus/4.
    case plus4 = "xplus4"
    /// Commodore 16, launched through the Plus/4 VICE target.
    case c16 = "xc16"
    /// Commodore 232 prototype, launched through the Plus/4 VICE target.
    case c232 = "xc232"
    /// Commodore V364 prototype, launched through the Plus/4 VICE target.
    case v364 = "xv364"
    /// VICE SID player.
    case vsid = "vsid"

    /// The native VICE target that owns the runtime entry point for this machine.
    public var viceTarget: String {
        switch self {
        case .c16, .c232, .v364:
            return MacVICEMachine.plus4.rawValue
        default:
            return rawValue
        }
    }

    /// The executable-style name VICE expects as `argv[0]`.
    public var executableName: String { rawValue }

    /// The packaged runtime dylib name for this machine.
    public var dynamicLibraryName: String {
        "libvicemac\(viceTarget).dylib"
    }

    /// The default VICE model argument needed for machines that share a runtime target.
    public var defaultModel: String? {
        defaultModel(for: nil)
    }

    /// Returns the default VICE model argument for the requested video standard.
    public func defaultModel(for videoStandard: MacVICEVideoStandard?) -> String? {
        switch self {
        case .c64sc:
            guard let videoStandard else {
                return nil
            }
            return videoStandard == .ntsc ? "c64ntsc" : "c64"
        case .c128:
            guard let videoStandard else {
                return nil
            }
            return videoStandard == .ntsc ? "ntsc" : "pal"
        case .plus4:
            guard let videoStandard else {
                return nil
            }
            return videoStandard == .ntsc ? "plus4ntsc" : "plus4pal"
        case .c16:
            return videoStandard == .ntsc ? "c16ntsc" : "c16pal"
        case .c232:
            return "c232"
        case .v364:
            return "v364"
        default:
            return nil
        }
    }

    /// Unique native VICE targets that must be built for the full MacVICEKit runtime.
    public static let runtimeBuildTargets: [String] = {
        var targets: [String] = []
        for machine in MacVICEMachine.allCases {
            guard !targets.contains(machine.viceTarget) else {
                continue
            }
            targets.append(machine.viceTarget)
        }
        return targets
    }()

    /// Default display sizing metadata for the machine's primary video output.
    public var displayProfile: MacVICEDisplayProfile {
        switch self {
        case .c64sc, .c128:
            return MacVICEDisplayProfile(bootFrame: MacVICEBootFrame(pixelSize: CGSize(width: 384, height: 272)),
                                         nativeScale: 2,
                                         pixelAspectRatio: 1)
        case .vic20:
            return MacVICEDisplayProfile(bootFrame: MacVICEBootFrame(pixelSize: CGSize(width: 400, height: 234)),
                                         nativeScale: 2,
                                         pixelAspectRatio: 1)
        case .pet:
            return MacVICEDisplayProfile(bootFrame: MacVICEBootFrame(pixelSize: CGSize(width: 640, height: 400)),
                                         nativeScale: 1,
                                         pixelAspectRatio: 1)
        case .plus4, .c16, .c232, .v364:
            return MacVICEDisplayProfile(bootFrame: MacVICEBootFrame(pixelSize: CGSize(width: 384, height: 288)),
                                         nativeScale: 2,
                                         pixelAspectRatio: 1)
        case .vsid:
            return MacVICEDisplayProfile(bootFrame: MacVICEBootFrame(pixelSize: CGSize(width: 384, height: 272)),
                                         nativeScale: 2,
                                         pixelAspectRatio: 1)
        }
    }
}

/// The video standard requested at startup.
public enum MacVICEVideoStandard: String, Sendable {
    /// PAL timing and video resources.
    case pal
    /// NTSC timing and video resources.
    case ntsc

    var machineVideoStandardResourceValue: Int32 {
        switch self {
        case .pal:
            return 1
        case .ntsc:
            return 2
        }
    }
}

extension MacVICEMachine {
    func runtimeModel(for videoStandard: MacVICEVideoStandard,
                      preferredModel: String?) -> String? {
        switch self {
        case .c64sc, .c128, .plus4, .c16:
            return preferredModel ?? defaultModel(for: videoStandard)
        case .vic20, .pet, .c232, .v364, .vsid:
            return nil
        }
    }
}

/// A custom ROM override passed through to VICE as a command-line option and file URL.
public struct MacVICEROMOverride: Sendable, Equatable {
    /// The VICE option name, such as `-kernal`, `-basic`, or `-chargen`.
    public let viceOption: String
    /// The ROM file URL to pass after `viceOption`.
    public let url: URL

    /// Creates a custom ROM override.
    public init(viceOption: String, url: URL) {
        self.viceOption = viceOption
        self.url = url
    }
}

/// ROM selection for machine startup.
public enum MacVICEROMSet: Sendable, Equatable {
    /// Use the ROMs bundled with the resolved VICE runtime.
    case bundled
    /// Override one or more VICE ROM command-line options.
    case custom([MacVICEROMOverride])

    var startupArguments: [String] {
        switch self {
        case .bundled:
            return []
        case .custom(let overrides):
            return overrides.flatMap { [$0.viceOption, $0.url.path] }
        }
    }
}

/// How VICE should handle media passed to autostart or attach operations.
public enum MacVICEMediaRunMode: Int32, Sendable {
    /// Attach the media without loading or running a program.
    case attach = -1
    /// Load and run the selected program.
    case run = 0
    /// Load the selected program but leave execution to the guest.
    case load = 1
}

/// Storage configuration for an IEC drive slot.
public enum MacVICEStorageKind: Sendable, Equatable {
    /// Leave the device detached.
    case detached
    /// Attach a disk image as a normal VICE drive.
    case diskImage(URL, readOnly: Bool = false)
    /// Attach a VICE hard-drive image.
    case hardDriveImage(URL, readOnly: Bool = false)
    /// Expose a local Mac folder through VICE's filesystem-device backend.
    case sharedFolder(URL)
}

/// Drive configuration used to build startup arguments for one emulated device.
public struct MacVICEDriveConfiguration: Sendable, Equatable {
    /// IEC device number, usually 8 through 11.
    public let unit: Int
    /// Drive number within a dual-drive device. Single-drive devices use 0.
    public let driveNumber: Int
    /// The media or backend attached to this device.
    public let kind: MacVICEStorageKind

    /// Creates a drive configuration for a VICE IEC device.
    public init(unit: Int = 8,
                driveNumber: Int = 0,
                kind: MacVICEStorageKind) {
        self.unit = unit
        self.driveNumber = driveNumber
        self.kind = kind
    }

    var startupArguments: [String] {
        switch kind {
        case .detached:
            return [
                "-devicebackend\(unit)", "0",
                "-drive\(unit)type", "0"
            ]
        case .diskImage(let url, let readOnly):
            return [
                "-devicebackend\(unit)", "0",
                "-drive\(unit)type", Self.driveType(forDiskImageAt: url),
                readOnly ? "-attach\(unit)ro" : "-attach\(unit)rw",
                url.path
            ]
        case .hardDriveImage(let url, let readOnly):
            return [
                "-devicebackend\(unit)", "0",
                "-drive\(unit)type", "4844",
                readOnly ? "-attach\(unit)ro" : "-attach\(unit)rw",
                url.path
            ]
        case .sharedFolder(let url):
            return [
                "-drive\(unit)type", "0",
                "-devicebackend\(unit)", "1",
                "-fs\(unit)", url.path,
                "-fs\(unit)convertp00",
                "+fs\(unit)savep00",
                "+fs\(unit)hidecbm",
                "+fslongnames",
                "+fsoverwrite"
            ]
        }
    }

    /// The VICE drive type that can actually read the disk image, chosen by
    /// file extension. A double-sided D71 attached to the previous hardcoded
    /// 1541 booted far enough to look healthy and then failed in
    /// software that needs the real drive (C128 CP/M's 1571 burst protocol),
    /// so every image family maps to its canonical drive here.
    static func driveType(forDiskImageAt url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "d71", "g71":
            return "1571"
        case "d81":
            return "1581"
        case "d1m", "d2m", "d4m":
            return "4000"
        case "d80":
            return "8050"
        case "d82":
            return "8250"
        case "d90":
            return "9000"
        default:
            return "1541"
        }
    }
}

/// Complete startup configuration for one embedded VICE machine session.
public struct MacVICEMachineConfiguration: Sendable, Equatable {
    /// Machine target to launch.
    public var machine: MacVICEMachine
    /// Where the native VICE runtime dylibs and data files should be loaded from.
    public var runtimeLocation: MacVICERuntimeLocation
    /// Optional VICE model name passed with `-model`.
    public var model: String?
    /// Optional video standard passed as `-pal` or `-ntsc`.
    public var videoStandard: MacVICEVideoStandard?
    /// Bundled or custom ROM selection.
    public var roms: MacVICEROMSet
    /// Drives to configure before startup.
    public var drives: [MacVICEDriveConfiguration]
    /// Optional media URL to autostart after machine launch.
    public var autostartURL: URL?
    /// Run mode for `autostartURL`.
    public var autostartRunMode: MacVICEMediaRunMode
    /// Enables VICE sound output at startup.
    public var soundEnabled: Bool
    /// Enables VICE warp mode at startup.
    public var warpEnabled: Bool
    /// Extra VICE command-line arguments appended after MacVICEKit-managed arguments.
    public var extraArguments: [String]

    /// Creates a startup configuration.
    public init(machine: MacVICEMachine,
                runtimeLocation: MacVICERuntimeLocation = .automatic,
                model: String? = nil,
                videoStandard: MacVICEVideoStandard? = nil,
                roms: MacVICEROMSet = .bundled,
                drives: [MacVICEDriveConfiguration] = [],
                autostartURL: URL? = nil,
                autostartRunMode: MacVICEMediaRunMode = .run,
                soundEnabled: Bool = true,
                warpEnabled: Bool = false,
                extraArguments: [String] = []) {
        self.machine = machine
        self.runtimeLocation = runtimeLocation
        self.model = model
        self.videoStandard = videoStandard
        self.roms = roms
        self.drives = drives
        self.autostartURL = autostartURL
        self.autostartRunMode = autostartRunMode
        self.soundEnabled = soundEnabled
        self.warpEnabled = warpEnabled
        self.extraArguments = extraArguments
    }

    /// Convenience configuration for a C64 project folder workflow.
    ///
    /// When `projectFolder` is supplied, it is mounted as device 8 through
    /// VICE's filesystem-device backend. When `program` is supplied, it is
    /// passed as the autostart target.
    public static func c64(projectFolder: URL? = nil,
                           autostart program: URL? = nil,
                           runtimeLocation: MacVICERuntimeLocation = .automatic) -> MacVICEMachineConfiguration {
        var drives: [MacVICEDriveConfiguration] = []
        if let projectFolder {
            drives.append(MacVICEDriveConfiguration(unit: 8, kind: .sharedFolder(projectFolder)))
        }

        return MacVICEMachineConfiguration(machine: .c64sc,
                                           runtimeLocation: runtimeLocation,
                                           drives: drives,
                                           autostartURL: program)
    }

    /// Resolves the runtime and converts this configuration into a launch plan.
    public func launchPlan() throws -> MacVICELaunchPlan {
        let runtime = try MacVICERuntime.resolve(location: runtimeLocation, machine: machine)
        let arguments = launchArguments(runtime: runtime)

        return MacVICELaunchPlan(machine: machine,
                                 runtime: runtime,
                                 arguments: arguments)
    }

    func launchArguments(runtime: MacVICERuntime) -> [String] {
        var arguments = [
            machine.executableName,
            "-default",
            "-directory",
            runtime.dataDirectoryURL.path,
            warpEnabled ? "-warp" : "+warp",
            soundEnabled ? "-sound" : "+sound"
        ]

        if let model = model ?? machine.defaultModel(for: videoStandard) {
            arguments += ["-model", model]
        }

        if let videoStandard {
            switch videoStandard {
            case .pal:
                arguments += ["-pal"]
            case .ntsc:
                arguments += ["-ntsc"]
            }
        }

        arguments += roms.startupArguments
        arguments += drives.flatMap(\.startupArguments)

        if let autostartURL {
            arguments += [
                "-autostart",
                autostartURL.path
            ]
        }

        arguments += extraArguments

        return arguments
    }
}

/// Resolved startup inputs ready to hand to `MacVICEEngineSession`.
public struct MacVICELaunchPlan: Sendable, Equatable {
    /// Machine target to launch.
    public let machine: MacVICEMachine
    /// Resolved runtime containing the machine dylib and VICE data directory.
    public let runtime: MacVICERuntime
    /// Full VICE argument vector, including `argv[0]`.
    public let arguments: [String]

    /// Creates a launch plan from already-resolved values.
    public init(machine: MacVICEMachine,
                runtime: MacVICERuntime,
                arguments: [String]) {
        self.machine = machine
        self.runtime = runtime
        self.arguments = arguments
    }

    /// Runtime dylib URL for `machine`.
    public var dynamicLibraryURL: URL {
        runtime.dynamicLibraryURL(for: machine)
    }
}
