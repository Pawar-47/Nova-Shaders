# Nova Shaders — Visual and Reuse Research

Research snapshot: 2026-11-20  
Target: Minecraft Java 1.21.5, Iris 1.8.x + Sodium, Linux Mint, Core i3-5005U, Intel HD Graphics 5500, 8 GB RAM.

## Design target

Nova should keep Minecraft's readable vanilla identity while removing the flat, glassy and overly geometric feel:

- Water should read as a coloured, translucent body. Shallow bottoms remain visible through tint and distortion; deep water should not look like clear glass.
- Clouds should be a small set of broad, irregular, asymmetric masses spread across the full sky, including overhead views, rather than a narrow horizon bank.
- Foliage should gain natural colour variation, soft backlighting and wind motion without expensive per-pixel effects.
- Grass, shrubs and tree canopies should look less like isolated flat cards or cubes. The shader can shade and animate existing geometry, but cannot change vanilla tree branching, block models or biome density. That requires a resource pack or world-generation layer.
- The default configuration must be chosen for the HD 5500 first. Expensive effects remain optional.

## Repositories reviewed

### Strong candidates for an optional foliage companion pack

| Repository | License / status | Relevant contribution | Decision |
|---|---|---|---|
| [thimblebird/edgy-foliage](https://github.com/thimblebird/edgy-foliage) | MIT | Custom block models and block states; includes grass-block, leaf, cactus and sugar-cane model work. It uses existing Minecraft textures rather than shipping replacement textures. | Best source to study/adapt for less-boxy grass and plant silhouettes. Its 1.21 branch and Respackopts integration need validation against 1.21.5 before shipping. |
| [TeamMidnightDust/BetterLeavesLite](https://github.com/TeamMidnightDust/BetterLeavesLite) | MIT | Optimized leaf models with fewer model elements; round foliage texture is pre-generated into one texture rather than adding multiple texture references. | Strong low-overhead option for fuller tree canopies. Its documented downside is reduced compatibility with other packs that replace leaf textures. Test as a separate optional pack before combining it with Edgy Foliage. |
| [PoeticRainbow/rainbows-foliage](https://github.com/PoeticRainbow/rainbows-foliage) | No repository license file found in this review | Adds detail and variation to foliage; vanilla edition changes leaves, while the PolyTone edition covers more plants. README describes low/no extra geometry for the leaf treatment. | Visual reference only. Do not copy or redistribute until the author provides a clear license. |

These resource packs should remain optional and separate from the shader ZIP. Combining both MIT candidates blindly could create conflicting leaf model/blockstate overrides, so choose a single leaf implementation and merge only non-conflicting plant/grass models after inspecting their generated output.

### Shader packs and rendering references

| Repository / source | License / status | Useful ideas | Decision |
|---|---|---|---|
| [javiergcim/MakeUpUltraFast](https://github.com/javiergcim/MakeUpUltraFast) | LGPL-3.0 | Lightweight shader design, feature toggles and low-end quality trade-offs. | Good reference. No code copied in this change; any future adaptation must preserve LGPL obligations. |
| [AlexanderNyr/AuraLite-Shaders](https://github.com/AlexanderNyr/AuraLite-Shaders) | CC BY-NC-SA 4.0 | Modern water, foliage translucency, clouds and HDR ideas. | Do not adopt source into Nova's MIT codebase: non-commercial/share-alike terms are incompatible with the project's permissive reuse goal. |
| [sixthsurge/photon](https://github.com/sixthsurge/photon) | Custom restrictive license | Detailed water, reflections, clouds and atmosphere to study. | Reference only. Its license restricts redistribution of derivative shader packs on creator-compensation platforms without written permission. |
| [RustingStudio/RustingShader](https://github.com/RustingStudio/RustingShader) | No clear LICENSE file found | Deferred water, caustics, soft shadows and volumetric clouds. | Reference only until licensing is clarified; several effects are too costly for the target GPU as a default. |
| [shff/opengl_sky](https://github.com/shff/opengl_sky) | MIT | Procedural sky/cloud rendering in a small standalone OpenGL project. | Algorithm reference only; it is not an Iris shader pack and has not been ported. |
| [SpudLight Shaders](https://modrinth.com/shader/spudlight-shaders) | Source/license not verified in this review | Lightweight shadows, waving leaves and water; described as tuned for low-end GPUs. | Useful visual/performance reference, but no verified source repository was located for code reuse. |

### Existing MIT adaptations already in Nova

- [jbritain/glimmer-shaders](https://github.com/jbritain/glimmer-shaders): MIT. Nova already adapts a compact directional wave profile/analytic slope and Beer–Lambert water attenuation/in-scattering.
- [zombye/spectrum](https://github.com/zombye/spectrum): MIT. Nova already adapts the height-profiled cloud-density approach and compact anisotropic phase term. Spectrum's 3D noise textures, compute passes and multi-ray march are not included.

The exact notices and copied portions are recorded in `THIRD-PARTY-NOTICES.txt`. No new third-party shader source was copied for v0.10.2.

### Other foliage references excluded from reuse

- [LambdAurora/LambdaBetterGrass](https://github.com/LambdAurora/LambdaBetterGrass): its custom Lambda License is not a standard permissive FOSS license and requires written approval for binary distribution. Study only unless permission is obtained.
- [NaiNonTH/Foliage-Plus](https://github.com/NaiNonTH/Foliage-Plus): archived repository, no clear root license found in this review, and the project points to separate terms of use. Do not copy its assets/models without permission.

## Hardware and compatibility notes

- The target is Intel HD Graphics 5500 (Broadwell / Gen8) under Linux Mint, so Mesa/OpenGL driver behaviour must be validated on the actual machine.
- Iris documentation lists Mesa Intel on Linux as supported with some issues; shader-pack compatibility still depends on the exact Minecraft, Iris, Sodium and Mesa versions.
- The project currently has static source checks and ZIP packaging in CI. A green CI run proves those checks and packaging passed; it does not prove shader compilation, correct rendering, or FPS.
- No FPS target should be claimed until measured on the target machine using the same world, render distance, resolution, Minecraft version and Iris/Sodium build.

## Next implementation order

1. Finish v0.10.2 source/CI checks, then compare matched screenshots for sky overhead, horizon, shallow/deep water, a river, a forest canopy, a grass field and shrubs.
2. Build a separate optional foliage companion pack from the MIT candidates. First inspect and validate Edgy Foliage's grass/plant models and BetterLeavesLite's leaf approach; avoid conflicting leaf overrides.
3. Test the companion pack's geometry cost and culling on the HD 5500. If the added models reduce FPS too much, keep it optional and provide a lighter preset.
4. Only after visual checks, tune cloud count/coverage and water opacity to the user's actual preference. Do not add volumetric ray marches, SSR or large shadow maps to the default HD 5500 profile.
