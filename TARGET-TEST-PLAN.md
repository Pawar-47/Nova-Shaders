# Nova Shaders — Target Hardware Test Plan

This plan is for the intended test system:

- Linux Mint
- Minecraft Java 1.21.5
- Iris 1.8.x with Sodium, launched through SK Launcher
- Intel Core i3-5005U @ 2.00 GHz
- Intel HD Graphics 5500
- 8 GB RAM

The shader source and ZIP packaging pass CI, but no GPU compilation, in-game rendering or FPS benchmark has been performed. Do not treat a static CI pass as proof of visual quality or hardware performance.

## Test setup

Keep these settings identical between comparisons:

- Same Minecraft version, Iris/Sodium versions and Java runtime
- Same display resolution, fullscreen/window mode, FOV, render distance and simulation distance
- Same world, coordinates, camera direction, time of day and weather
- Same background applications and power mode
- Restart the world or reload shaders after changing the resource-pack stack

Use a repeatable open area containing water, trees and grass if possible. Record the exact resource-pack order.

## Comparison profiles

Run these four combinations:

1. **Vanilla baseline:** no shader and no Nova foliage companion
2. **Nova DEFAULT:** shader enabled, foliage companion disabled
3. **Nova DEFAULT + foliage:** shader and Nova Natural Foliage Lite enabled
4. **Nova PERFORMANCE + foliage:** PERFORMANCE profile, shader and foliage companion enabled

The PERFORMANCE profile disables the actual Iris shadow pass and FXAA while keeping procedural clouds and water effects enabled.

## Visual checks

Capture the same camera positions for each relevant comparison:

- **Clouds overhead:** look nearly straight up; check that separate broad, asymmetric masses are distributed across the sky rather than one uniform patch
- **Cloud horizon:** look toward the horizon; check for stable broad masses without grainy bands or a smeared continuous strip
- **Shallow water:** stand at a shoreline; the bottom should remain visible but subdued through tinted water, not crystal clear
- **Deep water:** check that opacity increases with depth and the bottom becomes less visible
- **Vertical water:** check waterfalls and vertical faces; they should retain their texture translucency rather than inheriting the horizontal-water opacity floor
- **Trees:** compare canopy silhouette and leaf fullness; look for z-fighting, harsh card edges or excessive overdraw
- **Small plants:** compare short grass, fern, seagrass, dead bush, bush, dry grass and Nether sprouts; check that three crossed planes look fuller without obvious intersecting artifacts
- **Wind and shadows:** watch one plant closely; its base should remain planted, its upper part should bend, and its cast shadow should follow
- **Snowy grass:** confirm snowy grass blocks still display the vanilla snow-covered top and sides

## Performance checks

For each of the four combinations:

1. Stand at the same marked position and face the same direction.
2. Let the scene settle for 30 seconds.
3. Observe FPS and frame-time behaviour for 60 seconds.
4. Repeat once to reduce one-off variation.
5. Record the approximate average FPS and the lowest sustained FPS. If MangoHud is available, also record frame-time/1% low data.

Test a forest edge and a grassland separately; the companion pack adds one plane per leaf block and a third plane to selected small plants, so overdraw may differ by biome.

## Report format

For useful tuning, record:

- Profile and whether the companion pack was enabled
- Render distance, resolution and resource-pack order
- Approximate average FPS and lowest sustained FPS
- Which visual check failed, if any
- Screenshots from the same camera position

Do not change cloud scale, water opacity or foliage geometry based only on a single screenshot or an uncontrolled FPS reading. Tune against repeatable comparisons.
