import Foundation
import ImageIO
import XCTest
@testable import MacVICEKit

private final class LiveRuntimeTestGate: @unchecked Sendable {
    private let lock = NSLock()
    private var didStartLiveRuntimeInProcess = false

    func claim() throws {
        lock.lock()
        defer { lock.unlock() }

        if didStartLiveRuntimeInProcess {
            throw XCTSkip("VICE is not safely reentrant inside one XCTest host process.")
        }

        didStartLiveRuntimeInProcess = true
    }
}

final class MacVICEKitTests: XCTestCase {
    private static let liveRuntimeGate = LiveRuntimeTestGate()

    private static func claimLiveRuntimeTest() throws {
        try liveRuntimeGate.claim()
    }

    private static func stopRunningEngine(timeout: TimeInterval = 2) {
        _ = MacVICEEngineSession.requestQuit()
        let deadline = Date().addingTimeInterval(timeout)
        while MacVICEEngineSession.isRunning && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
    }

    func testMacVICEKitPackagePinsSwift6LanguageMode() throws {
        let source = try packageSourceText("Package.swift")

        XCTAssertTrue(source.contains("// swift-tools-version: 6.0"))
        XCTAssertTrue(source.contains("swiftLanguageModes: [.v6]"))
    }

    func testMacVICEKitSDKTemplatesPinSwift6LanguageMode() throws {
        let packageScript = try repositorySourceText("macos/scripts/package-macvicekit-runtime.sh")
        let smokeScript = try repositorySourceText("macos/scripts/smoke-test-macvicekit-sdk.sh")

        XCTAssertTrue(packageScript.contains("// swift-tools-version: 6.0"))
        XCTAssertTrue(packageScript.contains("swiftLanguageModes: [.v6]"))
        XCTAssertTrue(smokeScript.contains("// swift-tools-version: 6.0"))
        XCTAssertTrue(smokeScript.contains("swiftLanguageModes: [.v6]"))
    }

    func testEngineSessionClearsNativeCallbacksBeforeDeinit() throws {
        let source = try packageSourceText("Sources/MacVICEKit/Engine/MacVICEEngineSession.swift")

        XCTAssertTrue(source.contains("deinit {"))
        XCTAssertTrue(source.contains("private var hasInstalledCallbacks = false"))
        XCTAssertTrue(source.contains("clearInstalledCallbacks()"))
        XCTAssertTrue(source.contains("guard hasInstalledCallbacks else"))
        XCTAssertTrue(source.contains("Self.clearCallbacks()"))
        XCTAssertTrue(source.contains("ViceEngineSetVideoFrameCallback(nil, nil)"))
        XCTAssertTrue(source.contains("ViceEngineSetAudioSamplesCallback(nil, nil)"))
        XCTAssertTrue(source.contains("ViceEngineSetDriveStatusCallback(nil, nil)"))
        XCTAssertTrue(source.contains("ViceEngineSetCartridgeStatusCallback(nil, nil)"))
        XCTAssertTrue(source.contains("ViceEngineSetVSIDStateCallback(nil, nil)"))
        XCTAssertTrue(source.contains("ViceEngineSetSIDVoiceSamplesCallback(nil, nil)"))
    }

    func testDefaultConfigurationBuildsMinimalLaunchArguments() {
        let runtime = fakeRuntime()
        let configuration = MacVICEMachineConfiguration(machine: .c64sc)

        XCTAssertEqual(
            configuration.launchArguments(runtime: runtime),
            [
                "x64sc",
                "-default",
                "-directory", runtime.dataDirectoryURL.path,
                "+warp",
                "-sound"
            ]
        )
    }

    func testVariantConfigurationBuildsExpectedDefaultModelArguments() {
        let runtime = fakeRuntime()

        let c16Arguments = MacVICEMachineConfiguration(machine: .c16)
            .launchArguments(runtime: runtime)
        let c16NTSCArguments = MacVICEMachineConfiguration(machine: .c16, videoStandard: .ntsc)
            .launchArguments(runtime: runtime)
        let plus4PALArguments = MacVICEMachineConfiguration(machine: .plus4, videoStandard: .pal)
            .launchArguments(runtime: runtime)
        let plus4NTSCArguments = MacVICEMachineConfiguration(machine: .plus4, videoStandard: .ntsc)
            .launchArguments(runtime: runtime)
        let c232Arguments = MacVICEMachineConfiguration(machine: .c232)
            .launchArguments(runtime: runtime)
        let v364Arguments = MacVICEMachineConfiguration(machine: .v364)
            .launchArguments(runtime: runtime)

        XCTAssertEqual(c16Arguments.first, "xc16")
        XCTAssertEqual(c16Arguments.value(after: "-model"), "c16pal")
        XCTAssertEqual(c16NTSCArguments.value(after: "-model"), "c16ntsc")
        XCTAssertTrue(c16NTSCArguments.contains("-ntsc"))
        XCTAssertEqual(plus4PALArguments.first, "xplus4")
        XCTAssertEqual(plus4PALArguments.value(after: "-model"), "plus4pal")
        XCTAssertTrue(plus4PALArguments.contains("-pal"))
        XCTAssertEqual(plus4NTSCArguments.value(after: "-model"), "plus4ntsc")
        XCTAssertTrue(plus4NTSCArguments.contains("-ntsc"))
        XCTAssertEqual(c232Arguments.first, "xc232")
        XCTAssertEqual(c232Arguments.value(after: "-model"), "c232")
        XCTAssertEqual(v364Arguments.first, "xv364")
        XCTAssertEqual(v364Arguments.value(after: "-model"), "v364")
    }

    func testRuntimeVideoStandardModelNamesHideVICEModelCoupling() {
        XCTAssertEqual(MacVICEMachine.c64sc.runtimeModel(for: .ntsc, preferredModel: nil), "c64ntsc")
        XCTAssertEqual(MacVICEMachine.c64sc.runtimeModel(for: .pal, preferredModel: "c64c"), "c64c")
        XCTAssertEqual(MacVICEMachine.c128.runtimeModel(for: .pal, preferredModel: nil), "pal")
        XCTAssertEqual(MacVICEMachine.plus4.runtimeModel(for: .ntsc, preferredModel: nil), "plus4ntsc")
        XCTAssertEqual(MacVICEMachine.plus4.runtimeModel(for: .pal, preferredModel: "plus4pal"), "plus4pal")
        XCTAssertEqual(MacVICEMachine.c16.runtimeModel(for: .ntsc, preferredModel: nil), "c16ntsc")
        XCTAssertNil(MacVICEMachine.pet.runtimeModel(for: .pal, preferredModel: "4032"))
        XCTAssertNil(MacVICEMachine.vic20.runtimeModel(for: .ntsc, preferredModel: nil))
    }

