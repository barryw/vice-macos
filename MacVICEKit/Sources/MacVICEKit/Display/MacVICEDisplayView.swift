import AppKit
import MetalKit
import SwiftUI

/// Texture sampling mode used when scaling VICE video frames.
public enum MacVICETextureFiltering: Sendable, Equatable {
    /// Preserve hard pixel edges.
    case nearest
    /// Smooth scaled pixels with linear sampling.
    case linear
}

/// Rendering and input behavior for `MacVICEDisplayView`.
public struct MacVICEDisplayConfiguration: Sendable, Equatable {
    /// Preserve the machine display profile's aspect ratio instead of stretching.
    public var preservesAspectRatio: Bool
    /// Texture filtering used when scaling frames.
    public var filtering: MacVICETextureFiltering
    /// CRT/display filter controls.
    public var filterSettings: MacVICEVideoFilterSettings
    /// Forward keyboard, paste, mouse, and focus events to input handlers.
    public var forwardsInput: Bool
    /// Hide and capture the Mac pointer while it is over the display.
    public var capturesMouse: Bool
    /// Optional image to render before the first VICE frame arrives.
    public var bootImageURL: URL?

    /// Creates display behavior for an embedded VICE view.
    public init(preservesAspectRatio: Bool = true,
                filtering: MacVICETextureFiltering = .nearest,
                filterSettings: MacVICEVideoFilterSettings = .defaults(for: .commodore1702),
                forwardsInput: Bool = true,
                capturesMouse: Bool = false,
                bootImageURL: URL? = nil) {
        self.preservesAspectRatio = preservesAspectRatio
        self.filtering = filtering
        self.filterSettings = filterSettings
        self.forwardsInput = forwardsInput
        self.capturesMouse = capturesMouse
        self.bootImageURL = bootImageURL
    }

    /// Display-only configuration that does not forward input.
    public static let renderOnly = MacVICEDisplayConfiguration(forwardsInput: false)
    /// Interactive display configuration suitable for a normal emulator window.
    public static let interactive = MacVICEDisplayConfiguration()
}

/// Closures used by `MacVICEDisplayView` to route AppKit input.
public struct MacVICEDisplayInputHandlers {
    /// Handles key down and key up events. Return `true` when consumed.
    public var onKeyEvent: (NSEvent, Bool) -> Bool
    /// Handles modifier-flag changes. Return `true` when consumed.
    public var onFlagsChanged: (NSEvent) -> Bool
    /// Handles relative mouse movement. Return `true` when consumed.
    public var onMouseMoved: (CGFloat, CGFloat) -> Bool
    /// Handles mouse button changes. Return `true` when consumed.
    public var onMouseButton: (UInt32, Bool) -> Bool
    /// Called when pointer capture starts or stops.
    public var onMouseCaptureChanged: (Bool) -> Void
    /// Handles paste. Return `true` when consumed.
    public var onPaste: () -> Bool
    /// Called when the display loses keyboard focus.
    public var onFocusLost: () -> Void

    /// Creates a set of optional input handlers.
    public init(onKeyEvent: @escaping (NSEvent, Bool) -> Bool = { _, _ in false },
                onFlagsChanged: @escaping (NSEvent) -> Bool = { _ in false },
                onMouseMoved: @escaping (CGFloat, CGFloat) -> Bool = { _, _ in false },
                onMouseButton: @escaping (UInt32, Bool) -> Bool = { _, _ in false },
                onMouseCaptureChanged: @escaping (Bool) -> Void = { _ in },
                onPaste: @escaping () -> Bool = { false },
                onFocusLost: @escaping () -> Void = {}) {
        self.onKeyEvent = onKeyEvent
        self.onFlagsChanged = onFlagsChanged
        self.onMouseMoved = onMouseMoved
        self.onMouseButton = onMouseButton
        self.onMouseCaptureChanged = onMouseCaptureChanged
        self.onPaste = onPaste
        self.onFocusLost = onFocusLost
    }

    static func inputSink(_ inputSink: any MacVICEInputSink) -> MacVICEDisplayInputHandlers {
        MacVICEDisplayInputHandlers(
            onKeyEvent: { event, pressed in
                inputSink.sendKeyEvent(keyCode: Int64(event.keyCode),
                                       modifiers: Int32(event.modifierFlags.rawValue),
                                       pressed: pressed)
            },
            onMouseMoved: { deltaX, deltaY in
                inputSink.moveMouse(deltaX: deltaX, deltaY: deltaY)
            },
            onMouseButton: { button, pressed in
                inputSink.setMouseButton(button, pressed: pressed)
            },
            onPaste: {
                guard let string = NSPasteboard.general.string(forType: .string) else {
                    return false
                }
                return inputSink.typeText(string)
            },
            onFocusLost: {
                inputSink.releaseAllInput()
            }
        )
    }
}

