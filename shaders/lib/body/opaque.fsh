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
    if (vVegetationBlock > 100.5) {
        vec3 worldPos = cameraPosition + vPlayerPos;
        float patchTone = valueNoise(worldPos.xz * 0.24 + vec2(worldPos.y * 0.015));
        float variation = mix(0.90, 1.10, patchTone);
        float coverage = 1.0;
        if (vVegetationBlock > 101.5) {
            coverage = smoothstep(0.65, 0.90, normalize(vNormal).y);
        }
        albedo.rgb *= mix(1.0, variation, coverage);
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
    vec3 normal = normalize(vNormal);
    float NdotL = max(dot(normal, sky.lightDir), 0.0);

#ifdef NOVA_HAND
    // The first person hand has no meaningful world position, so shadows and
    // fog are skipped rather than sampled from the wrong place.
    float shadow = 1.0;
#else
    float shadow = shadowFactor(vPlayerPos, normal, NdotL);
#endif

    colour = applyLighting(albedo.rgb, normal, vLightCoord, shadow, sky);
#ifdef NOVA_VEGETATION_SWAY
    if (vVegetationBlock > 100.5 && vVegetationBlock < 101.5) {
        float backlit = max(dot(-normal, sky.lightDir), 0.0) * sky.day;
        colour += albedo.rgb * vec3(0.025, 0.10, 0.015)
                * backlit * SUN_STRENGTH * (0.35 + 0.65 * shadow);
    }
#endif
#endif

#ifndef NOVA_HAND
    colour = applyFog(colour, vPlayerPos, sky);
#endif

    fragColor = vec4(colour, albedo.a);
}

#endif
