import Foundation

struct DriveStatusSnapshot {
    let unit: Int
    let enabled: Bool
    let driveType: Int32
    let activeDriveNumber: UInt32
    let ledColor: UInt32
    let ledIntensity: UInt32
    let errorIntensity: UInt32
    let drive0LEDIntensity: UInt32
    let drive1LEDIntensity: UInt32
    let track: UInt32?
    let halfTrack: UInt32?
    let diskSide: UInt32
    let driveStatusCode: Int32
    let driveStatusText: String?
    let imagePath: String?
    let drive0ImagePath: String?
    let drive1ImagePath: String?
}

struct CartridgeStatusSnapshot {
    let isAttached: Bool
    let cartridgeID: Int32
    let cartridgeFlags: UInt32
    let romSize: UInt32
    let chipCount: UInt32
    let bankCount: UInt32
    let cartridgeName: String?
    let imagePath: String?
}

let viceFrameCallback: @convention(c) (
    UnsafePointer<ViceEngineVideoFrame>?,
    UnsafeMutableRawPointer?
) -> Void = { framePointer, context in
    guard let framePointer,
          let context,
          let pixels = framePointer.pointee.pixels else {
        return
    }

    let frame = framePointer.pointee
    let byteCount = UInt64(frame.stride) * UInt64(frame.height)
    guard frame.pixelFormat == 1,
          frame.width > 0,
          frame.height > 0,
          UInt64(frame.stride) >= UInt64(frame.width) * 4,
          byteCount <= UInt64(Int.max) else {
        return
    }

    let source = Unmanaged<EmulatorFrameSource>.fromOpaque(context).takeUnretainedValue()
    let pixelData = Data(bytes: pixels, count: Int(byteCount))

    source.publish(EmulatorVideoFrame(width: Int(frame.width),
                                      height: Int(frame.height),
                                      bytesPerRow: Int(frame.stride),
                                      sequence: frame.sequence,
                                      pixels: pixelData))
}

let viceDriveStatusCallback: @convention(c) (
    UnsafePointer<ViceEngineDriveStatus>?,
    UnsafeMutableRawPointer?
) -> Void = { statusPointer, context in
    guard let statusPointer,
          let context else {
        return
    }

    let status = statusPointer.pointee
    let session = Unmanaged<EmulatorSession>.fromOpaque(context).takeUnretainedValue()

    let snapshot = DriveStatusSnapshot(unit: Int(status.unit),
                                       enabled: status.enabled,
                                       driveType: status.driveType,
                                       activeDriveNumber: status.activeDriveNumber,
                                       ledColor: status.ledColor,
                                       ledIntensity: status.ledIntensity,
                                       errorIntensity: status.errorIntensity,
                                       drive0LEDIntensity: status.drive0LEDIntensity,
                                       drive1LEDIntensity: status.drive1LEDIntensity,
                                       track: status.trackValid ? status.track : nil,
                                       halfTrack: status.trackValid ? status.halfTrack : nil,
                                       diskSide: status.diskSide,
                                       driveStatusCode: status.driveStatusCode,
                                       driveStatusText: optionalString(from: status.driveStatusText),
                                       imagePath: optionalString(from: status.imagePath),
                                       drive0ImagePath: optionalString(from: status.drive0ImagePath),
                                       drive1ImagePath: optionalString(from: status.drive1ImagePath))

    Task { @MainActor in
        session.handleDriveStatus(snapshot)
    }
}

let viceCartridgeStatusCallback: @convention(c) (
    UnsafePointer<ViceEngineCartridgeStatus>?,
    UnsafeMutableRawPointer?
) -> Void = { statusPointer, context in
    guard let statusPointer,
          let context else {
        return
    }

    let status = statusPointer.pointee
    let session = Unmanaged<EmulatorSession>.fromOpaque(context).takeUnretainedValue()

    let snapshot = CartridgeStatusSnapshot(isAttached: status.attached,
                                           cartridgeID: status.cartridgeID,
                                           cartridgeFlags: status.cartridgeFlags,
                                           romSize: status.romSize,
                                           chipCount: status.chipCount,
                                           bankCount: status.bankCount,
                                           cartridgeName: optionalString(from: status.cartridgeName),
                                           imagePath: optionalString(from: status.imagePath))

    Task { @MainActor in
        session.handleCartridgeStatus(snapshot)
    }
}

private func optionalString(from cString: UnsafePointer<CChar>?) -> String? {
    guard let cString,
          cString.pointee != 0 else {
        return nil
    }

    return String(cString: cString)
}
