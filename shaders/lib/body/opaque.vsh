#ifndef NOVA_BODY_OPAQUE_VSH
#define NOVA_BODY_OPAQUE_VSH

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util.glsl"
#ifdef NOVA_WATER_MATERIAL_ID
#include "/lib/water_waves.glsl"
#endif
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
#endif

#ifdef NOVA_VEGETATION_SWAY
flat out float vVegetationBlock;
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
            float displacement = novaWaterSurfaceHeight(worldPos.xz);
            viewPos.xyz += mat3(gbufferModelView) * vec3(0.0, displacement, 0.0);
        }
#endif
    }
#endif

#ifdef NOVA_VEGETATION_SWAY
    vVegetationBlock = mc_Entity.x;
    if (mc_Entity.x == 101.0) {
        vec3 worldPos = cameraPosition + playerPos;
        vec2 offset = novaVegetationOffset(worldPos);
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
