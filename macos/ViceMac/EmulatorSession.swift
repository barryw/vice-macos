import AppKit
import Combine
import Foundation
import GameController

struct DriveConfiguration: Identifiable, Codable, Equatable {
    let unit: Int
    var isAttached: Bool
    var driveType: DriveType
    var accessMode: DriveAccessMode
    var soundEnabled: Bool
    var soundVolume: Int

    var id: Int { unit }

    init(unit: Int,
         isAttached: Bool,
         driveType: DriveType,
         accessMode: DriveAccessMode = .native,
         soundEnabled: Bool,
         soundVolume: Int) {
        self.unit = unit
        self.isAttached = isAttached
        self.driveType = driveType
        self.accessMode = accessMode
        self.soundEnabled = soundEnabled
        self.soundVolume = soundVolume
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        unit = try container.decode(Int.self, forKey: .unit)
        isAttached = try container.decode(Bool.self, forKey: .isAttached)
        driveType = try container.decode(DriveType.self, forKey: .driveType)
        accessMode = try container.decodeIfPresent(DriveAccessMode.self, forKey: .accessMode) ?? .native
        soundEnabled = try container.decode(Bool.self, forKey: .soundEnabled)
        soundVolume = try container.decode(Int.self, forKey: .soundVolume)
    }
}

enum DriveAccessMode: String, CaseIterable, Codable, Identifiable {
    case native
    case fast

    var id: String { rawValue }

    var title: String {
        switch self {
        case .native:
            return "Native"
        case .fast:
            return "Fast"
        }
    }

    var detail: String {
        switch self {
        case .native:
            return "True drive emulation"
        case .fast:
            return "Fast disk access"
        }
    }

    var systemImage: String {
        switch self {
        case .native:
            return "externaldrive"
        case .fast:
            return "bolt.fill"
        }
    }

    var trueDriveEmulationResourceValue: Int32 {
        switch self {
        case .native:
            return 1
        case .fast:
            return 0
        }
    }

    var trapDeviceResourceValue: Int32 {
        switch self {
        case .native:
            return 0
        case .fast:
            return 1
        }
    }
}

struct ControlPortConfiguration: Codable, Equatable {
    var devices: [ControlDeviceConfiguration]
    var port1DeviceID: UUID?
    var port2DeviceID: UUID?

    static let standard: ControlPortConfiguration = {
        let keyboardWASD = ControlDeviceConfiguration.keyboard(name: "Keyboard WASD",
                                                               mapping: .wasdAndSpace)
        let keyboardArrows = ControlDeviceConfiguration.keyboard(name: "Keyboard Arrows",
                                                                 mapping: .arrowsAndSpace)
        let gameController = ControlDeviceConfiguration.joystick(name: "Game Controller")

        return ControlPortConfiguration(devices: [keyboardWASD, keyboardArrows, gameController],
                                        port1DeviceID: nil,
                                        port2DeviceID: gameController.id)
    }()

    func assignedDeviceID(for port: ControlPort) -> UUID? {
        switch port {
        case .one:
            return port1DeviceID
        case .two:
            return port2DeviceID
        }
    }

    func assignedDevice(for port: ControlPort) -> ControlDeviceConfiguration? {
        guard let id = assignedDeviceID(for: port) else {
            return nil
        }

        return device(id: id)
    }

    func device(id: UUID) -> ControlDeviceConfiguration? {
        devices.first { $0.id == id }
    }

    mutating func setAssignedDeviceID(_ deviceID: UUID?, for port: ControlPort) {
        let validDeviceID = deviceID.flatMap { id in device(id: id)?.id }

        switch port {
        case .one:
            port1DeviceID = validDeviceID
        case .two:
            port2DeviceID = validDeviceID
        }
    }

    mutating func updateDevice(_ device: ControlDeviceConfiguration) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else {
            return
        }

        devices[index] = device.normalized()
    }

    mutating func removeDevice(id: UUID) {
        devices.removeAll { $0.id == id }

        if port1DeviceID == id {
            port1DeviceID = nil
        }
        if port2DeviceID == id {
            port2DeviceID = nil
        }
    }

    func sanitized() -> ControlPortConfiguration {
        var configuration = self
        configuration.devices = configuration.devices.map { $0.normalized() }

        if let port1DeviceID,
           configuration.device(id: port1DeviceID) == nil {
            configuration.port1DeviceID = nil
        }
        if let port2DeviceID,
           configuration.device(id: port2DeviceID) == nil {
            configuration.port2DeviceID = nil
        }

        return configuration
    }
}

struct ControlDeviceConfiguration: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var kind: ControlDeviceKind
    var keyboard: KeyboardJoystickMapping
    var joystick: GameControllerJoystickMapping

    var systemImage: String {
        kind.systemImage
    }

    static func keyboard(name: String,
                         mapping: KeyboardJoystickMapping = .wasdAndSpace) -> ControlDeviceConfiguration {
        ControlDeviceConfiguration(id: UUID(),
                                   name: name,
                                   kind: .keyboard,
                                   keyboard: mapping,
                                   joystick: .standard)
    }

    static func joystick(name: String,
                         mapping: GameControllerJoystickMapping = .standard) -> ControlDeviceConfiguration {
        ControlDeviceConfiguration(id: UUID(),
                                   name: name,
                                   kind: .joystick,
                                   keyboard: .wasdAndSpace,
                                   joystick: mapping)
    }

    func normalized() -> ControlDeviceConfiguration {
        var device = self
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        device.name = trimmedName.isEmpty ? kind.defaultName : trimmedName
        device.joystick = joystick.normalized()
        return device
    }
}

enum ControlDeviceKind: String, CaseIterable, Codable, Identifiable {
    case keyboard
    case joystick

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keyboard:
            return "Keyboard"
        case .joystick:
            return "Joystick"
        }
    }

    var defaultName: String {
        switch self {
        case .keyboard:
            return "Keyboard"
        case .joystick:
            return "Joystick"
        }
    }

    var systemImage: String {
        switch self {
        case .keyboard:
            return "keyboard"
        case .joystick:
            return "gamecontroller"
        }
    }

    var viceJoyPortDevice: Int32 {
        switch self {
        case .keyboard, .joystick:
            return ViceJoyPortDevice.joystick
        }
    }
}

enum ControlDeviceConnectionState: Equatable {
    case connected
    case unavailable(String)

    var isConnected: Bool {
        switch self {
        case .connected:
            return true
        case .unavailable:
            return false
        }
    }

    var title: String {
        switch self {
        case .connected:
            return "Connected"
        case .unavailable(let reason):
            return reason
        }
    }

    var systemImage: String {
        switch self {
        case .connected:
            return "checkmark.circle"
        case .unavailable:
            return "exclamationmark.triangle"
        }
    }
}

struct KeyboardJoystickMapping: Codable, Equatable {
    var up: UInt16
    var down: UInt16
    var left: UInt16
    var right: UInt16
    var fire: UInt16

    static let arrowsAndSpace = KeyboardJoystickMapping(up: MacJoystickKeyCode.upArrow,
                                                        down: MacJoystickKeyCode.downArrow,
                                                        left: MacJoystickKeyCode.leftArrow,
                                                        right: MacJoystickKeyCode.rightArrow,
                                                        fire: MacJoystickKeyCode.space)
    static let wasdAndSpace = KeyboardJoystickMapping(up: MacJoystickKeyCode.w,
                                                      down: MacJoystickKeyCode.s,
                                                      left: MacJoystickKeyCode.a,
                                                      right: MacJoystickKeyCode.d,
                                                      fire: MacJoystickKeyCode.space)

    func keyCode(for action: JoystickAction) -> UInt16 {
        switch action {
        case .up:
            return up
        case .down:
            return down
        case .left:
            return left
        case .right:
            return right
        case .fire:
            return fire
        }
    }

    mutating func setKeyCode(_ keyCode: UInt16, for action: JoystickAction) {
        switch action {
        case .up:
            up = keyCode
        case .down:
            down = keyCode
        case .left:
            left = keyCode
        case .right:
            right = keyCode
        case .fire:
            fire = keyCode
        }
    }

    func joystickBit(for keyCode: UInt16) -> UInt16? {
        for action in JoystickAction.allCases where self.keyCode(for: action) == keyCode {
            return action.bit
        }

        return nil
    }
}

struct GameControllerJoystickMapping: Codable, Equatable {
    var preferredControllerName: String?
    var deadZone: Double
    var up: GameControllerControl
    var down: GameControllerControl
    var left: GameControllerControl
    var right: GameControllerControl
    var fire: GameControllerControl

    static let standard = GameControllerJoystickMapping(preferredControllerName: nil,
                                                        deadZone: 0.28,
                                                        up: .dpadUp,
                                                        down: .dpadDown,
                                                        left: .dpadLeft,
                                                        right: .dpadRight,
                                                        fire: .buttonSouth)

    func control(for action: JoystickAction) -> GameControllerControl {
        switch action {
        case .up:
            return up
        case .down:
            return down
        case .left:
            return left
        case .right:
            return right
        case .fire:
            return fire
        }
    }

    mutating func setControl(_ control: GameControllerControl, for action: JoystickAction) {
        switch action {
        case .up:
            up = control
        case .down:
            down = control
        case .left:
            left = control
        case .right:
            right = control
        case .fire:
            fire = control
        }
    }

    func normalized() -> GameControllerJoystickMapping {
        var mapping = self
        mapping.deadZone = min(max(deadZone, 0.05), 0.95)

        if preferredControllerName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            mapping.preferredControllerName = nil
        }

        return mapping
    }
}

