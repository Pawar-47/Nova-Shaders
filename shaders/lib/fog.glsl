#ifndef NOVA_FOG_GLSL
#define NOVA_FOG_GLSL

#include "/lib/util.glsl"
#include "/lib/sky.glsl"

/* Exponential height fog.
 *
 * Density falls off with altitude above FOG_HEIGHT, so valleys and the sea stay
 * hazy while hill tops stay clear. The colour comes from the sky gradient, the
 * same one the sky is drawn with, so the far plane dissolves into the horizon
 * instead of into an unrelated colour.
 */

float novaFogAmount(vec3 rayToPoint) {
    float rayLength = length(rayToPoint);
    if (rayLength < 1.0e-3) return 0.0;

    float vertical = rayToPoint.y / rayLength;
    float density = (1.0 / 190.0) * FOG_DENSITY * (1.0 + saturate(rainStrength) * 1.4);

    if (isEyeInWater == 1) density *= 6.0;

    // Scale height of the exponential falloff, in blocks.
    const float scaleHeight = 26.0;
    float baseDensity = density * exp(-(cameraPosition.y - FOG_HEIGHT) / scaleHeight);

    float opticalDepth;
    if (abs(vertical) < 1.0e-3) {
        opticalDepth = baseDensity * rayLength;
    } else {
        opticalDepth = baseDensity * (1.0 - exp(-rayLength * vertical / scaleHeight))
                     * scaleHeight / vertical;
    }

    // A thin distance term on top, so the render distance never ends in a hard
    // edge on flat ground where the height term is weak.
    opticalDepth += rayLength * (1.0 / 2600.0) * FOG_DENSITY;

    return 1.0 - exp(-max(opticalDepth, 0.0));
}

vec3 novaFogColour(vec3 direction, NovaSky sky) {
    // Flatten the ray a little: fog should read as a wall around the player,
    // not as a second copy of the sky dome.
    vec3 flattened = normalize(vec3(direction.x, max(direction.y, 0.0) * 0.45 + 0.03, direction.z));
    vec3 colour = novaSkyGradient(flattened, sky);

    if (isEyeInWater == 1) {
        vec3 waterHaze = vec3(0.055, 0.135, 0.175) * (0.25 + 0.85 * sky.day);
        return mix(colour, waterHaze, 0.90);
    }

    return colour;
}

vec3 applyFog(vec3 colour, vec3 rayToPoint, NovaSky sky) {
    if (dot(rayToPoint, rayToPoint) < 1.0e-6) return colour;

    float amount = saturate(novaFogAmount(rayToPoint));
    return mix(colour, novaFogColour(normalize(rayToPoint), sky), amount);
}

#endif
