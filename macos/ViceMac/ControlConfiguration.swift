import Foundation
import GameController

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
        let macMouse = ControlDeviceConfiguration.mouse1351(name: "Mac Mouse 1351")

        return ControlPortConfiguration(devices: [keyboardWASD, keyboardArrows, gameController, macMouse],
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

    static func mouse1351(name: String) -> ControlDeviceConfiguration {
        ControlDeviceConfiguration(id: UUID(),
                                   name: name,
                                   kind: .mouse1351,
                                   keyboard: .wasdAndSpace,
                                   joystick: .standard)
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
    case mouse1351

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keyboard:
            return "Keyboard"
        case .joystick:
            return "Joystick"
        case .mouse1351:
            return "Mouse (1351)"
        }
    }

    var defaultName: String {
        switch self {
        case .keyboard:
            return "Keyboard"
        case .joystick:
            return "Joystick"
        case .mouse1351:
            return "Mac Mouse 1351"
        }
    }

    var systemImage: String {
        switch self {
        case .keyboard:
            return "keyboard"
        case .joystick:
            return "gamecontroller"
        case .mouse1351:
            return "computermouse"
        }
    }

    var viceJoyPortDevice: Int32 {
        switch self {
        case .keyboard, .joystick:
            return ViceJoyPortDevice.joystick
        case .mouse1351:
            return ViceJoyPortDevice.mouse1351
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

enum PointerControlAssignment: String, CaseIterable, Identifiable {
    case off
    case port1
    case port2

    var id: String { rawValue }

    var port: ControlPort? {
        switch self {
        case .off:
            return nil
        case .port1:
            return .one
        case .port2:
            return .two
        }
    }

    init(port: ControlPort?) {
        switch port {
        case .one:
            self = .port1
        case .two:
            self = .port2
        case nil:
            self = .off
        }
    }

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .port1:
            return "Port 1"
        case .port2:
            return "Port 2"
        }
    }

    var detail: String {
        switch self {
        case .off:
            return "The Mac pointer stays with macOS."
        case .port1:
            return "Use the Mac pointer as a 1351 mouse in port 1."
        case .port2:
            return "Use the Mac pointer as a 1351 mouse in port 2."
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

    private static let extendedCapturePriority: [GameControllerControl] = [
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
    private static let microCapturePriority: [GameControllerControl] = [
        .buttonSouth,
        .buttonWest,
        .dpadUp,
        .dpadDown,
        .dpadLeft,
        .dpadRight
    ]

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
        extendedCapturePriority.first { $0.isActive(on: gamepad, deadZone: deadZone) }
    }

    static func capturedControl(from gamepad: GCMicroGamepad, deadZone: Float) -> GameControllerControl? {
        microCapturePriority.first { $0.isActive(on: gamepad, deadZone: deadZone) }
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

enum JoystickBits {
    static let up: UInt16 = 1 << 0
    static let down: UInt16 = 1 << 1
    static let left: UInt16 = 1 << 2
    static let right: UInt16 = 1 << 3
    static let fire: UInt16 = 1 << 4
    static let all: UInt16 = up | down | left | right | fire
}

enum ViceJoyPortDevice {
    static let none: Int32 = 0
    static let joystick: Int32 = 1
    static let mouse1351: Int32 = 3
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
