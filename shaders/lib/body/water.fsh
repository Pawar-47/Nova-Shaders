#ifndef NOVA_BODY_WATER_FSH
#define NOVA_BODY_WATER_FSH

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util.glsl"
#include "/lib/sky.glsl"
#include "/lib/shadow.glsl"
#include "/lib/lighting.glsl"
#include "/lib/water.glsl"
#include "/lib/fog.glsl"

uniform sampler2D gtexture;

in vec2 vTexCoord;
in vec2 vLightCoord;
in vec4 vTint;
in vec3 vNormal;
in vec3 vPlayerPos;

/* DRAWBUFFERS:0 */

layout(location = 0) out vec4 fragColor;

/* Translucent surfaces: water, ice and stained glass all share this program,
   so the model is a tinted body with a Fresnel weighted sky reflection on top.
   A block with a flat tint (glass) ends up looking like a dark mirror, water
   ends up looking like water. */

void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vTint;
    if (albedo.a < 0.02) discard;

    NovaSky sky = novaSkyState();
    vec3 geometricNormal = normalize(vNormal);

#ifdef NOVA_HAND
    vec3 normal = geometricNormal;
#else
    vec3 normal = novaWaterNormal(vPlayerPos, geometricNormal);
#endif

    // vPlayerPos points from the camera to the surface, so the eye vector is
    // just the way back.
    vec3 toEye = normalize(-vPlayerPos);
    float NdotL = max(dot(normal, sky.lightDir), 0.0);

#ifdef NOVA_HAND
    float shadow = 1.0;
#else
    float shadow = shadowFactor(vPlayerPos, normal, NdotL);
#endif

    vec3 light = novaSurfaceLight(normal, NdotL, vLightCoord, shadow, sky);
    vec3 body = albedo.rgb * light;

    // Deep water eats red first, so the colour under the surface is never just
    // the tinted texture.
    vec3 deepWater = vec3(0.020, 0.075, 0.105) * (0.25 + 0.90 * sky.day);
    body = mix(body, deepWater, 0.40);

    vec3 reflection = novaWaterReflection(toEye, normal, sky);
    float fresnel = novaFresnel(dot(normal, toEye));
    vec3 colour = mix(body, reflection, fresnel);

    // Tight sun glint, and only where the light actually reaches the surface.
    colour += novaSunlight(sky) * novaWaterGlint(toEye, normal, sky) * shadow * 12.0;

#ifndef NOVA_HAND
    colour = applyFog(colour, vPlayerPos, sky);
#endif

    fragColor = vec4(colour, albedo.a);
}

#endif