/// SwiftUI view that renders VICE frames with Metal and can forward Mac input.
public struct MacVICEDisplayView: NSViewRepresentable {
    private let videoSource: any MacVICEVideoSource
    private let inputHandlers: MacVICEDisplayInputHandlers?
    private let configuration: MacVICEDisplayConfiguration

    /// Creates a display view backed by an arbitrary video source and optional input sink.
    public init(videoSource: any MacVICEVideoSource,
                inputSink: (any MacVICEInputSink)? = nil,
                configuration: MacVICEDisplayConfiguration = .interactive) {
        self.videoSource = videoSource
        self.inputHandlers = inputSink.map(MacVICEDisplayInputHandlers.inputSink)
        self.configuration = configuration
    }

    /// Creates a display view backed by an arbitrary video source and custom input handlers.
    public init(videoSource: any MacVICEVideoSource,
                inputHandlers: MacVICEDisplayInputHandlers?,
                configuration: MacVICEDisplayConfiguration = .interactive) {
        self.videoSource = videoSource
        self.inputHandlers = inputHandlers
        self.configuration = configuration
    }

    /// Creates a display view connected to a `MacVICEEngineSession`.
    public init(session: MacVICEEngineSession,
                configuration: MacVICEDisplayConfiguration = .interactive) {
        self.videoSource = session.videoSource
        self.inputHandlers = MacVICEDisplayInputHandlers.inputSink(session)
        self.configuration = configuration
    }

    /// Creates the Metal renderer coordinator.
    public func makeCoordinator() -> MacVICEMetalRenderer {
        MacVICEMetalRenderer(videoSource: videoSource,
                             configuration: configuration)
    }

    /// Creates the underlying Metal view.
    public func makeNSView(context: Context) -> MTKView {
        let view = MacVICEInputMetalView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.inputHandlers = inputHandlers
        view.configuration = configuration
        view.delegate = context.coordinator
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.018, green: 0.020, blue: 0.022, alpha: 1.0)
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.autoResizeDrawable = true
        view.framebufferOnly = true
        return view
    }

    /// Updates the underlying Metal view and renderer configuration.
    public func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.update(configuration: configuration)
        if let inputView = nsView as? MacVICEInputMetalView {
            inputView.inputHandlers = inputHandlers
            inputView.configuration = configuration
        }
    }
}

private final class MacVICEInputMetalView: MTKView {
    var inputHandlers: MacVICEDisplayInputHandlers?
    var configuration = MacVICEDisplayConfiguration()
    var isMouseInputActive: Bool {
        configuration.forwardsInput && configuration.capturesMouse
    }
    private var trackingArea: NSTrackingArea?
    private var keyEventMonitor: Any?
    private var isMouseInside = false
    private var isCursorHidden = false
    private var isMouseCaptured = false

