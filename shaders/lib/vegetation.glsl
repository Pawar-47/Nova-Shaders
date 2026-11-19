#ifndef NOVA_VEGETATION_GLSL
#define NOVA_VEGETATION_GLSL

/* A continuous world-space wind field shared by terrain and shadow passes.
   The caller weights it by how far the vertex sits above the middle of its
   sprite, so the base of a plant stays put and only the top leans. Because the
   phase itself varies with world height, the top of a tall plant lags its base
   and the quad curves instead of shearing flat. */
vec2 novaVegetationOffset(vec3 worldPosition) {
    float phase = dot(worldPosition.xz, vec2(0.12, 0.08))
                + worldPosition.y * 0.70 + frameTimeCounter * 1.35;
    float gust = dot(worldPosition.xz, vec2(-0.08, 0.15))
               - worldPosition.y * 0.32 + frameTimeCounter * 0.53;
    float sway = sin(phase) * 0.72 + sin(gust) * 0.28;
    return vec2(0.24, 0.14) * sway;
}

#endif