enum GameControllerControl: String, CaseIterable, Codable, Identifiable {
    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight
    case leftStickUp
    case leftStickDown
    case leftStickLeft
    case leftStickRight
    case buttonSouth
    case buttonEast
    case buttonWest
    case buttonNorth
    case leftShoulder
    case rightShoulder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dpadUp:
            return "D-Pad Up"
        case .dpadDown:
            return "D-Pad Down"
        case .dpadLeft:
            return "D-Pad Left"
        case .dpadRight:
            return "D-Pad Right"
        case .leftStickUp:
            return "Left Stick Up"
        case .leftStickDown:
            return "Left Stick Down"
        case .leftStickLeft:
            return "Left Stick Left"
        case .leftStickRight:
            return "Left Stick Right"
        case .buttonSouth:
            return "South Button"
        case .buttonEast:
            return "East Button"
        case .buttonWest:
            return "West Button"
        case .buttonNorth:
            return "North Button"
        case .leftShoulder:
            return "Left Shoulder"
        case .rightShoulder:
            return "Right Shoulder"
        }
    }

    func isActive(on gamepad: GCExtendedGamepad, deadZone: Float) -> Bool {
        switch self {
        case .dpadUp:
            return gamepad.dpad.yAxis.value >= deadZone
        case .dpadDown:
            return gamepad.dpad.yAxis.value <= -deadZone
        case .dpadLeft:
            return gamepad.dpad.xAxis.value <= -deadZone
        case .dpadRight:
            return gamepad.dpad.xAxis.value >= deadZone
        case .leftStickUp:
            return gamepad.leftThumbstick.yAxis.value >= deadZone
        case .leftStickDown:
            return gamepad.leftThumbstick.yAxis.value <= -deadZone
        case .leftStickLeft:
            return gamepad.leftThumbstick.xAxis.value <= -deadZone
        case .leftStickRight:
            return gamepad.leftThumbstick.xAxis.value >= deadZone
        case .buttonSouth:
            return gamepad.buttonA.isPressed
        case .buttonEast:
            return gamepad.buttonB.isPressed
        case .buttonWest:
            return gamepad.buttonX.isPressed
        case .buttonNorth:
            return gamepad.buttonY.isPressed
        case .leftShoulder:
            return gamepad.leftShoulder.isPressed
        case .rightShoulder:
            return gamepad.rightShoulder.isPressed
        }
    }

    func isActive(on gamepad: GCMicroGamepad, deadZone: Float) -> Bool {
        switch self {
        case .dpadUp:
            return gamepad.dpad.yAxis.value >= deadZone
        case .dpadDown:
            return gamepad.dpad.yAxis.value <= -deadZone
        case .dpadLeft:
            return gamepad.dpad.xAxis.value <= -deadZone
        case .dpadRight:
            return gamepad.dpad.xAxis.value >= deadZone
        case .buttonSouth:
            return gamepad.buttonA.isPressed
        case .buttonWest:
            return gamepad.buttonX.isPressed
        case .leftStickUp, .leftStickDown, .leftStickLeft, .leftStickRight,
             .buttonEast, .buttonNorth, .leftShoulder, .rightShoulder:
            return false
        }
    }

    static func capturedControl(from controller: GCController, deadZone: Float) -> GameControllerControl? {
        if let extendedGamepad = controller.extendedGamepad {
            return capturedControl(from: extendedGamepad, deadZone: deadZone)
        }
        if let microGamepad = controller.microGamepad {
            return capturedControl(from: microGamepad, deadZone: deadZone)
        }

        return nil
    }

    static func capturedControl(from gamepad: GCExtendedGamepad, deadZone: Float) -> GameControllerControl? {
        let controls: [GameControllerControl] = [
            .buttonSouth,
            .buttonEast,
            .buttonWest,
            .buttonNorth,
            .leftShoulder,
            .rightShoulder,
            .dpadUp,
            .dpadDown,
            .dpadLeft,
            .dpadRight,
            .leftStickUp,
            .leftStickDown,
            .leftStickLeft,
            .leftStickRight
        ]

        return controls.first { $0.isActive(on: gamepad, deadZone: deadZone) }
    }

    static func capturedControl(from gamepad: GCMicroGamepad, deadZone: Float) -> GameControllerControl? {
        let controls: [GameControllerControl] = [
            .buttonSouth,
            .buttonWest,
            .dpadUp,
            .dpadDown,
            .dpadLeft,
            .dpadRight
        ]

        return controls.first { $0.isActive(on: gamepad, deadZone: deadZone) }
    }
}

enum JoystickAction: String, CaseIterable, Identifiable, Hashable {
    case up
    case down
    case left
    case right
    case fire

    var id: String { rawValue }

    var title: String {
        switch self {
        case .up:
            return "Up"
        case .down:
            return "Down"
        case .left:
            return "Left"
        case .right:
            return "Right"
        case .fire:
            return "Fire"
        }
    }

    var bit: UInt16 {
        switch self {
        case .up:
            return JoystickBits.up
        case .down:
            return JoystickBits.down
        case .left:
            return JoystickBits.left
        case .right:
            return JoystickBits.right
        case .fire:
            return JoystickBits.fire
        }
    }
}

enum ControlPort: Int, CaseIterable, Identifiable {
    case one = 1
    case two = 2

    var id: Int { rawValue }
    var title: String { "Port \(rawValue)" }
    var resourceName: String { "JoyPort\(rawValue)Device" }
    var joystickIndex: UInt32 { UInt32(rawValue - 1) }
}

enum KeyboardKeyName {
    static func title(for keyCode: UInt16) -> String {
        switch keyCode {
        case MacJoystickKeyCode.a:
            return "A"
        case MacJoystickKeyCode.s:
            return "S"
        case MacJoystickKeyCode.d:
            return "D"
        case MacJoystickKeyCode.w:
            return "W"
        case MacJoystickKeyCode.space:
            return "Space"
        case MacJoystickKeyCode.leftArrow:
            return "Left Arrow"
        case MacJoystickKeyCode.rightArrow:
            return "Right Arrow"
        case MacJoystickKeyCode.downArrow:
            return "Down Arrow"
        case MacJoystickKeyCode.upArrow:
            return "Up Arrow"
        default:
            return "Key \(keyCode)"
        }
    }
}

private enum JoystickBits {
    static let up: UInt16 = 1 << 0
    static let down: UInt16 = 1 << 1
    static let left: UInt16 = 1 << 2
    static let right: UInt16 = 1 << 3
    static let fire: UInt16 = 1 << 4
    static let all: UInt16 = up | down | left | right | fire
}

private enum MacJoystickKeyCode {
    static let a: UInt16 = 0
    static let s: UInt16 = 1
    static let d: UInt16 = 2
    static let w: UInt16 = 13
    static let space: UInt16 = 49
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
}

struct ROMImageConfiguration: Codable, Equatable {
    private var paths: [String: String]

    static let standard = ROMImageConfiguration(paths: [:])

    init(paths: [String: String] = [:]) {
        self.paths = paths
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let paths = try container.decodeIfPresent([String: String].self, forKey: .paths) {
            self.paths = paths
            return
        }

        var legacyPaths: [String: String] = [:]
        if let basicPath = try container.decodeIfPresent(String.self, forKey: .basicPath) {
            legacyPaths[MachineROMSlot.c64Basic.id] = basicPath
        }
        if let kernalPath = try container.decodeIfPresent(String.self, forKey: .kernalPath) {
            legacyPaths[MachineROMSlot.c64Kernal.id] = kernalPath
        }
        if let characterPath = try container.decodeIfPresent(String.self, forKey: .characterPath) {
            legacyPaths[MachineROMSlot.c64Character.id] = characterPath
        }
        paths = legacyPaths
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(paths, forKey: .paths)
    }

    func path(for slot: MachineROMSlot) -> String? {
        paths[slot.id]
    }

    func resourceValue(for slot: MachineROMSlot) -> String {
        path(for: slot) ?? slot.defaultFileName
    }

    mutating func setPath(_ path: String?, for slot: MachineROMSlot) {
        let normalizedPath = path?.isEmpty == false ? path : nil
        paths[slot.id] = normalizedPath
    }

    private enum CodingKeys: String, CodingKey {
        case paths
        case basicPath
        case kernalPath
        case characterPath
    }
}

enum DriveType: Int32, CaseIterable, Codable, Identifiable {
    case c1540 = 1540
    case c1541 = 1541
    case c1541II = 1542
    case c1570 = 1570
    case c1571 = 1571
    case c1581 = 1581
    case fd2000 = 2000
    case fd4000 = 4000
    case c2031 = 2031
    case c2040 = 2040
    case c3040 = 3040
    case c4040 = 4040
    case sfd1001 = 1001
    case c8050 = 8050
    case c8250 = 8250
    case d9090d9060 = 9000
    case cmdHD = 4844

    var id: Int32 { rawValue }

    static let iecOptions: [DriveType] = [
        .c1540,
        .c1541,
        .c1541II,
        .c1570,
        .c1571,
        .c1581,
        .fd2000,
        .fd4000,
        .cmdHD
    ]

    static let petOptions: [DriveType] = [
        .c2031,
        .c2040,
        .c3040,
        .c4040,
        .sfd1001,
        .c8050,
        .c8250,
        .d9090d9060
    ]

    var title: String {
        switch self {
        case .c1540:
            return "1540"
        case .c1541:
            return "1541"
        case .c1541II:
            return "1541-II"
        case .c1570:
            return "1570"
        case .c1571:
            return "1571"
        case .c1581:
            return "1581"
        case .fd2000:
            return "FD-2000"
        case .fd4000:
            return "FD-4000"
        case .c2031:
            return "2031"
        case .c2040:
            return "2040"
        case .c3040:
            return "3040"
        case .c4040:
            return "4040"
        case .sfd1001:
            return "SFD-1001"
        case .c8050:
            return "8050"
        case .c8250:
            return "8250"
        case .d9090d9060:
            return "D9090/D9060"
        case .cmdHD:
            return "CMD HD"
        }
    }

    var busTitle: String {
        switch self {
        case .c2031, .c2040, .c3040, .c4040, .sfd1001, .c8050, .c8250, .d9090d9060:
            return "IEEE-488"
        default:
            return "IEC serial"
        }
    }

    var slotCount: Int {
        switch self {
        case .c2040, .c3040, .c4040, .c8050, .c8250:
            return 2
        default:
            return 1
        }
    }

    var driveNumbers: [Int] {
        Array(0..<slotCount)
    }

    var defaultLEDColor: DriveLEDColor {
        ledColor(forDriveNumber: 0)
    }

    func ledColor(forDriveNumber driveNumber: Int) -> DriveLEDColor {
        switch self {
        case .c1540, .c1541, .c1570, .c2031, .c2040, .c3040, .c4040, .sfd1001, .d9090d9060:
            return .red
        case .c8050:
            return .green
        case .c8250:
            return driveNumber == 0 ? .red : .green
        case .c1541II, .c1571, .c1581, .fd2000, .fd4000, .cmdHD:
            return .green
        }
    }

    var supportedDiskImageTypes: [DiskImageFileType] {
        switch self {
        case .c1540, .c1541, .c1541II, .c1570:
            return [.d64, .d67, .g64, .p64, .x64]
        case .c1571:
            return [.d64, .d67, .d71, .g64, .g71, .p64, .x64]
        case .c1581:
            return [.d81]
        case .fd2000, .fd4000:
            return [.d81, .d1m, .d2m, .d4m]
        case .c2031, .c2040, .c3040, .c4040:
            return [.d64, .d67]
        case .sfd1001, .c8050, .c8250:
            return [.d80, .d82]
        case .d9090d9060:
            return [.d90]
        case .cmdHD:
            return [.dhd]
        }
    }

    var supportedDiskImageDescription: String {
        supportedDiskImageTypes.map(\.title).joined(separator: ", ")
    }

    func supportsDiskImage(url: URL) -> Bool {
        guard let fileType = DiskImageFileType(url: url) else {
            return false
        }

        return supportedDiskImageTypes.contains(fileType)
    }
}

enum DiskImageFileType: String, CaseIterable, Identifiable {
    case d64
    case d67
    case d71
    case d80
    case d81
    case d82
    case d90
    case d1m
    case d2m
    case d4m
    case dhd
    case g64
    case g71
    case p64
    case x64

    var id: String { rawValue }
    var title: String { rawValue.uppercased() }

    init?(url: URL) {
        self.init(rawValue: url.pathExtension.lowercased())
    }
}

enum DriveLEDColor: Equatable {
    case red
    case green

    init(viceColor: UInt32) {
        self = (viceColor & 1) == 1 ? .green : .red
    }
}

struct DriveActivity: Identifiable, Equatable {
    let unit: Int
    var isConfigured: Bool
    var driveType: DriveType
    var accessMode: DriveAccessMode
    var activeDriveNumber: Int
    var slots: [DriveSlotActivity]
    var ledColor: DriveLEDColor
    var ledIntensity: UInt32
    var errorIntensity: UInt32
    var track: UInt32?
    var halfTrack: UInt32?
    var diskSide: UInt32
    var driveStatusCode: Int32
    var driveStatusText: String?
    var imagePath: String?

    var id: Int { unit }
    var isActive: Bool { ledIntensity > 0 }
    var isFastAccessEnabled: Bool { accessMode == .fast }
    var hasErrorStatus: Bool {
        driveStatusCode != DriveStatusCode.ok
            && driveStatusCode != DriveStatusCode.dosVersion
    }
    var hasMultipleSlots: Bool { driveType.slotCount > 1 }

