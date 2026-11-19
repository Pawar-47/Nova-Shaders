#!/usr/bin/env bash
#
# Nova Shaders - static checks. No GPU, no Minecraft, no build tools: these only
# look at the source, so they can run anywhere including CI.
#
#   * every entry program starts with the GLSL version line
#   * every entry program includes a body from shaders/lib/body
#   * every program has both a vertex and a fragment stage
#   * every #include resolves to a real file
#   * library files never declare #version
#   * preprocessor conditionals balance in every file
#   * options used by shaders.properties exist in the shaders and have a label
#     in shaders/lang/en_us.lang
#   * water, vegetation and grass mappings agree with their shader interfaces
#   * the cloud horizon LOD blends fields and bounds per-step optical depth
#   * pack.mcmeta is valid JSON and VERSION is a plain version number

set -uo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
shaders="$root/shaders"
props="$shaders/shaders.properties"
lang="$shaders/lang/en_us.lang"

errors=0

fail() { printf 'error: %s\n' "$*" >&2; errors=$((errors + 1)); }
section() { printf '\n== %s\n' "$*"; }

section "layout"

for required in shaders/shaders.properties shaders/lang/en_us.lang shaders/block.properties pack.mcmeta LICENSE THIRD-PARTY-NOTICES.txt VERSION; do
    [ -e "$root/$required" ] || fail "missing $required"
done

if [ -f "$root/VERSION" ]; then
    version="$(tr -d '[:space:]' < "$root/VERSION")"
    if printf '%s' "$version" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
        printf 'version %s\n' "$version"
    else
        fail "VERSION should look like 1.2.3 (found '$version')"
    fi
fi

if command -v python3 >/dev/null 2>&1 && [ -f "$root/pack.mcmeta" ]; then
    if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$root/pack.mcmeta"; then
        fail "pack.mcmeta is not valid JSON"
    fi
    if ! python3 -c 'import json,sys; json.load(open(sys.argv[1]))["pack"]["pack_format"]' "$root/pack.mcmeta" >/dev/null; then
        fail "pack.mcmeta has no pack.pack_format"
    fi
fi

section "entry programs"

mapfile -t entries < <(find "$shaders" -maxdepth 1 -type f \( -name '*.vsh' -o -name '*.fsh' \) | sort)

if [ "${#entries[@]}" -eq 0 ]; then
    fail "no entry programs found in shaders/"
fi

for file in "${entries[@]}"; do
    rel="${file#"$root"/}"
    first="$(grep -m1 -v '^[[:space:]]*$' "$file" | tr -d '\r')"
    case "$first" in
        '#version 330 compatibility'*) ;;
        *) fail "$rel: first line is not '#version 330 compatibility'"
    esac

    if ! grep -qE '^[[:space:]]*#include[[:space:]]+"/lib/body/[^"]+"' "$file"; then
        fail "$rel: does not include a body from /lib/body/"
    fi
done

printf '%d entry files\n' "${#entries[@]}"

section "stage pairing"

mapfile -t bases < <(
    find "$shaders" -maxdepth 1 -type f \( -name '*.vsh' -o -name '*.fsh' \) -printf '%f\n' |
        sed 's/\.[vf]sh$//' | sort -u
)

for base in "${bases[@]}"; do
    [ -f "$shaders/$base.vsh" ] || fail "$base: no vertex stage"
    [ -f "$shaders/$base.fsh" ] || fail "$base: no fragment stage"
done

printf '%d programs\n' "${#bases[@]}"

section "includes"

mapfile -t sources < <(find "$shaders" -type f \( -name '*.vsh' -o -name '*.fsh' -o -name '*.glsl' -o -name 'block.properties' \) | sort)

for file in "${sources[@]}"; do
    dir="$(dirname "$file")"
    while IFS= read -r include; do
        [ -n "$include" ] || continue
        case "$include" in
            /*) target="$shaders$include" ;;
            *) target="$dir/$include" ;;
        esac
        [ -f "$target" ] || fail "${file#"$root"/}: #include \"$include\" does not resolve"
    done < <(sed -n 's/^[[:space:]]*#include[[:space:]]*"\([^"]*\)".*/\1/p' "$file")
done

while IFS= read -r file; do
    if grep -q '^[[:space:]]*#version' "$file"; then
        fail "${file#"$root"/}: a library file must not declare #version"
    fi
done < <(find "$shaders/lib" -type f | sort)

section "material mappings and shader paths"

