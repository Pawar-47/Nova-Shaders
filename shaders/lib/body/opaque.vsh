#ifndef NOVA_BODY_OPAQUE_VSH
#define NOVA_BODY_OPAQUE_VSH

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util.glsl"
#ifdef NOVA_VEGETATION_SWAY
#include "/lib/vegetation.glsl"
#endif

/* Vertex stage for every lit, textured gbuffer program. It hands the fragment
   stage the four things surface shading needs and nothing else: texture
   coordinates, the packed lightmap coordinate, the block tint, the world space
   normal and the position relative to the camera. */

out vec2 vTexCoord;
out vec2 vLightCoord;
out vec4 vTint;
out vec3 vNormal;
out vec3 vPlayerPos;

#if defined(NOVA_VEGETATION_SWAY) || defined(NOVA_WATER_MATERIAL_ID)
in vec2 mc_Entity;
#endif

#ifdef NOVA_WATER_MATERIAL_ID
flat out float vWaterBlock;

float novaWaterVertexHeight(vec2 worldXZ) {
    const vec2 directionA = vec2(0.894427, 0.447214);
    const vec2 directionB = vec2(-0.371391, 0.928477);
    float angleA = mod(dot(directionA, worldXZ) * 0.075 + frameTimeCounter * 0.42, NOVA_TAU);
    float angleB = mod(dot(directionB, worldXZ) * 0.118 - frameTimeCounter * 0.31, NOVA_TAU);
    float waveA = exp(sin(angleA) - 1.0) * 0.5;
    float waveB = exp(sin(angleB) - 1.0) * 0.5;
    return ((waveA - 0.233) * 1.25 + (waveB - 0.233) * 0.72)
         * 0.22 * WATER_WAVE_HEIGHT;
}
#endif

void main() {
    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vec3 playerPos = (gbufferModelViewInverse * viewPos).xyz;

#ifdef NOVA_WATER_MATERIAL_ID
    vWaterBlock = 0.0;
    if (mc_Entity.x == 100.0) {
        vWaterBlock = 1.0;
#if WATER_WAVES == 1
        vec3 worldNormal = normalize(mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal));
        if (worldNormal.y > 0.75) {
            vec3 worldPos = cameraPosition + playerPos;
            float displacement = novaWaterVertexHeight(worldPos.xz);
            viewPos.xyz += mat3(gbufferModelView) * vec3(0.0, displacement, 0.0);
        }
#endif
    }
#endif

#ifdef NOVA_VEGETATION_SWAY
    if (mc_Entity.x == 101.0) {
        vec2 worldXZ = cameraPosition.xz + playerPos.xz;
        vec2 offset = novaVegetationOffset(worldXZ);
        viewPos.xyz += mat3(gbufferModelView) * vec3(offset.x, 0.0, offset.y);
    }
#endif

    gl_Position = gl_ProjectionMatrix * viewPos;

    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    vPlayerPos = (gbufferModelViewInverse * viewPos).xyz;

    // gl_NormalMatrix is the inverse transpose of the model view, so it is the
    // correct transform even where a model is scaled unevenly.
    vNormal = normalize(mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal));

    vTint = gl_Color;
    vTint.rgb = mix(vTint.rgb, entityColor.rgb, saturate(entityColor.a));
}

#endif
