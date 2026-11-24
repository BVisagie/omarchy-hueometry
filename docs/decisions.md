# Decisions

The plan in [plan.md](plan.md), [technology.md](technology.md) and
[build.md](build.md) was reviewed before the build started. This file records
what changed after review. Where it disagrees with those files, it wins.

## Game and engine (after review of plan.md)

- `step` and `undo` share an unchecked `transfer(board, from, to)`. Law T is
  stated on `transfer`. Undo is the transfer back, so law L9 needs only that
  the move was legal, not the capacity invariant.
- The move counter is not stored: `moves = len(history)`. Law L7 holds by
  definition.
- The column count comes from the board's length, not from the config.
- `generate` returns `Maybe`. It returns `Some` only after it has checked that
  replaying its certificate solves the board, that the board is valid, that it
  has the start shape (all columns full but one) and that it is not solved.
  Law G1 is "Some implies solvable"; it survives any later generator change.
- Added law V: `valid` is preserved by apply, undo and restart.
  Added law LT: `legal_targets` agrees with `step`.
- `valid` requires `cap >= 1` and `colours >= 1`.
- The PRNG remaps seed 0, which would keep xorshift32 at 0 forever.
- Scramble quality is the main risk: a random walk from solved rarely reaches
  deep beads. The generator uses a structured scramble, and par comes from the
  solver where it can run, otherwise from the shortened certificate.

## Open decisions settled by the owner

All defaults in plan.md section 10 were accepted, except:

- Distribution: ship through the Omarchy plugin marketplace AND as a
  standalone Omarchy install from this repository.
- Art and audio: final commissioned assets are deferred. Version 0.1 uses
  visuals drawn in QML and audio synthesised by our own script.
- The whole of version 0.1 lands in one pull request with review checkpoints.

## Technology (after review of technology.md)

- Audio loads from its own QML file behind a `Loader`, with a silent fallback:
  `qt6-multimedia` is not a dependency of Quickshell or Omarchy.
- Images are PNG or JPEG, not WebP: `qt6-imageformats` is not guaranteed.
- The engine is exposed through a generated wrapper with named exports.
- The generated engine lives at `qml/Hueometry/js/engine.mjs` (not
  `engine/dist/`), so the shared QML module is self-contained for both hosts.
  It must stay under 512 KiB, the marketplace scanner's
  per-file limit.
- Hard time caps in the generator; textures capped to the screen; the plugin
  overlay is not kept loaded, so closing it frees everything.
- Saves live in XDG directories, never inside the plugin folder (the shell
  reloads a plugin on any write inside it).
- The plugin has no launcher entry; the README documents a keybinding for
  `omarchy-shell shell summon io.github.bvisagie.hueometry '{}'`.
