// Prints volume (cm^3) of ASCII STLs: node stlvol.mjs a.stl b.stl
import { readFileSync } from "node:fs";
for (const f of process.argv.slice(2)) {
  const v = [...readFileSync(f, "utf8").matchAll(/vertex\s+(\S+)\s+(\S+)\s+(\S+)/g)].map(m => m.slice(1).map(Number));
  let vol = 0;
  for (let i = 0; i < v.length; i += 3) {
    const [a, b, c] = [v[i], v[i + 1], v[i + 2]];
    vol += (a[0] * (b[1] * c[2] - b[2] * c[1]) - a[1] * (b[0] * c[2] - b[2] * c[0]) + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6;
  }
  console.log(f, (Math.abs(vol) / 1000).toFixed(1), "cm3");
}
