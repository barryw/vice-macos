import MetalKit
import SwiftUI

struct EmulatorMetalView: NSViewRepresentable {
    let frameSource: EmulatorFrameSource
    let filterSettings: VideoFilterSettings
    let preservesAspectRatio: Bool
    let onKeyEvent: (NSEvent, Bool) -> Bool
    let onFlagsChanged: (NSEvent) -> Bool
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
            inputView.onPaste = onPaste
            inputView.onFocusLost = onFocusLost
        }
    }
}

private final class EmulatorInputMetalView: MTKView {
    var onKeyEvent: ((NSEvent, Bool) -> Bool)?
    var onFlagsChanged: ((NSEvent) -> Bool)?
    var onPaste: (() -> Bool)?
    var onFocusLost: (() -> Void)?
    private var keyEventMonitor: Any?

    deinit {
        MainActor.assumeIsolated {
            removeKeyEventMonitor()
        }
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func becomeFirstResponder() -> Bool {
        true
    }

    override func resignFirstResponder() -> Bool {
        onFocusLost?()
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
        }
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil {
            onFocusLost?()
            removeKeyEventMonitor()
        }
        super.viewWillMove(toWindow: newWindow)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
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
