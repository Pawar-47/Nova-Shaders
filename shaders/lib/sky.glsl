#ifndef NOVA_SKY_GLSL
#define NOVA_SKY_GLSL

#include "/lib/util.glsl"

/* The sky, the sun, the moon and the cloud sheet.
 *
 * Every direction in this file is a normalised world space direction. "World
 * space" means camera relative world space, which is what the inverse model
 * view hands out, so nothing here drifts when the player moves.
 */

struct NovaSky {
    vec3 sunDir;   // towards the sun
    vec3 moonDir;  // towards the moon
    vec3 lightDir; // towards whichever of the two is casting shadows
    float day;     // 0 deep at night, 1 in full day
    float sunset;  // 0 except while the sun sits on the horizon
};

vec3 novaSunDirection() {
    return normalize(mat3(gbufferModelViewInverse) * sunPosition);
}

vec3 novaMoonDirection() {
    return normalize(mat3(gbufferModelViewInverse) * moonPosition);
}

vec3 novaLightDirection() {
    return normalize(mat3(gbufferModelViewInverse) * shadowLightPosition);
}

/* Gather the per frame state once, at the top of a program. */
NovaSky novaSkyState() {
    NovaSky sky;
    sky.sunDir = novaSunDirection();
    sky.moonDir = novaMoonDirection();
    sky.lightDir = novaLightDirection();
    sky.day = smoothstep(-0.10, 0.25, sky.sunDir.y);
    sky.sunset = (1.0 - smoothstep(0.0, 0.30, abs(sky.sunDir.y)))
               * smoothstep(-0.30, 0.05, sky.sunDir.y);
    return sky;
}

/* Vertical gradient with a warm band on the sun side while it sets. This is the
   only sky colour the pack uses: the fog samples the same function, which is
   what makes distant terrain fade into the sky instead of into a guess. */
vec3 novaSkyGradient(vec3 direction, NovaSky sky) {
    vec3 dir = normalize(direction);
    float above = saturate(dir.y);

    vec3 zenithDay = vec3(0.10, 0.28, 0.62);
    vec3 horizonDay = vec3(0.60, 0.74, 0.90);
    vec3 zenithNight = vec3(0.006, 0.010, 0.026);
    vec3 horizonNight = vec3(0.030, 0.045, 0.080);

    vec3 zenith = mix(zenithNight, zenithDay, sky.day);
    vec3 horizon = mix(horizonNight, horizonDay, sky.day);

    // How much this direction looks towards the sun, flattened onto the horizon.
    vec2 flatDir = normalize(vec2(dir.x, dir.z) + vec2(1.0e-4, 0.0));
    vec2 flatSun = normalize(vec2(sky.sunDir.x, sky.sunDir.z) + vec2(1.0e-4, 0.0));
    float towardsSun = saturate(dot(flatDir, flatSun) * 0.5 + 0.5);

    float band = sky.sunset * (1.0 - saturate(abs(dir.y) * 2.2)) * pow(towardsSun, 2.0);
    horizon = mix(horizon, vec3(1.00, 0.42, 0.16), band * 0.85);

    // Wide glow around the sun itself, only near the horizon.
    float glow = pow(saturate(dot(dir, sky.sunDir)), 10.0);
    horizon += vec3(1.00, 0.70, 0.38) * glow * sky.sunset * 0.30;

    float height = pow(above, 0.42);
    vec3 colour = mix(horizon, zenith, height);

    // Below the horizon, fall into a flat haze rather than wrapping the dome.
    colour *= mix(1.0, 0.55, 1.0 - smoothstep(-0.30, 0.0, dir.y));

    // Let vanilla's fog colour pull the horizon into the right biome and
    // dimension: red in the Nether, purple in the End, blue-grey at home.
    colour = mix(colour, fogColor, 0.25 * (1.0 - height));

    // Rain flattens the whole sky into a grey lid.
    float gloom = saturate(rainStrength);
    colour = mix(colour, vec3(luma(colour)) * vec3(0.72, 0.76, 0.82), gloom * 0.65);

    return colour;
}

