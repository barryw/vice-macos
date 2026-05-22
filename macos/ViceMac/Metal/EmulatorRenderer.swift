import MetalKit
import QuartzCore

@MainActor
final class EmulatorRenderer: NSObject, MTKViewDelegate {
    private struct Vertex {
        let position: SIMD2<Float>
        let textureCoordinate: SIMD2<Float>
    }

    private struct FilterUniforms {
        let sourceAndRenderSize: SIMD4<Float>
        let controlsA: SIMD4<Float>
        let controlsB: SIMD4<Float>
        let controlsC: SIMD4<Float>
    }

    private struct PersistenceUniforms {
        let controls: SIMD4<Float>
    }

    private static let fullscreenVertices = [
        Vertex(position: SIMD2(-1.0, -1.0), textureCoordinate: SIMD2(0.0, 1.0)),
        Vertex(position: SIMD2(1.0, -1.0), textureCoordinate: SIMD2(1.0, 1.0)),
        Vertex(position: SIMD2(-1.0, 1.0), textureCoordinate: SIMD2(0.0, 0.0)),
        Vertex(position: SIMD2(1.0, 1.0), textureCoordinate: SIMD2(1.0, 0.0))
    ]

    private let frameSource: EmulatorFrameSource
    private var commandQueue: MTLCommandQueue?
    private var shaderLibrary: MTLLibrary?
    private var sourcePipelineState: MTLRenderPipelineState?
    private var filterPipelineState: MTLRenderPipelineState?
    private var persistencePipelineState: MTLRenderPipelineState?
    private var presentPipelineState: MTLRenderPipelineState?
    private var nearestSamplerState: MTLSamplerState?
    private var linearSamplerState: MTLSamplerState?
    private var frameTexture: MTLTexture?
    private var frameTextureSize = CGSize.zero
    private var lastFrameSequence: UInt64 = 0
    private var sourceStageTexture: MTLTexture?
    private var filterStageTexture: MTLTexture?
    private var persistenceStageTextures: [MTLTexture] = []
    private var stageTextureSize = CGSize.zero
    private var persistenceTextureSize = CGSize.zero
    private var currentPersistenceTextureIndex = 0
    private var persistenceHistoryValid = false
    private var lastPersistenceTimestamp: CFTimeInterval?
    private var filterSettings: VideoFilterSettings
    private var preservesAspectRatio: Bool

    init(frameSource: EmulatorFrameSource,
         filterSettings: VideoFilterSettings,
         preservesAspectRatio: Bool) {
        self.frameSource = frameSource
        self.filterSettings = filterSettings
        self.preservesAspectRatio = preservesAspectRatio
        super.init()
    }

    func update(filterSettings: VideoFilterSettings,
                preservesAspectRatio: Bool) {
        if filterSettings.preset != self.filterSettings.preset ||
            self.filterSettings.phosphorPersistence <= 0 && filterSettings.phosphorPersistence > 0 ||
            filterSettings.phosphorPersistence <= 0 {
            resetPersistenceHistory()
        }

        self.filterSettings = filterSettings
        self.preservesAspectRatio = preservesAspectRatio
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        ensureMetalState(for: view)
    }

