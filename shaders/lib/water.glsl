#ifndef NOVA_WATER_GLSL
#define NOVA_WATER_GLSL

#include "/lib/util.glsl"
#include "/lib/sky.glsl"

/* Water surface: five swells plus two fine ripples.
 *
 * The trick to water that does not look like corrugated iron is to never let two
 * wave trains line up. The directions here are a few degrees apart rather than
 * exactly crossed, the wavelengths are in an irrational ratio to each other, and
 * every train runs at its own speed. The result never repeats over the visible
 * area and has no visible grid, which is what the two crossed sines of the first
 * version produced.
 *
 * The surface is a height field, so the normal is the sum of every train's
 * gradient tilted into the Y axis.
 */

const vec2 WAVE_DIRECTION[5] = vec2[5](
    vec2( 0.94,  0.34),
    vec2(-0.39,  0.92),
    vec2( 0.66, -0.75),
    vec2(-0.88, -0.47),
    vec2( 0.21,  0.98)
);

const float WAVE_LENGTH[5] = float[5](13.7, 8.3, 5.1, 3.3, 2.1);
const float WAVE_SPEED[5] = float[5](0.62, -0.86, 1.13, -1.47, 1.91);
const float WAVE_SLOPE[5] = float[5](0.085, 0.055, 0.036, 0.022, 0.013);

vec3 novaWaterNormal(vec3 worldPos, vec3 geometricNormal) {
#if WATER_WAVES == 0
    return geometricNormal;
#else
    // Only the top of a liquid gets waves; the side of flowing water stays flat.
    if (geometricNormal.y < 0.75) return geometricNormal;

    float time = frameTimeCounter;
    vec2 p = worldPos.xz;
    vec2 slope = vec2(0.0);

    for (int i = 0; i < 5; i++) {
        float k = NOVA_TAU / WAVE_LENGTH[i];
        float phase = dot(p, WAVE_DIRECTION[i]) * k + time * WAVE_SPEED[i];
        slope += WAVE_DIRECTION[i] * (cos(phase) * k * WAVE_SLOPE[i]);
    }

    // Fine ripples on top. They fade out with distance, because ripples finer
    // than a pixel turn into shimmer and noise on the horizon.
    float viewDistance = length(worldPos);
    float fineFade = 1.0 - saturate(viewDistance / 70.0);

    if (fineFade > 0.01) {
        vec2 dirA = vec2(0.28, 0.96);
        float phaseA = dot(p, dirA) * 9.1 + time * 2.4;
        slope += dirA * (cos(phaseA) * 9.1 * 0.0075) * fineFade;

        vec2 dirB = vec2(-0.94, 0.33);
        float phaseB = dot(p, dirB) * 12.3 - time * 2.9;
        slope += dirB * (cos(phaseB) * 12.3 * 0.0055) * fineFade;
    }

    slope *= WATER_WAVE_HEIGHT;
    return normalize(vec3(-slope.x, 1.0, -slope.y));
#endif
}

/* Schlick approximation of Fresnel, with the F0 of water (1.33 refracting). */
float novaFresnel(float cosTheta) {
    float f = 1.0 - saturate(cosTheta);
    float f2 = f * f;
    return 0.02 + 0.98 * f2 * f2 * f;
}

/* What the surface mirrors: the sky, slightly desaturated so the water reads as
   water and not as a sheet of blue paint. */
vec3 novaWaterReflection(vec3 toEye, vec3 normal, NovaSky sky) {
    vec3 reflected = reflect(-toEye, normal);
    reflected.y = abs(reflected.y);

    vec3 reflectedSky = novaSkyGradient(reflected, sky);
    return mix(reflectedSky, vec3(luma(reflectedSky)), 0.20);
}

/* One tight specular lobe: the sun on water is a handful of bright pixels that
   jump between wave crests as the surface moves. */
float novaWaterGlint(vec3 toEye, vec3 normal, NovaSky sky) {
    vec3 halfVector = normalize(toEye + sky.lightDir + vec3(1.0e-5));
    float angle = saturate(dot(normal, halfVector));
    angle *= angle;
    angle *= angle;              // ^4
    angle *= angle;              // ^8
    angle = angle * angle * angle;   // ^24
    return angle * angle * angle * angle;   // ^96, broad enough to sparkle
}

#endif
