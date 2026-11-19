#ifndef NOVA_SETTINGS_GLSL
#define NOVA_SETTINGS_GLSL

/* Nova Shaders - every user facing option lives in this file.
 *
 * A #define followed by a "[...]" list inside its comment becomes a widget in
 * Shader Pack Settings, in the order the values are written. The rest of the
 * pack reads these macros directly, so this file is the single source of truth
 * for the defaults that shaders.properties exposes.
 */

// ------------------------------------------------------------------ Color ---
#define COLOR_EXPOSURE 1.0 // [0.6 0.8 1.0 1.15 1.4 1.7 2.0] Exposure applied before tonemapping. Raise it if the scene looks muddy.
#define COLOR_SATURATION 1.0 // [0.0 0.5 0.75 0.9 1.0 1.1 1.25 1.5 2.0] Colour saturation, applied after tonemapping.
#define COLOR_CONTRAST 1.0 // [0.7 0.8 0.9 1.0 1.1 1.2 1.3] Contrast around mid grey, applied after tonemapping.
#define COLOR_RED 1.0 // [0.5 0.6 0.7 0.8 0.85 0.9 0.95 1.0 1.05 1.1 1.15 1.2 1.3 1.4 1.5] Red channel gain, applied in linear light before tonemapping. 1.0 leaves red untouched.
#define COLOR_GREEN 1.0 // [0.5 0.6 0.7 0.8 0.85 0.9 0.95 1.0 1.05 1.1 1.15 1.2 1.3 1.4 1.5] Green channel gain, applied in linear light before tonemapping. 1.0 leaves green untouched.
#define COLOR_BLUE 1.0 // [0.5 0.6 0.7 0.8 0.85 0.9 0.95 1.0 1.05 1.1 1.15 1.2 1.3 1.4 1.5] Blue channel gain, applied in linear light before tonemapping. 1.0 leaves blue untouched.
#define COLOR_VIGNETTE 0.15 // [0.0 0.15 0.25 0.35 0.5 0.7 1.0] Corner darkening. 0.0 turns it off.
#define COLOR_DITHER 1 // [0 1] Ordered dither on the output, hides banding in sky and fog gradients.
#define ANTI_ALIASING 1 // [0 1] FXAA. Set to 0 if you need the frames more than the edges.

// ------------------------------------------------------------------ Scene ---
#define SUN_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0] Strength of direct sunlight, and of moonlight at night.
#define AMBIENT_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0] Strength of the skylight ambient term.
#define BLOCKLIGHT_STRENGTH 1.0 // [0.25 0.5 0.75 1.0 1.25 1.5 2.0] Strength of warm block light: torches, lava, glowstone.
#define FOG_DENSITY 1.0 // [0.0 0.5 0.75 1.0 1.25 1.5 2.0 3.0] Distance fog thickness. 0.0 removes the fog entirely.
#define FOG_HEIGHT 64.0 // [0.0 32.0 48.0 64.0 80.0 96.0 128.0] Altitude at which the fog is thickest. It thins out above this.
#define CLOUDS 1 // [0 1] Draw the procedural cloud sheet.
#define CLOUD_COVERAGE 0.35 // [0.0 0.2 0.35 0.5 0.7 1.0] How much of the sky the clouds cover. Low values give small scattered puffs.
#define CLOUD_ALTITUDE 180.0 // [120.0 150.0 180.0 220.0 260.0] Height of the cloud sheet in blocks.
#define WATER_WAVES 1 // [0 1] Animate the water surface normal.
#define WATER_WAVE_HEIGHT 1.0 // [0.25 0.5 1.0 1.5 2.0] Height of the two wave trains and the chop.
#define UNDERWATER_TINT 1 // [0 1] Tint the screen while the camera is under water.

// ---------------------------------------------------------------- Quality ---
#define SHADOWS 1 // [0 1] Shadow mapping with four filtered taps. 0 is the single biggest speed win.
#define SHADOW_SOFTNESS 1.0 // [0.5 1.0 1.5 2.0 3.0] Spread of the four shadow lookup taps.
#define CLOUD_OCTAVES 3 // [2 3 4 5] Noise octaves in the clouds. Lower is cheaper and blobbier.

const int shadowMapResolution = 1024; // [512 1024 2048] Shadow map size. 2048 is sharper and noticeably slower.
const float shadowDistance = 96.0; // [48.0 64.0 96.0 128.0 160.0] How far from the camera shadows are drawn.

#endif
