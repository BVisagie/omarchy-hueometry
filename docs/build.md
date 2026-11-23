# Hueometry build plan: one PR (addendum to PLAN.md and TECH.md)

User decisions: final art and audio deferred. Build the whole game now with
our own means: the best QML visuals and self-made audio possible. One big PR
with as many commits as needed. Review limits reset with each reviewed
commit (range).

## Facts
- Repo BVisagie/omarchy-hueometry is PRIVATE and EMPTY (no default branch).
  Local main has no commits; untracked: AGENTS.md, CLAUDE.md, .agents/,
  .claude/ (shopfloor recipe files, not made by me).
- Available, no sudo needed: Qt 6.12 (qml, qmllint, qmlformat,
  qmltestrunner, svgtoqml), qmake6, clang, node 26, python3 + numpy 2.5.4,
  ffmpeg with libopus/libvorbis/flac. Not available: docker, sox, elan/Lean,
  bend. Bend v2.0.40 ships linux-x64 tarballs as GitHub release assets.
- Review skill (repo): shopfloor-review, reviewers GPT-6.2 Astra (codex,
  reasoningEffort ultra) then Fable 5.2 (effort high), max 12 rounds per
  review. Advisor cap: 5 per task, 2 used in planning.

## Setup before the branch
- S1 Bootstrap main: commit README.md stub + LICENSE (MIT) on main, push to
  origin. Prose-only, so exempt from review under the working agreement.
  Gives the PR a base.
- S2 User-level tools (no sudo): Bend 2.0.40 tarball verified against the
  GitHub asset digest into ~/.local/share/bend, linked as ~/.local/bin/bend;
  elan + Lean 4.34.0 in ~/.elan (needed by --verdict); npm dev deps inside
  the repo (node_modules ignored).
- Branch: feat/hueometry-v0.1 from origin/main.

## Visual approach (our own means)
- Everything drawn in QML: QtQuick.Shapes (paths, linear/radial/conical
  gradients), Qt Quick Effects MultiEffect (blur, glow, shadow, saturation),
  QtQuick.Particles, Qt Quick animations. Hand-written SVG where a path is
  easier to author, converted with svgtoqml or loaded as vector images.
  Tiny generated textures (soft dot, leaf mask) as PNG from a script.
- Jungle: seeded procedural layers per area (far canopy silhouettes,
  ruins, mid foliage, near framing leaves), swaying vines, light shafts,
  drifting mist, fireflies, area features (river shimmer, waterfall stripes
  + spray particles, temple carvings). Static layers cached as textures
  (layer.enabled); only transforms animate.
- Orbs: radial-gradient body, rim shade, specular highlight, inner glint,
  optional carved symbol. Pillars: carved stone with moss and glyph bands;
  empty socket glows.
- Celebration: completed columns glow; area saturation rises (light
  restored); particles; a stylised vector animal friend (toucan, frog).
- Six-colour palette validated by a script: simulated protan/deutan/tritan,
  minimum colour difference between every pair, lightness spread.
- Visual QA: offscreen screenshots of every screen at 1080p and 4K, read and
  critiqued; at most 3 polish rounds per screen.

## Audio approach (our own means)
- tools/audio/synth.py (python3 + numpy, deterministic seeds) + ffmpeg.
- Instruments: modal marimba/kalimba (decaying inharmonic partials), log
  drum, shaker (filtered noise), soft pad (detuned saws + low-pass), simple
  reverb (Schroeder/FDN).
- SFX (WAV, 3-4 variants each): lift, place (each orb colour has its own
  pentatonic note, so play makes melodies), invalid (soft muted tok),
  undo, restart, hint sparkle, column complete chime, solved fanfare,
  menu move/select.
- Ambience (Ogg Opus loops, one per area family): wind in leaves, river,
  waterfall, temple hush, with synthesised birds and frogs.
- Music (Ogg Opus, seamless loops): menu theme, calm play theme, short win
  sting. Loudness normalised; music ducks under celebrations.
- Playback: SoundEffect for SFX, MediaPlayer + AudioOutput for loops, behind
  a Loader with a silent fallback; ±2% random pitch... (SoundEffect has no
  pitch: use the variants instead).
