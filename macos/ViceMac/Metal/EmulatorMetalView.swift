import MetalKit
import SwiftUI

struct EmulatorMetalView: NSViewRepresentable {
    func makeCoordinator() -> EmulatorRenderer {
        EmulatorRenderer()
    }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0.018, green: 0.020, blue: 0.022, alpha: 1.0)
        view.preferredFramesPerSecond = 60
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        view.autoResizeDrawable = true
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
    }
}
