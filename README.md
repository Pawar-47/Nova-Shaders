# Nova Shaders

A small, original shader pack for **Minecraft Java 1.21.5** running **Iris 1.8.x** with
**Sodium**, on a Fabric install.

It was written for one specific machine: an ageing Intel Core i3 with integrated graphics
and 12 GB of RAM on Windows. Every choice in it follows from that - a forward lit pipeline
instead of a deferred one, one shadow map with four filtered taps, one shared noise field,
and two full screen passes where most packs have a dozen.

Version **0.6.0**. MIT licensed. It has not been benchmarked (see below).

## What changed in 0.6.0

- **Clouds are small, lopsided puffs spread over the whole sky.** 0.5.0's field used cells
  about a hundred blocks across plus a large scale mask that grouped them into banks, which
  is exactly why the sky overhead looked empty: the patch you see when you look up is only a
  couple of hundred blocks wide, so it spanned barely two cells, and the mask had usually
  emptied it while the horizon packed thousands of blocks of cloud into a few degrees. The
  mask is gone, the cells are about forty blocks, and the threshold now cuts the field into
  separate islands spread evenly, each warped so it is not round. They drift four times
  faster too.
- **Water is translucent, not transparent.** The alpha no longer follows whatever vanilla
  handed the program. A horizontal water sheet sits at 0.68 over a shallow bottom and 0.94
  once it is deep, so the bottom shows through tinted rather than clear. Vertical faces keep
  a floor of 0.62, so waterfalls stay juicy and glass panes stay glass.

## What changed in 0.5.0

0.4.0's water still read as a moving sheet of tinted glass and the clouds as flat cut-outs.
Both are rebuilt around the techniques behind the look this pack was asked to follow, written
from scratch: no BSL file, function, constant or table was copied or transliterated, so the
provenance rule below still holds.

- **Water detail comes from noise now, not only sines.** Three swell trains carry the large
  motion; on top of them sits the gradient of a noise field at roughly one block per cell.
  That high frequency chop is what makes a surface read as water, and it fades with distance
  instead of turning into pixel noise. The reflection now includes the sun and moon discs, so
  the water picks up the sun path, and the glint is a broad sheen under a tight sparkle
  rather than one flat dot.
- **Clouds are billowed and rim lit.** The FBM lookup is domain warped by the cluster field,
  which turns round blobs into billows, and a second sample towards the sun drives both a
  stronger lit/shade split and a silver lining on the edges facing the light.
- **Fog is much lighter.** The old height fog reached about 40% at 100 blocks, which washed
  out everything within a few chunks. The height term is now weak enough to leave the near
  field clear and a squared distance term takes over further out: roughly 10% at 100 blocks,
  and the render edge still closes off by 500. Caves stopped misting up as well.

## What changed in 0.4.0

- **Clouds have depth now.** Each puff is shaded with a second density sample taken towards
  the sun, so an edge facing the light glows and a thick core goes grey: the sheet reads as
  a volume instead of a flat cut-out. Coverage is higher by default, and near the horizon
  the noise is averaged towards its mean instead of being faded away, so there is a cloud
  deck down to the skyline without it shimmering.
- **Water is a body, not a pane.** The water program reads the opaque depth buffer to work
  out how much water sits between the surface and the ground, absorbs the body colour into a
  dark teal and closes the alpha up as it gets deeper. Shallow water still shows the bottom
  through about 0.6 alpha; a lake is close to opaque. Waves are 25% taller.
- **Vegetation edges are softer.** The cutout alpha test rides a stable 4x4 ordered dither
  instead of a hard threshold, and the threshold creeps up with distance to drop the single
  texels that pop in and out as the camera moves.
- **Lighting that wraps.** The sun term has a small wrap, so terminators are soft instead of
  faceted, and ambient is now a hemisphere: cool skylight from above, warm bounce from the
  ground. That is most of the reason grass, leaves and mobs read as round.

## What changed in 0.3.0

- **Red, green and blue are adjustable separately.** Three channel gains on the Color
  screen, `COLOR_RED`, `COLOR_GREEN` and `COLOR_BLUE`, all three as sliders. They multiply
  the image in linear light before the tonemapper, which is what makes them a channel
  correction and not a brightness tweak: 1.0 leaves a channel alone, 0.85 pulls it back, 1.2
  pushes it. The small fixed white balance that keeps daylight neutral stays underneath
  them, so the defaults still look exactly like 0.2.0.

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
  horizon, a sun disc and a moon disc drawn in the sky pass, and clouds: a domain warped FBM
  field thresholded into small separate puffs spread evenly over the sky, each with a second
  sample towards the sun for a lit edge, a grey core and a silver lining. Vanilla sun, moon
  and cloud geometry is discarded so nothing is drawn twice.
- **Fog**: light exponential height fog whose density drops with altitude, plus a squared
  distance term that only builds up far away, coloured by a desaturated air colour with a
  little warmth on the sun side.
- **Water**: three swells plus a noise gradient chop summed into the surface normal, the chop
  faded out with distance, Schlick Fresnel, a reflection of the sky including its sun and
  moon, a two part sun glint, and a body that absorbs into a dark teal with depth.
- **Lighting**: the sun with a small wrap so terminators are soft, a hemisphere ambient with
  cool light from above and warm bounce from the ground, and block light for torches and
  lava.
- **Post**: exposure, per channel red/green/blue gains, ACES tonemapping, saturation and
  contrast, an underwater tint, FXAA, a soft vignette and a 4x4 ordered dither.
- **Cutout alpha test** in both the gbuffer and the shadow pass, so leaves and grass look
  and shadow correctly.
- **Shader Pack Settings**: three screens (Color, Scene, Quality) with sliders, and two
  presets, `DEFAULT` and `POTATO`.

## What is deliberately not in 0.6.0

Not missing by accident - left out on purpose, and listed here so nobody has to guess:

- Screen space terrain reflections in water (the water reflects the sky only).
- Volumetric clouds. There is one flat sheet; its depth comes from a second density sample,
  not from marching through a volume.
- Waving foliage, grass or leaves.
- Wet surfaces after rain. Rain darkens and flattens the sky, nothing more.
- PBR: no LabPBR, no POM, no parallax, no specular maps. Vanilla textures only.
- Dimension specific skies. The horizon is pulled toward vanilla's fog colour, so the
  Nether and the End read plausibly, but there is no bespoke End or Nether sky.
- Stars, moon phases, coloured shadows, SSAO, bloom, TAA.
- Water is not identified by block id, so every translucent surface shares one model. The
  depth driven body is limited to horizontal sheets, which keeps vertical glass panes looking
  like vanilla glass, but a glass roof or floor will read as water.
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
without borrowing code. 0.5.0 follows the same well documented family of techniques that
BSL Shaders is known for - noise gradient water detail, reflecting the sky and its sun in
the water, a two sample cloud volume, domain warped cloud noise - and every line of it was
written here. No BSL file, function, constant, coordinate table or structure was copied or
transliterated.

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
| Noise gradient surface detail | `shaders/lib/water.glsl` |
| Domain warped cloud field with two sample shading | `shaders/lib/sky.glsl` |

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
