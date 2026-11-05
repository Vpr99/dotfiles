// Rounded triangle cutouts in alternating (Warren truss) rows, shared by every part in this folder.
// tri_row() builds cutters in local XY: the row runs along +X from x0 to x1, apexes alternate ±Y,
// and they cut Z = 0..depth with a chamfer on the Z = depth face.
function tri_base(x0, x1, n, gap = 3.5) = (x1 - x0 - (n - 1)*gap) / ((n - 1)/2 + 1);
function tri_cx(x0, b, i, gap = 3.5) = x0 + b/2 + i*(b/2 + gap);
// Largest circle inside an isosceles triangle; its center sits this far above the base.
function tri_inradius(b, h) = b*h / (b + 2*sqrt(b*b/4 + h*h));

module rtri(pts, r) offset(r = r) offset(delta = -r) polygon(pts);

module tri_row(x0, x1, n, h, depth, first_up = true, gap = 3.5, r = 1.2, chamfer = 0.6) {
  b = tri_base(x0, x1, n, gap);
  for (i = [0:n - 1]) let(cx = tri_cx(x0, b, i, gap), up = (i % 2 == 0) == first_up, hh = h/2,
      pts = up ? [[cx - b/2, -hh], [cx + b/2, -hh], [cx, hh]] : [[cx - b/2, hh], [cx + b/2, hh], [cx, -hh]])
    hull() {
      translate([0, 0, -1]) linear_extrude(depth + 1 - chamfer) rtri(pts, r);
      translate([0, 0, depth - 0.01]) linear_extrude(1) offset(delta = chamfer) rtri(pts, r);
    }
}
