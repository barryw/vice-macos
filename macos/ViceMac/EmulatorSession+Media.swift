import AppKit
import CoreGraphics
import Foundation
import MacVICEKit

extension EmulatorSession {
    func handleDriveStatus(_ status: MacVICEDriveStatus) {
        guard let driveType = DriveType(rawValue: status.driveType) else {
            driveActivities.removeValue(forKey: status.unit)
            return
        }

        let slots = driveType.driveNumbers.map { driveNumber in
            DriveSlotActivity(driveNumber: driveNumber,
                              ledColor: driveType.ledColor(forDriveNumber: driveNumber),
                              ledIntensity: driveNumber == 0 ? status.drive0LEDIntensity : status.drive1LEDIntensity,
                              imagePath: driveNumber == 0 ? status.drive0ImagePath : status.drive1ImagePath)
        }

        let activity = DriveActivity(unit: status.unit,
                                     isConfigured: status.enabled,
                                     driveType: driveType,
                                     accessMode: driveAccessMode(for: Int(status.unit)),
                                     activeDriveNumber: Int(status.activeDriveNumber),
                                     slots: slots,
                                     ledColor: DriveLEDColor(viceColor: status.ledColor),
                                     ledIntensity: status.ledIntensity,
                                     errorIntensity: status.errorIntensity,
                                     track: status.track,
                                     halfTrack: status.halfTrack,
                                     diskSide: status.diskSide,
                                     driveStatusCode: status.driveStatusCode,
                                     driveStatusText: status.driveStatusText,
                                     imagePath: status.imagePath)

        if driveActivities[status.unit] != activity {
            driveActivities[status.unit] = activity
        }
    }

    func handleCartridgeStatus(_ status: MacVICECartridgeStatus) {
        cartridgeStatus = CartridgeStatus(isAttached: status.isAttached,
                                          cartridgeID: status.cartridgeID,
                                          cartridgeFlags: status.cartridgeFlags,
                                          romSize: status.romSize,
                                          chipCount: status.chipCount,
                                          bankCount: status.bankCount,
                                          cartridgeName: status.cartridgeName,
                                          imagePath: status.imagePath)
    }

    func resetDrive(_ unit: Int) {
        guard unit >= 8 && unit <= 11 else {
            return
        }

        _ = engine.resetDrive(unit: UInt32(unit))
    }

    func previewDriveSound(for configuration: DriveConfiguration) {
        guard engine.isRunning,
              configuration.isAttached,
              configuration.soundEnabled,
              configuration.soundVolume > 0,
              configuration.unit >= 8,
              configuration.unit <= 11 else {
            return
        }

        applyDriveSoundSettings()
        _ = engine.previewDriveSound(unit: UInt32(configuration.unit))
    }

    @discardableResult
    func openMedia(url: URL, autorun: Bool = false) -> Bool {
        openMedia(url: url, behavior: autorun ? .run : nil)
    }

    @discardableResult
    func openMedia(url: URL, behavior: MediaOpenBehavior?) -> Bool {
        guard let mediaFile = EmulatorMediaFile(url: url) else {
            let title = url.lastPathComponent.isEmpty ? "Media" : url.lastPathComponent
            statusText = "\(title) is not a supported media file"
            return false
        }

        let openBehavior = behavior ?? mediaBehavior.openBehavior

        switch mediaFile {
        case let .disk(diskImageType):
            return attachDiskToFirstCompatibleDrive(url: url,
                                                    diskImageType: diskImageType,
                                                    behavior: openBehavior)
        case let .autostart(type):
            if type == .tap,
               openBehavior == .attach {
                return attachTape(url: url)
            }

            let didOpen = autostartMedia(url: url, behavior: openBehavior == .attach ? .load : openBehavior)
            if didOpen,
               type == .tap {
                tapeImagePath = url.path
            }
            return didOpen
        case .cartridge:
            return attachCartridge(url: url)
        case .snapshot:
            return loadSnapshot(url: url)
        }
    }

    func openMedia(urls: [URL], autorun: Bool = false) {
        urls.forEach { url in
            openMedia(url: url, autorun: autorun)
        }
    }

    @discardableResult
    func attachDisk(to unit: Int, url: URL, autorun: Bool) -> Bool {
        attachDisk(to: unit, driveNumber: 0, url: url, behavior: autorun ? .run : .attach)
    }

