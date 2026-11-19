#!/usr/bin/env bash
#
# Nova Shaders - build the shader pack archive.
#
# The archive root must hold shaders/, pack.mcmeta and LICENSE, because that is
# what the shader pack loader and the mod distribution expect.

set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

version="$(tr -d '[:space:]' < VERSION)"
if [ -z "$version" ]; then
    printf 'error: VERSION is empty\n' >&2
    exit 1
fi

out="build/nova-shaders-${version}-shaderpack.zip"
mkdir -p build
rm -f "$out"

if command -v zip >/dev/null 2>&1; then
    zip -q -r -X "$out" shaders pack.mcmeta LICENSE THIRD-PARTY-NOTICES.txt -x '*.DS_Store' '__MACOSX/*'
else
    # Fallback for machines without zip; keeps the same archive layout.
    python3 - "$out" <<'PY'
import os
import sys
import zipfile

out = sys.argv[1]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as archive:
    archive.write("pack.mcmeta", "pack.mcmeta")
    archive.write("LICENSE", "LICENSE")
    archive.write("THIRD-PARTY-NOTICES.txt", "THIRD-PARTY-NOTICES.txt")
    for base, dirs, files in os.walk("shaders"):
        dirs.sort()
        for name in sorted(files):
            if name == ".DS_Store":
                continue
            path = os.path.join(base, name)
            archive.write(path, path)
PY
fi

# Never publish an archive that is missing something the loader needs.
missing=0
if command -v unzip >/dev/null 2>&1; then
    for required in pack.mcmeta LICENSE THIRD-PARTY-NOTICES.txt shaders/shaders.properties shaders/composite.fsh shaders/final.fsh shaders/lang/en_us.lang; do
        if ! unzip -l "$out" | grep -qE " ${required}$"; then
            printf 'error: %s is missing from the archive\n' "$required" >&2
            missing=1
        fi
    done
fi

if [ "$missing" -ne 0 ]; then
    exit 1
fi

printf 'wrote %s (%s bytes)\n' "$out" "$(wc -c < "$out" | tr -d '[:space:]')"

# Build the optional companion resource pack as a separate ZIP. It must not be
# merged into the shader archive: Minecraft loads it from the resource-pack list.
foliage_root="companion/nova-natural-foliage"
foliage_out="build/nova-natural-foliage-${version}.zip"
rm -f "$foliage_out"

if command -v zip >/dev/null 2>&1; then
    (cd "$foliage_root" && zip -q -r -X "$root/$foliage_out" pack.mcmeta README.md LICENSE THIRD-PARTY-NOTICES.txt assets -x '*.DS_Store' '__MACOSX/*')
else
    python3 - "$foliage_root" "$foliage_out" <<'PY'
import os
import sys
import zipfile

source, output = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
    for name in ("pack.mcmeta", "README.md", "LICENSE", "THIRD-PARTY-NOTICES.txt"):\n        archive.write(os.path.join(source, name), name)\n    for base, dirs, files in os.walk(os.path.join(source, "assets")):
        dirs.sort()
        for name in sorted(files):
            if name == ".DS_Store":
                continue
            path = os.path.join(base, name)
            archive.write(path, os.path.relpath(path, source))
PY
fi

if command -v unzip >/dev/null 2>&1; then
    for required in pack.mcmeta LICENSE README.md THIRD-PARTY-NOTICES.txt assets/nova/models/block/natural_leaves.json assets/minecraft/blockstates/oak_leaves.json assets/minecraft/blockstates/grass_block.json; do
        if ! unzip -l "$foliage_out" | grep -qE " ${required}$"; then
            printf 'error: optional foliage archive is missing %s\\n' "$required" >&2
            exit 1
        fi
    done
fi

printf 'wrote %s (%s bytes)\\n' "$foliage_out" "$(wc -c < "$foliage_out" | tr -d '[:space:]')"
