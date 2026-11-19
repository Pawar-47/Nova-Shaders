# Nova Shaders Development Checkpoint

Last updated: 2026-11-20 — shader-only direction confirmed; companion resource pack removed from active project.

## Project and target

- Repository: https://github.com/Pawar-47/Nova-Shaders
- Minecraft Java 1.21.5, Iris 1.8.x and Sodium on Linux Mint / SK Launcher.
- Target hardware: Intel Core i3-5005U @ 2.00 GHz, Intel HD Graphics 5500, 8 GB RAM.
- MIT project license. Existing MIT adaptations from Glimmer and Spectrum are documented in THIRD-PARTY-NOTICES.txt.
- **One shader pack only.** No companion resource pack, model override pack, separate foliage ZIP or dependency on another pack. All improvements must be implemented inside the shader pack.
- Shader limitations must be respected: GLSL can shade and animate existing vertices but cannot add leaf planes, change vanilla models, alter tree generation/branching or change biome vegetation density.

## Repository baseline and release state

- Main baseline inspected: `436c2e5d66622dac417092f00cb61dec13096d83`.
- Published release v0.10.2 exists and historically contains both a shader ZIP and a companion foliage ZIP. Do not treat the companion as part of the current product direction.
- Main contained an unreleased v0.10.3 preparation with companion pack validation and packaging. The `shader-only-research` branch is the working branch for removing that pack from source, CI and future releases.
- The old v0.10.2 release is immutable under the current additive-only release workflow; future releases must contain only `nova-shaders-<version>-shaderpack.zip`.
- No changes should be merged or released until branch CI passes and the source-only archive is verified.

## Current shader implementation (source-level, not visually verified)

- Compact forward pipeline, one shadow map, small cloud ray march and two full-screen passes.
- Default shadow map 512px / 64 blocks; PERFORMANCE disables the shadow pass and FXAA.
- Water: shared analytic wave height/slope; depth-derived Beer–Lambert absorption and in-scattering; horizontal opacity floor 0.82; sky reflection and restrained glint.
- Foliage: biome-preserving warm/cool variation, sunset-aware backlighting and a shared terrain/shadow wind field. Plant sway uses Iris `mc_midTexCoord` weighting to keep the sprite base planted.
- Clouds: asymmetric skewed field, near-view scales 0.014 / detail 0.050 fading to broad horizon LOD; four samples by default and no extra march samples added.
- No SSAO, bloom, SSR or multi-ray volumetric lighting in the default path.

## Research reviewed on 2026-11-20

- Modrinth: Spudlight (MIT / fork attribution), LIGHT (Chocapic13 rules), Googy (CC BY 4.0), UltraLight (ARR; reference only), RMC (Apache-2.0).
- GitHub: Iris shader template and documentation, MakeUp Ultra Fast (LGPL-3.0), Glimmer (MIT), Spectrum (MIT), opengl_sky (MIT).
- Research and licensing decisions are recorded in VISUAL-RESEARCH.md. Do not copy code from ARR, NC, ND, or unclear-license projects. Verify exact source provenance and obligations before any adaptation.

## Verification status

- Existing static shader checks and archive packaging have passed in previous runs.
- No GLSL driver compilation, Iris 1.8.x in-game render validation, target-machine screenshots or FPS benchmark has been performed.
- A passing static CI job is not proof of shader compilation, visual quality or performance.
- Do not claim that water/cloud/foliage visuals are complete until they have been inspected in-game.

## Next implementation order

1. Refine shader-only foliage motion with natural per-vertex phase variation, restrained gusts, distance falloff and exact shadow-pass parity. Avoid adding geometry or creating cracks between adjacent blocks.
2. Review water wave detail and depth response; keep high-frequency work close to camera and preserve the user's tinted, not glass-clear, water target.
3. Improve broad asymmetric cloud distribution within the current fixed sample budget.
4. Add reproducible Iris-compatible shader preprocessing / GLSL validation to CI if technically sound.
5. Keep packaging and releases to the single shader ZIP.
6. Update this checkpoint after each durable commit, including branch, commit SHA, CI run and explicit unverified items.
