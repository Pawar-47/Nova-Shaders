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
