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
        let arguments = machine.startupArguments(configuration: startupConfiguration(for: machine))

        XCTAssertEqual(machine.family, .pet)
        XCTAssertEqual(machine.viceTarget, "xpet")
        XCTAssertEqual(arguments.value(after: "-model"), "4032")
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

    private func startupConfiguration(for machine: EmulatedMachine,
                                      displayOutput: MachineDisplayOutput? = nil,
                                      videoStandard: EmulatorSession.VideoStandard = .ntsc,
                                      ramExpansion: RAMExpansion = .none,
                                      driveConfigurations: [DriveConfiguration]? = nil) -> MachineStartupConfiguration {
        MachineStartupConfiguration(executablePath: "/tmp/vice",
                                    dataDirectory: "/tmp/data",
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
