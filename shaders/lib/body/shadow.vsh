#ifndef NOVA_BODY_SHADOW_VSH
#define NOVA_BODY_SHADOW_VSH

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util.glsl"
#ifdef NOVA_VEGETATION_SWAY
#include "/lib/vegetation.glsl"
in vec2 mc_Entity;
/* Iris supplies the texture-UV midpoint of the current plant quad. */
in vec2 mc_midTexCoord;
#endif

/* The shadow pass is rendered from the light, so the same local to clip
   transform as the gbuffer stage puts every vertex in the right place. */

out vec2 vTexCoord;
out vec4 vTint;

void main() {
    vec4 shadowPos = gl_ModelViewMatrix * gl_Vertex;
#ifdef NOVA_VEGETATION_SWAY
    vec3 playerPos = (shadowModelViewInverse * shadowPos).xyz;
    vec3 worldPos = cameraPosition + playerPos;
    if (mc_Entity.x == 101.0) {
        float aboveMid = smoothstep(mc_midTexCoord.y - 1.0e-4,
                                    mc_midTexCoord.y + 1.0e-4,
                                    gl_MultiTexCoord0.y);
        vec2 offset = novaVegetationOffset(worldPos) * aboveMid;
        shadowPos.xyz += mat3(shadowModelView) * vec3(offset.x, 0.0, offset.y);
    } else if (mc_Entity.x == 103.0) {
        vec2 offset = novaLeafOffset(worldPos);
        shadowPos.xyz += mat3(shadowModelView) * vec3(offset.x, 0.0, offset.y);
    }
#endif
    gl_Position = gl_ProjectionMatrix * shadowPos;
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vTint = gl_Color;
}

#endif
