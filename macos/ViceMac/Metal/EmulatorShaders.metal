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

    float vignette = smoothstep(0.82, 0.28, length(centered));
    color *= mix(1.0 - vignetteIntensity, 1.0, vignette);

    return float4(clamp(color, 0.0, 1.0), sampled.a);
}
