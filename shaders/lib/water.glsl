#ifndef NOVA_WATER_GLSL
#define NOVA_WATER_GLSL

#include "/lib/util.glsl"
#include "/lib/sky.glsl"

/* Water surface.
 *
 * Three octaves of slope, each the exact gradient of a value noise field, summed
 * into one XY tilt. The gradient is analytic, so three octaves cost three noise
 * lookups instead of nine.
 *
 * Two things keep it reading as water rather than as moving glass:
 *   - the tilt is flattened by incidence, so looking down you get the full chop and
 *     looking along the surface it becomes a mirror. That is what keeps distant
 *     water stable without a distance fade;
 *   - the flatness is a single Z value, so roughness is one number and not a filter.
 */

vec3 novaWaterNormal(vec3 worldPos, vec3 geometricNormal) {
#if WATER_WAVES == 0
    return geometricNormal;
#else
    // Only the top of a liquid gets waves; the side of flowing water stays flat.
    if (geometricNormal.y < 0.75) return geometricNormal;

    vec2 p = worldPos.xz;
    float time = frameTimeCounter;
    float viewDistance = length(worldPos);

    // A 20 block swell, a 32 block cross swell, and an 8 block chop that carries
    // most of the detail.
    vec3 swellA = valueNoiseGradient(p * 0.0500 + vec2(time * 0.30, time * 0.30));
    vec3 swellB = valueNoiseGradient(p * 0.03125 - vec2(time * 0.42, time * 0.42));

    // The finest octave fades out with distance: without mipmaps it would alias
    // into noise on the far side of a lake.
    float fineFade = 1.0 - saturate(viewDistance / 80.0);
    vec3 chop = valueNoiseGradient(p * 0.1250 + vec2(time * 0.10, -time * 0.10));

    vec2 slope = swellA.yz * 0.075 + swellB.yz * 0.085 + chop.yz * 0.036 * fineFade;

    // Flatness: lower is choppier, and rain roughens the surface.
    float flatness = 0.90 - saturate(rainStrength) * 0.35;

    vec3 tilted = normalize(vec3(slope.x, flatness, slope.y));

    // Flatten by incidence: full chop underfoot, mirror towards the horizon.
    float incidence = abs(dot(geometricNormal, normalize(-worldPos)));
    tilted.xy *= incidence;
    tilted.z += 1.0 - incidence;

    return normalize(tilted);
#endif
}

/* Fresnel in the shape the reference water uses: no strong F0, a squared falloff,
   and a ceiling well below a full mirror, so water keeps its colour even at
   grazing angles instead of turning into a sheet of sky. */
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

/* Sun and moon glitter: a soft disc where the reflected view meets the light.
   A wide soft blob reads as water; a tight sparkle reads as glitter on plastic. */
float novaWaterGlint(vec3 toEye, vec3 normal, NovaSky sky) {
    vec3 reflected = reflect(-toEye, normal);
    float aligned = max(dot(normalize(reflected), sky.lightDir), 0.0);
    return smoothstep(0.995, 1.0, aligned) * 3.0;
}

#endif
