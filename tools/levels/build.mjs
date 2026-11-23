// Builds qml/Hueometry/data/levels.json: the tutorial and the six areas of
// the Lost Jungle Temple. Run with bin/levels. Nothing here ships except the
// JSON it writes.
//
// Each level is a seed: the game regenerates the board with the Bend engine,
// so the JSON holds no board it could get wrong. Each level also stores a
// solution found by solve.mjs and verified here by the engine: `par` is its
// length, and `optimal` is true only when A* proved it shortest.

import { writeFileSync } from "node:fs";
import * as R from "../../qml/Hueometry/js/rules.mjs";
import { solve } from "./solve.mjs";

const OUT = new URL("../../qml/Hueometry/data/levels.json", import.meta.url);
// Bump when engine/gen.bend changes what a seed produces.
const GENERATOR = 1;

const DIFFICULTY = {
  beginner: { colours: 3, cap: 3, minPar: 5, weights: [1] },
  easy: { colours: 4, cap: 4, minPar: 12, weights: [1] },
  medium: { colours: 5, cap: 5, minPar: 20, weights: [1.5, 2] },
  hard: { colours: 6, cap: 6, minPar: 35, weights: [2, 3] },
  expert: { colours: 6, cap: 10, minPar: 60, weights: [8, 12] },
};

// Area, difficulty, and which part of a sorted sample of puzzles it takes:
// "easier" keeps the lowest pars, "harder" the highest.
const AREAS = [
  { id: "clearing", difficulty: "beginner", pick: "easier" },
  { id: "river", difficulty: "easy", pick: "easier" },
  { id: "ruins", difficulty: "medium", pick: "easier" },
  { id: "waterfall", difficulty: "hard", pick: "easier" },
  { id: "temple", difficulty: "hard", pick: "harder" },
  { id: "heart", difficulty: "expert", pick: "easier" },
];
const PER_AREA = 8;

// Hand-made first boards: two colours, then three.
const TUTORIAL = [
  { colours: 2, cap: 2, columns: [[1, 0], [0, 1], []] },
  { colours: 2, cap: 3, columns: [[0, 1, 0], [1, 0, 1], []] },
  { colours: 3, cap: 2, columns: [[0, 1], [2, 0], [1, 2], []] },
];

function verified(colours, cap, columns, moves) {
  const end = R.replay(R.newGame(colours, cap, columns), moves);
  if (!R.solved(end) || R.moves(end) !== moves.length) throw new Error("solver answer failed in the engine");
  return moves;
}

function solveLevel(d, columns) {
  for (const weight of d.weights) {
    const r = solve(d.colours, d.cap, columns, { weight, budget: 400_000 });
    if (r) return { moves: verified(d.colours, d.cap, columns, r.moves), optimal: r.optimal };
  }
  return null;
}

const used = new Set();
function sample(name, count) {
  const d = DIFFICULTY[name];
  const out = [];
  for (let seed = 1; out.length < count && seed < 5000; seed++) {
    const tag = `${name}:${seed}`;
    if (used.has(tag)) continue;
    const p = R.generate(d.colours, d.cap, seed);
    if (!p) continue;
    const s = solveLevel(d, p.columns);
    if (!s || s.moves.length < d.minPar) continue;
    out.push({ seed, par: s.moves.length, optimal: s.optimal, solution: s.moves.map((m) => [m.from, m.to]) });
    process.stderr.write(`${tag} par ${s.moves.length}${s.optimal ? " (optimal)" : ""}\n`);
  }
  if (out.length < count) {
    throw new Error(`${name}: found only ${out.length} of ${count} qualifying seeds; the pack was not written`);
  }
  return out;
}

const tutorial = TUTORIAL.map((t) => {
  const r = solve(t.colours, t.cap, t.columns, { weight: 1 });
  const moves = verified(t.colours, t.cap, t.columns, r.moves);
  return { ...t, par: moves.length, optimal: true, solution: moves.map((m) => [m.from, m.to]) };
});

const areas = [];
const samples = new Map();
for (const a of AREAS) {
  const d = DIFFICULTY[a.difficulty];
  if (!samples.has(a.difficulty)) {
    const twice = AREAS.filter((x) => x.difficulty === a.difficulty).length;
    samples.set(a.difficulty, sample(a.difficulty, PER_AREA * twice).sort((x, y) => x.par - y.par));
  }
  const pool = samples.get(a.difficulty);
  const levels = a.pick === "harder" ? pool.splice(pool.length - PER_AREA) : pool.splice(0, PER_AREA);
  levels.sort((x, y) => x.par - y.par);
  areas.push({ id: a.id, colours: d.colours, cap: d.cap, levels });
}

writeFileSync(OUT, JSON.stringify({ version: 1, generator: GENERATOR, tutorial, areas }, null, 1) + "\n");
console.log(`wrote ${OUT.pathname}`);