    func testC64ProjectConfigurationBuildsFriendlyLaunchArguments() throws {
        let projectURL = URL(fileURLWithPath: "/tmp/c64-project", isDirectory: true)
        let prgURL = projectURL.appendingPathComponent("build/demo.prg")
        let runtime = fakeRuntime()
        let configuration = MacVICEMachineConfiguration.c64(projectFolder: projectURL,
                                                            autostart: prgURL,
                                                            runtimeLocation: .directory(runtime.directoryURL))

        let arguments = configuration.launchArguments(runtime: runtime)

        XCTAssertEqual(arguments.first, "x64sc")
        XCTAssertTrue(arguments.contains("-default"))
        XCTAssertEqual(arguments.value(after: "-directory"), runtime.dataDirectoryURL.path)
        XCTAssertEqual(arguments.value(after: "-devicebackend8"), "1")
        XCTAssertEqual(arguments.value(after: "-fs8"), projectURL.path)
        XCTAssertTrue(arguments.contains("-fs8convertp00"))
        XCTAssertTrue(arguments.contains("+fslongnames"))
        XCTAssertEqual(arguments.value(after: "-autostart"), prgURL.path)
    }

    func testLaunchPlanResolvesAllSupportedMachinesAgainstOneRuntime() throws {
        let runtimeURL = try createRuntimeDirectory(for: .c64sc, .c128, .vic20, .pet, .plus4, .vsid)

        for machine in MacVICEMachine.allCases {
            let configuration = MacVICEMachineConfiguration(machine: machine,
                                                            runtimeLocation: .directory(runtimeURL))

            let plan = try configuration.launchPlan()

            XCTAssertEqual(plan.machine, machine)
            XCTAssertEqual(plan.arguments.first, machine.executableName)
            XCTAssertEqual(plan.dynamicLibraryURL.lastPathComponent, machine.dynamicLibraryName)
            XCTAssertEqual(standardizedPath(plan.runtime.directoryURL), standardizedPath(runtimeURL))
        }
    }

    func testLaunchPlanResolvesExplicitRuntimeDirectory() throws {
        let runtimeURL = try createRuntimeDirectory(for: .c64sc)
        let configuration = MacVICEMachineConfiguration(machine: .c64sc,
                                                        runtimeLocation: .directory(runtimeURL),
                                                        soundEnabled: false,
                                                        warpEnabled: true)

        let plan = try configuration.launchPlan()

        XCTAssertEqual(plan.machine, .c64sc)
        XCTAssertEqual(plan.dynamicLibraryURL.lastPathComponent, "libvicemacx64sc.dylib")
        XCTAssertEqual(standardizedPath(plan.runtime.directoryURL), standardizedPath(runtimeURL))
        XCTAssertEqual(standardizedPath(plan.runtime.dataDirectoryURL),
                       standardizedPath(runtimeURL.appendingPathComponent("VICEData", isDirectory: true)))
        XCTAssertTrue(plan.arguments.contains("+sound"))
        XCTAssertTrue(plan.arguments.contains("-warp"))
    }

    func testLaunchPlanUsesLegacyDataDirectoryWhenVICEDataIsNotPresent() throws {
        let runtimeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macvice-runtime-\(UUID().uuidString)", isDirectory: true)
        let dataURL = runtimeURL.appendingPathComponent("data", isDirectory: true)
        try FileManager.default.createDirectory(at: dataURL, withIntermediateDirectories: true)
        try Data().write(to: runtimeURL.appendingPathComponent(MacVICEMachine.c64sc.dynamicLibraryName))
        addTeardownBlock { try? FileManager.default.removeItem(at: runtimeURL) }

        let configuration = MacVICEMachineConfiguration(machine: .c64sc,
                                                        runtimeLocation: .directory(runtimeURL))

        let plan = try configuration.launchPlan()

        XCTAssertEqual(standardizedPath(plan.runtime.dataDirectoryURL), standardizedPath(dataURL))
        XCTAssertEqual(plan.arguments.value(after: "-directory"), dataURL.path)
    }

    func testAutomaticRuntimeResolutionUsesEnvironmentOverride() throws {
        let runtimeURL = try createRuntimeDirectory(for: .c64sc)
        let previous = ProcessInfo.processInfo.environment["MACVICE_RUNTIME_DIR"]
        setenv("MACVICE_RUNTIME_DIR", runtimeURL.path, 1)
        addTeardownBlock {
            if let previous {
                setenv("MACVICE_RUNTIME_DIR", previous, 1)
            } else {
                unsetenv("MACVICE_RUNTIME_DIR")
            }
        }

        let configuration = MacVICEMachineConfiguration(machine: .c64sc,
                                                        runtimeLocation: .automatic)

        let plan = try configuration.launchPlan()

        XCTAssertEqual(standardizedPath(plan.runtime.directoryURL), standardizedPath(runtimeURL))
    }

    func testLaunchPlanResolvesRuntimeFrameworkBundle() throws {
        let bundleURL = try createRuntimeFrameworkBundle(for: .c64sc)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let configuration = MacVICEMachineConfiguration(machine: .c64sc,
                                                        runtimeLocation: .frameworkBundle(bundle))

        let plan = try configuration.launchPlan()

        XCTAssertEqual(standardizedPath(plan.runtime.directoryURL),
                       standardizedPath(bundleURL.appendingPathComponent("Frameworks", isDirectory: true)))
        XCTAssertEqual(standardizedPath(plan.runtime.dataDirectoryURL),
                       standardizedPath(bundleURL.appendingPathComponent("Resources/VICEData", isDirectory: true)))
        XCTAssertEqual(plan.dynamicLibraryURL.lastPathComponent, "libvicemacx64sc.dylib")
    }

    func testLaunchPlanResolvesRuntimeFrameworkBundleWithResourcesRuntimeDirectory() throws {
        let bundleURL = try createRuntimeFrameworkBundle(for: [.c64sc], runtimeDirectoryName: "Runtime")
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let configuration = MacVICEMachineConfiguration(machine: .c64sc,
                                                        runtimeLocation: .frameworkBundle(bundle))

        let plan = try configuration.launchPlan()

        XCTAssertEqual(standardizedPath(plan.runtime.directoryURL),
                       standardizedPath(bundleURL.appendingPathComponent("Resources/Runtime", isDirectory: true)))
    }

    func testRuntimeResolutionFindsEmbeddedRuntimeFrameworkInAppBundle() throws {
        let appURL = try createApplicationBundleWithRuntimeFramework(for: .c64sc)
        let appBundle = try XCTUnwrap(Bundle(url: appURL))

        let runtime = try XCTUnwrap(MacVICERuntime.runtimeFromApplicationBundle(appBundle))

        XCTAssertEqual(standardizedPath(runtime.directoryURL),
                       standardizedPath(appURL
                        .appendingPathComponent("Contents/Frameworks", isDirectory: true)
                        .appendingPathComponent(MacVICERuntime.frameworkName, isDirectory: true)
                        .appendingPathComponent("Frameworks", isDirectory: true)))
        XCTAssertEqual(standardizedPath(runtime.dataDirectoryURL),
                       standardizedPath(appURL
                        .appendingPathComponent("Contents/Frameworks", isDirectory: true)
                        .appendingPathComponent(MacVICERuntime.frameworkName, isDirectory: true)
                        .appendingPathComponent("Resources/VICEData", isDirectory: true)))
    }

