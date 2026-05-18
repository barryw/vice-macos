import MetalKit

final class EmulatorRenderer: NSObject, MTKViewDelegate {
    private var commandQueue: MTLCommandQueue?

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        ensureCommandQueue(for: view)
    }

    func draw(in view: MTKView) {
        ensureCommandQueue(for: view)

        guard let commandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable else {
            return
        }

        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        encoder?.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func ensureCommandQueue(for view: MTKView) {
        if commandQueue == nil {
            commandQueue = view.device?.makeCommandQueue()
        }
    }
}
