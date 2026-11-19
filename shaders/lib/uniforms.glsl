#ifndef NOVA_UNIFORMS_GLSL
#define NOVA_UNIFORMS_GLSL

/* Iris supplied uniforms.
 *
 * Nothing here is computed by the pack: these are only the declarations, so
 * that every body can rely on the same names and types. Samplers are declared
 * where they are actually sampled, because declaring one is what makes Iris
 * allocate the matching buffer.
 */

uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjectionInverse;

uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform vec3 cameraPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;
uniform vec3 shadowLightPosition;
uniform vec3 fogColor;

uniform float frameTimeCounter;
uniform float rainStrength;

uniform float viewWidth;
uniform float viewHeight;

uniform int isEyeInWater;
uniform vec4 entityColor;

#endif
