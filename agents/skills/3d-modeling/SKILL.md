---
name: 3d-modeling
description: Designs parametric 3D-printable parts in OpenSCAD + BOSL2, renders preview PNGs to review, exports STLs, and slices them with PrusaSlicer for Eric's Prusa MINI+ (PLA). Use when the user wants to design, model, refine, or print a physical part (bracket, mount, holder, clip, shelf, enclosure), mentions OpenSCAD, .scad, STL, fillets/chamfers on a part, print orientation, slicing, or G-code. Hand the finished G-code to the octoprint skill.
---

# 3D modeling (OpenSCAD → STL → G-code)

Tools: `openscad` (CLI), BOSL2 in `~/Documents/OpenSCAD/libraries`, PrusaSlicer.app.
Printer: Prusa MINI+ with input shaper, 180×180×180 bed, 0.4 nozzle, PLA unless told otherwise.
Projects live in the Obsidian vault (`~/Vault`, a git repo), following the vault project layout:
`~/Vault/Projects/<Name>/<Name>.md`, with every
artifact (.scad, tri.scad, PNGs, STL, G-code, ref/ photos) in `files/`. The note has frontmatter
(`type: project`, `tags: [project, 3d-printing, openscad]`, `created`, `updated`), the key dimensions,
the design decisions, print settings, and a post-print checklist. See `Projects/Tripod wall bracket/`.
Older parts in `~/Documents/OpenSCAD/desk/` show the house style.

## Quick start

```bash
S=~/.agents/skills/3d-modeling/scripts
$S/render.sh part.scad --stl            # part_front/back/below.png + part.stl + volume; exit 1 on any warning
$S/slice.sh part.stl --rotate-x 90      # part_PLA_MINI.gcode + time, grams, first-layer footprint
```

Then Read every PNG. Never report a design you haven't looked at.

## Workflow

1. **Gather dimensions.** Get each critical dimension and the clearance it needs. Ask what the part
   rests on and which way the load goes. Convert HEIC photos with `sips -s format jpeg -Z 1200 in.HEIC --out ref/x.jpg`
   and look at them. A photo often shows a constraint the user didn't mention (a lever, a lobe, a flange).
2. **Rough concepts first.** Put 2–4 different approaches in one file behind `concept = "a"; // [a, b, c]`.
   Render each one, show the user, and recommend one. Don't refine anything until they pick.
3. **Model for context.** Draw the mating parts as ghosts (`color("gray", 0.35)`) behind `show_ghosts = true`.
   `render.sh --stl` forces `show_ghosts=false`.
4. **Refine.** Delete the concepts that lost. Then add, in this order:
   - Retention (a seat pocket you lift out of, a detent).
   - Chamfers and fillets. Use the BOSL2 recipes in [REFERENCE.md](REFERENCE.md).
   - Lightening cutouts. Use the truss triangles in `assets/tri.scad` (Eric's house style). Copy the file into the project and `use <tri.scad>`.
5. **Check every cutout against the load path.** A cutout must not land under a gusset, rib, or screw head.
   Add an `assert()` that encodes the clearance. Leave the main load path solid.
6. **Choose the print orientation.** Layer lines should run along the bending stress, and no supports
   should be needed (bridges ≤ ~10mm, overhangs ≤ 45°). When orientation trades away strength, estimate the stress.
   Pass the rotation to `slice.sh` (`--rotate-x 90` puts a -Y-facing face on the bed). Check the first-layer footprint it prints.
7. **Write the project note** with the dimensions and decisions. Keep it current as the design changes.
8. **Slice and hand off.** `slice.sh` writes plain `.gcode`. Upload it with the `octoprint` skill. Don't start the print unless the user asks.

## Rules

- Keep every dimension a named variable at the top, with a short comment giving its meaning or source.
- Put critical clearances in their own variables (`clr`, `seat_clr`). Keep the calibration knobs; real printers drift.
- Mark a deliberate shortcut with `// ponytail:` and name its limit.
- Wall mounts into drywall: #8 countersunk screws with self-drilling anchors. Put the screws high so the bottom edge bears on the wall.
  Every screw needs a straight path for the driver: check gussets.
- PLA creeps above ~55°C. Use PETG near heat or sun, or for snap-fits that stay flexed.
- In zsh, `$VAR` holding several flags is not split into words. Pass flags inline or use an array.

See [REFERENCE.md](REFERENCE.md) for chamfer and fillet code, camera angles, `tri.scad` usage, and OpenSCAD failure modes.
