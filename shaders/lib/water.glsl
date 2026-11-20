#ifndef NOVA_WATER_GLSL
#define NOVA_WATER_GLSL

#include "/lib/util.glsl"
#include "/lib/sky.glsl"
#include "/lib/water_waves.glsl"

/* Water surface.
 *
 * The directional wave profile and its analytic slope are a reduced adaptation
 * of Glimmer's MIT-licensed waveNormals.glsl (itself crediting afl_ext's
 * "Very fast procedural ocean"). Two broad wave trains plus one inexpensive
 * value-noise detail octave keep the surface moving without the source's
 * sixteen-octave loop or three complete height evaluations per pixel.
 */
vec3 novaWaterNormal(vec3 worldPos, vec3 geometricNormal) {
#if WATER_WAVES == 0
    return geometricNormal;
#else
    // Only the top of a liquid gets waves; the side of flowing water stays flat.
    if (geometricNormal.y < 0.75) return geometricNormal;

    vec2 p = worldPos.xz;
    float time = frameTimeCounter;
    vec3 cameraRelative = worldPos - cameraPosition;
    float distanceSquared = dot(cameraRelative, cameraRelative);

    // The shared analytic slope matches the higher-frequency vertex displacement.
    // The extra noise ripple is only useful nearby, so past its range the
    // gradient-noise evaluation is skipped entirely rather than multiplied by zero.
    //
    // The swell is what carries water out to the horizon, and the sun path lives
    // out there, so it keeps most of its strength far away. Fading the whole tilt
    // by view incidence, as an earlier version did, flattened exactly the grazing
    // angles where a real surface shows the most detail and where the glitter is.
    float swellFade = mix(0.55, 1.0, 1.0 - saturate(sqrt(distanceSquared) / 320.0));

    vec2 slope = novaWaterSurfaceSlope(p) * 2.2 * swellFade;
    if (distanceSquared < 72.0 * 72.0) {
        float chopFade = 1.0 - sqrt(distanceSquared) / 72.0;
        vec3 chop = valueNoiseGradient(p * 0.42 + vec2(time * 0.18, -time * 0.14));
        slope += chop.yz * 0.055 * chopFade;
    }
    slope *= 1.0 + saturate(rainStrength) * 0.25;

    // Rain roughens the surface slightly. The normal's vertical axis is Y.
    float flatness = 1.0 - saturate(rainStrength) * 0.08;
    vec3 tilted = normalize(vec3(-slope.x, flatness, -slope.y));

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
    return 0.04 + 0.78 * f * f;
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
    return smoothstep(0.955, 0.997, aligned) * 1.8;
}

#endif
