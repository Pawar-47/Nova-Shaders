#ifndef NOVA_BODY_SHADOW_VSH
#define NOVA_BODY_SHADOW_VSH

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util.glsl"

/* The shadow pass is rendered from the light, so the same local to clip
   transform as the gbuffer stage puts every vertex in the right place. */

out vec2 vTexCoord;
out vec4 vTint;

void main() {
    gl_Position = ftransform();
    vTexCoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
    vTint = gl_Color;
}

#endif