    var headPositionText: String? {
        guard let track else {
            return nil
        }

        return "T\(Self.paddedHeadValue(track))"
    }

    private static func paddedHeadValue(_ value: UInt32) -> String {
        String(format: "%02u", value)
    }
}

struct DriveSlotActivity: Identifiable, Equatable {
    let driveNumber: Int
    var ledColor: DriveLEDColor
    var ledIntensity: UInt32
    var imagePath: String?

    var id: Int { driveNumber }
    var isActive: Bool { ledIntensity > 0 }
    var hasDiskImage: Bool { imagePath?.isEmpty == false }
}

struct CartridgeStatus: Equatable {
    var isAttached: Bool
    var cartridgeID: Int32
    var cartridgeFlags: UInt32
    var romSize: UInt32
    var chipCount: UInt32
    var bankCount: UInt32
    var cartridgeName: String?
    var imagePath: String?

    static let detached = CartridgeStatus(isAttached: false,
                                          cartridgeID: -1,
                                          cartridgeFlags: 0,
                                          romSize: 0,
                                          chipCount: 0,
                                          bankCount: 0,
                                          cartridgeName: nil,
                                          imagePath: nil)
}

private enum DriveStatusCode {
    static let ok: Int32 = 0
    static let dosVersion: Int32 = 73
}

enum MachineResetKind {
    case soft
    case hard

    var title: String {
        switch self {
        case .soft:
            return "Soft Reset"
        case .hard:
            return "Hard Reset"
        }
    }

    var statusText: String {
        switch self {
        case .soft:
            return "Soft reset queued"
        case .hard:
            return "Hard reset queued"
        }
    }
}

enum RAMExpansion: String, CaseIterable, Identifiable {
    case none
    case vic20_3k
    case vic20_8kBlock1
    case vic20_8kBlock2
    case vic20_8kBlock3
    case vic20_8kBlock5
    case vic20_11k
    case vic20_16k
    case vic20_19k
    case vic20_24k
    case vic20_27k
    case vic20_32k
    case vic20_35k
    case reu128
    case reu256
    case reu512
    case reu1024
    case reu2048
    case reu4096
    case reu8192
    case reu16384
    case georam512
    case georam1024
    case georam2048
    case georam4096
    case ramcart64
    case ramcart128
    case dqbb16
    case dqbb32
    case dqbb64
    case dqbb128
    case dqbb256
    case isepic
    case c64_256kDE00
    case c64_256kDE80
    case c64_256kDF00
    case c64_256kDF80
    case plus60kD040
    case plus60kD100
    case plus256k

    var id: String { rawValue }

    static let c64Options: [RAMExpansion] = [
        .none,
        .reu128,
        .reu256,
        .reu512,
        .reu1024,
        .reu2048,
        .reu4096,
        .reu8192,
        .reu16384,
        .georam512,
        .georam1024,
        .georam2048,
        .georam4096,
        .ramcart64,
        .ramcart128,
        .dqbb16,
        .dqbb32,
        .dqbb64,
        .dqbb128,
        .dqbb256,
        .isepic,
        .c64_256kDE00,
        .c64_256kDE80,
        .c64_256kDF00,
        .c64_256kDF80,
        .plus60kD040,
        .plus60kD100,
        .plus256k
    ]

    static let vic20Options: [RAMExpansion] = [
        .none,
        .vic20_3k,
        .vic20_8kBlock1,
        .vic20_8kBlock2,
        .vic20_8kBlock3,
        .vic20_8kBlock5,
        .vic20_11k,
        .vic20_16k,
        .vic20_19k,
        .vic20_24k,
        .vic20_27k,
        .vic20_32k,
        .vic20_35k
    ]

    var title: String {
        switch self {
        case .none:
            return "None"
        case .vic20_3k:
            return "VIC-20 3K"
        case .vic20_8kBlock1:
            return "VIC-20 8K BLK1"
        case .vic20_8kBlock2:
            return "VIC-20 8K BLK2"
        case .vic20_8kBlock3:
            return "VIC-20 8K BLK3"
        case .vic20_8kBlock5:
            return "VIC-20 8K BLK5"
        case .vic20_11k:
            return "VIC-20 11K"
        case .vic20_16k:
            return "VIC-20 16K"
        case .vic20_19k:
            return "VIC-20 19K"
        case .vic20_24k:
            return "VIC-20 24K"
        case .vic20_27k:
            return "VIC-20 27K"
        case .vic20_32k:
            return "VIC-20 32K"
        case .vic20_35k:
            return "VIC-20 35K"
        case .reu128, .reu256, .reu512, .reu1024, .reu2048, .reu4096, .reu8192, .reu16384:
            return "REU \(sizeTitle)"
        case .georam512, .georam1024, .georam2048, .georam4096:
            return "GeoRAM \(sizeTitle)"
        case .ramcart64, .ramcart128:
            return "RamCart \(sizeTitle)"
        case .dqbb16, .dqbb32, .dqbb64, .dqbb128, .dqbb256:
            return "DQBB \(sizeTitle)"
        case .isepic:
            return "ISEPIC 2K"
        case .c64_256kDE00:
            return "C64 256K @ $DE00"
        case .c64_256kDE80:
            return "C64 256K @ $DE80"
        case .c64_256kDF00:
            return "C64 256K @ $DF00"
        case .c64_256kDF80:
            return "C64 256K @ $DF80"
        case .plus60kD040:
            return "+60K @ $D040"
        case .plus60kD100:
            return "+60K @ $D100"
        case .plus256k:
            return "+256K"
        }
    }

    var statusTitle: String {
        self == .none ? "disabled" : title
    }

    func displayTitle(for machineID: MachineID) -> String {
        guard machineID == .xvic else {
            return title
        }

        switch self {
        case .none:
            return "VIC-20 5K (unexpanded)"
        case .vic20_3k:
            return "VIC-20 3K (BLK0)"
        case .vic20_8kBlock1:
            return "VIC-20 8K (BLK1)"
        case .vic20_8kBlock2:
            return "VIC-20 8K (BLK2)"
        case .vic20_8kBlock3:
            return "VIC-20 8K (BLK3)"
        case .vic20_8kBlock5:
            return "VIC-20 8K (BLK5)"
        case .vic20_11k:
            return "VIC-20 11K (BLK0 + BLK1)"
        case .vic20_16k:
            return "VIC-20 16K (BLK1 + BLK2)"
        case .vic20_19k:
            return "VIC-20 19K (BLK0 + BLK1 + BLK2)"
        case .vic20_24k:
            return "VIC-20 24K (BASIC max)"
        case .vic20_27k:
            return "VIC-20 27K (24K BASIC + BLK0)"
        case .vic20_32k:
            return "VIC-20 32K (24K BASIC + BLK5)"
        case .vic20_35k:
            return "VIC-20 35K (24K BASIC + BLK0 + BLK5)"
        default:
            return title
        }
    }

    var chipTitle: String {
        switch self {
        case .none:
            return ""
        case .vic20_3k:
            return "3K"
        case .vic20_8kBlock1:
            return "8K B1"
        case .vic20_8kBlock2:
            return "8K B2"
        case .vic20_8kBlock3:
            return "8K B3"
        case .vic20_8kBlock5:
            return "8K B5"
        case .vic20_11k:
            return "11K"
        case .vic20_16k:
            return "16K"
        case .vic20_19k:
            return "19K"
        case .vic20_24k:
            return "24K"
        case .vic20_27k:
            return "27K"
        case .vic20_32k:
            return "32K"
        case .vic20_35k:
            return "35K"
        case .c64_256kDE00, .c64_256kDE80, .c64_256kDF00, .c64_256kDF80:
            return "C64 256K"
        case .plus60kD040, .plus60kD100:
            return "+60K"
        default:
            return title
        }
    }

    fileprivate var device: RAMExpansionDevice {
        switch self {
        case .none:
            return .none
        case .vic20_3k, .vic20_8kBlock1, .vic20_8kBlock2, .vic20_8kBlock3, .vic20_8kBlock5,
             .vic20_11k, .vic20_16k, .vic20_19k, .vic20_24k, .vic20_27k, .vic20_32k,
             .vic20_35k:
            return .vic20Blocks
        case .reu128, .reu256, .reu512, .reu1024, .reu2048, .reu4096, .reu8192, .reu16384:
            return .reu
        case .georam512, .georam1024, .georam2048, .georam4096:
            return .georam
        case .ramcart64, .ramcart128:
            return .ramcart
        case .dqbb16, .dqbb32, .dqbb64, .dqbb128, .dqbb256:
            return .dqbb
        case .isepic:
            return .isepic
        case .c64_256kDE00, .c64_256kDE80, .c64_256kDF00, .c64_256kDF80,
             .plus60kD040, .plus60kD100, .plus256k:
            return .memoryHack
        }
    }

    fileprivate var sizeKiB: Int32? {
        switch self {
        case .reu128, .dqbb128, .ramcart128:
            return 128
        case .reu256, .dqbb256:
            return 256
        case .reu512, .georam512:
            return 512
        case .reu1024, .georam1024:
            return 1024
        case .reu2048, .georam2048:
            return 2048
        case .reu4096, .georam4096:
            return 4096
        case .reu8192:
            return 8192
        case .reu16384:
            return 16384
        case .ramcart64, .dqbb64:
            return 64
        case .dqbb16:
            return 16
        case .dqbb32:
            return 32
        case .none, .isepic, .c64_256kDE00, .c64_256kDE80, .c64_256kDF00, .c64_256kDF80,
             .plus60kD040, .plus60kD100, .plus256k, .vic20_3k, .vic20_8kBlock1,
             .vic20_8kBlock2, .vic20_8kBlock3, .vic20_8kBlock5, .vic20_11k, .vic20_16k,
             .vic20_19k, .vic20_24k, .vic20_27k, .vic20_32k, .vic20_35k:
            return nil
        }
    }

    fileprivate var memoryHack: Int32 {
        switch self {
        case .c64_256kDE00, .c64_256kDE80, .c64_256kDF00, .c64_256kDF80:
            return 1
        case .plus60kD040, .plus60kD100:
            return 2
        case .plus256k:
            return 3
        case .none, .reu128, .reu256, .reu512, .reu1024, .reu2048, .reu4096, .reu8192, .reu16384,
             .georam512, .georam1024, .georam2048, .georam4096, .ramcart64, .ramcart128,
             .dqbb16, .dqbb32, .dqbb64, .dqbb128, .dqbb256, .isepic, .vic20_3k,
             .vic20_8kBlock1, .vic20_8kBlock2, .vic20_8kBlock3, .vic20_8kBlock5,
             .vic20_11k, .vic20_16k, .vic20_19k, .vic20_24k, .vic20_27k, .vic20_32k,
             .vic20_35k:
            return 0
        }
    }

    fileprivate var baseAddress: Int32? {
        switch self {
        case .c64_256kDE00:
            return 0xde00
        case .c64_256kDE80:
            return 0xde80
        case .c64_256kDF00:
            return 0xdf00
        case .c64_256kDF80:
            return 0xdf80
        case .plus60kD040:
            return 0xd040
        case .plus60kD100:
            return 0xd100
        case .none, .reu128, .reu256, .reu512, .reu1024, .reu2048, .reu4096, .reu8192, .reu16384,
             .georam512, .georam1024, .georam2048, .georam4096, .ramcart64, .ramcart128,
             .dqbb16, .dqbb32, .dqbb64, .dqbb128, .dqbb256, .isepic, .plus256k, .vic20_3k,
             .vic20_8kBlock1, .vic20_8kBlock2, .vic20_8kBlock3, .vic20_8kBlock5,
             .vic20_11k, .vic20_16k, .vic20_19k, .vic20_24k, .vic20_27k, .vic20_32k,
             .vic20_35k:
            return nil
        }
    }

