import { test } from "node:test";
import assert from "node:assert/strict";
import * as S from "../../qml/Hueometry/js/session.mjs";
import * as St from "../../qml/Hueometry/js/store.mjs";
import * as L from "../../qml/Hueometry/js/layout.mjs";

// a save key: records name the level pack they belong to
const k = (name) => `${St.PACK}:${name}`;

test("a level plays to the end by following its own hints", () => {
  const p = S.puzzle({ kind: "level", area: "clearing", index: 0 });
  let s = S.start(p);
  for (let n = 0; n < 50 && !S.view(s).solved; n++) {
    const h = S.hint(s);
    assert.equal(h.kind, "play");
    let r = S.touch(s, h.from);
    assert.equal(r.effect.kind, "lift");
    r = S.touch(r.state, h.to);
    assert.equal(r.effect.kind, "move");
    s = r.state;
  }
  assert.equal(S.view(s).solved, true);
  assert.equal(S.view(s).moves, p.par);
});

test("touching columns lifts, drops, refuses and ignores as it should", () => {
  let s = S.start(S.puzzle({ kind: "tutorial", index: 0 }));
  assert.equal(S.touch(s, 2).effect.kind, "empty");
  let r = S.touch(s, 0);
  assert.equal(r.effect.kind, "lift");
  assert.deepEqual(S.view(r.state).targets, [2]);
  assert.equal(S.touch(r.state, 0).effect.kind, "drop");
  const refused = S.touch(r.state, 1);
  assert.equal(refused.effect.kind, "refuse");
  assert.equal(refused.effect.reason, "full-target");
  assert.equal(refused.state.selected, 0, "the orb stays lifted");
  assert.equal(S.touch(s, 99).effect.kind, "none");
  assert.equal(S.puzzle({ kind: "level", area: "nowhere", index: 0 }), null);
  assert.equal(S.puzzle({ kind: "free", difficulty: "easy", index: 1e6 }), null);
});

test("a saved game resumes through the engine", () => {
  const p = S.puzzle({ kind: "free", difficulty: "easy", index: 3 });
  let s = S.start(p);
  s = S.touch(S.touch(s, p.solution[0].from).state, p.solution[0].to).state;
  const saved = S.history(s);
  const back = S.resume(p, saved.concat([{ from: -4, to: 2 }]));
  assert.deepEqual(S.view(back).columns, S.view(s).columns);
  assert.equal(S.view(back).moves, 1);
});

test("progress merges keep the best of both copies", () => {
  const a = St.progress(JSON.stringify({ done: { [k("clearing/0")]: { best: 9 }, [k("clearing/1")]: { best: 7, assisted: true } } }));
  const b = St.progress(JSON.stringify({ done: { [k("tutorial/0")]: { best: 3 }, [k("tutorial/1")]: { best: 6 }, [k("tutorial/2")]: { best: 4 }, [k("clearing/0")]: { best: 11 }, [k("clearing/1")]: { best: 9 } } }));
  const m = St.merge(a, b);
  assert.deepEqual(m.done[k("clearing/0")], { best: 9, assisted: false });
  assert.deepEqual(m.done[k("clearing/1")], { best: 9, assisted: false });
  assert.equal(m.tutorial, true);
  assert.deepEqual(St.progress("not json"), { tutorial: false, done: {}, current: null, currentAt: 0 });
  const r1 = St.solved(St.progress(""), { kind: "level", area: "clearing", index: 0 }, 10, false);
  assert.equal(r1.record, "first");
  const r2 = St.solved(r1.progress, { kind: "level", area: "clearing", index: 0 }, 8, false);
  assert.equal(r2.record, "better");
  assert.equal(St.solved(r2.progress, { kind: "level", area: "clearing", index: 0 }, 12, false).record, "worse");
  assert.equal(St.settings('{"layout":"circle","music":7}').music, St.SETTINGS.music);
});

test("layouts place every column inside the board and walk them in order", () => {
  for (const pattern of L.PATTERNS) {
    for (const n of [3, 4, 5, 6, 7]) {
      for (const [w, h] of [[1280, 720], [800, 1000], [3840, 2160]]) {
        const out = L.place(pattern, n, w, h, 6);
        assert.equal(out.columns.length, n);
        for (const c of out.columns) {
          for (const p of [L.along(c, 0, out.unit), L.liftedAt(c, 6, out.unit)]) {
            assert.ok(p.x >= 0 && p.x <= w && p.y >= 0 && p.y <= h, `${pattern} ${n} ${w}x${h} inside`);
          }
        }
        assert.deepEqual([...out.order].sort(), [...Array(n).keys()].sort());
        // every column is found at its middle, at its top bead and above it
        out.columns.forEach((c, i) => {
          for (const k of [0, 3, 5]) {
            const p = L.beadAt(c, k, out.unit);
            assert.equal(L.hit(out.columns, p.x, p.y, out.unit), i, `${pattern} ${n} col ${i} bead ${k}`);
          }
          const q = L.liftedAt(c, 6, out.unit);
          assert.equal(L.hit(out.columns, q.x, q.y, out.unit), i, `${pattern} ${n} col ${i} lifted`);
        });
      }
    }
  }
  assert.equal(L.step([0, 1, 2], 2, 1), 0);
  assert.equal(L.step([0, 1, 2], 0, -1), 2);
});