block_props="$shaders/block.properties"
if [ -f "$block_props" ]; then
    if ! grep -qE '^[[:space:]]*block\.100[[:space:]]*=[[:space:]]*minecraft:water([[:space:]]|$)' "$block_props"; then
        fail "shaders/block.properties: block ID 100 must map to minecraft:water"
    fi
    if ! grep -qE '^[[:space:]]*block\.101[[:space:]]*=' "$block_props"; then
        fail "shaders/block.properties: block ID 101 must map vegetation tags"
    fi
    for tag in flowers tall_flowers saplings crops; do
        if ! grep -qE "(^|[[:space:]])%minecraft:$tag([[:space:]]|$)" "$block_props"; then
            fail "shaders/block.properties: vegetation mapping is missing %minecraft:$tag"
        fi
    done
    if ! grep -qE '^[[:space:]]*block\\.103[[:space:]]*=[[:space:]]*%minecraft:leaves([[:space:]]|$)' "$block_props"; then
        fail "shaders/block.properties: leaf block ID 103 must map %minecraft:leaves"
    fi
    for leaf in minecraft:oak_leaves minecraft:spruce_leaves minecraft:birch_leaves minecraft:jungle_leaves minecraft:acacia_leaves minecraft:dark_oak_leaves minecraft:mangrove_leaves minecraft:cherry_leaves minecraft:azalea_leaves minecraft:flowering_azalea_leaves minecraft:pale_oak_leaves; do
        if ! grep -qF "$leaf" "$block_props"; then
            fail "shaders/block.properties: leaf fallback mapping is missing $leaf"
        fi
    done
    for plant in minecraft:short_grass minecraft:tall_grass minecraft:fern minecraft:large_fern minecraft:dead_bush minecraft:seagrass minecraft:tall_seagrass; do
        if ! grep -qF "$plant" "$block_props"; then
            fail "shaders/block.properties: vegetation mapping is missing $plant"
        fi
    done
    if ! grep -qE '^[[:space:]]*block\.102[[:space:]]*=[[:space:]]*minecraft:grass_block([[:space:]]|$)' "$block_props"; then
        fail "shaders/block.properties: block ID 102 must map to minecraft:grass_block"
    fi
fi

if ! grep -qF 'in vec2 mc_Entity;' "$shaders/lib/body/opaque.vsh"; then
    fail "opaque vertex body does not declare Iris mc_Entity"
fi
if ! grep -qF 'in vec2 mc_Entity;' "$shaders/lib/body/shadow.vsh"; then
    fail "shadow vertex body does not declare Iris mc_Entity"
fi
if ! grep -qF 'uniform mat4 shadowModelViewInverse;' "$shaders/lib/uniforms.glsl"; then
    fail "shadow vegetation sway requires shadowModelViewInverse"
fi
if ! grep -qF 'mc_Entity.x == 100.0' "$shaders/lib/body/opaque.vsh"; then
    fail "water shader block ID does not match block.properties ID 100"
fi
if ! grep -qF 'mc_Entity.x == 101.0' "$shaders/lib/body/opaque.vsh" ||
   ! grep -qF 'mc_Entity.x == 101.0' "$shaders/lib/body/shadow.vsh" ||
   ! grep -qF 'mc_Entity.x == 103.0' "$shaders/lib/body/opaque.vsh" ||
   ! grep -qF 'mc_Entity.x == 103.0' "$shaders/lib/body/shadow.vsh"; then
    fail "plant and leaf shader block IDs must match block.properties in terrain and shadow passes"
fi
if ! grep -qF 'flat out float vWaterBlock;' "$shaders/lib/body/opaque.vsh" ||
   ! grep -qF 'flat in float vWaterBlock;' "$shaders/lib/body/water.fsh"; then
    fail "water material ID varying is not paired between vertex and fragment bodies"
fi
if ! grep -qF 'flat out float vVegetationBlock;' "$shaders/lib/body/opaque.vsh" ||
   ! grep -qF 'flat in float vVegetationBlock;' "$shaders/lib/body/opaque.fsh" ||
   ! grep -qF 'vVegetationBlock = mc_Entity.x;' "$shaders/lib/body/opaque.vsh"; then
    fail "vegetation material ID varying is not paired between terrain stages"
fi
if ! grep -qF 'if (vVegetationBlock > 100.5 && vVegetationBlock < 103.5)' "$shaders/lib/body/opaque.fsh" ||
   ! grep -qF 'if (vVegetationBlock > 101.5 && vVegetationBlock < 102.5)' "$shaders/lib/body/opaque.fsh"; then
    fail "terrain shading does not distinguish vegetation from grass-block ID 102"
