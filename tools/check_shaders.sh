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

for required in shaders/shaders.properties shaders/lang/en_us.lang pack.mcmeta LICENSE VERSION; do
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

mapfile -t sources < <(find "$shaders" -type f \( -name '*.vsh' -o -name '*.fsh' -o -name '*.glsl' \) | sort)

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
