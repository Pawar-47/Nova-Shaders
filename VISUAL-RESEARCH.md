# Nova Shaders — Shader Research and Implementation Notes

Research snapshot: 2026-11-20  
Target: Minecraft Java 1.21.5, Iris 1.8.x + Sodium, Linux Mint, Core i3-5005U, Intel HD Graphics 5500, 8 GB RAM.

## Non-negotiable project scope

Nova is a **single shader pack**. Do not create, package, recommend as part of the project, or depend on companion resource packs. All supported improvements must be implemented in GLSL within the shader pack.

Shader limits remain explicit: GLSL can shade, tint, animate and slightly deform existing vertices. It cannot add leaf planes, change vanilla block models, generate branches, alter tree structure or increase biome plant density. Do not promise geometry changes the shader pipeline cannot make.

## Visual goals

- Water: tinted/translucent body, subdued shallow bottom, stronger depth absorption, restrained reflections and subtle surface motion.
- Foliage: preserve biome tint; add restrained variation, backlighting and natural, non-synchronous motion using existing vertices only.
- Clouds: broad, asymmetric masses across overhead and horizon views, without a costly volumetric march.
- Performance: target Intel HD Graphics 5500 first. Avoid making SSR, SSAO, bloom, TAA or multi-ray volumetrics default requirements.

## Modrinth shader research

| Reference | License / status | Useful implementation lessons | Reuse decision |
|---|---|---|---|
| [Spudlight Shaders](https://modrinth.com/shader/spudlight-shaders) | MIT; fork of Mellow with upstream permission noted | Explicit low-end budget: 512px shadows, 64-block range, vertex-stage foliage/water animation, and no SSAO, bloom, SSR or volumetric clouds in its low-end profile. | Study the public source and preserve upstream attribution if any code is adapted. Do not assume its forked code is wholly original to Spudlight. |
| [LIGHT Shaders](https://modrinth.com/shader/light-shaders) | Chocapic13 sharing/modification rules | Shows how removing expensive features can retain water reflections/ripples, dynamic-weather response and moving clouds. | Follow the linked Chocapic13 rules; do not copy until the exact permitted reuse and required notices are checked. |
| [Googy Shaders](https://modrinth.com/mod/googy-shaders) | CC BY 4.0; older Minecraft versions | Per-vertex noise gives different parts of foliage different phases, avoiding one rigid synchronized sway. | Algorithm reference. If adapting code, include attribution and license terms; first verify Iris 1.8 compatibility. |
| [UltraLight Shaders](https://modrinth.com/shader/ultralightshader) | ARR; do not copy source | Useful design notes: every effect has a cheap path, depth-faded water opacity, distance falloff for water detail, and a clear performance cut order. | Design reference only; all-rights-reserved source is not reusable. |
| [RMC Shaders](https://modrinth.com/shader/rmc-shaders) | Apache-2.0 | A compact GLSL 120 compatibility strategy, procedural clouds and simple wave/reflection features. | Potential code reference after checking exact source files and compatibility; preserve Apache notices if adapted. |

## GitHub and Iris references

- [Iris shaderpack template](https://github.com/ascpixi/minecraft-shader-template): use as a minimal project-layout and entry-point reference.
- [Iris shader documentation](https://github.com/IrisShaders/docs): authoritative reference for shader stages, uniforms, attributes, program naming and pack compatibility.
- [MakeUp Ultra Fast](https://github.com/javiergcim/MakeUpUltraFast): LGPL-3.0; useful architecture and low-end feature budgeting, but any source adaptation must comply with LGPL.
- [Glimmer](https://github.com/jbritain/glimmer-shaders): MIT; already used for Nova's compact directional water-wave slope and Beer–Lambert water attenuation.
- [Spectrum](https://github.com/zombye/spectrum): MIT; already used for Nova's height-profiled cloud density and compact anisotropic phase term. Its heavy 3D textures and multi-ray march are not ported.
- [opengl_sky](https://github.com/shff/opengl_sky): MIT; standalone procedural sky reference, not a drop-in Iris shader.

## Current Nova implementation

- One compact forward pipeline, one shadow map, a small cloud ray march and two full-screen passes.
- Default shadow map 512px over 64 blocks; PERFORMANCE disables the shadow pass and FXAA.
- Water uses shared analytic vertex displacement and fragment slope, depth-derived Beer–Lambert tint, and a minimum horizontal blend opacity.
- Foliage uses biome-preserving colour variation, sunset-aware backlighting and a shared terrain/shadow wind field.
- Clouds use four samples by default (three in the lightest profile), a height-shaped density field and a broad horizon LOD.
- No SSAO, bloom, screen-space reflections or multi-ray volumetrics are required by default.

## Engineering rules

1. Research source and license before adopting code. Modrinth metadata alone is not sufficient: inspect the actual repository license and file provenance.
2. Prefer vertex-stage effects and analytic math over additional full-screen passes or per-pixel ray marches.
3. Make distance falloff explicit for high-frequency water and foliage detail to avoid shimmer and wasted work at distance.
4. Keep terrain and shadow vertex displacement mathematically identical.
5. Do not add geometry or claim fuller silhouettes; shader-only foliage work must stay within existing vertex topology.
6. Static CI checks and ZIP packaging are not GPU compilation, in-game visual validation or FPS benchmarking.
7. Measure on the target Linux Mint / Intel HD 5500 system before making performance claims.

## Next implementation order

1. Audit and refine shader-only foliage animation: natural phase variation, restrained gusts, stable world-space motion, distance fade and shadow parity.
2. Review water detail and depth response against the low-end design: avoid costly extra texture fetches and unnecessary wave work at distance.
3. Improve cloud distribution and shading within the existing fixed sample budget before considering any extra samples.
4. Add a real shader-preprocessing/GLSL validation stage if it can reproduce the Iris 1.8.x compatibility environment.
5. Keep the release artifact to one shader ZIP and update this checkpoint after every durable change.
