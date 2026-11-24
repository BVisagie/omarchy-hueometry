// Builds qml/Hueometry/js/levels.mjs (the tutorial and the six areas of the
// Lost Jungle Temple) and qml/Hueometry/js/free.mjs (the free-play pool).
// Run with bin/levels. Nothing here ships except the two modules it writes:
// ES modules rather than JSON, because QML imports them directly.
//
// Each level is a seed: the game regenerates the board with the Bend engine,
// so the modules hold no board they could get wrong. Each level also stores a
// solution found by solve.mjs and verified here by the engine: `par` is its
// length, and `optimal` is true only when A* proved it shortest.

import * as R from "../../qml/Hueometry/js/rules.mjs";
import { solve, lowerBound } from "./solve.mjs";

import { writeModule, packId } from "./write.mjs";
// Bump when engine/gen.bend changes what a seed produces.
const GENERATOR = 2;

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
// Free play draws from these pre-solved puzzles, so its hints follow a short
// solution too.
const FREE = { beginner: 60, easy: 60, medium: 60, hard: 60, expert: 30 };

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

// `from` keeps free-play seeds apart from level seeds.
function sample(name, count, from = 1) {
  const d = DIFFICULTY[name];
  const out = [];
  for (let seed = from; out.length < count && seed < from + 5000; seed++) {
    const tag = `${name}:${seed}`;
    const p = R.generate(d.colours, d.cap, seed);
    if (!p) continue;
    const s = solveLevel(d, p.columns);
    if (!s || s.moves.length < d.minPar) continue;
    out.push({ seed, par: s.moves.length, optimal: s.optimal, lower: lowerBound(p.columns), solution: s.moves.map((m) => [m.from, m.to]) });
    process.stderr.write(`${tag} par ${s.moves.length}${s.optimal ? " (optimal)" : ""}\n`);
  }
  if (out.length < count) {
    throw new Error(`${name}: found only ${out.length} of ${count} qualifying seeds; the pack was not written`);
  }
  return out;
}

function byHardness(x, y) {
  return x.lower - y.lower || x.par - y.par;
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
    // order by the solver's lower bound, which does not depend on how hard
    // the search had to work, then by par
    samples.set(a.difficulty, sample(a.difficulty, PER_AREA * twice).sort(byHardness));
  }
  const pool = samples.get(a.difficulty);
  const levels = a.pick === "harder" ? pool.splice(pool.length - PER_AREA) : pool.splice(0, PER_AREA);
  levels.sort(byHardness);
  areas.push({ id: a.id, colours: d.colours, cap: d.cap, levels });
}

const free = {};
for (const [name, count] of Object.entries(FREE)) {
  const d = DIFFICULTY[name];
  free[name] = { colours: d.colours, cap: d.cap, puzzles: sample(name, count, 10001) };
}

const pack = packId({ tutorial, areas, free });
writeModule("levels.mjs", { version: 1, generator: GENERATOR, pack, tutorial, areas });
writeModule("free.mjs", { version: 1, generator: GENERATOR, pack, puzzles: free });
