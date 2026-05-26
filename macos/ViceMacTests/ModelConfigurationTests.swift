import CoreGraphics
import Foundation
import XCTest

final class ModelConfigurationTests: XCTestCase {
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
        XCTAssertFalse(configuration.soundEnabled)
        XCTAssertEqual(configuration.soundVolume, 25)
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

    func testTEDMachinesKeepVideoAndROMChangesInStartupArguments() {
        let machine = EmulatedMachine.xplus4

        XCTAssertFalse(machine.supportsRuntimeVideoStandardUpdates)
        XCTAssertFalse(machine.supportsRuntimeROMImageUpdates)
    }

    func testTEDPrototypeModelsAreNTSConly() {
        XCTAssertTrue(EmulatedMachine.xplus4.capabilities.supportsVideoStandardSelection)
        XCTAssertTrue(EmulatedMachine.xc16.capabilities.supportsVideoStandardSelection)
        XCTAssertFalse(EmulatedMachine.xc232.capabilities.supportsVideoStandardSelection)
        XCTAssertFalse(EmulatedMachine.xv364.capabilities.supportsVideoStandardSelection)
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

        XCTAssertEqual(Set(autosaveNames).count, Self.allMachines.count)
        XCTAssertEqual(EmulatedMachine.x64sc.mainWindowFrameAutosaveName, "ViceMac.MainWindow.x64sc")
        XCTAssertTrue(autosaveNames.allSatisfy { $0.hasPrefix("ViceMac.MainWindow.") })
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

    func testOpenAIModelListDecodesModelIDs() throws {
        let json = """
        {
          "object": "list",
          "data": [
            { "id": "gpt-5.5", "object": "model" },
            { "id": "gpt-5.4", "object": "model" }
          ]
        }
        """.data(using: .utf8)!

        let models = try AIAssistantModelService.decodeOpenAIModels(from: json)

        XCTAssertEqual(models.map(\.id), ["gpt-5.5", "gpt-5.4"])
        XCTAssertEqual(models.first?.menuTitle, "gpt-5.5")
    }

    func testAnthropicModelListDecodesDisplayNames() throws {
        let json = """
        {
          "data": [
            {
              "type": "model",
              "id": "claude-sonnet-4-5-20250929",
              "display_name": "Claude Sonnet 4.5",
              "created_at": "2025-09-29T00:00:00Z"
            }
          ],
          "has_more": false
        }
        """.data(using: .utf8)!

        let models = try AIAssistantModelService.decodeAnthropicModels(from: json)

        XCTAssertEqual(models.first?.id, "claude-sonnet-4-5-20250929")
        XCTAssertEqual(models.first?.menuTitle, "Claude Sonnet 4.5 (claude-sonnet-4-5-20250929)")
    }

    func testOpenAIResponseDecodesTextAndFunctionCalls() throws {
        let json = """
        {
          "id": "resp_123",
          "output": [
            {
              "type": "message",
              "content": [
                {
                  "type": "output_text",
                  "text": "I can do that."
                }
              ]
            },
            {
              "type": "function_call",
              "call_id": "call_123",
              "name": "submit_line",
              "arguments": "{\\"line\\":\\"10 PRINT \\\\\\"HI\\\\\\"\\"}"
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try AIAssistantConversationService.decodeOpenAIResponse(from: json)

        XCTAssertEqual(response.id, "resp_123")
        XCTAssertEqual(response.text, "I can do that.")
        XCTAssertEqual(response.toolCalls.first?.id, "call_123")
        XCTAssertEqual(response.toolCalls.first?.name, "submit_line")
    }

    func testAnthropicResponseDecodesTextAndToolUse() throws {
        let json = """
        {
          "id": "msg_123",
          "type": "message",
          "role": "assistant",
          "content": [
            {
              "type": "text",
              "text": "Writing the line now."
            },
            {
              "type": "tool_use",
              "id": "toolu_123",
              "name": "submit_line",
              "input": {
                "line": "10 PRINT \\"HI\\""
              }
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try AIAssistantConversationService.decodeAnthropicResponse(from: json)

        XCTAssertEqual(response.text, "Writing the line now.")
        XCTAssertEqual(response.toolCalls.first?.id, "toolu_123")
        XCTAssertEqual(response.toolCalls.first?.name, "submit_line")
        XCTAssertEqual(response.rawContent.count, 2)
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
                                      driveConfigurations: [DriveConfiguration]? = nil) -> MachineStartupConfiguration {
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
                                    driveConfigurations: driveConfigurations ?? machine.defaultDriveConfigurations())
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

    private func temporaryURL(pathExtension: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(pathExtension)
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

    private func clearBAMBit(track: Int, sector: Int, in bam: inout Data) {
        let entry = 4 + (track - 1) * 4
        bam[entry + 1 + sector / 8] &= ~UInt8(1 << (sector % 8))
        bam[entry] = bam[entry] &- 1
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
