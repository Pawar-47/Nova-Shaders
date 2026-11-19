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

/* Everything opaque: the ground under the water. The distance to it is the water
   thickness, which is what decides how much of the bottom shows through. */
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

/* Translucent surfaces: water, ice and stained glass all share this program.
 *
 * The body is one dark desaturated teal, lit from the flat quad normal, with a
 * Fresnel weighted sky reflection on top. Ripples live in the reflection and in
 * the thickness, not in the lighting: lighting a wave normal makes water look like
 * waving fabric. */

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

    // vPlayerPos points from the camera to the surface, so the eye vector is just
    // the way back.
    vec3 toEye = normalize(-vPlayerPos);
    float NdotL = max(dot(geometricNormal, sky.lightDir), 0.0);

#ifdef NOVA_HAND
    float shadow = 1.0;
#else
    float shadow = shadowFactor(vPlayerPos, geometricNormal, NdotL);
#endif

    vec3 light = novaSurfaceLight(geometricNormal, NdotL, vLightCoord, shadow, sky);

    // One dark, slightly green water colour, with a quarter of the biome tint kept
    // so that two oceans are not literally identical.
    vec3 baseWater = vec3(0.050, 0.100, 0.110);
    vec3 body = mix(baseWater, albedo.rgb, 0.25) * light;

    // How much sky light reaches this water. Nearly none in a cave or under a roof,
    // so the reflection fades out there too instead of lighting the ceiling blue.
    float skyLevel = novaLightLevel(vLightCoord.y);

    vec3 reflection = novaWaterReflection(toEye, normal, sky);
    float reflectivity = novaFresnel(dot(normal, toEye));
    vec3 colour = mix(body, reflection * (0.25 + 0.75 * skyLevel), reflectivity);

    // Sun and moon glitter, where the reflection meets the light.
    colour += novaSunlight(sky) * novaWaterGlint(toEye, normal, sky) * skyLevel * shadow * 0.55;

    float alpha = albedo.a;

#ifndef NOVA_HAND
    // How much water sits between this pixel and the ground behind it, in blocks.
    float surfaceDistance = novaSceneDistance(gl_FragCoord.z);
    float behind = texture(depthtex1, gl_FragCoord.xy / vec2(viewWidth, viewHeight)).r;
    float thickness = clamp(novaSceneDistance(behind) - surfaceDistance, 0.0, 64.0);

    // Seen from below, the sky is behind the surface and it has to stay readable.
    if (isEyeInWater == 1) thickness *= 0.30;

    // The transparency curve: shallow water shows the bottom clearly through a
    // tinted body, and by about eight blocks nothing below survives. Alpha blending
    // against the already rendered scene is the same operation as sampling it.
    float depthAlpha = 1.0 - 1.0 / (thickness * thickness * 0.16 + 1.125);

    // Horizontal sheets only, so a vertical glass pane keeps vanilla's alpha.
    float sheet = smoothstep(0.55, 0.85, abs(geometricNormal.y));
    alpha = clamp(mix(max(albedo.a, 0.62), depthAlpha, sheet), 0.0, 0.97);
#endif

#ifndef NOVA_HAND
    colour = applyFog(colour, vPlayerPos, sky);
#endif

    fragColor = vec4(colour, alpha);
}

#endif