fi
if ! grep -qF 'vec3 foliageTint = mix(vec3(0.96, 1.03, 0.94),' "$shaders/lib/body/opaque.fsh" ||
   ! grep -qF 'vec3 transmissionTint = mix(vec3(0.025, 0.10, 0.015),' "$shaders/lib/body/opaque.fsh"; then
    fail "foliage shading must preserve biome colour while adding subtle natural variation and backlight"
fi
if ! grep -qF '#include "/lib/water_waves.glsl"' "$shaders/lib/body/opaque.vsh" ||
   ! grep -qF '#include "/lib/water_waves.glsl"' "$shaders/lib/water.glsl" ||
   ! grep -qF 'float novaWaterSurfaceHeight(vec2 worldXZ)' "$shaders/lib/water_waves.glsl" ||
   ! grep -qF 'vec2 novaWaterSurfaceSlope(vec2 worldXZ)' "$shaders/lib/water_waves.glsl"; then
    fail "water vertex displacement and fragment slope must share the analytic wave field"
fi
if ! grep -qF 'vec2 novaVegetationOffset(vec3 worldPosition)' "$shaders/lib/vegetation.glsl" ||
   ! grep -qF 'vec2 novaLeafOffset(vec3 worldPosition)' "$shaders/lib/vegetation.glsl" ||
   ! grep -qF 'novaLeafOffset(worldPos)' "$shaders/lib/body/opaque.vsh" ||
   ! grep -qF 'novaLeafOffset(worldPos)' "$shaders/lib/body/shadow.vsh" ||
   ! grep -qF 'novaVegetationOffset(worldPos) * aboveMid' "$shaders/lib/body/opaque.vsh" ||
   ! grep -qF 'novaVegetationOffset(worldPos) * aboveMid' "$shaders/lib/body/shadow.vsh"; then
    fail "terrain and shadow passes must use the shared world-space vegetation field, weighted by sprite height"
fi
if ! grep -qF 'in vec2 mc_midTexCoord;' "$shaders/lib/body/opaque.vsh" ||
   ! grep -qF 'in vec2 mc_midTexCoord;' "$shaders/lib/body/shadow.vsh" ||
   ! grep -qF 'smoothstep(mc_midTexCoord.y - 1.0e-4,' "$shaders/lib/body/opaque.vsh" ||
   ! grep -qF 'smoothstep(mc_midTexCoord.y - 1.0e-4,' "$shaders/lib/body/shadow.vsh"; then
    fail "vegetation sway must anchor vertices at the sprite base with mc_midTexCoord in both passes"
fi
if ! grep -qF 'minecraft:oak_leaves' "$block_props"; then
    fail "shaders/block.properties: vegetation needs an explicit leaf fallback list"
fi
for entry in gbuffers_water.vsh gbuffers_water.fsh; do
    if ! grep -qF '#define NOVA_WATER_MATERIAL_ID' "$shaders/$entry"; then
        fail "$entry does not enable the water material ID path"
    fi
done
for entry in gbuffers_terrain.vsh gbuffers_terrain.fsh shadow.vsh; do
    if ! grep -qF '#define NOVA_VEGETATION_SWAY' "$shaders/$entry"; then
        fail "$entry does not enable vegetation sway in both terrain stages and shadows"
    fi
done

section "integrated GPU performance profile"

if ! grep -qF '#if SHADOWS == 0' "$shaders/shaders.properties" ||
   ! grep -qF 'shadow.enabled = false' "$shaders/shaders.properties" ||
   ! grep -qF 'profile.PERFORMANCE =' "$shaders/shaders.properties" ||
   ! grep -qF 'SHADOWS=0' "$shaders/shaders.properties" ||
   ! grep -qF 'profile.PERFORMANCE=Performance' "$lang"; then
    fail "PERFORMANCE profile must disable the Iris shadow pass and have a visible label"
fi

section "water opacity and cloud shape"

if ! grep -qF 'float depthAlpha = max(0.82, novaWaterOpacity(thickness));' "$shaders/lib/body/water.fsh"; then
    fail "horizontal water must retain a tinted translucent body instead of becoming clear"
fi
if ! grep -qF 'alpha = clamp(mix(albedo.a, depthAlpha, sheet), 0.0, 0.97);' "$shaders/lib/body/water.fsh"; then
    fail "stronger water opacity must be restricted to horizontal sheets; vertical faces retain texture alpha"
fi

section "cloud horizon stability"

sky="$shaders/lib/sky.glsl"
if ! grep -qF 'float fieldScale = mix(0.0140, 0.0012, horizonLod);' "$sky" ||
   ! grep -qF 'worldXZ.y * 0.78 - worldXZ.x * 0.11' "$sky"; then
    fail "cloud field must use broad, asymmetric cloud masses across the sky"