    @discardableResult
    func attachDisk(to unit: Int, driveNumber: Int, url: URL, autorun: Bool) -> Bool {
        attachDisk(to: unit, driveNumber: driveNumber, url: url, behavior: autorun ? .run : .attach)
    }

    @discardableResult
    func attachDisk(to unit: Int, driveNumber: Int, url: URL, behavior: MediaOpenBehavior) -> Bool {
        guard unit >= 8 && unit <= 11 else {
            return false
        }

        guard let configuration = driveConfigurations.first(where: { $0.unit == unit }),
              configuration.isAttached else {
            statusText = "Drive \(unit) is disabled"
            return false
        }

        guard configuration.storageKind != .sharedFolder else {
            statusText = "Drive \(unit) is a Shared Mac Folder"
            return false
        }

        guard configuration.driveType.driveNumbers.contains(driveNumber) else {
            statusText = "Drive \(unit):\(driveNumber) is not available on \(configuration.driveType.title)"
            return false
        }

        guard configuration.driveType.supportsDiskImage(url: url) else {
            let fileType = DiskImageFileType(url: url)?.title
                ?? (url.pathExtension.isEmpty ? "File" : url.pathExtension.uppercased())
            statusText = "\(fileType) is not supported by drive \(unit) (\(configuration.driveType.title))"
            return false
        }

        applyDiskWriteProtection(configuration)
        applyMediaBehavior(updateStatus: false)

        let didAttach = engine.attachDisk(unit: UInt32(unit),
                                          drive: UInt32(driveNumber),
                                          url: url,
                                          runMode: behavior.macVICERunMode)

        if didAttach {
            rememberMedia(url)
            statusText = "\(url.lastPathComponent) \(behavior.statusVerb) on \(driveAddress(unit: unit, driveNumber: driveNumber))"
        } else {
            statusText = "Unable to attach \(url.lastPathComponent)"
        }

        return didAttach
    }

    @discardableResult
    func detachDisk(from unit: Int, driveNumber: Int = 0) -> Bool {
        guard unit >= 8 && unit <= 11 else {
            return false
        }

        guard let configuration = driveConfigurations.first(where: { $0.unit == unit }),
              configuration.isAttached else {
            statusText = "Drive \(unit) is disabled"
            return false
        }

        guard configuration.storageKind != .sharedFolder else {
            statusText = "Drive \(unit) is a Shared Mac Folder"
            return false
        }

        guard configuration.driveType.driveNumbers.contains(driveNumber) else {
            statusText = "Drive \(unit):\(driveNumber) is not available on \(configuration.driveType.title)"
            return false
        }

        guard hasDiskAttached(to: unit, driveNumber: driveNumber) else {
            statusText = "No disk attached to \(driveAddress(unit: unit, driveNumber: driveNumber))"
            return false
        }

        let didDetach = engine.detachDisk(unit: UInt32(unit), drive: UInt32(driveNumber))
        if didDetach {
            statusText = "Disk detached from \(driveAddress(unit: unit, driveNumber: driveNumber))"
        } else {
            statusText = "Unable to detach disk from \(driveAddress(unit: unit, driveNumber: driveNumber))"
        }

        return didDetach
    }

    @discardableResult
    func autostartMedia(url: URL, autorun: Bool) -> Bool {
        autostartMedia(url: url, behavior: autorun ? .run : .load)
    }

    @discardableResult
    func autostartMedia(url: URL, behavior: MediaOpenBehavior) -> Bool {
        let runBehavior = behavior == .attach ? MediaOpenBehavior.load : behavior
        applyMediaBehavior(updateStatus: false)

        let didStart = engine.autostart(url, runMode: runBehavior.macVICERunMode)

        if didStart {
            rememberMedia(url)
            statusText = "\(url.lastPathComponent) \(runBehavior.statusVerb)"
        } else {
            statusText = "Unable to open \(url.lastPathComponent)"
        }

        return didStart
    }

    @discardableResult
    func attachTape(url: URL) -> Bool {
        guard machine.capabilities.supportsTape else {
            statusText = "\(machineDisplayName) does not support tape media"
            return false
        }

        applyTapeConfiguration(updateStatus: false)

        let didAttach = engine.attachTape(unit: 1, url: url)

        if didAttach {
            tapeImagePath = url.path
            rememberMedia(url)
            statusText = "\(url.lastPathComponent) attached to Datasette"
        } else {
            statusText = "Unable to attach \(url.lastPathComponent)"
        }

        return didAttach
    }

