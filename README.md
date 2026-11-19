# Nova Shaders

A small, original shader pack for **Minecraft Java 1.21.5** running **Iris 1.8.x** with
**Sodium**, on a Fabric install.

It was written for one specific machine: an ageing Intel Core i3 with integrated graphics
and 12 GB of RAM on Windows. Every choice in it follows from that - a forward lit pipeline
instead of a deferred one, one shadow map with four filtered taps, one shared noise field,
and two full screen passes where most packs have a dozen.

Version **0.2.0**. MIT licensed. It has not been benchmarked (see below).

## What changed in 0.2.0

0.1.0 lit the scene with the sky itself, copied the sky into the fog, and built every water
normal out of two crossed sines. All three are visible mistakes, and all three are gone:

- **No more blue cast.** Ambient light is near neutral with only a hint of cool
  (0.64, 0.66, 0.70), the sky palette is much less saturated, fog is a desaturated air
  colour instead of a copy of the sky, water reflections are pulled 20% towards grey, and
  the composite applies a very small warm balance. Textures read as their own colour again.
- **Small scattered clouds.** Two noise fields: a low frequency mask that decides where the
  cloud banks are at all, and a higher frequency field that cuts each bank into puffs. Most
  of the sky is empty, and the sheet fades out before it can smear along the horizon.
- **Water that looks like water.** Five swells set a few degrees apart with irrational
  wavelength ratios and their own speeds, plus two fine ripples that fade out with distance.
  No visible grid, no repetition, no shimmer on the horizon, with Fresnel and a desaturated
  sky reflection on top.
- **Smoother and cheaper.** 0.1.0 evaluated the full sky gradient three times per pixel -
  once for ambient, once for fog, once for the sky. It is now zero for opaque pixels and one
  for sky and water. `pow()` is gone from the hot paths, the cloud sheet uses three octaves
  instead of four, and the water normal is a handful of cosines instead of twelve noise
  hashes. Exposure defaults to 1.0 and the vignette is softer.

## What works

- **Directional lighting** from the sun, and a dim cold moon at night, both warmed up near
  the horizon, over a near neutral ambient so surfaces keep their own colour.
- **Shadow mapping**: one depth map, four taps on a half texel grid (so they behave like a
  hardware box filter), slope scaled bias, normal offset, edge and distance fades, and a
  switch to turn it off.
- **Sky**: procedural vertical gradient, a sunset band that follows the sun across the
  horizon, a sun disc and a moon disc drawn in the sky pass, and small scattered cloud puffs
  from a cluster mask over an FBM field. Vanilla sun, moon and cloud geometry is discarded
  so nothing is drawn twice.
- **Fog**: exponential height fog whose density drops with altitude, coloured by a
  desaturated air colour with a little warmth on the sun side, so distance stays neutral
  instead of turning blue.
- **Water**: five swells plus two fine ripples summed into the surface normal, ripples faded
  out with distance, Schlick Fresnel, a slightly desaturated sky reflection, a sun glint,
  and red absorption in the body colour.
- **Post**: exposure, ACES tonemapping, saturation and contrast, an underwater tint, FXAA,
  a soft vignette and a 4x4 ordered dither.
- **Cutout alpha test** in both the gbuffer and the shadow pass, so leaves and grass look
  and shadow correctly.
- **Shader Pack Settings**: three screens (Color, Scene, Quality) with sliders, and two
  presets, `DEFAULT` and `POTATO`.

## What is deliberately not in 0.1.0

Not missing by accident - left out on purpose, and listed here so nobody has to guess:

- Screen space terrain reflections in water (the water reflects the sky only).
- Volumetric or layered clouds. There is one flat procedural sheet.
- Waving foliage, grass or leaves.
- Wet surfaces after rain. Rain darkens and flattens the sky, nothing more.
- PBR: no LabPBR, no POM, no parallax, no specular maps. Vanilla textures only.
- Dimension specific skies. The horizon is pulled toward vanilla's fog colour, so the
  Nether and the End read plausibly, but there is no bespoke End or Nether sky.
- Stars, moon phases, coloured shadows, SSAO, bloom, TAA.
- Water is not told apart from ice or stained glass: every translucent surface uses the
  same model, so glass ends up looking like a dark mirror.
- Vanilla's lightmap texture is not sampled; block and sky light levels are read straight
  out of the lightmap coordinate and shaped by curves in `lib/lighting.glsl`. Night vision
  and blindness are therefore not honoured.

## Install (Fabric 1.21.5 + Iris)

1. Install **Fabric Loader** for Minecraft **1.21.5** from the Fabric website and start the
   game once so the launcher creates a profile.
2. Put these mods in the instance's `mods` folder:
   - **Fabric API** (for 1.21.5)
   - **Iris** 1.8.x (for 1.21.5)
   - **Sodium** (for 1.21.5)
