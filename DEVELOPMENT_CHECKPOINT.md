# Nova Shaders Development Checkpoint

Last updated: 0.10.2 branch (cloud/water refinements, optional foliage models and CI; visual verification pending)

## Project and target

- Minecraft Java 1.21.5, Iris 1.8.x and Sodium on Linux Mint/SK Launcher.
- User hardware: Intel Core i3-5005U @ 2.00 GHz and Intel HD Graphics 5500.
- MIT license. Source adaptations remain limited to the documented Glimmer and Spectrum MIT portions; see `THIRD-PARTY-NOTICES.txt`. No proprietary shader source was used.
- Shader-only changes cannot alter vanilla tree generation, branch layout or grass-block density.
- This environment has no Minecraft/Iris runtime, GLSL compiler, shell or shaderpack build tool. Static review and CI are the only checks. Do not use the web inspector.

## Repository state

- Repository: `https://github.com/Pawar-47/Nova-Shaders.git`.
- `main` is now at merge commit `0544446` (v0.10.2). Pull request #1 (`natural-visuals-0.10.2`) was merged by the repository owner on 2026-11-19.
- Release `v0.10.2` is published. GitHub Actions run `44616741775` passed on the merge commit: shader checks, companion-pack validation, both ZIP builds, both artifact uploads and release publication all succeeded. Release assets: `nova-shaders-0.10.2-shaderpack.zip` and `nova-natural-foliage-0.10.2.zip`.
- The v0.10.2 research and license review is recorded in `VISUAL-RESEARCH.md`. No third-party shader or resource-pack model files were copied; Glimmer and Spectrum remain the only shader source adaptations. The Edgy Foliage grass-edge approach is attributed in the companion notices.
- Added `companion/nova-natural-foliage/`, an original optional MIT resource pack: one randomized angled plane per vanilla leaf block; three crossed planes for short grass, fern, seagrass, dead bush, bush, short/tall dry grass and Nether sprouts; and a grass-block side fringe. Tall grass and large fern remain vanilla. Snow-covered grass keeps the vanilla `grass_block_snow` model. The pack is built as a separate ZIP and validated by `tools/check_foliage_pack.py`. Geometry cost and compatibility are not yet benchmarked.


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

- Cloud field uses a balanced near-view sampling scale (0.014) with a restrained detail scale (0.050) in the same skewed domain; both fade to broader fields near the horizon. This changes only the coordinates of existing noise lookups and adds no ray-march samples. The target is roughly 15–20 broad, asymmetric masses in a typical overhead open-sky view; exact count varies with view and coverage. The four-step march remains in place.
- Horizontal water alpha has a 0.82 floor, with depth-driven opacity retained.
- Foliage shading now adds low-amplitude warm/cool patch variation and sunset-aware backlighting while retaining the original biome tint. Grass-block tops receive variation without vertex displacement. Vertical faces preserve their texture alpha rather than inheriting the horizontal-sheet opacity floor.
- Default shadow quality is now 512px over 64 blocks for the HD 5500 target; 1024 remains selectable.
- Added a `PERFORMANCE` preset that sets `SHADOWS=0`, disables Iris's actual shadow render pass through conditional `shadow.enabled`, disables FXAA and keeps three cloud samples plus water effects. The shader checker asserts this path.
- The target OS is Linux Mint, not Windows.

No shader compile, in-game visual check or FPS benchmark has been performed for these changes. The denser overhead cloud field and 0.82 water floor are source changes only; compare the actual cloud count/distribution and shallow/deep water in-game before calling them visually complete.

## What 0.10.1 changes (unverified)

- `shaders/lib/body/opaque.vsh` and `shaders/lib/body/shadow.vsh` declare `in vec4 mc_midTexCoord;` and weight the wind offset by `aboveMid`, a tiny smoothstep band around the sprite's own midpoint. The base of a plant stays planted and only the upper part bends; both passes compute the weight identically so the shadow follows.
- `shaders/lib/vegetation.glsl` raises the lateral amplitude to `vec2(0.24, 0.14)` now that only the top of a plant moves, and documents the midpoint weighting.
- `shaders/block.properties` adds an explicit `#else` fallback list of 1.21.5 leaf, plant, flower, sapling and crop blocks, so vegetation selection cannot silently fail on a loader without tag support. Grass blocks stay on ID 102 (top-face tint only, no geometry shear).
- `tools/check_shaders.sh` checks `mc_midTexCoord` in both passes, the shared `aboveMid` weight, and the explicit leaf fallback list.
- `README.md` gains a "Why it still looks simpler than large packs" section stating the limits above; the vegetation bullet now describes base-anchored bending.

## Verification status

- GitHub Actions run `44616741775` passed on main merge commit `0544446`: shader source checks, optional foliage JSON/reference checks (including selected plant geometry, tint-index rules and snowy grass fallback), packaging of both ZIPs, upload of both artifacts and publication of release `v0.10.2` all succeeded.
- This is static validation and archive packaging only. The shaders have not been compiled by a GLSL driver, loaded in Iris, rendered in Minecraft, or benchmarked on the Intel HD 5500.
- The balanced overhead cloud field (0.014 near-view scale and 0.050 detail scale), matching source-check assertion, cutout-mipped leaf render-layer check, horizontal-only water opacity floor, `PERFORMANCE` preset, and optional leaf/plant models plus the snowy grass-state fallback are included in this passing run.
- `PERFORMANCE` sets `SHADOWS=0`; Iris's conditional `shadow.enabled = false` disables the shadow render pass itself, not just fragment shadow sampling. FXAA is also disabled; clouds and water remain enabled.
- The previous commits' visual behaviour is also unverified: no screenshot comparison exists for 0.9.0 or 0.10.0.
- `mc_midTexCoord` is bound by Iris at attribute location 12 (`ProgramCreator`), and the terrain and shadow vertex formats both carry it, so the attribute itself is expected to resolve.

## Next actions

1. Install the released v0.10.2 shader ZIP on Linux Mint and capture matched screenshots on the target machine: a close plant (bend and shadow alignment), leaf blocks/canopies, a grass field, shallow and deep water, overhead clouds, and the horizon.
2. Test the optional `Nova Natural Foliage Lite` ZIP with vanilla and common texture packs; benchmark forest/grassland FPS before recommending it. It adds one extra plane per leaf block and a third plane to selected small plants, increasing overdraw.
3. After screenshots and FPS are available, tune cloud density/coverage and water alpha against those observations rather than guessing from source math.
4. Do not claim visual success until the shader has been loaded in Iris on the target Linux Mint machine. Tree structure and biome grass density remain outside GLSL; they require resource-pack models or world-generation changes.
