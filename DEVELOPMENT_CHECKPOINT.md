# Nova Shaders Development Checkpoint

Last updated: 0.11.0 (pipeline audit, defects fixed)

## Project and target

- Minecraft Java 1.21.5, Iris 1.8.x and Sodium on Windows/SK Launcher.
- User hardware: Intel Core i3-5005U @ 2.00 GHz and Intel HD Graphics 5500.
- MIT license. Source adaptations remain limited to the documented Glimmer and Spectrum MIT portions; see `THIRD-PARTY-NOTICES.txt`. No proprietary shader source was used.
- Shader-only changes cannot alter vanilla tree generation, branch layout or grass-block density.
- This environment has no Minecraft/Iris runtime, GLSL compiler, shell or shaderpack build tool. Static review and CI are the only checks. Do not use the web inspector.

## Repository state

- Repository: `https://github.com/Pawar-47/Nova-Shaders.git`, branch `main`, tracking `origin/main`.
- Published: 0.9.0 (`d43a423`), 0.10.0 (`47be422`), 0.10.1 (`a7bf008`).
- 0.11.0 is in `VERSION`, `pack.mcmeta`, `README.md` and the workflow release notes, but is **not committed or pushed** as of this checkpoint.

## Material IDs (block.properties)

| ID | Blocks | Vertex stage | Fragment stage |
| --- | --- | --- | --- |
| 100 | water | top-face height offset (dips only) | wave normal, depth medium |
| 101 | crossed-quad plants (tag list plus explicit fallback) | bends, weighted by `mc_midTexCoord` | tone patch, normal relief, backlight |
| 102 | grass block | none | top-face tone patch and relief |
| 103 | leaves and vines | none | tone patch, stronger relief, backlight |
| 104 | logs and wood | none | vertical bark relief |

Leaves and vines were on 101 until 0.11.0 and were being sheared per face, which tore canopies apart. They must never return to 101.

## Defects fixed in 0.11.0 (unverified)

1. **Leaf shear.** `opaque.vsh` adds the wind offset to every vertex of ID 101; leaves are full cubes, so the top of each face moved and the block detached from its neighbours. Fixed by moving leaves and vines to ID 103.
2. **Cloud slab self-ghosting.** `min/max` without a sign test made an above-deck downward ray march the empty air between the eye and the slab. Fixed with a proper interval test that also rejects a `tFar <= 0` segment.
3. **Water shoreline gap.** The displaced surface could rise above the block top while the vertical faces stayed put. `novaWaterSurfaceHeight` now subtracts `NOVA_WATER_CREST`, so the crest sits on the plane and every other point dips.
4. **Water normal flattening.** The tilt was multiplied by view incidence, removing wave detail and the sun path exactly at grazing angles. Replaced with a distance fade (fine chop to 48 blocks, swell to 320).
5. **Shadow filter.** A fixed 2x2 half-texel grid returned five coverage levels. Replaced with an eight-tap golden-angle spiral, a `smoothstep` comparison band and a radius that grows with distance and slope.

## Improvements in 0.11.0 (unverified)

- `colortex0Format = RGBA16F` enabled; without it the highlight excess bloom depends on does not exist.
- Bloom in `composite.fsh`: eight taps on two rings, threshold 0.92 in the encoded buffer, `saturate`-free raw excess decoded once and scaled by `BLOOM_STRENGTH` (default 0.30, POTATO 0.20, 0.0 removes the pass).
- Foliage and bark normal relief from `valueNoiseGradient`, and a stronger chlorophyll backlight.
- Cloud directional shading from the density field's gradient along the light direction, at no extra noise cost because `valueNoiseGradient` hashes the same four corners as `valueNoise`.

## Verification status

- Nothing here was compiled, packaged or rendered. The checker was not run locally; CI runs it for the next commit before packaging and release.
- No screenshot comparison exists for any version. Performance is unmeasured on the i3-5005U / HD Graphics 5500.
- Highest-risk items: the eight-tap shadow spiral (bandwidth), the bloom pass (bandwidth), and whether the RGBA16F target is affordable at the target resolution.

## Next actions

1. Commit and push 0.11.0; read the CI result. If `Check the shader sources` fails, fix the reported invariant rather than editing VERSION.
2. Get matched in-game screenshots on the target machine: a leaf canopy and a trunk close up, a shadow edge near and far, the sun near the horizon, a water shoreline, and the cloud horizon.
3. If the frame rate drops, measure in this order: Bloom 0.0, then Shadow softness 0.5, then `shadowMapResolution` 512, then CLOUD_STEPS 3.
4. Remaining honest ceilings if more quality is wanted: no SSAO, no screen-space reflections, no volumetric light, display-space shading, four cloud samples, and vanilla 16x textures.
