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
- Published releases v0.10.2 and v0.10.3 both historically contain a shader ZIP and a companion foliage ZIP. Those published assets have not been rewritten; they are not part of the current product direction.
- Main currently points to v0.10.3. The `shader-only-research` branch removes the companion source and validator, and changes CI/package/release output to a single shader ZIP.
- `VERSION` is now 0.10.4 so the next release will use a new tag rather than colliding with the already-published v0.10.3. Future releases must contain only `nova-shaders-<version>-shaderpack.zip`.
- No changes should be merged or released until branch CI passes and the source-only archive is verified.

## Current shader implementation (source-level, not visually verified)

- Compact forward pipeline, one shadow map, small cloud ray march and two full-screen passes.
- Default shadow map 512px / 64 blocks; PERFORMANCE disables the shadow pass and FXAA.
- Water: shared analytic wave height/slope; depth-derived Beer–Lambert absorption and in-scattering; horizontal opacity floor 0.82; sky reflection and restrained glint. High-frequency gradient noise is skipped beyond 72 blocks while analytic waves remain.
- Foliage: biome-preserving warm/cool variation and sunset-aware backlighting. Ground plants use a `mc_midTexCoord` sprite-midpoint hinge; leaf blocks use separate material ID 103 and a continuous world-space wind field with slow canopy sway, tiny per-vertex flutter and a 96-block distance fade. Terrain and shadow passes use the same leaf displacement.
- Clouds: asymmetric skewed field, near-view scales 0.014 / detail 0.050 fading to broad horizon LOD; four samples by default and no extra march samples added. The detail-noise lookup is skipped once the horizon LOD fades it out.
- No SSAO, bloom, SSR or multi-ray volumetric lighting in the default path.

## Research reviewed on 2026-11-20

- Modrinth: Spudlight (MIT / fork attribution), LIGHT (Chocapic13 rules), Googy (CC BY 4.0), UltraLight (ARR; reference only), RMC (Apache-2.0).
- GitHub: Iris shader template and documentation, At87668/LIGHT-Shaders (Chocapic13 sharing rules; inspected, no source copied), MakeUp Ultra Fast (LGPL-3.0), Glimmer (MIT), Spectrum (MIT), opengl_sky (MIT).
- Research and licensing decisions are recorded in VISUAL-RESEARCH.md. Do not copy code from ARR, NC, ND, or unclear-license projects. Verify exact source provenance and obligations before any adaptation.

## Active review and verification status

- PR #2: https://github.com/Pawar-47/Nova-Shaders/pull/2 — shader-only cleanup, per-leaf vertex wind and water distance gating. Working branch: `shader-only-research`.
- Next release version prepared: v0.10.4. The v0.10.2 and v0.10.3 release pages still retain their historical companion ZIP assets.
- The PR head is the authoritative current revision; use the head SHA shown on PR #2 rather than a copied SHA in this note. It includes the latest main checkpoint as a merge parent.
- The PR currently has no reported status checks / Actions run. The repository connector did not trigger the PR workflow, and a local clone attempt could not resolve github.com, so the changed checker and packaging script have not been executed in this environment.
- Existing static shader checks and archive packaging have passed in previous runs.
- No GLSL driver compilation, Iris 1.8.x in-game render validation, target-machine screenshots or FPS benchmark has been performed. Do not merge or release this branch until its source checks and packaging have actually run.
- A passing static CI job is not proof of shader compilation, visual quality or performance.
- Do not claim that water/cloud/foliage visuals are complete until they have been inspected in-game.

## Next implementation order

1. Validate the new leaf material ID 103 tag/fallback mapping on Iris 1.8.x; inspect for edge cracks, cube shearing and shadow mismatch. Tune the per-vertex wind amplitude and distance fade only after in-game comparison.
2. Review water wave detail and depth response; keep high-frequency work close to camera and preserve the user's tinted, not glass-clear, water target.
3. Improve broad asymmetric cloud distribution within the current fixed sample budget.
4. Add reproducible Iris-compatible shader preprocessing / GLSL validation to CI if technically sound.
5. Keep packaging and releases to the single shader ZIP.
6. Update this checkpoint after each durable commit, including branch, commit SHA, CI run and explicit unverified items.


## Validation update — 2026-11-20

- GitHub Actions run `44618555950` completed successfully on the PR head `552f2191ce25fd1aa0df8b6a51d6b19718b0ac98`.
- Job `Check, package and release`: VERSION validation, shader static checks, single shader ZIP packaging and artifact upload all passed. Release publication was correctly skipped because this was a pull-request run.
- The run produced the shader-only artifact; no companion archive is built or uploaded by this workflow.
- This supersedes the earlier note saying no PR workflow run was reported. The combined commit-status endpoint returned no separate status entries, but the workflow-run endpoint confirms the completed successful run.
- Scope of this verification remains static source validation and ZIP packaging. It does not compile GLSL with a GPU driver, launch Minecraft/Iris, verify rendered appearance, or benchmark Intel HD 5500 performance.
- PR #2 remains open pending review of the passing source changes and the remaining runtime-only validation. Do not mark the shader visually or performance complete without the target-machine test.


## Shader-only merge and release — 2026-11-20

- PR #2 (https://github.com/Pawar-47/Nova-Shaders/pull/2) was squash-merged into main.
- Merge commit: `7496358866e7e99246e63f2a5dfc367cd7256d0a`.
- The merge removed `companion/nova-natural-foliage/` and `tools/check_foliage_pack.py`; the build now packages and uploads only the shader ZIP.
- The main-branch release workflow published `v0.10.4` from the merge commit. Release URL: https://github.com/Pawar-47/Nova-Shaders/releases/tag/v0.10.4
- Verified release assets: `nova-shaders-0.10.4-shaderpack.zip` (41.2 KB; SHA-256 `99b916aa545970f017e04d7ecdf0cbb3a01ef48a17d3141188e97a642b867ae0`) plus GitHub-generated source archives. No companion resource pack is attached.
- PR-branch Actions run `44618555950` passed shader static checks, shader-only packaging and artifact upload. Follow-up checkpoint run `44618752783` also passed those same steps. PR workflow correctly skipped release publication; main merge triggered publication of v0.10.4.
- Release notes explicitly state that GLSL has not been GPU-compiled, the shader has not been visually checked in Minecraft/Iris, and Intel HD 5500 performance has not been benchmarked. Do not remove that qualification without real tests.
- Next engineering work is to add a genuine Iris-compatible shader preprocessing/GLSL validation path, then perform actual Minecraft 1.21.5 + Iris 1.8.x runtime tests and target-machine FPS/visual comparisons. Continue with shader-only code; do not reintroduce companion models or resource packs.
