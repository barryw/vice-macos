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
        let plan = RAMExpansion.vic20_24k.resourcePlan(for: .xvic)

        XCTAssertTrue(plan.requiresHardReset)
        XCTAssertEqual(plan.value(for: "RAMBlock0"), 0)
        XCTAssertEqual(plan.value(for: "RAMBlock1"), 1)
        XCTAssertEqual(plan.value(for: "RAMBlock2"), 1)
        XCTAssertEqual(plan.value(for: "RAMBlock3"), 1)
        XCTAssertEqual(plan.value(for: "RAMBlock5"), 0)
    }

    func testVIC20RAMExpansionDisableStillRequiresHardReset() {
        let plan = RAMExpansion.none.resourcePlan(for: .xvic)

        XCTAssertTrue(plan.requiresHardReset)
        XCTAssertEqual(plan.value(for: "RAMBlock0"), 0)
        XCTAssertEqual(plan.value(for: "RAMBlock1"), 0)
        XCTAssertEqual(plan.value(for: "RAMBlock2"), 0)
        XCTAssertEqual(plan.value(for: "RAMBlock3"), 0)
        XCTAssertEqual(plan.value(for: "RAMBlock5"), 0)
    }

    func testREUResourcePlanSetsSizeBeforeEnable() {
        let plan = RAMExpansion.reu512.resourcePlan(for: .x64sc)

        XCTAssertFalse(plan.requiresHardReset)
        XCTAssertEqual(plan.enableAssignments.map(\.name), ["REUsize", "REU"])
        XCTAssertEqual(plan.value(for: "REUsize"), 512)
        XCTAssertEqual(plan.value(for: "REU"), 1)
    }

    private func startupConfiguration(for machine: EmulatedMachine,
                                      displayOutput: MachineDisplayOutput? = nil,
                                      ramExpansion: RAMExpansion = .none,
                                      driveConfigurations: [DriveConfiguration]? = nil) -> MachineStartupConfiguration {
        MachineStartupConfiguration(executablePath: "/tmp/vice",
                                    dataDirectory: "/tmp/data",
                                    videoStandard: .ntsc,
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
        .xplus4
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
