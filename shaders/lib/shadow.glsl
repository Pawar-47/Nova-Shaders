#ifndef NOVA_SHADOW_GLSL
#define NOVA_SHADOW_GLSL

#include "/lib/util.glsl"

/* Shadow mapping.
 *
 * One depth map, four filtered taps on a rotated-free 2x2 grid, and a bias
 * that grows with the angle between the surface and the light. The 2x2 grid is
 * half a texel wide, which puts every tap on a texel centre: the four results
 * then behave like a hardware box filter and only cost four comparisons.
 */

uniform sampler2D shadowtex0;

const vec2 SHADOW_TAPS[4] = vec2[4](
    vec2(-0.5, -0.5),
    vec2( 0.5, -0.5),
    vec2(-0.5,  0.5),
    vec2( 0.5,  0.5)
);

/* playerPos is the position relative to the camera in world space, normal the
   world space surface normal, NdotL the angle to the casting light. Returns 1.0
   for fully lit and 0.0 for fully shadowed. */
float shadowFactor(vec3 playerPos, vec3 normal, float NdotL) {
#if SHADOWS == 0
    return 1.0;
#else
    float slope = 1.0 - clamp(NdotL, 0.0, 1.0);

    // Nudging the lookup along the normal moves the sample off the surface, so
    // the depth bias below only has to cover a couple of shadow texels.
    vec3 position = playerPos + normal * (0.035 + 0.10 * slope);

    vec4 clip = shadowProjection * (shadowModelView * vec4(position, 1.0));
    vec3 ndc = clip.xyz / clip.w;
    vec2 uv = ndc.xy * 0.5 + 0.5;

    if (uv.x <= 0.0 || uv.x >= 1.0 || uv.y <= 0.0 || uv.y >= 1.0) return 1.0;

    float receiverDepth = ndc.z * 0.5 + 0.5;
    float bias = (0.00035 + 0.00250 * slope) * SHADOW_SOFTNESS;
    vec2 texel = vec2(SHADOW_SOFTNESS / float(shadowMapResolution));

    float lit = 0.0;
    for (int i = 0; i < 4; i++) {
        float storedDepth = texture(shadowtex0, uv + SHADOW_TAPS[i] * texel).r;
        lit += step(receiverDepth - bias, storedDepth);
    }
    lit *= 0.25;

    // Fade out at the rim of the map and at the far end of the shadow range, so
    // there is no hard ring where shadows simply stop.
    float edge = min(min(uv.x, uv.y), min(1.0 - uv.x, 1.0 - uv.y));
    float edgeFade = smoothstep(0.0, 1.0 / 12.0, edge);
    float farFade = 1.0 - smoothstep(shadowDistance * 0.80, shadowDistance, length(playerPos));

    return mix(1.0, lit, edgeFade * farFade);
#endif
}

#endif
