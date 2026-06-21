import AppKit
import CoreGraphics
import CoreText
import Darwin
import Foundation
import FoundationModels
import MacVICEKit
@preconcurrency import Network
import XCTest
import zlib

final class ModelConfigurationTests: XCTestCase {
    func testAIAssistantFeatureFlagIsPaused() {
        XCTAssertFalse(VMCFeatureFlags.aiAssistant)
    }

    @MainActor
    func testAIAssistantSettingsAreRuntimeDisabledWhenFeatureIsPaused() {
        let settings = AIAssistantSettings()

        XCTAssertFalse(settings.isEnabled)
        XCTAssertFalse(settings.isConfigured)
        XCTAssertEqual(settings.assistantSummary, "Disabled")
        XCTAssertTrue(settings.remoteCredentialProviders.isEmpty)
    }

    func testSettingsPaneCatalogHidesAIAssistantWhenFeatureIsPaused() {
        let panes = SettingsPaneCatalog.availablePanes(showsControlSettings: true,
                                                       showsNetworkSettings: true,
                                                       aiAssistantEnabled: false)

        XCTAssertFalse(panes.contains(.ai))
        XCTAssertTrue(panes.contains(.machine))
        XCTAssertTrue(panes.contains(.display))
    }

    func testSettingsPaneCatalogIncludesOptionalPanesWhenSupported() {
        let panes = SettingsPaneCatalog.availablePanes(showsControlSettings: true,
                                                       showsNetworkSettings: true,
                                                       aiAssistantEnabled: true)

        XCTAssertTrue(panes.contains(.controls))
        XCTAssertTrue(panes.contains(.network))
        XCTAssertTrue(panes.contains(.ai))
    }

    func testSettingsPaneCatalogHidesUnavailableMachinePanes() {
        let panes = SettingsPaneCatalog.availablePanes(showsControlSettings: false,
                                                       showsNetworkSettings: false,
                                                       aiAssistantEnabled: false)

        XCTAssertFalse(panes.contains(.controls))
        XCTAssertFalse(panes.contains(.network))
        XCTAssertFalse(panes.contains(.ai))
        XCTAssertTrue(panes.contains(.keyboard))
        XCTAssertTrue(panes.contains(.media))
    }

    func testSettingsPaneCatalogNormalizesUnavailableSelections() {
        XCTAssertEqual(
            SettingsPaneCatalog.normalizedSelection(for: SettingsPaneID.controls.rawValue,
                                                    showsControlSettings: false,
                                                    showsNetworkSettings: true,
                                                    aiAssistantEnabled: false),
            .keyboard
        )
        XCTAssertEqual(
            SettingsPaneCatalog.normalizedSelection(for: SettingsPaneID.network.rawValue,
                                                    showsControlSettings: true,
                                                    showsNetworkSettings: false,
                                                    aiAssistantEnabled: false),
            .media
        )
        XCTAssertEqual(
            SettingsPaneCatalog.normalizedSelection(for: SettingsPaneID.ai.rawValue,
                                                    showsControlSettings: true,
                                                    showsNetworkSettings: true,
                                                    aiAssistantEnabled: false),
            .machine
        )
        XCTAssertEqual(
            SettingsPaneCatalog.normalizedSelection(for: "missing",
                                                    showsControlSettings: true,
                                                    showsNetworkSettings: true,
                                                    aiAssistantEnabled: false),
            .machine
        )
    }

    func testSettingsSharedControlsOwnReusableSlidersAndPortField() throws {
        let commonSource = try sourceText(at: "macos/ViceMac/Settings/SettingsCommonUI.swift")
        let settingsSource = try sourceText(at: "macos/ViceMac/Settings/SettingsView.swift")

        XCTAssertTrue(commonSource.contains("struct SettingsSliderControl"))
        XCTAssertTrue(commonSource.contains("struct SettingsPercentSlider"))
        XCTAssertTrue(commonSource.contains("struct SettingsPortField"))
        XCTAssertTrue(commonSource.contains("struct SettingsPane<Content: View>"))
        XCTAssertTrue(commonSource.contains("format: .number.grouping(.never)"))
        XCTAssertFalse(settingsSource.contains("private struct SettingsSliderControl"))
        XCTAssertFalse(settingsSource.contains("private struct SettingsPercentSlider"))
        XCTAssertFalse(settingsSource.contains("private func portControl"))
        XCTAssertFalse(settingsSource.contains("private struct SettingsPane<Content: View>"))
    }

    func testNetworkSettingsUseSharedPortFieldForDialAndIncomingPorts() throws {
        let settingsSource = try sourceText(at: "macos/ViceMac/Settings/SettingsView.swift")

        XCTAssertEqual(settingsSource.components(separatedBy: "SettingsPortField(").count - 1, 2)
        XCTAssertFalse(settingsSource.contains("TextField(\"Port\","))
        XCTAssertFalse(settingsSource.contains("Stepper(\"Port\""))
    }

    func testViceMacXcodeProjectPinsSwift6AndStrictConcurrency() throws {
        let projectSource = try sourceText(at: "macos/ViceMac.xcodeproj/project.pbxproj")
        let swiftVersions = try buildSettingValues(named: "SWIFT_VERSION", in: projectSource)
        let strictConcurrencyModes = try buildSettingValues(named: "SWIFT_STRICT_CONCURRENCY", in: projectSource)

        XCTAssertFalse(swiftVersions.isEmpty)
        XCTAssertTrue(swiftVersions.allSatisfy { $0 == "6.0" })
        XCTAssertFalse(strictConcurrencyModes.isEmpty)
        XCTAssertTrue(strictConcurrencyModes.allSatisfy { $0 == "complete" })
    }

    func testTerminationPolicyTerminatesImmediatelyWhenEngineIsStopped() {
        var policy = ViceMacTerminationPolicy()
        var didRequestEngineQuit = false

        let decision = policy.decision(isEngineRunning: false) {
            didRequestEngineQuit = true
            return true
        }

        XCTAssertEqual(decision, .terminateNow)
        XCTAssertFalse(didRequestEngineQuit)
    }

    func testTerminationPolicyRequestsEngineQuitOnceWhenEngineIsRunning() {
        var policy = ViceMacTerminationPolicy()
        var requestCount = 0

        let firstDecision = policy.decision(isEngineRunning: true) {
            requestCount += 1
            return true
        }
        let secondDecision = policy.decision(isEngineRunning: true) {
            requestCount += 1
            return true
        }

        XCTAssertEqual(firstDecision, .requestEngineQuitAndWait)
        XCTAssertEqual(secondDecision, .keepWaitingForEngineQuit)
        XCTAssertEqual(requestCount, 1)
    }

    func testTerminationPolicyFallsBackToNormalTerminationWhenQuitCannotBeQueued() {
        var policy = ViceMacTerminationPolicy()

        let decision = policy.decision(isEngineRunning: true) {
            false
        }

        XCTAssertEqual(decision, .terminateNow)
    }

    @MainActor
    func testAIDocumentLibraryImportsSearchablePDFAndReturnsContext() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViceMacAIDocumentLibraryTests-\(UUID().uuidString)", isDirectory: true)
        let pdfURL = rootURL.appendingPathComponent("Mapping Test.pdf")
        try FileManager.default.createDirectory(at: rootURL,
                                                withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let pdfText = """
        C64 SID volume and filter control are mapped near $D418. The low nybble of $D418 controls volume from 0 to 15.
        A BASIC program can use POKE 54296,15 to set the SID volume to the maximum value before playing sound.
        This test text is intentionally long enough to pass the searchable PDF threshold without relying on OCR.
        """
        try writeSearchablePDF(text: pdfText, to: pdfURL)

        let store = AIDocumentLibraryStore(rootURL: rootURL.appendingPathComponent("Library", isDirectory: true))
        let imported = await store.importPDFs([pdfURL],
                                              machineID: MachineID.x64sc.rawValue)

        XCTAssertEqual(imported.count, 1)
        XCTAssertEqual(store.documents(for: MachineID.x64sc.rawValue).first?.status, .indexed)

        let matches = try store.search(machineID: MachineID.x64sc.rawValue,
                                       query: "SID volume D418",
                                       limit: 5)
        XCTAssertFalse(matches.isEmpty)

        let context = try XCTUnwrap(store.context(machineID: MachineID.x64sc.rawValue,
                                                  chunkID: matches[0].chunkID,
                                                  before: 0,
                                                  after: 0))
        XCTAssertTrue(context.chunks.map(\.text).joined(separator: " ").contains("$D418"))
    }

    func testDriveConfigurationDecodesLegacyValues() throws {
        let json = """
        {
          "unit": 8,
          "isAttached": true,
          "driveType": 1541
        }
        """.data(using: .utf8)!

        let configuration = try JSONDecoder().decode(DriveConfiguration.self, from: json)

        XCTAssertEqual(configuration.accessMode, .native)
        XCTAssertEqual(configuration.storageKind, .diskImage)
        XCTAssertNil(configuration.sharedFolderPath)
        XCTAssertTrue(configuration.protectsInsertedDisks)
        XCTAssertFalse(configuration.soundEnabled)
        XCTAssertEqual(configuration.soundVolume, 25)
    }

    func testDriveConfigurationDecodesLegacyHardDriveTypeAsHardDriveImage() throws {
        let json = """
        {
          "unit": 8,
          "isAttached": true,
          "driveType": 4844
        }
        """.data(using: .utf8)!

        let configuration = try JSONDecoder().decode(DriveConfiguration.self, from: json)

        XCTAssertEqual(configuration.storageKind, .hardDriveImage)
        XCTAssertEqual(configuration.driveType, .cmdHD)
    }

    func testDriveConfigurationMigratesVICEVolumeToPercent() throws {
        let json = """
        {
          "unit": 8,
          "isAttached": true,
          "driveType": 1541,
          "accessMode": "native",
          "soundEnabled": true,
          "soundVolume": 2000
        }
        """.data(using: .utf8)!

        let configuration = try JSONDecoder().decode(DriveConfiguration.self, from: json)

        XCTAssertEqual(configuration.soundVolume, 50)
        XCTAssertEqual(configuration.viceSoundVolume, 2000)
    }

    func testDriveConfigurationClampsPercentVolume() {
        let configuration = DriveConfiguration(unit: 8,
                                               isAttached: true,
                                               driveType: .c1541,
                                               soundEnabled: true,
                                               soundVolume: 250)

        XCTAssertEqual(configuration.soundVolume, 100)
        XCTAssertEqual(configuration.viceSoundVolume, 4000)
    }

    func testROMImageConfigurationDecodesLegacyC64Slots() throws {
        let json = """
        {
          "basicPath": "/roms/basic.rom",
          "kernalPath": "/roms/kernal.rom",
          "characterPath": "/roms/chargen.rom"
        }
        """.data(using: .utf8)!

        let configuration = try JSONDecoder().decode(ROMImageConfiguration.self, from: json)

        XCTAssertEqual(configuration.path(for: .c64Basic), "/roms/basic.rom")
        XCTAssertEqual(configuration.path(for: .c64Kernal), "/roms/kernal.rom")
        XCTAssertEqual(configuration.path(for: .c64Character), "/roms/chargen.rom")
    }

