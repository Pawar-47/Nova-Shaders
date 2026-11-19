#ifndef NOVA_LIGHTING_GLSL
#define NOVA_LIGHTING_GLSL

#include "/lib/util.glsl"
#include "/lib/sky.glsl"

/* Surface lighting: one directional light from the sky, an ambient term taken
   from the sky gradient, and a warm block light term. Everything is added up
   and multiplied into the albedo, which stays in display encoded space so the
   pack only decodes once, in the composite pass. */

/* Light levels are packed into the lightmap coordinate: each of the sixteen
   texels covers 1/16 of the range, so level L sits at (L + 0.5) / 16. Undoing
   that packing gives the block and sky light levels back without a texture
   fetch. */
float novaLightLevel(float coordinate) {
    return clamp(coordinate * 16.0 - 0.5, 0.0, 15.0) / 15.0;
}

/* The sun by day, a weak cold moon by night, both warmed up near the horizon. */
vec3 novaSunlight(NovaSky sky) {
    vec3 warm = mix(vec3(1.00, 0.97, 0.90), vec3(1.00, 0.60, 0.32), sky.sunset * 0.85);
    vec3 colour = mix(vec3(0.22, 0.30, 0.55), warm, sky.day);
    float strength = mix(0.10, 1.0, sky.day);
    return colour * strength * SUN_STRENGTH;
}

/* Ambient light is the sky itself, averaged between what is overhead and what
   bounces off the ground, so shadows pick up the colour of the sky above them. */
vec3 novaAmbient(NovaSky sky) {
    vec3 above = novaSkyGradient(vec3(0.0, 1.0, 0.0), sky);
    vec3 below = novaSkyGradient(vec3(0.0, -1.0, 0.0), sky);
    vec3 ambient = above * 0.85 + below * 0.15;

    ambient = max(ambient, vec3(0.010, 0.012, 0.018));
    return ambient * AMBIENT_STRENGTH;
}

/* Warm block light. The squared curve keeps a torch local and still lets lava
   light a cave mouth. */
vec3 novaBlockLight(float level) {
    return vec3(1.00, 0.72, 0.42) * pow(level, 2.0) * BLOCKLIGHT_STRENGTH;
}

vec3 novaSurfaceLight(vec3 normal, float NdotL, vec2 lightCoord, float shadow, NovaSky sky) {
    float skyLevel = novaLightLevel(lightCoord.y);
    float blockLevel = novaLightLevel(lightCoord.x);

    vec3 direct = novaSunlight(sky) * NdotL * shadow;
    vec3 ambient = novaAmbient(sky) * pow(skyLevel, 1.6);
    vec3 block = novaBlockLight(blockLevel);

    // A floor on the light so unlit caves read as dark, not as a black hole.
    vec3 floorLight = vec3(0.008, 0.010, 0.016);

    return direct + ambient + block + floorLight;
}

/* The one call an opaque body needs. */
vec3 applyLighting(vec3 albedo, vec3 normal, vec2 lightCoord, float shadow, NovaSky sky) {
    float NdotL = max(dot(normal, sky.lightDir), 0.0);
    return albedo * novaSurfaceLight(normal, NdotL, lightCoord, shadow, sky);
}

#endif
