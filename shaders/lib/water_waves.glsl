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
const float NOVA_WATER_HEIGHT_SCALE = 0.22;

vec2 novaWaterWavePhase(vec2 worldXZ) {
    return vec2(
        mod(dot(NOVA_WATER_DIRECTION_A, worldXZ) * NOVA_WATER_FREQUENCY.x + frameTimeCounter * 0.42, NOVA_TAU),
        mod(dot(NOVA_WATER_DIRECTION_B, worldXZ) * NOVA_WATER_FREQUENCY.y - frameTimeCounter * 0.31, NOVA_TAU)
    );
}

vec2 novaWaterWaveValue(vec2 phase) {
    return exp(sin(phase) - vec2(1.0)) * 0.5;
}

float novaWaterSurfaceHeight(vec2 worldXZ) {
    vec2 phase = novaWaterWavePhase(worldXZ);
    vec2 wave = novaWaterWaveValue(phase);
    return dot(wave - vec2(0.233), NOVA_WATER_AMPLITUDE)
         * NOVA_WATER_HEIGHT_SCALE * WATER_WAVE_HEIGHT;
}

vec2 novaWaterSurfaceSlope(vec2 worldXZ) {
    vec2 phase = novaWaterWavePhase(worldXZ);
    vec2 wave = novaWaterWaveValue(phase);
    vec2 derivative = wave * cos(phase) * NOVA_WATER_FREQUENCY * NOVA_WATER_AMPLITUDE;
    return (NOVA_WATER_DIRECTION_A * derivative.x + NOVA_WATER_DIRECTION_B * derivative.y)
         * NOVA_WATER_HEIGHT_SCALE * WATER_WAVE_HEIGHT;
}

#endif
