import levels from "./levels.mjs";

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

// One setting changed: apply it to the settings on disk, so a change in one
// host never undoes a different change made in another.
export function withSetting(raw, key, value) {
  const next = settings(raw);
  next[key] = value;
  return settings(JSON.stringify(next));
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

// progress: { tutorial: bool, done: { key: { best, assisted } }, current,
//   currentAt }
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
  // an unfinished puzzle from another pack names a different board: drop it
  const current = p.current && p.current.ref && Array.isArray(p.current.moves) && p.current.pack === PACK
    ? { ref: p.current.ref, moves: p.current.moves, assisted: p.current.assisted === true, pack: PACK } : null;
  // when `current` last changed (set or cleared), so the newest copy wins
  const currentAt = Number.isFinite(p.currentAt) ? p.currentAt : 0;
  return { tutorial: tutorialDone(done), done, current, currentAt };
}

// The tutorial is done when all three of its puzzles are.
function tutorialDone(done) {
  return [0, 1, 2].every((i) => !!done[key({ kind: "tutorial", index: i })]);
}

// Levels and free-play puzzles are named by their place in the level pack,
// so a record names the pack too: a new pack (generator) starts fresh
// records rather than crediting a best to a different board.
export const PACK = levels.generator;

export function key(ref) {
  if (ref.kind === "tutorial") return `${PACK}:tutorial/${ref.index}`;
  if (ref.kind === "level") return `${PACK}:${ref.area}/${ref.index}`;
  return `${PACK}:free/${ref.difficulty}/${ref.index}`;
}

// The better of two records: fewer moves, and unassisted beats assisted.
function better(a, b) {
  if (!a) return b;
  if (!b) return a;
  if (a.assisted !== b.assisted) return a.assisted ? b : a;
  return a.best <= b.best ? a : b;
}

// Records combine (the better of each); the unfinished puzzle is the one
// changed most recently, which may be "none" if it was finished elsewhere.
export function merge(disk, mine) {
  const done = Object.assign({}, disk.done);
  for (const [k, v] of Object.entries(mine.done)) done[k] = better(done[k], v);
  // newest wins; on a tie (saves without a time), a puzzle beats none
  const dt = mine.currentAt || 0, ot = disk.currentAt || 0;
  const newer = dt > ot ? mine : ot > dt ? disk : (mine.current ? mine : disk);
  return { tutorial: tutorialDone(done), done, current: newer.current, currentAt: newer.currentAt || 0 };
}

// The unfinished puzzle changed (at a time in milliseconds).
export function setCurrent(p, current, at) {
  return Object.assign({}, p, { current: current ? Object.assign({ pack: PACK }, current) : null, currentAt: at });
}

// Records a solved puzzle. Answers { progress, record } where record says
// whether this beat the previous best ("first", "better", "same", "worse").
export function solved(p, ref, moveCount, assisted, at) {
  const k = key(ref);
  const before = p.done[k];
  const now = { best: moveCount, assisted: assisted === true };
  const kept = better(before, now);
  let record = "first";
  if (before) record = kept === now && (now.best < before.best || (before.assisted && !now.assisted)) ? "better" : now.best === before.best ? "same" : "worse";
  const done = Object.assign({}, p.done);
  done[k] = kept;
  return {
    progress: Object.assign({}, p, { tutorial: tutorialDone(done), done, current: null, currentAt: at || 0 }),
    record, previous: before || null, assisted: now.assisted, best: kept,
  };
}

// An area opens once five levels of the one before it are done.
export const TO_OPEN = 5;

// how many of an area's puzzles are done ("tutorial" for the first steps)
export function doneIn(p, area, count) {
  let n = 0;
  for (let i = 0; i < count; i++) {
    if (p.done[key(area === "tutorial" ? { kind: "tutorial", index: i } : { kind: "level", area, index: i })]) n++;
  }
  return n;
}

export function areaOpen(p, areas, index, perArea) {
  if (index === 0) return true;
  return doneIn(p, areas[index - 1], perArea) >= TO_OPEN;
}
