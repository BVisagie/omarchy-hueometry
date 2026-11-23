# Bend 2 feasibility

The brief (section 7.11) asks for a prototype that proves Bend 2 can be the
authoritative rules engine before the game is built on it. This is that
report.

**Verdict: feasible. Bend 2 is the rules engine.**

Measured on 2026-11-23 with Bend 2.0.40, Lean 4.34.0, Qt 6.12, Quickshell 0.3.2
and Omarchy 4.5.0, on an x86-64 laptop.

## The nine required demonstrations

| # | Brief 7.11 | Result |
|---|---|---|
| 1 | Representation of the standard seven-column puzzle | `engine/core.bend`: a board is a list of columns, top bead first; `Game` adds colours, capacity, the start board and the move history. Any size works; the standard puzzle is 6 colours of 6 in 7 columns. |
| 2 | A function that applies a move | `Core.apply` and `Core.step`; laws `legal_is_played` (a legal move is exactly `transfer` plus one history entry), `step_accepts_legal` and `step_refuses_illegal` |
| 3 | Rejection of invalid moves | `Core.step` answers `Rejected{reason}` (law `step_refuses_illegal`); `Core.apply` changes nothing (law `refused_changes_nothing`) |
| 4 | Victory detection | `Core.is_solved`; law `victory_is_solved` proves it equals the four conditions of section 3.3 on every valid board, and `reads_solved` ties the interface's `solved(g)` to it |
| 5 | Proof of bead conservation | laws `conserves_colours` and `conserves_beads` |
| 6 | Proof of capacity preservation | law `keeps_capacity` |
| 7 | Proof that invalid moves change nothing | law `refused_changes_nothing` |
| 8 | The verification workflow runs | `bin/proof` runs `bend PROOF.bend --verdict` and prints ALL PROOFS CHECK |
| 9 | A way to expose the engine to an application | `bin/engine` compiles it to an ES module that Node, Qt's JavaScript engine, a QML `WorkerScript` and Quickshell all load |

The prototype went further than asked: the exact effect of a move (laws 3 and
4: `transfer` changes only the two columns, as the rules say, and a legal
move is that transfer), victory (law 8) and all of law 9 are proved too: undo restores the game
before a legal move, restart returns to the first board with no moves, and
replaying a game's history from its first board rebuilds it exactly.

## Verification

- `bend PROOF.bend --verdict` checks every proof twice: with Bend's own
  checker, then with the BendTT kernel, whose soundness is proved in Lean.
  A deliberately false proof (one that leans on an `@unsafe` loop) fails both,
  and the command exits 1.
- The kernel is built once per machine with Lean 4.34.0 (about 20 s) and
  cached in `~/.bend/bendtt`. After that the whole check takes about 0.2 s.
- The laws read games through engine accessors (`Core.board`, `Core.cap`,
  ...); laws `reads_*` pin each one to its field.
- Limits, as Bend documents them: the parser and the translation into the
  kernel are not proved, the compiler is not audited, and the laws are about
  Bend's semantics, not about the JavaScript it emits. Conventional tests
  therefore run the compiled engine too (below).

## Integration

- `bend engine/api.bend -o x.mjs` emits one ES module: Bend's small JavaScript
  runtime plus the program. Lists are `{$: "Con", head, tail}` and
  `{$: "Nil"}`, `Nat` is a JavaScript number, `Bool` is a JavaScript boolean.
- **Qt's JavaScript engine cannot parse BigInt literals**, which appear in
  one runtime helper for F32 text. The engine uses no F32, so
  `tools/engine/build.py` replaces that helper with one that throws, and
  fails the build if a future Bend moves it. With that, the module runs
  unchanged in Qt 6.12's engine, in a `WorkerScript`, and in a Quickshell 0.3.2
  instance (the process that runs Omarchy shell plugins).
- The C target cannot build a library yet (Bend WONTFIX #813), and no
  JavaScript engine is needed beyond Qt's, so the native helper-process
  option was not pursued.

## Speed

| Where | What | Time |
|---|---|---|
| Node 26 | 500 random games of 20–150 moves, each move checked against a model | 0.1 s |
| Node 26 | 30,000 moves in one game (no stack growth) | 7 ms |
| Qt 6.12 JavaScript | 600 accepted moves on the Expert board (6 colours of 10) | 10 ms |
| Qt 6.12 JavaScript | replaying those 600 moves | 2 ms |

A move costs about 17 µs in Qt's engine, far below one frame.

## Rough edges met

- Constructor names are global and must not clash with Base: `Move` is a
  Base pointer event, so a move is `Mv{from, to}`.
- Values are affine: anything used twice needs `+`.
- A function cannot match a computed value, so every proof that splits on a
  computed fact takes it as a parameter (the `.go` and `.fin` helpers).
- No tactics: PROOF.bend is about 1,000 lines for the laws above.

None of these blocked anything.
