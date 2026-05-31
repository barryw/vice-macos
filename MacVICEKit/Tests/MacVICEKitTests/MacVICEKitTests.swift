import ImageIO
import XCTest
@testable import MacVICEKit

final class MacVICEKitTests: XCTestCase {
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
