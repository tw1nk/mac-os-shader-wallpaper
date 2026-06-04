//
//  desktopWarp.metal
//  ShaderWallpaper
//

#include <metal_stdlib>
#include "common.metal"
using namespace metal;

fragment float4 desktopWarpShader(
    ShaderWallpaperVertexOut in [[stage_in]],
    constant ShaderWallpaperUniforms& u [[buffer(0)]],
    texture2d<float> desktopTexture [[texture(0)]]
) {
    constexpr sampler desktopSampler(address::clamp_to_edge, filter::linear);

    float2 R = max(u.resolution, float2(1.0));
    float2 uv = in.texCoord;
    float2 mouse = u.mouse.xy;

    bool hasMouse = any(mouse > float2(0.0));
    mouse = hasMouse ? mouse : R * 0.5;

    float2 mouseUV = mouse / R;
    float2 fromMouse = uv - mouseUV;
    fromMouse.x *= R.x / R.y;

    float distanceFromMouse = length(fromMouse);
    float wave = sin(distanceFromMouse * 48.0 - u.time * 5.0);
    float strength = exp(-distanceFromMouse * 7.0);

    float2 direction = normalize(fromMouse + 0.0001);
    direction.x /= R.x / R.y;
    float2 warpedUV = uv + direction * wave * strength * 0.035;

    float3 desktop = desktopTexture.sample(desktopSampler, warpedUV).rgb;
    float highlight = smoothstep(0.02, 0.0, abs(wave) * 0.025 + distanceFromMouse * 0.04) * strength;
    float vignette = smoothstep(0.85, 0.2, length((uv - 0.5) * float2(R.x / R.y, 1.0)));

    float3 color = desktop * (0.75 + vignette * 0.35);
    color += float3(0.2, 0.55, 1.0) * highlight;

    return float4(color, 1.0);
}
