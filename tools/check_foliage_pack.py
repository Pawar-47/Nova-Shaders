#!/usr/bin/env python3
"""Validate the optional Nova Natural Foliage Lite resource pack."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "companion" / "nova-natural-foliage"
errors = []
for required in ("pack.mcmeta", "README.md", "LICENSE", "THIRD-PARTY-NOTICES.txt"):
    if not (ROOT / required).is_file():
        print(f"error: missing companion pack file {required}")
        errors.append(required)

def fail(message):
    errors.append(message)
    print(f"error: {message}")

def read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"{path.relative_to(ROOT)} is not valid JSON: {exc}")
        return None

meta = read_json(ROOT / "pack.mcmeta")
if meta:
    pack = meta.get("pack", {})
    if pack.get("pack_format") != 55:
        fail("pack.mcmeta must target Minecraft 1.21.5 resource pack format 55")

base_path = ROOT / "assets/nova/models/block/natural_leaves.json"
base = read_json(base_path)
if base:
    if base.get("render_type") != "minecraft:cutout_mipped":
        fail("natural_leaves.json must preserve the vanilla cutout-mipped leaf render layer")
    elements = base.get("elements", [])
    if len(elements) != 2:
        fail("natural_leaves.json must contain one cube and one lightweight foliage plane")
    if not any(e.get("rotation", {}).get("angle") == 22.5 for e in elements):
        fail("natural_leaves.json is missing its angled foliage plane")

blockstates = sorted((ROOT / "assets/minecraft/blockstates").glob("*_leaves.json"))
models = sorted((ROOT / "assets/minecraft/models/block").glob("*_leaves.json"))
if len(blockstates) != 11 or len(models) != 11:
    fail(f"expected 11 vanilla leaf blockstates and models, found {len(blockstates)} and {len(models)}")

for state_path in blockstates:
    state = read_json(state_path)
    if not state:
        continue
    variants = state.get("variants", {}).get("")
    if not isinstance(variants, list) or len(variants) != 4:
        fail(f"{state_path.name} must randomize four horizontal model rotations")
        continue
    model_name = state_path.stem
    for variant in variants:
        expected = f"minecraft:block/{model_name}"
        if variant.get("model") != expected:
            fail(f"{state_path.name} references unexpected model {variant.get('model')!r}")
        model_path = ROOT / "assets/minecraft/models/block" / f"{model_name}.json"
        if not model_path.is_file():
            fail(f"{state_path.name} references missing {model_path.name}")

grass_state = read_json(ROOT / "assets/minecraft/blockstates/grass_block.json")
grass_model = read_json(ROOT / "assets/minecraft/models/block/grass_block.json")
if grass_state:
    grass_variants = grass_state.get("variants", {})
    grass_rotations = grass_variants.get("snowy=false")
    if not isinstance(grass_rotations, list) or len(grass_rotations) != 4:
        fail("grass_block snowy=false must keep four randomized fringe-model rotations")
    else:
        for variant in grass_rotations:
            if variant.get("model") != "minecraft:block/grass_block":
                fail("grass_block snowy=false must use the companion grass-block model")
    if grass_variants.get("snowy=true", {}).get("model") != "minecraft:block/grass_block_snow":
        fail("grass_block snowy=true must retain Minecraft's vanilla snow-covered model")
if grass_model:
    if len(grass_model.get("elements", [])) != 2:
        fail("grass_block model must contain the vanilla cube and one edge-fringe overlay")
    if grass_model.get("textures", {}).get("overlay") != "block/grass_block_side_overlay":
        fail("grass_block model must use the vanilla grass side overlay texture")

plant_species = {
    "short_grass": "tinted",
    "fern": "tinted",
    "seagrass": "tinted",
    "dead_bush": "untinted",
    "bush": "untinted",
    "short_dry_grass": "untinted",
    "tall_dry_grass": "untinted",
    "nether_sprouts": "untinted",
}
for tint_mode in ("tinted", "untinted"):
    plant_base = read_json(ROOT / f"assets/nova/models/block/natural_plant_{tint_mode}.json")
    if not plant_base:
        continue
    elements = plant_base.get("elements", [])
    if len(elements) != 3:
        fail(f"natural_plant_{tint_mode}.json must contain three crossed plant planes")
        continue
    if plant_base.get("ambientocclusion") is not False:
        fail(f"natural_plant_{tint_mode}.json must disable ambient occlusion on thin crossed planes")
    for element in elements:
        faces = element.get("faces", {})
        if not {"north", "south"}.issubset(faces):
            fail(f"natural_plant_{tint_mode}.json planes must render on both sides")
        for face_name in ("north", "south"):
            face = faces.get(face_name, {})
            if tint_mode == "tinted" and face.get("tintindex") != 0:
                fail("tinted plant planes must preserve biome tint index 0")
            if tint_mode == "untinted" and "tintindex" in face:
                fail("untinted plant planes must not apply biome tint")

for name, tint_mode in plant_species.items():
    state = read_json(ROOT / f"assets/minecraft/blockstates/{name}.json")
    model = read_json(ROOT / f"assets/minecraft/models/block/{name}.json")
    plant_rotations = state.get("variants", {}).get("") if state else None
    if not isinstance(plant_rotations, list) or len(plant_rotations) != 4:
        fail(f"{name}.json blockstate must offer four horizontal rotations")
    else:
        for variant in plant_rotations:
            if variant.get("model") != f"minecraft:block/{name}":
                fail(f"{name}.json blockstate references an unexpected model")
    if model:
        if model.get("parent") != f"nova:block/natural_plant_{tint_mode}":
            fail(f"{name}.json must inherit the {tint_mode} plant model")
        if model.get("textures", {}).get("cross") != f"minecraft:block/{name}":
            fail(f"{name}.json must use its matching vanilla texture")

for model_path in models:
    model = read_json(model_path)
    if not model:
        continue
    expected_texture = f"minecraft:block/{model_path.stem}"
    if model.get("parent") != "nova:block/natural_leaves":
        fail(f"{model_path.name} must inherit nova:block/natural_leaves")
    if model.get("textures", {}).get("all") != expected_texture:
        fail(f"{model_path.name} must use its matching vanilla texture {expected_texture}")

if errors:
    raise SystemExit(1)
print(f"validated {len(blockstates)} vanilla leaf models, {len(plant_species)} plant models, and grass-block variants")