    func draw(in view: MTKView) {
        ensureMetalState(for: view)

        guard let commandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let sourceStageTexture,
              let filterStageTexture,
              let descriptor = view.currentRenderPassDescriptor,
              let drawable = view.currentDrawable,
              let sourcePipelineState,
              let filterPipelineState,
              let presentPipelineState,
              let frameTexture,
              let nearestSamplerState,
              let linearSamplerState else {
            return
        }

        let fullscreenVertices = Self.fullscreenVertices
        let sourceVertices = preservesAspectRatio
            ? makeVertices(drawableSize: view.drawableSize,
                           presentationSize: frameSource.presentationSize(for: frameTextureSize))
            : fullscreenVertices
        guard sourceVertices.count == 4, fullscreenVertices.count == 4 else {
            return
        }

        if let sourcePass = commandBuffer.makeRenderCommandEncoder(
            descriptor: makeRenderPassDescriptor(texture: sourceStageTexture)
        ) {
            sourcePass.setRenderPipelineState(sourcePipelineState)
            encode(vertices: sourceVertices, into: sourcePass)
            sourcePass.setFragmentTexture(frameTexture, index: 0)
            sourcePass.setFragmentSamplerState(nearestSamplerState, index: 0)
            sourcePass.drawPrimitives(type: .triangleStrip,
                                      vertexStart: 0,
                                      vertexCount: sourceVertices.count)
            sourcePass.endEncoding()
        }

        if let filterPass = commandBuffer.makeRenderCommandEncoder(
            descriptor: makeRenderPassDescriptor(texture: filterStageTexture)
        ) {
            var uniforms = makeFilterUniforms(renderSize: view.drawableSize)

            filterPass.setRenderPipelineState(filterPipelineState)
            encode(vertices: fullscreenVertices, into: filterPass)
            filterPass.setFragmentTexture(sourceStageTexture, index: 0)
            filterPass.setFragmentSamplerState(linearSamplerState, index: 0)
            filterPass.setFragmentBytes(&uniforms,
                                        length: MemoryLayout<FilterUniforms>.stride,
                                        index: 0)
            filterPass.drawPrimitives(type: .triangleStrip,
                                      vertexStart: 0,
                                      vertexCount: fullscreenVertices.count)
            filterPass.endEncoding()
        }

        let outputTexture = renderPersistencePass(commandBuffer: commandBuffer,
                                                  currentTexture: filterStageTexture,
                                                  vertices: fullscreenVertices,
                                                  sampler: linearSamplerState) ?? filterStageTexture

        if let presentPass = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) {
            presentPass.setRenderPipelineState(presentPipelineState)
            encode(vertices: fullscreenVertices, into: presentPass)
            presentPass.setFragmentTexture(outputTexture, index: 0)
            presentPass.setFragmentSamplerState(linearSamplerState, index: 0)
            presentPass.drawPrimitives(type: .triangleStrip,
                                       vertexStart: 0,
                                       vertexCount: fullscreenVertices.count)
            presentPass.endEncoding()
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func ensureMetalState(for view: MTKView) {
        guard let device = view.device else {
            return
        }

        if commandQueue == nil {
            commandQueue = device.makeCommandQueue()
        }

        if shaderLibrary == nil {
            shaderLibrary = makeShaderLibrary(device: device)
        }

        guard let shaderLibrary else {
            return
        }

        if sourcePipelineState == nil {
            sourcePipelineState = makePipelineState(device: device,
                                                    library: shaderLibrary,
                                                    pixelFormat: .bgra8Unorm,
                                                    fragmentName: "sourceFragment")
        }

        if filterPipelineState == nil {
            filterPipelineState = makePipelineState(device: device,
                                                    library: shaderLibrary,
                                                    pixelFormat: .bgra8Unorm,
                                                    fragmentName: "filterFragment")
        }

        if persistencePipelineState == nil {
            persistencePipelineState = makePipelineState(device: device,
                                                        library: shaderLibrary,
                                                        pixelFormat: .bgra8Unorm,
                                                        fragmentName: "persistenceFragment")
        }

        if presentPipelineState == nil {
            presentPipelineState = makePipelineState(device: device,
                                                     library: shaderLibrary,
                                                     pixelFormat: view.colorPixelFormat,
                                                     fragmentName: "sourceFragment")
        }

        if nearestSamplerState == nil {
            nearestSamplerState = makeSamplerState(device: device, filter: .nearest)
        }

        if linearSamplerState == nil {
            linearSamplerState = makeSamplerState(device: device, filter: .linear)
        }

        updateFrameTexture(device: device)

        ensureStageTextures(device: device, drawableSize: view.drawableSize)
    }

    private func makeShaderLibrary(device: MTLDevice) -> MTLLibrary? {
        device.makeDefaultLibrary()
    }

    private func makePipelineState(device: MTLDevice,
                                   library: MTLLibrary,
                                   pixelFormat: MTLPixelFormat,
                                   fragmentName: String) -> MTLRenderPipelineState? {
        guard let vertexFunction = library.makeFunction(name: "emulatorVertex"),
              let fragmentFunction = library.makeFunction(name: fragmentName) else {
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        return try? device.makeRenderPipelineState(descriptor: descriptor)
    }

    private func makeSamplerState(device: MTLDevice, filter: MTLSamplerMinMagFilter) -> MTLSamplerState? {
        let descriptor = MTLSamplerDescriptor()
        descriptor.minFilter = filter
        descriptor.magFilter = filter
        descriptor.mipFilter = .notMipmapped
        descriptor.sAddressMode = .clampToEdge
        descriptor.tAddressMode = .clampToEdge
        return device.makeSamplerState(descriptor: descriptor)
    }

    private func ensureStageTextures(device: MTLDevice, drawableSize: CGSize) {
        guard drawableSize.width > 0, drawableSize.height > 0 else {
            return
        }

        let targetSize = CGSize(width: Int(drawableSize.width), height: Int(drawableSize.height))
        let needsStageTextures = targetSize != stageTextureSize ||
            sourceStageTexture == nil ||
            filterStageTexture == nil ||
            persistenceStageTextures.count != 2 ||
            persistenceTextureSize != targetSize
        guard needsStageTextures else {
            return
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            mipmapped: false
        )
        descriptor.storageMode = .private
        descriptor.usage = [.renderTarget, .shaderRead]

        sourceStageTexture = device.makeTexture(descriptor: descriptor)
        filterStageTexture = device.makeTexture(descriptor: descriptor)
        persistenceStageTextures = [
            device.makeTexture(descriptor: descriptor),
            device.makeTexture(descriptor: descriptor)
        ].compactMap { $0 }
        stageTextureSize = targetSize
        persistenceTextureSize = targetSize
        currentPersistenceTextureIndex = 0
        resetPersistenceHistory()
    }

    private func makeRenderPassDescriptor(texture: MTLTexture) -> MTLRenderPassDescriptor {
        let descriptor = MTLRenderPassDescriptor()
        descriptor.colorAttachments[0].texture = texture
        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0,
                                                                   green: 0.0,
                                                                   blue: 0.0,
                                                                   alpha: 1.0)
        return descriptor
    }

    private func encode(vertices: [Vertex], into encoder: MTLRenderCommandEncoder) {
        vertices.withUnsafeBytes { vertexBytes in
            guard let baseAddress = vertexBytes.baseAddress else {
                return
            }

            encoder.setVertexBytes(baseAddress, length: vertexBytes.count, index: 0)
        }
    }

    private func renderPersistencePass(commandBuffer: MTLCommandBuffer,
                                       currentTexture: MTLTexture,
                                       vertices: [Vertex],
                                       sampler: MTLSamplerState) -> MTLTexture? {
        guard filterSettings.phosphorPersistence > 0,
              let persistencePipelineState,
              persistenceStageTextures.count == 2 else {
            return nil
        }

        let now = CACurrentMediaTime()
        let frameDelta = lastPersistenceTimestamp.map {
            min(max(now - $0, 1.0 / 240.0), 0.25)
        } ?? (1.0 / 60.0)
        lastPersistenceTimestamp = now

        let writeIndex = 1 - currentPersistenceTextureIndex
        let readTexture = persistenceHistoryValid
            ? persistenceStageTextures[currentPersistenceTextureIndex]
            : currentTexture
        let writeTexture = persistenceStageTextures[writeIndex]

        guard let persistencePass = commandBuffer.makeRenderCommandEncoder(
            descriptor: makeRenderPassDescriptor(texture: writeTexture)
        ) else {
            return nil
        }

        var uniforms = PersistenceUniforms(
            controls: SIMD4(Float(filterSettings.phosphorPersistence),
                            Float(frameDelta),
                            persistenceHistoryValid ? 1.0 : 0.0,
                            0.0)
        )

        persistencePass.setRenderPipelineState(persistencePipelineState)
        encode(vertices: vertices, into: persistencePass)
        persistencePass.setFragmentTexture(currentTexture, index: 0)
        persistencePass.setFragmentTexture(readTexture, index: 1)
        persistencePass.setFragmentSamplerState(sampler, index: 0)
        persistencePass.setFragmentBytes(&uniforms,
                                         length: MemoryLayout<PersistenceUniforms>.stride,
                                         index: 0)
        persistencePass.drawPrimitives(type: .triangleStrip,
                                       vertexStart: 0,
                                       vertexCount: vertices.count)
        persistencePass.endEncoding()

        persistenceHistoryValid = true
        currentPersistenceTextureIndex = writeIndex

        return writeTexture
    }

    private func resetPersistenceHistory() {
        persistenceHistoryValid = false
        lastPersistenceTimestamp = nil
    }

    private func makeFrameTexture(device: MTLDevice) -> MTLTexture? {
        guard let url = Bundle.main.url(forResource: frameSource.resourceName,
                                        withExtension: frameSource.fileExtension) else {
            return nil
        }

        let loader = MTKTextureLoader(device: device)
        let texture = try? loader.newTexture(URL: url, options: [
            .SRGB: false,
            .textureUsage: NSNumber(value: MTLTextureUsage.shaderRead.rawValue),
            .textureStorageMode: NSNumber(value: MTLStorageMode.private.rawValue)
        ])
        if let texture {
            frameTextureSize = CGSize(width: texture.width, height: texture.height)
        }
        return texture
    }

    private func updateFrameTexture(device: MTLDevice) {
        if let frame = frameSource.copyLatestFrame(after: lastFrameSequence) {
            upload(frame: frame, device: device)
            return
        }

        if frameTexture == nil {
            frameTexture = makeFrameTexture(device: device)
        }
    }

    private func upload(frame: EmulatorVideoFrame, device: MTLDevice) {
        guard frame.width > 0,
              frame.height > 0,
              frame.bytesPerRow >= frame.width * 4,
              frame.pixels.count >= frame.bytesPerRow * frame.height else {
            return
        }

        if frameTexture == nil ||
            frameTexture?.width != frame.width ||
            frameTexture?.height != frame.height ||
            frameTexture?.pixelFormat != .rgba8Unorm {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm,
                                                                      width: frame.width,
                                                                      height: frame.height,
                                                                      mipmapped: false)
            descriptor.storageMode = .shared
            descriptor.usage = .shaderRead
            frameTexture = device.makeTexture(descriptor: descriptor)
        }

        guard let frameTexture else {
            return
        }

        let region = MTLRegionMake2D(0, 0, frame.width, frame.height)
        frame.pixels.withUnsafeBytes { pixelBytes in
            guard let baseAddress = pixelBytes.baseAddress else {
                return
            }

            frameTexture.replace(region: region,
                                 mipmapLevel: 0,
                                 withBytes: baseAddress,
                                 bytesPerRow: frame.bytesPerRow)
        }

        frameTextureSize = CGSize(width: frame.width, height: frame.height)
        lastFrameSequence = frame.sequence
    }

