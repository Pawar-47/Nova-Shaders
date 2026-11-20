#ifndef NOVA_BODY_OPAQUE_FSH
#define NOVA_BODY_OPAQUE_FSH

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util.glsl"
#include "/lib/sky.glsl"
#include "/lib/shadow.glsl"
#include "/lib/lighting.glsl"
#include "/lib/fog.glsl"

uniform sampler2D gtexture;

in vec2 vTexCoord;
in vec2 vLightCoord;
in vec4 vTint;
in vec3 vNormal;
in vec3 vPlayerPos;
#ifdef NOVA_VEGETATION_SWAY
flat in float vVegetationBlock;
#endif

/* Everything this pack needs lives in one colour buffer. Saying so keeps the
   other seven attachments unbound, which is worth real milliseconds on an
   integrated GPU. */
/* DRAWBUFFERS:0 */

layout(location = 0) out vec4 fragColor;

/* Emissive geometry is pushed above 1.0 and left for the tonemapper, which
   keeps it bright without clipping it into a flat white blob. */
const float EMISSIVE_GAIN = 2.2;

void main() {
#ifdef NOVA_BASIC
    // Untextured geometry (lease, block outline): the vertex colour is all
    // there is, and its alpha carries the vanilla blend.
    vec4 albedo = vTint;
#else
    vec4 albedo = texture(gtexture, vTexCoord) * vTint;

#ifdef NOVA_VEGETATION_SWAY
    // 101 plants, 102 grass blocks, 103 leaves, 104 logs. Only 101 is also bent in
    // the vertex stage: a leaf, grass or log block is a full cube, and shearing one
    // around its sprite midpoint pulls it away from the six blocks beside it.
    bool isPlant = abs(vVegetationBlock - 101.0) < 0.5;
    bool isGrassBlock = abs(vVegetationBlock - 102.0) < 0.5;
    bool isLeaves = abs(vVegetationBlock - 103.0) < 0.5;
    bool isLog = abs(vVegetationBlock - 104.0) < 0.5;

    vec3 foliagePos = cameraPosition + vPlayerPos;
    float geometricUp = normalize(vNormal).y;

    if (isPlant || isLeaves || isGrassBlock) {
        // One low frequency field across the whole world, so a canopy reads as a
        // set of patches instead of one repeated tone per block. Foliage otherwise
        // shows the same value on every leaf block in a tree.
        float patchTone = valueNoise(foliagePos.xz * 0.24 + vec2(foliagePos.y * 0.015));
        float coverage = (isPlant || isLeaves) ? 1.0
                       : smoothstep(0.65, 0.90, geometricUp);
        albedo.rgb *= mix(1.0, mix(0.90, 1.10, patchTone), coverage);
    }
#endif

#ifndef NOVA_TRANSLUCENT_ENTITIES
#ifdef NOVA_ALPHA_COVERAGE
    // Terrain cutouts use stable ordered coverage dithering at distance.
    float distanceFade = smoothstep(12.0, 96.0, length(vPlayerPos));
    float cutoutThreshold = mix(0.5, novaAlphaCoverageThreshold(gl_FragCoord.xy), distanceFade);
    if (albedo.a < cutoutThreshold) discard;
#else
    // Preserve the prior low cutoff for other opaque programs; their textures can
    // contain partial alpha for effects that are not terrain cutouts.
    float cutoutNoise = novaDither(gl_FragCoord.xy) * 0.06;
    float cutoutThreshold = mix(0.10, 0.17, saturate(length(vPlayerPos) / 96.0));
    if (albedo.a < cutoutThreshold + cutoutNoise) discard;
#endif
#endif
#endif

    NovaSky sky = novaSkyState();
    vec3 colour;

#ifdef NOVA_UNLIT
    colour = albedo.rgb * EMISSIVE_GAIN;
#else
    vec3 geometricNormal = normalize(vNormal);
    vec3 normal = geometricNormal;

#ifdef NOVA_VEGETATION_SWAY
    // Foliage has no geometry of its own: every leaf face is one flat quad, so
    // vanilla's per-vertex light leaves a leaf block reading as a painted cube.
    // Tilting the normal with a world space noise field gives the surface micro
    // relief, so the sun breaks across a canopy instead of filling it with a
    // single tone. Bark gets the same treatment with a vertically stretched field,
    // which is what turns a trunk from a flat slab into a rough cylinder.
    if (isPlant || isLeaves) {
        // One perturbation cell is a little under a block, which is coarse enough
        // not to shimmer at distance and fine enough that a one block leaf face is
        // not one flat value. The gradient version costs the same four hashes as
        // the tone patch above, so the relief is effectively free.
        vec3 relief = valueNoiseGradient(foliagePos.xz * 1.40 + vec2(foliagePos.y * 1.05));
        normal = normalize(normal + vec3(relief.y, 0.0, relief.z) * 0.42);
    } else if (isGrassBlock && geometricUp > 0.75) {
        vec3 relief = valueNoiseGradient(foliagePos.xz * 1.20);
        normal = normalize(normal + vec3(relief.y, 0.0, relief.z) * 0.18);
    } else if (isLog && abs(geometricUp) < 0.70) {
        // Stretched along the trunk: fast around it, slow up it, which is what bark
        // is. A field that varied just as fast vertically would band at every block
        // boundary instead of running down the trunk.
        vec3 relief = valueNoiseGradient(vec2(foliagePos.x * 1.5 + foliagePos.z * 1.5,
                                              foliagePos.y * 0.85));
        normal = normalize(normal + vec3(relief.y, relief.z, -relief.y) * 0.26);
    }
#endif

    // applyLighting derives its own NdotL from the relief normal below.
#ifdef NOVA_HAND
    // The first person hand has no meaningful world position, so shadows and
    // fog are skipped rather than sampled from the wrong place.
    float shadow = 1.0;
#else
    // The shadow lookup uses the geometric normal for both the offset and the
    // slope: feeding it the noise relief would widen the bias on every tilted leaf
    // and let daylight straight through a canopy.
    float shadow = shadowFactor(vPlayerPos, geometricNormal,
                                max(dot(geometricNormal, sky.lightDir), 0.0));
#endif

    colour = applyLighting(albedo.rgb, normal, vLightCoord, shadow, sky);
#ifdef NOVA_VEGETATION_SWAY
    if (isPlant || isLeaves) {
        // A leaf is a thin sheet, not a solid: light that enters one side leaves
        // the other, greener for the chlorophyll it crossed. Without this term a
        // leaf mass under a bright sky is only its own texture multiplied by shadow,
        // which is most of why a canopy reads as a flat green slab.
        float backlit = max(dot(-normal, sky.lightDir), 0.0) * sky.day;
        float thinness = isLeaves ? 1.0 : 0.75;
        colour += albedo.rgb * vec3(0.10, 0.26, 0.06) * backlit * thinness
                * SUN_STRENGTH * (0.30 + 0.70 * shadow);
    }
#endif
#endif

#ifndef NOVA_HAND
    colour = applyFog(colour, vPlayerPos, sky);
#endif

    fragColor = vec4(colour, albedo.a);
}

#endif