    var detailTitle: String {
        switch self {
        case .none:
            return "Unexpanded"
        case .vic20_3k, .vic20_8kBlock1, .vic20_8kBlock2, .vic20_8kBlock3, .vic20_8kBlock5,
             .vic20_11k, .vic20_16k, .vic20_19k, .vic20_24k, .vic20_27k, .vic20_32k,
             .vic20_35k:
            return vic20BlockTitle
        default:
            return title
        }
    }

    func detailTitle(for machineID: MachineID) -> String {
        guard machineID == .xvic else {
            return detailTitle
        }

        switch self {
        case .vic20_24k:
            return "\(vic20BlockTitle); BASIC shows 28159 bytes free"
        case .vic20_27k, .vic20_32k, .vic20_35k:
            return "\(vic20BlockTitle); BASIC still shows 28159 bytes free"
        default:
            return detailTitle
        }
    }

    var vic20MemorySpec: String? {
        switch self {
        case .none:
            return "none"
        case .vic20_3k:
            return "3k"
        case .vic20_8kBlock1:
            return "8k"
        case .vic20_8kBlock2:
            return "2"
        case .vic20_8kBlock3:
            return "3"
        case .vic20_8kBlock5:
            return "5"
        case .vic20_11k:
            return "3k,8k"
        case .vic20_16k:
            return "16k"
        case .vic20_19k:
            return "3k,16k"
        case .vic20_24k:
            return "24k"
        case .vic20_27k:
            return "3k,24k"
        case .vic20_32k:
            return "1,2,3,5"
        case .vic20_35k:
            return "all"
        default:
            return nil
        }
    }

    fileprivate var vic20RAMBlocks: Set<Int> {
        switch self {
        case .vic20_3k:
            return [0]
        case .vic20_8kBlock1:
            return [1]
        case .vic20_8kBlock2:
            return [2]
        case .vic20_8kBlock3:
            return [3]
        case .vic20_8kBlock5:
            return [5]
        case .vic20_11k:
            return [0, 1]
        case .vic20_16k:
            return [1, 2]
        case .vic20_19k:
            return [0, 1, 2]
        case .vic20_24k:
            return [1, 2, 3]
        case .vic20_27k:
            return [0, 1, 2, 3]
        case .vic20_32k:
            return [1, 2, 3, 5]
        case .vic20_35k:
            return [0, 1, 2, 3, 5]
        default:
            return []
        }
    }

    private var sizeTitle: String {
        guard let sizeKiB else {
            return ""
        }

        if sizeKiB >= 1024 {
            return "\(sizeKiB / 1024)M"
        }

        return "\(sizeKiB)K"
    }

    private var vic20BlockTitle: String {
        let blocks = vic20RAMBlocks.sorted()

        guard !blocks.isEmpty else {
            return "Unexpanded"
        }

        let names = blocks.map { block in
            block == 0 ? "BLK0" : "BLK\(block)"
        }
        return names.joined(separator: " + ")
    }
}

fileprivate enum RAMExpansionDevice {
    case none
    case vic20Blocks
    case reu
    case georam
    case ramcart
    case dqbb
    case isepic
    case memoryHack
}

@MainActor
final class EmulatorSession: ObservableObject {
    let machine = EmulatedMachine.current

    @Published var isPaused = false {
        didSet {
            guard isPaused != oldValue else {
                return
            }

            applyPauseState()
        }
    }
    @Published var emulationSpeed: EmulationSpeed {
        didSet {
            guard emulationSpeed != oldValue else {
                return
            }

            EmulatorDefaults.saveEmulationSpeed(emulationSpeed, for: machine)
            applyEmulationSpeed()
        }
    }
    @Published var displayMode: DisplayMode {
        didSet {
            guard displayMode != oldValue else {
                return
            }

            EmulatorDefaults.saveDisplayMode(displayMode, for: machine)
            statusText = "Display \(displayMode.title)"
        }
    }
    @Published var videoStandard: VideoStandard {
        didSet {
            guard videoStandard != oldValue else {
                return
            }

            EmulatorDefaults.saveVideoStandard(videoStandard, for: machine)
            applyVideoStandard()
        }
    }
    @Published var sidModel: SIDModel {
        didSet {
            guard sidModel != oldValue else {
                return
            }

            EmulatorDefaults.saveSIDModel(sidModel, for: machine)
            applySIDModel()
        }
    }
    @Published var soundEnabled: Bool {
        didSet {
            guard soundEnabled != oldValue else {
                return
            }

            EmulatorDefaults.saveSoundEnabled(soundEnabled, for: machine)
            applySoundSettings()
        }
    }
    @Published var soundVolume: Int {
        didSet {
            let clampedVolume = min(max(soundVolume, 0), 100)
            guard soundVolume == clampedVolume else {
                soundVolume = clampedVolume
                return
            }

            guard soundVolume != oldValue else {
                return
            }

            EmulatorDefaults.saveSoundVolume(soundVolume, for: machine)
            applySoundSettings()
        }
    }
    @Published var romImages: ROMImageConfiguration {
        didSet {
            guard romImages != oldValue else {
                return
            }

            EmulatorDefaults.saveROMImages(romImages, for: machine)
            applyROMImages()
        }
    }
    @Published var ramExpansion: RAMExpansion {
        didSet {
            guard ramExpansion != oldValue else {
                return
            }

            EmulatorDefaults.saveRAMExpansion(ramExpansion, for: machine)
            applyRAMExpansion()
        }
    }
    @Published var controlPorts: ControlPortConfiguration {
        didSet {
            let sanitizedConfiguration = controlPorts.sanitized()
            guard controlPorts == sanitizedConfiguration else {
                controlPorts = sanitizedConfiguration
                return
            }

            guard controlPorts != oldValue else {
                return
            }

            EmulatorDefaults.saveControlPorts(controlPorts, for: machine)
            applyControlPorts()
            publishKeyboardJoystickValues(force: true)
            publishGameControllerValues(force: true)
        }
    }
    @Published var driveConfigurations: [DriveConfiguration] {
        didSet {
            let normalizedConfigurations = Self.normalizedDriveConfigurations(driveConfigurations, for: machine)
            guard driveConfigurations == normalizedConfigurations else {
                driveConfigurations = normalizedConfigurations
                return
            }

            EmulatorDefaults.saveDriveConfigurations(driveConfigurations, for: machine)
            applyDriveConfigurationChanges(from: oldValue)
        }
    }
    @Published private var driveActivities: [Int: DriveActivity] = [:]
    @Published var cartridgeStatus = CartridgeStatus.detached
    @Published private(set) var gameControllerNames: [String] = []
    @Published private var controlPortValues: [ControlPort: UInt16] = [:]
    @Published var filterSettings = VideoFilterSettings()
    @Published var statusText: String

    let frameSource: EmulatorFrameSource
    private var didStartEngine = false
    private var pressedKeys: [UInt16: PressedEmulatorKey] = [:]
    private var keyboardJoystickPressedKeys: [UUID: Set<UInt16>] = [:]
    private var lastJoystickValues: [UUID: UInt16] = [:]
    private var gameControllerObservers: [NSObjectProtocol] = []

    nonisolated static func normalizedDriveConfigurations(_ configurations: [DriveConfiguration],
                                                          for machine: EmulatedMachine) -> [DriveConfiguration] {
        let defaults = machine.defaultDriveConfigurations()

        return machine.capabilities.driveUnits.enumerated().map { index, unit in
            guard var configuration = configurations.first(where: { $0.unit == unit }) else {
                return defaults[index]
            }

            if !machine.capabilities.driveTypes.contains(configuration.driveType) {
                configuration.driveType = defaults[index].driveType
            }

            return configuration
        }
    }

    enum DisplayMode: String, CaseIterable, Identifiable {
        case native
        case fit
        case stretch

        var id: String { rawValue }

        var title: String {
            switch self {
            case .native:
                return "Actual Size"
            case .fit:
                return "Fit to Window"
            case .stretch:
                return "Stretch to Window"
            }
        }

        var toolbarTitle: String {
            switch self {
            case .native:
                return "Actual"
            case .fit:
                return "Fit"
            case .stretch:
                return "Stretch"
            }
        }

        var systemImage: String {
            switch self {
            case .native:
                return "rectangle.center.inset.filled"
            case .fit:
                return "arrow.up.left.and.arrow.down.right"
            case .stretch:
                return "arrow.left.and.right"
            }
        }

        var preservesAspectRatio: Bool {
            self != .stretch
        }
    }

    enum VideoStandard: String, CaseIterable, Identifiable {
        case ntsc = "NTSC"
        case pal = "PAL"

        var id: String { rawValue }
    }

    enum SIDModel: Int32, CaseIterable, Identifiable {
        case mos6581 = 0
        case mos8580 = 1

        var id: Int32 { rawValue }

        var title: String {
            switch self {
            case .mos6581:
                return "6581"
            case .mos8580:
                return "8580"
            }
        }
    }

    enum EmulationSpeed: String, CaseIterable, Identifiable {
        case normal
        case double
        case quadruple
        case octuple
        case uncapped

        var id: String { rawValue }

        var title: String {
            switch self {
            case .normal:
                return "100%"
            case .double:
                return "200%"
            case .quadruple:
                return "400%"
            case .octuple:
                return "800%"
            case .uncapped:
                return "Uncapped"
            }
        }

        var toolbarTitle: String {
            switch self {
            case .uncapped:
                return "Warp"
            default:
                return title
            }
        }

        var speedPercent: Int32 {
            switch self {
            case .normal, .uncapped:
                return 100
            case .double:
                return 200
            case .quadruple:
                return 400
            case .octuple:
                return 800
            }
        }

        var isWarpEnabled: Bool {
            self == .uncapped
        }
    }

    init() {
        let machine = EmulatedMachine.current

        videoStandard = EmulatorDefaults.loadVideoStandard(for: machine)
        emulationSpeed = EmulatorDefaults.loadEmulationSpeed(for: machine)
        displayMode = EmulatorDefaults.loadDisplayMode(for: machine)
        sidModel = EmulatorDefaults.loadSIDModel(for: machine)
        soundEnabled = EmulatorDefaults.loadSoundEnabled(for: machine)
        soundVolume = EmulatorDefaults.loadSoundVolume(for: machine)
        romImages = EmulatorDefaults.loadROMImages(for: machine)
        ramExpansion = EmulatorDefaults.loadRAMExpansion(for: machine)
        controlPorts = EmulatorDefaults.loadControlPorts(for: machine)
        driveConfigurations = EmulatorDefaults.loadDriveConfigurations(for: machine)
        statusText = "Starting \(machine.shortName)"
        frameSource = EmulatorFrameSource.displaySource(for: machine)
        setupGameControllerMonitoring()
    }

    deinit {
        for observer in gameControllerObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        GCController.stopWirelessControllerDiscovery()
    }

    var isRAMExpansionConfigured: Bool {
        machine.capabilities.supportsRAMExpansion && ramExpansion != .none
    }

    var availableControlPorts: [ControlPort] {
        machine.capabilities.controlPorts
    }