fi
if ! grep -qF 'float horizonMass = valueNoise(horizonXZ * fieldScale + wind);' "$sky"; then
    fail "horizon LOD must use the same asymmetric cloud domain as the main samples"
fi

if ! grep -qF 'float horizonLod = smoothstep(30.0, 150.0, stepLength);' "$sky" ||
   ! grep -qF 'mass = mix(mass, horizonMass, horizonBlend);' "$sky"; then
    fail "cloud march does not blend to a stable low-frequency horizon field"
fi
if ! grep -qF '1.0 - horizonLod, horizonMass, horizonLod' "$sky"; then
    fail "cloud horizon density is not shared across the ray-march samples"
fi
if ! grep -qF 'float opticalDepthLimit = mix(8.0, 0.90, horizonLod);' "$sky" ||
   ! grep -qF 'opticalDepth = min(opticalDepth, opticalDepthLimit);' "$sky"; then
    fail "cloud ray-march optical depth is not bounded at the horizon"
fi
if ! grep -qF 'float jitter = novaDither(gl_FragCoord.xy) * (1.0 - horizonLod);' "$sky"; then
    fail "cloud pixel jitter must fade out through the horizon LOD"
fi

section "preprocessor balance"

for file in "${sources[@]}"; do
    rel="${file#"$root"/}"
    open=()

    while IFS=$'\t' read -r line token; do
        case "$token" in
            if|ifdef|ifndef)
                open+=("$line")
                ;;
            elif|else)
                if [ "${#open[@]}" -eq 0 ]; then
                    fail "$rel:$line: #$token with no #if"
                fi
                ;;
            endif)
                if [ "${#open[@]}" -eq 0 ]; then
                    fail "$rel:$line: #endif with no #if"
                else
                    unset "open[$(( ${#open[@]} - 1 ))]"
                fi
                ;;
        esac
    done < <(awk '
        /^[[:space:]]*#[[:space:]]*(if|ifdef|ifndef|elif|else|endif)([^A-Za-z0-9_]|$)/ {
            text = $0
            sub(/^[[:space:]]*#[[:space:]]*/, "", text)
            match(text, /^[A-Za-z]+/)
            print NR "\t" substr(text, 1, RLENGTH)
        }
    ' "$file")

    if [ "${#open[@]}" -gt 0 ]; then
        fail "$rel: conditional opened at line ${open[${#open[@]}-1]} is never closed"
    fi
done

section "options"

if [ -f "$props" ] && [ -f "$lang" ]; then
    mapfile -t option_names < <(
        grep -vE '^[[:space:]]*screen(\.[A-Za-z0-9_]+)?\.columns[[:space:]]*=' "$props" |
            sed -n 's/^[[:space:]]*\(screen\(\.[A-Za-z0-9_]*\)\?\|sliders\|profile\.[A-Za-z0-9_]*\)[[:space:]]*=[[:space:]]*//p' |
            tr ' ' '\n' |
            sed 's/[[:space:]]*$//' |
            sed 's/[=:].*$//' |
            sed 's/^!//' |
            grep -v '^$' |
            grep -v '^\[.*\]$' |
            grep -v '^<.*>$' |
            grep -v '^\*$' |
            grep -v '^[0-9.]*$' |
            sort -u
    )

    for name in "${option_names[@]}"; do
        case "$name" in
            *.columns) continue ;;
        esac

        if ! grep -rqE "^[[:space:]]*#define[[:space:]]+$name([[:space:]]|$)|^[[:space:]]*const[[:space:]]+(int|float)[[:space:]]+$name[[:space:]]*=" \
            --include='*.glsl' --include='*.vsh' --include='*.fsh' "$shaders"; then
            fail "option $name is used in shaders.properties but is not defined in the shaders"
        fi

        if ! grep -qE "^option\.$name[[:space:]]*=" "$lang"; then
            fail "option $name has no label in shaders/lang/en_us.lang"
        fi
    done

    printf '%d options referenced by shaders.properties\n' "${#option_names[@]}"

    if ! grep -qE '^[[:space:]]*profile\.' "$props"; then
        fail "shaders.properties defines no presets"
    fi
    if ! grep -qE '^[[:space:]]*sliders[[:space:]]*=' "$props"; then
        fail "shaders.properties has no sliders list"
    fi
fi

section "result"

if [ "$errors" -gt 0 ]; then
    printf '%d problem(s) found\n' "$errors" >&2
    exit 1
fi

printf 'all checks passed\n'