    private func makeVertices(drawableSize: CGSize, presentationSize: CGSize) -> [Vertex] {
        guard drawableSize.width > 0,
              drawableSize.height > 0,
              presentationSize.width > 0,
              presentationSize.height > 0 else {
            return []
        }

        let drawableAspect = Float(drawableSize.width / drawableSize.height)
        let textureAspect = Float(presentationSize.width / presentationSize.height)
        let xScale: Float
        let yScale: Float

        if drawableAspect > textureAspect {
            xScale = textureAspect / drawableAspect
            yScale = 1.0
        } else {
            xScale = 1.0
            yScale = drawableAspect / textureAspect
        }

        return [
            Vertex(position: SIMD2(-xScale, -yScale), textureCoordinate: SIMD2(0.0, 1.0)),
            Vertex(position: SIMD2(xScale, -yScale), textureCoordinate: SIMD2(1.0, 1.0)),
            Vertex(position: SIMD2(-xScale, yScale), textureCoordinate: SIMD2(0.0, 0.0)),
            Vertex(position: SIMD2(xScale, yScale), textureCoordinate: SIMD2(1.0, 0.0))
        ]
    }

    private func makeFilterUniforms(renderSize: CGSize) -> FilterUniforms {
        let sourceSize = frameTextureSize == .zero ? frameSource.pixelSize : frameTextureSize

        return FilterUniforms(
            sourceAndRenderSize: SIMD4(Float(sourceSize.width),
                                       Float(sourceSize.height),
                                       Float(renderSize.width),
                                       Float(renderSize.height)),
            controlsA: SIMD4(Float(filterSettings.scanlineIntensity),
                             Float(filterSettings.phosphorMaskIntensity),
                             Float(filterSettings.barrelDistortion),
                             Float(filterSettings.vignette)),
            controlsB: SIMD4(Float(filterSettings.halation),
                             Float(filterSettings.saturation),
                             Float(filterSettings.warmth),
                             Float(filterSettings.monochromeAmount)),
            controlsC: SIMD4(Float(filterSettings.phosphorTintRed),
                             Float(filterSettings.phosphorTintGreen),
                             Float(filterSettings.phosphorTintBlue),
                             0.0)
        )
    }

}
