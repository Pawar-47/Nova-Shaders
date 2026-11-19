#ifndef NOVA_BODY_COMPOSITE_FSH
#define NOVA_BODY_COMPOSITE_FSH

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util.glsl"

/* Keep the scene in a half float target. The tonemapper needs values above 1.0
   to roll off; in an 8 bit buffer every highlight would already be clipped
   before this pass ever sees it. */

/*
const int colortex0Format = RGBA16F;
*/

uniform sampler2D colortex0;

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

    vec2 uv = gl_FragCoord.xy / vec2(viewWidth, viewHeight);
    vec3 scene = texture(colortex0, uv).rgb;

    // The gbuffer shaders write display encoded colour, so decode before
    // grading: exposure and tonemapping only mean anything in linear light.
    vec3 colour = sRGBToLinear(scene) * COLOR_EXPOSURE;
    colour *= WHITE_BALANCE * channels;

#if UNDERWATER_TINT == 1
    if (isEyeInWater == 1) colour = underwaterGrade(colour);
#endif

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
