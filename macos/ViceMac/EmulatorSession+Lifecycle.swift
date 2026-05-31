import Foundation
import MacVICEKit

extension EmulatorSession {
    func start() {
        guard !didStartEngine else {
            return
        }
        startupError = nil

        guard let executablePath = Bundle.main.executableURL?.path else {
            reportStartupFailure(
                status: "Missing runtime paths",
                detail: "The app bundle is missing its executable."
            )
            return
        }

        let runtime: MacVICERuntime
        do {
            runtime = try MacVICERuntime.resolve(machine: machine.macVICEKitMachine)
        } catch {
            reportStartupFailure(
                status: "Missing VICE runtime",
                detail: error.localizedDescription
            )
            return
        }

        preparePrintSpoolDirectory()
        let networkLocalPort: Int?
        do {
            networkLocalPort = try prepareNetworkModemForStartup()
        } catch {
            reportStartupFailure(
                status: "Unable to start modem",
                detail: error.localizedDescription
            )
            return
        }

        didStartEngine = true

        let startupConfiguration = MachineStartupConfiguration(executablePath: executablePath,
                                                               dataDirectory: runtime.dataDirectoryURL.path,
                                                               machineModel: activeMachineModel,
                                                               videoStandard: videoStandard,
                                                               sidModel: sidModel,
                                                               soundEnabled: soundEnabled,
                                                               soundVolume: soundVolume,
                                                               emulationSpeed: emulationSpeed,
                                                               displayOutput: displayOutput,
                                                               romImages: romImages,
                                                               ramExpansion: ramExpansion,
                                                               mediaBehavior: mediaBehavior,
                                                               sidConfiguration: sidConfiguration,
                                                               tapeConfiguration: tapeConfiguration,
                                                               printerConfiguration: printerConfiguration,
                                                               printerOutputBasePath: printSpoolBasePath,
                                                               driveConfigurations: driveConfigurations,
                                                               syncSystemTime: syncSystemTime,
                                                               networkModem: networkModem,
                                                               networkLocalPort: networkLocalPort)
        let startupArguments = machine.startupArguments(configuration: startupConfiguration)
        let startResult: MacVICEEngineStartResult
        do {
            startResult = try engine.start(machineID: machine.id.rawValue,
                                           dynamicLibraryURL: runtime.dynamicLibraryURL(for: machine.macVICEKitMachine),
                                           arguments: startupArguments)
        } catch {
            didStartEngine = false
            hayesModemService.stop()
            reportStartupFailure(
                status: "Unable to start \(machine.shortName)",
                detail: error.localizedDescription
            )
            return
        }

        didStartEngine = engine.isRunning

        if engine.isRunning {
            applyRuntimeConfiguration()
        }

        if startResult == .started {
            statusText = "\(machine.shortName) running"
        } else if engine.isRunning {
            statusText = "\(machine.shortName) already running"
        } else {
            hayesModemService.stop()
            reportStartupFailure(
                status: "Unable to start \(machine.shortName)",
                detail: lastEngineErrorMessage() ?? "The emulator engine did not start."
            )
        }
    }

    private func reportStartupFailure(status: String, detail: String) {
        statusText = status
        startupError = EmulatorStartupError(title: "Unable to Start \(machine.shortName)",
                                            message: detail)
    }

    private func lastEngineErrorMessage() -> String? {
        MacVICEEngineSession.lastError
    }

    func reset(kind: MachineResetKind = .soft) {
        guard engine.isRunning else {
            return
        }

        if isPaused {
            isPaused = false
        }

        _ = engine.reset(hard: kind == .hard)
        statusText = kind.statusText
    }

    func togglePause() {
        pausedBecauseAppInactive = false
        isPaused.toggle()
    }

    func handleApplicationActivationChanged(isActive: Bool) {
        guard sessionBehavior.pauseWhenAppInactive else {
            return
        }

        if isActive {
            guard pausedBecauseAppInactive else {
                return
            }

            pausedBecauseAppInactive = false
            if isPaused {
                isPaused = false
            }
            return
        }

        guard !isPaused else {
            pausedBecauseAppInactive = false
            return
        }

        pausedBecauseAppInactive = true
        isPaused = true
    }

    func applyFilterPreset(_ preset: VideoFilterPreset) {
        filterSettings = VideoFilterSettings.defaults(for: preset)
        statusText = "\(preset.title) display"
    }
}