    deinit {
        MainActor.assumeIsolated {
            removeKeyEventMonitor()
            setMouseCaptured(false)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        updateMouseCursorVisibility()
        return true
    }

    override func resignFirstResponder() -> Bool {
        inputHandlers?.onFocusLost()
        setMouseCaptured(false)
        return super.resignFirstResponder()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        installKeyEventMonitor()

        DispatchQueue.main.async { [weak self] in
            guard let self else {
                return
            }
            self.window?.makeFirstResponder(self)
            self.window?.acceptsMouseMovedEvents = true
            self.updateTrackingAreas()
            self.updateMouseCursorVisibility()
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            inputHandlers?.onFocusLost()
            removeKeyEventMonitor()
            setMouseCaptured(false)
        }
        super.viewWillMove(toWindow: newWindow)
    }

    override func updateTrackingAreas() {
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let options: NSTrackingArea.Options = [
            .activeInKeyWindow,
            .mouseMoved,
            .mouseEnteredAndExited,
            .inVisibleRect
        ]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self)
        addTrackingArea(area)
        trackingArea = area
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        updateMouseCursorVisibility()
        super.mouseEntered(with: event)
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        setMouseCaptured(false)
        super.mouseExited(with: event)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let wasCaptured = isMouseCaptured
        updateMouseCursorVisibility()
        guard wasCaptured || isMouseCaptured else {
            super.mouseDown(with: event)
            return
        }

        if wasCaptured && inputHandlers?.onMouseButton(0, true) == true {
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if isMouseCaptured && inputHandlers?.onMouseButton(0, false) == true {
            return
        }
        super.mouseUp(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let wasCaptured = isMouseCaptured
        updateMouseCursorVisibility()
        guard wasCaptured || isMouseCaptured else {
            super.rightMouseDown(with: event)
            return
        }

        if wasCaptured && inputHandlers?.onMouseButton(2, true) == true {
            return
        }
        super.rightMouseDown(with: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        if isMouseCaptured && inputHandlers?.onMouseButton(2, false) == true {
            return
        }
        super.rightMouseUp(with: event)
    }

    override func otherMouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let wasCaptured = isMouseCaptured
        updateMouseCursorVisibility()
        guard wasCaptured || isMouseCaptured else {
            super.otherMouseDown(with: event)
            return
        }

        if wasCaptured && inputHandlers?.onMouseButton(mappedOtherButton(for: event), true) == true {
            return
        }
        super.otherMouseDown(with: event)
    }

    override func otherMouseUp(with event: NSEvent) {
        if isMouseCaptured && inputHandlers?.onMouseButton(mappedOtherButton(for: event), false) == true {
            return
        }
        super.otherMouseUp(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        if handleMouseMotion(event) {
            return
        }
        super.mouseMoved(with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        if handleMouseMotion(event) {
            return
        }
        super.mouseDragged(with: event)
    }

    override func rightMouseDragged(with event: NSEvent) {
        if handleMouseMotion(event) {
            return
        }
        super.rightMouseDragged(with: event)
    }

    override func otherMouseDragged(with event: NSEvent) {
        if handleMouseMotion(event) {
            return
        }
        super.otherMouseDragged(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if configuration.forwardsInput,
           inputHandlers?.onKeyEvent(event, true) == true {
            return
        }

        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if configuration.forwardsInput,
           inputHandlers?.onKeyEvent(event, false) == true {
            return
        }

        super.keyUp(with: event)
    }

    override func flagsChanged(with event: NSEvent) {
        if configuration.forwardsInput,
           inputHandlers?.onFlagsChanged(event) == true {
            return
        }

        super.flagsChanged(with: event)
    }

    @objc func paste(_ sender: Any?) {
        if configuration.forwardsInput,
           inputHandlers?.onPaste() == true {
            return
        }

        NSSound.beep()
    }

    private func installKeyEventMonitor() {
        removeKeyEventMonitor()

        keyEventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            guard let self,
                  self.shouldHandleWindowEvent(event) else {
                return event
            }

            if self.handleWindowEvent(event) {
                return nil
            }

            return event
        }
    }

    private func removeKeyEventMonitor() {
        guard let keyEventMonitor else {
            return
        }

        NSEvent.removeMonitor(keyEventMonitor)
        self.keyEventMonitor = nil
    }

    private func shouldHandleWindowEvent(_ event: NSEvent) -> Bool {
        guard configuration.forwardsInput,
              let window,
              window.isKeyWindow,
              event.window === window,
              !isTextInputResponder(window.firstResponder) else {
            return false
        }

        return true
    }

    private func handleWindowEvent(_ event: NSEvent) -> Bool {
        switch event.type {
        case .keyDown:
            return inputHandlers?.onKeyEvent(event, true) == true
        case .keyUp:
            return inputHandlers?.onKeyEvent(event, false) == true
        case .flagsChanged:
            return inputHandlers?.onFlagsChanged(event) == true
        default:
            return false
        }
    }

    private func handleMouseMotion(_ event: NSEvent) -> Bool {
        guard isMouseCaptured else {
            return false
        }

        let deltaX = clampedMouseDelta(event.deltaX)
        let deltaY = clampedMouseDelta(event.deltaY)
        guard deltaX != 0 || deltaY != 0 else {
            return false
        }

        return inputHandlers?.onMouseMoved(deltaX, deltaY) == true
    }

    private func clampedMouseDelta(_ delta: CGFloat) -> CGFloat {
        min(63, max(-63, delta))
    }

    private func updateMouseCursorVisibility() {
        setMouseCaptured(isMouseInputActive && isMouseInside && window?.isKeyWindow == true)
    }

    private func setMouseCaptured(_ captured: Bool) {
        guard isMouseCaptured != captured else {
            return
        }

        isMouseCaptured = captured
        if captured {
            hideMouseCursorIfNeeded()
        } else {
            showMouseCursorIfNeeded()
        }
        inputHandlers?.onMouseCaptureChanged(captured)
    }

    private func hideMouseCursorIfNeeded() {
        guard !isCursorHidden else {
            return
        }

        NSCursor.hide()
        isCursorHidden = true
    }

    private func showMouseCursorIfNeeded() {
        guard isCursorHidden else {
            return
        }

        NSCursor.unhide()
        isCursorHidden = false
    }

    private func mappedOtherButton(for event: NSEvent) -> UInt32 {
        event.buttonNumber == 2 ? 1 : UInt32(max(0, min(event.buttonNumber, 4)))
    }

    private func isTextInputResponder(_ responder: Any?) -> Bool {
        guard let responder else {
            return false
        }

        if responder is NSTextView || responder is NSTextField {
            return true
        }

        guard let view = responder as? NSView else {
            return false
        }

        return view.ancestorIsTextInput
    }
}

private extension NSView {
    var ancestorIsTextInput: Bool {
        if self is NSTextView || self is NSTextField {
            return true
        }

        return superview?.ancestorIsTextInput ?? false
    }
}
