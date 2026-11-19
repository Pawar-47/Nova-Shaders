#ifndef NOVA_WATER_GLSL
#define NOVA_WATER_GLSL

#include "/lib/util.glsl"
#include "/lib/sky.glsl"

/* Water surface.
 *
 * The directional wave profile and its analytic slope are a reduced adaptation
 * of Glimmer's MIT-licensed waveNormals.glsl (itself crediting afl_ext's
 * "Very fast procedural ocean"). Two broad wave trains plus one inexpensive
 * value-noise detail octave keep the surface moving without the source's
 * sixteen-octave loop or three complete height evaluations per pixel.
 */
float novaWaterWaveSlope(vec2 position, vec2 direction, float frequency, float phase, float amplitude) {
    float angle = mod(dot(direction, position) * frequency + phase, NOVA_TAU);
    float wave = exp(sin(angle) - 1.0) * 0.5;
    return wave * cos(angle) * frequency * amplitude;
}

vec3 novaWaterNormal(vec3 worldPos, vec3 geometricNormal) {
#if WATER_WAVES == 0
    return geometricNormal;
#else
    // Only the top of a liquid gets waves; the side of flowing water stays flat.
    if (geometricNormal.y < 0.75) return geometricNormal;

    vec2 p = worldPos.xz;
    float time = frameTimeCounter;
    float viewDistance = length(worldPos - cameraPosition);

    const vec2 directionA = vec2(0.894427, 0.447214);
    const vec2 directionB = vec2(-0.371391, 0.928477);
    float swellA = novaWaterWaveSlope(p, directionA, 0.075, time * 0.42, 1.25);
    float swellB = novaWaterWaveSlope(p, directionB, 0.118, -time * 0.31, 0.72);

    // The finest octave fades out with distance to avoid aliased far-water detail.
    float fineFade = 1.0 - saturate(viewDistance / 80.0);
    vec3 chop = valueNoiseGradient(p * 0.125 + vec2(time * 0.10, -time * 0.10));

    vec2 slope = directionA * swellA + directionB * swellB + chop.yz * 0.030 * fineFade;
    slope *= WATER_WAVE_HEIGHT * (1.0 + saturate(rainStrength) * 0.25);

    // Rain roughens the surface slightly. The normal's vertical axis is Y.
    float flatness = 1.0 - saturate(rainStrength) * 0.08;
    vec3 tilted = normalize(vec3(-slope.x, flatness, -slope.y));

    // Fade the perturbation toward the horizon while preserving the actual up axis.
    float incidence = abs(dot(geometricNormal, normalize(cameraPosition - worldPos)));
    tilted.xz *= incidence;
    tilted.y += 1.0 - incidence;

    return normalize(tilted);
#endif
}

/* Beer-Lambert attenuation with a compact in-scattering term, adapted from
   Glimmer's MIT-licensed waterFog.glsl. This returns the colour of the water
   body; the caller still blends it with the already-rendered scene. */
vec3 novaWaterTransmittance(float thickness) {
    const vec3 absorption = vec3(0.52, 0.30, 0.23);
    return exp(-absorption * max(thickness, 0.0));
}

vec3 novaWaterMedium(vec3 surfaceColour, float thickness) {
    vec3 transmittance = novaWaterTransmittance(thickness);
    const vec3 scatterColour = vec3(0.035, 0.095, 0.078);
    vec3 surfaceLinear = sRGBToLinear(surfaceColour);
    vec3 scatterLinear = sRGBToLinear(scatterColour);
    return linearToSRGB(surfaceLinear * transmittance + scatterLinear * (1.0 - transmittance));
}

float novaWaterOpacity(float thickness) {
    return 1.0 - luma(novaWaterTransmittance(thickness));
}

/* Schlick-shaped reflection with a restrained ceiling, so water keeps some body
   colour at grazing angles instead of becoming a full sheet of sky. */
float novaFresnel(float cosTheta) {
    float f = 1.0 - saturate(cosTheta);
    return 0.02 + 0.73 * f * f;
}

/* What the surface mirrors: the sky, pulled slightly towards grey. */
vec3 novaWaterReflection(vec3 toEye, vec3 normal, NovaSky sky) {
    vec3 reflected = reflect(-toEye, normal);
    reflected.y = abs(reflected.y);

    vec3 reflectedSky = novaSkyGradient(reflected, sky);
    return mix(reflectedSky, vec3(luma(reflectedSky)), 0.12);
}

/* Sun and moon glitter: a soft disc where the reflected view meets the light. */
float novaWaterGlint(vec3 toEye, vec3 normal, NovaSky sky) {
    vec3 reflected = reflect(-toEye, normal);
    float aligned = max(dot(normalize(reflected), sky.lightDir), 0.0);
    return smoothstep(0.995, 1.0, aligned) * 3.0;
}

#endif
