#!/usr/bin/env bash
# Slice an STL for the Prusa MINI+ (input shaper) in PLA and print a verification summary.
#   slice.sh part.stl [out.gcode] [extra PrusaSlicer args, e.g. --rotate-x 90]
# Plain .gcode (not .bgcode) so OctoPrint can stream it. Supports are off unless SUPPORTS=1.
set -euo pipefail

stl="${1:?usage: slice.sh part.stl [out.gcode] [prusaslicer args...]}"; shift
out="${stl%.stl}_PLA_MINI.gcode"
if [ $# -gt 0 ] && [[ "$1" == *.gcode ]]; then out="$1"; shift; fi
supports=--no-support-material; [ "${SUPPORTS:-0}" = 1 ] && supports=--support-material

/Applications/PrusaSlicer.app/Contents/MacOS/PrusaSlicer --export-gcode \
  --printer-profile "Original Prusa MINI & MINI+ Input Shaper" \
  --print-profile "${PRINT_PROFILE:-0.20mm STRUCTURAL @MINIIS 0.4}" \
  --material-profile "${MATERIAL_PROFILE:-Generic PLA @MINIIS}" \
  --center 90,90 --perimeters "${PERIMETERS:-4}" --fill-density "${INFILL:-20%}" --fill-pattern gyroid \
  --no-binary-gcode "$supports" "$@" --output "$out" "$stl" | tail -1

grep -E "^; (estimated printing time \(normal mode\)|filament used \[g\]|max_layer_z|support_material|perimeters|fill_density|layer_height|binary_gcode) =" "$out"
# First-layer footprint: confirms orientation and that the part fits the 180x180 bed
awk '/^;LAYER_CHANGE/{n++} n==1 && /^G1 .*X.*Y.*E/{for(i=1;i<=NF;i++){c=substr($i,1,1);v=substr($i,2)+0; if(c=="X")x=v; if(c=="Y")y=v}
  if(!s){nx=mx=x;ny=my=y;s=1} if(x>mx)mx=x; if(x<nx)nx=x; if(y>my)my=y; if(y<ny)ny=y}
  END{printf "first layer: X %.1f-%.1f (%.1fmm)  Y %.1f-%.1f (%.1fmm)\n",nx,mx,mx-nx,ny,my,my-ny}' "$out"
echo "$out"
