# Nova Shaders Development Checkpoint

Last updated: committing the 0.10.0 source changes

## Project and target

- Minecraft Java 1.21.5, Iris 1.8.x and Sodium on Windows/SK Launcher.
- User hardware: Intel Core i3-5005U @ 2.00 GHz and Intel HD Graphics 5500.
- MIT license. Source adaptations remain limited to the documented Glimmer and Spectrum MIT portions; see `THIRD-PARTY-NOTICES.txt`. No proprietary shader source was used.
- The user wants substantial visual improvements to water, vegetation/trees/grass and clouds, and actual before/after comparison. Do not equate source-level changes or parameter adjustments with verified visual improvements.
- Shader-only changes cannot alter vanilla tree generation, branch layout or grass-block density. Those need a resource pack or world-generation work.
- This environment has no Minecraft/Iris runtime, GLSL compiler, shell or shaderpack build tool. Do not use the web inspector. Static review and CI are the only checks available here.

## Repository state

- Repository: `https://github.com/Pawar-47/Nova-Shaders.git`, branch `main`, tracking `origin/main`.
- Version metadata is **0.10.0** (`VERSION`, `pack.mcmeta`, `README.md`, release notes in `.github/workflows/build.yml`).
- The 0.10.0 source changes are committed and pushed in the commit that introduced this checkpoint (see `git log -1`). The previous release commit is `d43a423` (0.9.0).
- Pushing to `main` runs `tools/check_shaders.sh`, `tools/package.sh`, and then publishes release `v0.10.0` if that tag does not exist yet. A failing check aborts before packaging and release.

## What 0.10.0 changes

- Water: new `shaders/lib/water_waves.glsl` shares world-space analytic surface height and slope between vertex displacement (`shaders/lib/body/opaque.vsh`) and fragment normals (`shaders/lib/water.glsl`). Directional frequencies are 0.48 and 0.73 radians/block; `slope` is scaled in `water.glsl`, with a shorter-scale noise ripple and a broader glint.
- Vegetation: `shaders/lib/vegetation.glsl` takes `vec3 worldPosition` and returns a continuous, height-dependent wind offset. Terrain and shadow vertex bodies call the same function. Vegetation bending and grass tinting are unverified.
- Materials: `shaders/block.properties` keeps water at ID 100, extends ID 101 with explicit plant blocks, and maps `minecraft:grass_block` to ID 102. `shaders/lib/body/opaque.vsh` emits `vVegetationBlock`; `shaders/gbuffers_terrain.fsh` enables the matching fragment path in `shaders/lib/body/opaque.fsh`, which adds low-frequency tone variation to vegetation and grass-block top faces and a subtle vegetation backlight term.
- Clouds: `shaders/lib/sky.glsl` widens `fieldScale` and `detailScale` as `stepLength` grows, blends every horizon sample toward a shared midpoint mass, fades pixel dither, and bounds per-step optical depth with `mix(8.0, 0.90, horizonLod)`. This targets the reported dotted horizon. It is not rendered or validated.
- Static checker: `tools/check_shaders.sh` checks grass-block ID 102, paired material varyings, the shared water/vegetation paths, terrain and shadow defines, and the cloud horizon LOD and optical-depth bounds.

## Verification status

- Every item above is a source-level change. No GLSL compile, Minecraft/Iris run, matched visual comparison or frame-time measurement exists for 0.10.0.
- Locally the checker and packaging script were not run (no shell). CI runs both for this commit; check the workflow result before claiming either passed.
- A prior hardware-spec browser inspection attempt failed with `ERROR: Stopped.`; no hardware or FPS claims may rest on it.

## Next actions

1. Read the CI result for the 0.10.0 commit. If `Check the shader sources` fails, fix the exact reported invariant and push again; if `Publish release v0.10.0` fails, read the job log before touching `VERSION` or the tag.
2. Ask the user for matched before/after screenshots on the i3-5005U / HD Graphics 5500: close and distant water, vegetation with its shadows, and the cloud horizon. Ask for `logs/latest.log` if Iris reports a compile error.
3. Only after an actual in-game comparison: judge whether the horizon LOD removed the grain without flattening the deck, whether the vegetation wind bends rather than slides plants, and whether POTATO is playable. Do not claim visual success or frame rates before that.
4. Tree structure and grass density remain out of reach for GLSL; if the user still wants those, the answer is a resource pack or world-generation change, not more shader edits.