    var hasMultipleControlPorts: Bool {
        availableControlPorts.count > 1
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

    var hasGameControllers: Bool {
        !gameControllerNames.isEmpty
    }

    var sortedGameControllerNames: [String] {
        gameControllerNames.sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
    }

    func driveAccessMode(for unit: Int) -> DriveAccessMode {
        driveConfigurations.first { $0.unit == unit }?.accessMode ?? .native
    }

    func setDriveAccessMode(_ accessMode: DriveAccessMode, for unit: Int) {
        guard let index = driveConfigurations.firstIndex(where: { $0.unit == unit }) else {
            return
        }

        driveConfigurations[index].accessMode = accessMode
    }

    var controlDevices: [ControlDeviceConfiguration] {
        controlPorts.devices
    }

    func controlDevice(id: UUID) -> ControlDeviceConfiguration? {
        controlPorts.device(id: id)
    }

    func controlPortDevice(for port: ControlPort) -> ControlDeviceConfiguration? {
        controlPorts.assignedDevice(for: port)
    }

    func controlPortConnectionState(for port: ControlPort) -> ControlDeviceConnectionState {
        guard let device = controlPortDevice(for: port) else {
            return .connected
        }

        return connectionState(for: device)
    }

    func controlPortDeviceID(for port: ControlPort) -> UUID? {
        controlPorts.assignedDeviceID(for: port)
    }

    func connectionState(for device: ControlDeviceConfiguration) -> ControlDeviceConnectionState {
        switch device.kind {
        case .keyboard:
            return .connected
        case .joystick:
            if let preferredControllerName = device.joystick.preferredControllerName {
                return gameControllerNames.contains(preferredControllerName)
                    ? .connected
                    : .unavailable("Missing \(preferredControllerName)")
            }

            return hasGameControllers ? .connected : .unavailable("No controller connected")
        }
    }

    func setControlPortDeviceID(_ deviceID: UUID?, for port: ControlPort) {
        var updatedConfiguration = controlPorts
        updatedConfiguration.setAssignedDeviceID(deviceID, for: port)
        controlPorts = updatedConfiguration
    }

    func swapControlPorts() {
        guard hasMultipleControlPorts else {
            return
        }

        var updatedConfiguration = controlPorts
        let port1DeviceID = controlPorts.assignedDeviceID(for: .one)
        let port2DeviceID = controlPorts.assignedDeviceID(for: .two)

        updatedConfiguration.setAssignedDeviceID(port2DeviceID, for: .one)
        updatedConfiguration.setAssignedDeviceID(port1DeviceID, for: .two)
        controlPorts = updatedConfiguration
    }

    func controlPortJoystickValue(for port: ControlPort) -> UInt16 {
        controlPortValues[port] ?? 0
    }

    func controlPortActiveActions(for port: ControlPort) -> Set<JoystickAction> {
        let value = controlPortJoystickValue(for: port)
        var actions = Set<JoystickAction>()

        for action in JoystickAction.allCases where (value & action.bit) != 0 {
            actions.insert(action)
        }

        return actions
    }

    func makeControlDevice(kind: ControlDeviceKind) -> ControlDeviceConfiguration {
        switch kind {
        case .keyboard:
            return ControlDeviceConfiguration.keyboard(name: uniqueControlDeviceName(baseName: "Keyboard"))
        case .joystick:
            return ControlDeviceConfiguration.joystick(name: uniqueControlDeviceName(baseName: "Joystick"))
        }
    }

    @discardableResult
    func addControlDevice(kind: ControlDeviceKind) -> UUID {
        let device = makeControlDevice(kind: kind)
        saveControlDevice(device)
        return device.id
    }

    func saveControlDevice(_ device: ControlDeviceConfiguration) {
        var updatedConfiguration = controlPorts

        if updatedConfiguration.device(id: device.id) == nil {
            updatedConfiguration.devices.append(device.normalized())
        } else {
            updatedConfiguration.updateDevice(device)
        }

        controlPorts = updatedConfiguration
    }

    func updateControlDevice(_ device: ControlDeviceConfiguration) {
        var updatedConfiguration = controlPorts
        updatedConfiguration.updateDevice(device)
        controlPorts = updatedConfiguration
    }

    func removeControlDevice(id: UUID) {
        var updatedConfiguration = controlPorts
        updatedConfiguration.removeDevice(id: id)
        controlPorts = updatedConfiguration
    }

    func start() {
        guard !didStartEngine else {
            return
        }

        guard let executablePath = Bundle.main.executableURL?.path,
              let dataDirectory = Bundle.main.resourceURL?.appendingPathComponent("VICEData").path,
              let runtimeDirectory = Bundle.main.privateFrameworksURL?.path else {
            statusText = "Missing runtime paths"
            return
        }
        let dynamicLibraryPath = URL(fileURLWithPath: runtimeDirectory)
            .appendingPathComponent(machine.dynamicLibraryName)
            .path

        didStartEngine = true
        ViceEngineSetVideoFrameCallback(viceFrameCallback,
                                        Unmanaged.passUnretained(frameSource).toOpaque())
        ViceEngineSetDriveStatusCallback(viceDriveStatusCallback,
                                         Unmanaged.passUnretained(self).toOpaque())
        ViceEngineSetCartridgeStatusCallback(viceCartridgeStatusCallback,
                                             Unmanaged.passUnretained(self).toOpaque())

        let startupConfiguration = MachineStartupConfiguration(executablePath: executablePath,
                                                               dataDirectory: dataDirectory,
                                                               videoStandard: videoStandard,
                                                               sidModel: sidModel,
                                                               soundEnabled: soundEnabled,
                                                               soundVolume: soundVolume,
                                                               emulationSpeed: emulationSpeed,
                                                               romImages: romImages,
                                                               ramExpansion: ramExpansion)
        let startupArguments = machine.startupArguments(configuration: startupConfiguration)
        let started = machine.id.rawValue.withCString { machineIDPointer in
            dynamicLibraryPath.withCString { dynamicLibraryPathPointer in
                startupArguments.withCStringArray { argumentCount, argumentPointers in
                    ViceEngineStartMachine(machineIDPointer,
                                           dynamicLibraryPathPointer,
                                           argumentCount,
                                           argumentPointers)
                }
            }
        }

        if started || ViceEngineIsRunning() {
            applyRuntimeConfiguration()
        }

        statusText = started ? "\(machine.shortName) running" : "\(machine.shortName) already running"
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
        isPaused.toggle()
    }

    func applyFilterPreset(_ preset: VideoFilterPreset) {
        filterSettings = VideoFilterSettings.defaults(for: preset)
        statusText = "\(preset.rawValue) filter"
    }

    @discardableResult
    func handleKeyEvent(_ event: NSEvent, pressed: Bool) -> Bool {
        if !pressed, let existingKey = pressedKeys.removeValue(forKey: event.keyCode) {
            ViceEngineSendKeyEvent(existingKey.symbol, existingKey.modifiers, false)
            return true
        }

        if !pressed {
            return handleKeyboardJoystickEvent(event, pressed: false)
        }

        if event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command) {
            return false
        }

        if handleKeyboardJoystickEvent(event, pressed: true) {
            return true
        }

        if event.isARepeat {
            return true
        }

        guard let symbol = ViceMacKeyMapper.symbol(for: event) else {
            return false
        }

        let modifiers = ViceMacKeyMapper.modifiers(for: event)
        if let existingKey = pressedKeys.updateValue(PressedEmulatorKey(symbol: symbol, modifiers: modifiers),
                                                     forKey: event.keyCode) {
            ViceEngineSendKeyEvent(existingKey.symbol, existingKey.modifiers, false)
        }

        ViceEngineSendKeyEvent(symbol, modifiers, true)
        return true
    }

    @discardableResult
    func handleFlagsChanged(_ event: NSEvent) -> Bool {
        guard let modifierKey = ViceMacKeyMapper.modifierKey(for: event) else {
            return false
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command), pressedKeys[event.keyCode] == nil {
            return false
        }

        if modifierKey.isToggle {
            ViceEngineSendKeyEvent(modifierKey.symbol, modifierKey.modifiers, true)
            ViceEngineSendKeyEvent(modifierKey.symbol, modifierKey.modifiers, false)
            return true
        }

        if let existingKey = pressedKeys.removeValue(forKey: event.keyCode) {
            ViceEngineSendKeyEvent(existingKey.symbol, existingKey.modifiers, false)
        } else {
            pressedKeys[event.keyCode] = PressedEmulatorKey(symbol: modifierKey.symbol,
                                                            modifiers: modifierKey.modifiers)
            ViceEngineSendKeyEvent(modifierKey.symbol, modifierKey.modifiers, true)
        }

        return true
    }

    func releaseAllKeys() {
        pressedKeys.removeAll()
        keyboardJoystickPressedKeys.removeAll()
        ViceEngineReleaseAllKeys()

        for device in assignedControlDevices(kind: .keyboard) {
            lastJoystickValues[device.id] = 0
            publishJoystickValue(0, forDeviceID: device.id)
        }
    }

    func handleDriveStatus(_ status: DriveStatusSnapshot) {
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

    func handleCartridgeStatus(_ status: CartridgeStatusSnapshot) {
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

        _ = ViceEngineResetDrive(UInt32(unit))
    }

    func attachDisk(to unit: Int, url: URL, autorun: Bool) {
        attachDisk(to: unit, driveNumber: 0, url: url, autorun: autorun)
    }

    func attachDisk(to unit: Int, driveNumber: Int, url: URL, autorun: Bool) {
        guard unit >= 8 && unit <= 11 else {
            return
        }

        guard let configuration = driveConfigurations.first(where: { $0.unit == unit }),
              configuration.isAttached else {
            statusText = "Drive \(unit) is disabled"
            return
        }

        guard configuration.driveType.driveNumbers.contains(driveNumber) else {
            statusText = "Drive \(unit):\(driveNumber) is not available on \(configuration.driveType.title)"
            return
        }

        guard configuration.driveType.supportsDiskImage(url: url) else {
            let fileType = DiskImageFileType(url: url)?.title
                ?? (url.pathExtension.isEmpty ? "File" : url.pathExtension.uppercased())
            statusText = "\(fileType) is not supported by drive \(unit) (\(configuration.driveType.title))"
            return
        }

        url.path.withCString { path in
            _ = ViceEngineAttachDisk(UInt32(unit), UInt32(driveNumber), path, autorun)
        }
    }

    func setROMImage(_ image: MachineROMSlot, path: String?) {
        guard machine.romSlots.contains(image) else {
            return
        }

        var updatedImages = romImages
        updatedImages.setPath(path, for: image)
        romImages = updatedImages
    }

    func attachCartridge(url: URL) {
        guard machine.capabilities.supportsCartridges else {
            return
        }

        url.path.withCString { path in
            _ = ViceEngineAttachCartridge(path)
        }
    }

    func detachCartridge() {
        guard machine.capabilities.supportsCartridges else {
            return
        }

        _ = ViceEngineDetachCartridge()
    }

    private func applyRuntimeConfiguration() {
        applyVideoStandard(updateStatus: false)
        applySIDModel(updateStatus: false)
        applySoundSettings(updateStatus: false)
        applyEmulationSpeed(updateStatus: false)
        applyPauseState(updateStatus: false)
        applyROMImages()
        applyRAMExpansion(updateStatus: false)
        applyControlPorts()
        applyDriveConfigurations(updateStatus: false)
    }

    private func applyPauseState(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
            return
        }

        _ = ViceEngineSetPauseEnabled(isPaused)

        if updateStatus {
            statusText = isPaused ? "Paused" : "Running"
        }
    }

    private func applyVideoStandard(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              machine.capabilities.supportsVideoStandardSelection else {
            return
        }

        for assignment in machine.videoStandardAssignments(for: videoStandard) {
            setVICEIntResource(assignment.name, value: assignment.value)
        }

        if updateStatus {
            statusText = "Video \(videoStandard.rawValue)"
        }
    }

