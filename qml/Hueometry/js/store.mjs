// Progress and settings, as plain data, and how two copies of the progress
// combine. The standalone app and the shell plugin share one save folder;
// progress only ever grows (a level done stays done, a best only improves),
// so merging what is on disk with what is in memory before every write loses
// nothing, whichever copy writes last.

export const SETTINGS = {
  music: 0.6,
  effects: 0.8,
  muted: false,
  reducedMotion: false,
  symbols: false,
  layout: "line",
  scale: 1.0,
};

const num = (x, lo, hi, d) => (typeof x === "number" && x >= lo && x <= hi ? x : d);

export function settings(raw) {
  const s = parse(raw);
  return {
    music: num(s.music, 0, 1, SETTINGS.music),
    effects: num(s.effects, 0, 1, SETTINGS.effects),
    muted: s.muted === true,
    reducedMotion: s.reducedMotion === true,
    symbols: s.symbols === true,
    layout: s.layout === "circle" ? "circle" : "line",
    scale: num(s.scale, 0.75, 1.5, SETTINGS.scale),
  };
}

function parse(raw) {
  if (typeof raw !== "string" || raw === "") return {};
  try {
    const v = JSON.parse(raw);
    return v && typeof v === "object" && !Array.isArray(v) ? v : {};
  } catch (e) {
    return {};
  }
}

// progress: { tutorial: bool, done: { key: { best, assisted } }, current }
// key: "area/index", "tutorial/index" or "free/difficulty/index".
// `assisted` is true when the best was reached with a hint.
// `current` is the puzzle left unfinished: { ref, moves: [[from, to]],
// assisted } (assisted: a hint was used in it).
export function progress(raw) {
  const p = parse(raw);
  const done = {};
  if (p.done && typeof p.done === "object") {
    for (const [k, v] of Object.entries(p.done)) {
      if (v && Number.isInteger(v.best) && v.best > 0) done[k] = { best: v.best, assisted: v.assisted === true };
    }
  }
  const current = p.current && p.current.ref && Array.isArray(p.current.moves)
    ? { ref: p.current.ref, moves: p.current.moves, assisted: p.current.assisted === true } : null;
  return { tutorial: p.tutorial === true, done, current };
}

export function key(ref) {
  if (ref.kind === "tutorial") return `tutorial/${ref.index}`;
  if (ref.kind === "level") return `${ref.area}/${ref.index}`;
  return `free/${ref.difficulty}/${ref.index}`;
}

// The better of two records: fewer moves, and unassisted beats assisted.
function better(a, b) {
  if (!a) return b;
  if (!b) return a;
  if (a.assisted !== b.assisted) return a.assisted ? b : a;
  return a.best <= b.best ? a : b;
}

export function merge(disk, mine) {
  const done = Object.assign({}, disk.done);
  for (const [k, v] of Object.entries(mine.done)) done[k] = better(done[k], v);
  return { tutorial: disk.tutorial || mine.tutorial, done, current: mine.current };
}

// Records a solved puzzle. Answers { progress, record } where record says
// whether this beat the previous best ("first", "better", "same", "worse").
export function solved(p, ref, moveCount, assisted) {
  const k = key(ref);
  const before = p.done[k];
  const now = { best: moveCount, assisted: assisted === true };
  const kept = better(before, now);
  let record = "first";
  if (before) record = kept === now && (now.best < before.best || (before.assisted && !now.assisted)) ? "better" : now.best === before.best ? "same" : "worse";
  // the tutorial is done when all three of its puzzles are
  const tutorial = p.tutorial || [0, 1, 2].every((i) => (i === ref.index && ref.kind === "tutorial") || !!p.done[`tutorial/${i}`]);
  const done = Object.assign({}, p.done);
  done[k] = kept;
  return { progress: Object.assign({}, p, { tutorial, done, current: null }), record, previous: before || null };
}

// An area opens once five levels of the one before it are done.
export const TO_OPEN = 5;

export function doneIn(p, area, count) {
  let n = 0;
  for (let i = 0; i < count; i++) if (p.done[`${area}/${i}`]) n++;
  return n;
}

export function areaOpen(p, areas, index, perArea) {
  if (index === 0) return true;
  return doneIn(p, areas[index - 1], perArea) >= TO_OPEN;
}
