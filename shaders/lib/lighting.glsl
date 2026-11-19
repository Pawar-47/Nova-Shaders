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
    float strength = mix(0.16, 0.58, sky.day);
    return colour * strength * SUN_STRENGTH;
}

/* Hemisphere ambient: cool skylight from above, warm bounce off the ground.
 *
 * Taking ambient from the normal instead of a flat colour is what stops a hillside
 * and its shaded side reading as the same slab, and it is why grass and leaves
 * have a soft gradient instead of one value. Both ends are kept close to neutral,
 * so the colour still comes from the texture.
 */
vec3 novaAmbient(NovaSky sky, vec3 normal) {
    vec3 fromSky = vec3(0.60, 0.66, 0.74);
    vec3 fromGround = vec3(0.56, 0.52, 0.46);
    float up = normal.y * 0.5 + 0.5;

    vec3 day = mix(fromGround, fromSky, up);
    vec3 ambient = mix(vec3(0.030, 0.038, 0.060), day, sky.day);
    ambient = mix(ambient, vec3(0.60, 0.50, 0.42), sky.sunset * 0.30);

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

    // A small wrap term softens the terminator: a real surface does not go from
    // full sun to full shade across one polygon edge, and this is most of what
    // makes vegetation and mobs look rounded rather than faceted.
    float wrapped = clamp((NdotL + 0.18) / 1.18, 0.0, 1.0);

    vec3 direct = novaSunlight(sky) * wrapped * shadow;
    vec3 ambient = novaAmbient(sky, normal) * (skyLevel * skyLevel);
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
