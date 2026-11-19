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

    vec3 zenith = mix(vec3(0.020, 0.023, 0.030), vec3(0.36, 0.50, 0.67), sky.day);
    vec3 horizon = mix(vec3(0.050, 0.055, 0.070), vec3(0.75, 0.80, 0.83), sky.day);

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

/* Cloud density at one point in the slab.
 *
 * g is the height inside the slab, 0 at the base and 1 at the top. The threshold
 * rises with height, and that is what turns a noise field into cumulus: near the
 * base almost half of the field is dense, so the bottoms are flat and continuous;
 * by the top only the tallest peaks survive, so the crowns break into separate
 * rounded puffs. The union of those silhouettes is what reads as fluffy.
 *
 * There is no domain warping. Warping a noise field every frame is exactly what
 * makes clouds shear, swim and look distorted.
 */
float novaCloudDensityAt(vec2 worldXZ, float g, float detail, vec2 wind) {
    // One octave for the mass, at roughly seventy blocks per cell.
    vec2 p = worldXZ * 0.0143 + wind;
    float mass = valueNoise(p);

    // A weak, faster field for rag on the edges. Kept weak on purpose: a heavy
    // detail term chews the silhouette up.
    mass += (detail - 0.5) * 0.10;

    float threshold = mix(0.62, 0.38, saturate(CLOUD_COVERAGE)) + smoothstep(0.18, 1.0, g) * 0.30;
    float density = saturate((mass - threshold) * 1.8);

    // Keep a soft shelf at the base and erode the top into rounded crowns. The
    // compact height profile is adapted from Spectrum's MIT cloud density work;
    // its 3D noise textures and multi-ray lighting are deliberately not ported.
    density *= mix(0.55, 1.0, smoothstep(0.0, 0.18, g));
    density *= 1.0 - 0.24 * g * g;

    // Soft saturation keeps thin edges wispy while the cores approach a solid tone.
    return density * inversesqrt(density * density + 0.45);
}

/* The shaded side of a cloud: a cool slate blue, never black. */
vec3 novaCloudShade(NovaSky sky) {
    vec3 colour = mix(vec3(0.040, 0.050, 0.070), vec3(0.28, 0.31, 0.36), sky.day);
    return mix(colour, vec3(0.52, 0.40, 0.32), sky.sunset * 0.45);
}

/* The sun facing side: a slightly blue white. */
vec3 novaCloudLit(NovaSky sky) {
    vec3 colour = vec3(1.08, 1.09, 1.12) * (0.12 + 0.88 * sky.day);
    return mix(colour, vec3(1.00, 0.76, 0.55), sky.sunset * 0.60);
}

/* Compact Henyey-Greenstein-like phase term, adapted from the cloud scattering
   model in Spectrum's MIT-licensed clouds3D.fsh. This uses one inverse square
   root per pixel instead of Spectrum's view and sun ray marches.
 */
float novaCloudPhase(float cosine) {
    const float anisotropy = 0.42;
    float denominator = max(1.0 + anisotropy * anisotropy - 2.0 * anisotropy * cosine, 0.05);
    return min((1.0 - anisotropy * anisotropy)
             * inversesqrt(denominator * denominator * denominator) * 0.075, 1.0);
}

/* Draw the clouds.
 *
 * They are a slab, not a painted dome. The ray is intersected with the bottom and
 * the top of the slab and walked through it in a handful of steps, accumulating a
 * transmittance and a light in front to back order. That is what gives a deck depth:
 * back puffs are genuinely hidden behind front ones, and the accumulation produces a
 * continuous tonal ramp across a puff instead of one flat tone.
 *
 * The lighting is analytic per sample - dark base, bright crown, thick cores greyed
 * out - plus a forward scattering lift when the view points near the light. No
 * shadow lookups and no per-sample light march, which is what keeps this affordable
 * on integrated graphics.
 */
