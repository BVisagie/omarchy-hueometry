# Hueometry: development plan

Sources checked on 2026-11-23: Bend v2.0.40 (bendlang/bend, released 2026-11-06:
README, GUIDE.md, WONTFIX.txt, CHANGELOG, demos/proof_insertion_sort,
demos/app_win_is_bug_2d); Omarchy 4.5.0-3 installed on this machine (4.5.0
released 2026-11-05); /usr/share/omarchy/shell/plugins/README.md;
omacom/omarchy-plugin-marketplace (README, SUBMISSION.md, site/develop.html).
These were read before anything was installed; docs/decisions.md records
what changed after review and what was later verified.

## 1. Architecture overview

Seven parts. Arrows show who may call whom. Nothing calls into the presentation.

    Platform shell -> Presentation -> Engine adapter -> Bend rules engine
                         |   |                              ^
                     Layout  Theme                  Generator/Solver (Bend)
                         |
                   Progress store (saves seeds + move lists, never boards)

1. Bend rules engine (pure Bend, no IO, no @unsafe, no foreign code). Owns the
   board, legal moves, the move counter, history, undo, restart, replay,
   victory. Knows nothing of layout, theme, or platform.
2. Specification: LAWS.bend + SPEC.bend (protected) and PROOF.bend.
3. Generator / solver (Bend, pure, fuel-bounded). Seeded PRNG, reverse
   scramble, solvability certificate, difficulty metrics, par, hints.
4. Engine adapter. The one boundary the UI talks to: new_game, try_move,
   undo, restart, legal_targets, hint, snapshot. Hides Bend value encoding.
5. Layout system. Pure function: (pattern, column count, viewport) ->
   positions, hit areas, keyboard focus order. Sees only the column count.
6. Theme packs. Data: palette, symbol per colour, art, audio, celebrations.
7. Progress store and platform integration. Local files under XDG dirs;
   launcher entry, icon, packaging, optional marketplace plugin.

The UI never holds its own copy of the rules. It renders the snapshot the
engine returns and animates the difference between two snapshots. Legal-target
highlighting comes from `legal_targets`, which is the engine's own `legal`.

## 2. Bend feasibility assessment

What fits well
- Laws and proofs are first-class: `law` in LAWS.bend, a same-named
  `def Laws.x` in PROOF.bend, `bend PROOF.bend` prints ALL PROOFS CHECK or
  SOME PROOFS FAIL. `bend PROOF.bend --verdict` exists as the brief assumes:
  it rechecks with the BendTT kernel that has a Lean proof, and refuses any
  def that relies on @unsafe or foreign code.
- The demo proof_insertion_sort proves "sort permutes its input" by counts:
  the same shape as bead conservation. app_win_is_bug_2d proves a law over
  `replay(start, moves)` for every move list, and its browser UI imports the
  game as a module and renders `replay(...)`: our architecture in miniature.
- Lists of Nat are `Data` (copyable), so boards, history and snapshots can be
  plain values. No mutation, no aliasing.
- `-o engine.mjs` emits an ES module of all non-IO defs, callable from any JS
  host; constructors cross as `{$: "Name", ...}`, Nat as a JS number.

Limits that shape the design
- Termination is mandatory; no mutual recursion. Generator and solver loops
  take a Nat fuel argument. Anything @unsafe drops out of --verdict.
- No `if`, no matching on computed values: helpers take the computed value as a
  parameter (verbose, not blocking).
- No tactics or proof search. Every proof is hand-written induction with
  rewrites. Index lemmas over a list of columns are the bulk of the work.
- Numbers are Nat, U32, F32 only; no U64. Use Nat in the engine (it computes in
  the checker), U32 for the PRNG. No F32 anywhere in the engine (axiomatic, and
  differs across lanes).
