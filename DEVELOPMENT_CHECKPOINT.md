# Nova Shaders Development Checkpoint

Last updated: 0.10.1 commit (vegetation bending plus audit notes)

## Project and target

- Minecraft Java 1.21.5, Iris 1.8.x and Sodium on Windows/SK Launcher.
- User hardware: Intel Core i3-5005U @ 2.00 GHz and Intel HD Graphics 5500.
- MIT license. Source adaptations remain limited to the documented Glimmer and Spectrum MIT portions; see `THIRD-PARTY-NOTICES.txt`. No proprietary shader source was used.
- Shader-only changes cannot alter vanilla tree generation, branch layout or grass-block density.
- This environment has no Minecraft/Iris runtime, GLSL compiler, shell or shaderpack build tool. Static review and CI are the only checks. Do not use the web inspector.

## Repository state

- Repository: `https://github.com/Pawar-47/Nova-Shaders.git`, branch `main`, tracking `origin/main`.
- Published so far: 0.9.0 (`d43a423`) and 0.10.0 (`47be422`, CI job 135831147805, release `v0.10.0` created by the workflow).
- 0.10.1 in `VERSION`, `pack.mcmeta`, `README.md` and the workflow release notes publishes the audit follow-up below. CI runs the checker and packager first; a failing check stops the release.


## Audit: why the pack still reads as basic

Confirmed by reading the sources, not by rendering:

1. **Cloud sampling, not cloud code, is the limit.** `CLOUD_STEPS` is 4 by default and 3 in POTATO, spread over a slab whose far limit is 6000 blocks. At a low view elevation the four samples are 150-1500 blocks apart, so the field is undersampled by construction. The 0.10.0 horizon LOD blends the samples to one shared broad mass and bounds optical depth, which removes grain but also flattens the band. Detail above roughly six degrees of elevation is still carried by four samples.
2. **Shadow quality is a budget decision.** One 512/1024 map over 48/96 blocks with four half-texel taps: hard edges, no penumbra variation, no colored shadows. `shadowtex1` is never sampled, so translucent geometry is not excluded.
3. **No screen-space stage exists.** There is no SSAO, no SSR, no volumetric light and no bloom. `composite.fsh` and `final.fsh` are the only full-screen passes, and water reflects `novaSkyGradient` only, so terrain is never reflected.
4. **Highlight headroom is off.** The `colortex0Format = RGBA16F` directive in `lib/body/composite.fsh` is commented out, so `colortex0` is 8-bit: the sun disc (peaks near 4.5) and unlit geometry (`EMISSIVE_GAIN` 2.2) clip at 1.0 before the tonemapper.
5. **Shading runs in display space.** Gbuffers multiply sRGB-encoded texture values by light and the composite decodes once at the end. This is cheap and deliberate, but it compresses midtone contrast and dulls the terminator compared with a linear pipeline.
6. **Vegetation sway was translating whole quads.** Until this round `novaVegetationOffset` was applied to every vertex of a plant, so a tuft moved sideways as a rigid card instead of bending. Fixed below.
7. **Textures set the detail ceiling.** The pack ships none; vanilla 16x foliage and stone stay flat regardless of shader work.
8. **The palette is conservative on purpose.** Ambient is near neutral, fog is restrained, and saturation/exposure default to 1.0.

## What 0.10.1 changes (unverified)

- `shaders/lib/body/opaque.vsh` and `shaders/lib/body/shadow.vsh` declare `in vec4 mc_midTexCoord;` and weight the wind offset by `aboveMid`, a tiny smoothstep band around the sprite's own midpoint. The base of a plant stays planted and only the upper part bends; both passes compute the weight identically so the shadow follows.
- `shaders/lib/vegetation.glsl` raises the lateral amplitude to `vec2(0.24, 0.14)` now that only the top of a plant moves, and documents the midpoint weighting.
- `shaders/block.properties` adds an explicit `#else` fallback list of 1.21.5 leaf, plant, flower, sapling and crop blocks, so vegetation selection cannot silently fail on a loader without tag support. Grass blocks stay on ID 102 (top-face tint only, no geometry shear).
- `tools/check_shaders.sh` checks `mc_midTexCoord` in both passes, the shared `aboveMid` weight, and the explicit leaf fallback list.
- `README.md` gains a "Why it still looks simpler than large packs" section stating the limits above; the vegetation bullet now describes base-anchored bending.

## Verification status

- Nothing here was compiled, packaged or rendered. The checker was not run locally; CI runs it for this commit before packaging and release.
- The previous commits' visual behaviour is also unverified: no screenshot comparison exists for 0.9.0 or 0.10.0.
- `mc_midTexCoord` is bound by Iris at attribute location 12 (`ProgramCreator`), and the terrain and shadow vertex formats both carry it, so the attribute itself is expected to resolve.

## Next actions

1. Read the CI result for the 0.10.1 commit. If `Check the shader sources` fails, fix the reported invariant exactly and push again rather than editing VERSION.
2. Get matched in-game screenshots on the target machine: the same plant close up (to see whether it bends or shears), the same leaf block, a grass field, and the cloud horizon. Without those, the sway weight and the horizon LOD are guesses.
3. If more visual quality is wanted, the honest order is: enable RGBA16F for `colortex0`; raise `CLOUD_STEPS` on anything faster than the HD 5500; then add a compact SSAO in `composite.fsh`. Each needs an in-game comparison before it can be called an improvement.
4. Tree structure and grass density remain out of reach for GLSL; that is a resource pack or world-generation change.
