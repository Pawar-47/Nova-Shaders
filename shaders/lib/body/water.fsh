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

/* Everything opaque: the ground under the water. Reading it back is what lets
   the water know how deep it is. */
uniform sampler2D depthtex1;

in vec2 vTexCoord;
in vec2 vLightCoord;
in vec4 vTint;
in vec3 vNormal;
in vec3 vPlayerPos;

/* DRAWBUFFERS:0 */

layout(location = 0) out vec4 fragColor;

/* Distance from the camera to whatever opaque surface sits behind a fragment, in
   blocks. Unprojecting through the inverse projection is exact and costs one
   matrix multiply. A depth of 1.0 is sky, which lands on the clamp. */
float novaSceneDistance(float depth) {
    vec4 view = gbufferProjectionInverse * vec4(0.0, 0.0, depth * 2.0 - 1.0, 1.0);
    return -view.z / max(abs(view.w), 1.0e-4);
}

/* Translucent surfaces: water, ice and stained glass all share this program, so
   the model is a body with a Fresnel weighted sky reflection on top. The body is
   the biome tint under the light, absorbing into a dark teal with depth. */

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
    float alpha = albedo.a;

#ifndef NOVA_HAND
    // How much water sits between this fragment and the ground behind it. This is
    // what makes water a body rather than a pane of glass: shallow water shows
    // the bottom, deep water absorbs it and turns blue-green.
    float surfaceDistance = novaSceneDistance(gl_FragCoord.z);
    float behind = texture(depthtex1, gl_FragCoord.xy / vec2(viewWidth, viewHeight)).r;
    float thickness = clamp(novaSceneDistance(behind) - surfaceDistance, 0.0, 48.0);
    float depthFactor = saturate(1.0 - exp(-thickness * 0.22));

    // Seen from below, the sky is behind the surface and it has to stay bright.
    if (isEyeInWater == 1) depthFactor *= 0.35;

    // Water is always a horizontal sheet; glass is usually a pane. Keying the
    // depth effect off the surface orientation keeps vertical windows looking
    // like windows while water still gets its body.
    float sheet = smoothstep(0.55, 0.85, abs(geometricNormal.y));
    depthFactor *= sheet;

    vec3 deepBody = vec3(0.013, 0.058, 0.080) * (0.35 + 0.85 * sky.day);
    body = mix(body, deepBody, depthFactor);

    // Shallow water lets the bottom through; by a few blocks nothing does.
    alpha = clamp(mix(albedo.a, mix(albedo.a * 0.85, 0.96, depthFactor), sheet), 0.0, 0.97);
#endif

    vec3 reflection = novaWaterReflection(toEye, normal, sky);
    float fresnel = novaFresnel(dot(normal, toEye));

    // Ripples tilt the surface, so a little more sky reaches the eye than flat
    // water Fresnel suggests. The constant keeps distant water reading as a sheet
    // rather than as a mirror.
    float reflectivity = clamp(fresnel * 1.15 + 0.06, 0.0, 0.92);
    vec3 colour = mix(body, reflection, reflectivity);

    // Sun glint: a broad sheen under a tight sparkle, and only where the light
    // actually reaches the surface.
    colour += novaSunlight(sky) * novaWaterGlint(toEye, normal, sky) * shadow * 5.0;

#ifndef NOVA_HAND
    colour = applyFog(colour, vPlayerPos, sky);
#endif

    fragColor = vec4(colour, alpha);
}

#endif