- The checker can blow up on large concrete constants (WONTFIX #993): state
  laws over an abstract config, not over a literal 7-column board.
- The C target has no library export yet (WONTFIX "SOON" #813): one program
  with a main. Native embedding today means a sidecar process, not a linked
  library.
- Bend's own window/App layer needs X11 (XWayland on Hyprland) and renders
  quadtree images, with no text layout. Not a fit for the art direction; the
  engine is the right scope for Bend.
- --verdict builds its kernel once with Lean v4.34.0 (elan, or $BENDTT pointing
  at a built kernel). CI must provide it.
- The parser and the translation into the kernel are not proven; the compiler
  is "99% AI-written"; laws are about Bend semantics, and backends may differ.
- Releases are frequent and break things (2.0.37 changed how Nat crosses into
  JS). Pin one version; upgrade deliberately.
- No test framework. Conventional tests run in the host language against the
  exported module, plus Bend files whose main prints results.

Integration candidates the prototype must try (no stack is chosen here)
- A. ES module: `bend Engine.bend -o engine.mjs`, called from Node/Bun tests.
  Also check whether the output runs in other JS engines a future stack might
  use (for example Qt's QML engine, which can import .mjs).
- B. Native sidecar: a compiled Bend binary speaking a small line protocol over
  stdin/stdout. Must confirm Bend can read stdin and measure round-trip time.
- C. Direct C embedding: not supported in v2.0.40; record it as blocked on #813.

Verdict on feasibility: likely feasible for the engine and its core laws;
uncertain for proof effort on undo/victory and for solver speed in Bend
(strings are linked lists; Map is string-keyed). Only the prototype settles it.

## 3. Gameplay-state model

Types (sketch, final Bend syntax set in the prototype)

    Config  { colours: Nat, cap: Nat }      # columns = colours + 1
    Column  = List<Nat>                     # head is the TOP bead
    Board   = List<Column>                  # index = column id 0..n-1
    Move    { from: Nat, to: Nat }
    Game    { cfg, start: Board, board: Board, moves: Nat, history: List<Move> }
    Reject  = NoSuchColumn | SameColumn | EmptySource | FullTarget
    Outcome = Accepted{ game, bead } | Rejected{ reason }

- Top-at-head makes "take the top bead" `match col: case h <> t` and makes
  "the rest keeps its order" literally `t`.
- Colour is a Nat index; the theme maps index -> colour, symbol, sprite.
- cap equals beads per colour (brief: columns finish full).

Operations
- `legal(cfg, board, m) -> Bool`: from < n, to < n, from != to, source
  non-empty, len(target) < cap. Colour never appears in it.
- `step(g, m) -> Outcome`: if legal, pop top of `from`, push onto `to`,
  moves+1, history = m <> history. Else the reason.
- `apply(g, m) -> Game`: step, or g unchanged on rejection.
- `undo(g)`: pop history, apply the inverse move {to, from}, moves-1. The
  inverse is always legal. Empty history: no-op.
- `restart(g) = new(cfg, g.start)`. Never regenerates.
- `replay(g, moves)`: fold apply.
- `is_solved(cfg, board)`: every column is empty or (full and one colour),
  and exactly one column is empty. Given conservation and a valid start, this
  matches all four victory conditions in the brief.
- `valid(cfg, board)`: n = colours + 1 columns, each len <= cap, each bead <
  colours, count(c) = cap for every colour c.

## 4. Formal verification plan

Files
- SPEC.bend (protected): plain, obviously-correct helpers the laws use:
  count(c, board), column(i, board), len, Legal (as written in the rules),
  Solved (written declaratively, deliberately unlike the engine's
  is_solved). Same convention as Bend's own demos.
- LAWS.bend (protected): imports the engine and SPEC, states the laws only.
- PROOF.bend: imports LAWS, proves each `law x` with `def Laws.x`.
- Protection: an AGENTS.md rule plus a CI check that fails when LAWS.bend or
  SPEC.bend change without an explicit "Laws-Change:" trailer approved by the
  owner. A weakened law is a gameplay change.

Laws, in proof order. Drop preconditions where a law holds without them.
- T  Exact transition: if step(g, m) is Accepted, column `from` becomes its
     tail, column `to` gains the old top bead, every other column is equal.
     (Gives L3 and L4 directly.)
- L1 Conservation: for every colour c and every m, count(c, apply(g, m).board)
     = count(c, g.board). No precondition needed.
- L2 Capacity: if every column has len <= cap, it still does after apply.
- L5 Rejection is identity: not Legal(m) -> apply(g, m) = g (board, counter,
     history).
- L6 Completeness: Legal(m) -> step is Accepted. Legal never mentions colour,
     so a Ball-Sort restriction cannot sneak in. Add one concrete regression
     law: a move onto a different colour is accepted.
- L7 Counting: Accepted -> moves + 1; Rejected -> moves unchanged.
- L8 Victory: under valid(cfg, board), is_solved = True iff Spec.Solved.
- L9 Undo: Legal(m) -> undo(apply(g, m)) = g. Plus restart = new(start), and
     history consistency: moves = len(history) and
     replay(new(start), reverse(history)) = g for every reachable g.
- G1 Solvable by construction (generator): generate(seed, cfg) returns a board
     and a certificate move list; is_solved(replay(board, cert)) = True for
     every seed. Proof reuses L9 (the certificate is the inverted scramble).
- L10 Layout independence: not provable in Bend, because layout lives outside
     it. Enforced by construction (no engine def takes a layout or theme
     argument; the engine imports nothing outside Base and SPEC) and by
     tests: the same seed and move list give identical snapshots under every
     layout, and every layout's focus order is a permutation of the columns.

Prototype scope (brief 7.11): T, L1, L2, L5, plus victory detection tested
(L8 proof comes in milestone 2).

Workflow
- Local and CI: `bend PROOF.bend --verdict` must print ALL PROOFS CHECK and
  exit 0. Verify in the prototype that a failing proof gives a non-zero exit;
  if not, CI greps the verdict line.
- CI installs the pinned Bend release by exact version and checksum (not the
  curl | sh latest installer) and elan with Lean v4.34.0; caches the kernel.
- Conventional tests next to proofs: unit and property tests against the
  exported module; golden replays (seed + moves -> final snapshot); a
  cross-lane test that JS and native builds generate identical boards from the
  same seeds.
- Limits stated, not hidden: proofs cover Bend semantics of the engine only;
  not the compiler, not the adapter, UI, saves, or packaging.

## 5. Puzzle generation and solvability

- Start from solved; apply N random legal moves from a seeded U32 PRNG
  (xorshift32); never pick the inverse of the previous move; bias choices
  toward moves that mix colours.
- Finish phase: legal moves that refill columns until all but one are full.
- Keep the scramble; its inverse, reversed, is a valid solution: the
  certificate (law G1). Par = certificate length, shown as "par", never as
  "best possible".
- Reject and retry (fuel-bounded, next seed): solved or near-solved starts,
  too few mixed columns, metrics outside the difficulty band.
- Difficulty metrics: count of columns already monochrome, longest
  same-colour run, number of colour boundaries, solver effort, certificate
  length after shortening by a bounded search.
- Exact optimum: an offline solver (developer tool, not shipped) computes true
  minimums for curated Beginner and Easy levels with symmetry reduction
  (colour relabelling, column permutation). Medium and up ship par only, until
  a verified optimum exists.
- Reproducibility: puzzle id = (generator version, difficulty, seed). Saves
  store ids and move lists, and reload by replaying through the engine, so a
  save can never hold an illegal board.
- Hints: from the current state, a bounded search toward solved; if none is
  found within budget, suggest undoing back to the last state on a known
  solution path. Hints never claim to be optimal.

## 6. Layout system

- Input: pattern, column count n (4 to 7), safe area, scale. Output: column
  anchor, size, hit rectangle, and a focus order.
- Patterns in v1: Line and Circle. Arc, Zigzag, Spiral, Hexagon later; each is
  one function. Custom later as saved anchor lists.
- Focus order is the column index order, which every layout lays out in
  reading order (left to right; clockwise from top for Circle), so keyboard
  play is identical across layouts.
- Layout chooses where beads fly, never which move is legal.

## 7. Experience design

Minimum complete experience (v1)
- One world, The Lost Jungle Temple, with six areas as progression steps.
- Tutorial of three guided boards (it may use 2 colours, still one empty column).
- Five difficulties with friendly names (for example Sprout, Explorer,
  Adventurer, Temple Keeper, Legend), shown with pictures of how many orbs.
- Line and Circle boards. Mouse and keyboard. Undo, restart, hint.
- Results screen: kind message, moves, personal best, new-record badge,
  replay, next.
- Settings: music, effects, mute, reduced motion, orb symbols, interface size,
  key help.
- Fully offline, local saves only.

Interaction
- Mouse: click a pillar to lift its top orb; click a target to place it.
  Clicking the lifted pillar again puts the orb back (UI cancel, no engine
  call). Drag-and-drop optional later.
- Keyboard: Left/Right (and Up/Down) move focus in focus order; 1-7 jump;
  Space/Enter lift or place; Esc cancel; U or Ctrl+Z undo; R restart (hold to
  confirm); H hint. Visible focus ring on every layout.
- Invalid target: soft wobble and a soft sound, counter unchanged. No red, no
  buzzer.

Screens: main menu (Play, Choose Board, Choose Difficulty, Progress,
Settings), gameplay, board picker with live previews, completion, settings.

Visual structure of the jungle
- Three layers: far (canopy light, ruins, slow parallax), board (a stone dais
  in calm light, low detail), near (framing leaves at the edges).
- Orbs carry the most saturation and contrast on screen; background is
  slightly muted behind the board.
- Six orb colours chosen for distinct lightness as well as hue, checked under
  protan, deutan and tritan simulation; symbols mode adds a carved glyph per
  colour (circle, triangle, square, diamond, star, leaf).
- Spare pillar: same pillar, empty socket with a faint glow.
- Solving restores light to the area; an animal friend reacts briefly.

## 8. Omarchy 4.5+ findings that shape later choices

- This machine runs Omarchy 4.5.0-3. 4.5's shell ("Quattro") is a
  long-running Quickshell (Qt/QML) process; plugins load into it, run
  unsandboxed, and must not start a second Quickshell.
- Plugins: manifest.json (schemaVersion 1, id, name, version, kinds,
  entryPoints); kinds bar-widget, panel, overlay (fullscreen), menu, service,
  bar. CLI: `omarchy plugin add <git-url>`, validate, enable, remove, update.
- Marketplace: one plugin per public repo, manifest.json, README with install
  and removal steps, and LICENSE at the repo root; ID namespaced outside
  `omarchy.*`; category "Kids" and tags games, kids, education exist; an
  automated baseline flags download-to-shell and unpinned external git source
  execution. Install commands clone upstream HEAD.
- The brief names plugins.omarchy.org; the marketplace README links
  omarchyplugins.com. Confirm which is canonical before submission.
- No "Omarchy Kids" component ships in 4.5; "Kids" is a marketplace category.
  Treat it as the audience, not a dependency.
- Consequences: the game needs a native Wayland front end; a marketplace
  listing is a shell plugin, so a full game would either run inside the
  desktop shell process (overlay) or be a separate app with a small plugin
  that launches it. Keep the repo root free for manifest.json, README and
  LICENSE from day one. No install step may pipe a download into a shell or
  need root at play time.

## 9. Roadmap (each milestone ends with tests and proofs green)

- M0 Repo and toolchain: layout, license, AGENTS.md rules for LAWS/SPEC, Bend
  pinned (v2.0.40 or the newest at start), elan + Lean 4.34.0, CI running
  `bend PROOF.bend --verdict` and tests.
- M1 Bend feasibility prototype (brief 7.11): types, legal, step, apply,
  is_solved; laws T, L1, L2, L5 proved and passing --verdict; .mjs export
  driven from Node tests; sidecar experiment; timings for a move, a replay of
  500 moves, and generating 100 Hard boards. Output: FEASIBILITY.md with a
  go/no-go. Stop for your decision.
- M2 Full engine: L6, L7, L8, L9 and history consistency; undo, restart,
  replay; golden tests.
- M3 Generator: PRNG, scramble, finish phase, G1, difficulty metrics, seeds,
  offline optimum solver, curated level pack, cross-lane determinism test.
- M4 Technology selection (only when you ask): graphics, shell, audio,
  packaging, adapter choice A or B.
- M5 Vertical slice: one Hard board, Line layout, mouse and keyboard,
  undo/restart, results; greybox art.
- M6 Layouts: Circle and Line, focus order, layout-independence tests.
- M7 Jungle theme: art, orbs, pillars, animation, audio, reduced motion,
  symbols mode.
- M8 Progression and settings: tutorial, difficulties, areas, saves,
  personal bests, hints.
- M9 Omarchy integration: launcher entry, icon, XDG paths, scaling,
  install/update/remove, marketplace readiness.
- M10 Polish and playtests with children; release.

## 10. Open design decisions (defaults in brackets)

1. Capacity always equals beads per colour. [yes]
2. Does undo mark a result as assisted for personal bests? [no; hints do]
3. Show par to young players? [hidden on Sprout and Explorer, shown above]
4. Allow a 2-colour tutorial board below Beginner? [yes, tutorial only]
5. Marketplace shape: standalone app plus a small launcher plugin, or the
   whole game as an overlay plugin inside the shell? [standalone app; decide
   in M4]
6. Code and asset licences. [MIT for code, CC BY-SA 4.0 for art and audio]
7. Who makes the illustrated art and audio (hand-made, commissioned, other)?
   This is the largest effort in the project. [needs your answer before M7]
8. Bend upgrade policy. [pin; upgrade only in a dedicated PR with --verdict green]
9. Laws change control. [only Bernard approves LAWS.bend and SPEC.bend edits]
10. Localisation. [English only in v1; strings kept in one file]