    func testC128StartupArgumentsRestore80ColumnOutput() {
        let machine = EmulatedMachine.x128
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                     displayOutput: .c12880Column))

        XCTAssertEqual(arguments.value(after: "-model"), "ntsc")
        XCTAssertTrue(arguments.contains("-80col"))
        XCTAssertFalse(arguments.contains("-40col"))
    }

    func testC64StartupArgumentsUseSelectedModelVariant() {
        let machine = EmulatedMachine.x64sc
        let cases: [(C64MachineModel, EmulatorSession.VideoStandard, String)] = [
            (.c64, .pal, "c64"),
            (.c64, .ntsc, "c64ntsc"),
            (.c64c, .pal, "c64c"),
            (.c64c, .ntsc, "c64cntsc"),
            (.earlyC64, .pal, "c64old"),
            (.earlyC64, .ntsc, "c64oldntsc"),
            (.sx64, .pal, "sx64pal"),
            (.sx64, .ntsc, "sx64ntsc")
        ]

        for (model, standard, viceModelName) in cases {
            let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                         machineModel: .x64sc(model),
                                                                                         videoStandard: standard))

            XCTAssertEqual(arguments.value(after: "-model"), viceModelName)
        }
    }

    func testC128StartupArgumentsUseSelectedModelVariant() {
        let machine = EmulatedMachine.x128
        let cases: [(C128MachineModel, EmulatorSession.VideoStandard, String)] = [
            (.c128, .pal, "pal"),
            (.c128, .ntsc, "ntsc"),
            (.c128d, .pal, "c128dpal"),
            (.c128d, .ntsc, "c128dntsc"),
            (.c128dcr, .pal, "c128dcr"),
            (.c128dcr, .ntsc, "c128dcrntsc")
        ]

        for (model, standard, viceModelName) in cases {
            let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                         machineModel: .x128(model),
                                                                                         videoStandard: standard))

            XCTAssertEqual(arguments.value(after: "-model"), viceModelName)
        }
    }

    func testC64ModelVariantsUseMatchingDefaultKernals() {
        let machine = EmulatedMachine.x64sc

        XCTAssertEqual(
            machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                         machineModel: .x64sc(.earlyC64),
                                                                         videoStandard: .pal))
                .value(after: "-kernal"),
            "kernal-901227-02.bin"
        )
        XCTAssertEqual(
            machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                         machineModel: .x64sc(.earlyC64),
                                                                         videoStandard: .ntsc))
                .value(after: "-kernal"),
            "kernal-901227-01.bin"
        )
        XCTAssertEqual(
            machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                         machineModel: .x64sc(.sx64)))
                .value(after: "-kernal"),
            "kernal-251104-04.bin"
        )
    }

    func testVIC20StartupArgumentsIncludeSelectedMemory() {
        let machine = EmulatedMachine.xvic
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                     ramExpansion: .vic20_24k))

        XCTAssertEqual(arguments.value(after: "-memory"), "24k")
    }

    func testPETStartupArgumentsUseSelectedModelVariant() {
        let machine = EmulatedMachine.xpet

        XCTAssertEqual(machine.family, .pet)
        XCTAssertEqual(machine.viceTarget, "xpet")

        for model in PETMachineModel.allCases {
            let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                         machineModel: .xpet(model)))

            XCTAssertEqual(arguments.value(after: "-model"), model.viceModelName)
        }
    }

    func testPETModelVariantsUseMatchingDefaultROMs() {
        let machine = EmulatedMachine.xpet
        let cases: [(PETMachineModel, String, String, String, String)] = [
            (.model2001,
             "basic-1.901439-09-05-02-06.bin",
             "kernal-1.901439-04-07.bin",
             "edit-1-n.901439-03.bin",
             "characters-1.901447-08.bin"),
            (.model3032B,
             "basic-2.901465-01-02.bin",
             "kernal-2.901465-03.bin",
             "edit-2-b.901474-01.bin",
             "characters-2.901447-10.bin"),
            (.model4032B,
             "basic-4.901465-23-20-21.bin",
             "kernal-4.901465-22.bin",
             "edit-4-40-b-50Hz.ts.bin",
             "characters-2.901447-10.bin"),
            (.model8032,
             "basic-4.901465-23-20-21.bin",
             "kernal-4.901465-22.bin",
             "edit-4-80-b-50Hz.901474-04_.bin",
             "characters-2.901447-10.bin"),
            (.superPET,
             "basic-4.901465-23-20-21.bin",
             "kernal-4.901465-22.bin",
             "edit-4-80-b-50Hz.901474-04_.bin",
             "characters.901640-01.bin")
        ]

        for (model, basic, kernal, editor, chargen) in cases {
            let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                         machineModel: .xpet(model)))

            XCTAssertEqual(arguments.value(after: "-basic"), basic)
            XCTAssertEqual(arguments.value(after: "-kernal"), kernal)
            XCTAssertEqual(arguments.value(after: "-editor"), editor)
            XCTAssertEqual(arguments.value(after: "-chargen"), chargen)
        }
    }

    func testTEDStartupArgumentsUseSelectedModelVariant() {
        let plus4 = EmulatedMachine.xplus4
        let c16 = EmulatedMachine.xc16
        let c232 = EmulatedMachine.xc232
        let v364 = EmulatedMachine.xv364
        let plus4Arguments = plus4.startupArguments(configuration: startupConfiguration(for: plus4))
        let c16Arguments = c16.startupArguments(configuration: startupConfiguration(for: c16))
        let c232Arguments = c232.startupArguments(configuration: startupConfiguration(for: c232,
                                                                                      videoStandard: .pal))
        let v364Arguments = v364.startupArguments(configuration: startupConfiguration(for: v364,
                                                                                      videoStandard: .pal))

        XCTAssertEqual(plus4.family, .ted)
        XCTAssertEqual(c16.family, .ted)
        XCTAssertEqual(c16.viceTarget, plus4.viceTarget)
        XCTAssertEqual(c232.viceTarget, plus4.viceTarget)
        XCTAssertEqual(v364.viceTarget, plus4.viceTarget)
        XCTAssertEqual(c16.dynamicLibraryName, plus4.dynamicLibraryName)
        XCTAssertEqual(c232.dynamicLibraryName, plus4.dynamicLibraryName)
        XCTAssertEqual(v364.dynamicLibraryName, plus4.dynamicLibraryName)
        XCTAssertEqual(plus4Arguments.value(after: "-model"), "plus4ntsc")
        XCTAssertEqual(c16Arguments.value(after: "-model"), "c16ntsc")
        XCTAssertEqual(c232Arguments.value(after: "-model"), "c232")
        XCTAssertEqual(v364Arguments.value(after: "-model"), "v364")
        XCTAssertTrue(c16Arguments.contains("-TEDborders"))
        XCTAssertTrue(c232Arguments.contains("-TEDborders"))
        XCTAssertTrue(v364Arguments.contains("-TEDborders"))
    }

    func testTEDMachinesSupportRuntimeVideoButKeepROMChangesInStartupArguments() {
        let machine = EmulatedMachine.xplus4

        XCTAssertTrue(machine.supportsRuntimeVideoStandardUpdates)
        XCTAssertFalse(machine.supportsRuntimeROMImageUpdates)
    }

    func testTEDRuntimeVideoChangesUseModelNames() {
        XCTAssertEqual(MachineModel.ted(.plus4).viceModelName(for: .pal), "plus4pal")
        XCTAssertEqual(MachineModel.ted(.plus4).viceModelName(for: .ntsc), "plus4ntsc")
        XCTAssertEqual(MachineModel.ted(.c16).viceModelName(for: .pal), "c16pal")
        XCTAssertEqual(MachineModel.ted(.c16).viceModelName(for: .ntsc), "c16ntsc")
    }

    func testTEDPrototypeModelsAreNTSConly() {
        XCTAssertTrue(EmulatedMachine.xplus4.capabilities.supportsVideoStandardSelection)
        XCTAssertTrue(EmulatedMachine.xc16.capabilities.supportsVideoStandardSelection)
        XCTAssertFalse(EmulatedMachine.xc232.capabilities.supportsVideoStandardSelection)
        XCTAssertFalse(EmulatedMachine.xv364.capabilities.supportsVideoStandardSelection)
    }

    func testSystemTimeSyncStartupArgumentsUseDS1307RTC() {
        let machine = EmulatedMachine.x128
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                     syncSystemTime: true))

        XCTAssertTrue(arguments.contains("+userportrtcds1307save"))
        XCTAssertEqual(arguments.value(after: "-userportdevice"), "ds1307")
    }

    func testUserPortModemStartupArgumentsDisableRTCUserPortConflict() {
        let machine = EmulatedMachine.x64sc
        let modem = NetworkModemConfiguration(isEnabled: true,
                                              interface: .userPort,
                                              baudRate: 2400,
                                              transportMode: .telnet,
                                              acceptsIncomingCalls: true,
                                              incomingPort: 6400,
                                              autoAnswerRings: 0,
                                              echoCommands: true,
                                              verboseResultCodes: true,
                                              defaultDialPort: 23)
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                     syncSystemTime: true,
                                                                                     networkModem: modem,
                                                                                     networkLocalPort: 25232))

        XCTAssertEqual(arguments.value(after: "-rsdev3"), "127.0.0.1:25232")
        XCTAssertTrue(arguments.contains("+rsdev3ip232"))
        XCTAssertFalse(arguments.contains("-rsdev3ip232"))
        XCTAssertEqual(arguments.value(after: "-userportdevice"), "modem")
        XCTAssertEqual(arguments.value(after: "-rsuserdev"), "2")
        XCTAssertEqual(arguments.value(after: "-rsuserbaud"), "2400")
        XCTAssertFalse(arguments.contains("+userportrtcds1307save"))
        XCTAssertFalse(arguments.contains("ds1307"))
    }

    func testSwiftLinkModemStartupArgumentsPreserveRTC() {
        let machine = EmulatedMachine.x128
        let modem = NetworkModemConfiguration(isEnabled: true,
                                              interface: .swiftLink,
                                              baudRate: 9600,
                                              transportMode: .telnet,
                                              acceptsIncomingCalls: false,
                                              incomingPort: 6400,
                                              autoAnswerRings: 0,
                                              echoCommands: true,
                                              verboseResultCodes: true,
                                              defaultDialPort: 23)
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                     syncSystemTime: true,
                                                                                     networkModem: modem,
                                                                                     networkLocalPort: 25232))

        XCTAssertEqual(arguments.value(after: "-rsdev3"), "127.0.0.1:25232")
        XCTAssertTrue(arguments.contains("-rsdev3ip232"))
        XCTAssertTrue(arguments.contains("-acia1"))
        XCTAssertEqual(arguments.value(after: "-myaciadev"), "2")
        XCTAssertEqual(arguments.value(after: "-acia1mode"), "1")
        XCTAssertEqual(arguments.value(after: "-acia1base"), "\(0xde00)")
        XCTAssertTrue(arguments.contains("+userportrtcds1307save"))
        XCTAssertEqual(arguments.value(after: "-userportdevice"), "ds1307")
    }

    func testTurbo232ModemStartupArgumentsUseTurboACIAMode() {
        let machine = EmulatedMachine.xvic
        let modem = NetworkModemConfiguration(isEnabled: true,
                                              interface: .turbo232,
                                              baudRate: 38400,
                                              transportMode: .telnet,
                                              acceptsIncomingCalls: false,
                                              incomingPort: 6400,
                                              autoAnswerRings: 0,
                                              echoCommands: true,
                                              verboseResultCodes: true,
                                              defaultDialPort: 23)
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                     networkModem: modem,
                                                                                     networkLocalPort: 25232))

        XCTAssertTrue(arguments.contains("-acia1"))
        XCTAssertEqual(arguments.value(after: "-myaciadev"), "2")
        XCTAssertEqual(arguments.value(after: "-acia1mode"), "2")
        XCTAssertEqual(arguments.value(after: "-acia1base"), "\(0x9800)")
    }

    func testACIAModemStartupArgumentsUseSelectedBaseAddress() {
        let machine = EmulatedMachine.x128
        let modem = NetworkModemConfiguration(isEnabled: true,
                                              interface: .swiftLink,
                                              baudRate: 9600,
                                              transportMode: .telnet,
                                              acceptsIncomingCalls: false,
                                              incomingPort: 6400,
                                              autoAnswerRings: 0,
                                              echoCommands: true,
                                              verboseResultCodes: true,
                                              defaultDialPort: 23,
                                              aciaBaseAddress: .d700)
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                     networkModem: modem,
                                                                                     networkLocalPort: 25232))

        XCTAssertEqual(arguments.value(after: "-acia1base"), "\(0xd700)")
    }

    func testACIAModemAddressNormalizesToMachineSupportedAddress() {
        let machine = EmulatedMachine.x64sc
        let modem = NetworkModemConfiguration(isEnabled: true,
                                              interface: .turbo232,
                                              baudRate: 38400,
                                              transportMode: .raw,
                                              acceptsIncomingCalls: false,
                                              incomingPort: 6400,
                                              autoAnswerRings: 0,
                                              echoCommands: true,
                                              verboseResultCodes: true,
                                              defaultDialPort: 23,
                                              aciaBaseAddress: .d700)
        let normalizedModem = modem.normalized(for: machine)
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                     networkModem: modem,
                                                                                     networkLocalPort: 25232))

        XCTAssertEqual(normalizedModem.aciaBaseAddress, .de00)
        XCTAssertEqual(arguments.value(after: "-acia1base"), "\(0xde00)")
    }

    func testACIAModemBaudRateCapsAt38400() {
        let swiftLinkModem = NetworkModemConfiguration(isEnabled: true,
                                                       interface: .swiftLink,
                                                       baudRate: 57600,
                                                       transportMode: .raw,
                                                       acceptsIncomingCalls: false,
                                                       incomingPort: 6400,
                                                       autoAnswerRings: 0,
                                                       echoCommands: true,
                                                       verboseResultCodes: true,
                                                       defaultDialPort: 23)
        let turbo232Modem = NetworkModemConfiguration(isEnabled: true,
                                                      interface: .turbo232,
                                                      baudRate: 57600,
                                                      transportMode: .raw,
                                                      acceptsIncomingCalls: false,
                                                      incomingPort: 6400,
                                                      autoAnswerRings: 0,
                                                      echoCommands: true,
                                                      verboseResultCodes: true,
                                                      defaultDialPort: 23)

        XCTAssertEqual(swiftLinkModem.supportedBaudRates, [300, 1200, 2400, 9600, 19200, 38400])
        XCTAssertEqual(swiftLinkModem.baudRate, 38400)
        XCTAssertEqual(turbo232Modem.supportedBaudRates, [300, 1200, 2400, 9600, 19200, 38400])
        XCTAssertEqual(turbo232Modem.baudRate, 38400)
    }

    func testUserPortModemBaudRateCapsAt2400() {
        let modem = NetworkModemConfiguration(isEnabled: true,
                                              interface: .userPort,
                                              baudRate: 57600,
                                              transportMode: .raw,
                                              acceptsIncomingCalls: false,
                                              incomingPort: 6400,
                                              autoAnswerRings: 0,
                                              echoCommands: true,
                                              verboseResultCodes: true,
                                              defaultDialPort: 23)

        XCTAssertEqual(modem.supportedBaudRates, [300, 1200, 2400])
        XCTAssertEqual(modem.baudRate, 2400)
    }

    func testNetworkModemConfigurationFallsBackForInvalidPersistedPorts() {
        let modem = NetworkModemConfiguration(isEnabled: true,
                                              interface: .swiftLink,
                                              baudRate: 9600,
                                              transportMode: .raw,
                                              acceptsIncomingCalls: true,
                                              incomingPort: 0,
                                              autoAnswerRings: 0,
                                              echoCommands: true,
                                              verboseResultCodes: true,
                                              defaultDialPort: 70_000)

        XCTAssertEqual(modem.incomingPort, 6400)
        XCTAssertEqual(modem.defaultDialPort, 23)
    }

    func testNetworkModemConfigurationClampsInteractiveTCPPorts() {
        XCTAssertEqual(NetworkModemConfiguration.clampedTCPPort(-1), 1)
        XCTAssertEqual(NetworkModemConfiguration.clampedTCPPort(5190), 5190)
        XCTAssertEqual(NetworkModemConfiguration.clampedTCPPort(70_000), 65_535)
    }

    func testNetworkSettingsPresentationChoosesDialingSectionTitle() {
        XCTAssertEqual(NetworkSettingsPresentation.dialingSectionTitle(supportsQLinkReloaded: false),
                       "Dialing")
        XCTAssertEqual(NetworkSettingsPresentation.dialingSectionTitle(supportsQLinkReloaded: true),
                       "Q-Link Reloaded")
    }

    func testNetworkSettingsPresentationFormatsAutoAnswerOptions() {
        XCTAssertEqual(NetworkSettingsPresentation.autoAnswerOptionTitle(for: 0), "Off")
        XCTAssertEqual(NetworkSettingsPresentation.autoAnswerOptionTitle(for: 1), "After 1 ring")
        XCTAssertEqual(NetworkSettingsPresentation.autoAnswerOptionTitle(for: 2), "After 2 rings")
        XCTAssertEqual(NetworkSettingsPresentation.autoAnswerOptionTitle(for: 9), "After 9 rings")
    }

    func testNetworkSettingsPresentationFormatsQLinkDiskTitle() {
        XCTAssertEqual(NetworkSettingsPresentation.qLinkDiskTitle(configuredDiskTitle: nil,
                                                                  configuredDiskVersionTitle: nil),
                       "No disk selected")
        XCTAssertEqual(NetworkSettingsPresentation.qLinkDiskTitle(configuredDiskTitle: "QuantumLink",
                                                                  configuredDiskVersionTitle: nil),
                       "QuantumLink")
        XCTAssertEqual(NetworkSettingsPresentation.qLinkDiskTitle(configuredDiskTitle: "QuantumLink",
                                                                  configuredDiskVersionTitle: "Q-Link Version 4"),
                       "QuantumLink (Q-Link Version 4)")
    }

    func testNetworkSettingsPresentationFormatsQLinkProfileSummary() {
        XCTAssertEqual(NetworkSettingsPresentation.qLinkProfileSummary(diskProfileCount: 0,
                                                                       keychainProfileCount: 0),
                       "0 on disk, 0 in Keychain")
        XCTAssertEqual(NetworkSettingsPresentation.qLinkProfileSummary(diskProfileCount: 2,
                                                                       keychainProfileCount: 1),
                       "2 on disk, 1 in Keychain")
    }

    func testQLinkProfileManagerPresentationFormatsDiskTitle() {
        XCTAssertEqual(QLinkProfileManagerPresentation.diskTitle(configuredDiskTitle: nil,
                                                                 configuredDiskVersionTitle: nil),
                       "No Q-Link disk selected")
        XCTAssertEqual(QLinkProfileManagerPresentation.diskTitle(configuredDiskTitle: "QuantumLink",
                                                                 configuredDiskVersionTitle: nil),
                       "QuantumLink")
        XCTAssertEqual(QLinkProfileManagerPresentation.diskTitle(configuredDiskTitle: "QuantumLink",
                                                                 configuredDiskVersionTitle: "Q-Link Version 4"),
                       "QuantumLink (Q-Link Version 4)")
    }

    func testQLinkProfileManagerPresentationFormatsEmptyDiskState() {
        XCTAssertEqual(QLinkProfileManagerPresentation.diskProfilesEmptyTitle(hasConfiguredDisk: false),
                       "No Q-Link Disk")
        XCTAssertEqual(QLinkProfileManagerPresentation.diskProfilesEmptyDescription(hasConfiguredDisk: false),
                       "Choose a validated Q-Link disk to manage its saved users.")

        XCTAssertEqual(QLinkProfileManagerPresentation.diskProfilesEmptyTitle(hasConfiguredDisk: true),
                       "No Profiles")
        XCTAssertEqual(QLinkProfileManagerPresentation.diskProfilesEmptyDescription(hasConfiguredDisk: true),
                       "This disk does not currently have saved Q-Link users.")
    }

    func testQLinkProfileManagerPresentationFormatsProfileCounts() {
        XCTAssertEqual(QLinkProfileManagerPresentation.diskProfileCapacityTitle(count: 2, maximum: 10),
                       "2/10")
        XCTAssertEqual(QLinkProfileManagerPresentation.keychainProfileCountTitle(count: 0),
                       "0 saved")
        XCTAssertEqual(QLinkProfileManagerPresentation.keychainProfileCountTitle(count: 1),
                       "1 saved")
        XCTAssertEqual(QLinkProfileManagerPresentation.keychainProfileCountTitle(count: 2),
                       "2 saved")
    }

    func testQLinkReloadedSupportAcceptsOnlyNetworkedC64AndC128Machines() {
        XCTAssertTrue(QLinkReloadedSupport.supports(machine: .x64sc))
        XCTAssertTrue(QLinkReloadedSupport.supports(machine: .x128))

        XCTAssertFalse(QLinkReloadedSupport.supports(machine: .xvic))
        XCTAssertFalse(QLinkReloadedSupport.supports(machine: .xpet))
        XCTAssertFalse(QLinkReloadedSupport.supports(machine: .xplus4))
        XCTAssertFalse(QLinkReloadedSupport.supports(machine: .xc16))
        XCTAssertFalse(QLinkReloadedSupport.supports(machine: .xc232))
        XCTAssertFalse(QLinkReloadedSupport.supports(machine: .xv364))
    }

    func testQLinkReloadedSupportRequiresSupportedMachineDiskAndIdleConnection() {
        XCTAssertTrue(QLinkReloadedSupport.canConnect(machine: .x64sc,
                                                      hasConfiguredDisk: true,
                                                      isConnecting: false))

        XCTAssertFalse(QLinkReloadedSupport.canConnect(machine: .x64sc,
                                                       hasConfiguredDisk: false,
                                                       isConnecting: false))
        XCTAssertFalse(QLinkReloadedSupport.canConnect(machine: .x64sc,
                                                       hasConfiguredDisk: true,
                                                       isConnecting: true))
        XCTAssertFalse(QLinkReloadedSupport.canConnect(machine: .xpet,
                                                       hasConfiguredDisk: true,
                                                       isConnecting: false))
    }

    func testQLinkReloadedProtocolProbeBuildsResetFrameForServerHandshake() {
        let frame = Array(QLinkReloadedProtocolProbe.resetFrame())

        XCTAssertEqual(frame.first, 0x5A)
        XCTAssertEqual(frame.last, 0x0D)
        XCTAssertEqual(frame[5], 0x7F)
        XCTAssertEqual(frame[6], 0x7F)
        XCTAssertEqual(frame[7], QLinkReloadedProtocolProbe.resetCommand)
        XCTAssertEqual(frame[8], 5)
        XCTAssertEqual(frame[9], 9)
        XCTAssertTrue(QLinkReloadedProtocolProbe.isValidFrame(frame))
    }

    func testQLinkReloadedProtocolProbeRecognizesResetAckFrame() {
        let ack = QLinkReloadedProtocolProbe.frame(command: QLinkReloadedProtocolProbe.resetAckCommand,
                                                   sendSequence: 0x7F,
                                                   receiveSequence: 0x7F,
                                                   payload: [])

        XCTAssertTrue(QLinkReloadedProtocolProbe.containsResetAck(in: Array(ack)))
        XCTAssertFalse(QLinkReloadedProtocolProbe.containsResetAck(in: Array(QLinkReloadedProtocolProbe.resetFrame())))
    }

    func testQLinkServerConnectionCheckerCompletesTextAndResetHandshake() async throws {
        let server = try QLinkValidationTestServer()
        addTeardownBlock {
            server.cancel()
        }
        server.start()

        let checker = QLinkReloadedServerConnectionChecker(timeout: 2)
        let result = await checker.validateQLinkServer(host: "127.0.0.1",
                                                       port: Int(server.port.rawValue))

        XCTAssertEqual(result, .success)
        XCTAssertTrue(server.didReceiveResetFrame)
    }

    func testQLinkServerConnectionCheckerRejectsInvalidPort() async {
        let checker = QLinkReloadedServerConnectionChecker(timeout: 2)

        let result = await checker.validateQLinkServer(host: "127.0.0.1",
                                                       port: 70_000)

        XCTAssertEqual(result, .failure("Port 70000 is not valid."))
    }

    func testQLinkConfigurationValidatorRejectsIncompatibleSettingsBeforeNetworkCheck() async {
        let checker = StubQLinkServerChecker(result: .success)
        let validator = QLinkReloadedConfigurationValidator(connectionChecker: checker)

        let outcome = await validator.validate(configuration: .standard,
                                               machine: .x64sc,
                                               storedProfileCount: 0)

        XCTAssertEqual(outcome, .failure("Current modem settings are not compatible with Q-Link Reloaded:\n- Modem is off\n- Connection is Telnet, not Raw TCP\n- Dial host is blank\n- CONNECT response includes baud rate"))
        XCTAssertFalse(checker.didValidate)
    }

    func testQLinkConfigurationValidatorReportsSuccessfulProtocolAndStoredProfiles() async {
        let checker = StubQLinkServerChecker(result: .success)
        let validator = QLinkReloadedConfigurationValidator(connectionChecker: checker)
        let configuration = QLinkReloadedModemRequirements.preset(preservingValuesFrom: .standard)

        let outcome = await validator.validate(configuration: configuration,
                                               machine: .x64sc,
                                               storedProfileCount: 2)

        XCTAssertEqual(outcome, .success("Server responded correctly. 2 stored profiles are available locally."))
        XCTAssertTrue(checker.didValidate)
        XCTAssertEqual(checker.validatedHost, QLinkReloadedModemRequirements.serverHost)
        XCTAssertEqual(checker.validatedPort, QLinkReloadedModemRequirements.serverPort)
    }

    func testQLinkConfigurationValidatorProbesConfiguredEndpointInsteadOfBlessedPort() async {
        let checker = StubQLinkServerChecker(result: .success)
        let validator = QLinkReloadedConfigurationValidator(connectionChecker: checker)
        let configuration = NetworkModemConfiguration(isEnabled: true,
                                                      interface: .userPort,
                                                      baudRate: 1200,
                                                      transportMode: .raw,
                                                      acceptsIncomingCalls: false,
                                                      incomingPort: 6400,
                                                      autoAnswerRings: 0,
                                                      echoCommands: true,
                                                      verboseResultCodes: true,
                                                      connectResultIncludesBaudRate: false,
                                                      defaultDialPort: 5191,
                                                      defaultDialHost: "q-link.net")

        let outcome = await validator.validate(configuration: configuration,
                                               machine: .x64sc,
                                               storedProfileCount: 1)

        XCTAssertEqual(outcome, .success("Server responded correctly. 1 stored profile is available locally."))
        XCTAssertTrue(checker.didValidate)
        XCTAssertEqual(checker.validatedHost, "q-link.net")
        XCTAssertEqual(checker.validatedPort, 5191)
    }

    func testQLinkConfigurationValidatorReportsServerFailure() async {
        let checker = StubQLinkServerChecker(result: .failure("Timed out waiting for Q-Link reset acknowledgment."))
        let validator = QLinkReloadedConfigurationValidator(connectionChecker: checker)
        let configuration = QLinkReloadedModemRequirements.preset(preservingValuesFrom: .standard)

        let outcome = await validator.validate(configuration: configuration,
                                               machine: .x64sc,
                                               storedProfileCount: 1)

        XCTAssertEqual(outcome, .failure("Timed out waiting for Q-Link reset acknowledgment."))
    }

    func testQLinkReloadedModemRequirementsAcceptPreset() {
        let modem = QLinkReloadedModemRequirements.preset(preservingValuesFrom: .standard)

        XCTAssertTrue(QLinkReloadedModemRequirements.isCompatible(modem, for: .x64sc))
        XCTAssertEqual(modem.interface, .swiftLink)
        XCTAssertEqual(modem.baudRate, 38400)
        XCTAssertEqual(modem.transportMode, .raw)
        XCTAssertEqual(modem.defaultDialHost, "q-link.net")
        XCTAssertEqual(modem.defaultDialPort, 5190)
        XCTAssertTrue(modem.verboseResultCodes)
        XCTAssertFalse(modem.connectResultIncludesBaudRate)
    }

    func testQLinkReloadedModemRequirementsAcceptSwiftLinkAndTurbo232() {
        let swiftLink = NetworkModemConfiguration(isEnabled: true,
                                                  interface: .swiftLink,
                                                  baudRate: 38400,
                                                  transportMode: .raw,
                                                  acceptsIncomingCalls: false,
                                                  incomingPort: 6400,
                                                  autoAnswerRings: 0,
                                                  echoCommands: true,
                                                  verboseResultCodes: true,
                                                  connectResultIncludesBaudRate: false,
                                                  defaultDialPort: 5190,
                                                  defaultDialHost: "q-link.net",
                                                  aciaBaseAddress: .de00)
        let turbo232 = NetworkModemConfiguration(isEnabled: true,
                                                 interface: .turbo232,
                                                 baudRate: 38400,
                                                 transportMode: .raw,
                                                 acceptsIncomingCalls: false,
                                                 incomingPort: 6400,
                                                 autoAnswerRings: 0,
                                                 echoCommands: true,
                                                 verboseResultCodes: true,
                                                 connectResultIncludesBaudRate: false,
                                                 defaultDialPort: 5190,
                                                 defaultDialHost: "q-link.net",
                                                 aciaBaseAddress: .de00)

        XCTAssertTrue(QLinkReloadedModemRequirements.isCompatible(swiftLink, for: .x64sc))
        XCTAssertTrue(QLinkReloadedModemRequirements.isCompatible(turbo232, for: .x64sc))
    }

    func testQLinkReloadedModemRequirementsAcceptLegacyUserPortWithoutBaudRestriction() {
        let modem = NetworkModemConfiguration(isEnabled: true,
                                              interface: .userPort,
                                              baudRate: 2400,
                                              transportMode: .raw,
                                              acceptsIncomingCalls: false,
                                              incomingPort: 6400,
                                              autoAnswerRings: 0,
                                              echoCommands: true,
                                              verboseResultCodes: true,
                                              connectResultIncludesBaudRate: false,
                                              defaultDialPort: 5190,
                                              defaultDialHost: "q-link.net")

        XCTAssertTrue(QLinkReloadedModemRequirements.isCompatible(modem, for: .x64sc))
    }

    func testQLinkReloadedModemPresetPrefersModernAciaInterface() {
        let modem = NetworkModemConfiguration(isEnabled: true,
                                              interface: .userPort,
                                              baudRate: 2400,
                                              transportMode: .telnet,
                                              acceptsIncomingCalls: false,
                                              incomingPort: 6400,
                                              autoAnswerRings: 0,
                                              echoCommands: true,
                                              verboseResultCodes: true,
                                              connectResultIncludesBaudRate: true,
                                              defaultDialPort: 23,
                                              defaultDialHost: "")

        let preset = QLinkReloadedModemRequirements.preset(preservingValuesFrom: modem)

        XCTAssertEqual(preset.interface, .swiftLink)
        XCTAssertEqual(preset.baudRate, 38400)
        XCTAssertTrue(QLinkReloadedModemRequirements.isCompatible(preset, for: .x64sc))
    }

    func testQLinkReloadedModemPresetPreservesModernAciaInterface() {
        var modem = NetworkModemConfiguration.standard
        modem.interface = .turbo232

        let preset = QLinkReloadedModemRequirements.preset(preservingValuesFrom: modem)

        XCTAssertEqual(preset.interface, .turbo232)
        XCTAssertEqual(preset.baudRate, 38400)
        XCTAssertEqual(preset.aciaBaseAddress, modem.aciaBaseAddress)
        XCTAssertTrue(QLinkReloadedModemRequirements.isCompatible(preset, for: .x64sc))
    }

    func testQLinkReloadedModemRequirementsRejectIncompatibleUserSettings() {
        let modem = NetworkModemConfiguration(isEnabled: true,
                                              interface: .swiftLink,
                                              baudRate: 9600,
                                              transportMode: .telnet,
                                              acceptsIncomingCalls: false,
                                              incomingPort: 6400,
                                              autoAnswerRings: 0,
                                              echoCommands: true,
                                              verboseResultCodes: false,
                                              defaultDialPort: 23,
                                              defaultDialHost: "bbs.example",
                                              aciaBaseAddress: .de00)

        let issues = QLinkReloadedModemRequirements.incompatibilities(in: modem, for: .x64sc)

        XCTAssertTrue(issues.contains("Connection is Telnet, not Raw TCP"))
        XCTAssertFalse(issues.contains { $0.contains(QLinkReloadedModemRequirements.serverHost) })
        XCTAssertFalse(issues.contains { $0.contains(String(QLinkReloadedModemRequirements.serverPort)) })
        XCTAssertTrue(issues.contains("Verbose result codes are off"))
        XCTAssertTrue(issues.contains("CONNECT response includes baud rate"))
        XCTAssertFalse(QLinkReloadedModemRequirements.isCompatible(modem, for: .x64sc))
    }

    func testQLinkReloadedModemRequirementsAllowCustomDialEndpoint() {
        let modem = NetworkModemConfiguration(isEnabled: true,
                                              interface: .userPort,
                                              baudRate: 1200,
                                              transportMode: .raw,
                                              acceptsIncomingCalls: false,
                                              incomingPort: 6400,
                                              autoAnswerRings: 0,
                                              echoCommands: true,
                                              verboseResultCodes: true,
                                              connectResultIncludesBaudRate: false,
                                              defaultDialPort: 5191,
                                              defaultDialHost: "q-link.net",
                                              aciaBaseAddress: .de00)

        XCTAssertTrue(QLinkReloadedModemRequirements.isCompatible(modem, for: .x64sc))
    }

    func testQLinkReloadedModemRequirementsRequireDialHost() {
        let modem = NetworkModemConfiguration(isEnabled: true,
                                              interface: .userPort,
                                              baudRate: 1200,
                                              transportMode: .raw,
                                              acceptsIncomingCalls: false,
                                              incomingPort: 6400,
                                              autoAnswerRings: 0,
                                              echoCommands: true,
                                              verboseResultCodes: true,
                                              connectResultIncludesBaudRate: false,
                                              defaultDialPort: 5190,
                                              defaultDialHost: "",
                                              aciaBaseAddress: .de00)

        XCTAssertEqual(QLinkReloadedModemRequirements.incompatibilities(in: modem, for: .x64sc),
                       ["Dial host is blank"])
        XCTAssertFalse(QLinkReloadedModemRequirements.isCompatible(modem, for: .x64sc))
    }

    func testQLinkReloadedDriveRequirementsAcceptWritableDrive8() {
        let drives = QLinkReloadedDriveRequirements.preset(preservingValuesFrom: EmulatedMachine.x64sc.defaultDriveConfigurations(),
                                                           for: .x64sc)

        XCTAssertTrue(QLinkReloadedDriveRequirements.isCompatible(drives, for: .x64sc))
        let drive8 = drives.first { $0.unit == 8 }
        XCTAssertEqual(drive8?.storageKind, .diskImage)
        XCTAssertEqual(drive8?.driveType, .c1541)
        XCTAssertEqual(drive8?.accessMode, .native)
        XCTAssertFalse(drive8?.protectsInsertedDisks ?? true)
    }

    func testQLinkReloadedDrivePresetOnlyChangesDrive8Requirements() {
        var drives = EmulatedMachine.x64sc.defaultDriveConfigurations()
        drives[0].soundEnabled = true
        drives[1].isAttached = true
        drives[1].protectsInsertedDisks = true

        let patchedDrives = QLinkReloadedDriveRequirements.preset(preservingValuesFrom: drives, for: .x64sc)

        XCTAssertFalse(patchedDrives[0].protectsInsertedDisks)
        XCTAssertTrue(patchedDrives[0].soundEnabled)
        XCTAssertEqual(patchedDrives[1], drives[1])
    }

    func testQLinkReloadedDrivePresetForcesNativeDrive8() {
        var drives = EmulatedMachine.x64sc.defaultDriveConfigurations()
        drives[0].accessMode = .fast

        let patchedDrives = QLinkReloadedDriveRequirements.preset(preservingValuesFrom: drives, for: .x64sc)

        XCTAssertEqual(patchedDrives.first { $0.unit == 8 }?.accessMode, .native)
    }

    func testQLinkReloadedDriveRequirementsRejectProtectedDrive8() {
        let drives = EmulatedMachine.x64sc.defaultDriveConfigurations()

        let issues = QLinkReloadedDriveRequirements.incompatibilities(in: drives, for: .x64sc)

        XCTAssertTrue(issues.contains("Drive 8 protects inserted disks"))
        XCTAssertFalse(QLinkReloadedDriveRequirements.isCompatible(drives, for: .x64sc))
    }

    func testQLinkReloadedDriveRequirementsRejectFastDrive8() {
        var drives = QLinkReloadedDriveRequirements.preset(preservingValuesFrom: EmulatedMachine.x64sc.defaultDriveConfigurations(),
                                                           for: .x64sc)
        drives[0].accessMode = .fast

        let issues = QLinkReloadedDriveRequirements.incompatibilities(in: drives, for: .x64sc)

        XCTAssertTrue(issues.contains("Drive 8 is Fast, not Native"))
        XCTAssertFalse(QLinkReloadedDriveRequirements.isCompatible(drives, for: .x64sc))
    }

    func testQLinkReloadedStartupUsesRuntimeAutostartDiskCommand() throws {
        let appSource = try sourceText(at: "macos/ViceMac/ViceMacApp.swift")

        XCTAssertTrue(appSource.contains("programName: bootProgram"))
        XCTAssertFalse(appSource.contains("submitLine(\"LOAD\\\"\\(bootProgram)\\\",8\")"))
        XCTAssertFalse(appSource.contains("submitLine(\"RUN\")"))
    }

    func testQLinkCaptureViewerProvidesCopyAllAction() throws {
        let appSource = try sourceText(at: "macos/ViceMac/ViceMacApp.swift")

        XCTAssertTrue(appSource.contains("var allText: String"))
        XCTAssertTrue(appSource.contains("var rawCapturePath: String"))
        XCTAssertTrue(appSource.contains("Label(\"Copy All\", systemImage: \"doc.on.doc\")"))
        XCTAssertTrue(appSource.contains("Label(\"Copy .cap Path\", systemImage: \"doc\")"))
        XCTAssertTrue(appSource.contains("NSPasteboard.general.setString(model.allText, forType: .string)"))
        XCTAssertTrue(appSource.contains("NSPasteboard.general.setString(model.rawCapturePath, forType: .string)"))
    }

    func testQLinkProtocolCaptureWritesRawCapBesideLog() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ViceMacQLinkCaptureTests-\(UUID().uuidString)", isDirectory: true)
        let logURL = rootURL.appendingPathComponent("qlink-capture.log")
        try FileManager.default.createDirectory(at: rootURL,
                                                withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let capture = try XCTUnwrap(QLinkProtocolCapture(logURL: logURL))
        capture.record(direction: 0, bytes: [0x5A, 0x01, 0x02])
        capture.record(direction: 1, bytes: [0x20, 0x46, 0x44, 0x4F])
        capture.close()

        let capURL = QLinkProtocolCapture.capURL(forLogURL: logURL)
        let capBytes = [UInt8](try Data(contentsOf: capURL))
        XCTAssertEqual(capBytes, [
            0, 3, 0, 0x5A, 0x01, 0x02,
            1, 4, 0, 0x20, 0x46, 0x44, 0x4F
        ])

        let logText = try String(contentsOf: logURL, encoding: .utf8)
        XCTAssertTrue(logText.contains("# raw capture: \(capURL.path)"))
        XCTAssertTrue(logText.contains("dir uint8 (0=C2S,1=S2C), length uint16-le, bytes"))
    }

    func testDiskAttachReappliesDriveConfigurationBeforeRuntimeAttach() throws {
        let mediaSource = try sourceText(at: "macos/ViceMac/EmulatorSession+Media.swift")
        let applyRange = try XCTUnwrap(mediaSource.range(of: "applyDriveConfigurations(updateStatus: false)"))
        let attachRange = try XCTUnwrap(mediaSource.range(of: "let didAttach = engine.attachDisk"))

        XCTAssertLessThan(applyRange.lowerBound, attachRange.lowerBound)
    }

    func testQLinkReloadedIncompatibleSettingsMessageGroupsIssues() {
        let message = QLinkReloadedServiceError.incompatibleSettings(
            modemIssues: ["Connection is Telnet, not Raw TCP"],
            driveIssues: ["Drive 8 protects inserted disks"]
        ).localizedDescription

        XCTAssertTrue(message.contains("VICE Mac did not change them"))
        XCTAssertTrue(message.contains("Modem:\n- Connection is Telnet, not Raw TCP"))
        XCTAssertTrue(message.contains("Drive:\n- Drive 8 protects inserted disks"))
        XCTAssertTrue(message.contains("writable disk image in drive 8"))
    }

    func testModemCapabilitiesMatchVICERS232Targets() {
        XCTAssertEqual(EmulatedMachine.x64sc.capabilities.supportedModemInterfaces, [.userPort, .swiftLink, .turbo232])
        XCTAssertEqual(EmulatedMachine.x128.capabilities.supportedModemInterfaces, [.userPort, .swiftLink, .turbo232])
        XCTAssertEqual(EmulatedMachine.xvic.capabilities.supportedModemInterfaces, [.userPort, .swiftLink, .turbo232])
        XCTAssertFalse(EmulatedMachine.xpet.capabilities.supportsNetworking)
        XCTAssertFalse(EmulatedMachine.xplus4.capabilities.supportsNetworking)
    }

    func testModemACIAAddressOptionsMatchVICETargets() {
        XCTAssertEqual(NetworkModemACIAAddress.supportedAddresses(for: .x64sc), [.de00, .df00])
        XCTAssertEqual(NetworkModemACIAAddress.supportedAddresses(for: .x128), [.de00, .df00, .d700])
        XCTAssertEqual(NetworkModemACIAAddress.supportedAddresses(for: .xvic), [.vic20_9800, .vic20_9c00])
        XCTAssertEqual(NetworkModemACIAAddress.supportedAddresses(for: .xpet), [])
    }

    func testHayesModemServiceDialsWithATCommand() throws {
        let queue = DispatchQueue(label: "com.barrywalker.vicemac.tests.hayes-modem")
        let service = HayesModemService()
        addTeardownBlock {
            service.stop()
        }

        let remoteReady = expectation(description: "remote connection ready")
        let remoteEndpointPort = try NetworkTestPort.reserveLoopbackPort()
        let remoteListener = try NWListener(using: .tcp, on: remoteEndpointPort)
        addTeardownBlock {
            remoteListener.cancel()
        }
        remoteListener.newConnectionHandler = { connection in
            connection.stateUpdateHandler = { state in
                if case .ready = state {
                    remoteReady.fulfill()
                    connection.send(content: Data("WELCOME".utf8),
                                    completion: .contentProcessed { _ in })
                }
            }
            connection.start(queue: queue)
        }
        remoteListener.start(queue: queue)
        let remotePort = remoteEndpointPort.rawValue

        let modem = NetworkModemConfiguration(isEnabled: true,
                                              interface: .swiftLink,
                                              baudRate: 9600,
                                              transportMode: .raw,
                                              acceptsIncomingCalls: false,
                                              incomingPort: 6400,
                                              autoAnswerRings: 0,
                                              echoCommands: true,
                                              verboseResultCodes: true,
                                              defaultDialPort: 23)
        let localPort = try service.start(configuration: modem) { _ in }
        let serialPort = try XCTUnwrap(NWEndpoint.Port(rawValue: UInt16(localPort)))
        let serialConnection = NWConnection(host: .ipv4(.loopback),
                                            port: serialPort,
                                            using: .tcp)
        addTeardownBlock {
            serialConnection.cancel()
        }

        let serialReady = expectation(description: "serial connection ready")
        serialConnection.stateUpdateHandler = { state in
            if case .ready = state {
                serialReady.fulfill()
            }
        }
        serialConnection.start(queue: queue)
        wait(for: [serialReady], timeout: 2)

        let response = expectation(description: "Hayes dial response")
        let capture = NetworkTestCapture()

        @Sendable func receiveSerial() {
            serialConnection.receive(minimumIncompleteLength: 1,
                                     maximumLength: 4096) { data, _, isComplete, error in
                if let data,
                   !data.isEmpty,
                   capture.append(data, matching: ["CONNECT 9600", "WELCOME"]) {
                    response.fulfill()
                }

                if !isComplete,
                   error == nil {
                    receiveSerial()
                }
            }
        }

        receiveSerial()
        serialConnection.send(content: Data("atdt 127.0.0.1:\(remotePort)\r".utf8),
                              completion: .contentProcessed { _ in })

        wait(for: [remoteReady, response], timeout: 3)
        let printableResponse = capture.printableResponse
        XCTAssertTrue(printableResponse.contains("CONNECT 9600"))
        XCTAssertTrue(printableResponse.contains("WELCOME"))
    }

    func testHayesModemServiceCanSendPlainConnectResult() throws {
        let queue = DispatchQueue(label: "com.barrywalker.vicemac.tests.hayes-plain-connect")
        let service = HayesModemService()
        addTeardownBlock {
            service.stop()
        }

        let remoteReady = expectation(description: "remote connection ready")
        let remoteEndpointPort = try NetworkTestPort.reserveLoopbackPort()
        let remoteListener = try NWListener(using: .tcp, on: remoteEndpointPort)
        addTeardownBlock {
            remoteListener.cancel()
        }
        remoteListener.newConnectionHandler = { connection in
            connection.stateUpdateHandler = { state in
                if case .ready = state {
                    remoteReady.fulfill()
                    connection.send(content: Data("WELCOME".utf8),
                                    completion: .contentProcessed { _ in })
                }
            }
            connection.start(queue: queue)
        }
        remoteListener.start(queue: queue)
        let remotePort = remoteEndpointPort.rawValue

        let modem = NetworkModemConfiguration(isEnabled: true,
                                              interface: .userPort,
                                              baudRate: 1200,
                                              transportMode: .raw,
                                              acceptsIncomingCalls: false,
                                              incomingPort: 6400,
                                              autoAnswerRings: 0,
                                              echoCommands: true,
                                              verboseResultCodes: true,
                                              connectResultIncludesBaudRate: false,
                                              defaultDialPort: Int(remotePort),
                                              defaultDialHost: "127.0.0.1")
        let localPort = try service.start(configuration: modem) { _ in }
        let serialPort = try XCTUnwrap(NWEndpoint.Port(rawValue: UInt16(localPort)))
        let serialConnection = NWConnection(host: .ipv4(.loopback),
                                            port: serialPort,
                                            using: .tcp)
        addTeardownBlock {
            serialConnection.cancel()
        }

        let serialReady = expectation(description: "serial connection ready")
        serialConnection.stateUpdateHandler = { state in
            if case .ready = state {
                serialReady.fulfill()
            }
        }
        serialConnection.start(queue: queue)
        wait(for: [serialReady], timeout: 2)

        let response = expectation(description: "plain Hayes connect response")
        let capture = NetworkTestCapture()

        @Sendable func receiveSerial() {
            serialConnection.receive(minimumIncompleteLength: 1,
                                     maximumLength: 4096) { data, _, isComplete, error in
                if let data,
                   !data.isEmpty,
                   capture.append(data, matching: ["CONNECT", "WELCOME"]) {
                    response.fulfill()
                }

                if !isComplete,
                   error == nil {
                    receiveSerial()
                }
            }
        }

        receiveSerial()
        serialConnection.send(content: Data("atdt 5551212\r".utf8),
                              completion: .contentProcessed { _ in })

        wait(for: [remoteReady, response], timeout: 3)
        let printableResponse = capture.printableResponse
        XCTAssertTrue(printableResponse.contains("\r\nCONNECT\r\n"))
        XCTAssertFalse(printableResponse.contains("CONNECT 1200"))
        XCTAssertTrue(printableResponse.contains("WELCOME"))
    }

    func testHayesModemServiceReturnsNoCarrierWhenDialTimesOut() throws {
        let queue = DispatchQueue(label: "com.barrywalker.vicemac.tests.hayes-timeout")
        let service = HayesModemService(dialTimeout: .milliseconds(150))
        addTeardownBlock {
            service.stop()
        }

        let modem = NetworkModemConfiguration(isEnabled: true,
                                              interface: .swiftLink,
                                              baudRate: 9600,
                                              transportMode: .raw,
                                              acceptsIncomingCalls: false,
                                              incomingPort: 6400,
                                              autoAnswerRings: 0,
                                              echoCommands: true,
                                              verboseResultCodes: true,
                                              defaultDialPort: 23)
        let localPort = try service.start(configuration: modem) { _ in }
        let serialPort = try XCTUnwrap(NWEndpoint.Port(rawValue: UInt16(localPort)))
        let serialConnection = NWConnection(host: .ipv4(.loopback),
                                            port: serialPort,
                                            using: .tcp)
        addTeardownBlock {
            serialConnection.cancel()
        }

        let serialReady = expectation(description: "serial connection ready")
        serialConnection.stateUpdateHandler = { state in
            if case .ready = state {
                serialReady.fulfill()
            }
        }
        serialConnection.start(queue: queue)
        wait(for: [serialReady], timeout: 2)

        let response = expectation(description: "Hayes timeout response")
        let capture = NetworkTestCapture()

        @Sendable func receiveSerial() {
            serialConnection.receive(minimumIncompleteLength: 1,
                                     maximumLength: 4096) { data, _, isComplete, error in
                if let data,
                   !data.isEmpty,
                   capture.append(data, matching: ["NO CARRIER"]) {
                    response.fulfill()
                }

                if !isComplete,
                   error == nil {
                    receiveSerial()
                }
            }
        }

        receiveSerial()
        serialConnection.send(content: Data("ATDT 203.0.113.1:52146\r".utf8),
                              completion: .contentProcessed { _ in })

        wait(for: [response], timeout: 3)
        XCTAssertTrue(capture.printableResponse.contains("NO CARRIER"))
    }

    func testHayesModemServiceUsesPlainSerialForUserPort() throws {
        let queue = DispatchQueue(label: "com.barrywalker.vicemac.tests.hayes-user-port")
        let service = HayesModemService()
        addTeardownBlock {
            service.stop()
        }

        let modem = NetworkModemConfiguration(isEnabled: true,
                                              interface: .userPort,
                                              baudRate: 2400,
                                              transportMode: .raw,
                                              acceptsIncomingCalls: false,
                                              incomingPort: 6400,
                                              autoAnswerRings: 0,
                                              echoCommands: true,
                                              verboseResultCodes: true,
                                              defaultDialPort: 23)
        let localPort = try service.start(configuration: modem) { _ in }
        let serialPort = try XCTUnwrap(NWEndpoint.Port(rawValue: UInt16(localPort)))
        let serialConnection = NWConnection(host: .ipv4(.loopback),
                                            port: serialPort,
                                            using: .tcp)
        addTeardownBlock {
            serialConnection.cancel()
        }

        let serialReady = expectation(description: "serial connection ready")
        serialConnection.stateUpdateHandler = { state in
            if case .ready = state {
                serialReady.fulfill()
            }
        }
        serialConnection.start(queue: queue)
        wait(for: [serialReady], timeout: 2)

        let response = expectation(description: "Hayes command response")
        let capture = NetworkTestCapture()

        @Sendable func receiveSerial() {
            serialConnection.receive(minimumIncompleteLength: 1,
                                     maximumLength: 4096) { data, _, isComplete, error in
                if let data,
                   !data.isEmpty,
                   capture.append(data, matching: ["AT", "OK"]) {
                    response.fulfill()
                }

                if !isComplete,
                   error == nil {
                    receiveSerial()
                }
            }
        }

        receiveSerial()
        serialConnection.send(content: Data("AT\r".utf8),
                              completion: .contentProcessed { _ in })

        wait(for: [response], timeout: 3)
        XCTAssertFalse(capture.rawBytes.contains(0xff))
    }

    func testHayesModemCommandBufferTreatsPETSCIIDeleteAsDestructive() {
        var commandBuffer = ""

        for byte in Data("ATDT NOPE".utf8) {
            HayesModemService.applyCommandEditingByte(byte, to: &commandBuffer)
        }
        for byte in [UInt8](repeating: 20, count: 4) {
            HayesModemService.applyCommandEditingByte(byte, to: &commandBuffer)
        }
        for byte in Data("TEST".utf8) {
            HayesModemService.applyCommandEditingByte(byte, to: &commandBuffer)
        }

        XCTAssertEqual(commandBuffer, "ATDT TEST")
    }

    func testHayesModemServiceProvidesBuiltInTestLine() throws {
        let queue = DispatchQueue(label: "com.barrywalker.vicemac.tests.hayes-test-line")
        let service = HayesModemService()
        addTeardownBlock {
            service.stop()
        }

        let modem = NetworkModemConfiguration(isEnabled: true,
                                              interface: .swiftLink,
                                              baudRate: 9600,
                                              transportMode: .raw,
                                              acceptsIncomingCalls: false,
                                              incomingPort: 6400,
                                              autoAnswerRings: 0,
                                              echoCommands: true,
                                              verboseResultCodes: true,
                                              defaultDialPort: 23)
        let localPort = try service.start(configuration: modem) { _ in }
        let serialPort = try XCTUnwrap(NWEndpoint.Port(rawValue: UInt16(localPort)))
        let serialConnection = NWConnection(host: .ipv4(.loopback),
                                            port: serialPort,
                                            using: .tcp)
        addTeardownBlock {
            serialConnection.cancel()
        }

        let serialReady = expectation(description: "serial connection ready")
        serialConnection.stateUpdateHandler = { state in
            if case .ready = state {
                serialReady.fulfill()
            }
        }
        serialConnection.start(queue: queue)
        wait(for: [serialReady], timeout: 2)

        let response = expectation(description: "built-in test line response")
        let capture = NetworkTestCapture()

        @Sendable func receiveSerial() {
            serialConnection.receive(minimumIncompleteLength: 1,
                                     maximumLength: 4096) { data, _, isComplete, error in
                if let data,
                   !data.isEmpty,
                   capture.append(data, matching: [
                       "CONNECT 9600",
                       "mac VICE MODEM TEST LINE",
                       "PONG",
                       "NO CARRIER"
                   ]) {
                    response.fulfill()
                }

                if !isComplete,
                   error == nil {
                    receiveSerial()
                }
            }
        }

        receiveSerial()
        serialConnection.send(content: Data("ATDTEST\rPING\rBYE\r".utf8),
                              completion: .contentProcessed { _ in })

        wait(for: [response], timeout: 3)
        let printableResponse = capture.printableResponse
        XCTAssertTrue(printableResponse.contains("CONNECT 9600"))
        XCTAssertTrue(printableResponse.contains("mac VICE MODEM TEST LINE"))
        XCTAssertTrue(printableResponse.contains("PONG"))
        XCTAssertTrue(printableResponse.contains("NO CARRIER"))
    }

    func testSystemTimeSyncCapabilityMatchesVICEUserportRTCRegistration() {
        XCTAssertTrue(EmulatedMachine.x64sc.capabilities.supportsSystemTimeSync)
        XCTAssertTrue(EmulatedMachine.x128.capabilities.supportsSystemTimeSync)
        XCTAssertTrue(EmulatedMachine.xvic.capabilities.supportsSystemTimeSync)
        XCTAssertTrue(EmulatedMachine.xpet.capabilities.supportsSystemTimeSync)
        XCTAssertFalse(EmulatedMachine.xplus4.capabilities.supportsSystemTimeSync)
        XCTAssertFalse(EmulatedMachine.xc16.capabilities.supportsSystemTimeSync)
        XCTAssertFalse(EmulatedMachine.xc232.capabilities.supportsSystemTimeSync)
        XCTAssertFalse(EmulatedMachine.xv364.capabilities.supportsSystemTimeSync)
    }

    func testVideoFilterPresetsIncludeMonitorAndPhosphorModes() {
        XCTAssertTrue(VideoFilterPreset.allCases.contains(.commodore1084))
        XCTAssertTrue(VideoFilterPreset.allCases.contains(.greenPhosphor))
        XCTAssertTrue(VideoFilterPreset.allCases.contains(.amberPhosphor))

        let commodore1702 = VideoFilterSettings.defaults(for: .commodore1702)
        let commodore1084 = VideoFilterSettings.defaults(for: .commodore1084)
        let green = VideoFilterSettings.defaults(for: .greenPhosphor)
        let amber = VideoFilterSettings.defaults(for: .amberPhosphor)

        XCTAssertEqual(commodore1084.monochromeAmount, 0.0)
        XCTAssertLessThan(commodore1084.barrelDistortion, commodore1702.barrelDistortion)
        XCTAssertEqual(green.monochromeAmount, 1.0)
        XCTAssertGreaterThan(green.phosphorTintGreen, green.phosphorTintRed)
        XCTAssertGreaterThan(green.phosphorPersistence, commodore1702.phosphorPersistence)
        XCTAssertEqual(amber.monochromeAmount, 1.0)
        XCTAssertGreaterThan(amber.phosphorTintRed, amber.phosphorTintBlue)
        XCTAssertGreaterThan(amber.phosphorPersistence, commodore1702.phosphorPersistence)
    }

    func testVideoFilterSettingsRoundTripCustomPersistence() throws {
        var settings = VideoFilterSettings.defaults(for: .greenPhosphor)
        settings.phosphorPersistence = 0.91

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(VideoFilterSettings.self, from: data)

        XCTAssertEqual(decoded.preset, .greenPhosphor)
        XCTAssertEqual(decoded.phosphorPersistence, 0.91, accuracy: 0.0001)
    }

    func testTEDPrototypeModelsUseMatchingDefaultROMs() {
        let c232 = EmulatedMachine.xc232
        let v364 = EmulatedMachine.xv364
        let c232Arguments = c232.startupArguments(configuration: startupConfiguration(for: c232))
        let v364Arguments = v364.startupArguments(configuration: startupConfiguration(for: v364))

        XCTAssertEqual(c232Arguments.value(after: "-kernal"), "kernal-318004-01.bin")
        XCTAssertEqual(v364Arguments.value(after: "-kernal"), "kernal-364.bin")
        XCTAssertEqual(v364Arguments.value(after: "-c2lo"), "c2lo-364.bin")
    }

    func testDriveSoundStartupVolumeUsesVICEScale() {
        let machine = EmulatedMachine.x64sc
        let driveConfigurations = [
            DriveConfiguration(unit: 8,
                               isAttached: true,
                               driveType: .c1541,
                               soundEnabled: true,
                               soundVolume: 50)
        ]
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                     driveConfigurations: driveConfigurations))

        XCTAssertTrue(arguments.contains("-drivesound"))
        XCTAssertEqual(arguments.value(after: "-drivesoundvolume"), "2000")
    }

    func testSharedFolderStartupUsesFilesystemDeviceBackend() {
        let machine = EmulatedMachine.x64sc
        let driveConfigurations = [
            DriveConfiguration(unit: 8,
                               isAttached: true,
                               storageKind: .sharedFolder,
                               driveType: .c1541,
                               sharedFolderPath: "/Users/test/Commodore Shared",
                               soundEnabled: true,
                               soundVolume: 50)
        ]
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                     driveConfigurations: driveConfigurations))

        XCTAssertTrue(arguments.contains("+drivesound"))
        XCTAssertEqual(arguments.value(after: "-drive8type"), "0")
        XCTAssertTrue(arguments.contains("+drive8truedrive"))
        XCTAssertTrue(arguments.contains("-trapdevice8"))
        XCTAssertEqual(arguments.value(after: "-devicebackend8"), "1")
        XCTAssertEqual(arguments.value(after: "-fs8"), "/Users/test/Commodore Shared")
        XCTAssertTrue(arguments.contains("-fs8convertp00"))
        XCTAssertTrue(arguments.contains("+fs8savep00"))
        XCTAssertTrue(arguments.contains("+fs8hidecbm"))
        XCTAssertTrue(arguments.contains("+fslongnames"))
        XCTAssertTrue(arguments.contains("+fsoverwrite"))
    }

    func testSharedFolderWithoutFolderStartsDetached() {
        let machine = EmulatedMachine.x64sc
        let driveConfigurations = [
            DriveConfiguration(unit: 8,
                               isAttached: true,
                               storageKind: .sharedFolder,
                               driveType: .c1541,
                               soundEnabled: false,
                               soundVolume: 25)
        ]
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                     driveConfigurations: driveConfigurations))

        XCTAssertEqual(arguments.value(after: "-devicebackend8"), "0")
        XCTAssertEqual(arguments.value(after: "-drive8type"), "0")
        XCTAssertTrue(arguments.contains("+trapdevice8"))
    }

    func testSharedFolderDriveRejectsDiskOnlyCommandsWithUsefulStatusMessages() throws {
        let harness = try ViceFSDeviceHarness()

        XCTAssertEqual(try harness.status(after: "N:MACVICE,01"), "30,CANNOT FORMAT MAC FOLDER,00,00")
        XCTAssertEqual(try harness.status(after: "V"), "31,NO BAM ON MAC FOLDER,00,00")
        XCTAssertEqual(try harness.status(after: "B-A:0,18,0"), "31,NO BAM ON MAC FOLDER,18,00")
        XCTAssertEqual(try harness.status(after: "B-R:2,0,18,0"), "31,RAW BLOCKS UNSUPPORTED,18,00")
        XCTAssertEqual(try harness.status(after: "B-P:2,0"), "31,BUFFER POINTER UNSUPPORTED,00,00")
    }

    func testSharedFolderDirectoryListingHidesMacDotFilesAndShowsFoldersAsDirectories() throws {
        let containerURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macvice-fsdevice-\(UUID().uuidString)", isDirectory: true)
        let rootURL = containerURL.appendingPathComponent("Tip128 X2-128S", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: containerURL) }

        try Data([0x01, 0x08, 0x60]).write(to: rootURL.appendingPathComponent("Tip128 X2-128S"))
        try Data([0x00]).write(to: rootURL.appendingPathComponent(".DS_Store"))
        try Data([0x00]).write(to: rootURL.appendingPathComponent("._Tip128 X2-128S"))
        try FileManager.default.createDirectory(at: rootURL.appendingPathComponent("GEOS Extras", isDirectory: true),
                                                withIntermediateDirectories: true)

        let harness = try ViceFSDeviceHarness()
        let entries = try harness.directoryEntries(for: rootURL)
        let names = entries.map(\.name)

        let entrySummary = entries.map { "\($0.name) [\($0.detail)]" }.joined(separator: ", ")

        XCTAssertEqual(entries.first?.name, "tip128 x2-128s")
        XCTAssertTrue(entries.contains { $0.name == "tip128 x2-128s" && $0.detail.lowercased().contains("prg") },
                      entrySummary)
        XCTAssertTrue(entries.contains { $0.name == "geos extras" && $0.detail.lowercased().contains("dir") },
                      entrySummary)
        let rawNameSummary = entries.map {
            "\($0.name): \($0.rawNameBytes.map { String(format: "%02x", $0) }.joined(separator: " "))"
        }.joined(separator: ", ")
        XCTAssertFalse(entries.flatMap(\.rawNameBytes).contains { (UInt8(0xc1)...UInt8(0xda)).contains($0) },
                       rawNameSummary)
        XCTAssertTrue(try harness.canOpenDisplayedFile(named: "TIP128 X2-128S"))
        XCTAssertFalse(names.contains("."))
        XCTAssertFalse(names.contains(".."))
        XCTAssertFalse(names.contains(".DS_Store"))
        XCTAssertFalse(names.contains("._Tip128 X2-128S"))
    }

    func testDriveProtectionStartupUsesReadOnlyAttachOptions() {
        let machine = EmulatedMachine.x128
        let driveConfigurations = [
            DriveConfiguration(unit: 8,
                               isAttached: true,
                               driveType: .c4040,
                               protectsInsertedDisks: true,
                               soundEnabled: false,
                               soundVolume: 25)
        ]
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                     driveConfigurations: driveConfigurations))

        XCTAssertTrue(arguments.contains("-attach8ro"))
        XCTAssertTrue(arguments.contains("-attach8d1ro"))
    }

    func testDriveActivitySummariesExposeParsedStatusFields() {
        let activity = DriveActivity(unit: 8,
                                     isConfigured: true,
                                     driveType: .c1571,
                                     accessMode: .native,
                                     activeDriveNumber: 0,
                                     slots: [
                                        DriveSlotActivity(driveNumber: 0,
                                                          ledColor: .green,
                                                          ledIntensity: 100,
                                                          imagePath: "/tmp/work.d71")
                                     ],
                                     ledColor: .green,
                                     ledIntensity: 100,
                                     errorIntensity: 0,
                                     track: 18,
                                     halfTrack: 1,
                                     diskSide: 1,
                                     driveStatusCode: 74,
                                     driveStatusText: "DRIVE NOT READY",
                                     imagePath: "/tmp/work.d71")

        XCTAssertEqual(activity.headPositionText, "T18")
        XCTAssertEqual(activity.headDetailText, "Track 18 +1/2 Side 2")
        XCTAssertEqual(activity.resolvedStatusText, "DRIVE NOT READY")
        XCTAssertTrue(activity.hasDiskImage)
    }

    func testMediaAndTapeStartupOptionsUseMacSettings() {
        let machine = EmulatedMachine.x64sc
        let mediaBehavior = MediaBehaviorConfiguration(openBehavior: .load,
                                                       warpDuringAutostart: false,
                                                       useTrueDriveDuringAutostart: true)
        let tapeConfiguration = TapeConfiguration(isDatasetteEnabled: true,
                                                  soundEnabled: true,
                                                  soundVolume: 50)
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                     mediaBehavior: mediaBehavior,
                                                                                     tapeConfiguration: tapeConfiguration))

        XCTAssertTrue(arguments.contains("-autostart-handle-tde"))
        XCTAssertTrue(arguments.contains("+autostart-warp"))
        XCTAssertEqual(arguments.value(after: "-tapeport1device"), "1")
        XCTAssertTrue(arguments.contains("-datasettesound"))
        XCTAssertEqual(arguments.value(after: "-dssoundvolume"), "2048")
    }

    func testPrinterStartupOptionsUseMacPrintQueue() {
        let machine = EmulatedMachine.x64sc
        let printerConfiguration = PrinterConfiguration(isEnabled: true,
                                                        deviceNumber: 4,
                                                        model: .mps803)
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                     printerConfiguration: printerConfiguration))

        XCTAssertTrue(arguments.contains("-busdevice4"))
        XCTAssertEqual(arguments.value(after: "-devicebackend4"), "1")
        XCTAssertEqual(arguments.value(after: "-prtxtdev1"), "/tmp/macvice-print/geos-print")
        XCTAssertEqual(arguments.value(after: "-pr4txtdev"), "0")
        XCTAssertEqual(arguments.value(after: "-pr4drv"), "mps803")
        XCTAssertEqual(arguments.value(after: "-pr4output"), "graphics")
    }

    func testPrinterPreviewAvailabilityRequiresEnabledGraphicsPrinter() {
        XCTAssertTrue(PrinterConfiguration(isEnabled: true,
                                           deviceNumber: 4,
                                           model: .mps803).canPreviewPages)
        XCTAssertTrue(PrinterConfiguration(isEnabled: true,
                                           deviceNumber: 4,
                                           model: .nl10).canPreviewPages)
        XCTAssertFalse(PrinterConfiguration(isEnabled: false,
                                            deviceNumber: 4,
                                            model: .mps803).canPreviewPages)
        XCTAssertFalse(PrinterConfiguration(isEnabled: true,
                                            deviceNumber: 4,
                                            model: .ascii).canPreviewPages)
    }

    func testDisabledPrinterStartupOptionsLeaveDeviceOff() {
        let machine = EmulatedMachine.x64sc
        let printerConfiguration = PrinterConfiguration(isEnabled: false,
                                                        deviceNumber: 5,
                                                        model: .nl10)
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                     printerConfiguration: printerConfiguration))

        XCTAssertTrue(arguments.contains("+busdevice5"))
        XCTAssertEqual(arguments.value(after: "-devicebackend5"), "0")
        XCTAssertEqual(arguments.value(after: "-pr5drv"), "nl10")
        XCTAssertEqual(arguments.value(after: "-pr5output"), "graphics")
    }

    func testSIDLayoutStartupOptionsUseExtraSIDResources() {
        let machine = EmulatedMachine.x64sc
        let sidConfiguration = SIDConfiguration(layout: .triple,
                                                secondAddress: .d420,
                                                thirdAddress: .de00)
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                     sidConfiguration: sidConfiguration))

        XCTAssertEqual(arguments.value(after: "-sidextra"), "2")
        XCTAssertEqual(arguments.value(after: "-sid2address"), "\(SIDAddressPreset.d420.rawValue)")
        XCTAssertEqual(arguments.value(after: "-sid3address"), "\(SIDAddressPreset.de00.rawValue)")
    }

    func testFastDriveStartupKeepsDriveAttachedAndDisablesTrueDrive() {
        let machine = EmulatedMachine.x64sc
        let driveConfigurations = [
            DriveConfiguration(unit: 8,
                               isAttached: true,
                               driveType: .c1541,
                               accessMode: .fast,
                               soundEnabled: false,
                               soundVolume: 25)
        ]
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine,
                                                                                     driveConfigurations: driveConfigurations))

        XCTAssertEqual(arguments.value(after: "-drive8type"), "1541")
        XCTAssertEqual(arguments.value(after: "-devicebackend8"), "0")
        XCTAssertTrue(arguments.contains("+drive8truedrive"))
        XCTAssertTrue(arguments.contains("-trapdevice8"))
    }

    func testDriveTypeFiltersDiskImageFormats() {
        XCTAssertTrue(DriveType.c1541.supportsDiskImage(url: URL(fileURLWithPath: "/tmp/demo.d64")))
        XCTAssertFalse(DriveType.c1541.supportsDiskImage(url: URL(fileURLWithPath: "/tmp/demo.d71")))
        XCTAssertTrue(DriveType.c1571.supportsDiskImage(url: URL(fileURLWithPath: "/tmp/demo.d71")))
    }

    func testMediaFileClassifiesSupportedMedia() {
        XCTAssertEqual(EmulatorMediaFile(url: URL(fileURLWithPath: "/tmp/demo.d64")), .disk(.d64))
        XCTAssertEqual(EmulatorMediaFile(url: URL(fileURLWithPath: "/tmp/demo.prg")), .autostart(.prg))
        XCTAssertEqual(EmulatorMediaFile(url: URL(fileURLWithPath: "/tmp/demo.t64")), .autostart(.t64))
        XCTAssertEqual(EmulatorMediaFile(url: URL(fileURLWithPath: "/tmp/demo.tap")), .autostart(.tap))
        XCTAssertEqual(EmulatorMediaFile(url: URL(fileURLWithPath: "/tmp/demo.crt")), .cartridge(.crt))
        XCTAssertEqual(EmulatorMediaFile(url: URL(fileURLWithPath: "/tmp/demo.vsf")), .snapshot(.vsf))
        XCTAssertNil(EmulatorMediaFile(url: URL(fileURLWithPath: "/tmp/demo.txt")))
    }

    func testP1ConfigurationDefaultsDecodeLegacyValues() throws {
        let data = "{}".data(using: .utf8)!

        let snapshot = try JSONDecoder().decode(SnapshotConfiguration.self, from: data)
        let behavior = try JSONDecoder().decode(SessionBehaviorConfiguration.self, from: data)
        let printer = try JSONDecoder().decode(PrinterConfiguration.self, from: data)

        XCTAssertEqual(snapshot, .standard)
        XCTAssertEqual(snapshot.summaryTitle, "Machine state, ROM images, and attached disks")
        XCTAssertEqual(behavior, .standard)
        XCTAssertFalse(behavior.pauseWhenAppInactive)
        XCTAssertEqual(printer, .standard)
    }

    func testFrameSourceCopiesLatestFrameWithoutSequenceFilter() {
        let source = MacVICEFrameSource(displayProfile: EmulatedMachine.x64sc.macVICEDisplayProfile)
        let frame = MacVICEVideoFrame(width: 2,
                                      height: 1,
                                      bytesPerRow: 8,
                                      sequence: 42,
                                      pixels: Data(repeating: 255, count: 8))

        source.publish(frame)

        XCTAssertEqual(source.copyLatestFrame()?.sequence, 42)
        XCTAssertNil(source.copyLatestFrame(after: 42))
    }

    func testSupportedMediaExtensionsRespectMachineCapabilities() {
        let c64Extensions = EmulatorMediaFile.supportedFilenameExtensions(for: .x64sc)
        let petExtensions = EmulatorMediaFile.supportedFilenameExtensions(for: .xpet)

        XCTAssertTrue(c64Extensions.contains("d64"))
        XCTAssertTrue(c64Extensions.contains("prg"))
        XCTAssertTrue(c64Extensions.contains("t64"))
        XCTAssertTrue(c64Extensions.contains("tap"))
        XCTAssertTrue(c64Extensions.contains("crt"))
        XCTAssertTrue(c64Extensions.contains("vsf"))
        XCTAssertTrue(petExtensions.contains("d80"))
        XCTAssertTrue(petExtensions.contains("prg"))
        XCTAssertTrue(petExtensions.contains("tap"))
        XCTAssertTrue(petExtensions.contains("vsf"))
        XCTAssertFalse(petExtensions.contains("crt"))
    }

    func testKeyboardTextChunksNormalizeClipboardText() {
        let chunks = EmulatorSession.keyboardTextChunks(for: "10 print \"hi\"\n20 π\tthere\0")

        XCTAssertEqual(chunks, ["10 print \"hi\"\n20 ? there"])
    }

    func testKeyboardTextChunksSplitBeforeBridgeLimit() {
        let text = String(repeating: "A", count: EmulatorSession.maxKeyboardTextChunkLength + 5)
        let chunks = EmulatorSession.keyboardTextChunks(for: text)

        XCTAssertEqual(chunks.count, 2)
        XCTAssertEqual(chunks[0].count, EmulatorSession.maxKeyboardTextChunkLength)
        XCTAssertEqual(chunks[1].count, 5)
        XCTAssertTrue(chunks.allSatisfy { $0.utf8.count <= EmulatorSession.maxKeyboardTextChunkLength })
    }

    func testDebuggerSnapshotFormatsRawMemorySpace() {
        let snapshot = DebuggerSnapshot(
            MacVICEDebuggerSnapshot(memorySpace: .drive11,
                                    cpuType: 5,
                                    bank: -1,
                                    cycle: 0,
                                    programCounter: 0xc000,
                                    supportedCPUTypes: [],
                                    registers: [])
        )

        XCTAssertEqual(snapshot.memorySpaceText, "Drive 11")
        XCTAssertEqual(snapshot.pcText, "C000")
        XCTAssertEqual(snapshot.bankText, "Current")
        XCTAssertEqual(DebuggerFormatter.memorySpaceTitle(99), "Memory 99")
    }

    func testDebuggerCheckpointDetailTextSurfacesParsedOptions() {
        let checkpoint = DebuggerCheckpoint(
            MacVICECheckpoint(id: 7,
                              memorySpace: .drive9,
                              startAddress: 0xc000,
                              endAddress: 0xc002,
                              operations: DebuggerOperations.read.rawValue | DebuggerOperations.write.rawValue,
                              isEnabled: true,
                              stops: false,
                              isTemporary: true,
                              hitCount: 2,
                              ignoreCount: 4)
        )

        XCTAssertEqual(checkpoint.rangeText, "C000-C002")
        XCTAssertEqual(checkpoint.memorySpaceText, "Drive 9")
        XCTAssertEqual(checkpoint.detailText, "Drive 9 - Logs - Temporary - Ignore 4")
        XCTAssertEqual(checkpoint.addresses, [0xc000, 0xc001, 0xc002])
    }

    func testVICEKeymapParserExpandsIncludesAndMatrixLabels() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        try """
        # |Bit 0| DEL |Retrn|C_L/R|  F7 |  F1 |  F3 |  F5 |C_U/D|
        !CLEAR
        Return 0 1 8
        """.write(to: directory.appendingPathComponent("child.vkm"),
                   atomically: true,
                   encoding: .utf8)

        let document = try VICEKeymapDocument.parse(text: "!INCLUDE child.vkm",
                                                    baseURL: directory)

        XCTAssertEqual(document.entries.count, 1)
        XCTAssertEqual(document.entries.first?.symbol, "Return")
        XCTAssertEqual(document.targetTitle(for: try XCTUnwrap(document.entries.first)),
                       "Retrn (row 0, column 1)")
    }

    func testVICEKeymapParserReadsNumberedMatrixLabels() throws {
        let document = try VICEKeymapDocument.parse(text: """
        # 0 |INST/DEL|RETURN  |--------|F7/HELP |F4/F1   |F5/F2   |F6/F3   |@       |
        Return 0 1 8
        """)

        XCTAssertEqual(document.matrixKey(row: 0, column: 0)?.title, "INST/DEL")
        XCTAssertEqual(document.matrixKey(row: 0, column: 1)?.title, "RETURN")
        XCTAssertNil(document.matrixKey(row: 0, column: 2))
        XCTAssertEqual(document.matrixKey(row: 0, column: 7)?.title, "@")
        XCTAssertEqual(document.targetTitle(for: try XCTUnwrap(document.entries.first)),
                       "RETURN (row 0, column 1)")
    }

    func testVICEKeymapDocumentUpdatesEntryAndRendersVKM() throws {
        let document = try VICEKeymapDocument.parse(text: "Return 0 1 8")
        var entry = try XCTUnwrap(document.entries.first)
        entry.symbol = "F1"
        entry.row = 0
        entry.column = 4
        entry.flags = 0x8

        let rendered = document.updating(entry: entry).rendered(customTitle: "Test map")

        XCTAssertTrue(rendered.contains("F1"))
        XCTAssertTrue(rendered.contains("0x8"))
        XCTAssertFalse(rendered.contains("Return 0 1 8"))
    }

    func testVICEKeymapDocumentAddsAndRemovesMappings() throws {
        let document = try VICEKeymapDocument.parse(text: """
        !CLEAR
        Return 0 1 8
        """)
        let added = VICEKeymapEntry(id: document.nextEntryID,
                                    symbol: "KP_Enter",
                                    row: 0,
                                    column: 1,
                                    flags: VICEKeymapFlags.anyShiftState,
                                    trailingComment: nil)

        let updated = document.appending(entry: added)
        XCTAssertEqual(updated.entries.count, 2)
        XCTAssertTrue(updated.rendered(customTitle: "Test map").contains("VICE Mac custom mappings"))

        let removed = updated.removingEntry(id: added.id)
        XCTAssertEqual(removed.entries.map(\.symbol), ["Return"])
    }

    func testVICEKeymapDocumentSyncsModifierDirectives() throws {
        let document = try VICEKeymapDocument.parse(text: """
        !CLEAR
        !LSHIFT 1 7
        Shift_L 2 3 0x2
        """)
        let entry = try XCTUnwrap(document.entries.first)

        let rendered = document
            .syncingModifierDirectives(for: entry)
            .rendered(customTitle: "Test map")

        XCTAssertTrue(rendered.contains("!LSHIFT 2 3"))
    }

    func testControlKeyChordUsesPrintableBaseSymbol() throws {
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown,
                                                   location: .zero,
                                                   modifierFlags: .control,
                                                   timestamp: 0,
                                                   windowNumber: 0,
                                                   context: nil,
                                                   characters: "\u{1}",
                                                   charactersIgnoringModifiers: "a",
                                                   isARepeat: false,
                                                   keyCode: 0))

        XCTAssertEqual(ViceMacKeyMapper.symbol(for: event), 97)
        XCTAssertEqual(ViceMacKeyMapper.keySymbolName(for: event), "a")
    }

    func testShiftedPrintableSymbolDoesNotFallBackToUnshiftedKey() throws {
        let event = try XCTUnwrap(NSEvent.keyEvent(with: .keyDown,
                                                   location: .zero,
                                                   modifierFlags: .shift,
                                                   timestamp: 0,
                                                   windowNumber: 0,
                                                   context: nil,
                                                   characters: "A",
                                                   charactersIgnoringModifiers: "a",
                                                   isARepeat: false,
                                                   keyCode: 0))

        XCTAssertEqual(ViceMacKeyMapper.symbol(for: event), 65)
        XCTAssertEqual(ViceMacKeyMapper.keySymbolName(for: event), "A")
    }

    func testAllMachinesResolveBundledMacKeymaps() throws {
        for machine in Self.allMachines {
            for mode in VICEKeyboardMappingMode.allCases {
                let url = try XCTUnwrap(VICEKeymapStore.bundledKeymapURL(for: machine, mode: mode),
                                        "\(machine.shortName) \(mode.shortTitle)")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            }
        }
    }

    func testAllMachinesParseBundledMacKeymaps() throws {
        for machine in Self.allMachines {
            for mode in VICEKeyboardMappingMode.allCases {
                let document = try VICEKeymapStore.document(
                    for: machine,
                    configuration: VICEKeyboardMappingConfiguration(mode: mode, profile: .viceDefault)
                )

                XCTAssertFalse(document.entries.isEmpty, "\(machine.shortName) \(mode.shortTitle)")
            }
        }
    }

    func testKeymapStoreReadsDefaultMapFromRuntimeDataDirectory() throws {
        let dataDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macvice-data-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("VICEData", isDirectory: true)
        let machineDirectoryURL = dataDirectoryURL.appendingPathComponent("C64", isDirectory: true)
        let keymapURL = machineDirectoryURL.appendingPathComponent("macos_sym.vkm")
        try FileManager.default.createDirectory(at: machineDirectoryURL, withIntermediateDirectories: true)
        try """
        # VICE keyboard mapping file
        # 0 | A | B | C | D | E | F | G | H
        a 1 2 0x8
        """.write(to: keymapURL, atomically: true, encoding: .utf8)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: dataDirectoryURL.deletingLastPathComponent())
        }

        let document = try VICEKeymapStore.document(for: .x64sc,
                                                    configuration: .standard,
                                                    dataDirectoryURLs: [dataDirectoryURL])

        XCTAssertEqual(document.entries.first?.symbol, "a")
        XCTAssertEqual(document.entries.first?.row, 1)
        XCTAssertEqual(document.entries.first?.column, 2)
    }

    func testDataDirectoryLocatorFindsRepoDataFromNestedPackageSourcePath() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macvice-source-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = rootURL
            .appendingPathComponent("MacVICEKit/Sources/MacVICEKit/Runtime", isDirectory: true)
            .appendingPathComponent("MacVICERuntime.swift")
        let dataDirectoryURL = rootURL
            .appendingPathComponent("vice", isDirectory: true)
            .appendingPathComponent("data", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: dataDirectoryURL, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: rootURL) }

        let urls = VICEDataDirectoryLocator.existingDataDirectoryURLs(bundle: nil,
                                                                      environment: [:],
                                                                      sourceFilePath: sourceURL.path)

        XCTAssertEqual(urls.map { $0.standardizedFileURL.path },
                       [dataDirectoryURL.standardizedFileURL.path])
    }

    func testPETModelSpecificMacKeymapsResolve() throws {
        for model in PETMachineModel.allCases {
            let machine = EmulatedMachine(id: .xpet,
                                          model: .xpet(model),
                                          displayName: model.displayName,
                                          shortName: "xpet",
                                          viceTarget: "xpet",
                                          dynamicLibraryName: "libvicemacxpet.dylib",
                                          displayProfile: EmulatedMachine.xpet.displayProfile,
                                          startupOptions: [],
                                          displayOutputs: EmulatedMachine.xpet.displayOutputs,
                                          romSlots: EmulatedMachine.xpet.romSlots,
                                          ramExpansions: EmulatedMachine.xpet.ramExpansions,
                                          capabilities: EmulatedMachine.xpet.capabilities,
                                          videoStandardResources: EmulatedMachine.xpet.videoStandardResources)

            for mode in VICEKeyboardMappingMode.allCases {
                let url = try XCTUnwrap(VICEKeymapStore.bundledKeymapURL(for: machine, mode: mode),
                                        "\(model.displayName) \(mode.shortTitle)")
                XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            }
        }
    }

    func testNormalizedDriveConfigurationsReplacesInvalidMachineDriveType() {
        var configuration = DriveConfiguration(unit: 8,
                                               isAttached: true,
                                               driveType: .c4040,
                                               soundEnabled: true,
                                               soundVolume: 25)
        configuration.soundVolume = 175

        let normalized = EmulatorSession.normalizedDriveConfigurations([configuration], for: .x64sc)

        XCTAssertEqual(normalized.first?.driveType, EmulatedMachine.x64sc.capabilities.defaultDriveType)
        XCTAssertEqual(normalized.first?.soundVolume, 100)
    }

    func testNormalizedDriveConfigurationsKeepsStorageTypeAndDriveModelAligned() {
        let machine = EmulatedMachine.x64sc
        let diskImageConfiguration = DriveConfiguration(unit: 8,
                                                        isAttached: true,
                                                        storageKind: .diskImage,
                                                        driveType: .cmdHD,
                                                        soundEnabled: false,
                                                        soundVolume: 25)
        let hardDriveConfiguration = DriveConfiguration(unit: 9,
                                                        isAttached: true,
                                                        storageKind: .hardDriveImage,
                                                        driveType: .c1541,
                                                        soundEnabled: false,
                                                        soundVolume: 25)

        let normalized = EmulatorSession.normalizedDriveConfigurations([
            diskImageConfiguration,
            hardDriveConfiguration
        ], for: machine)

        XCTAssertEqual(normalized.first(where: { $0.unit == 8 })?.storageKind, .diskImage)
        XCTAssertEqual(normalized.first(where: { $0.unit == 8 })?.driveType, .c1541)
        XCTAssertEqual(normalized.first(where: { $0.unit == 9 })?.storageKind, .hardDriveImage)
        XCTAssertEqual(normalized.first(where: { $0.unit == 9 })?.driveType, .cmdHD)
    }

    func testMachineDefaultDrivesMatchAdvertisedUnitsAndTypes() {
        for machine in Self.allMachines {
            let defaults = machine.defaultDriveConfigurations()

            XCTAssertEqual(defaults.map(\.unit), machine.capabilities.driveUnits, machine.shortName)
            XCTAssertTrue(defaults.allSatisfy { drive in
                machine.capabilities.driveTypes.contains(drive.driveType)
            }, machine.shortName)
        }
    }

    func testWindowFrameAutosaveNamesAreMachineSpecific() {
        let autosaveNames = Self.allMachines.map(\.mainWindowFrameAutosaveName)
        let identifiers = Self.allMachines.map(\.mainWindowIdentifier)

        XCTAssertEqual(Set(autosaveNames).count, Self.allMachines.count)
        XCTAssertEqual(Set(identifiers).count, Self.allMachines.count)
        XCTAssertEqual(EmulatedMachine.x64sc.mainWindowFrameAutosaveName, "ViceMac.MainWindow.x64sc")
        XCTAssertEqual(EmulatedMachine.x64sc.mainWindowIdentifier, "ViceMac.MainWindow.x64sc")
        XCTAssertTrue(autosaveNames.allSatisfy { $0.hasPrefix("ViceMac.MainWindow.") })
        XCTAssertTrue(identifiers.allSatisfy { $0.hasPrefix("ViceMac.MainWindow.") })
    }

    func testMainWindowFrameDefaultsRoundTrip() {
        let machine = EmulatedMachine.x64sc
        let key = EmulatorDefaults.mainWindowFrameDefaultsKey(for: machine)
        let previousValue = UserDefaults.standard.object(forKey: key)
        defer {
            if let previousValue {
                UserDefaults.standard.set(previousValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }

        UserDefaults.standard.removeObject(forKey: key)
        XCTAssertNil(EmulatorDefaults.loadMainWindowFrame(for: machine))

        let frame = CGRect(x: 40, y: 56, width: 1280, height: 860)
        EmulatorDefaults.saveMainWindowFrame(frame, for: machine)
        XCTAssertEqual(EmulatorDefaults.loadMainWindowFrame(for: machine), frame)

        UserDefaults.standard.set("not a frame", forKey: key)
        XCTAssertNil(EmulatorDefaults.loadMainWindowFrame(for: machine))
    }

    func testDisplayOutputFallsBackToDefault() {
        let machine = EmulatedMachine.x128

        XCTAssertEqual(machine.displayOutput(id: nil), machine.defaultDisplayOutput)
        XCTAssertEqual(machine.displayOutput(id: "unknown"), machine.defaultDisplayOutput)
        XCTAssertEqual(machine.displayOutput(id: MachineDisplayOutput.c12880Column.id), .c12880Column)
    }

    func testControlPortConfigurationSanitizesAssignmentsAndNames() {
        let staleDeviceID = UUID()
        let device = ControlDeviceConfiguration.keyboard(name: "   ")
        let configuration = ControlPortConfiguration(devices: [device],
                                                     port1DeviceID: staleDeviceID,
                                                     port2DeviceID: device.id)

        let sanitized = configuration.sanitized()

        XCTAssertNil(sanitized.port1DeviceID)
        XCTAssertEqual(sanitized.port2DeviceID, device.id)
        XCTAssertEqual(sanitized.devices.first?.name, ControlDeviceKind.keyboard.defaultName)
    }

    func testGameControllerJoystickMappingDecodesLegacyControllerSelection() throws {
        let json = """
        {
          "preferredControllerName": "8BitDo SN30 Pro",
          "deadZone": 0.28,
          "up": "dpadUp",
          "down": "dpadDown",
          "left": "dpadLeft",
          "right": "dpadRight",
          "fire": "buttonSouth"
        }
        """.data(using: .utf8)!

        let mapping = try JSONDecoder().decode(GameControllerJoystickMapping.self, from: json)

        XCTAssertEqual(mapping.preferredControllerName, "8BitDo SN30 Pro")
        XCTAssertNil(mapping.preferredControllerIdentifier)
    }

    func testGameControllerJoystickMappingNormalizesControllerSelection() {
        var mapping = GameControllerJoystickMapping.standard
        mapping.preferredControllerName = "  8BitDo SN30 Pro  "
        mapping.preferredControllerIdentifier = "   "
        mapping.deadZone = 2

        let normalized = mapping.normalized()

        XCTAssertEqual(normalized.preferredControllerName, "8BitDo SN30 Pro")
        XCTAssertNil(normalized.preferredControllerIdentifier)
        XCTAssertEqual(normalized.deadZone, 0.95)
    }

    func testConnectedGameControllerTitlesDisambiguateDuplicates() {
        let firstController = ConnectedGameController(id: "first",
                                                      vendorName: "USB Gamepad",
                                                      productCategory: "",
                                                      duplicateIndex: 0,
                                                      duplicateCount: 2)
        let secondController = ConnectedGameController(id: "second",
                                                       vendorName: "USB Gamepad",
                                                       productCategory: "External HID Device",
                                                       duplicateIndex: 1,
                                                       duplicateCount: 2)

        XCTAssertEqual(firstController.title, "USB Gamepad #1")
        XCTAssertEqual(secondController.title, "USB Gamepad #2")
        XCTAssertEqual(firstController.detailTitle, "Game controller")
        XCTAssertEqual(secondController.detailTitle, "External HID Device")
        XCTAssertEqual(
            ConnectedGameController.identifier(vendorName: "USB Gamepad",
                                               productCategory: "External HID Device",
                                               duplicateIndex: 1),
            "name=USB Gamepad|category=External HID Device|index=1"
        )
    }

    func testGameControllerJoystickMappingStoresPreferredControllerDescriptor() {
        let controller = ConnectedGameController(id: "controller-id",
                                                 vendorName: "USB Gamepad",
                                                 productCategory: "",
                                                 duplicateIndex: 0,
                                                 duplicateCount: 1)
        var mapping = GameControllerJoystickMapping.standard

        mapping.setPreferredController(controller)

        XCTAssertEqual(mapping.preferredControllerIdentifier, "controller-id")
        XCTAssertEqual(mapping.preferredControllerName, "USB Gamepad")

        mapping.setPreferredController(nil)

        XCTAssertNil(mapping.preferredControllerIdentifier)
        XCTAssertNil(mapping.preferredControllerName)
    }

    func testMediaLibraryImportsManagedCopyAndDeduplicatesByHash() throws {
        let rootURL = temporaryDirectoryURL("MediaLibrary")
        let sourceDirectoryURL = temporaryDirectoryURL("MediaLibrarySources")
        let sourceURL = sourceDirectoryURL.appendingPathComponent("my_game.prg")
        defer {
            try? FileManager.default.removeItem(at: rootURL)
            try? FileManager.default.removeItem(at: sourceDirectoryURL)
        }

        try FileManager.default.createDirectory(at: sourceDirectoryURL,
                                                withIntermediateDirectories: true)
        try Data([0x01, 0x08, 0x60]).write(to: sourceURL)

        let store = try MediaLibraryStore(rootURL: rootURL)
        let imported = try store.importURLs([sourceURL])

        XCTAssertEqual(imported.count, 1)

        let item = try XCTUnwrap(imported.first)
        let managedURL = store.primaryFileURL(for: item)

        XCTAssertTrue(managedURL.path.hasPrefix(rootURL.path))
        XCTAssertNotEqual(managedURL.path, sourceURL.path)
        XCTAssertTrue(FileManager.default.fileExists(atPath: managedURL.path))
        XCTAssertEqual(item.title, "my game")
        XCTAssertEqual(item.primaryFile.originalPath, sourceURL.path)
        XCTAssertEqual(item.primaryFile.kind, .program)
        XCTAssertEqual(item.primaryFile.mediaType, "prg")

        let duplicateImport = try store.importURLs([sourceURL])
        XCTAssertEqual(duplicateImport.first?.id, item.id)
        XCTAssertEqual(try store.items().count, 1)

        try FileManager.default.removeItem(at: managedURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: managedURL.path))

        let restoredDuplicateImport = try store.importURLs([sourceURL])
        XCTAssertEqual(restoredDuplicateImport.first?.id, item.id)
        XCTAssertEqual(try store.items().count, 1)
        XCTAssertEqual(try Data(contentsOf: managedURL), try Data(contentsOf: sourceURL))

        try store.removeItem(id: item.id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: managedURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertEqual(try store.items().count, 0)
    }

    func testMediaLibraryRefreshUpdatesDiskDirectoryMetadata() throws {
        let rootURL = temporaryDirectoryURL("MediaLibraryDiskRefresh")
        let sourceDirectoryURL = temporaryDirectoryURL("MediaLibraryDiskRefreshSources")
        let sourceURL = sourceDirectoryURL.appendingPathComponent("work_disk.d64")
        defer {
            try? FileManager.default.removeItem(at: rootURL)
            try? FileManager.default.removeItem(at: sourceDirectoryURL)
        }

        try FileManager.default.createDirectory(at: sourceDirectoryURL,
                                                withIntermediateDirectories: true)
        _ = try DiskImageService.createBlankImage(at: sourceURL,
                                                  format: .d64,
                                                  diskName: "WORK DISK",
                                                  diskID: "VM")

        let store = try MediaLibraryStore(rootURL: rootURL)
        let item = try XCTUnwrap(try store.importURLs([sourceURL]).first)
        let managedURL = store.primaryFileURL(for: item)
        let originalHash = item.primaryFile.sha256

        XCTAssertTrue(item.entries.isEmpty)

        var managedImage = try DiskImageService.openImage(url: managedURL)
        try managedImage.importFile(named: "HELLO",
                                    payload: Data([0x01, 0x08, 0x60]))
        try managedImage.save()

        let staleItem = try XCTUnwrap(try store.items().first { $0.id == item.id })
        XCTAssertFalse(staleItem.entries.contains { $0.name.caseInsensitiveCompare("HELLO") == .orderedSame })

        let refreshedItem = try XCTUnwrap(try store.refreshItemMetadata(id: item.id))

        XCTAssertNotEqual(refreshedItem.primaryFile.sha256, originalHash)
        XCTAssertTrue(refreshedItem.entries.contains { $0.name.caseInsensitiveCompare("HELLO") == .orderedSame })
    }

    func testMediaLibraryCachesArtworkBesideManagedMediaAndPersistsMetadata() throws {
        let rootURL = temporaryDirectoryURL("MediaLibraryArtwork")
        let sourceDirectoryURL = temporaryDirectoryURL("MediaLibraryArtworkSources")
        let sourceURL = sourceDirectoryURL.appendingPathComponent("cover_test.prg")
        defer {
            try? FileManager.default.removeItem(at: rootURL)
            try? FileManager.default.removeItem(at: sourceDirectoryURL)
        }

        try FileManager.default.createDirectory(at: sourceDirectoryURL,
                                                withIntermediateDirectories: true)
        try Data([0x01, 0x08, 0x60]).write(to: sourceURL)

        let store = try MediaLibraryStore(rootURL: rootURL)
        let item = try XCTUnwrap(try store.importURLs([sourceURL]).first)
        let coverData = Data([0x89, 0x50, 0x4e, 0x47, 0x01])
        let coverSourceURL = try XCTUnwrap(URL(string: "https://example.test/cover.png"))

        let artwork = try store.cacheArtwork(coverData,
                                             kind: .boxFront,
                                             itemID: item.id,
                                             sourceURL: coverSourceURL,
                                             fileExtension: "png",
                                             width: 320,
                                             height: 200)
        let artworkURL = store.artworkURL(for: artwork)

        XCTAssertTrue(artwork.relativePath.hasPrefix("Artwork/\(item.id.uuidString)/"))
        XCTAssertEqual(artwork.kind, .boxFront)
        XCTAssertEqual(artwork.sourceURL, coverSourceURL.absoluteString)
        XCTAssertEqual(artwork.byteCount, Int64(coverData.count))
        XCTAssertEqual(artwork.width, 320)
        XCTAssertEqual(artwork.height, 200)
        XCTAssertEqual(try Data(contentsOf: artworkURL), coverData)

        let reloadedItem = try XCTUnwrap(try store.items().first { $0.id == item.id })
        XCTAssertEqual(reloadedItem.artwork.count, 1)
        XCTAssertEqual(reloadedItem.artwork.first?.id, artwork.id)
        XCTAssertEqual(reloadedItem.artwork.first?.relativePath, artwork.relativePath)

        let replacementData = Data([0xff, 0xd8, 0xff])
        let replacement = try store.cacheArtwork(replacementData,
                                                 kind: .boxFront,
                                                 itemID: item.id,
                                                 fileExtension: "jpg")

        XCTAssertEqual(replacement.id, artwork.id)
        XCTAssertEqual(try store.artwork(for: item.id).count, 1)
        XCTAssertEqual(try Data(contentsOf: store.artworkURL(for: replacement)), replacementData)
        XCTAssertFalse(FileManager.default.fileExists(atPath: artworkURL.path))

        try store.updateMetadata(itemID: item.id,
                                 title: "Cover Test Deluxe",
                                 notes: "Metadata: TheGamesDB 123")
        let metadataItem = try XCTUnwrap(try store.items().first { $0.id == item.id })
        XCTAssertEqual(metadataItem.title, "Cover Test Deluxe")
        XCTAssertEqual(metadataItem.notes, "Metadata: TheGamesDB 123")
        XCTAssertEqual(metadataItem.artwork.first?.id, replacement.id)

        try store.removeItem(id: item.id)

        XCTAssertFalse(FileManager.default.fileExists(atPath: store.primaryFileURL(for: item).path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: replacement.url(in: rootURL).deletingLastPathComponent().path))
    }

    @MainActor
    func testDiskImageManagerOpenRequestsCarryMediaLibraryContext() throws {
        let requests = DiskImageManagerOpenRequests()
        let itemID = UUID()
        let firstURL = URL(fileURLWithPath: "/tmp/first.d64")
        let secondURL = URL(fileURLWithPath: "/tmp/second.d64")

        requests.open(url: firstURL,
                      in: .right,
                      mediaLibraryItemID: itemID)

        let firstRequest = requests.pendingRequest
        XCTAssertEqual(firstRequest?.url, firstURL)
        XCTAssertEqual(firstRequest?.pane, .right)
        XCTAssertEqual(firstRequest?.mediaLibraryItemID, itemID)

        requests.open(url: secondURL, in: .left)
        requests.clear(try XCTUnwrap(firstRequest))

        XCTAssertEqual(requests.pendingRequest?.url, secondURL)

        requests.clear(try XCTUnwrap(requests.pendingRequest))

        XCTAssertNil(requests.pendingRequest)
    }

    func testQLinkReloadedDiskPatcherConfiguresConnectionAndPreservesAccountProfile() throws {
        var data = makeQLinkD64ProfileFixture()
        let originalProfile = try QLinkReloadedDiskPatcher.decryptedProfileSector(from: data)

        let changed = try QLinkReloadedDiskPatcher.configureReloadedProfile(in: &data)
        let patchedProfile = try QLinkReloadedDiskPatcher.decryptedProfileSector(from: data)

        XCTAssertTrue(changed)
        XCTAssertEqual(Array(patchedProfile[0..<6]), [5, 1, 2, 0, 0x44, 1])
        XCTAssertEqual(Array(patchedProfile[30..<50]),
                       [5, 5, 5, 1, 2, 1, 2] + Array(repeating: 0x80, count: 13))
        XCTAssertEqual(Array(patchedProfile[9..<30]), Array(originalProfile[9..<30]))
        XCTAssertEqual(Array(patchedProfile[50..<201]), Array(originalProfile[50..<201]))

        let secondPatchChangedDisk = try QLinkReloadedDiskPatcher.configureReloadedProfile(in: &data)
        XCTAssertFalse(secondPatchChangedDisk)
    }

    func testQLinkReloadedDiskPatcherExtractsRegistrationProfileByAccessNumberAndScreenName() throws {
        let data = makeQLinkD64ProfileFixture(accessNumber: "5974",
                                              screenName: "BarryWalkr")

        let registration = try XCTUnwrap(QLinkReloadedDiskPatcher.registrationProfile(from: data))

        XCTAssertEqual(registration.accessNumber, "5974")
        XCTAssertEqual(registration.accessCode, "5974")
        XCTAssertEqual(registration.accountID, "0000005974")
        XCTAssertEqual(registration.accountDisplayTitle, "5974")
        XCTAssertEqual(registration.handle, "BARRYWALKR")
        XCTAssertEqual(registration.decryptedProfile.count, 256)
    }

    func testQLinkReloadedDiskPatcherIgnoresPlaceholderRegistrationProfile() throws {
        let data = makeQLinkD64ProfileFixture(accessNumber: "1")

        XCTAssertNil(try QLinkReloadedDiskPatcher.registrationProfile(from: data))
    }

    func testQLinkReloadedRegistrationProfileDecodesLegacyUsernamePayload() throws {
        struct LegacyProfile: Encodable {
            var username: String
            var decryptedProfileData: Data
        }

        let data = makeQLinkD64ProfileFixture(accessNumber: "5974",
                                              screenName: "BarryWalkr")
        let registration = try XCTUnwrap(QLinkReloadedDiskPatcher.registrationProfile(from: data))
        let legacyData = try JSONEncoder().encode(LegacyProfile(username: registration.accessNumber,
                                                                decryptedProfileData: registration.decryptedProfileData))

        let decoded = try JSONDecoder().decode(QLinkReloadedRegistrationProfile.self, from: legacyData)

        XCTAssertEqual(decoded.accessNumber, "5974")
        XCTAssertEqual(decoded.accessCode, "5974")
        XCTAssertEqual(decoded.accountID, "0000005974")
        XCTAssertEqual(decoded.handle, "BARRYWALKR")
    }

    func testQLinkReloadedDiskPatcherRestoresSavedRegistrationAndForcesConnectionSettings() throws {
        let savedData = makeQLinkD64ProfileFixture(accessNumber: "5974",
                                                   screenName: "BarryWalkr")
        let savedRegistration = try XCTUnwrap(QLinkReloadedDiskPatcher.registrationProfile(from: savedData))
        var blankData = makeQLinkD64ProfileFixture(accessNumber: "1")

        let changed = try QLinkReloadedDiskPatcher.configureReloadedProfile(in: &blankData,
                                                                            restoring: savedRegistration)
        let patchedProfile = try QLinkReloadedDiskPatcher.decryptedProfileSector(from: blankData)

        XCTAssertTrue(changed)
        XCTAssertEqual(Array(patchedProfile[0..<6]), [5, 1, 2, 0, 0x44, 1])
        XCTAssertEqual(Array(patchedProfile[30..<50]),
                       [5, 5, 5, 1, 2, 1, 2] + Array(repeating: 0x80, count: 13))
        XCTAssertEqual(Array(patchedProfile[9..<30]), Array(savedRegistration.decryptedProfile[9..<30]))
        XCTAssertEqual(Array(patchedProfile[50..<201]), Array(savedRegistration.decryptedProfile[50..<201]))
        let restoredRegistration = try XCTUnwrap(QLinkReloadedDiskPatcher.registrationProfile(from: blankData))
        XCTAssertEqual(restoredRegistration.accessNumber, "5974")
        XCTAssertEqual(restoredRegistration.handle, "BARRYWALKR")
    }

    func testQLinkReloadedDiskPatcherRepairsClearedPlaceholderUserSlot() throws {
        var data = makeQLinkD64ProfileFixture(accessNumber: "1")
        var profile = try QLinkReloadedDiskPatcher.decryptedProfileSector(from: data)
        profile.replaceSubrange(50..<201, with: Array(repeating: UInt8(0), count: 151))
        data.replaceSubrange(qLinkProfileSectorRange(), with: encryptedQLinkProfile(profile))

        let changed = try QLinkReloadedDiskPatcher.configureReloadedProfile(in: &data)
        let patchedProfile = try QLinkReloadedDiskPatcher.decryptedProfileSector(from: data)

        XCTAssertTrue(changed)
        XCTAssertNil(try QLinkReloadedDiskPatcher.registrationProfile(from: data))
        XCTAssertEqual(Array(patchedProfile[9..<30]), qLinkFactoryBlankAccessNumberProfile())
        XCTAssertEqual(Array(patchedProfile[50..<201]), qLinkFactoryBlankUserRecordBlock())
    }

    func testQLinkReloadedDiskPatcherRemovesRegistrationProfileAndForcesConnectionSettings() throws {
        var data = makeQLinkD64ProfileFixture(accessNumber: "5974",
                                              screenName: "BarryWalkr")
        XCTAssertNotNil(try QLinkReloadedDiskPatcher.registrationProfile(from: data))

        let changed = try QLinkReloadedDiskPatcher.removeRegistrationProfile(in: &data)
        let patchedProfile = try QLinkReloadedDiskPatcher.decryptedProfileSector(from: data)

        XCTAssertTrue(changed)
        XCTAssertNil(try QLinkReloadedDiskPatcher.registrationProfile(from: data))
        XCTAssertEqual(Array(patchedProfile[0..<6]), [5, 1, 2, 0, 0x44, 1])
        XCTAssertEqual(Array(patchedProfile[30..<50]),
                       [5, 5, 5, 1, 2, 1, 2] + Array(repeating: 0x80, count: 13))
        XCTAssertEqual(Array(patchedProfile[9..<30]), qLinkFactoryBlankAccessNumberProfile())
        XCTAssertEqual(Array(patchedProfile[50..<201]), qLinkFactoryBlankUserRecordBlock())

        let secondPatchChangedDisk = try QLinkReloadedDiskPatcher.removeRegistrationProfile(in: &data)
        XCTAssertFalse(secondPatchChangedDisk)
    }

    func testQLinkReloadedDiskPatcherExtractsAllDiskProfilesAndReportsCapacity() throws {
        let data = makeQLinkD64ProfileFixture(accessNumber: "5974",
                                              screenNames: ["BarryWalkr", "JASMAZ"])

        let registrations = try QLinkReloadedDiskPatcher.registrationProfiles(from: data)

        XCTAssertEqual(QLinkReloadedDiskPatcher.maximumRegistrationProfileCount, 10)
        XCTAssertEqual(registrations.map(\.accessNumber), ["5974", "5974"])
        XCTAssertEqual(registrations.map(\.handle), ["BARRYWALKR", "JASMAZ"])
        XCTAssertEqual(registrations.map(\.id), ["barrywalkr", "jasmaz"])
    }

    func testQLinkReloadedDiskPatcherAddsRegistrationProfileToDisk() throws {
        var data = makeQLinkD64ProfileFixture(accessNumber: "5974",
                                              screenNames: ["BarryWalkr"])
        let savedData = makeQLinkD64ProfileFixture(accessNumber: "5974",
                                                   screenNames: ["JASMAZ"])
        let savedRegistration = try XCTUnwrap(QLinkReloadedDiskPatcher.registrationProfile(from: savedData))

        let changed = try QLinkReloadedDiskPatcher.addRegistrationProfile(savedRegistration,
                                                                          in: &data)
        let patchedProfile = try QLinkReloadedDiskPatcher.decryptedProfileSector(from: data)
        let registrations = try QLinkReloadedDiskPatcher.registrationProfiles(from: data)

        XCTAssertTrue(changed)
        XCTAssertEqual(Array(patchedProfile[0..<6]), [5, 1, 2, 0, 0x44, 1])
        XCTAssertEqual(registrations.map(\.handle), ["BARRYWALKR", "JASMAZ"])
        XCTAssertEqual(patchedProfile[50], 2)
    }

    func testQLinkReloadedDiskPatcherReplacesMatchingRegistrationProfileOnDisk() throws {
        var data = makeQLinkD64ProfileFixture(accessNumber: "5974",
                                              screenNames: ["BarryWalkr", "JASMAZ"])
        var savedData = makeQLinkD64ProfileFixture(accessNumber: "5974",
                                                   screenNames: ["JASMAZ"])
        var savedProfile = try QLinkReloadedDiskPatcher.decryptedProfileSector(from: savedData)
        savedProfile[51] = 0x7f
        savedData.replaceSubrange(qLinkProfileSectorRange(), with: encryptedQLinkProfile(savedProfile))
        let savedRegistration = try XCTUnwrap(QLinkReloadedDiskPatcher.registrationProfile(from: savedData))

        let changed = try QLinkReloadedDiskPatcher.addRegistrationProfile(savedRegistration,
                                                                          in: &data)
        let patchedRegistrations = try QLinkReloadedDiskPatcher.registrationProfiles(from: data)

        XCTAssertTrue(changed)
        XCTAssertEqual(patchedRegistrations.map(\.handle), ["BARRYWALKR", "JASMAZ"])
        XCTAssertEqual(patchedRegistrations[1].userRecord.first, 0x7f)
    }

    func testQLinkReloadedDiskPatcherRemovesRegistrationProfileAndCompactsDiskSlots() throws {
        var data = makeQLinkD64ProfileFixture(accessNumber: "5974",
                                              screenNames: ["BarryWalkr", "JASMAZ", "NIGHTOWL"])

        let changed = try QLinkReloadedDiskPatcher.removeRegistrationProfile(id: "jasmaz",
                                                                             in: &data)
        let patchedProfile = try QLinkReloadedDiskPatcher.decryptedProfileSector(from: data)
        let registrations = try QLinkReloadedDiskPatcher.registrationProfiles(from: data)

        XCTAssertTrue(changed)
        XCTAssertEqual(patchedProfile[50], 2)
        XCTAssertEqual(registrations.map(\.handle), ["BARRYWALKR", "NIGHTOWL"])
        XCTAssertEqual(Array(patchedProfile[66..<81]), qLinkUserRecord(screenName: "NIGHTOWL", accountID: "0000005976"))
        XCTAssertEqual(Array(patchedProfile[81..<96]), Array(repeating: UInt8(0), count: 15))
    }

    func testQLinkReloadedDiskPatcherRestoresFactoryBlankWhenLastRegistrationProfileRemoved() throws {
        var data = makeQLinkD64ProfileFixture(accessNumber: "5974",
                                              screenNames: ["BarryWalkr"])

        let changed = try QLinkReloadedDiskPatcher.removeRegistrationProfile(id: "barrywalkr",
                                                                             in: &data)
        let patchedProfile = try QLinkReloadedDiskPatcher.decryptedProfileSector(from: data)

        XCTAssertTrue(changed)
        XCTAssertNil(try QLinkReloadedDiskPatcher.registrationProfile(from: data))
        XCTAssertEqual(Array(patchedProfile[9..<30]), qLinkFactoryBlankAccessNumberProfile())
        XCTAssertEqual(Array(patchedProfile[50..<201]), qLinkFactoryBlankUserRecordBlock())
    }

    func testQLinkReloadedDiskPatcherRejectsAddingRegistrationProfileToFullDisk() throws {
        var data = makeQLinkD64ProfileFixture(accessNumber: "5974",
                                              screenNames: (0..<10).map { "USER\($0)" })
        let savedData = makeQLinkD64ProfileFixture(accessNumber: "5974",
                                                   screenNames: ["EXTRA"])
        let savedRegistration = try XCTUnwrap(QLinkReloadedDiskPatcher.registrationProfile(from: savedData))

        XCTAssertThrowsError(try QLinkReloadedDiskPatcher.addRegistrationProfile(savedRegistration,
                                                                                 in: &data)) { error in
            XCTAssertEqual(error as? QLinkReloadedServiceError, .diskProfileLimitReached)
        }

    }

    func testQLinkReloadedRegistrationStoreKeepsOneProfilePerUsername() throws {
        let store = QLinkReloadedRegistrationMemoryStore()
        let firstData = makeQLinkD64ProfileFixture(accessNumber: "5974")
        var secondData = makeQLinkD64ProfileFixture(accessNumber: "5974")
        var secondProfile = try QLinkReloadedDiskPatcher.decryptedProfileSector(from: secondData)
        secondProfile[51] = 0x7f
        secondData.replaceSubrange(qLinkProfileSectorRange(), with: encryptedQLinkProfile(secondProfile))

        store.saveRegistration(try XCTUnwrap(QLinkReloadedDiskPatcher.registrationProfile(from: firstData)))
        store.saveRegistration(try XCTUnwrap(QLinkReloadedDiskPatcher.registrationProfile(from: secondData)))

        XCTAssertEqual(store.registrations().count, 1)
        XCTAssertEqual(store.loadRegistration(id: "barrywalkr")?.userRecord.first, 0x7f)
    }

    func testQLinkReloadedDiskPatcherWritesOnlyRequestedManagedCopy() throws {
        let rootURL = temporaryDirectoryURL("QLinkReloadedPatchCopy")
        let sourceURL = rootURL.appendingPathComponent("QuantumLink.d64")
        let managedCopyURL = rootURL.appendingPathComponent("ManagedQuantumLink.d64")
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        try FileManager.default.createDirectory(at: rootURL,
                                                withIntermediateDirectories: true)
        let sourceData = makeQLinkD64ProfileFixture()
        try sourceData.write(to: sourceURL)
        try sourceData.write(to: managedCopyURL)

        let version = QLinkReloadedDiskVersion(profileAgnosticSHA256: "fixture",
                                               displayTitle: "Fixture Q-Link")
        let result = try QLinkReloadedDiskPatcher.configureReloadedProfile(at: managedCopyURL,
                                                                           version: version)

        XCTAssertTrue(result.changedDisk)
        XCTAssertEqual(try Data(contentsOf: sourceURL), sourceData)
        XCTAssertNotEqual(try Data(contentsOf: managedCopyURL), sourceData)
    }

    func testQLinkReloadedDiskPatcherAcceptsDevelopmentNGDiskWithoutFingerprint() throws {
        let data = try makeQLinkDevelopmentNGD64Data()

        let version = try QLinkReloadedDiskPatcher.knownVersion(for: data)

        XCTAssertEqual(version.displayTitle, "Q-Link NG Development")
        XCTAssertFalse(version.requiresLegacyPatch)
        XCTAssertTrue(QLinkReloadedDiskPatcher.isDevelopmentNGDisk(data))
    }

    func testQLinkReloadedDiskPatcherRejectsGenericBootDiskAsUnknownVersion() throws {
        let data = try makeQLinkDevelopmentNGD64Data(programNames: ["BOOT64"])

        XCTAssertFalse(QLinkReloadedDiskPatcher.isDevelopmentNGDisk(data))
        XCTAssertThrowsError(try QLinkReloadedDiskPatcher.knownVersion(for: data)) { error in
            XCTAssertEqual(error as? QLinkReloadedServiceError, .unknownVersion)
        }
    }

    func testQLinkReloadedDiskPatcherDoesNotPatchDevelopmentNGDisk() throws {
        let url = temporaryURL(pathExtension: "d64")
        let data = try makeQLinkDevelopmentNGD64Data()
        try data.write(to: url)
        let version = try QLinkReloadedDiskPatcher.knownVersion(for: data)

        let result = try QLinkReloadedDiskPatcher.configureReloadedProfile(at: url,
                                                                           version: version)

        XCTAssertFalse(result.changedDisk)
        XCTAssertEqual(result.version, version)
        XCTAssertEqual(try Data(contentsOf: url), data)
    }

    func testQLinkReloadedDiskPatcherRejectsLegacyProfileWritesForDevelopmentNGDisk() throws {
        let url = temporaryURL(pathExtension: "d64")
        let data = try makeQLinkDevelopmentNGD64Data()
        try data.write(to: url)
        let version = try QLinkReloadedDiskPatcher.knownVersion(for: data)
        let registration = try XCTUnwrap(QLinkReloadedDiskPatcher.registrationProfile(from: makeQLinkD64ProfileFixture()))

        XCTAssertThrowsError(try QLinkReloadedDiskPatcher.addRegistrationProfile(registration,
                                                                                 at: url,
                                                                                 version: version)) { error in
            XCTAssertEqual(error as? QLinkReloadedServiceError, .legacyProfileStorageUnavailable)
        }
        XCTAssertThrowsError(try QLinkReloadedDiskPatcher.removeRegistrationProfile(id: registration.id,
                                                                                    at: url,
                                                                                    version: version)) { error in
            XCTAssertEqual(error as? QLinkReloadedServiceError, .legacyProfileStorageUnavailable)
        }
        XCTAssertThrowsError(try QLinkReloadedDiskPatcher.removeRegistrationProfile(at: url,
                                                                                    version: version)) { error in
            XCTAssertEqual(error as? QLinkReloadedServiceError, .legacyProfileStorageUnavailable)
        }
        XCTAssertEqual(try Data(contentsOf: url), data)
    }

    @MainActor
    func testMetadataIngestionSettingsPersistProviderAndMatchingConfiguration() throws {
        let defaults = try temporaryUserDefaults("MetadataProvider")
        let credentialStore = MetadataIngestionMemoryCredentialStore()
        let settings = MetadataIngestionSettings(defaults: defaults,
                                                 credentialStore: credentialStore)

        settings.setEnabled(true, for: .theGamesDB)
        settings.setCredential("tgdb-key", providerID: .theGamesDB, field: .apiKey)
        settings.matchStrategy = .hashFirst
        settings.cachesArtworkLocally = false
        settings.artworkPreference = .screenshot

        let reloadedSettings = MetadataIngestionSettings(defaults: defaults,
                                                         credentialStore: credentialStore)
        let configuration = reloadedSettings.configuration(for: .theGamesDB)
        let snapshot = try XCTUnwrap(reloadedSettings.providerSnapshots.first { $0.providerID == .theGamesDB })

        XCTAssertTrue(configuration.isEnabled)
        XCTAssertEqual(reloadedSettings.matchStrategy, .hashFirst)
        XCTAssertFalse(reloadedSettings.cachesArtworkLocally)
        XCTAssertEqual(reloadedSettings.artworkPreference, .screenshot)
        XCTAssertTrue(snapshot.isReady)
        XCTAssertEqual(snapshot.statusTitle, "Enabled")
    }

    func testMetadataProvidersExposeDocumentedArtworkCapabilities() {
        XCTAssertFalse(MetadataProviderID.allCases.map(\.rawValue).contains("mobyGames"))
        XCTAssertFalse(MetadataProviderID.activeProviderIDs.map(\.rawValue).contains("mobyGames"))

        XCTAssertFalse(MetadataProviderID.gameBase64.supportsArtwork)
        XCTAssertEqual(MetadataProviderID.gameBase64.supportedArtworkPreferences, [])

        XCTAssertEqual(MetadataProviderID.igdb.supportedArtworkPreferences, [.boxFront, .screenshot])
        XCTAssertEqual(MetadataProviderID.theGamesDB.supportedArtworkPreferences, [.boxFront, .screenshot, .titleScreen])
        XCTAssertTrue(MetadataProviderID.theGamesDB.supportsMediaLibraryMetadataSearch)

        XCTAssertFalse(MetadataProviderID.csdb.supportsArtwork)
    }

    @MainActor
    func testMetadataSettingsIgnoreRemovedAndUnknownStoredProviders() throws {
        let defaults = try temporaryUserDefaults("RemovedMetadataProvider")
        let storedConfigurationJSON = """
        [
          { "providerID": "mobyGames", "isEnabled": true, "databasePath": "/tmp/moby.mdb" },
          { "providerID": "missingProvider", "isEnabled": true },
          { "providerID": "theGamesDB", "isEnabled": true }
        ]
        """
        defaults.set(Data(storedConfigurationJSON.utf8), forKey: "vice.metadata.providers")

        let settings = MetadataIngestionSettings(defaults: defaults,
                                                 credentialStore: MetadataIngestionMemoryCredentialStore())

        XCTAssertTrue(settings.configuration(for: .theGamesDB).isEnabled)
        XCTAssertEqual(settings.providerSnapshots.map(\.providerID),
                       MetadataProviderID.activeProviderIDs)
        XCTAssertFalse(settings.providerSnapshots.map(\.providerID.rawValue).contains("mobyGames"))
    }

    func testTheGamesDBSearchResponseParsesMetadataAndArtworkURL() throws {
        let json = """
        {
          "data": {
            "count": 1,
            "games": [
              {
                "id": 53,
                "game_title": "Impossible Mission",
                "release_date": "1984-01-01",
                "platform": 40,
                "overview": "Stay a while. Stay forever."
              }
            ]
          },
          "include": {
            "boxart": {
              "base_url": {
                "original": "https://cdn.thegamesdb.net/images/original/",
                "small": "https://cdn.thegamesdb.net/images/small/",
                "thumb": "https://cdn.thegamesdb.net/images/thumb/",
                "medium": "https://cdn.thegamesdb.net/images/medium/",
                "large": "https://cdn.thegamesdb.net/images/large/"
              },
              "data": {
                "53": [
                  {
                    "id": 17438,
                    "type": "boxart",
                    "side": "front",
                    "filename": "boxart/front/53-1.jpg",
                    "resolution": "1521x2156"
                  }
                ]
              }
            },
            "platform": {
              "data": {
                "40": {
                  "id": 40,
                  "name": "Commodore 64"
                }
              }
            }
          }
        }
        """.data(using: .utf8)!

        let results = try TheGamesDBMetadataClient.searchResults(from: json,
                                                                 artworkPreference: .boxFront)
        let result = try XCTUnwrap(results.first)

        XCTAssertEqual(result.id, "theGamesDB:53")
        XCTAssertEqual(result.providerID, .theGamesDB)
        XCTAssertEqual(result.externalID, "53")
        XCTAssertEqual(result.title, "Impossible Mission")
        XCTAssertEqual(result.platformName, "Commodore 64")
        XCTAssertEqual(result.releaseDate, "1984-01-01")
        XCTAssertEqual(result.overview, "Stay a while. Stay forever.")
        XCTAssertEqual(result.artworkURL?.absoluteString, "https://cdn.thegamesdb.net/images/large/boxart/front/53-1.jpg")
    }

    @MainActor
    func testMetadataIngestionSettingsUseCredentialsForAPIReadiness() throws {
        let defaults = try temporaryUserDefaults("MetadataCredentials")
        let credentialStore = MetadataIngestionMemoryCredentialStore()
        let settings = MetadataIngestionSettings(defaults: defaults,
                                                 credentialStore: credentialStore)

        XCTAssertFalse(try metadataSnapshot(.igdb, in: settings).isReady)

        settings.setCredential("client-1", providerID: .igdb, field: .clientID)

        XCTAssertFalse(try metadataSnapshot(.igdb, in: settings).isReady)

        settings.setCredential("token-1", providerID: .igdb, field: .accessToken)
        settings.setEnabled(true, for: .igdb)

        let configuredSnapshot = try metadataSnapshot(.igdb, in: settings)
        XCTAssertTrue(configuredSnapshot.isReady)
        XCTAssertEqual(configuredSnapshot.statusTitle, "Enabled")
        XCTAssertEqual(settings.credential(providerID: .igdb, field: .clientID), "client-1")
        XCTAssertEqual(settings.credential(providerID: .igdb, field: .accessToken), "token-1")

        settings.clearCredentials(for: .igdb)

        XCTAssertFalse(try metadataSnapshot(.igdb, in: settings).isReady)
    }

    @MainActor
    func testMetadataIngestionSettingsKeepUnsupportedSourcesDisabled() throws {
        let defaults = try temporaryUserDefaults("MetadataUnsupported")
        let settings = MetadataIngestionSettings(defaults: defaults,
                                                 credentialStore: MetadataIngestionMemoryCredentialStore())

        settings.setEnabled(true, for: .csdb)

        let configuration = settings.configuration(for: .csdb)
        let snapshot = try metadataSnapshot(.csdb, in: settings)

        XCTAssertFalse(configuration.isEnabled)
        XCTAssertFalse(snapshot.isReady)
        XCTAssertEqual(snapshot.statusTitle, "Unavailable")
    }

    @MainActor
    func testMetadataIngestionSettingsImportGameBase64MDBIntoManagedStorage() throws {
        let defaults = try temporaryUserDefaults("MetadataGameBase64MDB")
        let metadataDirectoryURL = temporaryDirectoryURL("MetadataSources")
        let sourceDirectoryURL = temporaryDirectoryURL("MetadataSourceFiles")
        try FileManager.default.createDirectory(at: sourceDirectoryURL, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: metadataDirectoryURL)
            try? FileManager.default.removeItem(at: sourceDirectoryURL)
        }

        let sourceURL = sourceDirectoryURL.appendingPathComponent("GBC_v19.mdb")
        let databaseData = fakeAccessDatabaseData()
        try databaseData.write(to: sourceURL)
        let settings = MetadataIngestionSettings(defaults: defaults,
                                                 credentialStore: MetadataIngestionMemoryCredentialStore(),
                                                 metadataSourceDirectoryURL: metadataDirectoryURL)

        let result = try settings.importDatabasePackage(sourceURL, for: .gameBase64)

        let configuration = settings.configuration(for: .gameBase64)
        let snapshot = try metadataSnapshot(.gameBase64, in: settings)

        XCTAssertEqual(MetadataProviderID.gameBase64.connectionKind, .importedDatabase)
        XCTAssertEqual(MetadataProviderID.gameBase64.importFilenameExtensions, ["mdb", "zip", "exe"])
        XCTAssertEqual(result.packageKind, .accessDatabase)
        XCTAssertTrue(result.databaseURL.path.hasPrefix(metadataDirectoryURL.path))
        XCTAssertEqual(configuration.databasePath, result.databaseURL.path)
        XCTAssertNotNil(configuration.lastImportedAt)
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.databaseURL.path))
        XCTAssertEqual(try Data(contentsOf: result.databaseURL), databaseData)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(snapshot.isReady)
        XCTAssertEqual(snapshot.statusTitle, "Ready")
    }

    func testGameBase64ImporterExtractsMDBFromZIPWithoutShellingOut() throws {
        let rootURL = temporaryDirectoryURL("GameBase64ZIPImport")
        let sourceDirectoryURL = temporaryDirectoryURL("GameBase64ZIPSources")
        try FileManager.default.createDirectory(at: sourceDirectoryURL, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: rootURL)
            try? FileManager.default.removeItem(at: sourceDirectoryURL)
        }

        let databaseData = fakeAccessDatabaseData()
        let zipURL = sourceDirectoryURL.appendingPathComponent("gb64v19.zip")
        try makeStoredZIP(filename: "Database/GBC_v19.mdb", contents: databaseData).write(to: zipURL)

        let result = try GameBase64MetadataImporter().importPackage(at: zipURL, into: rootURL)

        XCTAssertEqual(result.packageKind, .zipArchive)
        XCTAssertEqual(result.databaseURL.lastPathComponent, "GBC_v19.mdb")
        XCTAssertTrue(result.databaseURL.path.hasPrefix(rootURL.path))
        XCTAssertEqual(try Data(contentsOf: result.databaseURL), databaseData)
    }

    func testGameBase64ImporterUsesEmbeddedInnoExtractorBoundaryForInstallers() throws {
        let rootURL = temporaryDirectoryURL("GameBase64InstallerImport")
        let sourceDirectoryURL = temporaryDirectoryURL("GameBase64InstallerSources")
        try FileManager.default.createDirectory(at: sourceDirectoryURL, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: rootURL)
            try? FileManager.default.removeItem(at: sourceDirectoryURL)
        }

        let installerURL = sourceDirectoryURL.appendingPathComponent("gb64v19.exe")
        try fakeInnoSetupInstallerData().write(to: installerURL)
        let extractedDatabaseURL = sourceDirectoryURL.appendingPathComponent("GBC_v19.mdb")
        let databaseData = fakeAccessDatabaseData()
        try databaseData.write(to: extractedDatabaseURL)

        XCTAssertThrowsError(try GameBase64MetadataImporter().importPackage(at: installerURL, into: rootURL)) { error in
            XCTAssertEqual(error as? GameBase64MetadataImportError, .nativeInnoExtractorUnavailable)
        }

        let importer = GameBase64MetadataImporter(extractor: StubInnoSetupExtractor(databaseURL: extractedDatabaseURL))
        let result = try importer.importPackage(at: installerURL, into: rootURL)

        XCTAssertEqual(result.packageKind, .innoSetupInstaller)
        XCTAssertTrue(result.databaseURL.path.hasPrefix(rootURL.path))
        XCTAssertEqual(try Data(contentsOf: result.databaseURL), databaseData)
    }

    func testVIC20RAMExpansionPlanUsesBlockResources() {
        let plan = RAMExpansion.vic20_24k.resourcePlan(for: EmulatedMachine.xvic)

        XCTAssertTrue(plan.requiresHardReset)
        XCTAssertEqual(plan.value(for: "RAMBlock0"), 0)
        XCTAssertEqual(plan.value(for: "RAMBlock1"), 1)
        XCTAssertEqual(plan.value(for: "RAMBlock2"), 1)
        XCTAssertEqual(plan.value(for: "RAMBlock3"), 1)
        XCTAssertEqual(plan.value(for: "RAMBlock5"), 0)
    }

    func testVIC20RAMExpansionDisableStillRequiresHardReset() {
        let plan = RAMExpansion.none.resourcePlan(for: EmulatedMachine.xvic)

        XCTAssertTrue(plan.requiresHardReset)
        XCTAssertEqual(plan.value(for: "RAMBlock0"), 0)
        XCTAssertEqual(plan.value(for: "RAMBlock1"), 0)
        XCTAssertEqual(plan.value(for: "RAMBlock2"), 0)
        XCTAssertEqual(plan.value(for: "RAMBlock3"), 0)
        XCTAssertEqual(plan.value(for: "RAMBlock5"), 0)
    }

    func testREUResourcePlanSetsSizeBeforeEnable() {
        let plan = RAMExpansion.reu512.resourcePlan(for: EmulatedMachine.x64sc)

        XCTAssertFalse(plan.requiresHardReset)
        XCTAssertEqual(plan.enableAssignments.map(\.name), ["REUsize", "REU"])
        XCTAssertEqual(plan.value(for: "REUsize"), 512)
        XCTAssertEqual(plan.value(for: "REU"), 1)
    }

    func testMemorySpaceRawValuesMatchVICEMonitorMemspaces() {
        XCTAssertEqual(EmulatorSession.MemorySpace.computer.rawValue, 1)
        XCTAssertEqual(EmulatorSession.MemorySpace.drive8.rawValue, 2)
        XCTAssertEqual(EmulatorSession.MemorySpace.drive9.rawValue, 3)
        XCTAssertEqual(EmulatorSession.MemorySpace.drive10.rawValue, 4)
        XCTAssertEqual(EmulatorSession.MemorySpace.drive11.rawValue, 5)
    }

    func testFoundationModelAvailabilityMapsRuntimeReasons() {
        XCTAssertEqual(AIAssistantFoundationModelAvailability.from(systemAvailability: .available), .available)
        XCTAssertEqual(AIAssistantFoundationModelAvailability.from(systemAvailability: .unavailable(.deviceNotEligible)),
                       .unavailable(.deviceNotEligible))
        XCTAssertEqual(AIAssistantFoundationModelAvailability.from(systemAvailability: .unavailable(.appleIntelligenceNotEnabled)),
                       .unavailable(.appleIntelligenceNotEnabled))
        XCTAssertEqual(AIAssistantFoundationModelAvailability.from(systemAvailability: .unavailable(.modelNotReady)),
                       .unavailable(.modelNotReady))
    }

    func testFoundationModelUnavailableReasonsExplainDisabledAssistant() {
        let notEligible = AIAssistantFoundationModelAvailability.unavailable(.deviceNotEligible)
        let appleIntelligenceOff = AIAssistantFoundationModelAvailability.unavailable(.appleIntelligenceNotEnabled)
        let modelNotReady = AIAssistantFoundationModelAvailability.unavailable(.modelNotReady)

        XCTAssertFalse(notEligible.isAvailable)
        XCTAssertTrue(notEligible.detail.contains("does not support Apple Intelligence"))
        XCTAssertTrue(appleIntelligenceOff.detail.contains("Turn on Apple Intelligence"))
        XCTAssertTrue(modelNotReady.detail.contains("downloading or preparing"))
    }

    func testGEOSProgramValidatorAcceptsLinkedPRGPayload() {
        let prg = Data([0x00, 0x04, 0xa9, 0x00, 0x4c, 0x00, 0xc2])

        let validation = GEOSProgramValidator.validatePRG(prg, entryAddressText: "$0402")

        XCTAssertTrue(validation.canPackage)
        XCTAssertEqual(validation.loadAddress, 0x0400)
        XCTAssertEqual(validation.endAddress, 0x0404)
        XCTAssertEqual(validation.entryAddress, 0x0402)
        XCTAssertEqual(validation.payloadByteCount, 5)
    }

    func testGEOSProgramValidatorRejectsBrokenPRGInputs() {
        let tooShort = GEOSProgramValidator.validatePRG(Data([0x00]))
        XCTAssertFalse(tooShort.canPackage)
        XCTAssertTrue(tooShort.issues.contains { $0.title == "Missing load address" })

        var highPayload = Data([0x00, 0x7f])
        highPayload.append(Data(repeating: 0xea, count: 0x0101))
        let overlapsGEOS = GEOSProgramValidator.validatePRG(highPayload)
        XCTAssertFalse(overlapsGEOS.canPackage)
        XCTAssertTrue(overlapsGEOS.issues.contains { $0.title == "Payload overlaps GEOS workspace" })

        let entryOutside = GEOSProgramValidator.validatePRG(Data([0x00, 0x04, 0xea]), entryAddressText: "$0800")
        XCTAssertFalse(entryOutside.canPackage)
        XCTAssertTrue(entryOutside.issues.contains { $0.title == "Entry outside payload" })
    }

    func testGEOSProgramMetadataGeneratesConstrainedGRC() {
        var metadata = GEOSProgramMetadata()
        metadata.kind = .autoExec
        metadata.dosName = "MACVICE RTC"
        metadata.className = "MacVICE RTC"
        metadata.version = "V1.0"
        metadata.dosType = .usr
        metadata.mode = .any

        XCTAssertTrue(metadata.canGenerate)
        XCTAssertEqual(metadata.generatedGRC, """
        HEADER AUTO_EXEC "MACVICE RTC" "MacVICE RTC" "V1.0" {
        dostype USR
        mode any
        structure SEQ
        author "mac VICE"
        info "Synchronizes GEOS with the VICE DS1307 real-time clock."
        }

        """)

        metadata.dosName = "THIS NAME IS FAR TOO LONG"
        XCTAssertFalse(metadata.canGenerate)
        XCTAssertTrue(metadata.validationIssues.contains { $0.title == "DOS name is too long" })
    }

    func testGEOSPackageBuilderCreatesCVTRecords() throws {
        var metadata = GEOSProgramMetadata()
        metadata.kind = .autoExec
        metadata.dosName = "MACVICE RTC"
        metadata.className = "MacVICE RTC"
        metadata.version = "V1.0"
        metadata.dosType = .usr
        metadata.mode = .any

        let prg = Data([0x00, 0x04, 0xa9, 0x00, 0x4c, 0x2c, 0xc2])
        let package = try GEOSPackageBuilder.buildCVT(prgData: prg,
                                                       entryAddressText: "$0402",
                                                       metadata: metadata,
                                                       timestamp: GEOSFileTimestamp(year: 26, month: 5, day: 27, hour: 15, minute: 42))

        XCTAssertEqual(package.directoryRecord.count, GEOSCVTFile.recordSize)
        XCTAssertEqual(package.fileInfoRecord.count, GEOSCVTFile.recordSize)
        XCTAssertEqual(package.programPayload, prg.dropFirst(2))
        XCTAssertEqual(package.directoryRecord[0], 0x83)
        XCTAssertEqual(package.directoryRecord[22], 14)
        XCTAssertEqual(package.directoryRecord[23], 26)
        XCTAssertEqual(String(bytes: package.directoryRecord[30..<(30 + GEOSCVTFile.magic.count)], encoding: .ascii), GEOSCVTFile.magic)
        XCTAssertEqual(package.fileInfoRecord[66], 0x83)
        XCTAssertEqual(package.fileInfoRecord[67], 14)
        XCTAssertEqual(package.fileInfoRecord[68], 0)
        XCTAssertEqual(Int(package.fileInfoRecord[69]) | (Int(package.fileInfoRecord[70]) << 8), 0x0400)
        XCTAssertEqual(Int(package.fileInfoRecord[71]) | (Int(package.fileInfoRecord[72]) << 8), 0x0404)
        XCTAssertEqual(Int(package.fileInfoRecord[73]) | (Int(package.fileInfoRecord[74]) << 8), 0x0402)
        XCTAssertEqual(package.data.count, GEOSCVTFile.recordSize * 3)
    }

    func testCommodoreDiskImageReadsD64DirectoryAndFileData() throws {
        let payload = Data([0x01, 0x08, 0x0b, 0x08, 0x0a, 0x00, 0x99, 0x22, 0x48, 0x49, 0x22, 0x00])
        let url = try makeD64Image(name: "HELLO", payload: payload)
        let image = try CommodoreDiskImage(url: url)

        let entries = try image.directoryEntries()

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].name, "HELLO")
        XCTAssertEqual(entries[0].type, .prg)
        XCTAssertEqual(entries[0].blocks, 1)
        XCTAssertEqual(try image.fileData(for: entries[0]), payload)
        XCTAssertEqual(image.header.name, "VICE MAC")
        XCTAssertEqual(image.header.blocksFree, 663)
    }

    func testCommodoreDiskImageCopiesFileBetweenD64Images() throws {
        let sourceURL = try makeD64Image(name: "HELLO", payload: Data([0x01, 0x08, 0x00]))
        let destinationURL = try makeD64Image()
        let source = try CommodoreDiskImage(url: sourceURL)
        var destination = try CommodoreDiskImage(url: destinationURL)
        let entry = try XCTUnwrap(source.directoryEntries().first)

        try destination.copyFile(entry, from: source)

        let copied = try XCTUnwrap(destination.directoryEntries().first)
        XCTAssertEqual(copied.name, "HELLO")
        XCTAssertEqual(try destination.fileData(for: copied), try source.fileData(for: entry))
        XCTAssertTrue(destination.isModified)
    }

    func testCommodoreDiskImageCreatesBlankD64Image() throws {
        let url = temporaryURL(pathExtension: "d64")
        let image = try CommodoreDiskImage(blankImageAt: url,
                                           format: .d64,
                                           diskName: "NEW DISK",
                                           diskID: "ND")

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(image.header.name, "NEW DISK")
        XCTAssertEqual(image.header.id, "ND")
        XCTAssertEqual(image.header.blocksFree, 664)
        XCTAssertEqual(try image.directoryEntries(), [])

        let directory = try image.readSector(CommodoreDiskAddress(track: 18, sector: 1))
        XCTAssertEqual(directory[0], 0)
        XCTAssertEqual(directory[1], 255)
    }

    func testCommodoreDiskImageImportsRenamesAndDeletesProgram() throws {
        let url = temporaryURL(pathExtension: "d64")
        var image = try CommodoreDiskImage(blankImageAt: url,
                                           format: .d64,
                                           diskName: "WORK",
                                           diskID: "WK")
        let payload = Data((0..<300).map { UInt8($0 & 0xff) })

        try image.importFile(named: "demo", payload: payload)

        var entry = try XCTUnwrap(image.directoryEntries().first)
        XCTAssertEqual(entry.name, "DEMO")
        XCTAssertEqual(entry.type, .prg)
        XCTAssertEqual(entry.blocks, 2)
        XCTAssertEqual(try image.fileData(for: entry), payload)
        XCTAssertEqual(image.header.blocksFree, 662)

        try image.renameFile(entry, to: "renamed")

        entry = try XCTUnwrap(image.directoryEntries().first)
        XCTAssertEqual(entry.name, "RENAMED")

        try image.deleteFile(entry)

        XCTAssertEqual(try image.directoryEntries(), [])
        XCTAssertEqual(image.header.blocksFree, 664)
        XCTAssertTrue(image.isModified)
    }

    func testDiskImageDirectoryEntryBadgesExposeProtectionAttributes() {
        let commodore = CommodoreDiskDirectoryEntry(id: "cbm",
                                                    name: "LOCKED",
                                                    rawName: [],
                                                    type: .prg,
                                                    isClosed: false,
                                                    isLocked: true,
                                                    start: CommodoreDiskAddress(track: 1, sector: 0),
                                                    blocks: 1,
                                                    directoryAddress: CommodoreDiskAddress(track: 18, sector: 1),
                                                    slotIndex: 0)
        let cpm = CPMDirectoryEntry(id: "cpm",
                                    user: 0,
                                    fileName: "PROFILE",
                                    fileExtension: "SUB",
                                    records: 1,
                                    allocationBlocks: [2],
                                    directorySlots: [0],
                                    isReadOnly: true,
                                    isSystem: true,
                                    isArchived: true,
                                    startAddress: CommodoreDiskAddress(track: 1, sector: 0))

        XCTAssertEqual(DiskImageDirectoryEntry.commodore(commodore).statusBadges, [.open, .locked])
        XCTAssertEqual(DiskImageDirectoryEntry.cpm(cpm).statusBadges, [.readOnly, .system, .archived])
    }

    func testCommodoreDiskImageRejectsDuplicateImportedNames() throws {
        let url = temporaryURL(pathExtension: "d64")
        var image = try CommodoreDiskImage(blankImageAt: url,
                                           format: .d64,
                                           diskName: "WORK",
                                           diskID: "WK")

        try image.importFile(named: "demo", payload: Data([0x01, 0x08]))

        XCTAssertThrowsError(try image.importFile(named: "DEMO", payload: Data([0x01, 0x08]))) { error in
            XCTAssertEqual(error as? CommodoreDiskImageError, .fileExists("DEMO"))
        }
    }

    func testCommodoreDiskImageCreatesAndWritesAllManagedFormats() throws {
        let cases: [(CommodoreDiskImageFormat, Int)] = [
            (.d64, 664),
            (.d67, 670),
            (.d71, 1328),
            (.d80, 2052),
            (.d81, 3160),
            (.d82, 4133)
        ]

        for (format, expectedFreeBlocks) in cases {
            let url = temporaryURL(pathExtension: format.rawValue)
            var image = try CommodoreDiskImage(blankImageAt: url,
                                               format: format,
                                               diskName: "\(format.title) WORK",
                                               diskID: "VM")
            let payload = Data((0..<600).map { UInt8($0 & 0xff) })

            XCTAssertEqual(image.header.blocksFree, expectedFreeBlocks, format.title)

            try image.importFile(named: "demo", payload: payload)

            let entry = try XCTUnwrap(image.directoryEntries().first, format.title)
            XCTAssertEqual(entry.name, "DEMO", format.title)
            XCTAssertEqual(entry.blocks, 3, format.title)
            XCTAssertEqual(try image.fileData(for: entry), payload, format.title)
            XCTAssertEqual(image.header.blocksFree, expectedFreeBlocks - 3, format.title)
        }
    }

    func testCommodoreDiskImageClonesWithDriveOptimizedInterleave() throws {
        let sourceURL = temporaryURL(pathExtension: "d64")
        var source = try CommodoreDiskImage(blankImageAt: sourceURL,
                                            format: .d64,
                                            diskName: "SOURCE",
                                            diskID: "VM")
        let payload = Data((0..<900).map { UInt8($0 & 0xff) })

        try source.importFile(named: "demo", payload: payload)
        try source.save()

        let sourceEntry = try XCTUnwrap(source.directoryEntries().first)
        XCTAssertEqual(sourceEntry.start, CommodoreDiskAddress(track: 1, sector: 0))
        XCTAssertFalse(source.isModified)

        let cloneURL = temporaryURL(pathExtension: "d64")
        let clone = try source.cloneOptimized(to: cloneURL)
        let cloneEntry = try XCTUnwrap(clone.directoryEntries().first)

        XCTAssertEqual(try clone.fileData(for: cloneEntry), payload)
        XCTAssertEqual(try source.fileData(for: sourceEntry), payload)
        XCTAssertFalse(source.isModified)
        XCTAssertEqual(Array(try fileChain(in: clone, for: cloneEntry).prefix(4)), [
            CommodoreDiskAddress(track: 17, sector: 0),
            CommodoreDiskAddress(track: 17, sector: 10),
            CommodoreDiskAddress(track: 17, sector: 20),
            CommodoreDiskAddress(track: 17, sector: 8)
        ])
    }

    func testCommodoreDiskImageDirectoryExpansionUsesDirectoryInterleave() throws {
        let url = temporaryURL(pathExtension: "d64")
        var image = try CommodoreDiskImage(blankImageAt: url,
                                           format: .d64,
                                           diskName: "DIR TEST",
                                           diskID: "VM")

        for index in 1...9 {
            try image.importFile(named: "file \(index)", payload: Data([UInt8(index)]))
        }

        let firstDirectory = try image.readSector(CommodoreDiskAddress(track: 18, sector: 1))
        XCTAssertEqual(firstDirectory[0], 18)
        XCTAssertEqual(firstDirectory[1], 4)
    }

    func testCommodoreDiskImageRebuildAnalysisBlocksRelativeFiles() throws {
        let url = temporaryURL(pathExtension: "d64")
        var image = try CommodoreDiskImage(blankImageAt: url,
                                           format: .d64,
                                           diskName: "REL TEST",
                                           diskID: "VM")
        var directory = try image.readSector(CommodoreDiskAddress(track: 18, sector: 1))
        directory[2] = 0x84
        directory[3] = 1
        directory[4] = 0
        let name = CommodorePETSCII.encodeFilename("RANDOM")
        for index in 0..<16 {
            directory[5 + index] = name[index]
        }
        directory[30] = 1
        try image.writeSector(directory, at: CommodoreDiskAddress(track: 18, sector: 1))

        let analysis = image.rebuildAnalysis()

        XCTAssertFalse(analysis.canRebuild)
        XCTAssertTrue(analysis.blockingIssues.contains { $0.title.contains("REL") })
    }

    func testCommodoreDiskImageWritesSectorData() throws {
        let url = try makeD64Image()
        var image = try CommodoreDiskImage(url: url)
        let address = CommodoreDiskAddress(track: 1, sector: 1)
        let bytes = Data((0..<256).map { UInt8($0 & 0xff) })

        try image.writeSector(bytes, at: address)

        XCTAssertEqual(try image.readSector(address), bytes)
        XCTAssertTrue(image.isModified)
    }

    func testCommodoreDiskImageMakesGEOS1351DefaultInputDriver() throws {
        var image = try makeGEOS128SystemDiskImage()

        let initialStatus = try XCTUnwrap(image.geosStatus)
        XCTAssertEqual(image.geosBootProgramName, "GEOS128")
        XCTAssertEqual(initialStatus.defaultInputDriver?.name, "128 JOYSTICK")
        XCTAssertEqual(initialStatus.preferred1351Driver?.name, "128 COMM 1351")
        XCTAssertTrue(initialStatus.canMake1351Default)

        try image.makeGEOS1351Default()

        let updatedStatus = try XCTUnwrap(image.geosStatus)
        XCTAssertEqual(updatedStatus.defaultInputDriver?.name, "128 COMM 1351")
        XCTAssertEqual(updatedStatus.inputDrivers.map(\.name), [
            "128 COMM 1351",
            "128 JOYSTICK",
            "128 COMM 1351(A)"
        ])
        XCTAssertTrue(updatedStatus.is1351Default)
        XCTAssertTrue(image.isModified)
    }

    func testGEOS128DiskRunLaunchUsesC128BasicRunCommand() throws {
        let image = try makeGEOS128SystemDiskImage()

        let plan = DiskImageLaunchPlan.plan(for: image.url,
                                            machine: .x128,
                                            unit: 8,
                                            driveNumber: 0,
                                            driveType: .c1571,
                                            behavior: .run)

        XCTAssertEqual(plan.runMode, .attach)
        XCTAssertNil(plan.programName)
        XCTAssertEqual(plan.keyboardText, "RUN\"GEOS128\"\r")
    }

    func testExplicitGEOS128BootProgramStillUsesC128BasicRunCommand() throws {
        let image = try makeGEOS128SystemDiskImage()

        let plan = DiskImageLaunchPlan.plan(for: image.url,
                                            machine: .x128,
                                            unit: 8,
                                            driveNumber: 0,
                                            driveType: .c1571,
                                            behavior: .run,
                                            explicitProgramName: "GEOS128")

        XCTAssertEqual(plan.runMode, .attach)
        XCTAssertNil(plan.programName)
        XCTAssertEqual(plan.keyboardText, "RUN\"GEOS128\"\r")
    }

    func testGEOSDiskLoadLaunchQueuesLoadWithoutRun() throws {
        let image = try makeGEOS128SystemDiskImage()

        let plan = DiskImageLaunchPlan.plan(for: image.url,
                                            machine: .x128,
                                            unit: 8,
                                            driveNumber: 0,
                                            driveType: .c1571,
                                            behavior: .load)

        XCTAssertEqual(plan.runMode, .attach)
        XCTAssertNil(plan.programName)
        XCTAssertEqual(plan.keyboardText, "LOAD\"GEOS128\",8,1\r")
    }

    func testGEOS64DiskRunLaunchUsesLoadThenRun() throws {
        let image = try makeGEOS64SystemDiskImage()

        let plan = DiskImageLaunchPlan.plan(for: image.url,
                                            machine: .x64sc,
                                            unit: 8,
                                            driveNumber: 0,
                                            driveType: .c1541II,
                                            behavior: .run)

        XCTAssertEqual(plan.runMode, .attach)
        XCTAssertNil(plan.programName)
        XCTAssertEqual(plan.keyboardText, "LOAD\"GEOS\",8,1\rRUN\r")
    }

    func testGEOS128DiskOnC64AttachesWithoutBooting() throws {
        let image = try makeGEOS128SystemDiskImage()

        let plan = DiskImageLaunchPlan.plan(for: image.url,
                                            machine: .x64sc,
                                            unit: 8,
                                            driveNumber: 0,
                                            driveType: .c1541,
                                            behavior: .run)

        XCTAssertEqual(plan.runMode, .attach)
        XCTAssertNil(plan.programName)
        XCTAssertNil(plan.keyboardText)
        XCTAssertEqual(plan.statusMessage, "GEOS128 requires a Commodore 128")
    }

    func testNonGEOSDiskRunLaunchUsesVICEAutostart() throws {
        let url = try makeD64Image(name: "HELLO", payload: Data([0x01, 0x08, 0x00]))

        let plan = DiskImageLaunchPlan.plan(for: url,
                                            machine: .x64sc,
                                            unit: 8,
                                            driveNumber: 0,
                                            driveType: .c1541,
                                            behavior: .run)

        XCTAssertEqual(plan.runMode, .run)
        XCTAssertNil(plan.programName)
        XCTAssertNil(plan.keyboardText)
    }

    func testCommodoreDiskImageInstallsGEOSPackage() throws {
        var image = try makeGEOS128SystemDiskImage()
        var metadata = GEOSProgramMetadata()
        metadata.kind = .autoExec
        metadata.dosName = "MACVICE RTC"
        metadata.className = "MacVICE RTC"
        metadata.version = "V1.0"
        metadata.dosType = .usr
        metadata.mode = .any

        let prg = Data([0x00, 0x04, 0xa9, 0x00, 0x4c, 0x2c, 0xc2])
        let package = try GEOSPackageBuilder.buildCVT(prgData: prg,
                                                       entryAddressText: "$0402",
                                                       metadata: metadata,
                                                       timestamp: GEOSFileTimestamp(year: 26, month: 5, day: 27, hour: 15, minute: 42))

        try image.installGEOSPackage(package)

        let entry = try XCTUnwrap(try image.directoryEntries().first { $0.name == "MACVICE RTC" })
        XCTAssertEqual(entry.type, .usr)
        XCTAssertTrue(entry.isClosed)
        XCTAssertEqual(entry.blocks, 2)
        XCTAssertEqual(try image.fileData(for: entry), prg.dropFirst(2))

        let directorySector = try image.readSector(entry.directoryAddress)
        let base = entry.slotIndex * 32
        let headerAddress = CommodoreDiskAddress(track: Int(directorySector[base + 21]),
                                                 sector: Int(directorySector[base + 22]))
        XCTAssertNotEqual(headerAddress.track, 0)
        XCTAssertEqual(directorySector[base + 23], 0)
        XCTAssertEqual(directorySector[base + 24], 14)

        let header = try image.readSector(headerAddress)
        XCTAssertEqual(header[2], 3)
        XCTAssertEqual(header[3], 21)
        XCTAssertEqual(header[68], 0x83)
        XCTAssertEqual(header[69], 14)
        XCTAssertEqual(header[70], 0)
        XCTAssertTrue(image.isModified)
    }

    func testCommodoreHexDumpRoundTripsSectorText() throws {
        let bytes = Data((0..<256).map { UInt8($0 & 0xff) })
        let text = CommodoreHexDump.text(for: bytes)

        XCTAssertEqual(try CommodoreHexDump.data(from: text), bytes)
    }

    private func startupConfiguration(for machine: EmulatedMachine,
                                      displayOutput: MachineDisplayOutput? = nil,
                                      machineModel: MachineModel? = nil,
                                      videoStandard: EmulatorSession.VideoStandard = .ntsc,
                                      ramExpansion: RAMExpansion = .none,
                                      mediaBehavior: MediaBehaviorConfiguration = .standard,
                                      sidConfiguration: SIDConfiguration = .standard,
                                      tapeConfiguration: TapeConfiguration = .standard,
                                      printerConfiguration: PrinterConfiguration = .standard,
                                      driveConfigurations: [DriveConfiguration]? = nil,
                                      syncSystemTime: Bool = false,
                                      networkModem: NetworkModemConfiguration = .standard,
                                      networkLocalPort: Int? = nil) -> MachineStartupConfiguration {
        MachineStartupConfiguration(executablePath: "/tmp/vice",
                                    dataDirectory: "/tmp/data",
                                    machineModel: machineModel,
                                    videoStandard: videoStandard,
                                    sidModel: .mos8580,
                                    soundEnabled: true,
                                    soundVolume: 100,
                                    emulationSpeed: .normal,
                                    displayOutput: displayOutput ?? machine.defaultDisplayOutput,
                                    romImages: .standard,
                                    ramExpansion: ramExpansion,
                                    mediaBehavior: mediaBehavior,
                                    sidConfiguration: sidConfiguration,
                                    tapeConfiguration: tapeConfiguration,
                                    printerConfiguration: printerConfiguration,
                                    printerOutputBasePath: "/tmp/macvice-print/geos-print",
                                    driveConfigurations: driveConfigurations ?? machine.defaultDriveConfigurations(),
                                    syncSystemTime: syncSystemTime,
                                    networkModem: networkModem,
                                    networkLocalPort: networkLocalPort)
    }

    private static let allMachines: [EmulatedMachine] = [
        .x64sc,
        .x128,
        .xvic,
        .xpet,
        .xplus4,
        .xc16,
        .xc232,
        .xv364
    ]

    private func makeD64Image(name: String? = nil, payload: Data = Data()) throws -> URL {
        let url = temporaryURL(pathExtension: "d64")
        let geometry = try CommodoreDiskGeometry(format: .d64, fileSize: 174_848)
        var data = Data(repeating: 0, count: geometry.dataByteCount)

        var bam = Data(repeating: 0, count: CommodoreDiskImage.bytesPerSector)
        bam[0] = 18
        bam[1] = 1
        bam[2] = 65

        for track in 1...35 {
            let entry = 4 + (track - 1) * 4
            let sectorCount = geometry.sectorsPerTrack(track)
            bam[entry] = UInt8(sectorCount)
            for sector in 0..<sectorCount {
                bam[entry + 1 + sector / 8] |= UInt8(1 << (sector % 8))
            }
        }

        writePETSCII("VICE MAC", into: &bam, range: 144..<160)
        writePETSCII("VM", into: &bam, range: 162..<167)
        bam[165] = 50
        bam[166] = 65

        clearBAMBit(track: 18, sector: 0, in: &bam)
        clearBAMBit(track: 18, sector: 1, in: &bam)

        var directory = Data(repeating: 0, count: CommodoreDiskImage.bytesPerSector)
        directory[0] = 0
        directory[1] = 255

        if let name {
            let fileAddress = CommodoreDiskAddress(track: 1, sector: 0)
            clearBAMBit(track: fileAddress.track, sector: fileAddress.sector, in: &bam)
            directory[2] = 0x82
            directory[3] = UInt8(fileAddress.track)
            directory[4] = UInt8(fileAddress.sector)
            let encodedName = CommodorePETSCII.encodeFilename(name)
            for index in 0..<16 {
                directory[5 + index] = encodedName[index]
            }
            directory[30] = 1

            var fileSector = Data(repeating: 0, count: CommodoreDiskImage.bytesPerSector)
            fileSector[0] = 0
            fileSector[1] = UInt8(payload.count + 1)
            fileSector.replaceSubrange(2..<(2 + payload.count), with: payload)
            writeSector(fileSector, at: fileAddress, geometry: geometry, data: &data)
        }

        writeSector(bam, at: CommodoreDiskAddress(track: 18, sector: 0), geometry: geometry, data: &data)
        writeSector(directory, at: CommodoreDiskAddress(track: 18, sector: 1), geometry: geometry, data: &data)
        try data.write(to: url)
        return url
    }

    private func makeQLinkDevelopmentNGD64Data(programNames: [String] = ["BOOT64", "MODBOOT"]) throws -> Data {
        let url = temporaryURL(pathExtension: "d64")
        var image = try CommodoreDiskImage(blankImageAt: url,
                                           format: .d64,
                                           diskName: "QLINK NG",
                                           diskID: "NG")

        for (index, programName) in programNames.enumerated() {
            try image.importFile(named: programName,
                                 payload: Data([0x01, 0x08, 0x60, UInt8(index)]))
        }
        try image.save()

        return try Data(contentsOf: url)
    }

    private func makeGEOS128SystemDiskImage() throws -> CommodoreDiskImage {
        let url = temporaryURL(pathExtension: "d64")
        var image = try CommodoreDiskImage(blankImageAt: url,
                                           format: .d64,
                                           diskName: "GEOS128",
                                           diskID: "G2")

        var firstDirectory = try image.readSector(CommodoreDiskAddress(track: 18, sector: 1))
        firstDirectory[0] = 18
        firstDirectory[1] = 9
        writeDirectoryEntry("GEOS128", slot: 0, type: 0x82, start: CommodoreDiskAddress(track: 17, sector: 10), blocks: 2, in: &firstDirectory)
        writeDirectoryEntry("GEOBOOT128", slot: 1, type: 0x82, start: CommodoreDiskAddress(track: 17, sector: 11), blocks: 152, in: &firstDirectory)
        writeDirectoryEntry("128 DESKTOP", slot: 2, type: 0x83, start: CommodoreDiskAddress(track: 23, sector: 10), blocks: 137, in: &firstDirectory)
        writeDirectoryEntry("128 JOYSTICK", slot: 3, type: 0x83, start: CommodoreDiskAddress(track: 5, sector: 15), blocks: 3, in: &firstDirectory)
        try image.writeSector(firstDirectory, at: CommodoreDiskAddress(track: 18, sector: 1))

        var secondDirectory = Data(repeating: 0, count: CommodoreDiskImage.bytesPerSector)
        secondDirectory[0] = 0
        secondDirectory[1] = 255
        writeDirectoryEntry("128 COMM 1351", slot: 0, type: 0x83, start: CommodoreDiskAddress(track: 5, sector: 12), blocks: 3, in: &secondDirectory)
        writeDirectoryEntry("128 COMM 1351(A)", slot: 1, type: 0x83, start: CommodoreDiskAddress(track: 1, sector: 16), blocks: 3, in: &secondDirectory)
        try image.writeSector(secondDirectory, at: CommodoreDiskAddress(track: 18, sector: 9))
        try image.save()

        return image
    }

    private func makeGEOS64SystemDiskImage() throws -> CommodoreDiskImage {
        let url = temporaryURL(pathExtension: "d64")
        var image = try CommodoreDiskImage(blankImageAt: url,
                                           format: .d64,
                                           diskName: "GEOS",
                                           diskID: "G2")

        var directory = try image.readSector(CommodoreDiskAddress(track: 18, sector: 1))
        directory[0] = 0
        directory[1] = 255
        writeDirectoryEntry("GEOS", slot: 0, type: 0x82, start: CommodoreDiskAddress(track: 17, sector: 10), blocks: 2, in: &directory)
        writeDirectoryEntry("GEOBOOT", slot: 1, type: 0x82, start: CommodoreDiskAddress(track: 17, sector: 11), blocks: 152, in: &directory)
        writeDirectoryEntry("DESK TOP", slot: 2, type: 0x83, start: CommodoreDiskAddress(track: 23, sector: 10), blocks: 137, in: &directory)
        try image.writeSector(directory, at: CommodoreDiskAddress(track: 18, sector: 1))
        try image.save()

        return image
    }

    private func temporaryURL(pathExtension: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)
    }

    private func temporaryDirectoryURL(_ prefix: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    }

    private func temporaryUserDefaults(_ prefix: String) throws -> UserDefaults {
        let suiteName = "com.barrywalker.vicemac.tests.\(prefix).\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    private func sourceText(at relativePath: String) throws -> String {
        try String(contentsOf: repositoryRootURL.appendingPathComponent(relativePath),
                   encoding: .utf8)
    }

    private func buildSettingValues(named name: String, in source: String) throws -> [String] {
        let pattern = #"\#(name) = ([^;]+);"#
        let expression = try NSRegularExpression(pattern: pattern)
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        return expression.matches(in: source, range: range).compactMap { match in
            guard let valueRange = Range(match.range(at: 1), in: source) else {
                return nil
            }
            return String(source[valueRange])
        }
    }

    private var repositoryRootURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func makeQLinkD64ProfileFixture(accessNumber: String = "5974",
                                            screenName: String = "BarryWalkr") -> Data {
        makeQLinkD64ProfileFixture(accessNumber: accessNumber,
                                    screenNames: [screenName])
    }

    private func makeQLinkD64ProfileFixture(accessNumber: String = "5974",
                                            screenNames: [String]) -> Data {
        var data = Data(repeating: 0, count: QLinkReloadedDiskPatcher.d64ByteCount)
        var profile = [UInt8](repeating: 0, count: 256)
        profile[0] = 0
        profile[1] = 0
        profile[2] = 3
        profile[3] = 1
        profile[4] = 0x44
        profile[5] = 0
        let accessNumberBytes = Array(accessNumber.prefix(21).utf8)
        for index in 9..<30 {
            profile[index] = 0
        }
        profile.replaceSubrange(9..<(9 + accessNumberBytes.count), with: accessNumberBytes)
        for index in (9 + accessNumberBytes.count)..<30 {
            profile[index] = 0x20
        }
        profile[30] = 9
        profile[31] = 9
        profile[32] = 9
        profile[33] = 0x80
        for index in 50..<201 {
            profile[index] = 0
        }
        profile[50] = UInt8(min(screenNames.count, QLinkReloadedDiskPatcher.maximumRegistrationProfileCount))
        for (index, screenName) in screenNames.prefix(QLinkReloadedDiskPatcher.maximumRegistrationProfileCount).enumerated() {
            let slotRange = (51 + index * 15)..<(66 + index * 15)
            let accountID = String(format: "%010d", 5_974 + index)
            profile.replaceSubrange(slotRange,
                                    with: qLinkUserRecord(screenName: screenName, accountID: accountID))
        }

        data.replaceSubrange(qLinkProfileSectorRange(), with: encryptedQLinkProfile(profile))
        return data
    }

    private func qLinkUserRecord(screenName: String, accountID: String = "0000005974") -> [UInt8] {
        var record = qLinkPackedAccountID(accountID)
        let screenNameBytes = qLinkScreenNameBytes(screenName)
        record.append(contentsOf: screenNameBytes)
        record.append(contentsOf: Array(repeating: UInt8(0x20), count: max(0, 10 - screenNameBytes.count)))
        return Array(record.prefix(15))
    }

    private func qLinkPackedAccountID(_ accountID: String) -> [UInt8] {
        let digits = Array(accountID.prefix(10).utf8)
        let paddedDigits = Array(repeating: UInt8(ascii: "0"), count: max(0, 10 - digits.count)) + digits
        return stride(from: 0, to: 10, by: 2).map { index in
            ((paddedDigits[index] - UInt8(ascii: "0")) << 4)
                | (paddedDigits[index + 1] - UInt8(ascii: "0"))
        }
    }

    private func qLinkScreenNameBytes(_ screenName: String) -> [UInt8] {
        screenName
            .uppercased()
            .prefix(10)
            .compactMap { character -> UInt8? in
                guard let ascii = character.asciiValue else {
                    return nil
                }

                switch ascii {
                case 65...90:
                    return ascii - 64
                case 48...57, 32:
                    return ascii
                default:
                    return nil
                }
            }
    }

    private func qLinkFactoryBlankAccessNumberProfile() -> [UInt8] {
        [0x31, 0x20, 0x20, 0x20] + Array(repeating: UInt8(0), count: 17)
    }

    private func qLinkFactoryBlankUserRecordBlock() -> [UInt8] {
        [0x01]
            + [0x58, 0x89, 0x34, 0x95, 0x67]
            + Array("QLINK     ".utf8)
            + Array(repeating: UInt8(0), count: 135)
    }

    private func qLinkProfileSectorRange() -> Range<Data.Index> {
        func sectors(onTrack track: Int) -> Int {
            switch track {
            case 1...17:
                return 21
            case 18...24:
                return 19
            case 25...30:
                return 18
            default:
                return 17
            }
        }

        let precedingSectorCount = (1..<QLinkReloadedDiskPatcher.profileSectorTrack)
            .map(sectors(onTrack:))
            .reduce(0, +)
        let offset = (precedingSectorCount + QLinkReloadedDiskPatcher.profileSector) * 256
        return offset..<(offset + 256)
    }

    private func encryptedQLinkProfile(_ profile: [UInt8]) -> Data {
        var encryptedProfile = profile
        var crypto: UInt8 = 0x6e
        for index in encryptedProfile.indices {
            encryptedProfile[index] ^= crypto
            crypto &+= 1
        }
        return Data(encryptedProfile)
    }

    private func fakeAccessDatabaseData() -> Data {
        var data = Data([0xd0, 0xcf, 0x11, 0xe0, 0xa1, 0xb1, 0x1a, 0xe1])
        data.append(Data("GameBase64 MDB test fixture".utf8))
        data.append(Data(repeating: 0, count: 512))
        return data
    }

    private func fakeInnoSetupInstallerData() -> Data {
        var data = Data([0x4d, 0x5a])
        data.append(Data(repeating: 0, count: 128))
        data.append(Data("Inno Setup Setup Data (6.1.0) (u)".utf8))
        return data
    }

    private func makeStoredZIP(filename: String, contents: Data) -> Data {
        let nameData = Data(filename.utf8)
        let checksum = contents.withUnsafeBytes { buffer -> UInt32 in
            guard let baseAddress = buffer.bindMemory(to: Bytef.self).baseAddress else {
                return UInt32(crc32(0, nil, 0))
            }

            return UInt32(crc32(0, baseAddress, uInt(contents.count)))
        }

        var data = Data()
        let localHeaderOffset = UInt32(data.count)
        data.appendUInt32LE(0x04034b50)
        data.appendUInt16LE(20)
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt32LE(checksum)
        data.appendUInt32LE(UInt32(contents.count))
        data.appendUInt32LE(UInt32(contents.count))
        data.appendUInt16LE(UInt16(nameData.count))
        data.appendUInt16LE(0)
        data.append(nameData)
        data.append(contents)

        let centralDirectoryOffset = UInt32(data.count)
        data.appendUInt32LE(0x02014b50)
        data.appendUInt16LE(20)
        data.appendUInt16LE(20)
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt32LE(checksum)
        data.appendUInt32LE(UInt32(contents.count))
        data.appendUInt32LE(UInt32(contents.count))
        data.appendUInt16LE(UInt16(nameData.count))
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt32LE(0)
        data.appendUInt32LE(localHeaderOffset)
        data.append(nameData)

        let centralDirectorySize = UInt32(data.count) - centralDirectoryOffset
        data.appendUInt32LE(0x06054b50)
        data.appendUInt16LE(0)
        data.appendUInt16LE(0)
        data.appendUInt16LE(1)
        data.appendUInt16LE(1)
        data.appendUInt32LE(centralDirectorySize)
        data.appendUInt32LE(centralDirectoryOffset)
        data.appendUInt16LE(0)

        return data
    }

    @MainActor
    private func metadataSnapshot(_ providerID: MetadataProviderID,
                                  in settings: MetadataIngestionSettings) throws -> MetadataProviderSnapshot {
        try XCTUnwrap(settings.providerSnapshots.first { $0.providerID == providerID })
    }

    private func writeSector(_ sector: Data,
                             at address: CommodoreDiskAddress,
                             geometry: CommodoreDiskGeometry,
                             data: inout Data) {
        let offset = try! geometry.offset(for: address)
        data.replaceSubrange(offset..<(offset + CommodoreDiskImage.bytesPerSector), with: sector)
    }

    private func fileChain(in image: CommodoreDiskImage,
                           for entry: CommodoreDiskDirectoryEntry) throws -> [CommodoreDiskAddress] {
        var chain: [CommodoreDiskAddress] = []
        var address = entry.start
        var seen = Set<CommodoreDiskAddress>()

        while address.track != 0 {
            XCTAssertFalse(seen.contains(address))
            seen.insert(address)
            chain.append(address)
            let sector = try image.readSector(address)
            address = CommodoreDiskAddress(track: Int(sector[0]), sector: Int(sector[1]))
        }

        return chain
    }

    private func writePETSCII(_ string: String, into data: inout Data, range: Range<Int>) {
        let bytes = CommodorePETSCII.encodeFilename(string)
        for (index, dataIndex) in range.enumerated() {
            data[dataIndex] = index < bytes.count ? bytes[index] : 0xa0
        }
    }

    private func writeDirectoryEntry(_ name: String,
                                     slot: Int,
                                     type: UInt8,
                                     start: CommodoreDiskAddress,
                                     blocks: Int,
                                     in sector: inout Data) {
        let base = slot * 32
        sector[base + 2] = type
        sector[base + 3] = UInt8(start.track)
        sector[base + 4] = UInt8(start.sector)

        let nameBytes = CommodorePETSCII.encodeFilename(name)
        for index in 0..<16 {
            sector[base + 5 + index] = nameBytes[index]
        }

        sector[base + 30] = UInt8(blocks & 0xff)
        sector[base + 31] = UInt8((blocks >> 8) & 0xff)
    }

    private func clearBAMBit(track: Int, sector: Int, in bam: inout Data) {
        let entry = 4 + (track - 1) * 4
        bam[entry + 1 + sector / 8] &= ~UInt8(1 << (sector % 8))
        bam[entry] = bam[entry] &- 1
    }
}

