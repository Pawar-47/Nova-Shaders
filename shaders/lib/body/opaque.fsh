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

    // Vanilla renders cutout geometry with an alpha test that does not exist on
    // modern OpenGL, so the discard has to happen here. The threshold rides a
    // stable ordered dither, which turns a staircased cutout edge into a soft
    // fringe, and it creeps up with distance to drop the single texels that would
    // otherwise pop in and out as the camera moves. Vegetation is where both of
    // those show up most.
    float cutoutNoise = novaDither(gl_FragCoord.xy) * 0.06;
    float cutoutThreshold = mix(0.10, 0.17, saturate(length(vPlayerPos) / 96.0));
    if (albedo.a < cutoutThreshold + cutoutNoise) discard;
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
#endif

#ifndef NOVA_HAND
    colour = applyFog(colour, vPlayerPos, sky);
#endif

    fragColor = vec4(colour, albedo.a);
}

#endif
