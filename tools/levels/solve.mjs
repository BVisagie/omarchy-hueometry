// A puzzle solver for the level tools. It never ships with the game.
//
// It searches with a fast model of the rules (tests/engine/model.mjs) and
// returns a move list; build.mjs then replays every solution through the
// Bend engine, so a model mistake can only cost a level, never ship a wrong
// one.
//
// h(board) is a lower bound on the moves left: a bead with a different
// colour anywhere below it must move at least once, and of the columns whose
// bottom run is the same colour, all but the longest run must move too. With
// weight 1 the search is A* and its answer is a shortest solution.

import { legal, move, solved } from "../../tests/engine/model.mjs";

export function lowerBound(cols) {
  let h = 0;
  const best = new Map(); // colour -> [longest bottom run, sum of runs]
  for (const c of cols) {
    if (c.length === 0) continue;
    const bottom = c[c.length - 1];
    let run = 0;
    while (run < c.length && c[c.length - 1 - run] === bottom) run++;
    h += c.length - run;
    const [max, sum] = best.get(bottom) ?? [0, 0];
    best.set(bottom, [Math.max(max, run), sum + run]);
  }
  for (const [max, sum] of best.values()) h += sum - max;
  return h;
}

// columns in a fixed order: boards that differ only by column order are the
// same position
const key = (cols) => cols.map((c) => c.join(",")).sort().join("|");

class Heap {
  constructor() { this.a = []; }
  get size() { return this.a.length; }
  push(x) {
    const a = this.a;
    a.push(x);
    for (let i = a.length - 1; i > 0;) {
      const p = (i - 1) >> 1;
      if (a[p].f <= a[i].f) break;
      [a[p], a[i]] = [a[i], a[p]];
      i = p;
    }
  }
  pop() {
    const a = this.a, top = a[0], last = a.pop();
    if (a.length) {
      a[0] = last;
      for (let i = 0; ;) {
        const l = 2 * i + 1, r = l + 1;
        let m = i;
        if (l < a.length && a[l].f < a[m].f) m = l;
        if (r < a.length && a[r].f < a[m].f) m = r;
        if (m === i) break;
        [a[m], a[i]] = [a[i], a[m]];
        i = m;
      }
    }
    return top;
  }
}

// Answers { moves, optimal, expanded } or null when the node budget runs out.
export function solve(colours, cap, start, { weight = 1, budget = 2_000_000 } = {}) {
  const open = new Heap();
  const seen = new Map();
  const node = (cols, g, parent, mv) => ({ cols, g, f: g + weight * lowerBound(cols), parent, mv });
  open.push(node(start, 0, null, null));
  seen.set(key(start), 0);
  let expanded = 0;
  while (open.size) {
    const n = open.pop();
    if (seen.get(key(n.cols)) < n.g) continue;
    if (solved(colours, cap, n.cols)) {
      const moves = [];
      for (let x = n; x.parent; x = x.parent) moves.push(x.mv);
      return { moves: moves.reverse(), optimal: weight === 1, expanded };
    }
    if (++expanded > budget) return null;
    for (let from = 0; from < n.cols.length; from++) {
      for (let to = 0; to < n.cols.length; to++) {
        if (!legal(cap, n.cols, from, to)) continue;
        const next = move(n.cols, from, to);
        const k = key(next);
        const g = n.g + 1;
        if (seen.has(k) && seen.get(k) <= g) continue;
        seen.set(k, g);
        open.push(node(next, g, n, { from, to }));
      }
    }
  }
  return null;
}
