#ifndef NOVA_VEGETATION_GLSL
#define NOVA_VEGETATION_GLSL

/* Ground plants use the quad's texture midpoint as a hinge. The base stays
   planted while the top follows a smooth, world-anchored gust field. */
vec2 novaVegetationOffset(vec3 worldPosition) {
    float phase = dot(worldPosition.xz, vec2(0.12, 0.08))
                + worldPosition.y * 0.70 + frameTimeCounter * 1.35;
    float gust = dot(worldPosition.xz, vec2(-0.08, 0.15))
               - worldPosition.y * 0.32 + frameTimeCounter * 0.53;
    float sway = sin(phase) * 0.72 + sin(gust) * 0.28;
    return vec2(0.24, 0.14) * sway;
}

/* Leaf blocks have cube topology rather than a single crossed plant quad.
   Their displacement is therefore a continuous function of world position:
   duplicated vertices on adjoining block edges receive the same offset, so
   the canopy does not open visible cracks. A slower branch-scale motion is
   layered with a tiny, faster vertex flutter, inspired by the per-vertex
   foliage motion documented by Googy Shaders. The distance fade avoids
   spending the full animation budget on distant canopies. */
vec2 novaLeafOffset(vec3 worldPosition) {
    vec3 cameraRelative = worldPosition - cameraPosition;
    float distanceSquared = dot(cameraRelative, cameraRelative);
    if (distanceSquared >= 96.0 * 96.0) return vec2(0.0);

    float distanceFade = 1.0 - smoothstep(42.0 * 42.0,
                                         96.0 * 96.0,
                                         distanceSquared);

    float canopyPhase = dot(worldPosition.xz, vec2(0.035, 0.021))
                      + worldPosition.y * 0.055
                      + frameTimeCounter * 0.48;
    float gustPhase = dot(worldPosition.xz, vec2(-0.021, 0.046))
                    - worldPosition.y * 0.075
                    - frameTimeCounter * 0.23;
    float flutterPhase = dot(worldPosition.xz, vec2(0.29, 0.37))
                       + worldPosition.y * 1.10
                       + frameTimeCounter * 2.20;

    float gustEnvelope = 0.68 + 0.32 * sin(gustPhase);
    float broadSway = sin(canopyPhase) * 0.72 + sin(gustPhase) * 0.28;
    vec2 branchMotion = vec2(0.060, 0.035) * broadSway * gustEnvelope;
    vec2 leafFlutter = vec2(0.009, -0.006) * sin(flutterPhase);
    return (branchMotion + leafFlutter) * distanceFade;
}

#endif