test("the tutorial counts as done only when all three puzzles are", () => {
  let p = St.progress("");
  p = St.solved(p, { kind: "tutorial", index: 2 }, 4, false).progress;
  assert.equal(p.tutorial, false);
  p = St.solved(p, { kind: "tutorial", index: 0 }, 3, false).progress;
  assert.equal(p.tutorial, false);
  p = St.solved(p, { kind: "tutorial", index: 1 }, 6, false).progress;
  assert.equal(p.tutorial, true);
  assert.equal(St.doneIn(p, "tutorial", 3), 3);
});

test("known() checks a reference without generating", () => {
  assert.equal(S.known({ kind: "level", area: "heart", index: 7 }), true);
  assert.equal(S.known({ kind: "level", area: "heart", index: 8 }), false);
  assert.equal(S.known({ kind: "free", difficulty: "expert", index: 0 }), true);
  assert.equal(S.known({ kind: "tutorial", index: -1 }), false);
  assert.equal(S.known(null), false);
  assert.deepEqual(St.progress(JSON.stringify({ current: { ref: { kind: "tutorial", index: 0 }, moves: [null, [0, 2]], assisted: true, pack: St.PACK } })).current.assisted, true);
  // a puzzle saved from another level pack names a different board
  assert.equal(St.progress(JSON.stringify({ current: { ref: { kind: "tutorial", index: 0 }, moves: [], pack: St.PACK + 1 } })).current, null);
});

test("across two hosts, the newest unfinished puzzle wins and settings merge per key", () => {
  const ref = { kind: "level", area: "clearing", index: 1 };
  // started in the app at t=100, finished in the plugin at t=200
  let app = St.setCurrent(St.progress(""), { ref, moves: [[0, 3]], assisted: false }, 100);
  let plugin = St.solved(St.setCurrent(St.progress(""), { ref, moves: [[0, 3]], assisted: false }, 150), ref, 9, false, 200).progress;
  assert.equal(St.merge(app, plugin).current, null);
  assert.equal(St.merge(plugin, app).current, null, "order does not matter");
  // the tutorial completes from records made in different hosts
  const a = St.progress(JSON.stringify({ done: { [k("tutorial/0")]: { best: 3 }, [k("tutorial/1")]: { best: 6 } } }));
  const b = St.progress(JSON.stringify({ done: { [k("tutorial/0")]: { best: 3 }, [k("tutorial/2")]: { best: 4 } } }));
  assert.equal(St.merge(a, b).tutorial, true);
  // a hinted solve keeps the earlier unhinted best and says so
  const r = St.solved(St.progress(JSON.stringify({ done: { [k("clearing/1")]: { best: 12 } } })), ref, 10, true, 1);
  assert.equal(r.assisted, true);
  assert.deepEqual(r.best, { best: 12, assisted: false });
  // one setting changes on top of what is on disk
  const disk = JSON.stringify({ reducedMotion: true, music: 0.3 });
  const next = St.withSetting(disk, "music", 0.8);
  assert.equal(next.reducedMotion, true);
  assert.equal(next.music, 0.8);
  // a change made after a clock jump back is still the newest
  assert.equal(St.nextAt({ currentAt: 500 }, 100), 501);
  assert.equal(St.nextAt({ currentAt: 500 }, 900), 900);
  const later = St.setCurrent(plugin, { ref, moves: [], assisted: false }, St.nextAt(plugin, 50));
  assert.deepEqual(St.merge(plugin, later).current.ref, ref);
  // saves carry a version, keep fields they do not know, and a newer save
  // is recognised
  assert.equal(JSON.parse(St.settingsText('{"future":1}', St.settings(""))).future, 1);
  assert.equal(JSON.parse(St.progressText("", St.progress(""))).version, St.VERSION);
  assert.equal(St.newer(JSON.stringify({ version: St.VERSION + 1 })), true);
  assert.equal(St.newer("{}"), false);
  // records name the pack by its contents
  assert.match(St.PACK, /^[0-9a-f]{12}$/);
  assert.equal(S.known({ kind: "free", difficulty: "constructor", index: 0 }), false);
  assert.equal(S.puzzle({ kind: "free", difficulty: "constructor", index: 0 }), null);
});
