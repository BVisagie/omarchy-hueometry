import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import * as R from "../../qml/Hueometry/js/rules.mjs";

const pack = JSON.parse(readFileSync(new URL("../../qml/Hueometry/data/levels.json", import.meta.url)));
const moves = (s) => s.map(([from, to]) => ({ from, to }));

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
      const p = R.generate(a.colours, a.cap, l.seed);
      assert.ok(p, `${a.id} seed ${l.seed}`);
      const end = R.replay(R.newGame(a.colours, a.cap, p.columns), moves(l.solution));
      assert.ok(R.solved(end), `${a.id} seed ${l.seed}`);
      assert.equal(R.moves(end), l.par);
    }
    const pars = a.levels.map((l) => l.par);
    assert.deepEqual(pars, [...pars].sort((x, y) => x - y), `${a.id} levels get harder`);
  }
});
