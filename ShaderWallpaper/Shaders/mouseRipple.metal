//
//  mouseRipple.metal
//  ShaderWallpaper
//

#include <metal_stdlib>
#include "common.metal"
using namespace metal;

fragment float4 mouseRippleShader(
    VertexOut in [[stage_in]],
    constant Uniforms& u [[buffer(0)]]
) {
    float2 R = max(u.resolution, float2(1.0));
    float2 C = in.texCoord * R;
    float2 mouse = u.mouse.xy;

    bool hasMouse = any(mouse > float2(0.0));
    mouse.y = R.y - mouse.y;
    mouse = hasMouse ? mouse : R * 0.5;

    float2 centered = (C - R * 0.5) / R.y;
    float2 fromMouse = (C - mouse) / R.y;

    float distanceFromMouse = length(fromMouse);
    float wave = sin(distanceFromMouse * 72.0 - u.time * 6.0);
    float ring = smoothstep(0.045, 0.0, abs(wave) * 0.035 + distanceFromMouse * 0.08);
    float glow = exp(-distanceFromMouse * 5.0);

    float grid = 0.04 / max(abs(sin(centered.x * 24.0) * sin(centered.y * 24.0)), 0.08);
    float3 background = float3(0.02, 0.025, 0.035) + float3(0.02, 0.05, 0.08) * grid;
    float3 rippleColor = 0.5 + 0.5 * cos(u.time + distanceFromMouse * 9.0 + float3(0.0, 2.0, 4.0));
    float3 color = background + rippleColor * ring + float3(0.25, 0.55, 1.0) * glow;

    return float4(color, 1.0);
}
