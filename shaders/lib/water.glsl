#ifndef NOVA_WATER_GLSL
#define NOVA_WATER_GLSL

#include "/lib/util.glsl"
#include "/lib/sky.glsl"

/* Water surface.
 *
 * Three swell trains give the large motion: directions a few degrees apart,
 * wavelengths in an irrational ratio, each running at its own speed, so they never
 * line up into a visible grid. On top of that sits a noise gradient at roughly one
 * block per cell, which is the high frequency detail that actually reads as water.
 * Sines alone always look like corrugated iron from some angle; the noise is what
 * makes the surface glitter and break up.
 *
 * The surface is a height field, so the normal is the sum of every gradient
 * tilted into the Y axis.
 */

const vec2 SWELL_DIRECTION[3] = vec2[3](
    vec2( 0.94,  0.34),
    vec2(-0.39,  0.92),
    vec2( 0.66, -0.75)
);

const float SWELL_LENGTH[3] = float[3](12.9, 7.3, 4.1);
const float SWELL_SPEED[3] = float[3](0.55, -0.82, 1.14);
const float SWELL_SLOPE[3] = float[3](0.085, 0.060, 0.040);

vec3 novaWaterNormal(vec3 worldPos, vec3 geometricNormal) {
#if WATER_WAVES == 0
    return geometricNormal;
#else
    // Only the top of a liquid gets waves; the side of flowing water stays flat.
    if (geometricNormal.y < 0.75) return geometricNormal;

    float time = frameTimeCounter;
    vec2 p = worldPos.xz;
    float viewDistance = length(worldPos);

    vec2 slope = vec2(0.0);

    for (int i = 0; i < 3; i++) {
        float k = NOVA_TAU / SWELL_LENGTH[i];
        float phase = dot(p, SWELL_DIRECTION[i]) * k + time * SWELL_SPEED[i];
        slope += SWELL_DIRECTION[i] * (cos(phase) * k * SWELL_SLOPE[i]);
    }

    // Fine chop, as the gradient of a noise field. It fades out with distance so
    // the far water does not dissolve into pixel noise, which is what ripples
    // finer than a pixel turn into.
    float detail = 1.0 - saturate(viewDistance / 90.0);
    if (detail > 0.02) {
        vec2 q = p * 0.9 + vec2(time * 0.22, -time * 0.17);
        const float e = 0.35;
        float n0 = valueNoise(q);
        float nx = valueNoise(q + vec2(e, 0.0));
        float nz = valueNoise(q + vec2(0.0, e));
        slope += vec2(nx - n0, nz - n0) * (0.055 / e) * detail;
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

/* What the surface mirrors: the sky, including the sun and the moon, pulled
   slightly towards grey so the water reads as water and not as blue paint. */
vec3 novaWaterReflection(vec3 toEye, vec3 normal, NovaSky sky) {
    vec3 reflected = reflect(-toEye, normal);
    reflected.y = abs(reflected.y);

    vec3 reflectedSky = novaSkyGradient(reflected, sky);
    reflectedSky += novaSunDisc(reflected, sky) * 0.45;
    reflectedSky += novaMoonDisc(reflected, sky) * 0.40;

    return mix(reflectedSky, vec3(luma(reflectedSky)), 0.16);
}

/* Sun glint: a broad sheen under a tight sparkle, so the highlight has a shape
   instead of being one flat dot. */
float novaWaterGlint(vec3 toEye, vec3 normal, NovaSky sky) {
    vec3 halfVector = normalize(toEye + sky.lightDir + vec3(1.0e-5));
    float angle = saturate(dot(normal, halfVector));

    float a2 = angle * angle;
    float a4 = a2 * a2;
    float a8 = a4 * a4;
    float a16 = a8 * a8;
    float a32 = a16 * a16;

    float broad = a32 * a32;      // angle to the 64th
    float mid = broad * broad;    // angle to the 128th
    float tight = mid * mid;      // angle to the 256th

    return broad * 0.30 + mid * 0.35 + tight * 0.55;
}

#endif
