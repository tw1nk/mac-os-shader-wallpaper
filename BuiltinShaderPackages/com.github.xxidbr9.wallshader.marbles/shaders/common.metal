//
//  common.metal
//  ShaderWallpaper
//
//  Created by Barnando Akbarto on 17/04/26.
//

#include <metal_stdlib>
#include "ShaderWallpaper.h"
using namespace metal;


// =====================
// Shared shader support
// =====================

#define PI 3.14159265359

// =====================
// Helpers (expanded macros)
// =====================


static float3 normalizeSafe(float3 v) {
    return normalize(v);
}

static float3 fract3(float3 v) {
    return fract(v);
}

static float length3(float3 v) {
    return length(v);
}

static float3 max3(float3 a, float b) {
    return max(a, float3(b));
}

// rotation (equivalent to m2)
static float2 rot(float2 p, float a) {
    float s = sin(a);
    float c = cos(a);
    return float2(c*p.x - s*p.y, s*p.x + c*p.y);
}
