#ifndef NOVA_SKY_GLSL
#define NOVA_SKY_GLSL

#include "/lib/util.glsl"

/* The sky, the sun, the moon and the cloud sheet.
 *
 * Every direction here is a normalised world space direction, in camera
 * relative world space, so nothing drifts when the player moves.
 *
 * The palette is deliberately restrained. A very saturated blue sky drags every
 * shadow, every distant hill and every reflection blue with it, which is what
 * the first version did; these values sit much closer to neutral daylight.
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
    sky.day = smoothstep(-0.12, 0.22, sky.sunDir.y);
    sky.sunset = (1.0 - smoothstep(0.0, 0.26, abs(sky.sunDir.y)))
               * smoothstep(-0.26, 0.04, sky.sunDir.y);
    return sky;
}

/* Vertical gradient, sunset band and sun glow.
 *
 * No pow() in here on purpose: this runs for every sky pixel and for every
 * water reflection, and sqrt() is one instruction where pow() is a call. */
vec3 novaSkyGradient(vec3 direction, NovaSky sky) {
    vec3 dir = normalize(direction);
    float above = saturate(dir.y);
    float height = sqrt(above);

    vec3 zenith = mix(vec3(0.015, 0.021, 0.038), vec3(0.33, 0.49, 0.72), sky.day);
    vec3 horizon = mix(vec3(0.045, 0.056, 0.082), vec3(0.71, 0.79, 0.86), sky.day);

    // How much this direction looks towards the sun, flattened onto the horizon.
    vec2 flatDir = normalize(vec2(dir.x, dir.z) + vec2(1.0e-4, 0.0));
    vec2 flatSun = normalize(vec2(sky.sunDir.x, sky.sunDir.z) + vec2(1.0e-4, 0.0));
    float towardsSun = saturate(dot(flatDir, flatSun) * 0.5 + 0.5);

    // Warm band along the horizon on the sun side, while it is setting.
    float band = sky.sunset * (1.0 - saturate(abs(dir.y) * 2.5)) * towardsSun * towardsSun;
    horizon = mix(horizon, vec3(1.00, 0.50, 0.24), band * 0.70);

    // A wider glow right around the sun itself.
    float glow = saturate(dot(dir, sky.sunDir));
    glow *= glow;
    glow *= glow;
    glow *= glow;                                    // glow to the eighth
    horizon += vec3(1.00, 0.74, 0.46) * glow * sky.sunset * 0.20;

    vec3 colour = mix(horizon, zenith, height);

    // Below the horizon, fade into haze instead of wrapping the dome.
    colour *= mix(1.0, 0.62, 1.0 - smoothstep(-0.30, 0.0, dir.y));

    // A whisper of vanilla's fog colour: enough to keep the Nether red and the
    // End purple, not enough to tint an ordinary horizon blue.
    colour = mix(colour, fogColor, 0.10 * (1.0 - height));

    // Rain: flatter and greyer, not darker and bluer.
    float gloom = saturate(rainStrength);
    colour = mix(colour, vec3(luma(colour)) * vec3(0.90, 0.92, 0.95), gloom * 0.55);

    return colour;
}

/* Offset of dir from centre, measured in the plane tangent to centre. A tangent
   basis keeps the disc edge sharp, where acos(dot()) loses precision exactly at
   the edge. Only reached for pixels that face the sun or the moon. */
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
    float body = 1.0 - smoothstep(0.015, 0.019, radius);

    float halo = saturate(1.0 - radius * 5.0);
    halo *= halo * halo * 0.18;

    vec3 warm = mix(vec3(1.00, 0.96, 0.90), vec3(1.00, 0.55, 0.26), sky.sunset);
    return (warm * body + warm * halo) * mix(0.55, 1.0, sky.day) * 4.0;
}

vec3 novaMoonDisc(vec3 direction, NovaSky sky) {
    if (dot(direction, sky.moonDir) < 0.9) return vec3(0.0);

    vec2 offset = novaDiscOffset(direction, sky.moonDir);
    float body = 1.0 - smoothstep(0.010, 0.014, length(offset));

    // A little procedural mottling so the disc is not a flat coin.
    float mottle = 0.82 + 0.18 * valueNoise(offset * 70.0);
    return vec3(0.80, 0.85, 1.00) * mottle * body * (1.0 - sky.day) * 1.6;
}

