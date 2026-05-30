import AppKit
import Foundation
import GameController

extension EmulatorSession {
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

    var pointerControlAssignment: PointerControlAssignment {
        let assignedPort = availableControlPorts.first { port in
            controlPorts.assignedDevice(for: port)?.kind == .mouse1351
        }

        return PointerControlAssignment(port: assignedPort)
    }

    func setPointerControlAssignment(_ assignment: PointerControlAssignment) {
        var updatedConfiguration = controlPorts

        for port in availableControlPorts where updatedConfiguration.assignedDevice(for: port)?.kind == .mouse1351 {
            updatedConfiguration.setAssignedDeviceID(nil, for: port)
        }

        if let port = assignment.port,
           availableControlPorts.contains(port) {
            let mouseID = existingMacMouseDeviceID(in: updatedConfiguration)
                ?? makeDefaultMacMouseDevice(in: &updatedConfiguration)
            updatedConfiguration.setAssignedDeviceID(mouseID, for: port)
        }

        controlPorts = updatedConfiguration
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
        case .mouse1351:
            return .connected
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
        case .mouse1351:
            return ControlDeviceConfiguration.mouse1351(name: uniqueControlDeviceName(baseName: "Mac Mouse 1351"))
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

    private func existingMacMouseDeviceID(in configuration: ControlPortConfiguration) -> UUID? {
        configuration.devices.first { $0.kind == .mouse1351 }?.id
    }

    private func makeDefaultMacMouseDevice(in configuration: inout ControlPortConfiguration) -> UUID {
        let device = ControlDeviceConfiguration.mouse1351(name: uniqueControlDeviceName(baseName: "Mac Mouse 1351"))
        configuration.devices.append(device)
        return device.id
    }

    func setKeyboardMappingMode(_ mode: VICEKeyboardMappingMode) {
        guard keyboardMapping.mode != mode else {
            return
        }

        keyboardMapping = VICEKeyboardMappingConfiguration(mode: mode,
                                                           profile: keyboardMapping.profile)
    }

    func useVICEKeyboardDefaults() {
        keyboardMapping = VICEKeyboardMappingConfiguration(mode: keyboardMapping.mode,
                                                           profile: .viceDefault)
    }

    @discardableResult
    func useCustomKeyboardMapping() -> Bool {
        do {
            try VICEKeymapStore.ensureCustomKeymap(for: keyboardMappingMachine, mode: keyboardMapping.mode)
            keyboardMapping = VICEKeyboardMappingConfiguration(mode: keyboardMapping.mode,
                                                               profile: .custom)
            return true
        } catch {
            statusText = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func saveKeyboardMapEntry(_ entry: VICEKeymapEntry) -> Bool {
        do {
            let document = try VICEKeymapStore.ensureCustomKeymap(for: keyboardMappingMachine,
                                                                  mode: keyboardMapping.mode)
                .updating(entry: entry)
                .syncingModifierDirectives(for: entry)
            let url = VICEKeymapStore.customKeymapURL(for: keyboardMappingMachine,
                                                      mode: keyboardMapping.mode)
            try VICEKeymapStore.save(document,
                                     to: url,
                                     title: "Custom \(machine.shortName) \(keyboardMapping.mode.shortTitle) map")
            keyboardMapping = VICEKeyboardMappingConfiguration(mode: keyboardMapping.mode,
                                                               profile: .custom)
            applyKeyboardMapping(forceReload: true)
            statusText = "Keyboard map updated"
            return true
        } catch {
            statusText = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func removeKeyboardMapEntry(_ entry: VICEKeymapEntry) -> Bool {
        do {
            let document = try VICEKeymapStore.ensureCustomKeymap(for: keyboardMappingMachine,
                                                                  mode: keyboardMapping.mode)
                .removingEntry(id: entry.id)
            let url = VICEKeymapStore.customKeymapURL(for: keyboardMappingMachine,
                                                      mode: keyboardMapping.mode)
            try VICEKeymapStore.save(document,
                                     to: url,
                                     title: "Custom \(machine.shortName) \(keyboardMapping.mode.shortTitle) map")
            keyboardMapping = VICEKeyboardMappingConfiguration(mode: keyboardMapping.mode,
                                                               profile: .custom)
            applyKeyboardMapping(forceReload: true)
            statusText = "Keyboard mapping removed"
            return true
        } catch {
            statusText = error.localizedDescription
            return false
        }
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

    @discardableResult
    func handleMouseMoved(deltaX: CGFloat, deltaY: CGFloat) -> Bool {
        guard isMouse1351Assigned,
              ViceEngineIsRunning() else {
            return false
        }

        return ViceEngineMoveMouse(Float(deltaX), Float(deltaY))
    }

    @discardableResult
    func handleMouseButton(_ button: UInt32, pressed: Bool) -> Bool {
        guard isMouse1351Assigned,
              ViceEngineIsRunning() else {
            return false
        }

        if pressed {
            pressedMouseButtons.insert(button)
        } else {
            pressedMouseButtons.remove(button)
        }
        updateMouseControlPortValues()

        return ViceEngineSetMouseButton(button, pressed)
    }

    func handleMouseCaptureChanged(_ captured: Bool) {
        guard ViceEngineIsRunning() else {
            return
        }

        if !captured {
            releaseMouseButtons()
            _ = ViceEngineResetMouse()
        }
    }

    func releaseAllKeys() {
        pressedKeys.removeAll()
        keyboardJoystickPressedKeys.removeAll()
        ViceEngineReleaseAllKeys()
        releaseMouseButtons()

        for device in assignedControlDevices(kind: .keyboard) {
            lastJoystickValues[device.id] = 0
            publishJoystickValue(0, forDeviceID: device.id)
        }
    }

    @discardableResult
    func typeText(_ text: String) -> Bool {
        queueKeyboardText(text)
    }

    @discardableResult
    func submitLine(_ line: String) -> Bool {
        queueKeyboardText("\(line)\r")
    }

    @discardableResult
    func pasteFromPasteboard(_ pasteboard: NSPasteboard = .general) -> Bool {
        guard let text = pasteboard.string(forType: .string),
              !text.isEmpty else {
            statusText = "Clipboard has no text"
            return false
        }

        guard canReceiveKeyboardText else {
            statusText = isPaused ? "Resume before pasting" : "Emulator is not running"
            return false
        }

        let didPaste = queueKeyboardText(text)
        statusText = didPaste ? pasteStatusText(for: text) : "Unable to paste clipboard text"
        return didPaste
    }

    @discardableResult
    private func queueKeyboardText(_ text: String) -> Bool {
        guard canReceiveKeyboardText else {
            return false
        }

        let chunks = Self.keyboardTextChunks(for: text)
        guard !chunks.isEmpty else {
            return false
        }

        for chunk in chunks {
            let didQueue = chunk.withCString { pointer in
                ViceEngineFeedKeyboardText(pointer)
            }
            if !didQueue {
                return false
            }
        }

        return true
    }

    var canReceiveKeyboardText: Bool {
        ViceEngineIsRunning() && !isPaused
    }

    nonisolated static func keyboardTextChunks(for text: String) -> [String] {
        var chunks: [String] = []
        var chunkScalars = String.UnicodeScalarView()

        for scalar in normalizedKeyboardText(text).unicodeScalars {
            if chunkScalars.count >= maxKeyboardTextChunkLength {
                chunks.append(String(chunkScalars))
                chunkScalars.removeAll(keepingCapacity: true)
            }

            chunkScalars.append(scalar)
        }

        if !chunkScalars.isEmpty {
            chunks.append(String(chunkScalars))
        }

        return chunks
    }

    nonisolated private static func normalizedKeyboardText(_ text: String) -> String {
        var normalized = String.UnicodeScalarView()

        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0:
                continue
            case 0x09:
                normalized.append(" ")
            case 0x0a, 0x0d, 0x20...0x7e:
                normalized.append(scalar)
            default:
                normalized.append("?")
            }
        }

        return String(normalized)
    }

    private func pasteStatusText(for text: String) -> String {
        let lineCount = text.split(whereSeparator: \.isNewline).count
        if lineCount > 1 {
            return "Pasted \(lineCount) lines"
        }

        return "Pasted clipboard text"
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

    func setupGameControllerMonitoring() {
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

    func publishGameControllerValues(force: Bool) {
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

    func publishKeyboardJoystickValues(force: Bool) {
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

    func currentJoystickValue(for device: ControlDeviceConfiguration) -> UInt16 {
        switch device.kind {
        case .keyboard:
            return keyboardJoystickValue(for: device)
        case .joystick:
            return gameControllerValue(for: device)
        case .mouse1351:
            return 0
        }
    }

    var isMouse1351Assigned: Bool {
        availableControlPorts.contains { port in
            controlPorts.assignedDevice(for: port)?.kind == .mouse1351
        }
    }

    var mouseButtonJoystickValue: UInt16 {
        var value: UInt16 = 0

        if pressedMouseButtons.contains(0) {
            value |= JoystickBits.fire
        }
        if pressedMouseButtons.contains(2) {
            value |= JoystickBits.up
        }

        return value
    }

    private func updateMouseControlPortValues() {
        for port in availableControlPorts where controlPorts.assignedDevice(for: port)?.kind == .mouse1351 {
            controlPortValues[port] = mouseButtonJoystickValue
        }
    }

    func releaseMouseButtons() {
        guard !pressedMouseButtons.isEmpty else {
            return
        }

        let buttons = pressedMouseButtons
        pressedMouseButtons.removeAll()
        for button in buttons {
            _ = ViceEngineSetMouseButton(button, false)
        }
        updateMouseControlPortValues()
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

    func publishJoystickValue(_ value: UInt16, to port: ControlPort) {
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



extension Array where Element == String {
}
