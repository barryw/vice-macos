import AppKit
import CMacVICEEngineBridge
import Foundation

/// Receives keyboard, pointer, and joystick input from a MacVICEKit display view.
public protocol MacVICEInputSink: AnyObject {
    /// Sends a raw macOS key code and modifier mask to the running VICE machine.
    @discardableResult
    func sendKeyEvent(keyCode: Int64, modifiers: Int32, pressed: Bool) -> Bool

    /// Feeds text through VICE's keyboard buffer.
    @discardableResult
    func typeText(_ text: String) -> Bool

    /// Sets the current joystick bit mask for a VICE joystick port.
    @discardableResult
    func setJoystickValue(port: UInt32, value: UInt32) -> Bool

    /// Sends relative mouse motion to VICE.
    @discardableResult
    func moveMouse(deltaX: CGFloat, deltaY: CGFloat) -> Bool

    /// Sets a VICE mouse button state.
    @discardableResult
    func setMouseButton(_ button: UInt32, pressed: Bool) -> Bool

    /// Releases all currently pressed keyboard keys.
    func releaseKeyboardKeys()

    /// Releases all captured keyboard and pointer input state.
    func releaseAllInput()
}

extension MacVICEEngineSession: MacVICEInputSink {
    /// Sends a raw macOS key code and modifier mask to the running VICE machine.
    @discardableResult
    public func sendKeyEvent(keyCode: Int64, modifiers: Int32 = 0, pressed: Bool) -> Bool {
        ViceEngineSendKeyEvent(keyCode, modifiers, pressed)
        return true
    }

    /// Sends a macOS key event to the running VICE machine.
    @discardableResult
    public func sendKeyEvent(_ event: NSEvent, pressed: Bool) -> Bool {
        sendKeyEvent(keyCode: Int64(event.keyCode),
                     modifiers: Int32(event.modifierFlags.rawValue),
                     pressed: pressed)
    }

    /// Feeds text through VICE's keyboard buffer.
    @discardableResult
    public func typeText(_ text: String) -> Bool {
        text.withCString { ViceEngineFeedKeyboardText($0) }
    }

    /// Sets the current joystick bit mask for a VICE joystick port.
    @discardableResult
    public func setJoystickValue(port: UInt32, value: UInt32) -> Bool {
        ViceEngineSetJoystickValue(port, value)
    }

    /// Sends relative mouse motion to VICE.
    @discardableResult
    public func moveMouse(deltaX: CGFloat, deltaY: CGFloat) -> Bool {
        ViceEngineMoveMouse(Float(deltaX), Float(deltaY))
    }

    /// Sets a VICE mouse button state.
    @discardableResult
    public func setMouseButton(_ button: UInt32, pressed: Bool) -> Bool {
        ViceEngineSetMouseButton(button, pressed)
    }

    /// Resets VICE's accumulated mouse state.
    @discardableResult
    public func resetMouse() -> Bool {
        ViceEngineResetMouse()
    }

    /// Releases all currently pressed keyboard keys.
    public func releaseKeyboardKeys() {
        ViceEngineReleaseAllKeys()
    }

    /// Releases all captured keyboard and pointer input state.
    public func releaseAllInput() {
        releaseKeyboardKeys()
        _ = ViceEngineResetMouse()
    }
}
