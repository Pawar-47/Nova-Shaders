#ifndef NOVA_BODY_COMPOSITE_FSH
#define NOVA_BODY_COMPOSITE_FSH

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util.glsl"

/* Keep the scene in a half float target. The tonemapper needs values above 1.0
   to roll off; in an 8 bit buffer every highlight would already be clipped
   before this pass ever saw it, and so would the bloom below, which is built
   entirely out of the excess over white. */
const int colortex0Format = RGBA16F;

uniform sampler2D colortex0;

/* Bloom.
 *
 * The sun disc, the moon, water glitter and emissive blocks are written above
 * 1.0, and the only thing above white is highlight. Eight taps on two rings
 * collect that excess and add it back as a glow, which turns the sun from a flat
 * white coin into a disc with light around it and keeps bright edges from ending
 * as a hard cut. The taps sit on a coarse ring on purpose: a glow is low
 * frequency by nature, so a wide ring costs nothing in fidelity and saves the
 * sixteen taps an inner ring would need.
 *
 * This only works because colortex0 is RGBA16F. In an 8 bit buffer every tap
 * reads at most 1.0, the excess is zero everywhere, and this function returns
 * black.
 */
const vec2 BLOOM_TAPS[8] = vec2[8](
    vec2( 2.1,  0.0),
    vec2(-2.1,  0.0),
    vec2( 0.0, -2.1),
    vec2( 0.0,  2.1),
    vec2( 3.4,  3.4),
    vec2(-3.4, -3.4),
    vec2( 3.4, -3.4),
    vec2(-3.4,  3.4)
);

vec3 novaBloom(vec2 uv, vec2 texel) {
    vec3 excess = vec3(0.0);
    for (int i = 0; i < 8; i++) {
        vec3 tap = texture(colortex0, uv + BLOOM_TAPS[i] * texel).rgb;
        excess += max(tap - vec3(0.92), vec3(0.0));
    }
    // The average stays display encoded like the rest of the buffer, so it is
    // decoded here, once, rather than eight times inside the loop.
    return sRGBToLinear(excess * 0.125);
}

/* Reads colortex0 and writes it back; the loader keeps two buffers per
   attachment so that is a legal ping-pong rather than a feedback loop. */
/* RENDERTARGETS: 0 */

layout(location = 0) out vec4 fragColor;

/* Under water red is absorbed first, and the contrast drops with it. */
vec3 underwaterGrade(vec3 linearColour) {
    linearColour *= vec3(0.55, 0.86, 0.95);
    linearColour += vec3(0.000, 0.008, 0.016);
    return linearColour;
}

void main() {
    // The house white balance: the filmic curve lifts the blue channel a little on
    // its own, and this keeps daylight reading as daylight.
    const vec3 WHITE_BALANCE = vec3(1.030, 1.000, 0.975);

    // The three channel gains from Shader Pack Settings sit on top of it, in
    // linear light and before the tonemapper. That is what makes them a channel
    // correction rather than a brightness control: 1.0 leaves a channel alone,
    // 0.8 pulls it back, 1.2 pushes it.
    vec3 channels = vec3(COLOR_RED, COLOR_GREEN, COLOR_BLUE);

    vec2 texel = 1.0 / vec2(viewWidth, viewHeight);
    vec2 uv = gl_FragCoord.xy * texel;
    vec3 scene = texture(colortex0, uv).rgb;

    // The gbuffer shaders write display encoded colour, so decode before
    // grading: exposure and tonemapping only mean anything in linear light.
    vec3 colour = sRGBToLinear(scene) * COLOR_EXPOSURE;
    colour *= WHITE_BALANCE * channels;

#if UNDERWATER_TINT == 1
    if (isEyeInWater == 1) colour = underwaterGrade(colour);
#endif

    // After the exposure and the channel gains, so the glow answers to them too,
    // and before the tonemapper, so it rolls off with the rest of the highlight.
    if (BLOOM_STRENGTH > 0.0) {
        colour += novaBloom(uv, texel) * BLOOM_STRENGTH;
    }

    colour = acesTonemap(colour);
    colour = linearToSRGB(colour);

    // Saturation and contrast are look controls, so they act on the displayed
    // image where the eye expects them.
    float grey = luma(colour);
    colour = mix(vec3(grey), colour, COLOR_SATURATION);
    colour = (colour - 0.5) * COLOR_CONTRAST + 0.5;

    fragColor = vec4(saturate(colour), 1.0);
}

#endif