- Both channels share one save folder, but each writes only its own
  progress file (`progress-app.json`, `progress-plugin.json`) and reads all
  of them, merging (progress only grows: `qml/Hueometry/js/store.mjs`). Two
  hosts saving at once therefore never overwrite each other, with no lock
  (the plugin cannot check whether the app's process is alive).

## Verified before the build (gate zero, 2026-11-23)

- Bend 2.0.40 (linux-x64 release tarball, sha256
  `c9ff8d67bd903fb6ad9a26b43d8a62c01021de82a44d55ce4a3dcd4732113d6b`) and
  Lean 4.34.0: Bend's own insertion-sort demo prints ALL PROOFS CHECK under
  `--verdict`; a broken proof prints SOME PROOFS FAIL and exits 1.
- Bend's `.mjs` output runs in Qt 6.12's JavaScript engine once one helper is
  stubbed: `f32_round` uses BigInt literals, which Qt's engine cannot parse.
  The engine never uses F32, so `bin/engine` replaces that helper with one
  that throws. It also runs inside a `WorkerScript`.
- In a separate Quickshell 0.3.2 instance: the `.mjs` import, a
  `WorkerScript`, `QtMultimedia` `SoundEffect` behind a `Loader`, and a
  `FileView` atomic write all work.
- Qt's `offscreen` platform forces the software renderer, which cannot draw
  `MultiEffect`. `tools/shot` renders through `QQuickRenderControl` on the
  GPU instead, with animations stepped frame by frame.

## Levels, par and hints (checkpoint 2)

- Progression uses a level pack, `qml/Hueometry/js/levels.mjs`, built by
  `bin/levels`: a three-board tutorial and six areas of eight levels, from
  Beginner (3 colours of 3) to Expert (6 colours of 10). Each level is a
  seed; the game regenerates the board with the engine.
- Each level stores a solution found offline by an A* search
  (`tools/levels/solve.mjs`) and verified by the engine. `par` is its length.
  For Beginner and Easy the search is exact (`optimal: true`); harder levels
  use weighted A*, so their par is a known solution, never called optimal.
- Hints follow the puzzle's stored solution: the next move when the board is
  on it, or how many moves to undo to get back.
- Free play draws a random puzzle from a pool of pre-solved puzzles per
  difficulty (`qml/Hueometry/js/free.mjs`), with seeds apart from the
  levels, so its hints follow a short solution too. The generator's
  certificate (valid but hundreds of moves long) is never used for hints.
- Levels in an area are ordered by the solver's lower bound, which does not
  depend on the search weight, then by par.
- The level pack is generated as ES modules (`levels.mjs`, `free.mjs`), not
  JSON: Qt's engine imports modules directly, while reading a local JSON
  file needs an environment flag.
- The scramble works in rounds of a random walk, a gather, and pouring a
  full column into the empty one; the pour is what mixes the bottom beads.

## Interface (checkpoint 3)

- The circle layout grows its pillars outwards like spokes from a carved
  medallion, so tall pillars never stand in front of each other. Beads stack
  from the centre out; keyboard order is clockwise from the top.
- Qt's JavaScript engine has no object spread (`{ ...x }`); the shared
  modules use `Object.assign`.
- Quickshell only resolves the shared module's types that its `qmldir`
  lists, so every component is listed and `bin/check` enforces it.
- A refused move leaves the orb lifted, so the player can choose another
  pillar; clicking the lifted pillar again (or Esc) puts it back.
- Restart needs a held button or R pressed twice; quitting the app needs Q
  pressed twice.
- Par is hidden on the tutorial, the first two areas and the two smallest
  free-play sizes.

## Look and sound (checkpoint 4)

- The six orbs are yellow, moonstone (pearl), jade, ember, lagoon and orchid.
  Five are Okabe-Ito colours; the pearl replaces its sky blue, which was too
  close to its blue for normal vision. `tools/palette/check.py` requires
  every pair to differ by 30 (CIE76) in normal vision and by 12 under
  simulated protanopia, deuteranopia and tritanopia.
- The jungle is drawn in QML per area: canopy light, seeded far trees, the
  area's feature (river, ruins, waterfall, temple, heart tree), swaying
  leaves and vines, mist and fireflies; it brightens when a puzzle is solved.
  Reduced motion stops every ambient animation.
- Sounds are synthesised by `tools/audio/synth.py`: each orb colour plays its
  own note of a pentatonic scale when placed, a refusal is a soft low tok,
  and the music dips under the win fanfare. Effects follow the sounds
  slider; music and ambience follow the music slider.

## Packaging (checkpoint 5)

- The app installs from a checkout with `bin/install` (makepkg), following
  Omarchy's own apps; each release also attaches the built package. The
  package depends on Qt Multimedia, so the app always has sound.
- The release workflow assembles the plugin and attaches it to the release.
  Publishing it to `BVisagie/omarchy-hueometry-plugin` stays off until that
  repository, its deploy key secret and the `PLUGIN_PUBLISH` variable exist.

## After review of checkpoints 3-5

- A win is recorded the moment the engine accepts the winning move; the
  animation only decides when the results card appears.
- Using a hint is saved with the unfinished puzzle, so resuming keeps it;
  restarting clears it.
- Boards are regenerated on a WorkerScript thread (Expert takes about half a
  second in Qt), so the shell's interface never waits. Hints stay on the main
  thread: along a stored solution they take a few milliseconds.
- Number keys only choose a pillar; Space or Enter lifts and places. Held R
  and Q repeat but never confirm.
- The plugin is linted against the installed shell's own modules, and
  warnings fail `bin/check`.
- Each local change to the unfinished puzzle is stamped later than any
  stamp already seen, so a clock that steps back cannot let an older puzzle
  win the merge. The level pack is named by a hash of its contents, so a new
  pack never credits a record or replays moves on a different board.
- A save that cannot be written is said on screen, and the unsaved progress
  stays in memory until a later save succeeds.
- v0.1 uses the system font (no bundled font) and English source strings
  marked for translation, with no translation catalogue yet.
- The smallest supported window is 720×540: every screen is checked there
  at 150% interface size, and the app window will not shrink below it. The
  plugin always fills a monitor. Screens that do not fit scroll; layouts
  below that size are not designed for.

## Moss and bloom

- The flat moss blobs became moss cushions on each shoulder of the plinth
  and a fern on some pillars, shaped by the pillar's position so each
  pillar differs but never changes.
- A pillar that is full of one colour opens a flower in that colour on its
  plinth, or on its outer end on the circle layout, where the spokes have
  room (its heart shows the colour's symbol in symbols mode). The engine
  decides which pillars are done (`complete` in engine/core.bend, built
  from SPEC.bend's own tests); the board opens a flower only once that
  pillar's last orb has landed, and closes it while an orb is lifted from
  it. No law covers `complete`; a property test checks it against the
  independent model.
- No chime for a finished pillar: it would need a new sound and would land
  on top of the solved fanfare.

## Version on the menu

- The main menu shows the version in a bottom corner: `v0.1.0` for a clean
  build of the release tag, `v0.1.0 · <commit>` for any other build, with
  `+` when tracked files had uncommitted changes (a patched build of the
  release included), so a local test build can be told apart. The host provides it as `version` (see ARCHITECTURE.md).
- The version stays written where each tool reads it (hueometry.pro, the
  PKGBUILD, the plugin manifest), with no separate VERSION file;
  `tools/check/version.sh` fails on every check run unless they agree.
- The app takes the build id from a header qmake writes (buildinfo.h), not
  a compiler define, since the incremental build would not recompile for a
  changed define. The PKGBUILD has no pkgver(): makepkg would rewrite it and
  every build would then count as having uncommitted changes.
