#ifndef NOVA_UTIL_GLSL
#define NOVA_UTIL_GLSL

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"

/* Small toolbox shared by every program: colour space, the tonemap curve and
   the noise the clouds, water and dither are built from. No state, no side
   effects, nothing here knows about the scene. */

const float NOVA_PI = 3.14159265;
const float NOVA_TAU = 6.28318531;

float saturate(float x) { return clamp(x, 0.0, 1.0); }
vec2 saturate(vec2 x) { return clamp(x, vec2(0.0), vec2(1.0)); }
vec3 saturate(vec3 x) { return clamp(x, vec3(0.0), vec3(1.0)); }

float luma(vec3 colour) { return dot(colour, vec3(0.2126, 0.7152, 0.0722)); }

/* Display encoded colour in, linear light out. */
vec3 sRGBToLinear(vec3 colour) {
    colour = max(colour, vec3(0.0));
    vec3 low = colour * (1.0 / 12.92);
    vec3 high = pow((colour + 0.055) * (1.0 / 1.055), vec3(2.4));
    return mix(low, high, step(vec3(0.04045), colour));
}

/* Linear light in, display encoded colour out. */
vec3 linearToSRGB(vec3 colour) {
    colour = max(colour, vec3(0.0));
    vec3 low = colour * 12.92;
    vec3 high = pow(colour, vec3(1.0 / 2.4)) * 1.055 - 0.055;
    return mix(low, high, step(vec3(0.0031308), colour));
}

/* Narkowicz' polynomial fit of the ACES filmic curve. Cheap, and it rolls the
   highlights off gradually instead of clipping them into flat white. */
vec3 acesTonemap(vec3 colour) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    vec3 numerator = colour * (a * colour + b);
    vec3 denominator = colour * (c * colour + d) + e;
    return clamp(numerator / denominator, 0.0, 1.0);
}

/* One hash for all procedural detail in the pack. It avoids sin() so it keeps
   working in far away coordinates instead of collapsing into bands. */
float novaHash(vec2 p) {
    vec3 q = fract(vec3(p.x, p.y, p.x + p.y) * vec3(0.1031, 0.1030, 0.0973));
    q += dot(q, q.yzx + 31.17);
    return fract((q.x + q.z) * q.y);
}

/* Smoothly interpolated value noise on a unit grid. */
float valueNoise(vec2 p) {
    vec2 cell = floor(p);
    vec2 local = fract(p);
    vec2 weight = local * local * (3.0 - 2.0 * local);

    float a = novaHash(cell);
    float b = novaHash(cell + vec2(1.0, 0.0));
    float c = novaHash(cell + vec2(0.0, 1.0));
    float d = novaHash(cell + vec2(1.0, 1.0));

    return mix(mix(a, b, weight.x), mix(c, d, weight.x), weight.y);
}

/* Fractal sum of value noise. Each octave is rotated so the grid never shows
   up as axis aligned squares, which is the giveaway of a cheap noise field. */
float fbm(vec2 p, int octaves) {
    mat2 turn = mat2(0.80, 0.60, -0.60, 0.80);

    float sum = 0.0;
    float norm = 0.0;
    float amplitude = 0.5;

    for (int i = 0; i < octaves; i++) {
        sum += valueNoise(p) * amplitude;
        norm += amplitude;
        p = turn * p * 2.03;
        amplitude *= 0.5;
    }

    return sum / max(norm, 1.0e-4);
}

#endif
