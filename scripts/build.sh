#!/usr/bin/env bash
# Build / flash the Gowin project straight from the CLI.
#
# Single source of truth: the *.gprj file. Device and source list are parsed
# from it, so there is nothing to keep in sync here.
#
# Usage (run from anywhere):
#   scripts/build.sh              # synthesize + place&route + bitstream
#   scripts/build.sh flash        # flash last bitstream to SRAM (volatile)
#   scripts/build.sh flash-spi    # write bitstream to onboard flash (persistent)
#   scripts/build.sh all          # build, then flash to SRAM
#
# Override autodetected paths/board via env vars if needed:
#   GWSH=/path/to/gw_sh  LOADER_BOARD=tangnano1k  scripts/build.sh

set -euo pipefail

# --- locate the project file -------------------------------------------------
# The .gprj lives under gowin/; its <File> paths are relative to that dir, and
# Gowin writes impl/ next to it, so we run the whole build from the .gprj's dir.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GPRJ_PATH="$(find "$REPO_ROOT" -maxdepth 2 -name '*.gprj' 2>/dev/null | head -n1 || true)"
[ -n "$GPRJ_PATH" ] || { echo "error: no *.gprj found under $REPO_ROOT" >&2; exit 1; }
cd "$(dirname "$GPRJ_PATH")"
GPRJ="$(basename "$GPRJ_PATH")"
BASE="${GPRJ%.gprj}"

# --- locate the Gowin toolchain ----------------------------------------------
GW_RES="/Applications/GowinIDE.app/Contents/Resources/Gowin_EDA"
GWSH="${GWSH:-$GW_RES/IDE/bin/gw_sh}"
# gw_sh ships with broken @rpath/absolute dylib refs; point dyld at the bundled libs.
GW_LIB="$(dirname "$GWSH")/../lib"
export DYLD_LIBRARY_PATH="$GW_LIB${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
export DYLD_FRAMEWORK_PATH="$GW_LIB${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}"
LOADER="${LOADER:-$(command -v openFPGALoader || true)}"
LOADER_BOARD="${LOADER_BOARD:-tangnano1k}"

# --- parse device + file list from the .gprj (tolerant of the malformed decl) -
read_gprj() {  # $1 = "device" | "files"
  python3 - "$GPRJ" "$1" <<'PY'
import sys, re, xml.etree.ElementTree as ET
path, what = sys.argv[1], sys.argv[2]
text = open(path, encoding="utf-8").read()
# Gowin emits <?xml version="1" ...?>; normalize so the parser accepts it.
text = re.sub(r'<\?xml[^>]*\?>', '<?xml version="1.0" encoding="UTF-8"?>', text, count=1)
root = ET.fromstring(text)
if what == "device":
    d = root.find(".//Device")
    print(d.get("name", ""), d.get("pn", ""))
else:
    for f in root.findall(".//FileList/File"):
        if f.get("enable", "1") == "1":
            print(f.get("path"))
PY
}

do_build() {
  read DEV_NAME DEV_PN < <(read_gprj device)
  [ -n "$DEV_NAME" ] || { echo "error: no <Device> in $GPRJ" >&2; exit 1; }
  [ -x "$GWSH" ] || { echo "error: gw_sh not found at $GWSH (set GWSH=...)" >&2; exit 1; }

  TCL="$(mktemp -t ${BASE}_build.XXXXXX.tcl)"
  trap 'rm -f "$TCL"' RETURN

  {
    echo "set_device -name $DEV_NAME $DEV_PN"
    while IFS= read -r f; do
      [ -n "$f" ] && echo "add_file \"$f\""
    done < <(read_gprj files)
    echo "set_option -synthesis_tool gowinsynthesis"
    echo "set_option -output_base_name $BASE"
    echo "run all"
  } > "$TCL"

  echo ">> Device: $DEV_NAME ($DEV_PN)"
  echo ">> Running gw_sh ($GWSH)"
  "$GWSH" "$TCL"
  echo ">> Bitstream: impl/pnr/$BASE.fs"
}

bitstream() {
  local fs="impl/pnr/$BASE.fs"
  [ -f "$fs" ] || { echo "error: $fs not found — run a build first" >&2; exit 1; }
  echo "$fs"
}

do_flash() {  # $1 = "" (SRAM) | "-f" (flash)
  [ -n "$LOADER" ] || { echo "error: openFPGALoader not found (brew install openFPGALoader)" >&2; exit 1; }
  local fs; fs="$(bitstream)"
  echo ">> Flashing $fs via $LOADER (board=$LOADER_BOARD) ${1:+[to flash]}"
  "$LOADER" -b "$LOADER_BOARD" ${1:+$1} "$fs"
}

case "${1:-build}" in
  build)     do_build ;;
  flash)     do_flash ;;
  flash-spi) do_flash -f ;;
  all)       do_build; do_flash ;;
  *) echo "usage: $0 [build|flash|flash-spi|all]" >&2; exit 1 ;;
esac
