#include <metal_stdlib>
#include "common.metal"
using namespace metal;

fragment float4 errorShader(ShaderWallpaperVertexOut in [[stage_in]], constant ShaderWallpaperUniforms& u [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float2 grid = floor(uv * 16.0);
    float checker = fmod(grid.x + grid.y, 2.0);
    float pulse = 0.5 + 0.5 * sin(u.time * 4.0);
    float3 a = float3(0.65 + 0.25 * pulse, 0.02, 0.12);
    float3 b = float3(0.05, 0.0, 0.02);
    return float4(mix(a, b, checker), 1.0);
}
