#ifndef NOVA_BODY_SKY_FSH
#define NOVA_BODY_SKY_FSH

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util.glsl"
#include "/lib/sky.glsl"

in vec3 vSkyView;

layout(location = 0) out vec4 fragColor;

/* The whole sky is drawn here: gradient, sunset band, sun disc, moon disc and
   the procedural cloud sheet. Vanilla's sun, moon and clouds are thrown away in
   their own programs, so nothing is drawn twice. */

void main() {
#ifdef NOVA_DISCARD
    // Used by the programs whose vanilla geometry this pack replaces.
    discard;
#else
    vec3 viewDir = normalize(vSkyView + vec3(1.0e-5));
    vec3 dir = normalize(mat3(gbufferModelViewInverse) * viewDir);

    NovaSky sky = novaSkyState();

    vec3 colour = novaSkyGradient(dir, sky);
    colour += novaSunDisc(dir, sky);
    colour += novaMoonDisc(dir, sky);
    colour = novaSkyWithClouds(dir, sky, colour);

    fragColor = vec4(colour, 1.0);
#endif
}

#endif
