#!/usr/bin/env bash
#
# Reproducibly builds the bundled CJK fonts declared in pubspec.yaml.
#
# Downloads the upstream Noto Serif SC / Noto Sans SC *variable* fonts, pins a
# static weight (varLib.instancer), then subsets (pyftsubset) to a
# comprehensive-but-lean glyph set for Chinese novels. The Regular weights are
# copied into assets/fonts/ (what the app actually ships); Bold/Medium are left
# in the build dir for optional future use — the engine synthesizes bold today.
#
# Requires: python3 with `fonttools` (pip install fonttools brotli), curl.
# Usage:    tool/build_fonts.sh
set -euo pipefail

# Resolve repo root from this script's location so it runs from anywhere.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ASSETS="$REPO_ROOT/assets/fonts"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$ASSETS" "$WORK/src" "$WORK/out"

echo "=== [1/4] downloading variable fonts ==="
curl -sL --retry 3 --max-time 300 -o "$WORK/src/serif-var.ttf" \
  "https://github.com/google/fonts/raw/main/ofl/notoserifsc/NotoSerifSC%5Bwght%5D.ttf"
curl -sL --retry 3 --max-time 300 -o "$WORK/src/sans-var.ttf" \
  "https://github.com/google/fonts/raw/main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf"
ls -la "$WORK/src/serif-var.ttf" "$WORK/src/sans-var.ttf"

# Comprehensive-but-lean coverage for Chinese novels:
#   main CJK ideographs (U+4E00-9FFF) + Latin + CJK/general punctuation +
#   fullwidth forms + kana (some novels quote Japanese) + compat ideographs.
# Deliberately DROP CJK Ext-A/B (rare) and non-CJK scripts to control size;
# any glyph outside this set falls back to the platform CJK font at runtime.
RANGES="U+0020-007E,U+00A0-00FF,U+2010-201F,U+2020-2027,U+2030-205E,U+2E80-2EFF,U+3000-303F,U+3040-309F,U+30A0-30FF,U+31C0-31EF,U+3200-33FF,U+4E00-9FFF,U+F900-FAFF,U+FE10-FE1F,U+FE30-FE4F,U+FF00-FFEF"

instance_and_subset () {
  local src="$1" wght="$2" out="$3"
  echo "--- instancing $(basename "$src") @ wght=$wght ---"
  fonttools varLib.instancer "$src" "wght=$wght" -o "$WORK/src/_inst.ttf" --quiet
  echo "--- subsetting -> $out ---"
  pyftsubset "$WORK/src/_inst.ttf" \
    --output-file="$WORK/out/$out" \
    --unicodes="$RANGES" \
    --layout-features='ccmp,locl,mark,mkmk,kern,vert,vrt2,halt,vhal' \
    --no-hinting \
    --name-IDs='' \
    --notdef-outline \
    --recalc-bounds
  rm -f "$WORK/src/_inst.ttf"
}

echo "=== [2/4] serif (reading + titles): Regular + Bold ==="
instance_and_subset "$WORK/src/serif-var.ttf" 400 NotoSerifSC-Regular.ttf
instance_and_subset "$WORK/src/serif-var.ttf" 700 NotoSerifSC-Bold.ttf

echo "=== [3/4] sans (UI chrome): Regular + Medium ==="
instance_and_subset "$WORK/src/sans-var.ttf" 400 NotoSansSC-Regular.ttf
instance_and_subset "$WORK/src/sans-var.ttf" 500 NotoSansSC-Medium.ttf

echo "=== [4/4] installing Regular weights into assets/fonts/ ==="
cp "$WORK/out/NotoSerifSC-Regular.ttf" "$ASSETS/NotoSerifSC-Regular.ttf"
cp "$WORK/out/NotoSansSC-Regular.ttf" "$ASSETS/NotoSansSC-Regular.ttf"
ls -la "$ASSETS"
echo "--- build dir also has Bold/Medium if you later want to ship them: ---"
ls -la "$WORK/out/"
echo "FONT_BUILD_DONE"