vec3 novaSkyWithClouds(vec3 direction, NovaSky sky, vec3 skyColour) {
#if CLOUDS == 0
    return skyColour;
#else
    float dirY = direction.y;
    if (abs(dirY) < 1.0e-3) return skyColour;

    // The slab: sixty blocks thick, sitting on CLOUD_ALTITUDE.
    const float slabThickness = 60.0;
    float baseY = CLOUD_ALTITUDE;
    float camY = cameraPosition.y;

    // Where the ray enters and leaves the slab, whether the camera is below,
    // inside or above the clouds.
    float tBottom = (baseY - camY) / dirY;
    float tTop = (baseY + slabThickness - camY) / dirY;
    float tNear = max(min(tBottom, tTop), 0.0);
    float tFar = max(tBottom, tTop);

    // Past this the deck is smaller than a pixel; cutting it here stops the
    // skyline smearing.
    const float farLimit = 6000.0;
    if (tNear > farLimit) return skyColour;
    tFar = min(tFar, farLimit);
    if (tFar <= tNear) return skyColour;

    vec2 wind = vec2(frameTimeCounter * 0.0200, frameTimeCounter * 0.0080);
    float stepLength = (tFar - tNear) / float(CLOUD_STEPS);

    // The fine detail is sampled once, midway: it only has to rag the threshold, it
    // does not have to travel with every step.
    vec2 midPoint = cameraPosition.xz + direction.xz * (tNear + tFar) * 0.5;
    float detail = valueNoise(midPoint * 0.0600 + wind);

    // Ordered dither on the first sample so the steps read as grain, not as rings.
    float t = tNear + stepLength * (novaDither(gl_FragCoord.xy) + 0.5);

    // Evaluate the phase only if this ray encounters cloud density; most empty
    // sky rays then avoid the inverse-square-root cost entirely.
    float scattering = 0.0;
    bool scatteringComputed = false;

    float transmittance = 1.0;
    float absorbed = 0.0;
    float lit = 0.0;

    for (int i = 0; i < CLOUD_STEPS; i++) {
        float sampleY = camY + dirY * t;
        float g = saturate((sampleY - baseY) / slabThickness);

        vec2 p = cameraPosition.xz + direction.xz * t;
        float density = novaCloudDensityAt(p, g, detail, wind);

        if (density > 0.004) {
            if (!scatteringComputed) {
                scattering = novaCloudPhase(dot(-direction, sky.lightDir));
                scatteringComputed = true;
            }

            // Dark base, bright crown, thick cores grey. sqrt is the cheap stand in
            // for pow(g, 1.5).
            float heightLight = 0.20 + 0.80 * (g * sqrt(g));
            heightLight *= 1.0 - density * 0.42;
            heightLight = mix(heightLight, 1.0, scattering * 0.65);

            float absorb = 1.0 - exp(-density * stepLength * 0.075);
            lit += heightLight * absorb * transmittance;
            absorbed += absorb * transmittance;
            transmittance *= 1.0 - absorb;

            if (transmittance < 0.03) break;
        }

        t += stepLength;
    }

    float alpha = 1.0 - transmittance;
    if (alpha < 0.004) return skyColour;

    vec3 cloudColour = mix(novaCloudShade(sky), novaCloudLit(sky), saturate(lit / max(absorbed, 1.0e-4)));
    cloudColour = mix(cloudColour, vec3(luma(cloudColour)) * 0.85, saturate(rainStrength) * 0.70);

    // Soften the skirt: this thins the outer few percent of every puff to nothing
    // while the cores stay solid, which is most of the "soft" in soft edges.
    alpha *= sqrt(alpha);

    // Grazing rays skim the slab instead of entering it: fade them out rather than
    // letting the deck smear along the skyline.
    alpha *= smoothstep(0.004, 0.045, abs(dirY));

    return mix(skyColour, cloudColour, saturate(alpha));
#endif
}

#endif