    func detachTape() {
        guard machine.capabilities.supportsTape else {
            return
        }

        if engine.detachTape(unit: 1) {
            tapeImagePath = nil
            statusText = "Tape ejected"
        } else {
            statusText = "Unable to eject tape"
        }
    }

    func controlTape(_ command: TapeControlCommand) {
        guard machine.capabilities.supportsTape else {
            return
        }

        if engine.controlTape(unit: 1, rawCommand: command.rawValue) {
            statusText = "Datasette \(command.title.lowercased())"
        }
    }

    private func driveAddress(unit: Int, driveNumber: Int) -> String {
        guard let configuration = driveConfigurations.first(where: { $0.unit == unit }),
              configuration.driveType.slotCount > 1 else {
            return "drive \(unit)"
        }

        return "drive \(unit):\(driveNumber)"
    }

    func setROMImage(_ image: MachineROMSlot, path: String?) {
        guard machine.romSlots.contains(image) else {
            return
        }

        var updatedImages = romImages
        updatedImages.setPath(path, for: image)
        romImages = updatedImages
    }

    @discardableResult
    func attachCartridge(url: URL) -> Bool {
        guard machine.capabilities.supportsCartridges else {
            statusText = "\(machineDisplayName) does not support cartridges"
            return false
        }

        let didAttach = engine.attachCartridge(url)

        if didAttach {
            rememberMedia(url)
            statusText = "\(url.lastPathComponent) attached"
        } else {
            statusText = "Unable to attach \(url.lastPathComponent)"
        }

        return didAttach
    }

    func detachCartridge() {
        guard machine.capabilities.supportsCartridges else {
            return
        }

        if engine.detachCartridge() {
            statusText = "Cartridge detached"
        } else {
            statusText = "Unable to detach cartridge"
        }
    }

    @discardableResult
    func saveSnapshot(url: URL) -> Bool {
        guard engine.isRunning else {
            statusText = "\(machine.shortName) is not running"
            return false
        }

        let didSave = engine.saveSnapshot(to: url,
                                          includesROMs: snapshotConfiguration.includesROMImages,
                                          includesDisks: snapshotConfiguration.includesAttachedDisks)

        if didSave {
            rememberMedia(url)
            statusText = "Snapshot saved"
        } else {
            statusText = "Unable to save snapshot"
        }

        return didSave
    }

    @discardableResult
    func exportScreenshot(url: URL) -> Bool {
        guard let frame = frameSource.copyLatestFrame() else {
            statusText = "No emulator frame is available yet"
            return false
        }

        do {
            try Self.writePNG(frame: frame, to: url)
            rememberMedia(url)
            statusText = "Screenshot exported"
            return true
        } catch {
            statusText = "Unable to export screenshot"
            return false
        }
    }

    @discardableResult
    func loadSnapshot(url: URL) -> Bool {
        guard engine.isRunning else {
            statusText = "\(machine.shortName) is not running"
            return false
        }

        releaseAllKeys()

        let didLoad = engine.loadSnapshot(from: url)

        if didLoad {
            rememberMedia(url)
            statusText = "Snapshot loaded"
        } else {
            statusText = "Unable to load snapshot"
        }

        return didLoad
    }

    private func attachDiskToFirstCompatibleDrive(url: URL,
                                                  diskImageType: DiskImageFileType,
                                                  behavior: MediaOpenBehavior) -> Bool {
        guard let target = firstCompatibleDriveTarget(for: diskImageType) else {
            statusText = "No enabled drive supports \(diskImageType.title) images"
            return false
        }

        return attachDisk(to: target.unit,
                          driveNumber: target.driveNumber,
                          url: url,
                          behavior: behavior)
    }

    private func firstCompatibleDriveTarget(for diskImageType: DiskImageFileType) -> (unit: Int, driveNumber: Int)? {
        for configuration in driveConfigurations where configuration.isAttached {
            guard configuration.driveType.supportsDiskImage(diskImageType),
                  let driveNumber = configuration.driveType.driveNumbers.first else {
                continue
            }

            return (configuration.unit, driveNumber)
        }

        return nil
    }

    func rememberMedia(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
    }
}
