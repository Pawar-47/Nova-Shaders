#ifndef NOVA_VEGETATION_GLSL
#define NOVA_VEGETATION_GLSL

/* A small, world-anchored wind offset shared by terrain and shadow passes. */
vec2 novaVegetationOffset(vec2 worldXZ) {
    vec2 cell = floor(worldXZ);
    float phase = dot(cell, vec2(0.13, 0.21)) + frameTimeCounter * 1.35;
    float sway = sin(phase) * 0.75 + sin(phase * 0.47 - frameTimeCounter * 0.55) * 0.25;
    return vec2(0.11, 0.07) * sway;
}

#endif
