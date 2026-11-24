# Architecture

```
  Omarchy shell plugin          Standalone app
  plugin/Overlay.qml            src/main.cpp, src/Main.qml
  (FileView saves)              (QSaveFile saves)
          \                        /
           \   host: readText,    /
            \  writeText, quit   /
             qml/Hueometry/Game.qml  ── screens: Menu, Map, FreePlay,
                     │                  Settings, Play (+ Board, Results)
                     │
        js/session.mjs   js/store.mjs   js/layout.mjs   js/palette.mjs
        (a puzzle in     (settings,     (where pillars   (orb colours)
         play)            progress)      stand)
                     │
               js/rules.mjs   the one door to the engine
                     │
               js/engine.mjs  compiled from engine/*.bend
                     │
     engine/core.bend   engine/gen.bend   engine/hint.bend   (Bend 2)
                     │
          SPEC.bend + LAWS.bend  ←  proved by  PROOF.bend
```

## Rules

Every rule lives in the Bend engine. `engine/core.bend` holds the game state
(colours, capacity, the first board, the board, the history) and decides
legality through `Spec.legal`, the rule exactly as `SPEC.bend` states it. A
legal move is an unchecked `transfer` plus one history entry; undo is the
transfer back. `engine/gen.bend` makes puzzles from seeds and returns one
only after the engine's own replay of its certificate solves it.
`engine/hint.bend` follows a known solution.

`LAWS.bend` states what must hold (conservation, capacity, exact effect of a
move, refusals change nothing, counting, undo, restart, replay, victory,
validity, legal targets, refusal reasons, solvable generation) and
`PROOF.bend` proves all of it. `bin/proof` checks the proofs twice, the second
time with BendTT's kernel, whose soundness is proved in Lean.

## The boundary

`bin/engine` compiles `engine/api.bend` to an ES module and adapts it for
Qt's JavaScript engine (see `tools/engine/build.py`). Only
`qml/Hueometry/js/rules.mjs` imports it: it converts between JavaScript arrays
and Bend lists, rejects malformed input, and decides nothing. The interface
never edits a board; it asks the engine and draws the answer, including which
pillars glow as legal targets.

## Interface

`qml/Hueometry` is one Qt Quick module used by both installs; it imports
nothing from Quickshell. Its host (the app's window or the plugin's overlay)
provides saves and window control. `session.mjs` remembers the lifted orb and
reports what happened so the board can animate it; `layout.mjs` places
pillars on a line or as spokes of a circle and fixes the keyboard order,
knowing only how many pillars there are.

### The host

`Game.qml` takes everything outside the game from its `host`, which may
arrive after the game has loaded (the plugin sets it late), so the module
copes with a missing host. A host provides:

| Member | What it is |
|---|---|
| `kind` | `"app"` or `"plugin"` |
| `readText(name)`, `writeText(name, text)` | the save files, by name; `writeText` answers whether it wrote |
| `quit()` | close the game |
| `canFullscreen`, `toggleFullscreen()` | full screen, where the host can |
| `version` | what the menu shows: `0.1.0`, or `0.1.0 · 9323709` (with `+` for uncommitted changes) for a build that is not the release itself |

The app's host is `gameHost` in `src/Main.qml`; the plugin's is `gameHost`
in `plugin/Overlay.qml`; tests use `tests/qml/MemoryHost.qml`.

### Version

The version is written in `hueometry.pro`, `pkgbuild/PKGBUILD` and
`plugin/manifest.json`; `tools/check/version.sh` fails unless they agree
(and, at a release, unless the tag matches). `tools/version/build-id.sh`
names the build: nothing when the commit carries the release tag, else the
short commit. qmake writes both into `buildinfo.h`; `bin/plugin` stamps the
build into its copy of the overlay.

Saves are JSON in XDG folders, with a format version: a save from a newer
Hueometry is read but never overwritten. Progress only grows, and each save
first merges what is on disk, so the app and the plugin can share it.

## Content

Levels (`js/levels.mjs`) and the free-play pool (`js/free.mjs`) are seeds
plus solutions found offline by `tools/levels/solve.mjs` and verified by the
engine. Sounds are synthesised by `tools/audio/synth.py`. Pictures are drawn
in QML; there are no image files besides the app icon and the plugin
preview.

## Checks

`bin/check` runs: shellcheck; the Laws-Change trailer rule; `--verdict`; the
engine drift check; the 512 KiB file limit; Node tests (unit, property tests
against an independent model, levels, session, layouts); native-vs-JavaScript
generation; the qmldir list; the palette and sound checks; Qt Quick tests
(the engine in Qt's engine, a worker, hints, the level pack, a keyboard
playthrough); the app build and its Qt tests; the plugin's assembly,
`omarchy plugin validate`, and the overlay under Quickshell where installed.
