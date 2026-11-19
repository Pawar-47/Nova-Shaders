#ifndef NOVA_BODY_FINAL_FSH
#define NOVA_BODY_FINAL_FSH

#include "/lib/settings.glsl"
#include "/lib/uniforms.glsl"
#include "/lib/util.glsl"

uniform sampler2D colortex0;

layout(location = 0) out vec4 fragColor;

/* Edge directed anti-aliasing.
 *
 * The luma of a 2x2 neighbourhood tells us whether there is an edge here and
 * which way it runs. Only edge pixels are blurred, and they are blurred along
 * the edge rather than across it, which is what keeps texture detail intact. */

const float FXAA_EDGE_THRESHOLD = 0.125;
const float FXAA_EDGE_THRESHOLD_MIN = 0.0312;

vec3 novaAntiAlias(vec2 uv, vec2 texel) {
    vec3 centre = texture(colortex0, uv).rgb;

    vec3 northWest = texture(colortex0, uv + vec2(-1.0, -1.0) * texel).rgb;
    vec3 northEast = texture(colortex0, uv + vec2(1.0, -1.0) * texel).rgb;
    vec3 southWest = texture(colortex0, uv + vec2(-1.0, 1.0) * texel).rgb;
    vec3 southEast = texture(colortex0, uv + vec2(1.0, 1.0) * texel).rgb;

    float lumaCentre = luma(centre);
    float lumaNW = luma(northWest);
    float lumaNE = luma(northEast);
    float lumaSW = luma(southWest);
    float lumaSE = luma(southEast);

    float lumaMin = min(lumaCentre, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
    float lumaMax = max(lumaCentre, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
    float range = lumaMax - lumaMin;

    if (range < max(FXAA_EDGE_THRESHOLD_MIN, lumaMax * FXAA_EDGE_THRESHOLD)) return centre;

    // The steepest gradient of the luma field runs across the edge, so the
    // blend has to be applied along the direction perpendicular to it.
    vec2 gradient = vec2(
        -((lumaNW + lumaNE) - (lumaSW + lumaSE)),
        ((lumaNW + lumaSW) - (lumaNE + lumaSE))
    );

    float reduce = max((lumaNW + lumaNE + lumaSW + lumaSE) * 0.03125, 1.0e-4);
    float scale = 1.0 / (min(abs(gradient.x), abs(gradient.y)) + reduce);
    vec2 offset = clamp(gradient * scale, vec2(-8.0), vec2(8.0)) * texel;

    // Two short taps, then a slightly wider pair when they stay inside the
    // local luma range.
    vec3 blendA = 0.5 * (texture(colortex0, uv + offset * (1.0 / 3.0 - 0.5)).rgb
                       + texture(colortex0, uv + offset * (2.0 / 3.0 - 0.5)).rgb);
    vec3 blendB = blendA * 0.5 + 0.25 * (texture(colortex0, uv - offset * 0.5).rgb
                                       + texture(colortex0, uv + offset * 0.5).rgb);

    float lumaBlendB = luma(blendB);
    if (lumaBlendB < lumaMin || lumaBlendB > lumaMax) return blendA;
    return blendB;
}

/* 4x4 ordered dither. A fixed pattern beats random noise here: it never
   flickers between frames, and it is exactly what breaks up banding in a slow
   sky gradient. */
const float BAYER_4X4[16] = float[16](
     0.0,  8.0,  2.0, 10.0,
    12.0,  4.0, 14.0,  6.0,
     3.0, 11.0,  1.0,  9.0,
    15.0,  7.0, 13.0,  5.0
);

float novaDither(vec2 pixel) {
    ivec2 cell = ivec2(mod(floor(pixel), vec2(4.0)));
    return BAYER_4X4[cell.y * 4 + cell.x] / 16.0 - 0.5;
}

void main() {
    vec2 texel = 1.0 / vec2(viewWidth, viewHeight);
    vec2 uv = gl_FragCoord.xy * texel;

#if ANTI_ALIASING == 1
    vec3 colour = novaAntiAlias(uv, texel);
#else
    vec3 colour = texture(colortex0, uv).rgb;
#endif

    if (COLOR_VIGNETTE > 0.0) {
        vec2 centred = uv * 2.0 - 1.0;
        float radius = saturate(dot(centred, centred) * 0.5);
        colour *= 1.0 - COLOR_VIGNETTE * pow(radius, 1.6);
    }

#if COLOR_DITHER == 1
    colour += vec3(novaDither(gl_FragCoord.xy) / 255.0);
#endif

    fragColor = vec4(saturate(colour), 1.0);
}

#endif
