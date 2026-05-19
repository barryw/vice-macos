import AppKit
import Combine
import Foundation
import GameController

struct DriveConfiguration: Identifiable, Codable, Equatable {
    let unit: Int
    var isAttached: Bool
    var driveType: DriveType
    var soundEnabled: Bool
    var soundVolume: Int

    var id: Int { unit }
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

enum JoystickAction: String, CaseIterable, Identifiable {
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
    var basicPath: String?
    var kernalPath: String?
    var characterPath: String?

    static let standard = ROMImageConfiguration(basicPath: nil,
                                                kernalPath: nil,
                                                characterPath: nil)

    func path(for image: MachineROMImage) -> String? {
        switch image {
        case .basic:
            return basicPath
        case .kernal:
            return kernalPath
        case .character:
            return characterPath
        }
    }

    func resourceValue(for image: MachineROMImage) -> String {
        path(for: image) ?? image.defaultFileName
    }

    mutating func setPath(_ path: String?, for image: MachineROMImage) {
        let normalizedPath = path?.isEmpty == false ? path : nil

        switch image {
        case .basic:
            basicPath = normalizedPath
        case .kernal:
            kernalPath = normalizedPath
        case .character:
            characterPath = normalizedPath
        }
    }
}

enum MachineROMImage: String, CaseIterable, Identifiable {
    case basic
    case kernal
    case character

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic:
            return "BASIC"
        case .kernal:
            return "KERNAL"
        case .character:
            return "Character"
        }
    }

    var resourceName: String {
        switch self {
        case .basic:
            return "BasicName"
        case .kernal:
            return "KernalName"
        case .character:
            return "ChargenName"
        }
    }

    var defaultFileName: String {
        switch self {
        case .basic:
            return "basic-901226-01.bin"
        case .kernal:
            return "kernal-901227-03.bin"
        case .character:
            return "chargen-901225-01.bin"
        }
    }

    var systemImage: String {
        switch self {
        case .basic:
            return "terminal"
        case .kernal:
            return "cpu"
        case .character:
            return "textformat"
        }
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
    case cmdHD = 4844

    var id: Int32 { rawValue }

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
        case .cmdHD:
            return "CMD HD"
        }
    }

    var defaultLEDColor: DriveLEDColor {
        switch self {
        case .c1540, .c1541, .c1570:
            return .red
        case .c1541II, .c1571, .c1581, .fd2000, .fd4000, .cmdHD:
            return .green
        }
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
    var hasErrorStatus: Bool {
        errorIntensity > 0 || (driveStatusCode != DriveStatusCode.ok
            && driveStatusCode != DriveStatusCode.dosVersion)
    }

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

@MainActor
final class EmulatorSession: ObservableObject {
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

            EmulatorDefaults.saveEmulationSpeed(emulationSpeed)
            applyEmulationSpeed()
        }
    }
    @Published var displayMode: DisplayMode {
        didSet {
            guard displayMode != oldValue else {
                return
            }

            EmulatorDefaults.saveDisplayMode(displayMode)
            statusText = "Display \(displayMode.title)"
        }
    }
    @Published var videoStandard: VideoStandard {
        didSet {
            guard videoStandard != oldValue else {
                return
            }

            EmulatorDefaults.saveVideoStandard(videoStandard)
            applyVideoStandard()
        }
    }
    @Published var sidModel: SIDModel {
        didSet {
            guard sidModel != oldValue else {
                return
            }

            EmulatorDefaults.saveSIDModel(sidModel)
            applySIDModel()
        }
    }
    @Published var soundEnabled: Bool {
        didSet {
            guard soundEnabled != oldValue else {
                return
            }

            EmulatorDefaults.saveSoundEnabled(soundEnabled)
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

            EmulatorDefaults.saveSoundVolume(soundVolume)
            applySoundSettings()
        }
    }
    @Published var romImages: ROMImageConfiguration {
        didSet {
            guard romImages != oldValue else {
                return
            }

            EmulatorDefaults.saveROMImages(romImages)
            applyROMImages()
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

            EmulatorDefaults.saveControlPorts(controlPorts)
            applyControlPorts()
            publishKeyboardJoystickValues(force: true)
            publishGameControllerValues(force: true)
        }
    }
    @Published var driveConfigurations: [DriveConfiguration] {
        didSet {
            EmulatorDefaults.saveDriveConfigurations(driveConfigurations)
            applyDriveConfigurations()
        }
    }
    @Published private var driveActivities: [Int: DriveActivity] = [:]
    @Published var cartridgeStatus = CartridgeStatus.detached
    @Published private(set) var gameControllerNames: [String] = []
    @Published var filterSettings = VideoFilterSettings()
    @Published var statusText = "Starting x64sc"

    let frameSource = EmulatorFrameSource.x64scReady()
    private var didStartEngine = false
    private var pressedKeys: [UInt16: PressedEmulatorKey] = [:]
    private var keyboardJoystickPressedKeys: [UUID: Set<UInt16>] = [:]
    private var lastJoystickValues: [UUID: UInt16] = [:]

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

        var viciiModelResourceValue: Int32 {
            switch self {
            case .ntsc:
                return ViceVICIIModel.mos8562
            case .pal:
                return ViceVICIIModel.mos8565
            }
        }

        var powerFrequency: Int32 {
            switch self {
            case .ntsc:
                return 60
            case .pal:
                return 50
            }
        }
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
        videoStandard = EmulatorDefaults.loadVideoStandard()
        emulationSpeed = EmulatorDefaults.loadEmulationSpeed()
        displayMode = EmulatorDefaults.loadDisplayMode()
        sidModel = EmulatorDefaults.loadSIDModel()
        soundEnabled = EmulatorDefaults.loadSoundEnabled()
        soundVolume = EmulatorDefaults.loadSoundVolume()
        romImages = EmulatorDefaults.loadROMImages()
        controlPorts = EmulatorDefaults.loadControlPorts()
        driveConfigurations = EmulatorDefaults.loadDriveConfigurations()
        setupGameControllerMonitoring()
    }

    var visibleDriveActivities: [DriveActivity] {
        driveConfigurations.compactMap { configuration in
            guard configuration.isAttached else {
                return nil
            }

            if let activity = driveActivities[configuration.unit],
               activity.isConfigured {
                return activity
            }

            return DriveActivity(unit: configuration.unit,
                                 isConfigured: true,
                                 driveType: configuration.driveType,
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

    var hasGameControllers: Bool {
        !gameControllerNames.isEmpty
    }

    var sortedGameControllerNames: [String] {
        gameControllerNames.sorted { lhs, rhs in
            lhs.localizedStandardCompare(rhs) == .orderedAscending
        }
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
              let dataDirectory = Bundle.main.resourceURL?.appendingPathComponent("VICEData").path else {
            statusText = "Missing runtime paths"
            return
        }

        didStartEngine = true
        ViceEngineSetVideoFrameCallback(viceFrameCallback,
                                        Unmanaged.passUnretained(frameSource).toOpaque())
        ViceEngineSetDriveStatusCallback(viceDriveStatusCallback,
                                         Unmanaged.passUnretained(self).toOpaque())
        ViceEngineSetCartridgeStatusCallback(viceCartridgeStatusCallback,
                                             Unmanaged.passUnretained(self).toOpaque())

        let basicROM = romImages.resourceValue(for: .basic)
        let kernalROM = romImages.resourceValue(for: .kernal)
        let characterROM = romImages.resourceValue(for: .character)
        let started = executablePath.withCString { executablePathPointer in
            dataDirectory.withCString { dataDirectoryPointer in
                basicROM.withCString { basicROMPointer in
                    kernalROM.withCString { kernalROMPointer in
                        characterROM.withCString { characterROMPointer in
                            ViceEngineStartX64SC(executablePathPointer,
                                                  dataDirectoryPointer,
                                                  sidModel.rawValue,
                                                  soundEnabled,
                                                  Int32(soundVolume),
                                                  emulationSpeed.speedPercent,
                                                  emulationSpeed.isWarpEnabled,
                                                  basicROMPointer,
                                                  kernalROMPointer,
                                                  characterROMPointer)
                        }
                    }
                }
            }
        }

        if started || ViceEngineIsRunning() {
            applyRuntimeConfiguration()
        }

        statusText = started ? "x64sc running" : "x64sc already running"
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

        let activity = DriveActivity(unit: status.unit,
                                     isConfigured: status.enabled,
                                     driveType: driveType,
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
        guard unit >= 8 && unit <= 11 else {
            return
        }

        url.path.withCString { path in
            _ = ViceEngineAttachDisk(UInt32(unit), path, autorun)
        }
    }

    func setROMImage(_ image: MachineROMImage, path: String?) {
        var updatedImages = romImages
        updatedImages.setPath(path, for: image)
        romImages = updatedImages
    }

    func attachCartridge(url: URL) {
        url.path.withCString { path in
            _ = ViceEngineAttachCartridge(path)
        }
    }

    func detachCartridge() {
        _ = ViceEngineDetachCartridge()
    }

    private func applyRuntimeConfiguration() {
        applyVideoStandard(updateStatus: false)
        applySIDModel(updateStatus: false)
        applySoundSettings(updateStatus: false)
        applyEmulationSpeed(updateStatus: false)
        applyPauseState(updateStatus: false)
        applyROMImages()
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
        guard ViceEngineIsRunning() else {
            return
        }

        setVICEIntResource(ViceResource.viciiModel, value: videoStandard.viciiModelResourceValue)
        setVICEIntResource(ViceResource.machinePowerFrequency, value: videoStandard.powerFrequency)

        if updateStatus {
            statusText = "Video \(videoStandard.rawValue)"
        }
    }

    private func applySIDModel(updateStatus: Bool = true) {
        guard ViceEngineIsRunning() else {
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

        for image in MachineROMImage.allCases {
            setVICEStringResource(image.resourceName,
                                  value: romImages.resourceValue(for: image))
        }
    }

    private func applyControlPorts() {
        guard ViceEngineIsRunning() else {
            return
        }

        for port in ControlPort.allCases {
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

        for configuration in driveConfigurations {
            let driveType = configuration.isAttached ? configuration.driveType.rawValue : 0
            setVICEIntResource("Drive\(configuration.unit)Type", value: driveType)
            setVICEIntResource("Drive\(configuration.unit)SoundEmulation", value: configuration.soundEnabled ? 1 : 0)
            setVICEIntResource("Drive\(configuration.unit)SoundEmulationVolume", value: Int32(configuration.soundVolume))
        }

        if updateStatus {
            statusText = "Drive settings updated"
        }
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
        NotificationCenter.default.addObserver(forName: .GCControllerDidConnect,
                                               object: nil,
                                               queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refreshGameControllers()
            }
        }
        NotificationCenter.default.addObserver(forName: .GCControllerDidDisconnect,
                                               object: nil,
                                               queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.refreshGameControllers()
            }
        }

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
        for port in ControlPort.allCases where controlPorts.assignedDeviceID(for: port) == deviceID {
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

        for port in ControlPort.allCases {
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
        guard ViceEngineIsRunning() else {
            return
        }

        _ = ViceEngineSetJoystickValue(port.joystickIndex, UInt32(value))
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
    let ledColor: UInt32
    let ledIntensity: UInt32
    let errorIntensity: UInt32
    let track: UInt32?
    let halfTrack: UInt32?
    let diskSide: UInt32
    let driveStatusCode: Int32
    let driveStatusText: String?
    let imagePath: String?
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
    static let viciiModel = "VICIIModel"
    static let machinePowerFrequency = "MachinePowerFrequency"
    static let speed = "Speed"
    static let sidModel = "SidModel"
    static let sound = "Sound"
    static let soundVolume = "SoundVolume"
}

private enum ViceJoyPortDevice {
    static let none: Int32 = 0
    static let joystick: Int32 = 1
}

private enum ViceVICIIModel {
    static let mos8565: Int32 = 1
    static let mos8562: Int32 = 4
}

private enum EmulatorDefaults {
    private static let videoStandardKey = "vice.videoStandard"
    private static let emulationSpeedKey = "vice.emulationSpeed"
    private static let displayModeKey = "vice.displayMode"
    private static let sidModelKey = "vice.sidModel"
    private static let soundEnabledKey = "vice.soundEnabled"
    private static let soundVolumeKey = "vice.soundVolume"
    private static let romImagesKey = "vice.romImages"
    private static let controlPortsKey = "vice.controlPorts"
    private static let driveConfigurationsKey = "vice.driveConfigurations"

    static func loadVideoStandard() -> EmulatorSession.VideoStandard {
        guard let rawValue = UserDefaults.standard.string(forKey: videoStandardKey) else {
            return .ntsc
        }

        return EmulatorSession.VideoStandard(rawValue: rawValue) ?? .ntsc
    }

    static func saveVideoStandard(_ standard: EmulatorSession.VideoStandard) {
        UserDefaults.standard.set(standard.rawValue, forKey: videoStandardKey)
    }

    static func loadEmulationSpeed() -> EmulatorSession.EmulationSpeed {
        guard let rawValue = UserDefaults.standard.string(forKey: emulationSpeedKey) else {
            return .normal
        }

        return EmulatorSession.EmulationSpeed(rawValue: rawValue) ?? .normal
    }

    static func saveEmulationSpeed(_ speed: EmulatorSession.EmulationSpeed) {
        UserDefaults.standard.set(speed.rawValue, forKey: emulationSpeedKey)
    }

    static func loadDisplayMode() -> EmulatorSession.DisplayMode {
        guard let rawValue = UserDefaults.standard.string(forKey: displayModeKey) else {
            return .native
        }

        return EmulatorSession.DisplayMode(rawValue: rawValue) ?? .native
    }

    static func saveDisplayMode(_ mode: EmulatorSession.DisplayMode) {
        UserDefaults.standard.set(mode.rawValue, forKey: displayModeKey)
    }

    static func loadSIDModel() -> EmulatorSession.SIDModel {
        guard UserDefaults.standard.object(forKey: sidModelKey) != nil else {
            return .mos8580
        }

        let rawValue = Int32(UserDefaults.standard.integer(forKey: sidModelKey))
        return EmulatorSession.SIDModel(rawValue: rawValue) ?? .mos8580
    }

    static func saveSIDModel(_ model: EmulatorSession.SIDModel) {
        UserDefaults.standard.set(Int(model.rawValue), forKey: sidModelKey)
    }

    static func loadSoundEnabled() -> Bool {
        guard UserDefaults.standard.object(forKey: soundEnabledKey) != nil else {
            return true
        }

        return UserDefaults.standard.bool(forKey: soundEnabledKey)
    }

    static func saveSoundEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: soundEnabledKey)
    }

    static func loadSoundVolume() -> Int {
        guard UserDefaults.standard.object(forKey: soundVolumeKey) != nil else {
            return 100
        }

        return min(max(UserDefaults.standard.integer(forKey: soundVolumeKey), 0), 100)
    }

    static func saveSoundVolume(_ volume: Int) {
        UserDefaults.standard.set(min(max(volume, 0), 100), forKey: soundVolumeKey)
    }

    static func loadROMImages() -> ROMImageConfiguration {
        guard let data = UserDefaults.standard.data(forKey: romImagesKey),
              let images = try? JSONDecoder().decode(ROMImageConfiguration.self, from: data) else {
            return .standard
        }

        return images
    }

    static func saveROMImages(_ images: ROMImageConfiguration) {
        guard let data = try? JSONEncoder().encode(images) else {
            return
        }

        UserDefaults.standard.set(data, forKey: romImagesKey)
    }

    static func loadControlPorts() -> ControlPortConfiguration {
        guard let data = UserDefaults.standard.data(forKey: controlPortsKey),
              let configuration = try? JSONDecoder().decode(ControlPortConfiguration.self, from: data) else {
            return .standard
        }

        return configuration
    }

    static func saveControlPorts(_ configuration: ControlPortConfiguration) {
        guard let data = try? JSONEncoder().encode(configuration) else {
            return
        }

        UserDefaults.standard.set(data, forKey: controlPortsKey)
    }

    static func loadDriveConfigurations() -> [DriveConfiguration] {
        guard let data = UserDefaults.standard.data(forKey: driveConfigurationsKey),
              let configurations = try? JSONDecoder().decode([DriveConfiguration].self, from: data),
              configurations.map(\.unit) == [8, 9, 10, 11] else {
            return [
                DriveConfiguration(unit: 8, isAttached: true, driveType: .c1541, soundEnabled: false, soundVolume: 1000),
                DriveConfiguration(unit: 9, isAttached: false, driveType: .c1541, soundEnabled: false, soundVolume: 1000),
                DriveConfiguration(unit: 10, isAttached: false, driveType: .c1541, soundEnabled: false, soundVolume: 1000),
                DriveConfiguration(unit: 11, isAttached: false, driveType: .c1541, soundEnabled: false, soundVolume: 1000)
            ]
        }

        return configurations
    }

    static func saveDriveConfigurations(_ configurations: [DriveConfiguration]) {
        guard let data = try? JSONEncoder().encode(configurations) else {
            return
        }

        UserDefaults.standard.set(data, forKey: driveConfigurationsKey)
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
    let driveStatusText: String?

    if let imagePathPointer = status.imagePath, imagePathPointer.pointee != 0 {
        imagePath = String(cString: imagePathPointer)
    } else {
        imagePath = nil
    }

    if let driveStatusTextPointer = status.driveStatusText, driveStatusTextPointer.pointee != 0 {
        driveStatusText = String(cString: driveStatusTextPointer)
    } else {
        driveStatusText = nil
    }

    let snapshot = DriveStatusSnapshot(unit: Int(status.unit),
                                       enabled: status.enabled,
                                       driveType: status.driveType,
                                       ledColor: status.ledColor,
                                       ledIntensity: status.ledIntensity,
                                       errorIntensity: status.errorIntensity,
                                       track: status.trackValid ? status.track : nil,
                                       halfTrack: status.trackValid ? status.halfTrack : nil,
                                       diskSide: status.diskSide,
                                       driveStatusCode: status.driveStatusCode,
                                       driveStatusText: driveStatusText,
                                       imagePath: imagePath)

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