private func writeSearchablePDF(text: String, to url: URL) throws {
    let data = NSMutableData()
    guard let consumer = CGDataConsumer(data: data as CFMutableData) else {
        throw NSError(domain: "ViceMacTests", code: 1)
    }

    var mediaBox = CGRect(x: 0, y: 0, width: 612, height: 792)
    guard let context = CGContext(consumer: consumer,
                                  mediaBox: &mediaBox,
                                  nil) else {
        throw NSError(domain: "ViceMacTests", code: 2)
    }

    context.beginPDFPage(nil)
    let attributedText = NSAttributedString(string: text,
                                            attributes: [.font: NSFont.systemFont(ofSize: 12)])
    let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
    let textPath = CGPath(rect: CGRect(x: 72, y: 72, width: 468, height: 648),
                          transform: nil)
    let frame = CTFramesetterCreateFrame(framesetter,
                                         CFRange(location: 0, length: attributedText.length),
                                         textPath,
                                         nil)
    CTFrameDraw(frame, context)
    context.endPDFPage()
    context.closePDF()
    try data.write(to: url)
}

private struct StubInnoSetupExtractor: InnoSetupExtracting {
    var databaseURL: URL

    func extractAccessDatabase(from installerURL: URL,
                               to temporaryDirectoryURL: URL) throws -> URL {
        databaseURL
    }
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0x00ff))
        append(UInt8((value >> 8) & 0x00ff))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0x000000ff))
        append(UInt8((value >> 8) & 0x000000ff))
        append(UInt8((value >> 16) & 0x000000ff))
        append(UInt8((value >> 24) & 0x000000ff))
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