    private func applySIDModel(updateStatus: Bool = true) {
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

    private func applyEmulationSpeed(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
            return
        }

        setVICEIntResource(ViceResource.speed, value: emulationSpeed.speedPercent)
        _ = ViceEngineSetWarpMode(emulationSpeed.isWarpEnabled)

        if updateStatus {
            statusText = emulationSpeed.isWarpEnabled ? "Warp enabled" : "Speed \(emulationSpeed.title)"
        }
    }

    private func applySoundSettings(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
            return
        }

        setVICEIntResource(ViceResource.sound, value: soundEnabled ? 1 : 0)
        setVICEIntResource(ViceResource.soundVolume, value: Int32(soundVolume))

        if updateStatus {
            statusText = soundEnabled ? "Volume \(soundVolume)" : "Muted"
        }
    }

    private func applyROMImages() {
        guard ViceEngineIsRunning() else {
            return
        }

        for slot in machine.romSlots {
            setVICEStringResource(slot.resourceName,
                                  value: romImages.resourceValue(for: slot))
        }
    }

    private func applyRAMExpansion(updateStatus: Bool = true) {
        guard ViceEngineIsRunning(),
              machine.capabilities.supportsRAMExpansion,
              machine.ramExpansions.contains(ramExpansion) else {
            return
        }

        disableRAMExpansionResources()

        switch ramExpansion.device {
        case .none:
            break
        case .vic20Blocks:
            applyVIC20RAMBlocks(ramExpansion.vic20RAMBlocks)
        case .reu:
            if let sizeKiB = ramExpansion.sizeKiB {
                setVICEIntResource(ViceResource.reuSize, value: sizeKiB)
            }
            setVICEIntResource(ViceResource.reu, value: 1)
        case .georam:
            if let sizeKiB = ramExpansion.sizeKiB {
                setVICEIntResource(ViceResource.georamSize, value: sizeKiB)
            }
            setVICEIntResource(ViceResource.georam, value: 1)
        case .ramcart:
            if let sizeKiB = ramExpansion.sizeKiB {
                setVICEIntResource(ViceResource.ramCartSize, value: sizeKiB)
            }
            setVICEIntResource(ViceResource.ramCart, value: 1)
        case .dqbb:
            if let sizeKiB = ramExpansion.sizeKiB {
                setVICEIntResource(ViceResource.dqbbSize, value: sizeKiB)
            }
            setVICEIntResource(ViceResource.dqbbMode, value: ViceDQBBMode.c64)
            setVICEIntResource(ViceResource.dqbb, value: 1)
        case .isepic:
            setVICEIntResource(ViceResource.isepicSwitch, value: 1)
            setVICEIntResource(ViceResource.isepicCartridgeEnabled, value: 1)
        case .memoryHack:
            if let baseAddress = ramExpansion.baseAddress {
                switch ramExpansion {
                case .c64_256kDE00, .c64_256kDE80, .c64_256kDF00, .c64_256kDF80:
                    setVICEIntResource(ViceResource.c64_256kBase, value: baseAddress)
                case .plus60kD040, .plus60kD100:
                    setVICEIntResource(ViceResource.plus60kBase, value: baseAddress)
                default:
                    break
                }
            }
            setVICEIntResource(ViceResource.memoryHack, value: ramExpansion.memoryHack)
        }

        if updateStatus {
            if machine.id == .xvic {
                _ = ViceEngineTriggerMachineReset(true)
            }
            statusText = "RAM expansion \(ramExpansion.statusTitle)"
        }
    }

    private func disableRAMExpansionResources() {
        if machine.id == .xvic {
            disableVIC20RAMExpansionResources()
            return
        }

        setVICEIntResource(ViceResource.reu, value: 0)
        setVICEIntResource(ViceResource.georam, value: 0)
        setVICEIntResource(ViceResource.ramCart, value: 0)
        setVICEIntResource(ViceResource.dqbb, value: 0)
        setVICEIntResource(ViceResource.isepicCartridgeEnabled, value: 0)
        setVICEIntResource(ViceResource.isepicSwitch, value: 0)
        setVICEIntResource(ViceResource.memoryHack, value: 0)
    }

    private func disableVIC20RAMExpansionResources() {
        applyVIC20RAMBlocks([])
    }

    private func applyVIC20RAMBlocks(_ blocks: Set<Int>) {
        for resource in ViceResource.vic20RAMBlocks {
            setVICEIntResource(resource.name,
                               value: blocks.contains(resource.block) ? 1 : 0)
        }
    }

    private func applyControlPorts() {
        guard ViceEngineIsRunning() else {
            return
        }

        for port in availableControlPorts {
            guard let controlDevice = controlPorts.assignedDevice(for: port) else {
                setVICEIntResource(port.resourceName, value: ViceJoyPortDevice.none)
                publishJoystickValue(0, to: port)
                continue
            }

            setVICEIntResource(port.resourceName, value: controlDevice.kind.viceJoyPortDevice)
            publishJoystickValue(currentJoystickValue(for: controlDevice), to: port)
        }
    }

    private func applyDriveConfigurations(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
            return
        }

        let driveSoundEnabled = driveConfigurations.contains { $0.soundEnabled }
        setVICEIntResource("DriveSoundEmulation", value: driveSoundEnabled ? 1 : 0)
        if driveSoundEnabled,
           let volume = driveConfigurations
               .filter(\.soundEnabled)
               .map(\.soundVolume)
               .max() {
            setVICEIntResource("DriveSoundEmulationVolume", value: Int32(volume))
        }

        for configuration in driveConfigurations {
            let driveType = configuration.isAttached ? configuration.driveType.rawValue : 0

            setVICEIntResource("Drive\(configuration.unit)Type", value: driveType)
            applyDriveAccessMode(configuration)
        }

        if updateStatus {
            statusText = "Drive settings updated"
        }
    }

    private func applyDriveConfigurationChanges(from oldConfigurations: [DriveConfiguration]) {
        guard ViceEngineIsRunning() else {
            return
        }

        guard driveConfigurations.map(\.unit) == oldConfigurations.map(\.unit) else {
            applyDriveConfigurations()
            return
        }

        var accessModeUpdates: [DriveConfiguration] = []

        for configuration in driveConfigurations {
            guard let oldConfiguration = oldConfigurations.first(where: { $0.unit == configuration.unit }) else {
                applyDriveConfigurations()
                return
            }

            guard configuration != oldConfiguration else {
                continue
            }

            let onlyAccessModeChanged = configuration.accessMode != oldConfiguration.accessMode
                && configuration.isAttached == oldConfiguration.isAttached
                && configuration.driveType == oldConfiguration.driveType
                && configuration.soundEnabled == oldConfiguration.soundEnabled
                && configuration.soundVolume == oldConfiguration.soundVolume

            guard onlyAccessModeChanged else {
                applyDriveConfigurations()
                return
            }

            accessModeUpdates.append(configuration)
        }

        for configuration in accessModeUpdates {
            applyDriveAccessMode(configuration)
        }
    }

    private func applyDriveAccessMode(_ configuration: DriveConfiguration) {
        let accessMode = configuration.isAttached ? configuration.accessMode : DriveAccessMode.native

        setVICEIntResource("Drive\(configuration.unit)TrueEmulation",
                           value: accessMode.trueDriveEmulationResourceValue)
        setVICEIntResource("TrapDevice\(configuration.unit)",
                           value: accessMode.trapDeviceResourceValue)
    }

    private func setVICEIntResource(_ name: String, value: Int32) {
        name.withCString { resourceName in
            _ = ViceEngineSetIntResource(resourceName, value)
        }
    }

    private func setVICEStringResource(_ name: String, value: String) {
        name.withCString { resourceName in
            value.withCString { resourceValue in
                _ = ViceEngineSetStringResource(resourceName, resourceValue)
            }
        }
    }

    private func handleKeyboardJoystickEvent(_ event: NSEvent, pressed: Bool) -> Bool {
        let matchingDevices = assignedControlDevices(kind: .keyboard).filter { device in
            device.keyboard.joystickBit(for: event.keyCode) != nil
        }

        guard !matchingDevices.isEmpty else {
            return false
        }

        if pressed, event.isARepeat {
            return true
        }

        for device in matchingDevices {
            if pressed {
                keyboardJoystickPressedKeys[device.id, default: []].insert(event.keyCode)
            } else {
                keyboardJoystickPressedKeys[device.id, default: []].remove(event.keyCode)
            }

            publishKeyboardJoystickValue(for: device, force: false)
        }

        return true
    }

    private func keyboardJoystickValue(for device: ControlDeviceConfiguration) -> UInt16 {
        var pressedBits: UInt16 = 0

        for keyCode in keyboardJoystickPressedKeys[device.id, default: []] {
            if let bit = device.keyboard.joystickBit(for: keyCode) {
                pressedBits |= bit
            }
        }

        return normalizedJoystickValue(pressedBits)
    }

    private func setupGameControllerMonitoring() {
        let connectObserver = NotificationCenter.default.addObserver(forName: .GCControllerDidConnect,
                                                                     object: nil,
                                                                     queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refreshGameControllers()
            }
        }
        let disconnectObserver = NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect,
                                                                        object: nil,
                                                                        queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refreshGameControllers()
            }
        }

        gameControllerObservers = [connectObserver, disconnectObserver]
        GCController.startWirelessControllerDiscovery()
        refreshGameControllers()
    }

    private func refreshGameControllers() {
        let controllers = GCController.controllers()
        gameControllerNames = Array(Set(controllers.map(Self.displayName(for:))))

        for controller in controllers {
            installGameControllerHandlers(controller)
        }

        publishGameControllerValues(force: true)
    }

    private func installGameControllerHandlers(_ controller: GCController) {
        controller.extendedGamepad?.valueChangedHandler = { [weak self, weak controller] _, _ in
            guard let controller else {
                return
            }

            Task { @MainActor in
                self?.handleGameControllerChanged(controller: controller)
            }
        }

        controller.microGamepad?.valueChangedHandler = { [weak self, weak controller] _, _ in
            guard let controller else {
                return
            }

            Task { @MainActor in
                self?.handleGameControllerChanged(controller: controller)
            }
        }
    }

    private func handleGameControllerChanged(controller: GCController) {
        guard assignedControlDevices(kind: .joystick).contains(where: { device in
            gameController(for: device) === controller
        }) else {
            return
        }

        publishGameControllerValues(force: false)
    }

    private func publishGameControllerValues(force: Bool) {
        for device in assignedControlDevices(kind: .joystick) {
            let value = gameControllerValue(for: device)
            publishJoystickValue(value, for: device, force: force)
        }
    }

    private func gameControllerValue(for device: ControlDeviceConfiguration) -> UInt16 {
        guard let controller = gameController(for: device) else {
            return 0
        }

        if let extendedGamepad = controller.extendedGamepad {
            return gameControllerValue(from: extendedGamepad, mapping: device.joystick)
        }
        if let microGamepad = controller.microGamepad {
            return gameControllerValue(from: microGamepad, mapping: device.joystick)
        }

        return 0
    }

    private func gameController(for device: ControlDeviceConfiguration) -> GCController? {
        let controllers = GCController.controllers()

        if let preferredControllerName = device.joystick.preferredControllerName {
            return controllers.first { Self.displayName(for: $0) == preferredControllerName }
        }

        return controllers.first
    }

    private func gameControllerValue(from gamepad: GCExtendedGamepad,
                                     mapping: GameControllerJoystickMapping) -> UInt16 {
        let deadZone = Float(mapping.deadZone)
        var value: UInt16 = 0

        for action in JoystickAction.allCases where mapping.control(for: action).isActive(on: gamepad, deadZone: deadZone) {
            value |= action.bit
        }

        return normalizedJoystickValue(value)
    }

    private func gameControllerValue(from gamepad: GCMicroGamepad,
                                     mapping: GameControllerJoystickMapping) -> UInt16 {
        let deadZone = Float(mapping.deadZone)
        var value: UInt16 = 0

        for action in JoystickAction.allCases where mapping.control(for: action).isActive(on: gamepad, deadZone: deadZone) {
            value |= action.bit
        }

        return normalizedJoystickValue(value)
    }

    private func normalizedJoystickValue(_ value: UInt16) -> UInt16 {
        var normalizedValue = value

        if (normalizedValue & JoystickBits.up) != 0,
           (normalizedValue & JoystickBits.down) != 0 {
            normalizedValue &= ~(JoystickBits.up | JoystickBits.down)
        }

        if (normalizedValue & JoystickBits.left) != 0,
           (normalizedValue & JoystickBits.right) != 0 {
            normalizedValue &= ~(JoystickBits.left | JoystickBits.right)
        }

        return normalizedValue
    }

    private func publishKeyboardJoystickValues(force: Bool) {
        for device in assignedControlDevices(kind: .keyboard) {
            publishKeyboardJoystickValue(for: device, force: force)
        }
    }

    private func publishKeyboardJoystickValue(for device: ControlDeviceConfiguration, force: Bool) {
        let value = keyboardJoystickValue(for: device)
        publishJoystickValue(value, for: device, force: force)
    }

    private func publishJoystickValue(_ value: UInt16, for device: ControlDeviceConfiguration, force: Bool) {
        if force || lastJoystickValues[device.id] != value {
            lastJoystickValues[device.id] = value
            publishJoystickValue(value, forDeviceID: device.id)
        }
    }

    private func publishJoystickValue(_ value: UInt16, forDeviceID deviceID: UUID) {
        for port in availableControlPorts where controlPorts.assignedDeviceID(for: port) == deviceID {
            publishJoystickValue(value, to: port)
        }
    }

    private func currentJoystickValue(for device: ControlDeviceConfiguration) -> UInt16 {
        switch device.kind {
        case .keyboard:
            return keyboardJoystickValue(for: device)
        case .joystick:
            return gameControllerValue(for: device)
        }
    }

    private func assignedControlDevices(kind: ControlDeviceKind) -> [ControlDeviceConfiguration] {
        var devices: [ControlDeviceConfiguration] = []

        for port in availableControlPorts {
            guard let device = controlPorts.assignedDevice(for: port),
                  device.kind == kind,
                  !devices.contains(where: { $0.id == device.id }) else {
                continue
            }

            devices.append(device)
        }

        return devices
    }

    private func publishJoystickValue(_ value: UInt16, to port: ControlPort) {
        let normalizedValue = value & JoystickBits.all
        if controlPortValues[port] != normalizedValue {
            controlPortValues[port] = normalizedValue
        }

        guard ViceEngineIsRunning() else {
            return
        }

        _ = ViceEngineSetJoystickValue(port.joystickIndex, UInt32(normalizedValue))
    }

    private func uniqueControlDeviceName(baseName: String) -> String {
        let existingNames = Set(controlPorts.devices.map(\.name))

        guard existingNames.contains(baseName) else {
            return baseName
        }

        for index in 2...99 {
            let candidate = "\(baseName) \(index)"
            if !existingNames.contains(candidate) {
                return candidate
            }
        }

        return "\(baseName) \(controlPorts.devices.count + 1)"
    }

    private static func displayName(for controller: GCController) -> String {
        controller.vendorName ?? "Game Controller"
    }
}

