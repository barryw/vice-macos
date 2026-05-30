import Foundation

extension EmulatorSession {
    func start() {
        guard !didStartEngine else {
            return
        }
        startupError = nil

        guard let executablePath = Bundle.main.executableURL?.path,
              let dataDirectory = Bundle.main.resourceURL?.appendingPathComponent("VICEData").path,
              let runtimeDirectory = Bundle.main.privateFrameworksURL?.path else {
            reportStartupFailure(
                status: "Missing runtime paths",
                detail: "The app bundle is missing its executable, resources, or Frameworks path."
            )
            return
        }
        let dynamicLibraryPath = URL(fileURLWithPath: runtimeDirectory)
            .appendingPathComponent(machine.dynamicLibraryName)
            .path

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
        ViceEngineSetVideoFrameCallback(viceFrameCallback,
                                        Unmanaged.passUnretained(frameSource).toOpaque())
        ViceEngineSetDriveStatusCallback(viceDriveStatusCallback,
                                         Unmanaged.passUnretained(self).toOpaque())
        ViceEngineSetCartridgeStatusCallback(viceCartridgeStatusCallback,
                                             Unmanaged.passUnretained(self).toOpaque())

        let startupConfiguration = MachineStartupConfiguration(executablePath: executablePath,
                                                               dataDirectory: dataDirectory,
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
        let startResult = machine.id.rawValue.withCString { machineIDPointer in
            dynamicLibraryPath.withCString { dynamicLibraryPathPointer in
                startupArguments.withCStringArray { argumentCount, argumentPointers in
                    ViceEngineStartMachine(machineIDPointer,
                                           dynamicLibraryPathPointer,
                                           argumentCount,
                                           argumentPointers)
                }
            }
        }
        guard let started = startResult else {
            didStartEngine = false
            hayesModemService.stop()
            reportStartupFailure(
                status: "Unable to prepare startup arguments",
                detail: "VICE Mac could not build the emulator startup arguments."
            )
            return
        }

        let isRunning = started || ViceEngineIsRunning()
        didStartEngine = isRunning

        if isRunning {
            applyRuntimeConfiguration()
        }

        if started {
            statusText = "\(machine.shortName) running"
        } else if isRunning {
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
        guard let error = ViceEngineGetLastError() else {
            return nil
        }

        let message = String(cString: error).trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? nil : message
    }

    func reset(kind: MachineResetKind = .soft) {
        guard ViceEngineIsRunning() else {
            return
        }

        if isPaused {
            isPaused = false
        }

        _ = ViceEngineTriggerMachineReset(kind == .hard)
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
