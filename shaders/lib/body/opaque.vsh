#ifndef NOVA_BODY_OPAQUE_VSH
#define NOVA_BODY_OPAQUE_VSH

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util.glsl"

/* Vertex stage for every lit, textured gbuffer program. It hands the fragment
   stage the four things surface shading needs and nothing else: texture
   coordinates, the packed lightmap coordinate, the block tint, the world space
   normal and the position relative to the camera. */

out vec2 vTexCoord;
out vec2 vLightCoord;
out vec4 vTint;
out vec3 vNormal;
out vec3 vPlayerPos;

void main() {
    gl_Position = ftransform();

    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vLightCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

    vec4 viewPos = gl_ModelViewMatrix * gl_Vertex;
    vPlayerPos = (gbufferModelViewInverse * viewPos).xyz;

    // gl_NormalMatrix is the inverse transpose of the model view, so it is the
    // correct transform even where a model is scaled unevenly.
    vNormal = normalize(mat3(gbufferModelViewInverse) * (gl_NormalMatrix * gl_Normal));

    vTint = gl_Color;
    vTint.rgb = mix(vTint.rgb, entityColor.rgb, saturate(entityColor.a));
}

#endif