- ASSETS.md credits every file as our own work, CC BY-SA 4.0.

## Commits and review checkpoints
Each checkpoint runs shopfloor-review on the commits since the previous
checkpoint, with a fresh 12-round limit. A final review reads the whole PR.

A Foundation
 1 Add agent instruction files as they are (AGENTS.md, CLAUDE.md, .agents,
   .claude).
 2 Skeleton: README, LICENSE, LICENSE-ASSETS (CC BY-SA 4.0), .gitignore,
   CHANGELOG, folder layout.
 3 AGENTS.md project rules (agent-instructions skill): Bend commands, laws
   protection, generated-file rules, test commands.
 4 Toolchain pin and scripts: bin/setup, bin/proof, bin/engine.
B Bend feasibility (M1) - STOP and report if any gate fails
 5 Engine types, legal, transfer, step, apply, is_solved.
 6 SPEC.bend, LAWS.bend (T, L1, L2, L5), PROOF.bend; --verdict green.
 7 Time-boxed spike: undo inverse lemma and L8 counting step.
 8 engine.mjs + named-export wrapper; Node tests; QJSEngine and WorkerScript
   runs; Quickshell import probe; QtMultimedia-in-Quickshell probe;
   timings; FEASIBILITY.md.
C Full engine (M2)
 9 undo, restart, replay, history; laws L6, L7, V, L8, L9, LT.
10 Golden replays and property tests.
D Generator (M3)
11 PRNG, structured scramble, checked certificate, G1, metrics, bands,
   puzzle ids.
12 Bounded solver and hints; offline optimum tool; curated tutorial,
   Beginner and Easy pack with verified minimums.
13 JS vs native determinism test.
E Shared module and hosts (M4)
14 qml/Hueometry: engine adapter, Host interface, settings and progress
   models, storage abstraction, save lock.
15 Standalone C++ host: qmake6, fullscreen, QSaveFile storage, translator;
   bin/build, bin/test.
16 Plugin host: manifest, Overlay.qml, BarWidget.qml, FileView storage;
   bin/plugin builds dist/plugin; validate + qmllint.
F Gameplay (M5, M6)
17 Board, pillars, orbs, selection, arc move animation, invalid wobble,
   counter, undo/restart/hint.
18 Layouts Line and Circle, focus order, keyboard map, layout tests.
G Jungle visuals (M7 visuals)
19 Procedural jungle renderer and six area compositions.
20 Orb and pillar art pass, symbols mode, palette validation script.
21 Celebrations, light restoration, animal friends, reduced motion.
H Audio (M7 audio)
22 Synth tool and all audio assets; ASSETS.md.
23 Audio manager with fallback, volumes, mute, ducking.
I Screens and progression (M8)
24 Main menu scene, difficulty and board pickers with previews, area map,
   settings, results, pause.
25 Tutorial, unlocks, personal bests, autosave and resume, `?` key help.
26 qsTr everywhere, en.json, interface scaling.
J Packaging and CI (M9)
27 PKGBUILD, .desktop, SVG icon, bin/install; release workflow (package +
   plugin tree; plugin-repo push left disabled).
28 GitHub Actions in Arch container: proofs, tests, drift and size checks,
   QML tests, makepkg, plugin validate, ASSETS check.
29 README (both installs, removal, keys, overlay keybinding),
   ARCHITECTURE.md, final FEASIBILITY.md.
Final: whole-PR review, open PR (never merge).

## Testing on this machine
- All CI checks run locally before each checkpoint review.
- Standalone: build and run from build/; makepkg builds the package; the
  actual `pacman -U` install is left to the user (needs sudo).
- Plugin: validate + qmllint; then a live test in the real shell under a dev
  id (io.github.bvisagie.hueometry-dev): copy, enable, summon, screenshot,
  disable, remove.
- Branch pushed to origin at checkpoints so GitHub CI runs.

## Not in this PR
Commissioned art/audio; creating the plugin repo and marketplace
submission; AUR; playtests with children; Clockwork theme; extra layouts.
