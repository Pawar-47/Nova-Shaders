# Nova Shaders Development Checkpoint

Last updated: 0.11.0 — pipeline audit merged on top of the shader-only 0.10.4 baseline.

## Project and target

- Repository: https://github.com/Pawar-47/Nova-Shaders
- Minecraft Java 1.21.5, Iris 1.8.x and Sodium on Linux Mint / SK Launcher.
- Target hardware: Intel Core i3-5005U @ 2.00 GHz, Intel HD Graphics 5500, 8 GB RAM.
- MIT project license. Existing MIT adaptations from Glimmer and Spectrum are documented in THIRD-PARTY-NOTICES.txt.
- **One shader pack only.** No companion resource pack, model override pack, separate foliage ZIP or dependency on another pack. All improvements are implemented inside the shader pack.
- Shader limitations are respected: GLSL can shade and animate existing vertices but cannot add leaf planes, change vanilla models, alter tree generation/branching or change biome vegetation density.
- This environment has no Minecraft/Iris runtime and no GLSL compiler. Static review and CI are the only checks. Do not use the web inspector.

## Repository and release state

- Baseline this work was written against: `a7bf008` (v0.10.1).
- Upstream since then: 0.10.2, 0.10.3, the shader-only 0.10.4 restructure (`7496358`) and its docs follow-up (`933786b`). v0.10.4 is published and contains only `nova-shaders-0.10.4-shaderpack.zip`.
- 0.11.0 merges both lines. `VERSION`, `pack.mcmeta`, `README.md` and the workflow release notes are at 0.11.0; the workflow publishes `v0.11.0` on the next push to main.
- The 0.10.x releases keep their historical assets; nothing is rewritten or moved.

## Material IDs (block.properties)

| ID | Blocks | Vertex stage | Fragment stage |
| --- | --- | --- | --- |
| 100 | water | top-face height offset (dips only) | wave normal, depth medium |
| 101 | crossed-quad ground plants | sprite-midpoint hinge | tone patch, warm/cool shift, relief, backlight |
| 102 | grass block | none | top-face tone patch and relief |
| 103 | leaves and vines | continuous world-space wind field | strongest relief, warm/cool shift, backlight |
| 104 | logs and wood | none | vertical bark relief |

Two rules that must not regress:

1. A full cube (leaf block, grass block, log) must never use the sprite hinge on 101. The hinge moves the top of each face relative to the bottom, which detaches a cube from its six neighbours.
2. `%minecraft:small_flowers` must be used for plants, not `%minecraft:flowers`. The wide tag also holds flowering azalea and chorus flower, which are full cubes, plus spore blossom and pink petals. The checker rejects `%minecraft:flowers`.

## Defects fixed in 0.11.0 (unverified)

1. **Full cubes on the hinge.** Leaves were on 101 and were hinged per face. They are on 103 with the continuous field (`novaLeafOffset`), so shared vertices receive identical offsets and the canopy cannot crack.
2. **Wrong flower tag.** `%minecraft:flowers` replaced with `%minecraft:small_flowers`; the checker now forbids the wide tag.
3. **Cloud slab self-ghosting.** `min/max` without a sign test made an above-deck downward ray march the empty air between the eye and the slab. Fixed with an interval test that also rejects a `tFar <= 0` segment.
4. **Water shoreline gap.** The displaced surface could rise above the block top while the vertical faces stayed put. `novaWaterSurfaceHeight` now subtracts `NOVA_WATER_CREST`, so the crest sits on the plane and every other point dips.
5. **Water normal flattening.** The tilt was multiplied by view incidence, removing wave detail and the sun path exactly at grazing angles. Replaced by a distance fade; the 72-block high-frequency skip from 0.10.4 is kept.
6. **Shadow filter.** A fixed 2x2 half-texel grid returned five coverage levels. Replaced with an eight-tap golden-angle spiral, a `smoothstep` comparison band and a radius that grows with distance and slope.

## Improvements in 0.11.0 (unverified)

- `colortex0Format = RGBA16F` enabled; without it the highlight excess bloom depends on does not exist.
- Bloom in `composite.fsh`: eight taps on two rings, threshold 0.92 in the encoded buffer, decoded once and scaled by `BLOOM_STRENGTH` (DEFAULT 0.30, POTATO 0.20, PERFORMANCE 0.0).
- Foliage and bark normal relief from `valueNoiseGradient`; stronger chlorophyll backlight with a sunset tint.
- Cloud directional shading from the density field's gradient along the light direction, at no extra noise cost because `valueNoiseGradient` hashes the same four corners as `valueNoise`.

## Verification status

- Nothing here was compiled, packaged or rendered. CI runs the static checker and packager on push; a failing check stops the release.
- No screenshot comparison exists for any version. Performance is unmeasured on the i3-5005U / HD Graphics 5500.
- Highest-risk items: the eight-tap shadow spiral (bandwidth), the bloom pass (bandwidth), and whether the RGBA16F target is affordable at the target resolution.

## Next actions

1. Read the CI result for the 0.11.0 merge. If `Check the shader sources` fails, fix the reported invariant rather than editing VERSION.
2. Follow TARGET-TEST-PLAN.md on the target machine: a leaf canopy and a trunk close up, a shadow edge near and far, the sun near the horizon, a water shoreline, and the cloud horizon.
3. If the frame rate drops, measure in this order: PERFORMANCE preset, then Bloom 0.0, then Shadow softness 0.5, then CLOUD_STEPS 3.
4. Remaining honest ceilings: no SSAO, no screen-space reflections, no volumetric light, display-space shading, four cloud samples, no cloud shadows, and vanilla 16x textures.
