// An independent model of the rules in section 3 of the brief, written
// straight from the text. Tests compare the engine with it; the game never
// uses it.

export function legal(cap, cols, from, to) {
  return Number.isInteger(from) && Number.isInteger(to) &&
    from >= 0 && to >= 0 && from < cols.length && to < cols.length &&
    from !== to && cols[from].length > 0 && cols[to].length < cap;
}

// columns list beads top first
export function move(cols, from, to) {
  const next = cols.map((c) => c.slice());
  const bead = next[from].shift();
  next[to].unshift(bead);
  return next;
}

// A column that holds beads of one colour only and is full.
export function complete(cap, col) {
  return col.length === cap && col.every((b) => b === col[0]);
}

export function solved(colours, cap, cols) {
  const empty = cols.filter((c) => c.length === 0).length;
  if (empty !== 1) return false;
  const seen = new Set();
  for (const c of cols) {
    if (c.length === 0) continue;
    if (c.length !== cap || c.some((b) => b !== c[0])) return false;
    if (seen.has(c[0])) return false;
    seen.add(c[0]);
  }
  return seen.size === colours;
}

export function counts(cols) {
  const n = new Map();
  for (const c of cols) for (const b of c) n.set(b, (n.get(b) ?? 0) + 1);
  return n;
}