/* Offset of dir from centre, measured in the plane tangent to centre. Using a
   tangent basis instead of acos(dot()) keeps the disc edge sharp and cheap. */
vec2 novaDiscOffset(vec3 dir, vec3 centre) {
    vec3 reference = abs(centre.y) > 0.99 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
    vec3 tangentX = normalize(cross(centre, reference));
    vec3 tangentY = cross(centre, tangentX);
    float forward = max(dot(dir, centre), 1.0e-3);
    return vec2(dot(dir, tangentX), dot(dir, tangentY)) / forward;
}

vec3 novaSunDisc(vec3 direction, NovaSky sky) {
    if (dot(direction, sky.sunDir) < 0.9) return vec3(0.0);

    float radius = length(novaDiscOffset(direction, sky.sunDir));
    float body = 1.0 - smoothstep(0.016, 0.021, radius);
    float halo = pow(saturate(1.0 - radius * 6.0), 3.0) * 0.35;

    vec3 warm = mix(vec3(1.00, 0.96, 0.88), vec3(1.00, 0.52, 0.22), sky.sunset);
    return (warm * body + warm * halo) * mix(0.6, 1.0, sky.day) * 6.0;
}

vec3 novaMoonDisc(vec3 direction, NovaSky sky) {
    if (dot(direction, sky.moonDir) < 0.9) return vec3(0.0);

    vec2 offset = novaDiscOffset(direction, sky.moonDir);
    float body = 1.0 - smoothstep(0.011, 0.015, length(offset));

    // A little procedural mottling so the disc is not a flat coin.
    float mottle = 0.80 + 0.20 * valueNoise(offset * 70.0);
    return vec3(0.72, 0.80, 1.00) * mottle * body * (1.0 - sky.day) * 2.2;
}

/* One flat noise sheet, sampled in world space so it stays anchored to the
   ground while the camera moves. */
float novaCloudDensity(vec2 worldXZ, int octaves) {
    vec2 p = worldXZ * 0.0018;
    p += vec2(frameTimeCounter * 0.0032, frameTimeCounter * 0.0011);

    float n = fbm(p, octaves);
    float threshold = mix(0.70, 0.28, saturate(CLOUD_COVERAGE));
    return smoothstep(threshold, threshold + 0.20, n);
}

vec3 novaCloudColour(NovaSky sky) {
    vec3 lit = vec3(1.05, 1.02, 0.96) * (0.30 + 0.80 * sky.day);
    vec3 shade = mix(vec3(0.06, 0.08, 0.14), vec3(0.42, 0.46, 0.54), sky.day);

    vec3 colour = mix(shade, lit, 0.72);
    colour = mix(colour, vec3(1.00, 0.52, 0.28), sky.sunset * 0.45);

    return mix(colour, vec3(luma(colour)) * 0.70, saturate(rainStrength) * 0.70);
}

/* Composite the cloud sheet over an already drawn sky colour. */
vec3 novaSkyWithClouds(vec3 direction, NovaSky sky, vec3 skyColour) {
#if CLOUDS == 0
    return skyColour;
#else
    float altitude = CLOUD_ALTITUDE - cameraPosition.y;
    if (altitude <= 0.0 || direction.y <= 0.02) return skyColour;

    float rayLength = altitude / direction.y;
    vec2 hit = cameraPosition.xz + direction.xz * rayLength;

    float density = novaCloudDensity(hit, CLOUD_OCTAVES);

    // Fade the sheet out where it is far away, and where the ray grazes the
    // horizon, so it reads as a lid that goes on forever.
    float farFade = 1.0 - smoothstep(1200.0, 5200.0, rayLength);
    float horizonFade = smoothstep(0.02, 0.16, direction.y);

    return mix(skyColour, novaCloudColour(sky), density * farFade * horizonFade * 0.92);
#endif
}

#endif