private extension RAMExpansionResourcePlan {
    func value(for resourceName: String) -> Int32? {
        (disableAssignments + enableAssignments).last { $0.name == resourceName }?.value
    }
}

private final class ViceFSDeviceHarness {
    struct DirectoryEntry {
        let name: String
        let detail: String
        let rawNameBytes: [UInt8]
    }

    private typealias ResourcesInit = @convention(c) (UnsafePointer<CChar>) -> Int32
    private typealias FSDeviceResourcesInit = @convention(c) () -> Int32
    private typealias FSDeviceInit = @convention(c) () -> Void
    private typealias FSDeviceShutdown = @convention(c) () -> Void
    private typealias FSDeviceSetDirectory = @convention(c) (UnsafeMutablePointer<CChar>, UInt32) -> Void
    private typealias FSDeviceOpen = @convention(c) (UnsafeMutableRawPointer, UnsafePointer<UInt8>, UInt32, UInt32, UnsafeMutableRawPointer?) -> Int32
    private typealias FSDeviceRead = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt8>, UInt32) -> Int32
    private typealias FSDeviceClose = @convention(c) (UnsafeMutableRawPointer, UInt32) -> Int32
    private typealias FSDeviceFlushWriteByte = @convention(c) (UnsafeMutableRawPointer, UInt8) -> Int32
    private typealias FSDeviceFlush = @convention(c) (UnsafeMutableRawPointer, UInt32) -> Void
    private typealias FSDeviceErrorGetByte = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt8>) -> Int32
    private typealias CharsetPToASCII = @convention(c) (UInt8, Int32) -> UInt8

    private let handle: UnsafeMutableRawPointer
    private let dependencyHandles: [UnsafeMutableRawPointer]
    private let fsdeviceShutdown: FSDeviceShutdown
    private let fsdeviceSetDirectory: FSDeviceSetDirectory
    private let fsdeviceOpen: FSDeviceOpen
    private let fsdeviceRead: FSDeviceRead
    private let fsdeviceClose: FSDeviceClose
    private let fsdeviceFlushWriteByte: FSDeviceFlushWriteByte
    private let fsdeviceFlush: FSDeviceFlush
    private let fsdeviceErrorGetByte: FSDeviceErrorGetByte
    private let charsetPToASCII: CharsetPToASCII
    private let vdrive: UnsafeMutableRawPointer
    private var didShutdown = false

    private static let resourceLock = NSLock()
    nonisolated(unsafe) private static var didInitializeResources = false

    init() throws {
        let sourceFileURL = URL(fileURLWithPath: #filePath)
        let repositoryRootURL = sourceFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let buildProductsURL = repositoryRootURL
            .appendingPathComponent("macos")
            .appendingPathComponent("BuildProducts")
        let dependencyNames = [
            "libpng16.16.dylib",
            "libintl.8.dylib",
            "libusb-1.0.0.dylib"
        ]

        var openedDependencies: [UnsafeMutableRawPointer] = []
        for dependencyName in dependencyNames {
            let dependencyURL = buildProductsURL.appendingPathComponent(dependencyName)
            guard let dependencyHandle = dlopen(dependencyURL.path, RTLD_NOW | RTLD_GLOBAL) else {
                throw ViceFSDeviceHarness.error("Could not load \(dependencyName): \(ViceFSDeviceHarness.dlErrorMessage())")
            }
            openedDependencies.append(dependencyHandle)
        }

        dependencyHandles = openedDependencies

        let viceLibraryURL = buildProductsURL.appendingPathComponent("libvicemacx64sc.dylib")
        guard let handle = dlopen(viceLibraryURL.path, RTLD_NOW | RTLD_GLOBAL) else {
            throw ViceFSDeviceHarness.error("Could not load libvicemacx64sc.dylib: \(ViceFSDeviceHarness.dlErrorMessage())")
        }
        self.handle = handle

        let resourcesInit: ResourcesInit = try Self.symbol("resources_init", in: handle)
        let fsdeviceResourcesInit: FSDeviceResourcesInit = try Self.symbol("fsdevice_resources_init", in: handle)
        let fsdeviceInit: FSDeviceInit = try Self.symbol("fsdevice_init", in: handle)
        fsdeviceShutdown = try Self.symbol("fsdevice_shutdown", in: handle)
        fsdeviceSetDirectory = try Self.symbol("fsdevice_set_directory", in: handle)
        fsdeviceOpen = try Self.symbol("fsdevice_open", in: handle)
        fsdeviceRead = try Self.symbol("fsdevice_read", in: handle)
        fsdeviceClose = try Self.symbol("fsdevice_close", in: handle)
        fsdeviceFlushWriteByte = try Self.symbol("fsdevice_flush_write_byte", in: handle)
        fsdeviceFlush = try Self.symbol("fsdevice_flush", in: handle)
        fsdeviceErrorGetByte = try Self.symbol("fsdevice_error_get_byte", in: handle)
        charsetPToASCII = try Self.symbol("charset_p_toascii", in: handle)

        try Self.initializeResourcesIfNeeded(resourcesInit: resourcesInit,
                                             fsdeviceResourcesInit: fsdeviceResourcesInit)

        vdrive = UnsafeMutableRawPointer.allocate(byteCount: 4096, alignment: MemoryLayout<UInt64>.alignment)
        vdrive.initializeMemory(as: UInt8.self, repeating: 0, count: 4096)
        vdrive.storeBytes(of: UInt32(8), as: UInt32.self)

        fsdeviceInit()
    }

    deinit {
        if !didShutdown {
            fsdeviceShutdown()
        }
        vdrive.deallocate()
        dlclose(handle)
        for dependencyHandle in dependencyHandles {
            dlclose(dependencyHandle)
        }
    }

    func status(after command: String) throws -> String {
        for byte in command.utf8 {
            _ = fsdeviceFlushWriteByte(vdrive, byte)
        }
        _ = fsdeviceFlushWriteByte(vdrive, 13)
        fsdeviceFlush(vdrive, 15)

        var statusBytes: [UInt8] = []
        while statusBytes.count < 256 {
            var byte: UInt8 = 0
            let result = fsdeviceErrorGetByte(vdrive, &byte)
            if byte == 13 {
                return String(decoding: statusBytes, as: UTF8.self)
            }
            statusBytes.append(byte)
            if result == 0x40 {
                return String(decoding: statusBytes, as: UTF8.self)
            }
        }

        throw Self.error("VICE fsdevice status channel did not terminate")
    }

    func directoryEntries(for directoryURL: URL) throws -> [DirectoryEntry] {
        directoryURL.path.withCString { path in
            fsdeviceSetDirectory(UnsafeMutablePointer(mutating: path), 8)
        }

        let name = [UInt8(ascii: "$"), 0]
        let openStatus = name.withUnsafeBufferPointer { buffer in
            fsdeviceOpen(vdrive, buffer.baseAddress!, UInt32(buffer.count - 1), 0, nil)
        }
        guard openStatus == 0 else {
            throw Self.error("VICE fsdevice_open directory failed with status \(openStatus)")
        }

        var bytes: [UInt8] = []
        while bytes.count < 16_384 {
            var byte: UInt8 = 0
            let result = fsdeviceRead(vdrive, &byte, 0)
            bytes.append(byte)
            if result == 0x40 {
                _ = fsdeviceClose(vdrive, 0)
                return parseDirectoryEntries(from: bytes)
            }
        }

        _ = fsdeviceClose(vdrive, 0)
        throw Self.error("VICE fsdevice directory listing did not terminate")
    }

    func canOpenDisplayedFile(named name: String) throws -> Bool {
        var bytes = Array(name.utf8)
        bytes.append(0)

        let openStatus = bytes.withUnsafeBufferPointer { buffer in
            fsdeviceOpen(vdrive, buffer.baseAddress!, UInt32(buffer.count - 1), 2, nil)
        }

        if openStatus == 0 {
            _ = fsdeviceClose(vdrive, 2)
            return true
        }

        return false
    }

    private func parseDirectoryEntries(from bytes: [UInt8]) -> [DirectoryEntry] {
        var entries: [DirectoryEntry] = []
        var index = bytes.startIndex

        while let openQuote = bytes[index...].firstIndex(of: UInt8(ascii: "\"")) {
            let nameStart = bytes.index(after: openQuote)
            guard let closeQuote = bytes[nameStart...].firstIndex(of: UInt8(ascii: "\"")) else {
                break
            }

            let rawNameBytes = Array(bytes[nameStart..<closeQuote])
            let name = asciiString(from: bytes[nameStart..<closeQuote])
            let detailStart = bytes.index(after: closeQuote)
            let detailEnd = min(bytes.endIndex, detailStart + 24)
            let detail = asciiString(from: bytes[detailStart..<detailEnd])
            entries.append(DirectoryEntry(name: name, detail: detail, rawNameBytes: rawNameBytes))
            index = detailStart
        }

        return entries
    }

    private func asciiString(from bytes: ArraySlice<UInt8>) -> String {
        let decoded = bytes.compactMap { byte -> UInt8? in
            let converted = charsetPToASCII(byte, 0)
            return (32...126).contains(converted) ? converted : nil
        }

        return String(decoding: decoded, as: UTF8.self).trimmingCharacters(in: .whitespaces)
    }

    private static func initializeResourcesIfNeeded(resourcesInit: ResourcesInit,
                                                    fsdeviceResourcesInit: FSDeviceResourcesInit) throws {
        resourceLock.lock()
        defer { resourceLock.unlock() }

        guard !didInitializeResources else {
            return
        }

        let resourceStatus = "x64sc".withCString { resourcesInit($0) }
        guard resourceStatus == 0 else {
            throw error("VICE resources_init failed with status \(resourceStatus)")
        }

        let fsdeviceResourceStatus = fsdeviceResourcesInit()
        guard fsdeviceResourceStatus == 0 else {
            throw error("VICE fsdevice_resources_init failed with status \(fsdeviceResourceStatus)")
        }

        didInitializeResources = true
    }

    private static func symbol<T>(_ name: String, in handle: UnsafeMutableRawPointer) throws -> T {
        guard let pointer = dlsym(handle, name) else {
            throw error("Missing VICE symbol \(name): \(dlErrorMessage())")
        }

        return unsafeBitCast(pointer, to: T.self)
    }

    private static func error(_ message: String) -> NSError {
        NSError(domain: "ViceFSDeviceHarness", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private static func dlErrorMessage() -> String {
        guard let message = dlerror() else {
            return "unknown dynamic loader error"
        }
        return String(cString: message)
    }
}

private final class NetworkTestCapture: @unchecked Sendable {
    private var bytes: [UInt8] = []
    private var didMatch = false

    var rawBytes: [UInt8] {
        bytes
    }

    var printableResponse: String {
        String(decoding: bytes.filter { byte in
            byte == 10 || byte == 13 || (byte >= 32 && byte <= 126)
        }, as: UTF8.self)
    }

    func append(_ data: Data, matching fragments: [String]) -> Bool {
        bytes.append(contentsOf: data)
        guard !didMatch else {
            return false
        }

        let printableResponse = printableResponse
        if fragments.allSatisfy({ printableResponse.contains($0) }) {
            didMatch = true
            return true
        }

        return false
    }
}

private final class QLinkValidationTestServer: @unchecked Sendable {
    let port: NWEndpoint.Port

    private let queue = DispatchQueue(label: "com.barrywalker.vicemac.tests.qlink-validation-server")
    private let listener: NWListener
    private var connections: [NWConnection] = []
    private var receivedInitialCRCount = 0
    private var receivedBinaryBytes: [UInt8] = []
    private var receivedResetFrame = false

    var didReceiveResetFrame: Bool {
        queue.sync {
            receivedResetFrame
        }
    }

    init() throws {
        port = try NetworkTestPort.reserveLoopbackPort()
        listener = try NWListener(using: .tcp, on: port)
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
    }

    func start() {
        listener.start(queue: queue)
    }

    func cancel() {
        queue.sync {
            listener.cancel()
            for connection in connections {
                connection.cancel()
            }
            connections.removeAll()
        }
    }

    private func accept(_ connection: NWConnection) {
        connections.append(connection)
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard case .ready = state,
                  let connection else {
                return
            }

            self?.receiveInitialCRs(on: connection)
        }
        connection.start(queue: queue)
    }

    private func receiveInitialCRs(on connection: NWConnection) {
        receive(on: connection) { data in
            self.receivedInitialCRCount += data.filter { $0 == 0x0D }.count
            guard self.receivedInitialCRCount >= 3 else {
                self.receiveInitialCRs(on: connection)
                return
            }

            self.sendText("TERMINAL=", on: connection)
            self.receiveTerminalSelection(on: connection)
        }
    }

    private func receiveTerminalSelection(on connection: NWConnection) {
        receiveText(on: connection, containing: "D1") {
            self.sendText("@", on: connection)
            self.receiveConnect(on: connection)
        }
    }

    private func receiveConnect(on connection: NWConnection) {
        receiveText(on: connection, containing: "CONNECT") {
            self.sendText("\r\rCONNECTED\r", on: connection)
            self.receiveReset(on: connection)
        }
    }

    private func receiveReset(on connection: NWConnection) {
        receive(on: connection) { data in
            self.receivedBinaryBytes.append(contentsOf: data)
            guard QLinkReloadedProtocolProbe.isValidFrame(self.receivedBinaryBytes),
                  self.receivedBinaryBytes.count > 7,
                  self.receivedBinaryBytes[7] == QLinkReloadedProtocolProbe.resetCommand else {
                self.receiveReset(on: connection)
                return
            }

            self.receivedResetFrame = true
            let ack = QLinkReloadedProtocolProbe.frame(command: QLinkReloadedProtocolProbe.resetAckCommand,
                                                       sendSequence: QLinkReloadedProtocolProbe.defaultSequence,
                                                       receiveSequence: QLinkReloadedProtocolProbe.defaultSequence,
                                                       payload: [])
            self.sendData(ack, on: connection)
        }
    }

    private func receiveText(on connection: NWConnection,
                             containing needle: String,
                             then next: @escaping @Sendable () -> Void) {
        receive(on: connection) { data in
            let text = String(decoding: data, as: UTF8.self)
            guard text.contains(needle) else {
                self.receiveText(on: connection, containing: needle, then: next)
                return
            }

            next()
        }
    }

    private func receive(on connection: NWConnection,
                         then next: @escaping @Sendable (Data) -> Void) {
        connection.receive(minimumIncompleteLength: 1,
                           maximumLength: 4096) { [weak self] data, _, _, _ in
            guard let self,
                  let data,
                  !data.isEmpty else {
                return
            }

            self.queue.async {
                next(data)
            }
        }
    }

    private func sendText(_ text: String, on connection: NWConnection) {
        sendData(Data(text.utf8), on: connection)
    }

    private func sendData(_ data: Data, on connection: NWConnection) {
        connection.send(content: data,
                        completion: .contentProcessed { _ in })
    }
}

private final class StubQLinkServerChecker: QLinkReloadedConnectionChecking, @unchecked Sendable {
    private let result: QLinkReloadedServerCheckResult
    private(set) var didValidate = false
    private(set) var validatedHost: String?
    private(set) var validatedPort: Int?

    init(result: QLinkReloadedServerCheckResult) {
        self.result = result
    }

    func validateQLinkServer(host: String, port: Int) async -> QLinkReloadedServerCheckResult {
        didValidate = true
        validatedHost = host
        validatedPort = port
        return result
    }
}

private enum NetworkTestPort {
    static func reserveLoopbackPort() throws -> NWEndpoint.Port {
        let descriptor = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
        guard descriptor >= 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
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
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }

        var boundAddress = sockaddr_in()
        var boundAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                getsockname(descriptor, socketAddress, &boundAddressLength)
            }
        }
        guard nameResult == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }

        let port = UInt16(bigEndian: boundAddress.sin_port)
        guard let endpointPort = NWEndpoint.Port(rawValue: port),
              port != 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(EADDRNOTAVAIL))
        }

        return endpointPort
    }
}
