import { test } from "node:test";
import assert from "node:assert/strict";
import fc from "fast-check";
import * as R from "../../qml/Hueometry/js/rules.mjs";
import * as M from "./model.mjs";

const solvedBoard = (colours, cap) =>
  [...Array.from({ length: colours }, (_, c) => Array(cap).fill(c)), []];

test("a bead may land on a different colour", () => {
  const g = R.newGame(2, 2, [[0, 1], [1], [0]]);
  const r = R.play(g, 0, 1);
  assert.equal(r.accepted, true);
  assert.equal(r.bead, 0);
  assert.deepEqual(R.view(r.game).columns, [[1], [0, 1], [0]]);
  assert.equal(R.moves(r.game), 1);
});

test("invalid boards are refused", () => {
  for (const [c, k, cols] of [
    [2, 2, [[0], [1], []]], [2, 2, [[0, 0], [0, 0], []]], [2, 2, [[0, 1, 1], [0], []]],
    [2, 2, [[0, 1], [1, 0]]], [2, 2, [[0, 1], [1, 2], []]], [0, 2, [[]]], [2, 0, [[], [], []]],
    [2, 2, [[0, -1], [1, 0], []]], [2, 2, "nope"],
  ]) {
    assert.equal(R.valid(c, k, cols), false, JSON.stringify(cols));
    assert.throws(() => R.newGame(c, k, cols), RangeError);
  }
  assert.equal(R.valid(2, 2, [[0, 1], [1, 0], []]), true);
});

const LEVELS = [[3, 3], [4, 4], [5, 5], [6, 6], [6, 10]];

test("generated puzzles are valid, unsolved, reproducible and solved by their solution", () => {
  for (const [c, k] of LEVELS) {
    for (let seed = 0; seed < 12; seed++) {
      const p = R.generate(c, k, seed * 7919 + 1);
      assert.ok(p, `no puzzle for ${c}x${k} seed ${seed}`);
      assert.ok(R.valid(c, k, p.columns));
      assert.equal(p.columns.filter((col) => col.length === 0).length, 1);
      const g = R.newGame(c, k, p.columns);
      assert.equal(R.solved(g), false);
      const end = R.replay(g, p.solution);
      assert.equal(R.solved(end), true);
      assert.equal(R.moves(end), p.solution.length, "every certificate move is legal");
      assert.deepEqual(R.generate(c, k, seed * 7919 + 1), p);
    }
  }
  assert.equal(R.generate(0, 3, 1), null);
  assert.equal(R.generate(3, 0, 1), null);
});

test("hints follow the solution and lead back to it", () => {
  const p = R.generate(4, 4, 42);
  let g = R.newGame(4, 4, p.columns);
  for (let n = 0; n < p.solution.length && !R.solved(g); n++) {
    const h = R.hint(g, p.solution);
    assert.equal(h.kind, "play");
    const r = R.play(g, h.from, h.to);
    assert.equal(r.accepted, true);
    g = r.game;
  }
  assert.equal(R.solved(g), true);
  assert.deepEqual(R.hint(g, p.solution), { kind: "solved" });

  // leave the solution with a move it does not make: the hint says go back
  g = R.newGame(4, 4, p.columns);
  const first = R.hint(g, p.solution);
  const off = R.targets(g, first.from).map((t) => ({ from: first.from, to: t }))
    .concat(...[0, 1, 2, 3, 4].map((f) => R.targets(g, f).map((t) => ({ from: f, to: t }))))
    .find((m) => !(m.from === first.from && m.to === first.to));
  const away = R.play(g, off.from, off.to).game;
  const back = R.hint(away, p.solution);
  if (back.kind === "back") {
    assert.equal(back.steps, 1);
  } else {
    // the move happened to land on another board of the solution
    assert.equal(back.kind, "play");
  }
});

test("refusals name their reason and change nothing", () => {
  const g = R.newGame(2, 2, [[0, 1], [1, 0], []]);
  for (const [from, to, reason] of [
    [0, 7, "no-such-column"], [9, 0, "no-such-column"], [-1, 0, "no-such-column"],
    [0, 0, "same-column"], [2, 0, "empty-source"], [0, 1, "full-target"],
  ]) {
    const r = R.play(g, from, to);
    assert.equal(r.accepted, false);
    assert.equal(r.reason, reason);
    assert.equal(r.game, g);
    assert.equal(R.moves(r.game), 0);
  }
});

