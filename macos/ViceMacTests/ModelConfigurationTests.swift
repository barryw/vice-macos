import AppKit
import CoreGraphics
import Darwin
import Foundation
import MacVICEKit
@preconcurrency import Network
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
                                              transportMode: .raw,
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
                                              transportMode: .raw,
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

        return image
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
