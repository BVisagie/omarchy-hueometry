// The JavaScript twin of tests/native/gen.bend: same seeds, same format.
import * as R from "../../qml/Hueometry/js/rules.mjs";

const runs = [[6, 3, 3], [6, 4, 4], [6, 5, 5], [6, 6, 6], [4, 6, 10]];
for (const [n, colours, cap] of runs) {
  for (let p = n - 1; p >= 0; p--) {
    const seed = Math.imul(p, 2654435761) >>> 0;
    const g = R.generate(colours, cap, seed);
    const board = g ? g.columns.map((c) => "[" + c.map((b) => b + ",").join("") + "]").join("") + " " + g.solution.map((m) => `${m.from}>${m.to} `).join("") : "none";
    console.log(`${colours}x${cap} ${seed} ${board}`);
  }
}
