#ifndef NOVA_WATER_GLSL
#define NOVA_WATER_GLSL

#include "/lib/util.glsl"
#include "/lib/sky.glsl"

/* Water surface: two crossed wave trains plus a noisy chop term.
 *
 * The surface is described by the gradient of a height field, so the normal is
 * simply the gradient tilted into the Y axis. Two sine trains give a repeatable
 * swell, the value noise chop breaks up the regularity.
 */

vec3 novaWaterNormal(vec3 worldPos, vec3 geometricNormal) {
#if WATER_WAVES == 0
    return geometricNormal;
#else
    // Only the top of a liquid gets waves; the side of flowing water stays flat.
    if (geometricNormal.y < 0.6) return geometricNormal;

    float time = frameTimeCounter;
    vec2 p = worldPos.xz;
    vec2 slope = vec2(0.0);

    // Train one: long swell running out of +X.
    vec2 dirA = normalize(vec2(0.88, 0.47));
    float phaseA = dot(p, dirA) * 0.55 + time * 0.75;
    slope += dirA * cos(phaseA) * 0.55 * 0.070;

    // Train two: shorter, faster and crossed, so the pattern never lines up.
    vec2 dirB = normalize(vec2(-0.51, 0.86));
    float phaseB = dot(p, dirB) * 1.35 - time * 1.10;
    slope += dirB * cos(phaseB) * 1.35 * 0.034;

    // Chop: the gradient of a noise field, taken with forward differences.
    vec2 q = p * 2.6 + vec2(time * 0.33, -time * 0.26);
    const float e = 0.08;
    float n0 = valueNoise(q);
    float nx = valueNoise(q + vec2(e, 0.0));
    float nz = valueNoise(q + vec2(0.0, e));
    slope += vec2(nx - n0, nz - n0) * (0.06 / e);

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

/* What the surface mirrors: the sky gradient, never the ground underneath. */
vec3 novaWaterReflection(vec3 toEye, vec3 normal, NovaSky sky) {
    vec3 reflected = reflect(-toEye, normal);
    reflected.y = abs(reflected.y);
    return novaSkyGradient(reflected, sky);
}

/* One tight specular lobe: the sun on water is a handful of bright pixels. */
float novaWaterGlint(vec3 toEye, vec3 normal, NovaSky sky) {
    vec3 halfVector = normalize(toEye + sky.lightDir + vec3(1.0e-5));
    return pow(saturate(dot(normal, halfVector)), 420.0);
}

#endif
