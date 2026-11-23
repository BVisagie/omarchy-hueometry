import { test } from "node:test";
import assert from "node:assert/strict";
import * as R from "../../qml/Hueometry/js/rules.mjs";
import { lowerBound } from "../../tools/levels/solve.mjs";

import levels from "../../qml/Hueometry/js/levels.mjs";
import free from "../../qml/Hueometry/js/free.mjs";

const pack = { ...levels, free: free.puzzles };
const moves = (s) => s.map(([from, to]) => ({ from, to }));

const check = (colours, cap, l, where) => {
  const p = R.generate(colours, cap, l.seed);
  assert.ok(p, `${where} seed ${l.seed}`);
  const end = R.replay(R.newGame(colours, cap, p.columns), moves(l.solution));
  assert.ok(R.solved(end), `${where} seed ${l.seed}`);
  assert.equal(R.moves(end), l.par);
  assert.equal(lowerBound(p.columns), l.lower);
  assert.ok(l.lower <= l.par);
};

// Only an exact A* search may mark a par optimal: the tutorial, Beginner and
// Easy. Harder puzzles must never claim it.
const EXACT = new Set(["clearing", "river", "beginner", "easy"]);

test("every level's board comes from its seed and its solution solves it in par moves", () => {
  for (const t of pack.tutorial) {
    const end = R.replay(R.newGame(t.colours, t.cap, t.columns), moves(t.solution));
    assert.ok(R.solved(end));
    assert.equal(R.moves(end), t.par);
  }
  assert.equal(pack.areas.length, 6);
  for (const a of pack.areas) {
    assert.equal(a.levels.length, 8);
    for (const l of a.levels) {
      check(a.colours, a.cap, l, a.id);
      assert.equal(l.optimal, EXACT.has(a.id), `${a.id} optimal flag`);
    }
    const lows = a.levels.map((l) => l.lower);
    assert.deepEqual(lows, [...lows].sort((x, y) => x - y), `${a.id} levels are ordered by lower bound`);
  }
  for (const t of pack.tutorial) assert.equal(t.optimal, true);
});

test("free play puzzles are pre-solved, with seeds apart from the levels", () => {
  const levelSeeds = new Set(pack.areas.flatMap((a) => a.levels.map((l) => `${a.colours}x${a.cap}:${l.seed}`)));
  for (const [name, f] of Object.entries(pack.free)) {
    assert.ok(f.puzzles.length >= 16, name);
    for (const l of f.puzzles) {
      check(f.colours, f.cap, l, name);
      assert.equal(l.optimal, EXACT.has(name), `${name} optimal flag`);
      assert.ok(!levelSeeds.has(`${f.colours}x${f.cap}:${l.seed}`));
    }
  }
});
