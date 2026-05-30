import Foundation

extension EmulatorSession {
    func applyRuntimeConfiguration() {
        if machine.supportsRuntimeVideoStandardUpdates {
            applyVideoStandard(updateStatus: false)
        }
        applySessionBehavior(oldValue: sessionBehavior)
        applyMediaBehavior(updateStatus: false)
        applyPrinterConfiguration(updateStatus: false)
        applySIDModel(updateStatus: false)
        applySIDConfiguration(updateStatus: false)
        applySoundSettings(updateStatus: false)
        applyTapeConfiguration(updateStatus: false)
        applyEmulationSpeed(updateStatus: false)
        applyDisplayOutput(updateStatus: false)
        applyPauseState(updateStatus: false)
        applyNetworkModem(updateStatus: false)
        if machine.supportsRuntimeROMImageUpdates {
            applyROMImages()
        }
        applyRAMExpansion(updateStatus: false)
        applyKeyboardMapping(updateStatus: false)
        applyControlPorts()
        applySystemTimeSync(updateStatus: false)
    }

    func applySessionBehavior(oldValue: SessionBehaviorConfiguration) {
        guard oldValue.pauseWhenAppInactive,
              !sessionBehavior.pauseWhenAppInactive,
              pausedBecauseAppInactive else {
            return
        }

        pausedBecauseAppInactive = false
        if isPaused {
            isPaused = false
        }
    }

    func applySystemTimeSync(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              machine.capabilities.supportsSystemTimeSync else {
            return
        }

        if ViceEngineSetSystemTimeSyncEnabled(syncSystemTime), updateStatus {
            statusText = syncSystemTime ? "System time synced" : "System time sync off"
        }
    }

    func applyPauseState(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
            return
        }

        _ = ViceEngineSetPauseEnabled(isPaused)

