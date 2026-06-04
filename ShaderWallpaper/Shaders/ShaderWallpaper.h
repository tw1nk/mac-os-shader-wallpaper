#ifndef SHADER_WALLPAPER_H
#define SHADER_WALLPAPER_H

#include <metal_stdlib>

struct ShaderWallpaperUniforms {
    float time;
    metal::float2 resolution;
    metal::float4 mouse;
};

struct ShaderWallpaperVertexOut {
    metal::float4 position [[position]];
    metal::float2 texCoord;
};

#endif
