# Nova Natural Foliage Lite

An optional, low-overhead companion resource pack for Nova Shaders.

## What it changes

- Adds one thin, slightly angled leaf-textured plane to each vanilla leaf block model, extending just beyond the cube silhouette.
- Randomizes the plane's horizontal orientation per leaf block, breaking up the repeated square canopy outline.
- Adds a 4-pixel grass fringe above the sides of grass blocks, softening the hard grass-to-dirt edge.
- Keeps vanilla textures and biome tint indices, so ordinary texture packs that replace vanilla leaf and grass-block textures remain usable.
- Leaves the original leaf cube in place for canopy volume and block culling.

Supported vanilla leaf blocks: oak, spruce, birch, jungle, acacia, dark oak, mangrove, cherry, azalea, flowering azalea and pale oak.

## Performance and limitations

This is deliberately a **Lite** treatment: one extra double-sided plane per leaf block, plus a small grass-block edge overlay. It is not a dense multi-layer leaf model. The added geometry and overdraw must be benchmarked on the Intel HD Graphics 5500 before being recommended as a default. Disable this pack if forest or grassland scenes lose too much FPS.

It changes leaf block models and grass-block edges only. It does not change tree generation, branch placement, tall-grass/shrub models or biome vegetation density. The Nova shader remains usable without this pack.

## Installation

Place this ZIP in Minecraft's resourcepacks folder and enable it above any pack that replaces vanilla leaf or grass-block models. It uses the vanilla textures selected by the active pack. Test the final resource-pack stack for compatibility.

## License

Original Nova model definitions are MIT-licensed; see `LICENSE`. The grass-block edge treatment is adapted from the MIT-licensed Edgy Foliage project; see `THIRD-PARTY-NOTICES.txt`.