    func testRuntimeResolutionFindsRepoRootFromNestedPackageSourcePath() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macvice-source-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = rootURL
            .appendingPathComponent("MacVICEKit/Sources/MacVICEKit/Runtime", isDirectory: true)
            .appendingPathComponent("MacVICERuntime.swift")
        let buildProductsURL = rootURL
            .appendingPathComponent("macos", isDirectory: true)
            .appendingPathComponent("BuildProducts", isDirectory: true)
        let dataDirectoryURL = rootURL
            .appendingPathComponent("vice", isDirectory: true)
            .appendingPathComponent("data", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: buildProductsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dataDirectoryURL, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: rootURL) }

        let runtime = try XCTUnwrap(MacVICERuntime.runtimeFromSourceCheckout(startingAt: sourceURL))

        XCTAssertEqual(standardizedPath(runtime.directoryURL), standardizedPath(buildProductsURL))
        XCTAssertEqual(standardizedPath(runtime.dataDirectoryURL), standardizedPath(dataDirectoryURL))
    }

    func testLaunchPlanReportsMissingFrameworkRuntimeDirectory() throws {
        let bundleURL = try createRuntimeFrameworkBundle(for: [], runtimeDirectoryName: nil)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let configuration = MacVICEMachineConfiguration(machine: .c64sc,
                                                        runtimeLocation: .frameworkBundle(bundle))

        XCTAssertThrowsError(try configuration.launchPlan()) { error in
            XCTAssertTrue(String(describing: error).contains("runtime dylib directory"))
        }
    }

    func testLaunchPlanReportsMissingFrameworkDataDirectory() throws {
        let bundleURL = try createRuntimeFrameworkBundle(for: [.c64sc],
                                                         runtimeDirectoryName: "Runtime",
                                                         includeDataDirectory: false)
        let bundle = try XCTUnwrap(Bundle(url: bundleURL))
        let configuration = MacVICEMachineConfiguration(machine: .c64sc,
                                                        runtimeLocation: .frameworkBundle(bundle))

        XCTAssertThrowsError(try configuration.launchPlan()) { error in
            XCTAssertTrue(String(describing: error).contains("VICEData"))
        }
    }

    func testLaunchPlanReportsMissingRuntimeLibrary() throws {
        let runtimeURL = try createRuntimeDirectory()
        let configuration = MacVICEMachineConfiguration(machine: .c128,
                                                        runtimeLocation: .directory(runtimeURL))

        XCTAssertThrowsError(try configuration.launchPlan()) { error in
            XCTAssertTrue(String(describing: error).contains("libvicemacx128.dylib"))
        }
    }

    func testLaunchPlanReportsMissingDataDirectory() throws {
        let runtimeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macvice-runtime-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: runtimeURL, withIntermediateDirectories: true)
        try Data().write(to: runtimeURL.appendingPathComponent(MacVICEMachine.c64sc.dynamicLibraryName))
        addTeardownBlock { try? FileManager.default.removeItem(at: runtimeURL) }

        let configuration = MacVICEMachineConfiguration(machine: .c64sc,
                                                        runtimeLocation: .directory(runtimeURL))

        XCTAssertThrowsError(try configuration.launchPlan()) { error in
            XCTAssertTrue(String(describing: error).contains("VICEData"))
        }
    }

    func testRuntimeDynamicLibraryURLsAreMachineSpecific() {
        let runtime = fakeRuntime()

        for machine in MacVICEMachine.allCases {
            XCTAssertEqual(runtime.dynamicLibraryURL(for: machine).lastPathComponent, machine.dynamicLibraryName)
        }
    }

    func testMachineRuntimeMetadataMatchesVICETargets() {
        let expected: [(MacVICEMachine, String, String, String)] = [
            (.c64sc, "x64sc", "x64sc", "libvicemacx64sc.dylib"),
            (.c128, "x128", "x128", "libvicemacx128.dylib"),
            (.vic20, "xvic", "xvic", "libvicemacxvic.dylib"),
            (.pet, "xpet", "xpet", "libvicemacxpet.dylib"),
            (.plus4, "xplus4", "xplus4", "libvicemacxplus4.dylib"),
            (.c16, "xplus4", "xc16", "libvicemacxplus4.dylib"),
            (.c232, "xplus4", "xc232", "libvicemacxplus4.dylib"),
            (.v364, "xplus4", "xv364", "libvicemacxplus4.dylib"),
            (.vsid, "vsid", "vsid", "libvicemacvsid.dylib")
        ]

        for (machine, target, executable, library) in expected {
            XCTAssertEqual(machine.viceTarget, target)
            XCTAssertEqual(machine.executableName, executable)
            XCTAssertEqual(machine.dynamicLibraryName, library)
        }
    }

    func testMachineRuntimeBuildTargetsAreDeduplicatedVICEEntrypoints() {
        XCTAssertEqual(MacVICEMachine.runtimeBuildTargets, ["x64sc", "x128", "xvic", "xpet", "xplus4", "vsid"])
    }

    func testMachineDisplayProfilesMatchExpectedBootSizes() {
        let expected: [(MacVICEMachine, CGSize, CGFloat)] = [
            (.c64sc, CGSize(width: 384, height: 272), 2),
            (.c128, CGSize(width: 384, height: 272), 2),
            (.vic20, CGSize(width: 400, height: 234), 2),
            (.pet, CGSize(width: 640, height: 400), 1),
            (.plus4, CGSize(width: 384, height: 288), 2),
            (.c16, CGSize(width: 384, height: 288), 2),
            (.c232, CGSize(width: 384, height: 288), 2),
            (.v364, CGSize(width: 384, height: 288), 2),
            (.vsid, CGSize(width: 384, height: 272), 2)
        ]

        for (machine, bootSize, nativeScale) in expected {
            XCTAssertEqual(machine.displayProfile.bootFrame.pixelSize, bootSize)
            XCTAssertEqual(machine.displayProfile.nativeScale, nativeScale)
            XCTAssertEqual(machine.displayProfile.pixelAspectRatio, 1)
        }
    }

    func testStorageStartupArgumentsAreVICECompatible() {
        let diskURL = URL(fileURLWithPath: "/tmp/game.d64")
        let hdURL = URL(fileURLWithPath: "/tmp/hd.dhd")
        let folderURL = URL(fileURLWithPath: "/tmp/shared", isDirectory: true)

        XCTAssertEqual(
            MacVICEDriveConfiguration(unit: 8, kind: .detached).startupArguments,
            ["-devicebackend8", "0", "-drive8type", "0"]
        )
        XCTAssertEqual(
            MacVICEDriveConfiguration(unit: 8, kind: .diskImage(diskURL, readOnly: true)).startupArguments,
            ["-devicebackend8", "0", "-drive8type", "1541", "-attach8ro", diskURL.path]
        )
        XCTAssertEqual(
            MacVICEDriveConfiguration(unit: 9, kind: .hardDriveImage(hdURL)).startupArguments,
            ["-devicebackend9", "0", "-drive9type", "4844", "-attach9rw", hdURL.path]
        )
        XCTAssertEqual(
            MacVICEDriveConfiguration(unit: 10, kind: .sharedFolder(folderURL)).startupArguments,
            [
                "-drive10type", "0",
                "-devicebackend10", "1",
                "-fs10", folderURL.path,
                "-fs10convertp00",
                "+fs10savep00",
                "+fs10hidecbm",
                "+fslongnames",
                "+fsoverwrite"
            ]
        )
    }

    func testDiskImageDriveTypeFollowsImageFamily() {
        // A D71 on the old hardcoded 1541 reads far enough to look healthy,
        // then dies in software that needs the real drive (C128 CP/M's 1571
        // burst protocol). Every image family must map to a drive that can
        // actually read it.
        let expectations: [(String, String)] = [
            ("game.d64", "1541"),
            ("game.d67", "1541"),
            ("game.g64", "1541"),
            ("game.p64", "1541"),
            ("game.x64", "1541"),
            ("turbocpm128.d71", "1571"),
            ("flux.g71", "1571"),
            ("spacious.d81", "1581"),
            ("cmd.d1m", "4000"),
            ("cmd.d2m", "4000"),
            ("cmd.d4m", "4000"),
            ("pet.d80", "8050"),
            ("pet.d82", "8250"),
            ("big.d90", "9000"),
            ("UPPER.D71", "1571"),
            ("noextension", "1541")
        ]

        for (name, driveType) in expectations {
            let url = URL(fileURLWithPath: "/tmp/\(name)")
            XCTAssertEqual(
                MacVICEDriveConfiguration(unit: 8, kind: .diskImage(url)).startupArguments,
                ["-devicebackend8", "0", "-drive8type", driveType, "-attach8rw", url.path],
                "wrong drive type for \(name)"
            )
        }
    }

    func testStorageReadWriteArgumentsAreVICECompatible() {
        let diskURL = URL(fileURLWithPath: "/tmp/game.d64")
        let hdURL = URL(fileURLWithPath: "/tmp/hd.dhd")

        XCTAssertEqual(
            MacVICEDriveConfiguration(unit: 11, kind: .diskImage(diskURL, readOnly: false)).startupArguments,
            ["-devicebackend11", "0", "-drive11type", "1541", "-attach11rw", diskURL.path]
        )
        XCTAssertEqual(
            MacVICEDriveConfiguration(unit: 9, kind: .hardDriveImage(hdURL, readOnly: true)).startupArguments,
            ["-devicebackend9", "0", "-drive9type", "4844", "-attach9ro", hdURL.path]
        )
    }

    func testMultipleDriveArgumentsPreserveCallerOrdering() {
        let diskURL = URL(fileURLWithPath: "/tmp/a.d64")
        let folderURL = URL(fileURLWithPath: "/tmp/project", isDirectory: true)
        let runtime = fakeRuntime()
        let configuration = MacVICEMachineConfiguration(
            machine: .c64sc,
            drives: [
                MacVICEDriveConfiguration(unit: 9, kind: .sharedFolder(folderURL)),
                MacVICEDriveConfiguration(unit: 8, kind: .diskImage(diskURL))
            ]
        )

        let arguments = configuration.launchArguments(runtime: runtime)

        XCTAssertLessThan(arguments.firstIndex(of: "-fs9") ?? Int.max,
                          arguments.firstIndex(of: "-attach8rw") ?? Int.max)
        XCTAssertEqual(arguments.value(after: "-fs9"), folderURL.path)
        XCTAssertEqual(arguments.value(after: "-attach8rw"), diskURL.path)
    }

    func testROMOverridesAndAdvancedArgumentsArePreserved() {
        let basicURL = URL(fileURLWithPath: "/roms/basic.rom")
        let kernalURL = URL(fileURLWithPath: "/roms/kernal.rom")
        let runtime = fakeRuntime()
        let configuration = MacVICEMachineConfiguration(
            machine: .c64sc,
            runtimeLocation: .directory(runtime.directoryURL),
            model: "c64c",
            videoStandard: .ntsc,
            roms: .custom([
                MacVICEROMOverride(viceOption: "-basic", url: basicURL),
                MacVICEROMOverride(viceOption: "-kernal", url: kernalURL)
            ]),
            extraArguments: ["-moncommands", "/tmp/symbols.mon"]
        )

        let arguments = configuration.launchArguments(runtime: runtime)

        XCTAssertEqual(arguments.value(after: "-model"), "c64c")
        XCTAssertTrue(arguments.contains("-ntsc"))
        XCTAssertEqual(arguments.value(after: "-basic"), basicURL.path)
        XCTAssertEqual(arguments.value(after: "-kernal"), kernalURL.path)
        XCTAssertEqual(arguments.value(after: "-moncommands"), "/tmp/symbols.mon")
    }

    func testROMSetBundledAddsNoLaunchArguments() {
        XCTAssertEqual(MacVICEROMSet.bundled.startupArguments, [])
    }

    func testMediaRunModesMatchBridgeRawValues() {
        XCTAssertEqual(MacVICEMediaRunMode.attach.rawValue, -1)
        XCTAssertEqual(MacVICEMediaRunMode.run.rawValue, 0)
        XCTAssertEqual(MacVICEMediaRunMode.load.rawValue, 1)
    }

    func testFrameSourcePublishesLatestFramesBySequence() throws {
        let source = MacVICEFrameSource(displayProfile: MacVICEMachine.c64sc.displayProfile)
        let first = MacVICEVideoFrame(width: 1,
                                      height: 1,
                                      bytesPerRow: 4,
                                      sequence: 1,
                                      pixels: Data([255, 0, 0, 255]))
        let second = MacVICEVideoFrame(width: 1,
                                       height: 1,
                                       bytesPerRow: 4,
                                       sequence: 2,
                                       pixels: Data([0, 255, 0, 255]))

        XCTAssertNil(source.copyLatestFrame())
        source.publish(first)
        XCTAssertEqual(source.copyLatestFrame(after: 0)?.sequence, 1)
        XCTAssertNil(source.copyLatestFrame(after: 1))
        source.publish(second)
        XCTAssertEqual(source.copyLatestFrame()?.sequence, 2)
        XCTAssertEqual(source.copyLatestFrame(after: 1)?.pixels, second.pixels)
    }

    func testFrameSourceExportsLatestFrameAsPNG() throws {
        let source = MacVICEFrameSource(displayProfile: MacVICEMachine.c64sc.displayProfile)
        source.publish(MacVICEVideoFrame(width: 1,
                                         height: 1,
                                         bytesPerRow: 4,
                                         sequence: 1,
                                         pixels: Data([0, 0, 255, 255])))

        let png = try source.latestScreenshotPNG()

        XCTAssertEqual(Array(png.prefix(8)), [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])
        XCTAssertNotNil(CGImageSourceCreateWithData(png as CFData, nil))
    }

    func testFrameSourceExportsPaddedRowsAsPNG() throws {
        let frame = MacVICEVideoFrame(width: 2,
                                      height: 1,
                                      bytesPerRow: 12,
                                      sequence: 1,
                                      pixels: Data([
                                        255, 0, 0, 255,
                                        0, 255, 0, 255,
                                        0, 0, 0, 0
                                      ]))

        let png = try MacVICEFrameSource.pngData(from: frame)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(png as CFData, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])

        XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, 2)
        XCTAssertEqual(properties[kCGImagePropertyPixelHeight] as? Int, 1)
    }

    func testFrameSourceReportsMissingScreenshotFrame() {
        let source = MacVICEFrameSource(displayProfile: MacVICEMachine.c64sc.displayProfile)

        XCTAssertThrowsError(try source.latestScreenshotPNG()) { error in
            XCTAssertTrue(String(describing: error).contains("No VICE video frame"))
        }
    }

    func testFrameSourceRejectsInvalidScreenshotFrames() {
        let invalid = MacVICEVideoFrame(width: 1,
                                        height: 1,
                                        bytesPerRow: 2,
                                        sequence: 1,
                                        pixels: Data([0, 0]))

        XCTAssertThrowsError(try MacVICEFrameSource.pngData(from: invalid))
    }

    func testAudioSourcePublishesLatestSamplesBySequence() {
        let source = MacVICEAudioSampleSource()
        let first = MacVICEAudioSamples(samples: Data([0, 1, 2, 3]),
                                        frameCount: 1,
                                        channelCount: 2,
                                        sampleRate: 44_100,
                                        sequence: 1)
        let second = MacVICEAudioSamples(samples: Data([4, 5, 6, 7]),
                                         frameCount: 1,
                                         channelCount: 2,
                                         sampleRate: 44_100,
                                         sequence: 2)

        XCTAssertNil(source.copyLatestSamples())
        source.publish(first)
        XCTAssertEqual(source.copyLatestSamples(after: 0)?.sequence, 1)
        XCTAssertNil(source.copyLatestSamples(after: 1))
        source.publish(second)
        XCTAssertEqual(source.copyLatestSamples()?.samples, second.samples)
    }

    func testDisplayProfilesPreservePixelAspectAndNativeScale() {
        let profile = MacVICEDisplayProfile(bootFrame: MacVICEBootFrame(pixelSize: CGSize(width: 320, height: 200)),
                                            nativeScale: 2,
                                            pixelAspectRatio: 1.2)

        XCTAssertEqual(profile.presentationSize(for: CGSize(width: 320, height: 200)), CGSize(width: 384, height: 200))
        XCTAssertEqual(profile.nativeDisplaySize(), CGSize(width: 768, height: 400))
    }

    func testMemorySpaceRawValuesMatchVICEMonitorMemspaces() {
        XCTAssertEqual(MacVICEMemorySpace.computer.rawValue, 1)
        XCTAssertEqual(MacVICEMemorySpace.drive8.rawValue, 2)
        XCTAssertEqual(MacVICEMemorySpace.drive9.rawValue, 3)
        XCTAssertEqual(MacVICEMemorySpace.drive10.rawValue, 4)
        XCTAssertEqual(MacVICEMemorySpace.drive11.rawValue, 5)
    }

    func testCheckpointOperationMasksMatchVICEMonitorOperations() {
        XCTAssertEqual(MacVICECheckpointOperation.load.rawValue, 1)
        XCTAssertEqual(MacVICECheckpointOperation.store.rawValue, 2)
        XCTAssertEqual(MacVICECheckpointOperation.execute.rawValue, 4)
        XCTAssertEqual(
            [MacVICECheckpointOperation.load, .store, .execute].reduce(UInt32(0)) { $0 | $1.rawValue },
            7
        )
    }

    func testDisplayConfigurationPresetsArePredictable() {
        XCTAssertFalse(MacVICEDisplayConfiguration.renderOnly.forwardsInput)
        XCTAssertTrue(MacVICEDisplayConfiguration.renderOnly.preservesAspectRatio)
        XCTAssertEqual(MacVICEDisplayConfiguration.renderOnly.filterSettings.preset, .commodore1702)
        XCTAssertTrue(MacVICEDisplayConfiguration.interactive.forwardsInput)
        XCTAssertFalse(MacVICEDisplayConfiguration.interactive.capturesMouse)
    }

    func testDisplayConfigurationIsCustomizableForEmbeddedConsumers() {
        let bootURL = URL(fileURLWithPath: "/tmp/boot.png")
        let filters = MacVICEVideoFilterSettings.defaults(for: .greenPhosphor)
        let configuration = MacVICEDisplayConfiguration(preservesAspectRatio: false,
                                                        filtering: .linear,
                                                        filterSettings: filters,
                                                        forwardsInput: false,
                                                        capturesMouse: true,
                                                        bootImageURL: bootURL)

        XCTAssertFalse(configuration.preservesAspectRatio)
        XCTAssertEqual(configuration.filtering, .linear)
        XCTAssertEqual(configuration.filterSettings, filters)
        XCTAssertFalse(configuration.forwardsInput)
        XCTAssertTrue(configuration.capturesMouse)
        XCTAssertEqual(configuration.bootImageURL, bootURL)
    }

    func testVideoFilterPresetsExposeMacFriendlyLabelsAndDefaults() {
        XCTAssertEqual(MacVICEVideoFilterPreset.commodore1702.toolbarTitle, "1702")
        XCTAssertEqual(MacVICEVideoFilterPreset.greenPhosphor.toolbarTitle, "Green")
        XCTAssertEqual(MacVICEVideoFilterPreset.rf.systemImage, "antenna.radiowaves.left.and.right")

        let clean = MacVICEVideoFilterSettings.defaults(for: .clean)
        XCTAssertEqual(clean.scanlineIntensity, 0)
        XCTAssertEqual(clean.phosphorPersistence, 0)

        let green = MacVICEVideoFilterSettings.defaults(for: .greenPhosphor)
        XCTAssertEqual(green.monochromeAmount, 1)
        XCTAssertGreaterThan(green.phosphorPersistence, clean.phosphorPersistence)
    }

    func testMacVICEErrorsExposeLocalizedDescriptions() {
        XCTAssertEqual(MacVICEError.runtimeNotFound("missing").errorDescription, "missing")
        XCTAssertEqual(MacVICEError.invalidConfiguration("bad config").errorDescription, "bad config")
        XCTAssertEqual(MacVICEError.engineFailure("engine stopped").errorDescription, "engine stopped")
        XCTAssertEqual(MacVICEError.unsupported("not supported").errorDescription, "not supported")
    }

    func testRuntimeFrameworkConstantsAreStableForConsumers() {
        XCTAssertEqual(MacVICERuntime.frameworkName, "MacVICERuntime.framework")
        XCTAssertEqual(MacVICERuntime.frameworkBundleIdentifier, "com.barrywalker.MacVICERuntime")
        XCTAssertEqual(MacVICERuntime.manifestFileName, "MacVICERuntimeManifest.json")
    }

    func testNativeBridgeRejectsStaleDiskAttachABI() throws {
        let bridgeSource = try sourceText(at: "MacVICEKit/Sources/CMacVICEEngineBridge/ViceEngineBridge.c")
        let bridgeHeader = try sourceText(at: "MacVICEKit/Sources/CMacVICEEngineBridge/include/vicemacbridge.h")
        let runtimeHeader = try sourceText(at: "vice/src/arch/macos/vicemacbridge.h")
        let runtimeSource = try sourceText(at: "vice/src/arch/macos/vicemacbridge.c")

        XCTAssertTrue(bridgeSource.contains("vicemac_bridge_abi_version"))
        XCTAssertTrue(bridgeSource.contains("VICEMAC_BRIDGE_ABI_VERSION"))
        XCTAssertTrue(bridgeSource.contains("LOAD_RUNTIME_SYMBOL(queueDriveAttachDisk, \"vicemac_queue_drive_attach_disk_v2\")"))
        XCTAssertFalse(bridgeSource.contains("LOAD_RUNTIME_SYMBOL(queueDriveAttachDisk, \"vicemac_queue_drive_attach_disk\")"))
        XCTAssertTrue(bridgeHeader.contains("int vicemac_queue_drive_attach_disk_v2(uint32_t unit,"))
        XCTAssertTrue(runtimeHeader.contains("int vicemac_queue_drive_attach_disk_v2(uint32_t unit,"))
        XCTAssertTrue(runtimeSource.contains("int vicemac_bridge_abi_version(void)"))
        XCTAssertTrue(runtimeSource.contains("int vicemac_queue_drive_attach_disk_v2(uint32_t unit,"))
    }

    func testNativeBridgeQuitCommandShutsDownVICEThreadBeforeProcessExitFallback() throws {
        let runtimeSource = try sourceText(at: "vice/src/arch/macos/vicemacbridge.c")
        XCTAssertTrue(runtimeSource.contains("#include \"mainlock.h\""))
        XCTAssertTrue(runtimeSource.contains("#include \"main.h\""))

        let quitCaseRange = try XCTUnwrap(runtimeSource.range(of: "case VICEMAC_MACHINE_COMMAND_QUIT:"))
        let quitCase = runtimeSource[quitCaseRange.lowerBound...]
        let breakRange = try XCTUnwrap(quitCase.range(of: "break;"))
        let quitBlock = String(quitCase[..<breakRange.upperBound])

        XCTAssertTrue(quitBlock.contains("#ifdef USE_VICE_THREAD"))
        XCTAssertTrue(quitBlock.contains("mainlock_initiate_shutdown();"))
        XCTAssertTrue(quitBlock.contains("#else"))
        XCTAssertTrue(quitBlock.contains("main_exit();"))
        XCTAssertTrue(quitBlock.contains("pthread_exit(NULL);"))
        XCTAssertFalse(quitBlock.contains("archdep_vice_exit(0);"))
    }

    func testHostBridgeCleansEngineStateWhenVICEExitsThreadDirectly() throws {
        let bridgeSource = try sourceText(at: "MacVICEKit/Sources/CMacVICEEngineBridge/ViceEngineBridge.c")

        XCTAssertTrue(bridgeSource.contains("static void cleanupEngineThread(void *opaque)"))
        XCTAssertTrue(bridgeSource.contains("atomic_store(&engineRunning, false);"))
        XCTAssertTrue(bridgeSource.contains("freeStartArguments(arguments);"))
        XCTAssertTrue(bridgeSource.contains("pthread_cleanup_push(cleanupEngineThread, arguments);"))
        XCTAssertTrue(bridgeSource.contains("pthread_cleanup_pop(1);"))
    }

    func testRuntimeResourceCopiesUseChecksumSyncToAvoidStaleVICEData() throws {
        let prepareScript = try sourceText(at: "macos/scripts/prepare-vicemac-runtime.sh")
        let packageScript = try sourceText(at: "macos/scripts/package-macvicekit-runtime.sh")
        let expectedCommand = "rsync -a --delete --checksum \"$VICE_SRC/data/\" \"$resources_dir/VICEData/\""

        XCTAssertTrue(prepareScript.contains(expectedCommand))
        XCTAssertTrue(packageScript.contains(expectedCommand))
    }

    func testRuntimeDiskAttachPublishesAttachedImagePath() throws {
        guard !MacVICEEngineSession.isRunning else {
            throw XCTSkip("A VICE engine is already running in this process.")
        }
        try Self.claimLiveRuntimeTest()

        let runtime = try builtRuntime()
        let diskURL = try temporaryBlankD64(named: "macvice-attach-\(UUID().uuidString).d64")
        let attached = expectation(description: "Drive 8 reports attached disk image")
        var observedStatuses: [MacVICEDriveStatus] = []
        let configuration = MacVICEMachineConfiguration(machine: .c64sc,
                                                        soundEnabled: false,
                                                        warpEnabled: true,
                                                        extraArguments: [
                                                            "-devicebackend8", "0",
                                                            "-drive8type", "1542",
                                                            "-drive8truedrive",
                                                            "+trapdevice8",
                                                            "-attach8rw"
                                                        ])

        let session = MacVICEEngineSession(
            configuration: configuration
        )
        session.callbacks.driveStatus = { status in
            guard status.unit == 8 else { return }
            observedStatuses.append(status)
            if status.drive0ImagePath == diskURL.path || status.imagePath == diskURL.path {
                attached.fulfill()
            }
        }

        try session.start(machineID: MacVICEMachine.c64sc.viceTarget,
                          dynamicLibraryURL: runtime.dynamicLibraryURL(for: .c64sc),
                          arguments: configuration.launchArguments(runtime: runtime))
        addTeardownBlock {
            Self.stopRunningEngine()
        }

        XCTAssertTrue(session.attachDisk(unit: 8, drive: 0, url: diskURL))
        wait(for: [attached], timeout: 5)

        XCTAssertTrue(observedStatuses.contains { $0.enabled && $0.drive0ImagePath == diskURL.path },
                      "Drive 8 never reported \(diskURL.path). Observed: \(observedStatuses)")
    }

    func testRuntimeDiskAttachReturnsFalseWhenVICERejectsImage() throws {
        guard !MacVICEEngineSession.isRunning else {
            throw XCTSkip("A VICE engine is already running in this process.")
        }
        try Self.claimLiveRuntimeTest()

        let runtime = try builtRuntime()
        let missingDiskURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macvice-missing-\(UUID().uuidString).d64")
        let configuration = MacVICEMachineConfiguration(machine: .c64sc,
                                                        soundEnabled: false,
                                                        warpEnabled: true,
                                                        extraArguments: [
                                                            "-devicebackend8", "0",
                                                            "-drive8type", "1542",
                                                            "-drive8truedrive",
                                                            "+trapdevice8",
                                                            "-attach8rw"
                                                        ])
        let session = MacVICEEngineSession(configuration: configuration)

        try session.start(machineID: MacVICEMachine.c64sc.viceTarget,
                          dynamicLibraryURL: runtime.dynamicLibraryURL(for: .c64sc),
                          arguments: configuration.launchArguments(runtime: runtime))
        addTeardownBlock {
            Self.stopRunningEngine()
        }

        XCTAssertFalse(session.attachDisk(unit: 8, drive: 0, url: missingDiskURL))
    }

    func testRuntimeAttachedDiskCanLoadDirectoryFromBasic() throws {
        guard !MacVICEEngineSession.isRunning else {
            throw XCTSkip("A VICE engine is already running in this process.")
        }
        try Self.claimLiveRuntimeTest()

        let runtime = try builtRuntime()
        let diskTitle = "MACVICE TEST"
        let diskURL = try temporaryFormattedD64(named: "macvice-directory-\(UUID().uuidString).d64",
                                                diskName: diskTitle)
        let configuration = MacVICEMachineConfiguration(machine: .c64sc,
                                                        soundEnabled: false,
                                                        warpEnabled: true,
                                                        extraArguments: [
                                                            "-devicebackend8", "0",
                                                            "-drive8type", "1542",
                                                            "-drive8truedrive",
                                                            "+trapdevice8",
                                                            "-attach8rw"
                                                        ])
        let session = MacVICEEngineSession(configuration: configuration)

        try session.start(machineID: MacVICEMachine.c64sc.viceTarget,
                          dynamicLibraryURL: runtime.dynamicLibraryURL(for: .c64sc),
                          arguments: configuration.launchArguments(runtime: runtime))
        addTeardownBlock {
            Self.stopRunningEngine()
        }

        XCTAssertTrue(session.attachDisk(unit: 8, drive: 0, url: diskURL))
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.25))
        XCTAssertTrue(session.typeText("LOAD\"$\",8\r"))

        let loadedDirectory = waitForBasicDirectoryLoad(session: session,
                                                        diskTitle: diskTitle,
                                                        timeout: 8)
        XCTAssertTrue(loadedDirectory, "BASIC memory never showed a loaded disk directory from \(diskURL.path).")
    }

    func testRuntimeC128BootsTurboCPMFromD71() throws {
        // Regression proof for the drive-type fix: a Turbo CP/M boot D71
        // attached through MacVICEDriveConfiguration must come up on a 1571
        // (the old hardcoded 1541 died at the loader's burst-init stage with
        // E1 on the VDC). The prompt-test image reports the whole boot -
        // loader, 1571 kernel install, CP/M 3, first A> prompt - by writing
        // $AA to bank-0 $2000 (the 8502 side turns that into the debug-cart
        // exit 55 the headless harness sees). Run alone via
        // `swift test --filter testRuntimeC128BootsTurboCPMFromD71`
        // (one live VICE runtime per test process).
        guard !MacVICEEngineSession.isRunning else {
            throw XCTSkip("A VICE engine is already running in this process.")
        }
        try Self.claimLiveRuntimeTest()

        let environment = ProcessInfo.processInfo.environment
        let diskPath = environment["TURBOCPM128_PROMPT_D71"]
            ?? ("\(NSHomeDirectory())/Git/turbocpm128/build/turbocpm128-cpm3-prompt-test.d71")
        guard FileManager.default.fileExists(atPath: diskPath) else {
            throw XCTSkip("Turbo CP/M prompt-test image not found at \(diskPath); build it with `make` in turbocpm128 or set TURBOCPM128_PROMPT_D71.")
        }

        let runtime = try builtRuntime()
        let x128Library = runtime.dynamicLibraryURL(for: .c128)
        guard FileManager.default.fileExists(atPath: x128Library.path) else {
            throw XCTSkip("Build the VICE Mac C128 scheme first; missing \(x128Library.path).")
        }

        let diskURL = URL(fileURLWithPath: diskPath)
        let configuration = MacVICEMachineConfiguration(
            machine: .c128,
            drives: [MacVICEDriveConfiguration(unit: 8, kind: .diskImage(diskURL, readOnly: true))],
            soundEnabled: false,
            warpEnabled: true
        )

        let session = MacVICEEngineSession(configuration: configuration)
        try session.start(machineID: MacVICEMachine.c128.viceTarget,
                          dynamicLibraryURL: x128Library,
                          arguments: configuration.launchArguments(runtime: runtime))
        addTeardownBlock {
            Self.stopRunningEngine()
        }

        // Bank 4 is the monitor's ram00 view: physical bank-0 RAM no matter
        // which CPU or MMU configuration is live when we look.
        let bootResultAddress: UInt32 = 0x2000
        let deadline = Date().addingTimeInterval(120)
        var lastObserved: UInt8 = 0
        while Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.25))
            if let byte = try? session.debugger.peekByte(bank: 4, address: bootResultAddress) {
                lastObserved = byte
                if byte == 0xAA {
                    return
                }
                if (byte & 0xF0) == 0xE0 {
                    break
                }
            }
        }

        XCTFail(String(format: "Turbo CP/M did not reach its CP/M prompt; boot result byte is $%02X (expected $AA; $Ex = loader stage failure, $00 = still booting or Z80 never ran).", lastObserved))
    }

    func testCStringArrayBridgesSwiftArgumentsToNullTerminatedArgv() {
        let arguments = ["x64sc", "-default", "-directory", "/tmp/runtime/VICEData"]

        let bridged = arguments.withMacVICECStringArray { argc, argv -> [String] in
            XCTAssertEqual(argc, Int32(arguments.count))
            guard let argv else {
                XCTFail("Expected argv storage")
                return []
            }

            let values = (0..<Int(argc)).map { index -> String in
                guard let pointer = argv[index] else {
                    XCTFail("Expected argv[\(index)]")
                    return ""
                }
                return String(cString: pointer)
            }
            XCTAssertNil(argv[Int(argc)])
            return values
        }

        XCTAssertEqual(bridged, arguments)
    }

    func testExistingDirectoryHelperRejectsFilesAndMissingPaths() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macvice-existing-directory-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent("file.txt")
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try Data().write(to: fileURL)
        addTeardownBlock { try? FileManager.default.removeItem(at: directoryURL) }

        XCTAssertNotNil(directoryURL.macVICEExistingDirectory)
        XCTAssertNil(fileURL.macVICEExistingDirectory)
        XCTAssertNil(directoryURL.appendingPathComponent("missing", isDirectory: true).macVICEExistingDirectory)
    }

    private func fakeRuntime() -> MacVICERuntime {
        let runtimeURL = URL(fileURLWithPath: "/tmp/macvice-runtime", isDirectory: true)
        return MacVICERuntime(directoryURL: runtimeURL,
                              dataDirectoryURL: runtimeURL.appendingPathComponent("VICEData", isDirectory: true))
    }

    private func sourceText(at relativePath: String) throws -> String {
        guard let rootURL = repositoryRoot() else {
            throw XCTSkip("Source checkout unavailable; this test requires the bundled VICE source tree.")
        }

        return try String(contentsOf: rootURL.appendingPathComponent(relativePath),
                          encoding: .utf8)
    }

    private func builtRuntime() throws -> MacVICERuntime {
        guard let runtime = MacVICERuntime.runtimeFromSourceCheckout(startingAt: URL(fileURLWithPath: #filePath)) else {
            throw XCTSkip("Build the VICE Mac C64 scheme first; source checkout runtime was not found.")
        }

        guard FileManager.default.fileExists(atPath: runtime.dynamicLibraryURL(for: .c64sc).path) else {
            throw XCTSkip("Build the VICE Mac C64 scheme first; missing \(runtime.dynamicLibraryURL(for: .c64sc).path).")
        }

        return runtime
    }

    private func temporaryBlankD64(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try Data(repeating: 0, count: 174_848).write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func temporaryFormattedD64(named name: String, diskName: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try formattedD64Data(diskName: diskName, diskID: "42").write(to: url)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    private func formattedD64Data(diskName: String, diskID: String) -> Data {
        let sectorsPerTrack = [21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21,
                               19, 19, 19, 19, 19, 19, 19,
                               18, 18, 18, 18, 18, 18,
                               17, 17, 17, 17, 17]
        var data = Data(repeating: 0, count: sectorsPerTrack.reduce(0, +) * 256)

        func offset(track: Int, sector: Int) -> Int {
            (sectorsPerTrack.prefix(track - 1).reduce(0, +) + sector) * 256
        }

        func petsciiName(_ value: String, length: Int) -> [UInt8] {
            let bytes = Array(value.uppercased().utf8.prefix(length))
            return bytes + Array(repeating: 0xa0, count: max(0, length - bytes.count))
        }

        let bamOffset = offset(track: 18, sector: 0)
        data[bamOffset] = 18
        data[bamOffset + 1] = 1
        data[bamOffset + 2] = 0x41

        for track in 1...35 {
            let entryOffset = bamOffset + 4 + ((track - 1) * 4)
            let sectorCount = sectorsPerTrack[track - 1]
            var bitmap = UInt32((1 << sectorCount) - 1)
            var freeCount = UInt8(sectorCount)

            if track == 18 {
                bitmap &= ~UInt32(1 << 0)
                bitmap &= ~UInt32(1 << 1)
                freeCount -= 2
            }

            data[entryOffset] = freeCount
            data[entryOffset + 1] = UInt8(bitmap & 0xff)
            data[entryOffset + 2] = UInt8((bitmap >> 8) & 0xff)
            data[entryOffset + 3] = UInt8((bitmap >> 16) & 0xff)
        }

        data.replaceSubrange((bamOffset + 0x90)..<(bamOffset + 0xa0),
                             with: petsciiName(diskName, length: 16))
        data.replaceSubrange((bamOffset + 0xa2)..<(bamOffset + 0xa4),
                             with: petsciiName(diskID, length: 2))
        data[bamOffset + 0xa5] = UInt8(ascii: "2")
        data[bamOffset + 0xa6] = UInt8(ascii: "A")

        let directoryOffset = offset(track: 18, sector: 1)
        data[directoryOffset] = 0
        data[directoryOffset + 1] = 0xff

        return data
    }

    private func waitForBasicDirectoryLoad(session: MacVICEEngineSession,
                                           diskTitle: String,
                                           timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        let titleBytes = Array(diskTitle.uppercased().utf8)

        while Date() < deadline {
            if let bytes = try? session.debugger.peek(address: 0x0801, length: 512),
               containsBytes(titleBytes, in: Array(bytes)) {
                return true
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.1))
        }

        return false
    }

    private func containsBytes(_ needle: [UInt8], in haystack: [UInt8]) -> Bool {
        guard !needle.isEmpty,
              haystack.count >= needle.count else {
            return false
        }

        for index in 0...(haystack.count - needle.count) {
            if Array(haystack[index..<(index + needle.count)]) == needle {
                return true
            }
        }

        return false
    }

    private func repositoryRoot() -> URL? {
        var url = URL(fileURLWithPath: #filePath)
        while url.path != "/" {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: url.appendingPathComponent("vice", isDirectory: true).path),
               fileManager.fileExists(atPath: url.appendingPathComponent("MacVICEKit", isDirectory: true).path) {
                return url
            }
            url.deleteLastPathComponent()
        }
        return nil
    }

    private func packageRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func packageSourceText(_ relativePath: String) throws -> String {
        try String(contentsOf: packageRoot().appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func repositorySourceText(_ relativePath: String) throws -> String {
        guard let root = repositoryRoot() else {
            throw XCTSkip("Source checkout unavailable; this test requires the full MacVICE repository.")
        }
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private func createRuntimeDirectory(for machines: MacVICEMachine...) throws -> URL {
        let runtimeURL = try createRuntimeDirectory()
        for machine in machines {
            try Data().write(to: runtimeURL.appendingPathComponent(machine.dynamicLibraryName))
        }
        return runtimeURL
    }

    private func createRuntimeFrameworkBundle(for machines: MacVICEMachine...) throws -> URL {
        try createRuntimeFrameworkBundle(for: machines, runtimeDirectoryName: "Frameworks")
    }

    private func createRuntimeFrameworkBundle(for machines: [MacVICEMachine],
                                              runtimeDirectoryName: String?,
                                              includeDataDirectory: Bool = true) throws -> URL {
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacVICERuntime-\(UUID().uuidString).framework", isDirectory: true)
        let resourcesURL = bundleURL.appendingPathComponent("Resources", isDirectory: true)
        let runtimeURL: URL?
        switch runtimeDirectoryName {
        case "Frameworks":
            runtimeURL = bundleURL.appendingPathComponent("Frameworks", isDirectory: true)
        case .some(let name):
            runtimeURL = resourcesURL.appendingPathComponent(name, isDirectory: true)
        case .none:
            runtimeURL = nil
        }

        if let runtimeURL {
            try FileManager.default.createDirectory(at: runtimeURL, withIntermediateDirectories: true)
        }
        if includeDataDirectory {
            try FileManager.default.createDirectory(at: resourcesURL.appendingPathComponent("VICEData", isDirectory: true),
                                                    withIntermediateDirectories: true)
        } else {
            try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
        }
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.barrywalker.MacVICERuntime.tests</string>
            <key>CFBundlePackageType</key>
            <string>FMWK</string>
        </dict>
        </plist>
        """
        try plist.data(using: .utf8)?.write(to: resourcesURL.appendingPathComponent("Info.plist"))
        try plist.data(using: .utf8)?.write(to: bundleURL.appendingPathComponent("Info.plist"))

        for machine in machines {
            guard let runtimeURL else { continue }
            try Data().write(to: runtimeURL.appendingPathComponent(machine.dynamicLibraryName))
        }

        addTeardownBlock { try? FileManager.default.removeItem(at: bundleURL) }
        return bundleURL
    }

    private func createApplicationBundleWithRuntimeFramework(for machines: MacVICEMachine...) throws -> URL {
        let appURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacVICEKitConsumer-\(UUID().uuidString).app", isDirectory: true)
        let contentsURL = appURL.appendingPathComponent("Contents", isDirectory: true)
        let frameworksURL = contentsURL.appendingPathComponent("Frameworks", isDirectory: true)
        let resourcesURL = contentsURL.appendingPathComponent("Resources", isDirectory: true)
        let runtimeFrameworkURL = frameworksURL.appendingPathComponent(MacVICERuntime.frameworkName, isDirectory: true)

        try FileManager.default.createDirectory(at: frameworksURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: resourcesURL, withIntermediateDirectories: true)
        let frameworkURL = try createRuntimeFrameworkBundle(for: Array(machines), runtimeDirectoryName: "Frameworks")
        try FileManager.default.copyItem(at: frameworkURL, to: runtimeFrameworkURL)

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>CFBundleIdentifier</key>
            <string>com.barrywalker.MacVICEKitConsumer.tests</string>
            <key>CFBundlePackageType</key>
            <string>APPL</string>
        </dict>
        </plist>
        """
        try XCTUnwrap(plist.data(using: .utf8)).write(to: contentsURL.appendingPathComponent("Info.plist"))

        addTeardownBlock { try? FileManager.default.removeItem(at: appURL) }
        return appURL
    }

    private func createRuntimeDirectory() throws -> URL {
        let runtimeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macvice-runtime-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: runtimeURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: runtimeURL.appendingPathComponent("VICEData", isDirectory: true),
                                                withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: runtimeURL) }
        return runtimeURL
    }

    private func standardizedPath(_ url: URL) -> String {
        url.standardizedFileURL.path
    }
}

private extension Array where Element == String {
    func value(after option: String) -> String? {
        guard let index = firstIndex(of: option),
              indices.contains(index + 1) else {
            return nil
        }

        return self[index + 1]
    }
}
