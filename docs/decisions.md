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
- `engine/dist/engine.mjs` must stay under 512 KiB, the marketplace scanner's
  per-file limit.
- Hard time caps in the generator; textures capped to the screen; the plugin
  overlay is not kept loaded, so closing it frees everything.
- Saves live in XDG directories, never inside the plugin folder (the shell
  reloads a plugin on any write inside it).
- The plugin has no launcher entry; the README documents a keybinding for
  `omarchy-shell shell summon io.github.bvisagie.hueometry '{}'`.
- Both channels share one save folder; a lock file stops two copies writing.

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
