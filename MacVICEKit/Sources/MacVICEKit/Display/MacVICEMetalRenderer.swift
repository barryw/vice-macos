import CoreGraphics
import MetalKit
import QuartzCore

/// Metal renderer used by `MacVICEDisplayView`.
///
/// Most apps should embed `MacVICEDisplayView` instead of creating this class
/// directly. The renderer is public because SwiftUI exposes coordinator types
/// through `NSViewRepresentable`.
@MainActor
public final class MacVICEMetalRenderer: NSObject, MTKViewDelegate {
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

    private let videoSource: any MacVICEVideoSource
    private var configuration: MacVICEDisplayConfiguration
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

    init(videoSource: any MacVICEVideoSource,
         configuration: MacVICEDisplayConfiguration) {
        self.videoSource = videoSource
        self.configuration = configuration
        super.init()
    }

    func update(configuration: MacVICEDisplayConfiguration) {
        if configuration.filterSettings.preset != self.configuration.filterSettings.preset ||
            self.configuration.filterSettings.phosphorPersistence <= 0 && configuration.filterSettings.phosphorPersistence > 0 ||
            configuration.filterSettings.phosphorPersistence <= 0 {
            resetPersistenceHistory()
        }

        self.configuration = configuration
    }

    /// Handles drawable-size changes from MetalKit.
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        ensureMetalState(for: view)
    }

    /// Draws the latest VICE frame into the Metal view.
    public func draw(in view: MTKView) {
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
              let sourceSamplerState,
              let linearSamplerState else {
            return
        }

        let fullscreenVertices = Self.fullscreenVertices
        let sourceVertices = configuration.preservesAspectRatio
            ? makeVertices(drawableSize: view.drawableSize,
                           presentationSize: videoSource.presentationSize(for: frameTextureSize))
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
            sourcePass.setFragmentSamplerState(sourceSamplerState, index: 0)
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

    private var sourceSamplerState: MTLSamplerState? {
        switch configuration.filtering {
        case .nearest:
            return nearestSamplerState
        case .linear:
            return linearSamplerState
        }
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
        try? device.makeLibrary(source: Self.shaderSource, options: nil)
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
        guard configuration.filterSettings.phosphorPersistence > 0,
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
            controls: SIMD4(Float(configuration.filterSettings.phosphorPersistence),
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

    private func makeBootTexture(device: MTLDevice) -> MTLTexture? {
        guard let bootImageURL = configuration.bootImageURL else {
            return nil
        }

        let loader = MTKTextureLoader(device: device)
        let texture = try? loader.newTexture(URL: bootImageURL, options: [
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
        if let frame = videoSource.copyLatestFrame(after: lastFrameSequence) {
            upload(frame: frame, device: device)
            return
        }

        if frameTexture == nil {
            frameTexture = makeBootTexture(device: device)
        }
    }

    private func upload(frame: MacVICEVideoFrame, device: MTLDevice) {
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
            resetPersistenceHistory()
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
        let sourceSize = frameTextureSize == .zero ? CGSize(width: 1, height: 1) : frameTextureSize
        let settings = configuration.filterSettings

        return FilterUniforms(
            sourceAndRenderSize: SIMD4(Float(sourceSize.width),
                                       Float(sourceSize.height),
                                       Float(renderSize.width),
                                       Float(renderSize.height)),
            controlsA: SIMD4(Float(settings.scanlineIntensity),
                             Float(settings.phosphorMaskIntensity),
                             Float(settings.barrelDistortion),
                             Float(settings.vignette)),
            controlsB: SIMD4(Float(settings.halation),
                             Float(settings.saturation),
                             Float(settings.warmth),
                             Float(settings.monochromeAmount)),
            controlsC: SIMD4(Float(settings.phosphorTintRed),
                             Float(settings.phosphorTintGreen),
                             Float(settings.phosphorTintBlue),
                             0.0)
        )
    }

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct EmulatorVertex {
        float2 position;
        float2 textureCoordinate;
    };

    struct EmulatorRasterVertex {
        float4 position [[position]];
        float2 textureCoordinate;
    };

    struct FilterUniforms {
        float4 sourceAndRenderSize;
        float4 controlsA;
        float4 controlsB;
        float4 controlsC;
    };

    struct PersistenceUniforms {
        float4 controls;
    };

    vertex EmulatorRasterVertex emulatorVertex(
        uint vertexID [[vertex_id]],
        constant EmulatorVertex *vertices [[buffer(0)]]
    ) {
        EmulatorVertex rasterVertex = vertices[vertexID];

        EmulatorRasterVertex out;
        out.position = float4(rasterVertex.position, 0.0, 1.0);
        out.textureCoordinate = rasterVertex.textureCoordinate;
        return out;
    }

    fragment float4 sourceFragment(
        EmulatorRasterVertex in [[stage_in]],
        texture2d<float> frameTexture [[texture(0)]],
        sampler frameSampler [[sampler(0)]]
    ) {
        return frameTexture.sample(frameSampler, in.textureCoordinate);
    }

    float3 applySaturation(float3 color, float saturation) {
        float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
        return mix(float3(luma), color, saturation);
    }

    float3 applyPhosphorMask(float3 color, float pixelX, float intensity) {
        float triad = fmod(floor(pixelX), 3.0);
        float3 mask = float3(1.0 - intensity * 0.34);

        if (triad < 1.0) {
            mask.r = 1.0 + intensity * 0.18;
        } else if (triad < 2.0) {
            mask.g = 1.0 + intensity * 0.18;
        } else {
            mask.b = 1.0 + intensity * 0.18;
        }

        return color * mask;
    }

    fragment float4 filterFragment(
        EmulatorRasterVertex in [[stage_in]],
        texture2d<float> sourceTexture [[texture(0)]],
        sampler sourceSampler [[sampler(0)]],
        constant FilterUniforms &uniforms [[buffer(0)]]
    ) {
        float2 sourceSize = max(uniforms.sourceAndRenderSize.xy, float2(1.0));
        float2 renderSize = max(uniforms.sourceAndRenderSize.zw, float2(1.0));
        float scanlineIntensity = uniforms.controlsA.x;
        float maskIntensity = uniforms.controlsA.y;
        float barrelDistortion = uniforms.controlsA.z;
        float vignetteIntensity = uniforms.controlsA.w;
        float halation = uniforms.controlsB.x;
        float saturation = uniforms.controlsB.y;
        float warmth = uniforms.controlsB.z;
        float monochromeAmount = uniforms.controlsB.w;
        float3 phosphorTint = uniforms.controlsC.rgb;

        float2 centered = in.textureCoordinate - 0.5;
        float radiusSquared = dot(centered, centered);
        float2 warped = 0.5 + centered * (1.0 + barrelDistortion * radiusSquared * 3.0);

        if (warped.x < 0.0 || warped.x > 1.0 || warped.y < 0.0 || warped.y > 1.0) {
            return float4(0.0, 0.0, 0.0, 1.0);
        }

        float4 sampled = sourceTexture.sample(sourceSampler, warped);
        float3 color = sampled.rgb;

        float2 texel = 1.0 / renderSize;
        float3 glow = sourceTexture.sample(sourceSampler, warped + float2(texel.x * 2.0, 0.0)).rgb;
        glow += sourceTexture.sample(sourceSampler, warped - float2(texel.x * 2.0, 0.0)).rgb;
        glow += sourceTexture.sample(sourceSampler, warped + float2(0.0, texel.y * 2.0)).rgb;
        glow += sourceTexture.sample(sourceSampler, warped - float2(0.0, texel.y * 2.0)).rgb;
        color += glow * (halation * 0.1125);

        float scanWave = 0.5 + 0.5 * cos(warped.y * sourceSize.y * 6.2831853);
        color *= 1.0 - scanlineIntensity * scanWave;

        color = applyPhosphorMask(color, warped.x * renderSize.x, maskIntensity);
        color = applySaturation(color, saturation);
        color.r += warmth * 0.08;
        color.b -= warmth * 0.06;

        float luma = dot(color, float3(0.2126, 0.7152, 0.0722));
        color = mix(color, float3(luma) * phosphorTint, monochromeAmount);

        float vignette = smoothstep(0.82, 0.28, length(centered));
        color *= mix(1.0 - vignetteIntensity, 1.0, vignette);

        return float4(clamp(color, 0.0, 1.0), sampled.a);
    }

    fragment float4 persistenceFragment(
        EmulatorRasterVertex in [[stage_in]],
        texture2d<float> currentTexture [[texture(0)]],
        texture2d<float> previousTexture [[texture(1)]],
        sampler textureSampler [[sampler(0)]],
        constant PersistenceUniforms &uniforms [[buffer(0)]]
    ) {
        float persistence = clamp(uniforms.controls.x, 0.0, 1.0);
        float deltaTime = clamp(uniforms.controls.y, 1.0 / 240.0, 0.25);

        float4 current = currentTexture.sample(textureSampler, in.textureCoordinate);
        if (persistence <= 0.0) {
            return current;
        }

        float4 previous = previousTexture.sample(textureSampler, in.textureCoordinate);
        float halfLife = mix(0.035, 1.70, persistence * persistence);
        float decay = exp2(-deltaTime / halfLife);
        float3 persisted = previous.rgb * decay;
        float3 color = max(current.rgb, persisted);

        return float4(clamp(color, 0.0, 1.0), current.a);
    }
    """
}
