#ifndef NOVA_SHADOW_GLSL
#define NOVA_SHADOW_GLSL

#include "/lib/util.glsl"

/* Shadow mapping.
 *
 * One depth map and an eight tap golden angle spiral, with the tap radius growing
 * with distance from the camera and with the angle between the surface and the
 * light. The angle term is the cheap stand in for a contact hardened penumbra:
 * tight where a wall meets the floor, wide at the far end of the shadow range.
 *
 * The spiral replaced a fixed 2x2 half texel grid, which put every tap on a texel
 * centre and could only ever return five levels of coverage between lit and
 * fully shadowed. Eight taps across a wider disc give nine levels over a soft
 * edge, which is the difference between a shadow that is cut out of black paper
 * and one that has a gradient.
 *
 * The comparison is a smoothstep band rather than a hard step for the same
 * reason: a surface sitting within one depth quantum of its own shadow then
 * receives partial light instead of flickering between black and white, which is
 * what shadow acne is.
 */

uniform sampler2D shadowtex0;

const vec2 SHADOW_TAPS[8] = vec2[8](
    vec2(-0.2608,  0.2388),
    vec2( 0.0436, -0.4981),
    vec2( 0.3728,  0.4859),
    vec2(-0.6962, -0.1232),
    vec2( 0.6670, -0.4243),
    vec2(-0.2248,  0.8363),
    vec2(-0.4306, -0.8305),
    vec2( 0.9392,  0.3432)
);

/* playerPos is the position relative to the camera in world space, normal the
   geometric surface normal, NdotL the angle to the casting light. Returns 1.0
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

    // Tight near the eye, wide at the far end of the range, and wider still where
    // the surface is edge on to the light, which is where a shadow stretches.
    float distance01 = saturate(length(playerPos) / shadowDistance);
    float radius = SHADOW_SOFTNESS * mix(0.55, 2.60, distance01) * (0.80 + 0.70 * slope);
    vec2 texel = vec2(radius / float(shadowMapResolution));

    // The soft band grows with distance as well, because one shadow texel covers
    // more world space out there and the depth quantisation grows with it.
    float band = 0.00045 + 0.00120 * distance01;

    float lit = 0.0;
    for (int i = 0; i < 8; i++) {
        float storedDepth = texture(shadowtex0, uv + SHADOW_TAPS[i] * texel).r;
        lit += smoothstep(receiverDepth - bias, receiverDepth - bias + band, storedDepth);
    }
    lit *= 0.125;

    // Fade out at the rim of the map and at the far end of the shadow range, so
    // there is no hard ring where shadows simply stop.
    float edge = min(min(uv.x, uv.y), min(1.0 - uv.x, 1.0 - uv.y));
    float edgeFade = smoothstep(0.0, 1.0 / 12.0, edge);
    float farFade = 1.0 - smoothstep(shadowDistance * 0.80, shadowDistance, length(playerPos));

    return mix(1.0, lit, edgeFade * farFade);
#endif
}

#endif