test("undo, restart and victory", () => {
  let g = R.newGame(2, 2, [[0, 1], [0, 1], []]);
  for (const [f, t] of [[0, 2], [1, 2], [1, 0]]) g = R.play(g, f, t).game;
  assert.deepEqual(R.view(g).columns, [[1, 1], [], [0, 0]]);
  assert.equal(R.solved(g), true);
  assert.equal(R.moves(g), 3);
  assert.deepEqual(R.history(g), [{ from: 0, to: 2 }, { from: 1, to: 2 }, { from: 1, to: 0 }]);
  const back = R.undo(g);
  assert.equal(R.moves(back), 2);
  assert.equal(R.solved(back), false);
  assert.deepEqual(R.view(R.restart(g)).columns, [[0, 1], [0, 1], []]);
  assert.equal(R.moves(R.restart(g)), 0);
  assert.deepEqual(R.view(R.undo(R.newGame(1, 1, [[0], []]))).columns, [[0], []]);
});

// A random game: a solved board, then random legal moves.
const arbGame = fc.record({ colours: fc.integer({ min: 1, max: 6 }), cap: fc.integer({ min: 1, max: 6 }) })
  .chain(({ colours, cap }) => fc.record({
    colours: fc.constant(colours),
    cap: fc.constant(cap),
    moves: fc.array(fc.tuple(fc.nat(colours + 1), fc.nat(colours + 1)), { minLength: 20, maxLength: 150 }),
  }));

test("the engine agrees with the model on every move", () => {
  fc.assert(fc.property(arbGame, ({ colours, cap, moves }) => {
    let cols = solvedBoard(colours, cap);
    let g = R.newGame(colours, cap, cols);
    let count = 0;
    for (const [from, to] of moves) {
      const ok = M.legal(cap, cols, from, to);
      assert.deepEqual(R.targets(g, from).includes(to), ok);
      const r = R.play(g, from, to);
      assert.equal(r.accepted, ok);
      assert.equal(r.bead, ok ? cols[from][0] : null);
      if (ok) {
        cols = M.move(cols, from, to);
        count++;
        assert.deepEqual(R.view(R.undo(r.game)).columns, R.view(g).columns);
      } else {
        assert.equal(r.game, g);
      }
      g = r.game;
      assert.deepEqual(R.view(g).columns, cols);
      assert.equal(R.moves(g), count);
      assert.equal(R.solved(g), M.solved(colours, cap, cols));
      assert.deepEqual(M.counts(cols), M.counts(solvedBoard(colours, cap)));
      assert.ok(cols.every((c) => c.length <= cap));
    }
    const again = R.replay(R.newGame(colours, cap, solvedBoard(colours, cap)), R.history(g));
    assert.deepEqual(R.view(again).columns, cols);
  }), { numRuns: 500 });
});

test("replay agrees with playing each move, malformed moves included", () => {
  const junk = fc.oneof(fc.integer({ min: -3, max: 9 }), fc.constant(1.5), fc.constant(NaN),
    fc.constant(2 ** 60), fc.constant("1"), fc.constant(null));
  fc.assert(fc.property(fc.array(fc.record({ from: junk, to: junk }), { minLength: 10, maxLength: 80 }), (ms) => {
    const start = R.newGame(3, 3, [[0, 1, 2], [2, 0, 1], [1, 2, 0], []]);
    let g = start;
    for (const m of ms) g = R.play(g, m.from, m.to).game;
    const again = R.replay(start, ms);
    assert.deepEqual(R.view(again), R.view(g));
  }), { numRuns: 300 });
});

test("very long games do not overflow the stack", () => {
  let g = R.newGame(1, 1, [[0], []]);
  for (let k = 0; k < 30000; k++) g = R.play(g, k % 2, (k + 1) % 2).game;
  assert.equal(R.moves(g), 30000);
  assert.deepEqual(R.view(g).columns, [[0], []]);
});