3. Launch the Fabric profile once, then close the game.
4. Drop `nova-shaders-<version>-shaderpack.zip` **unmodified** into the `shaderpacks`
   folder - do not unzip it. With SK Launcher that is
   `%APPDATA%\.minecraft\shaderpacks` unless the launcher keeps its own instance folder,
   in which case it is `<instance>\shaderpacks`.
5. Start the game, open **Options -> Video Settings -> Shader Packs**, select
   **Nova Shaders** and click **Apply**.
6. If the frame rate is poor, open **Shader Pack Settings** and pick the **POTATO** preset:
   it turns shadows and clouds off and thins the fog.

The pack reports `pack_format` 46, which is the 1.21.5 resource pack format.

## Licence and provenance

MIT, see [LICENSE](LICENSE).

Every line in this pack was written for this pack. No file, function, constant or asset has
been copied, ported, renamed or "rewritten" from BSL Shaders, Complementary Shaders, MakeUp
Ultra Fast, or any other shader pack. No textures ship with it: the cloud sheet, the water
chop, the moon mottling and the dither are all generated in GLSL from one hash function in
`shaders/lib/util.glsl`.

The techniques are standard and publicly documented, which is what makes them usable
without borrowing code:

| Technique | Where |
| --- | --- |
| Shadow mapping with a few filtered taps and slope scaled bias | `shaders/lib/shadow.glsl` |
| Lightmap sky and block light split | `shaders/lib/lighting.glsl` |
| Exponential height fog | `shaders/lib/fog.glsl` |
| FBM (fractal value noise) cloud plane | `shaders/lib/util.glsl`, `shaders/lib/sky.glsl` |
| Schlick Fresnel, sky reflection, sun glint | `shaders/lib/water.glsl` |
| ACES filmic tonemapping (Narkowicz fit) | `shaders/lib/util.glsl` |
| FXAA | `shaders/lib/body/final.fsh` |
| Layered directional waves with distance fading | `shaders/lib/water.glsl` |

## Not benchmarked

**This pack has never been compiled on a GPU or measured for frame rate.** It was written
and then checked statically, with `tools/check_shaders.sh`, which verifies:

- every entry program starts with `#version 330 compatibility`,
- every entry program includes a body from `shaders/lib/body`,
- every `#include` resolves to a real file,
- every program has both a vertex and a fragment stage,
- preprocessor conditionals balance in every file,
- every option used by `shaders.properties` is defined in the shaders and labelled in
  `shaders/lang/en_us.lang`.

That is not the same as running it. No frame times are claimed anywhere in this repository.
If something fails to compile, the Iris shader log (`logs/latest.log`) names the file and
line; please report it.

Worth testing first: shadow edges and acne, water close up and at a distance, the scattered
clouds at dawn and dusk, rain, and the Nether.

## Repository layout

```
pack.mcmeta               pack format 46
VERSION                   the version the release is built from
LICENSE                   MIT
shaders/
  shaders.properties      option screens, sliders and the two presets
  lang/en_us.lang         labels, tooltips and on/off values
  gbuffers_*.vsh/.fsh     entry points: one #version line and one #include each
  shadow.vsh/.fsh         renders the shadow map: cutout aware, colour reserved
  composite.vsh/.fsh      exposure, tonemapping, saturation, underwater tint
  final.vsh/.fsh          FXAA, vignette, dither
  lib/
    settings.glsl         every user facing option, and nothing else
    uniforms.glsl         declarations for the Iris uniforms the pack reads
    util.glsl             colour space, ACES, hash, value noise, FBM
    sky.glsl              day/sunset amounts, gradient, sun and moon discs, clouds
    shadow.glsl           shadowFactor: four taps, slope scaled bias
    lighting.glsl         sunlight, skylight ambient, warm block light, applyLighting
    water.glsl            wave normal, Fresnel, reflection, glint
    fog.glsl              height falloff distance fog using the sky gradient
    body/                 the actual shader bodies the entry points include
tools/
  check_shaders.sh        static checks, run by CI
  package.sh              builds build/nova-shaders-<version>-shaderpack.zip
.github/workflows/
  build.yml               checks, packages, uploads, releases v<version>
```

## Building

```sh
bash tools/check_shaders.sh
bash tools/package.sh
```

The archive is written to `build/nova-shaders-<version>-shaderpack.zip` with `shaders/`,
`pack.mcmeta` and `LICENSE` at its root.

## Releasing

`.github/workflows/build.yml` runs the checks and the packaging on every push, uploads the
zip as a workflow artifact, and - on a push to `main` - creates the release `v<version>`
from the `VERSION` file with the zip attached. It is additive: if a release for that
version already exists, the tag and its assets are left alone. To publish a new version,
bump `VERSION` and push.