/* Cloud field.
 *
 * One FBM at a small cell size, thresholded hard enough that what survives are
 * separate little islands rather than a sheet, and domain warped so every island is
 * lopsided.
 *
 * There is deliberately no large scale mask. A mask arranged the clouds into banks
 * and left most of the sky empty - including straight overhead - because the patch
 * of sky you see when you look up is only a couple of hundred blocks across and
 * spans barely two cells of a coarse field. Small cells spread evenly fix both
 * problems at once.
 */
float novaCloudDensity(vec2 worldXZ, vec2 wind, int octaves) {
    // Roughly forty blocks per cell, so the puffs overhead are small objects and
    // not one sheet spanning the sky.
    vec2 p = worldXZ * 0.0235 + wind;

    // One low frequency sample, used both to warp the field and to vary how dense
    // the puffs are from place to place.
    float drift = valueNoise(p * 0.11 + 17.3);
    vec2 warp = vec2(drift, fract(drift * 5.7 + 0.31)) - 0.5;

    float n = fbm(p + warp * 1.15, octaves);

    float start = mix(0.64, 0.41, saturate(CLOUD_COVERAGE)) - drift * 0.06;
    float puff = smoothstep(start, start + 0.09, n);

    // A soft shoulder so a puff has a body between its core and its rim.
    puff *= mix(0.78, 1.0, smoothstep(start + 0.04, start + 0.22, n));

    return puff;
}

/* The shaded side of a cloud, before the sun side is added. */
vec3 novaCloudShade(NovaSky sky) {
    vec3 colour = mix(vec3(0.09, 0.10, 0.13), vec3(0.43, 0.45, 0.50), sky.day);
    return mix(colour, vec3(0.62, 0.48, 0.38), sky.sunset * 0.40);
}

/* The sun facing side. */
vec3 novaCloudLit(NovaSky sky) {
    vec3 colour = vec3(1.06, 1.04, 1.00) * (0.14 + 0.86 * sky.day);
    return mix(colour, vec3(1.00, 0.74, 0.52), sky.sunset * 0.55);
}

/* Composite the cloud sheet over an already drawn sky colour.
 *
 * The shading is a cheap fake volume: a second density sample, shifted towards
 * the sun, tells us whether this bit of cloud is a thin edge (lit, bright) or deep
 * inside a bank (thick, grey). One extra field evaluation, and only on pixels that
 * have cloud in them at all. */
vec3 novaSkyWithClouds(vec3 direction, NovaSky sky, vec3 skyColour) {
#if CLOUDS == 0
    return skyColour;
#else
    float altitude = CLOUD_ALTITUDE - cameraPosition.y;
    if (altitude <= 0.0 || direction.y <= 0.01) return skyColour;

    float rayLength = altitude / direction.y;
    vec2 hit = cameraPosition.xz + direction.xz * rayLength;
    vec2 wind = vec2(frameTimeCounter * 0.0180, frameTimeCounter * 0.0072);

    float density = novaCloudDensity(hit, wind, CLOUD_OCTAVES);
    if (density < 0.004) return skyColour;

    // A second sample towards the sun, at two octaves because only the shape
    // matters here: a low value means this face of the puff has clear air in front
    // of the light, so it is a sunlit edge. High means it is buried in a bank.
    vec2 sunShift = normalize(sky.lightDir.xz + vec2(1.0e-4)) * 120.0;
    float occlusion = novaCloudDensity(hit + sunShift, wind, 2);

    float sunlit = saturate(1.0 - occlusion * 1.5 + density * 0.20);
    vec3 cloudColour = mix(novaCloudShade(sky), novaCloudLit(sky), sunlit);

    // Silver lining: dense here and clear towards the sun, so this is the edge of a
    // puff with the light behind it.
    float rim = saturate((density - occlusion) * 1.6);
    cloudColour += novaCloudLit(sky) * rim * 0.30;

    // Rain flattens the whole sheet.
    cloudColour = mix(cloudColour, vec3(luma(cloudColour)) * 0.85, saturate(rainStrength) * 0.70);

    // Towards the horizon the sheet is seen almost edge on, so its noise becomes
    // sub pixel. Pull it towards the mean density there rather than letting it
    // shimmer, and let the sky behind it do the hazing.
    float horizon = 1.0 - smoothstep(0.02, 0.30, direction.y);
    float shaped = mix(density, 0.38, horizon * 0.85);

    float farFade = 1.0 - smoothstep(5000.0, 10000.0, rayLength);
    float alpha = shaped * farFade * (1.0 - horizon * 0.30);

    return mix(skyColour, cloudColour, saturate(alpha));
#endif
}

#endif
