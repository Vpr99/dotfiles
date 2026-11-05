# 3D modeling reference

## Chamfers and fillets

Include BOSL2 at the top: `include <BOSL2/std.scad>` and `include <BOSL2/rounding.scad>`. Its `circle()`,
`square()`, and `cylinder()` modules behave like the built-ins, and it adds function forms that return paths.

**Slab with every perimeter edge chamfered. Works on concave outlines (slots, notches):**

```openscad
module chamfered_slab(region, h, c = 1)
    offset_sweep(region, height = h, bottom = os_chamfer(width = c), top = os_chamfer(width = c));

// Build the outline as a region with BOSL2 function forms, not modules:
hull_pts = let(p = concat(move([x0, 0], square([w, t])), move([0, cy], circle(r = R)))) select(p, hull(p));
outline  = difference(hull_pts, union(move([0, cy], circle(r = r)), move([-r, cy], square([2 * r, cy]))));
rounded  = offset(offset(outline, delta = -2, closed = true), r = 2, closed = true);   // round convex corners
chamfered_slab(rounded, 8);
```

Use `os_circle(r = ...)` instead of `os_chamfer` for rounded edges.

**Pocket or hole with a chamfered rim.** Split the shape into convex pieces and hull each one:

```openscad
module chamfered_cut(top, c = 1) for (i = [0:$children - 1]) hull() {
    translate([0, 0, -1]) linear_extrude(top - c + 1) children(i);
    translate([0, 0, top]) linear_extrude(1) offset(delta = c) children(i);
}
translate([0, cy, floor_z]) chamfered_cut(depth) { circle(r = rs); translate([-rs, 0]) square([2 * rs, 50]); }
```

**Fillet strip in an inside corner** (for example, where a shelf meets a back plate). Draw it as a YZ profile and extrude it along X:

```openscad
translate([x0, 0, 0]) rotate([90, 0, 90]) linear_extrude(len) difference() {
    translate([plate_t, -f]) square(f);
    translate([plate_t + f, -f]) circle(r = f);
}
```

**2D rounding, for parts extruded from one profile:**
`offset(r = -f) offset(delta = f)` fillets inside corners, and `offset(r = f) offset(delta = -f)` rounds outside corners.

## Failure modes

- **`minkowski()` with a concave operand** fails with `CGAL error: assertion violation` / `Discarded N facets`
  and leaves a broken mesh. A zero-thickness `linear_extrude(0.01)` does the same. Use `offset_sweep` or a hull per convex piece instead.
- **`hull()` of a non-convex child** fills in its slots and notches. Hull convex pieces only.
- **Holes covered by later geometry.** A hole cut by an inner `difference()` gets filled when you union more geometry over it.
  Make the screw holes and cutouts the last `difference()`.
- **`grep -i error` on OpenSCAD output** matches `Status: NoError`. Match `WARNING|ERROR|assert` case-sensitively.

## Truss cutouts (`assets/tri.scad`)

`tri_row(x0, x1, n, h, depth, first_up = true, gap = 3.5, r = 1.2, chamfer = 0.6)` makes a row of rounded triangles
along +X between x0 and x1, centered on y=0, cutting Z 0..depth. The `depth` face is chamfered. Apexes alternate.
`n = 1` gives a single ▲. Helpers: `tri_base`, `tri_cx`, `tri_inradius` (to put a screw in a triangle's incircle).

- **Cutting a plate that lies in XZ:** use `multmatrix([[1,0,0,0],[0,0,1,0],[0,1,0,0]])`, which maps local Y to Z and Z to Y.
- **Turning a row:** use `rotate([0, 0, 90])` so it lands between supports.
- **Gussets:** cut a window with `offset(r = 1.5) offset(delta = -inset - 1.5) polygon(pts)`.
- **Style:** one ▲ per bay with the screw above its apex looks cleaner than a busy row of small triangles.

## Rendering

- `render.sh` views are OpenSCAD gimbal rotations `rx,ry,rz` in the form `name:rx,ry,rz`. The defaults
  (`front:55,0,215 back:75,0,15 below:125,0,210`) look at a part whose front faces +Y.
  For a part whose front faces -Y, use `VIEWS="front:55,0,25 back:55,0,205"`.
- **Close-up of one feature:** `openscad -o x.png --camera=cx,cy,cz,rx,ry,rz,dist part.scad`, without `--viewall`.
- **Volume:** `node scripts/stlvol.mjs a.stl b.stl` needs ASCII STLs (`--export-format asciistl`). Compare before and after lightening.

## Slicing

- `slice.sh` uses the system presets `Original Prusa MINI & MINI+ Input Shaper`, `0.20mm STRUCTURAL @MINIIS 0.4`,
  and `Generic PLA @MINIIS`. Its defaults are 4 perimeters and 20% gyroid. For a small part, perimeters give more strength than infill does.
- **Overrides:** environment variables `PRINT_PROFILE`, `MATERIAL_PROFILE`, `PERIMETERS`, `INFILL`, and `SUPPORTS=1`.
  Any other PrusaSlicer flag goes after the output path.
- **Always pass `--no-support-material` explicitly.** Without it, the slice came out with `support_material = 1`.
- **Always pass `--no-binary-gcode`.** The MINI profile writes `.bgcode` by default, and OctoPrint can't stream that.
- **Check the result:** `max_layer_z` should match the expected print height, and the first-layer footprint should match the face you meant to put on the bed.
