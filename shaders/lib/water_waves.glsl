#ifndef NOVA_WATER_WAVES_GLSL
#define NOVA_WATER_WAVES_GLSL

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util.glsl"

/* Shared world-space height and analytic slope. The shorter wavelengths make
   motion survive the one-block spacing of Minecraft's water surface vertices. */
const vec2 NOVA_WATER_DIRECTION_A = vec2(0.894427, 0.447214);
const vec2 NOVA_WATER_DIRECTION_B = vec2(-0.371391, 0.928477);
const vec2 NOVA_WATER_FREQUENCY = vec2(0.48, 0.73);
const vec2 NOVA_WATER_AMPLITUDE = vec2(0.90, 0.55);
const float NOVA_WATER_HEIGHT_SCALE = 0.16;

/* Peak of the wave shape in unscaled units: exp(sin(x) - 1) * 0.5 reaches 0.5 at
   its crest, and the two weighted trains then add up, so the shape tops out here.
   It is subtracted below so that no point of the surface ever lifts. */
const float NOVA_WATER_CREST = 0.3872;

vec2 novaWaterWavePhase(vec2 worldXZ) {
    return vec2(
        mod(dot(NOVA_WATER_DIRECTION_A, worldXZ) * NOVA_WATER_FREQUENCY.x + frameTimeCounter * 0.42, NOVA_TAU),
        mod(dot(NOVA_WATER_DIRECTION_B, worldXZ) * NOVA_WATER_FREQUENCY.y - frameTimeCounter * 0.31, NOVA_TAU)
    );
}

vec2 novaWaterWaveValue(vec2 phase) {
    return exp(sin(phase) - vec2(1.0)) * 0.5;
}

/* The displaced surface never rises above the block top it belongs to: the crest
   sits exactly on the water plane and every other point dips below it.

   That is not a stylistic choice. Only the top face of a water block is moved,
   because the vertical faces are not displaced; a surface that lifts above the
   plane therefore leaves a hairline of empty space between the raised sheet and
   the side face below it, at every shoreline, beach and pool edge. A surface that
   sinks instead stays covered by the side face and reads as swell. */
float novaWaterSurfaceHeight(vec2 worldXZ) {
    vec2 phase = novaWaterWavePhase(worldXZ);
    vec2 wave = novaWaterWaveValue(phase);
    float shape = dot(wave - vec2(0.233), NOVA_WATER_AMPLITUDE);
    return (shape - NOVA_WATER_CREST) * NOVA_WATER_HEIGHT_SCALE * WATER_WAVE_HEIGHT;
}

/* Derivative of the same shape, so the fragment stage shades exactly the surface
   the vertex stage displaced. The constant offset above drops out here. */
vec2 novaWaterSurfaceSlope(vec2 worldXZ) {
    vec2 phase = novaWaterWavePhase(worldXZ);
    vec2 wave = novaWaterWaveValue(phase);
    vec2 derivative = wave * cos(phase) * NOVA_WATER_FREQUENCY * NOVA_WATER_AMPLITUDE;
    return (NOVA_WATER_DIRECTION_A * derivative.x + NOVA_WATER_DIRECTION_B * derivative.y)
         * NOVA_WATER_HEIGHT_SCALE * WATER_WAVE_HEIGHT;
}

#endif
