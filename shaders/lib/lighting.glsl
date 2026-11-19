#ifndef NOVA_LIGHTING_GLSL
#define NOVA_LIGHTING_GLSL

#include "/lib/util.glsl"
#include "/lib/sky.glsl"

/* Surface lighting: one directional light from the sky, a near neutral ambient
   term, and a warm block light term. Everything is added up and multiplied into
   the albedo, which stays in display encoded space so the pack only decodes
   once, in the composite pass.
 *
 * The ambient is no longer taken from the sky gradient. Doing that made every
 * shadow and every hillside blue; ambient is now close to neutral, with only a
 * hint of cool in it and a hint of sunset warmth at the edges of the day.
 */

/* Light levels are packed into the lightmap coordinate: each of the sixteen
   texels covers 1/16 of the range, so level L sits at (L + 0.5) / 16. Undoing
   that packing gives the block and sky light levels back without a fetch. */
float novaLightLevel(float coordinate) {
    return clamp(coordinate * 16.0 - 0.5, 0.0, 15.0) / 15.0;
}

/* The sun by day, a weak cold moon by night, both warmed up near the horizon. */
vec3 novaSunlight(NovaSky sky) {
    vec3 warm = mix(vec3(1.00, 0.97, 0.92), vec3(1.00, 0.68, 0.42), sky.sunset * 0.90);
    vec3 colour = mix(vec3(0.34, 0.40, 0.56), warm, sky.day);
    float strength = mix(0.16, 0.62, sky.day);
    return colour * strength * SUN_STRENGTH;
}

/* Daylight ambient. 0.66 is picked so a lit surface lands just above 1.0 and a
   shadowed one around half of that: textures then read as their own colour
   rather than as their colour multiplied by blue. */
vec3 novaAmbient(NovaSky sky) {
    vec3 ambient = mix(vec3(0.030, 0.038, 0.060), vec3(0.64, 0.66, 0.70), sky.day);
    ambient = mix(ambient, vec3(0.64, 0.52, 0.44), sky.sunset * 0.35);
    return ambient * AMBIENT_STRENGTH;
}

/* Warm block light. The squared curve keeps a torch local and still lets lava
   light a cave mouth, without turning the walls orange. */
vec3 novaBlockLight(float level) {
    return vec3(1.00, 0.76, 0.50) * (level * level) * BLOCKLIGHT_STRENGTH;
}

vec3 novaSurfaceLight(vec3 normal, float NdotL, vec2 lightCoord, float shadow, NovaSky sky) {
    float skyLevel = novaLightLevel(lightCoord.y);
    float blockLevel = novaLightLevel(lightCoord.x);

    vec3 direct = novaSunlight(sky) * NdotL * shadow;
    vec3 ambient = novaAmbient(sky) * (skyLevel * skyLevel);
    vec3 block = novaBlockLight(blockLevel);

    // A floor on the light so unlit caves read as dark, not as a black hole.
    vec3 floorLight = vec3(0.010, 0.011, 0.014);

    return direct + ambient + block + floorLight;
}

/* The one call an opaque body needs. */
vec3 applyLighting(vec3 albedo, vec3 normal, vec2 lightCoord, float shadow, NovaSky sky) {
    float NdotL = max(dot(normal, sky.lightDir), 0.0);
    return albedo * novaSurfaceLight(normal, NdotL, lightCoord, shadow, sky);
}

#endif
