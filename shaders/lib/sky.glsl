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

/* Puff field.
 *
 * Two noise fields: a low frequency mask decides where the cloud banks sit, and a
 * higher frequency field cuts each bank into puffs. A third, coarser ramp gives
 * every puff a soft shoulder, because a hard thresholded edge is exactly what
 * makes a cloud sheet look like paper. */
float novaCloudDensity(vec2 worldXZ, vec2 wind, int octaves) {
    vec2 p = worldXZ * 0.0090 + wind;

    float cluster = valueNoise(p * 0.19 + 17.3);
    float clusterStart = mix(0.55, 0.22, saturate(CLOUD_COVERAGE));
    float mask = smoothstep(clusterStart, clusterStart + 0.18, cluster);

    float n = fbm(p, octaves);
    float puffStart = mix(0.52, 0.32, saturate(CLOUD_COVERAGE));
    float puff = smoothstep(puffStart, puffStart + 0.18, n);
    puff *= mix(0.70, 1.0, smoothstep(puffStart + 0.02, puffStart + 0.30, n));

    return puff * mask;
}

/* The shaded side of a cloud, before the sun side is added. */
vec3 novaCloudShade(NovaSky sky) {
    vec3 colour = mix(vec3(0.10, 0.115, 0.14), vec3(0.56, 0.58, 0.63), sky.day);
    return mix(colour, vec3(0.72, 0.56, 0.44), sky.sunset * 0.40);
}

/* The sun facing side. */
vec3 novaCloudLit(NovaSky sky) {
    vec3 colour = vec3(1.04, 1.02, 0.98) * (0.16 + 0.84 * sky.day);
    return mix(colour, vec3(1.00, 0.72, 0.50), sky.sunset * 0.55);
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
    vec2 wind = vec2(frameTimeCounter * 0.0075, frameTimeCounter * 0.0028);

    float density = novaCloudDensity(hit, wind, CLOUD_OCTAVES);
    if (density < 0.004) return skyColour;

    // A low value here means this puff has nothing between it and the sun.
    vec2 sunShift = normalize(sky.lightDir.xz + vec2(1.0e-4)) * 130.0;
    float occlusion = novaCloudDensity(hit + sunShift, wind, CLOUD_OCTAVES);
    float lit = saturate(1.0 - occlusion * 1.5 + 0.55);

    vec3 cloudColour = mix(novaCloudShade(sky), novaCloudLit(sky), lit);

    // Rain flattens the whole sheet.
    cloudColour = mix(cloudColour, vec3(luma(cloudColour)) * 0.85, saturate(rainStrength) * 0.70);

    // Towards the horizon the sheet is seen almost edge on, so its noise becomes
    // sub pixel. Pull it towards the mean density there rather than letting it
    // shimmer, and let the sky behind it do the hazing.
    float horizon = 1.0 - smoothstep(0.02, 0.28, direction.y);
    float shaped = mix(density, 0.55, horizon * 0.75);

    float farFade = 1.0 - smoothstep(3000.0, 7000.0, rayLength);
    float alpha = shaped * farFade * (1.0 - horizon * 0.35);

    return mix(skyColour, cloudColour, saturate(alpha));
#endif
}

#endif
