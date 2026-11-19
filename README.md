# Nova Shaders

A small, original shader pack for **Minecraft Java 1.21.5** running **Iris 1.8.x** with
**Sodium**, on a Fabric install.

The target is an older Intel Core i3 with integrated graphics on Windows, but the exact CPU
and GPU model are not available. The pack therefore stays on a compact forward pipeline,
one shadow map, a small cloud ray march and two full-screen passes rather than making
hardware-specific FPS claims.

Version **0.9.0**. MIT licensed; third-party MIT adaptations are recorded in
[THIRD-PARTY-NOTICES.txt](THIRD-PARTY-NOTICES.txt). It has not been GPU-tested or benchmarked.

## What changed in 0.9.0

- **Water has actual surface motion.** Iris block ID 100 selects water for low-amplitude vertex displacement as well as the animated fragment normal, so the silhouette moves instead of only the reflection. The depth treatment is restricted to mapped water.
- **Vegetation moves with the wind.** Iris block ID 101 selects leaves, flowers, saplings and crops for subtle world-anchored sway. The same displacement is applied in the shadow pass to keep silhouettes aligned.
- **The visual changes are stronger by default.** Cloud coverage and absorption increase; daytime direct light is brighter, and the sky/ground ambient contrast is more pronounced.
- **POTATO keeps the effects visible.** It uses three cloud steps and a 512-pixel shadow map over 48 blocks, instead of disabling clouds and shadows. On very slow hardware, turn those options off manually.

These are source-level changes; their visible result still needs an in-game Iris check.

## What changed in 0.8.0

- **Water waves stay anchored to the world.** Two low-cost directional wave slopes, adapted
  from Glimmer's MIT-licensed wave code, layer over one fine noise gradient. The view-angle
  flattening now blends toward the actual world-up axis, and the existing wave-height slider
  now controls the result.
- **Water has depth-tinted body colour.** Per-channel Beer-Lambert attenuation and a restrained
  teal-green in-scattering term are adapted from Glimmer's MIT-licensed water medium code.
  The alpha follows the same transmittance and keeps a floor over shallow bottoms.
- **Clouds shade more naturally at lower cost.** Spectrum's MIT cloud source informed a compact
  anisotropic phase term and height-shaped density; the expensive 3D noise textures and
  secondary light marches are not ported. The default cloud budget drops from five samples to
  four, while the Potato profile uses three.
- **Terrain cutouts transition more smoothly.** A distance-faded Bayer coverage threshold is
  used for terrain and shadows; other opaque programs keep their low alpha cutoff, while the
  translucent-entity pass preserves texture alpha for blending.
- **Daylight ambient is less blue.** Sky and ground hemisphere colours are closer to neutral,
  while sunset warmth remains intact.

## What changed in 0.7.0

This version's cloud slab and depth-based water were implemented in Nova before the licensed
source adaptations in 0.8.0.

- **Clouds are a marched slab now, not a painted dome.** A single noise field sampled by view
  direction can only ever look like a texture on a sphere. The clouds are a 60 block thick slab
  that the view ray is intersected with and walked in `CLOUD_STEPS` steps, accumulating
  transmittance and light front to back: back puffs are genuinely hidden behind front ones and
  each puff carries a continuous tone instead of one flat colour. Coverage is height dependent
  - dense at the base, so the bottoms are flat and continuous; eroded towards the top, so the
  crowns break into separate rounded puffs. Lighting is analytic per sample (dark base, bright
  crown, thick cores greyed), plus forward scattering when the view points near the sun, and the
  alpha is softened with a square root so the skirt fades out instead of being cut. The domain
  warp is gone: warping a field every frame is what made the old clouds shear and swim.
- **Water follows the reference surface model.** Three octaves of slope, each the exact gradient
  of a value noise field (analytic, so three octaves cost three lookups rather than nine), summed
  into one tilt whose flatness is a single Z value. The tilt is flattened by incidence, so there
  is full chop underfoot and a stable mirror towards the horizon with no distance fade at all.
  Fresnel is the reference's squared shape with a 0.75 ceiling, the reflection is the sky, and the
  sun is a soft eleven degree glitter disc rather than a tight sparkle. The body is one dark
  desaturated teal carrying about a quarter of the biome tint, lit from the flat quad normal, and
  the transparency is the reference's depth curve: `1 - 1/(thickness * thickness * 0.16 + 1.125)`,
  so a shallow bottom shows through tinted and eight blocks of water is opaque.

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
Both were rebuilt in Nova. Those implementations predate the limited MIT-licensed source
adaptations added in 0.8.0 and documented in the provenance section below.

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

- **Lighting and shadows:** directional sunlight and moonlight, hemisphere ambient with a stronger sky/ground split, warm block light, and one shadow map with four filtered taps, bias and distance fades.
- **Sky and clouds:** procedural day/night gradient, sunset band, sun and moon discs, plus a 60-block cloud slab marched in `CLOUD_STEPS` with front-to-back transmittance and analytic shading.
- **Fog:** altitude-sensitive height fog plus a distance term, coloured with a restrained air palette.
- **Water:** Iris block mapping limits low-amplitude vertex displacement, animated normals, Fresnel sky reflection, sun glint and depth absorption/in-scattering to water. The hand-water pass remains separate.
- **Vegetation:** Iris tags select leaves, flowers, saplings and crops for gentle world-anchored movement, matched in the shadow pass.
- **Post-processing:** exposure, independent RGB gains, ACES tonemapping, saturation, contrast, underwater tint, FXAA, vignette and ordered dithering.
- **Alpha coverage:** distance-faded Bayer coverage for terrain cutouts and shadows; other opaque programs keep the previous low cutoff, and translucent entities retain alpha for blending.
- **Settings:** Color, Scene and Quality screens, with `DEFAULT` and `POTATO` presets.

