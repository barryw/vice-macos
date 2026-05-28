import MetalKit
import SwiftUI

struct EmulatorMetalView: NSViewRepresentable {
    let frameSource: EmulatorFrameSource
    let filterSettings: VideoFilterSettings
    let preservesAspectRatio: Bool
    let isMouseInputActive: Bool
    let onKeyEvent: (NSEvent, Bool) -> Bool
    let onFlagsChanged: (NSEvent) -> Bool
    let onMouseMoved: (CGFloat, CGFloat) -> Bool
    let onMouseButton: (UInt32, Bool) -> Bool
    let onMouseCaptureChanged: (Bool) -> Void
    let onPaste: () -> Bool
    let onFocusLost: () -> Void

    func makeCoordinator() -> EmulatorRenderer {
        EmulatorRenderer(frameSource: frameSource,
                         filterSettings: filterSettings,
                         preservesAspectRatio: preservesAspectRatio)
    }

    func makeNSView(context: Context) -> MTKView {
        let view = EmulatorInputMetalView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.onKeyEvent = onKeyEvent
        view.onFlagsChanged = onFlagsChanged
        view.isMouseInputActive = isMouseInputActive
        view.onMouseMoved = onMouseMoved
        view.onMouseButton = onMouseButton
        view.onMouseCaptureChanged = onMouseCaptureChanged
        view.onPaste = onPaste
        view.onFocusLost = onFocusLost
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

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.update(filterSettings: filterSettings,
                                   preservesAspectRatio: preservesAspectRatio)
        if let inputView = nsView as? EmulatorInputMetalView {
            inputView.onKeyEvent = onKeyEvent
            inputView.onFlagsChanged = onFlagsChanged
            inputView.isMouseInputActive = isMouseInputActive
            inputView.onMouseMoved = onMouseMoved
            inputView.onMouseButton = onMouseButton
            inputView.onMouseCaptureChanged = onMouseCaptureChanged
            inputView.onPaste = onPaste
            inputView.onFocusLost = onFocusLost
        }
    }
}

private final class EmulatorInputMetalView: MTKView {
    var onKeyEvent: ((NSEvent, Bool) -> Bool)?
    var onFlagsChanged: ((NSEvent) -> Bool)?
    var isMouseInputActive = false {
        didSet {
            guard isMouseInputActive != oldValue else {
                return
            }
            updateMouseCursorVisibility()
        }
    }
    var onMouseMoved: ((CGFloat, CGFloat) -> Bool)?
    var onMouseButton: ((UInt32, Bool) -> Bool)?
    var onMouseCaptureChanged: ((Bool) -> Void)?
    var onPaste: (() -> Bool)?
    var onFocusLost: (() -> Void)?
    private var keyEventMonitor: Any?
    private var mouseTrackingArea: NSTrackingArea?
    private var isMouseInside = false
    private var isCursorHidden = false
    private var isMouseCaptured = false

    deinit {
        MainActor.assumeIsolated {
            removeKeyEventMonitor()
            setMouseCaptured(false)
        }
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func becomeFirstResponder() -> Bool {
        updateMouseCursorVisibility()
        return true
    }

    override func resignFirstResponder() -> Bool {
        onFocusLost?()
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
            self.updateMouseTrackingArea()
            self.updateMouseCursorVisibility()
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            onFocusLost?()
            removeKeyEventMonitor()
            setMouseCaptured(false)
        }
        super.viewWillMove(toWindow: newWindow)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        updateMouseTrackingArea()
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

        if wasCaptured && onMouseButton?(0, true) == true {
            return
        }
        super.mouseDown(with: event)
    }

    override func mouseUp(with event: NSEvent) {
        if isMouseCaptured && onMouseButton?(0, false) == true {
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

        if wasCaptured && onMouseButton?(2, true) == true {
            return
        }
        super.rightMouseDown(with: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        if isMouseCaptured && onMouseButton?(2, false) == true {
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

        if wasCaptured && onMouseButton?(mappedOtherButton(for: event), true) == true {
            return
        }
        super.otherMouseDown(with: event)
    }

    override func otherMouseUp(with event: NSEvent) {
        if isMouseCaptured && onMouseButton?(mappedOtherButton(for: event), false) == true {
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
        if onKeyEvent?(event, true) == true {
            return
        }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if onKeyEvent?(event, false) == true {
            return
        }
        super.keyUp(with: event)
    }

    override func flagsChanged(with event: NSEvent) {
        if onFlagsChanged?(event) == true {
            return
        }
        super.flagsChanged(with: event)
    }

    @objc func paste(_ sender: Any?) {
        if onPaste?() != true {
            NSSound.beep()
        }
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
        guard let window,
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
            return onKeyEvent?(event, true) == true
        case .keyUp:
            return onKeyEvent?(event, false) == true
        case .flagsChanged:
            return onFlagsChanged?(event) == true
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

        return onMouseMoved?(deltaX, deltaY) == true
    }

    private func clampedMouseDelta(_ delta: CGFloat) -> CGFloat {
        min(63, max(-63, delta))
    }

    private func updateMouseTrackingArea() {
        if let mouseTrackingArea {
            removeTrackingArea(mouseTrackingArea)
        }

        let area = NSTrackingArea(rect: .zero,
                                  options: [.activeInKeyWindow,
                                            .inVisibleRect,
                                            .mouseEnteredAndExited],
                                  owner: self,
                                  userInfo: nil)
        addTrackingArea(area)
        mouseTrackingArea = area
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
        onMouseCaptureChanged?(captured)
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