private struct PressedEmulatorKey {
    let symbol: Int64
    let modifiers: Int32
}

private struct EmulatorModifierKey {
    let symbol: Int64
    let modifiers: Int32
    let isToggle: Bool
}

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

private enum ViceResource {
    static let speed = "Speed"
    static let sidModel = "SidModel"
    static let sound = "Sound"
    static let soundVolume = "SoundVolume"
    static let reu = "REU"
    static let reuSize = "REUsize"
    static let georam = "GEORAM"
    static let georamSize = "GEORAMsize"
    static let ramCart = "RAMCART"
    static let ramCartSize = "RAMCARTsize"
    static let dqbb = "DQBB"
    static let dqbbSize = "DQBBSize"
    static let dqbbMode = "DQBBMode"
    static let isepicCartridgeEnabled = "IsepicCartridgeEnabled"
    static let isepicSwitch = "IsepicSwitch"
    static let memoryHack = "MemoryHack"
    static let c64_256kBase = "C64_256Kbase"
    static let plus60kBase = "PLUS60Kbase"
    static let vic20RAMBlocks: [(block: Int, name: String)] = [
        (0, "RAMBlock0"),
        (1, "RAMBlock1"),
        (2, "RAMBlock2"),
        (3, "RAMBlock3"),
        (5, "RAMBlock5")
    ]
}

private enum ViceJoyPortDevice {
    static let none: Int32 = 0
    static let joystick: Int32 = 1
}

private enum ViceDQBBMode {
    static let c64: Int32 = 1
}

private enum EmulatorDefaults {
    private static let videoStandardKey = "vice.videoStandard"
    private static let emulationSpeedKey = "vice.emulationSpeed"
    private static let displayModeKey = "vice.displayMode"
    private static let sidModelKey = "vice.sidModel"
    private static let soundEnabledKey = "vice.soundEnabled"
    private static let soundVolumeKey = "vice.soundVolume"
    private static let romImagesKey = "vice.romImages"
    private static let ramExpansionKey = "vice.ramExpansion"
    private static let controlPortsKey = "vice.controlPorts"
    private static let driveConfigurationsKey = "vice.driveConfigurations"

    static func loadVideoStandard(for machine: EmulatedMachine) -> EmulatorSession.VideoStandard {
        guard let rawValue = UserDefaults.standard.string(forKey: key(videoStandardKey, machine: machine))
                ?? legacyString(forKey: videoStandardKey, machine: machine) else {
            return .ntsc
        }

        return EmulatorSession.VideoStandard(rawValue: rawValue) ?? .ntsc
    }

    static func saveVideoStandard(_ standard: EmulatorSession.VideoStandard, for machine: EmulatedMachine) {
        UserDefaults.standard.set(standard.rawValue, forKey: key(videoStandardKey, machine: machine))
    }

    static func loadEmulationSpeed(for machine: EmulatedMachine) -> EmulatorSession.EmulationSpeed {
        guard let rawValue = UserDefaults.standard.string(forKey: key(emulationSpeedKey, machine: machine))
                ?? legacyString(forKey: emulationSpeedKey, machine: machine) else {
            return .normal
        }

        return EmulatorSession.EmulationSpeed(rawValue: rawValue) ?? .normal
    }

    static func saveEmulationSpeed(_ speed: EmulatorSession.EmulationSpeed, for machine: EmulatedMachine) {
        UserDefaults.standard.set(speed.rawValue, forKey: key(emulationSpeedKey, machine: machine))
    }

    static func loadDisplayMode(for machine: EmulatedMachine) -> EmulatorSession.DisplayMode {
        guard let rawValue = UserDefaults.standard.string(forKey: displayModeKey) else {
            return .native
        }

        return EmulatorSession.DisplayMode(rawValue: rawValue) ?? .native
    }

    static func saveDisplayMode(_ mode: EmulatorSession.DisplayMode, for machine: EmulatedMachine) {
        UserDefaults.standard.set(mode.rawValue, forKey: displayModeKey)
    }

    static func loadSIDModel(for machine: EmulatedMachine) -> EmulatorSession.SIDModel {
        let defaultsKey = key(sidModelKey, machine: machine)
        let legacyKey = machine.id == .x64sc ? sidModelKey : defaultsKey
        let activeKey = UserDefaults.standard.object(forKey: defaultsKey) != nil ? defaultsKey : legacyKey

        guard UserDefaults.standard.object(forKey: activeKey) != nil else {
            return .mos8580
        }

        let rawValue = Int32(UserDefaults.standard.integer(forKey: activeKey))
        return EmulatorSession.SIDModel(rawValue: rawValue) ?? .mos8580
    }

    static func saveSIDModel(_ model: EmulatorSession.SIDModel, for machine: EmulatedMachine) {
        UserDefaults.standard.set(Int(model.rawValue), forKey: key(sidModelKey, machine: machine))
    }

    static func loadSoundEnabled(for machine: EmulatedMachine) -> Bool {
        guard UserDefaults.standard.object(forKey: soundEnabledKey) != nil else {
            return true
        }

        return UserDefaults.standard.bool(forKey: soundEnabledKey)
    }

    static func saveSoundEnabled(_ enabled: Bool, for machine: EmulatedMachine) {
        UserDefaults.standard.set(enabled, forKey: soundEnabledKey)
    }

    static func loadSoundVolume(for machine: EmulatedMachine) -> Int {
        guard UserDefaults.standard.object(forKey: soundVolumeKey) != nil else {
            return 100
        }

        return min(max(UserDefaults.standard.integer(forKey: soundVolumeKey), 0), 100)
    }

    static func saveSoundVolume(_ volume: Int, for machine: EmulatedMachine) {
        UserDefaults.standard.set(min(max(volume, 0), 100), forKey: soundVolumeKey)
    }

    static func loadROMImages(for machine: EmulatedMachine) -> ROMImageConfiguration {
        guard let data = UserDefaults.standard.data(forKey: key(romImagesKey, machine: machine))
                ?? legacyData(forKey: romImagesKey, machine: machine),
              let images = try? JSONDecoder().decode(ROMImageConfiguration.self, from: data) else {
            return .standard
        }

        return images
    }

    static func saveROMImages(_ images: ROMImageConfiguration, for machine: EmulatedMachine) {
        guard let data = try? JSONEncoder().encode(images) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key(romImagesKey, machine: machine))
    }

    static func loadRAMExpansion(for machine: EmulatedMachine) -> RAMExpansion {
        guard machine.capabilities.supportsRAMExpansion,
              let rawValue = UserDefaults.standard.string(forKey: key(ramExpansionKey, machine: machine))
                ?? legacyString(forKey: ramExpansionKey, machine: machine) else {
            return .none
        }

        guard let expansion = RAMExpansion(rawValue: rawValue),
              machine.ramExpansions.contains(expansion) else {
            return .none
        }

        return expansion
    }

    static func saveRAMExpansion(_ expansion: RAMExpansion, for machine: EmulatedMachine) {
        UserDefaults.standard.set(expansion.rawValue, forKey: key(ramExpansionKey, machine: machine))
    }

    static func loadControlPorts(for machine: EmulatedMachine) -> ControlPortConfiguration {
        guard let data = UserDefaults.standard.data(forKey: key(controlPortsKey, machine: machine))
                ?? legacyData(forKey: controlPortsKey, machine: machine),
              let configuration = try? JSONDecoder().decode(ControlPortConfiguration.self, from: data) else {
            return .standard
        }

        return configuration.sanitized()
    }

    static func saveControlPorts(_ configuration: ControlPortConfiguration, for machine: EmulatedMachine) {
        guard let data = try? JSONEncoder().encode(configuration) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key(controlPortsKey, machine: machine))
    }

    static func loadDriveConfigurations(for machine: EmulatedMachine) -> [DriveConfiguration] {
        guard let data = UserDefaults.standard.data(forKey: key(driveConfigurationsKey, machine: machine))
                ?? legacyData(forKey: driveConfigurationsKey, machine: machine),
              let configurations = try? JSONDecoder().decode([DriveConfiguration].self, from: data),
              configurations.map(\.unit) == machine.capabilities.driveUnits else {
            return machine.defaultDriveConfigurations()
        }

        return EmulatorSession.normalizedDriveConfigurations(configurations, for: machine)
    }

    static func saveDriveConfigurations(_ configurations: [DriveConfiguration], for machine: EmulatedMachine) {
        guard let data = try? JSONEncoder().encode(configurations) else {
            return
        }

        UserDefaults.standard.set(data, forKey: key(driveConfigurationsKey, machine: machine))
    }

    private static func key(_ baseKey: String, machine: EmulatedMachine) -> String {
        "\(baseKey).\(machine.id.rawValue)"
    }

    private static func legacyData(forKey baseKey: String, machine: EmulatedMachine) -> Data? {
        guard machine.id == .x64sc else {
            return nil
        }

        return UserDefaults.standard.data(forKey: baseKey)
    }

    private static func legacyString(forKey baseKey: String, machine: EmulatedMachine) -> String? {
        guard machine.id == .x64sc else {
            return nil
        }

        return UserDefaults.standard.string(forKey: baseKey)
    }
}