        if updateStatus {
            statusText = isPaused ? "Paused" : "Running"
        }
    }

    func applyVideoStandard(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              machine.capabilities.supportsVideoStandardSelection else {
            return
        }

        if case .x64sc = activeMachineModel {
            applyMachineModel(updateStatus: false)
            applySIDModel(updateStatus: false)
            applySIDConfiguration(updateStatus: false)
            applyROMImages()
            applyDriveConfigurations(updateStatus: false)
        } else {
            for assignment in machine.videoStandardAssignments(for: videoStandard) {
                setVICEIntResource(assignment.name, value: assignment.value)
            }
        }

        if updateStatus {
            statusText = "Video \(videoStandard.rawValue)"
        }
    }

    func applySIDModel(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              machine.capabilities.supportsSIDModelSelection else {
            return
        }

        ViceResource.sidModel.withCString { resourceName in
            _ = ViceEngineSetIntResource(resourceName, sidModel.rawValue)
        }

        if updateStatus {
            statusText = "SID \(sidModel.title)"
        }
    }

    func applySIDConfiguration(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              machine.capabilities.supportsSIDModelSelection else {
            return
        }

        setVICEIntResource("Sid2AddressStart", value: sidConfiguration.secondAddress.rawValue)
        setVICEIntResource("Sid3AddressStart", value: sidConfiguration.thirdAddress.rawValue)
        setVICEIntResource("SidStereo", value: sidConfiguration.layout.extraSIDCount)

        if updateStatus {
            statusText = sidConfiguration.layout.title
        }
    }

    func applyMediaBehavior(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
            return
        }

        setVICEIntResource("AutostartWarp", value: mediaBehavior.warpDuringAutostart ? 1 : 0)
        setVICEIntResource("AutostartHandleTrueDriveEmulation",
                           value: mediaBehavior.useTrueDriveDuringAutostart ? 1 : 0)

        if updateStatus {
            statusText = "Media opens with \(mediaBehavior.openBehavior.title.lowercased())"
        }
    }

    func applyPrinterConfiguration(updateStatus: Bool = true,
                                           previousDeviceNumber: Int? = nil) {
        guard ViceEngineIsRunning() else {
            return
        }

        preparePrintSpoolDirectory()

        let device = printerConfiguration.deviceNumber
        if let previousDeviceNumber,
           previousDeviceNumber != device {
            setVICEIntResource("Printer\(previousDeviceNumber)", value: 0)
            setVICEIntResource("BusDevice\(previousDeviceNumber)", value: 0)
        }

        setVICEStringResource("PrinterTextDevice1", value: printSpoolBasePath)
        setVICEIntResource("Printer\(device)TextDevice", value: 0)
        setVICEStringResource("Printer\(device)Driver", value: printerConfiguration.model.viceDriverName)
        setVICEStringResource("Printer\(device)Output", value: printerConfiguration.model.outputMode)
        setVICEIntResource("Printer\(device)", value: printerConfiguration.isEnabled ? 1 : 0)
        setVICEIntResource("BusDevice\(device)", value: printerConfiguration.isEnabled ? 1 : 0)

        if updateStatus {
            statusText = "Printer \(printerConfiguration.statusTitle.lowercased())"
        }
    }

    func applyTapeConfiguration(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              machine.capabilities.supportsTape else {
            return
        }

        setVICEIntResource("TapePort1Device", value: tapeConfiguration.isDatasetteEnabled ? 1 : 0)
        setVICEIntResource("DatasetteSound", value: tapeConfiguration.soundEnabled ? 1 : 0)
        setVICEIntResource("DatasetteSoundVolume", value: tapeConfiguration.viceSoundVolume)

        if updateStatus {
            statusText = tapeConfiguration.isDatasetteEnabled ? "Datasette connected" : "Datasette disconnected"
        }
    }

    func applyEmulationSpeed(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
            return
        }

        setVICEIntResource(ViceResource.speed, value: emulationSpeed.speedPercent)
        _ = ViceEngineSetWarpMode(emulationSpeed.isWarpEnabled)

        if updateStatus {
            statusText = emulationSpeed.isWarpEnabled ? "Warp enabled" : "Speed \(emulationSpeed.title)"
        }
    }

    func applyDisplayOutput(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              machine.supportsDisplayOutputSelection,
              let resourceName = displayOutput.resourceName else {
            return
        }

        setVICEIntResource(resourceName, value: displayOutput.resourceValue)

        if updateStatus {
            statusText = "Display \(displayOutput.statusTitle)"
        }
    }

    func applyMachineModelChange(_ model: MachineModel) {
        if let defaultSIDModel = model.defaultSIDModel,
           sidModel != defaultSIDModel {
            sidModel = defaultSIDModel
        }

        applyMachineModel()
        applySIDModel(updateStatus: false)
        applySIDConfiguration(updateStatus: false)
        applyROMImages()
        applyDriveConfigurations(updateStatus: false)
    }

    func applyMachineModel(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              activeMachineModel.supportsRuntimeModelSelection,
              let modelName = activeMachineModel.viceModelName(for: videoStandard) else {
            return
        }

        let didQueueModel = modelName.withCString { modelNamePointer in
            ViceEngineSetMachineModel(modelNamePointer)
        }
        guard didQueueModel else {
            if updateStatus {
                statusText = "\(machineDisplayName) model unavailable"
            }
            return
        }

        if updateStatus {
            statusText = machineDisplayName
        }
    }

    func applySoundSettings(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
            return
        }

        setVICEIntResource(ViceResource.sound, value: soundEnabled ? 1 : 0)
        setVICEIntResource(ViceResource.soundVolume, value: Int32(soundVolume))

        if updateStatus {
            statusText = soundEnabled ? "Volume \(soundVolume)" : "Muted"
        }
    }

    func applyROMImages() {
        guard ViceEngineIsRunning() else {
            return
        }

        for slot in machine.romSlots {
            setVICEStringResource(slot.resourceName,
                                  value: romResourceValue(for: slot))
        }
    }

    func applyRAMExpansion(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              machine.capabilities.supportsRAMExpansion,
              machine.ramExpansions.contains(ramExpansion) else {
            return
        }

        let plan = ramExpansion.resourcePlan(for: machine)
        for assignment in plan.disableAssignments + plan.enableAssignments {
            setVICEIntResource(assignment.name, value: assignment.value)
        }

        if updateStatus {
            if plan.requiresHardReset {
                _ = ViceEngineTriggerMachineReset(true)
            }
            statusText = "RAM expansion \(ramExpansion.statusTitle)"
        }
    }

    func applyKeyboardMapping(updateStatus: Bool = true, forceReload: Bool = false) {
        guard ViceEngineIsRunning() else {
            return
        }

        if keyboardMapping.profile == .custom {
            do {
                try VICEKeymapStore.ensureCustomKeymap(for: keyboardMappingMachine,
                                                       mode: keyboardMapping.mode)
                setVICEStringResource(keyboardMapping.mode.userResourceName,
                                      value: VICEKeymapStore.customKeymapURL(for: keyboardMappingMachine,
                                                                             mode: keyboardMapping.mode).path)
                if forceReload {
                    setVICEIntResource("KeymapIndex", value: keyboardMapping.mode.defaultKeymapIndex)
                }
            } catch {
                statusText = error.localizedDescription
                return
            }
        }

        setVICEIntResource("KeymapIndex", value: keyboardMapping.keymapIndex)

        if updateStatus {
            statusText = "Keyboard \(keyboardMapping.statusTitle)"
        }
    }

    func applyControlPorts() {
        guard ViceEngineIsRunning() else {
            return
        }

        var hasMouse1351 = false

        for port in availableControlPorts {
            guard let controlDevice = controlPorts.assignedDevice(for: port) else {
                setVICEIntResource(port.resourceName, value: ViceJoyPortDevice.none)
                publishJoystickValue(0, to: port)
                continue
            }

            setVICEIntResource(port.resourceName, value: controlDevice.kind.viceJoyPortDevice)
            if controlDevice.kind == .mouse1351 {
                hasMouse1351 = true
                controlPortValues[port] = mouseButtonJoystickValue
            } else {
                publishJoystickValue(currentJoystickValue(for: controlDevice), to: port)
            }
        }

        setVICEIntResource("Mouse", value: hasMouse1351 ? 1 : 0)
        if !hasMouse1351 {
            releaseMouseButtons()
            _ = ViceEngineResetMouse()
        }
    }

    func applyDriveConfigurations(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
            return
        }

        applyDriveSoundSettings()

        for configuration in driveConfigurations {
            let driveType = configuration.isAttached ? configuration.driveType.rawValue : 0

            setVICEIntResource("Drive\(configuration.unit)Type", value: driveType)
            applyDriveAccessMode(configuration)
            applyDiskWriteProtection(configuration)
        }

        if updateStatus {
            statusText = "Drive settings updated"
        }
    }

    func applyDriveConfigurationChanges(from oldConfigurations: [DriveConfiguration]) {
        guard ViceEngineIsRunning() else {
            return
        }

        guard driveConfigurations.map(\.unit) == oldConfigurations.map(\.unit) else {
            applyDriveConfigurations()
            return
        }

        var accessModeUpdates: [DriveConfiguration] = []
        var driveProtectionUpdates: [DriveConfiguration] = []
        var driveSoundSettingsChanged = false

        for configuration in driveConfigurations {
            guard let oldConfiguration = oldConfigurations.first(where: { $0.unit == configuration.unit }) else {
                applyDriveConfigurations()
                return
            }

            guard configuration != oldConfiguration else {
                continue
            }

            let driveHardwareUnchanged = configuration.isAttached == oldConfiguration.isAttached
                && configuration.driveType == oldConfiguration.driveType
            let accessModeChanged = configuration.accessMode != oldConfiguration.accessMode
            let driveProtectionChanged = configuration.protectsInsertedDisks != oldConfiguration.protectsInsertedDisks
            let driveSoundChanged = configuration.soundEnabled != oldConfiguration.soundEnabled
                || configuration.soundVolume != oldConfiguration.soundVolume

            guard driveHardwareUnchanged else {
                applyDriveConfigurations()
                return
            }

            if accessModeChanged {
                accessModeUpdates.append(configuration)
            }

            if driveSoundChanged {
                driveSoundSettingsChanged = true
            }

            if driveProtectionChanged {
                driveProtectionUpdates.append(configuration)
            }

            guard accessModeChanged || driveSoundChanged || driveProtectionChanged else {
                applyDriveConfigurations()
                return
            }
        }

        if driveSoundSettingsChanged {
            applyDriveSoundSettings()
        }

        for configuration in accessModeUpdates {
            applyDriveAccessMode(configuration)
        }

        for configuration in driveProtectionUpdates {
            applyDiskWriteProtection(configuration)
        }
    }

    func applyDriveSoundSettings() {
        let driveSoundEnabled = driveConfigurations.contains { $0.isAttached && $0.soundEnabled }
        setVICEIntResource("DriveSoundEmulation", value: driveSoundEnabled ? 1 : 0)
        if driveSoundEnabled,
           let volume = driveConfigurations
               .filter({ $0.isAttached && $0.soundEnabled })
               .map(\.viceSoundVolume)
               .max() {
            setVICEIntResource("DriveSoundEmulationVolume", value: volume)
        }
    }

    private func applyDriveAccessMode(_ configuration: DriveConfiguration) {
        let accessMode = configuration.isAttached ? configuration.accessMode : DriveAccessMode.native

        setVICEIntResource("Drive\(configuration.unit)TrueEmulation",
                           value: accessMode.trueDriveEmulationResourceValue)
        setVICEIntResource("TrapDevice\(configuration.unit)",
                           value: accessMode.trapDeviceResourceValue)
    }

    func applyDiskWriteProtection(_ configuration: DriveConfiguration) {
        for driveNumber in configuration.driveType.driveNumbers {
            setVICEIntResource("AttachDevice\(configuration.unit)d\(driveNumber)Readonly",
                               value: configuration.protectsInsertedDisks ? 1 : 0)
        }
    }

    func setVICEIntResource(_ name: String, value: Int32) {
        name.withCString { resourceName in
            _ = ViceEngineSetIntResource(resourceName, value)
        }
    }

    func setVICEStringResource(_ name: String, value: String) {
        name.withCString { resourceName in
            value.withCString { resourceValue in
                _ = ViceEngineSetStringResource(resourceName, resourceValue)
            }
        }
    }
}
