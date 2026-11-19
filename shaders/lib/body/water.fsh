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
#ifdef NOVA_WATER_MATERIAL_ID
flat in float vWaterBlock;
#endif

/* DRAWBUFFERS:0 */

layout(location = 0) out vec4 fragColor;

/* Distance from the camera to whatever opaque surface sits behind a fragment, in
   blocks. Unprojecting through the inverse projection is exact and costs one
   matrix multiply. A depth of 1.0 is sky, which lands on the clamp. */
float novaSceneDistance(float depth) {
    vec4 view = gbufferProjectionInverse * vec4(0.0, 0.0, depth * 2.0 - 1.0, 1.0);
    return -view.z / max(abs(view.w), 1.0e-4);
}

/* Translucent surfaces: water, ice and stained glass share this program. Water
   alone receives the depth-driven medium treatment on near-horizontal sheets. */
void main() {
    vec4 albedo = texture(gtexture, vTexCoord) * vTint;
    if (albedo.a < 0.02) discard;

    NovaSky sky = novaSkyState();
    vec3 geometricNormal = normalize(vNormal);

#ifdef NOVA_HAND
    vec3 normal = geometricNormal;
#elif defined(NOVA_WATER_MATERIAL_ID)
    // Only actual water receives wave normals; ice and glass retain their shape.
    vec3 normal = vWaterBlock > 0.5
        ? novaWaterNormal(cameraPosition + vPlayerPos, geometricNormal)
        : geometricNormal;
#else
    vec3 normal = novaWaterNormal(cameraPosition + vPlayerPos, geometricNormal);
#endif

    vec3 toEye = normalize(-vPlayerPos);
    float NdotL = max(dot(geometricNormal, sky.lightDir), 0.0);

#ifdef NOVA_HAND
    float shadow = 1.0;
#else
    float shadow = shadowFactor(vPlayerPos, geometricNormal, NdotL);
#endif

    vec3 light = novaSurfaceLight(geometricNormal, NdotL, vLightCoord, shadow, sky);
    float thickness = 0.0;
    float sheet = 0.0;

#ifndef NOVA_HAND
    // How much water sits between this pixel and the ground behind it, in blocks.
    float surfaceDistance = novaSceneDistance(gl_FragCoord.z);
    float behind = texture(depthtex1, gl_FragCoord.xy / vec2(viewWidth, viewHeight)).r;
    thickness = clamp(novaSceneDistance(behind) - surfaceDistance, 0.0, 64.0);

    // Seen from below, the sky is behind the surface and it has to stay readable.
    if (isEyeInWater == 1) thickness *= 0.30;

    // Vertical faces keep vanilla's translucency; only water-like sheets get depth.
    sheet = smoothstep(0.55, 0.85, abs(geometricNormal.y));
#ifdef NOVA_WATER_MATERIAL_ID
    sheet *= vWaterBlock;
#endif
#endif

    // Keep a restrained biome contribution, then absorb it through the water column.
    vec3 baseWater = mix(vec3(0.050, 0.100, 0.110), albedo.rgb, 0.25);
    vec3 mediumWater = novaWaterMedium(baseWater, thickness);
    vec3 body = mix(baseWater, mediumWater, sheet) * light;

    // Reflections fade in dark interiors instead of lighting their ceilings blue.
    float skyLevel = novaLightLevel(vLightCoord.y);
    vec3 reflection = novaWaterReflection(toEye, normal, sky);
    float reflectivity = novaFresnel(dot(normal, toEye));
    vec3 colour = mix(body, reflection * (0.25 + 0.75 * skyLevel), reflectivity);

    // Sun and moon glitter, where the reflection meets the light.
    colour += novaSunlight(sky) * novaWaterGlint(toEye, normal, sky) * skyLevel * shadow * 0.55;

    float alpha = albedo.a;
#ifndef NOVA_HAND
    // The scalar blend approximates the mean of the per-channel transmittance;
    // a stronger floor keeps shallow water visibly tinted rather than clear.
    float depthAlpha = max(0.82, novaWaterOpacity(thickness));
    alpha = clamp(mix(max(albedo.a, 0.82), depthAlpha, sheet), 0.0, 0.97);
    colour = applyFog(colour, vPlayerPos, sky);
#endif

    fragColor = vec4(colour, alpha);
}

#endif