## What is deliberately not in 0.9.0

- Screen-space terrain reflections in water.
- Multiple-scattering clouds or cloud shadows on the ground.
- Wet surfaces after rain.
- PBR, LabPBR, parallax, POM or specular maps.
- Dimension-specific skies, stars, moon phases, coloured shadows, SSAO, bloom or TAA.
- Iris tag support (Iris 1.7+) is needed for vegetation selection; without it, water mapping still works but vegetation sway is unavailable.
- The vanilla lightmap texture is not sampled; night vision and blindness are therefore not honoured.

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
   it keeps clouds and shadows enabled with three cloud samples and a lower-resolution,
   shorter-range shadow map. If performance is still poor, turn **Shadows** and **Clouds** off
   manually and reduce **Cloud steps**.

The pack reports `pack_format` 46, which is the 1.21.5 resource pack format.

## Licence and provenance

Nova Shaders is MIT licensed; see [LICENSE](LICENSE). The pack includes limited adaptations from two MIT-licensed shader projects, with source links, attribution, scope and license text in [THIRD-PARTY-NOTICES.txt](THIRD-PARTY-NOTICES.txt):

- **Glimmer:** the compact directional wave profile and analytic slope, plus Beer-Lambert water attenuation and in-scattering, adapted in `shaders/lib/water.glsl`. Glimmer credits afl_ext for the upstream procedural wave method; that credit is included in the notice.
- **Spectrum:** the height-profiled cloud-density approach and compact anisotropic phase model, adapted in `shaders/lib/sky.glsl`. Spectrum's 3D noise textures, compute passes and multi-ray lighting are not included.

No code from BSL Shaders, Complementary Shaders or MakeUp Ultra Fast is included. No textures ship with the pack; procedural detail is generated in GLSL.

| Technique | Where |
| --- | --- |
| Shadow mapping and filtered taps | `shaders/lib/shadow.glsl` |
| Lightmap sky and block-light split | `shaders/lib/lighting.glsl` |
| Exponential height and distance fog | `shaders/lib/fog.glsl` |
| Marched cloud slab and compact scattering phase | `shaders/lib/sky.glsl` |
| Wave slopes, water medium, Fresnel and reflection | `shaders/lib/water.glsl` |
| ACES filmic tonemapping | `shaders/lib/util.glsl` |
| FXAA | `shaders/lib/body/final.fsh` |
| Depth-driven water treatment | `shaders/lib/body/water.fsh` |

## Not benchmarked

These changes have not been GPU-compiled, visually checked in Minecraft, or benchmarked. The repository includes `tools/check_shaders.sh`, a static source checker that checks required files, version and pack metadata, entry-point and stage pairing, include resolution, preprocessor balance (including `block.properties`), block-ID/tag mappings, material varyings, and option definitions/labels and settings controls. It does not compile GLSL or establish runtime compatibility or performance, and it has not been run for these changes.

No frame times are claimed. If Iris reports a compile failure, its shader log (`logs/latest.log`) should identify the file and line. Useful first checks are cloud edges and shading, water near and far and underwater, translucent entities, foliage and shadows, rain, and the Nether.

## Repository layout

```
pack.mcmeta               pack format 46
VERSION                   the version the release is built from
LICENSE                   MIT
THIRD-PARTY-NOTICES.txt   adaptation attributions and MIT notices
shaders/
  shaders.properties      option screens, sliders and the two presets
  block.properties        Iris water and vegetation material IDs
  lang/en_us.lang         labels, tooltips and on/off values
  gbuffers_*.vsh/.fsh     entry points with program defines and shared-body includes
  shadow.vsh/.fsh         renders the shadow map with matching foliage sway
  composite.vsh/.fsh      exposure, tonemapping, saturation, underwater tint
  final.vsh/.fsh          FXAA, vignette, dither
  lib/
    settings.glsl         every user facing option, and nothing else
    uniforms.glsl         declarations for the Iris uniforms the pack reads
    util.glsl             colour space, ACES, hash, value noise and its gradient, dither
    sky.glsl              day/sunset amounts, gradient, discs, the cloud slab
    shadow.glsl           shadowFactor: four taps, slope scaled bias
    lighting.glsl         sunlight, skylight ambient, warm block light, applyLighting
    water.glsl            slope normal, Fresnel, reflection, glitter
    vegetation.glsl       shared world-anchored wind offset
    fog.glsl              height falloff distance fog
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

The archive is written to `build/nova-shaders-<version>-shaderpack.zip`. Its root contains `shaders/`, `pack.mcmeta`, `LICENSE`, and `THIRD-PARTY-NOTICES.txt`.

## Releasing

`.github/workflows/build.yml` runs the static checker and package script on pushes and pull requests, uploads the ZIP as a workflow artifact, and creates release `v<version>` on a push to `main`. Existing releases are left untouched. To publish a new version, update `VERSION` and push.
