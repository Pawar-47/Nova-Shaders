#ifndef NOVA_FOG_GLSL
#define NOVA_FOG_GLSL

#include "/lib/util.glsl"
#include "/lib/sky.glsl"

/* Exponential height fog.
 *
 * Density falls off with altitude above FOG_HEIGHT, so valleys and the sea stay
 * hazy while hill tops stay clear. The colour is a near neutral air colour with
 * a little warmth on the sun side: the first version copied the sky gradient
 * here, which painted every distant hill blue.
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

/* Air colour. Desaturated on purpose, and cheap: no sky gradient, no pow(). */
vec3 novaFogColour(vec3 direction, NovaSky sky) {
    vec3 air = mix(vec3(0.055, 0.064, 0.084), vec3(0.63, 0.69, 0.76), sky.day);
    air = mix(air, vec3(0.80, 0.64, 0.50), sky.sunset * 0.35);

    // A little extra brightness towards the sun, so haze glows where the light is.
    float towardsSun = saturate(dot(normalize(direction), sky.sunDir) * 0.5 + 0.5);
    air += vec3(0.060, 0.050, 0.030) * (towardsSun * towardsSun) * sky.day;

    // A hint of the biome colour vanilla picked for this place, desaturated so
    // it cannot drag the distance blue.
    air = mix(air, mix(fogColor, vec3(luma(fogColor)), 0.45), 0.20);

    if (isEyeInWater == 1) {
        vec3 haze = vec3(0.055, 0.135, 0.155) * (0.25 + 0.85 * sky.day);
        return mix(air, haze, 0.92);
    }

    return air;
}

vec3 applyFog(vec3 colour, vec3 rayToPoint, NovaSky sky) {
    if (dot(rayToPoint, rayToPoint) < 1.0e-6) return colour;

    float amount = saturate(novaFogAmount(rayToPoint));
    return mix(colour, novaFogColour(normalize(rayToPoint), sky), amount);
}

#endif
