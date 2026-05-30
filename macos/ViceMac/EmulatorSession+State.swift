import Foundation

extension EmulatorSession {
    var isRAMExpansionConfigured: Bool {
        machine.capabilities.supportsRAMExpansion && ramExpansion != .none
    }

    var activeMachineModel: MachineModel {
        switch machine.family {
        case .c64:
            return .x64sc(c64Model)
        case .c128:
            return .x128(c128Model)
        case .pet:
            return .xpet(petModel)
        case .vic20, .ted:
            return machine.model
        }
    }

    var keyboardMappingMachine: EmulatedMachine {
        guard machine.family == .pet else {
            return machine
        }

        return EmulatedMachine(id: machine.id,
                               model: .xpet(petModel),
                               displayName: petModel.displayName,
                               shortName: machine.shortName,
                               viceTarget: machine.viceTarget,
                               dynamicLibraryName: machine.dynamicLibraryName,
                               displayProfile: machine.displayProfile,
                               startupOptions: machine.startupOptions,
                               displayOutputs: machine.displayOutputs,
                               romSlots: machine.romSlots,
                               ramExpansions: machine.ramExpansions,
                               capabilities: machine.capabilities,
                               videoStandardResources: machine.videoStandardResources)
    }

    var machineDisplayName: String {
        activeMachineModel.displayName ?? machine.displayName
    }

    var machineModelStatusTitle: String? {
        guard activeMachineModel.supportsRuntimeModelSelection else {
            return nil
        }

        return activeMachineModel.statusChipTitle
    }

    var availableControlPorts: [ControlPort] {
        machine.capabilities.controlPorts
    }

    var availableModemInterfaces: [NetworkModemInterface] {
        machine.capabilities.supportedModemInterfaces
    }

    var availableModemACIAAddresses: [NetworkModemACIAAddress] {
        NetworkModemACIAAddress.supportedAddresses(for: machine)
    }

    func romResourceValue(for slot: MachineROMSlot) -> String {
        machine.romResourceValue(for: slot,
                                 romImages: romImages,
                                 videoStandard: videoStandard,
                                 machineModel: activeMachineModel)
    }

    var hasMultipleControlPorts: Bool {
        availableControlPorts.count > 1
    }

    var isMacMouseInputActive: Bool {
        isMouse1351Assigned
    }

    var visibleDriveActivities: [DriveActivity] {
        driveConfigurations.compactMap { configuration in
            guard configuration.isAttached else {
                return nil
            }

            if var activity = driveActivities[configuration.unit] {
                activity.isConfigured = true
                activity.driveType = configuration.driveType
                activity.accessMode = configuration.accessMode
                activity.slots = normalizedDriveSlots(activity.slots, for: configuration.driveType)
                return activity
            }

            return DriveActivity(unit: configuration.unit,
                                 isConfigured: true,
                                 driveType: configuration.driveType,
                                 accessMode: configuration.accessMode,
                                 activeDriveNumber: 0,
                                 slots: defaultDriveSlots(for: configuration.driveType),
                                 ledColor: configuration.driveType.defaultLEDColor,
                                 ledIntensity: 0,
                                 errorIntensity: 0,
                                 track: nil,
                                 halfTrack: nil,
                                 diskSide: 0,
                                 driveStatusCode: 0,
                                 driveStatusText: nil,
                                 imagePath: nil)
        }
    }

    func diskImagePath(for unit: Int, driveNumber: Int) -> String? {
        visibleDriveActivities
            .first { $0.unit == unit }?
            .slots
            .first { $0.driveNumber == driveNumber }?
            .imagePath
    }

    func hasDiskAttached(to unit: Int, driveNumber: Int) -> Bool {
        diskImagePath(for: unit, driveNumber: driveNumber)?.isEmpty == false
    }

    private func defaultDriveSlots(for driveType: DriveType) -> [DriveSlotActivity] {
        driveType.driveNumbers.map { driveNumber in
            DriveSlotActivity(driveNumber: driveNumber,
                              ledColor: driveType.ledColor(forDriveNumber: driveNumber),
                              ledIntensity: 0,
                              imagePath: nil)
        }
    }

    private func normalizedDriveSlots(_ slots: [DriveSlotActivity], for driveType: DriveType) -> [DriveSlotActivity] {
        driveType.driveNumbers.map { driveNumber in
            if var slot = slots.first(where: { $0.driveNumber == driveNumber }) {
                slot.ledColor = driveType.ledColor(forDriveNumber: driveNumber)
                return slot
            }

            return DriveSlotActivity(driveNumber: driveNumber,
                                     ledColor: driveType.ledColor(forDriveNumber: driveNumber),
                                     ledIntensity: 0,
                                     imagePath: nil)
        }
    }
}
