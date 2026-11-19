# Nova Natural Foliage Lite

An optional, low-overhead companion resource pack for Nova Shaders.

## What it changes

- Adds one thin, slightly angled leaf-textured plane to each vanilla leaf block model, extending just beyond the cube silhouette.
- Randomizes the plane's horizontal orientation per leaf block, breaking up the repeated square canopy outline.
- Keeps the vanilla leaf texture references and biome tint index, so ordinary texture packs that replace vanilla leaf textures remain usable.
- Leaves the original block cube in place for canopy volume and block culling.

Supported vanilla leaf blocks: oak, spruce, birch, jungle, acacia, dark oak, mangrove, cherry, azalea, flowering azalea and pale oak.

## Performance and limitations

This is deliberately a **Lite** treatment: one extra double-sided plane per leaf block, not a dense multi-layer leaf model. It adds geometry and overdraw, so it is optional and must be benchmarked on the Intel HD Graphics 5500 before being recommended as a default. Disable this pack if forest scenes lose too much FPS.

It changes leaf block models only. It does not change tree generation, branch placement, grass blocks, shrubs or plant density. The Nova shader remains usable without this pack.

## Installation

Place this ZIP in Minecraft's resourcepacks folder and enable it above any pack that replaces vanilla leaf models. If a texture pack changes leaf textures, keep that texture pack below this pack so its textures remain selected; test the final stack for compatibility.

## License

MIT. Original Nova companion model definitions. See `LICENSE`.
