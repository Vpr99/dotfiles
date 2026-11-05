#!/usr/bin/env bash
# Render an OpenSCAD file to one PNG per view, and optionally an STL.
#   render.sh part.scad [-o NAME] [--stl] [-D 'var=value' ...]
# Views come from VIEWS="name:rx,ry,rz ..." (OpenSCAD gimbal rotation). The defaults suit a
# wall-mounted part with the wall on the XZ plane at y=0 and the part sticking out +Y.
# PNGs use preview mode, so %/color(alpha) ghost parts show; the STL never includes them
# if the file gates them behind show_ghosts.
set -euo pipefail

scad="${1:?usage: render.sh part.scad [-o NAME] [--stl] [-D var=value ...]}"; shift
name="$(basename "$scad" .scad)"; stl=0; defs=()
while [ $# -gt 0 ]; do
  case "$1" in
    -o) name="$2"; shift 2 ;;
    --stl) stl=1; shift ;;
    -D) defs+=(-D "$2"); shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
dir="$(dirname "$scad")"
VIEWS="${VIEWS:-front:55,0,215 back:75,0,15 below:125,0,210}"

fail=0
for v in $VIEWS; do
  out="$dir/${name}_${v%%:*}.png"
  log="$(openscad -o "$out" --imgsize=1000,750 --viewall --autocenter --colorscheme=Tomorrow \
    --camera="0,0,0,${v#*:},0" "${defs[@]+"${defs[@]}"}" "$scad" 2>&1)" || fail=1
  grep -E "WARNING|ERROR|[Aa]ssert" <<<"$log" && fail=1
  echo "$out"
done
if [ "$stl" = 1 ]; then
  log="$(openscad -o "$dir/$name.stl" --export-format asciistl -D show_ghosts=false "${defs[@]+"${defs[@]}"}" "$scad" 2>&1)" || fail=1
  grep -E "WARNING|ERROR|[Aa]ssert" <<<"$log" && fail=1
  echo "$dir/$name.stl $(node "$(dirname "$0")/stlvol.mjs" "$dir/$name.stl" | awk '{print $(NF-1), $NF}')"
fi
exit "$fail"
