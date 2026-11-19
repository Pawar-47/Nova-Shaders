# Nova Shaders Development Checkpoint

Last updated: 0.10.2 branch (cloud/water refinements and companion-pack CI; visual verification pending)

## Project and target

- Minecraft Java 1.21.5, Iris 1.8.x and Sodium on Linux Mint/SK Launcher.
- User hardware: Intel Core i3-5005U @ 2.00 GHz and Intel HD Graphics 5500.
- MIT license. Source adaptations remain limited to the documented Glimmer and Spectrum MIT portions; see `THIRD-PARTY-NOTICES.txt`. No proprietary shader source was used.
- Shader-only changes cannot alter vanilla tree generation, branch layout or grass-block density.
- This environment has no Minecraft/Iris runtime, GLSL compiler, shell or shaderpack build tool. Static review and CI are the only checks. Do not use the web inspector.

## Repository state

- Repository: `https://github.com/Pawar-47/Nova-Shaders.git`.
- `main` was at `a7bf008` (v0.10.1) when this work started. Active work branch: `natural-visuals-0.10.2`; pull request: `https://github.com/Pawar-47/Nova-Shaders/pull/1`.
- v0.10.2 is proposed on the PR branch and is not yet merged or released. The PR workflow run `44612327841` completed successfully: static shader checks, packaging and artifact upload passed. The release step was correctly skipped because this is a pull request.
- The v0.10.2 research and license review is recorded in `VISUAL-RESEARCH.md`. No new third-party shader source or resource-pack model code was copied; Glimmer and Spectrum remain the only shader source adaptations.
- Added `companion/nova-natural-foliage/`, an original optional MIT resource pack with one randomized angled plane per vanilla leaf block plus a grass-block side fringe. It is packaged as a separate ZIP, validated by `tools/check_foliage_pack.py`, and attached separately to CI artifacts and GitHub releases. Geometry cost and compatibility are not yet benchmarked. The pack does not change tall-grass or shrub models.
- The latest confirmed successful PR workflow run is `44615022503` (checkpoint commit `3cf4e1e`): shader source checks, companion-pack validation, both ZIP builds and both artifact uploads passed. The duplicate companion check briefly added to `check_shaders.sh` was removed; the dedicated `tools/check_foliage_pack.py` remains the single companion validator. No GLSL compilation or Minecraft rendering occurred.


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

## What 0.10.2 changes (unverified)

- Cloud field uses a larger near-view sampling scale (0.006) so overhead views are not reduced to one uniform patch, then fades to a broader 0.0012 field near the horizon. The target is roughly 15–20 broad, asymmetric masses in a typical open-sky view; exact count varies with view and coverage. The four-step march remains in place.
- Horizontal water alpha has a 0.82 floor, with depth-driven opacity retained.
- Foliage shading now adds low-amplitude warm/cool patch variation and sunset-aware backlighting while retaining the original biome tint. Grass-block tops receive variation without vertex displacement. Vertical faces preserve their texture alpha rather than inheriting the horizontal-sheet opacity floor.
- Default shadow quality is now 512px over 64 blocks for the HD 5500 target; 1024 remains selectable.
- The target OS is Linux Mint, not Windows.

No shader compile, in-game visual check or FPS benchmark has been performed for these changes. The latest cloud scale and 0.82 water floor are source changes only; compare overhead cloud coverage and shallow/deep water in-game before calling them visually complete.

## What 0.10.1 changes (unverified)

- `shaders/lib/body/opaque.vsh` and `shaders/lib/body/shadow.vsh` declare `in vec4 mc_midTexCoord;` and weight the wind offset by `aboveMid`, a tiny smoothstep band around the sprite's own midpoint. The base of a plant stays planted and only the upper part bends; both passes compute the weight identically so the shadow follows.
- `shaders/lib/vegetation.glsl` raises the lateral amplitude to `vec2(0.24, 0.14)` now that only the top of a plant moves, and documents the midpoint weighting.
- `shaders/block.properties` adds an explicit `#else` fallback list of 1.21.5 leaf, plant, flower, sapling and crop blocks, so vegetation selection cannot silently fail on a loader without tag support. Grass blocks stay on ID 102 (top-face tint only, no geometry shear).
- `tools/check_shaders.sh` checks `mc_midTexCoord` in both passes, the shared `aboveMid` weight, and the explicit leaf fallback list.
- `README.md` gains a "Why it still looks simpler than large packs" section stating the limits above; the vegetation bullet now describes base-anchored bending.

## Verification status

- GitHub Actions run `44614644080` passed on commit `94132d5`: shader source checks, optional foliage JSON/reference checks, packaging of both ZIPs, and upload of both artifacts all succeeded. The release step was correctly skipped on the pull-request branch.
- This is static validation and archive packaging only. The shaders have not been compiled by a GLSL driver, loaded in Iris, rendered in Minecraft, or benchmarked on the Intel HD 5500.
- The release-notes duplicate was removed in a later documentation-only commit; recheck CI against the current branch head before treating that exact head as validated.
- The previous commits' visual behaviour is also unverified: no screenshot comparison exists for 0.9.0 or 0.10.0.
- `mc_midTexCoord` is bound by Iris at attribute location 12 (`ProgramCreator`), and the terrain and shadow vertex formats both carry it, so the attribute itself is expected to resolve.

## Next actions

1. Install the PR build on Linux Mint and capture matched screenshots on the target machine: a close plant (bend and shadow alignment), leaf blocks/canopies, a grass field, shallow and deep water, overhead clouds, and the horizon.
2. Test the optional `Nova Natural Foliage Lite` pack with vanilla and common texture packs; benchmark forest FPS before recommending it. It adds one extra plane per leaf block and may increase overdraw.
3. After screenshots and FPS are available, tune cloud density/coverage and water alpha against those observations rather than guessing from source math.
4. Do not merge or claim visual success until the shader has been loaded in Iris on the target Linux Mint machine. Tree structure and grass density remain outside GLSL; they require resource-pack models or world-generation changes.
