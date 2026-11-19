#ifndef NOVA_BODY_SHADOW_FSH
#define NOVA_BODY_SHADOW_FSH

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util.glsl"

uniform sampler2D gtexture;

/* The shadow target only stores depth, but declaring the colour attachment
   keeps the draw framebuffer complete on every driver, and gives this program
   somewhere to write its single output. Nothing samples it in 0.1.0: it is
   reserved for coloured shadows later on. */
uniform sampler2D shadowcolor0;

in vec2 vTexCoord;
in vec4 vTint;

/* DRAWBUFFERS:0 */

layout(location = 0) out vec4 fragColor;

/* Cutout geometry still has to discard its transparent texels here, or leaves
   and grass would cast solid cubes of shadow. */

void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vTint;
    if (albedo.a < novaAlphaCoverageThreshold(gl_FragCoord.xy)) discard;

    fragColor = vec4(1.0);
}

#endif