private enum ViceMacKeyMapper {
    private enum Modifier {
        static let leftShift: Int32 = 1 << 0
        static let rightShift: Int32 = 1 << 1
        static let leftControl: Int32 = 1 << 2
        static let leftOption: Int32 = 1 << 4
        static let rightOption: Int32 = 1 << 5
    }

    private enum Key {
        static let backspace: Int64 = 0xff08
        static let tab: Int64 = 0xff09
        static let returnKey: Int64 = 0xff0d
        static let escape: Int64 = 0xff1b
        static let insert: Int64 = 0xff63
        static let delete: Int64 = 0xffff
        static let home: Int64 = 0xff50
        static let left: Int64 = 0xff51
        static let up: Int64 = 0xff52
        static let right: Int64 = 0xff53
        static let down: Int64 = 0xff54
        static let pageUp: Int64 = 0xff55
        static let pageDown: Int64 = 0xff56
        static let end: Int64 = 0xff57
        static let shiftLeft: Int64 = 0xffe1
        static let shiftRight: Int64 = 0xffe2
        static let controlLeft: Int64 = 0xffe3
        static let capsLock: Int64 = 0xffe5
        static let f1: Int64 = 0xffbe
    }

    private enum MacKeyCode {
        static let tab: UInt16 = 48
        static let returnKey: UInt16 = 36
        static let keypadEnter: UInt16 = 76
        static let escape: UInt16 = 53
        static let delete: UInt16 = 51
        static let forwardDelete: UInt16 = 117
        static let home: UInt16 = 115
        static let end: UInt16 = 119
        static let pageUp: UInt16 = 116
        static let pageDown: UInt16 = 121
        static let leftArrow: UInt16 = 123
        static let rightArrow: UInt16 = 124
        static let downArrow: UInt16 = 125
        static let upArrow: UInt16 = 126
        static let leftShift: UInt16 = 56
        static let rightShift: UInt16 = 60
        static let capsLock: UInt16 = 57
        static let leftControl: UInt16 = 59
        static let f1: UInt16 = 122
        static let f2: UInt16 = 120
        static let f3: UInt16 = 99
        static let f4: UInt16 = 118
        static let f5: UInt16 = 96
        static let f6: UInt16 = 97
        static let f7: UInt16 = 98
        static let f8: UInt16 = 100
        static let f9: UInt16 = 101
        static let f10: UInt16 = 109
        static let f11: UInt16 = 103
        static let f12: UInt16 = 111
    }

    static func symbol(for event: NSEvent) -> Int64? {
        if let special = specialSymbol(for: event.keyCode) {
            return special
        }

        guard let scalar = event.characters?.unicodeScalars.first,
              scalar.value >= 0x20,
              scalar.value <= 0x7e else {
            return nil
        }

        return Int64(scalar.value)
    }

    static func modifiers(for event: NSEvent) -> Int32 {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: Int32 = 0

        if flags.contains(.shift) {
            modifiers |= Modifier.leftShift
        }
        if flags.contains(.control) {
            modifiers |= Modifier.leftControl
        }
        if flags.contains(.option) {
            modifiers |= Modifier.leftOption
        }

        return modifiers
    }

    static func modifierKey(for event: NSEvent) -> EmulatorModifierKey? {
        switch event.keyCode {
        case MacKeyCode.leftShift:
            return EmulatorModifierKey(symbol: Key.shiftLeft,
                                       modifiers: Modifier.leftShift,
                                       isToggle: false)
        case MacKeyCode.rightShift:
            return EmulatorModifierKey(symbol: Key.shiftRight,
                                       modifiers: Modifier.rightShift,
                                       isToggle: false)
        case MacKeyCode.leftControl:
            return EmulatorModifierKey(symbol: Key.controlLeft,
                                       modifiers: Modifier.leftControl,
                                       isToggle: false)
        case MacKeyCode.capsLock:
            return EmulatorModifierKey(symbol: Key.capsLock,
                                       modifiers: 0,
                                       isToggle: true)
        default:
            return nil
        }
    }

    private static func specialSymbol(for keyCode: UInt16) -> Int64? {
        switch keyCode {
        case MacKeyCode.tab:
            return Key.tab
        case MacKeyCode.returnKey, MacKeyCode.keypadEnter:
            return Key.returnKey
        case MacKeyCode.escape:
            return Key.escape
        case MacKeyCode.delete:
            return Key.backspace
        case MacKeyCode.forwardDelete:
            return Key.delete
        case MacKeyCode.home:
            return Key.home
        case MacKeyCode.end:
            return Key.end
        case MacKeyCode.pageUp:
            return Key.pageUp
        case MacKeyCode.pageDown:
            return Key.pageDown
        case MacKeyCode.leftArrow:
            return Key.left
        case MacKeyCode.rightArrow:
            return Key.right
        case MacKeyCode.downArrow:
            return Key.down
        case MacKeyCode.upArrow:
            return Key.up
        default:
            return functionSymbol(for: keyCode)
        }
    }

    private static func functionSymbol(for keyCode: UInt16) -> Int64? {
        switch keyCode {
        case MacKeyCode.f1:
            return Key.f1
        case MacKeyCode.f2:
            return Key.f1 + 1
        case MacKeyCode.f3:
            return Key.f1 + 2
        case MacKeyCode.f4:
            return Key.f1 + 3
        case MacKeyCode.f5:
            return Key.f1 + 4
        case MacKeyCode.f6:
            return Key.f1 + 5
        case MacKeyCode.f7:
            return Key.f1 + 6
        case MacKeyCode.f8:
            return Key.f1 + 7
        case MacKeyCode.f9:
            return Key.f1 + 8
        case MacKeyCode.f10:
            return Key.f1 + 9
        case MacKeyCode.f11:
            return Key.f1 + 10
        case MacKeyCode.f12:
            return Key.f1 + 11
        default:
            return nil
        }
    }
}

private extension Array where Element == String {
    func withCStringArray<Result>(
        _ body: (Int32, UnsafePointer<UnsafePointer<CChar>?>?) -> Result
    ) -> Result {
        var cStrings: [UnsafeMutablePointer<CChar>] = []
        cStrings.reserveCapacity(count)

        for string in self {
            guard let cString = strdup(string) else {
                fatalError("Unable to allocate C string")
            }
            cStrings.append(cString)
        }
        defer {
            for cString in cStrings {
                free(cString)
            }
        }

        var pointers = cStrings.map { Optional(UnsafePointer<CChar>($0)) }
        pointers.append(nil)

        return pointers.withUnsafeBufferPointer { buffer in
            body(Int32(count), buffer.baseAddress)
        }
    }
}

private let viceFrameCallback: @convention(c) (
    UnsafePointer<ViceEngineVideoFrame>?,
    UnsafeMutableRawPointer?
) -> Void = { framePointer, context in
    guard let framePointer,
          let context,
          framePointer.pointee.pixelFormat == 1,
          framePointer.pointee.width > 0,
          framePointer.pointee.height > 0,
          framePointer.pointee.stride >= framePointer.pointee.width * 4,
          let pixels = framePointer.pointee.pixels else {
        return
    }

    let frame = framePointer.pointee
    let byteCount = Int(frame.stride * frame.height)
    let source = Unmanaged<EmulatorFrameSource>.fromOpaque(context).takeUnretainedValue()
    let pixelData = Data(bytes: pixels, count: byteCount)

    source.publish(EmulatorVideoFrame(width: Int(frame.width),
                                      height: Int(frame.height),
                                      bytesPerRow: Int(frame.stride),
                                      sequence: frame.sequence,
                                      pixels: pixelData))
}

private let viceDriveStatusCallback: @convention(c) (
    UnsafePointer<ViceEngineDriveStatus>?,
    UnsafeMutableRawPointer?
) -> Void = { statusPointer, context in
    guard let statusPointer,
          let context else {
        return
    }

    let status = statusPointer.pointee
    let session = Unmanaged<EmulatorSession>.fromOpaque(context).takeUnretainedValue()
    let imagePath: String?
    let drive0ImagePath: String?
    let drive1ImagePath: String?
    let driveStatusText: String?

    if let imagePathPointer = status.imagePath, imagePathPointer.pointee != 0 {
        imagePath = String(cString: imagePathPointer)
    } else {
        imagePath = nil
    }

    if let drive0ImagePathPointer = status.drive0ImagePath, drive0ImagePathPointer.pointee != 0 {
        drive0ImagePath = String(cString: drive0ImagePathPointer)
    } else {
        drive0ImagePath = nil
    }

    if let drive1ImagePathPointer = status.drive1ImagePath, drive1ImagePathPointer.pointee != 0 {
        drive1ImagePath = String(cString: drive1ImagePathPointer)
    } else {
        drive1ImagePath = nil
    }

    if let driveStatusTextPointer = status.driveStatusText, driveStatusTextPointer.pointee != 0 {
        driveStatusText = String(cString: driveStatusTextPointer)
    } else {
        driveStatusText = nil
    }

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
                                       driveStatusText: driveStatusText,
                                       imagePath: imagePath,
                                       drive0ImagePath: drive0ImagePath,
                                       drive1ImagePath: drive1ImagePath)

    Task { @MainActor in
        session.handleDriveStatus(snapshot)
    }
}

private let viceCartridgeStatusCallback: @convention(c) (
    UnsafePointer<ViceEngineCartridgeStatus>?,
    UnsafeMutableRawPointer?
) -> Void = { statusPointer, context in
    guard let statusPointer,
          let context else {
        return
    }

    let status = statusPointer.pointee
    let session = Unmanaged<EmulatorSession>.fromOpaque(context).takeUnretainedValue()
    let cartridgeName: String?
    let imagePath: String?

    if let cartridgeNamePointer = status.cartridgeName, cartridgeNamePointer.pointee != 0 {
        cartridgeName = String(cString: cartridgeNamePointer)
    } else {
        cartridgeName = nil
    }

    if let imagePathPointer = status.imagePath, imagePathPointer.pointee != 0 {
        imagePath = String(cString: imagePathPointer)
    } else {
        imagePath = nil
    }

    let snapshot = CartridgeStatusSnapshot(isAttached: status.attached,
                                           cartridgeID: status.cartridgeID,
                                           cartridgeFlags: status.cartridgeFlags,
                                           romSize: status.romSize,
                                           chipCount: status.chipCount,
                                           bankCount: status.bankCount,
                                           cartridgeName: cartridgeName,
                                           imagePath: imagePath)

    Task { @MainActor in
        session.handleCartridgeStatus(snapshot)
    }
}
