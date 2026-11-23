# Hueometry: the gameplay laws.
#
# The owner's specification, with SPEC.bend. Each law is a claim about the
# engine that PROOF.bend must prove; `bend PROOF.bend --verdict` checks every
# proof with Bend's checker and again with the proven BendTT kernel.
#
# Change this file only when the owner asks, with a `Laws-Change:` commit
# trailer. Never weaken, delete or trivialise a law to make a proof pass.

import Base
import ./SPEC.bend as Spec
import ./engine/core.bend as Core

# Reading a game
# --------------
# The laws read games through these accessors, so each is pinned to the
# field it names.

law reads_colours:
  for +c: Nat
  for +k: Nat
  for +s: List<&2, List<&2, Nat>>
  for +b: List<&2, List<&2, Nat>>
  for +h: List<&2, Core.Move>
  {Core.colours(Core.Game{c, k, s, b, h}) == c : Nat}

law reads_cap:
  for +c: Nat
  for +k: Nat
  for +s: List<&2, List<&2, Nat>>
  for +b: List<&2, List<&2, Nat>>
  for +h: List<&2, Core.Move>
  {Core.cap(Core.Game{c, k, s, b, h}) == k : Nat}

law reads_start:
  for +c: Nat
  for +k: Nat
  for +s: List<&2, List<&2, Nat>>
  for +b: List<&2, List<&2, Nat>>
  for +h: List<&2, Core.Move>
  {Core.start(Core.Game{c, k, s, b, h}) == s : List<&2, List<&2, Nat>>}

law reads_board:
  for +c: Nat
  for +k: Nat
  for +s: List<&2, List<&2, Nat>>
  for +b: List<&2, List<&2, Nat>>
  for +h: List<&2, Core.Move>
  {Core.board(Core.Game{c, k, s, b, h}) == b : List<&2, List<&2, Nat>>}

law reads_history:
  for +c: Nat
  for +k: Nat
  for +s: List<&2, List<&2, Nat>>
  for +b: List<&2, List<&2, Nat>>
  for +h: List<&2, Core.Move>
  {Core.history(Core.Game{c, k, s, b, h}) == h : List<&2, Core.Move>}

law reads_move:
  for +i: Nat
  for +j: Nat
  {(Core.from(Core.Mv{i, j}), Core.to(Core.Mv{i, j})) == (i, j) : Nat & Nat}

# A legal move is played
# ----------------------
# A legal move changes exactly the board, by transfer, and records itself in
# the history; colours, capacity and the first board stay. What the
# interface calls (step) answers that game and the bead it lifted, or, for an
# illegal move, a refusal.

law legal_is_played:
  for +c: Nat
  for +k: Nat
  for +s: List<&2, List<&2, Nat>>
  for +b: List<&2, List<&2, Nat>>
  for +h: List<&2, Core.Move>
  for +i: Nat
  for +j: Nat
  for e: {Spec.legal(k, b, i, j) == True{} : Bool}
  {Core.apply(Core.Game{c, k, s, b, h}, Core.Mv{i, j}) == Core.Game{c, k, s, Core.transfer(b, i, j), Core.Mv{i, j} <> h} : Core.Game}

law step_accepts_legal:
  for +c: Nat
  for +k: Nat
  for +s: List<&2, List<&2, Nat>>
  for +b: List<&2, List<&2, Nat>>
  for +h: List<&2, Core.Move>
  for +i: Nat
  for +j: Nat
  for e: {Spec.legal(k, b, i, j) == True{} : Bool}
  {Core.step(Core.Game{c, k, s, b, h}, Core.Mv{i, j}) == Core.Accepted{Core.apply(Core.Game{c, k, s, b, h}, Core.Mv{i, j}), Spec.top(Spec.column(b, i))} : Core.Outcome}

law step_refuses_illegal:
  for +c: Nat
  for +k: Nat
  for +s: List<&2, List<&2, Nat>>
  for +b: List<&2, List<&2, Nat>>
  for +h: List<&2, Core.Move>
  for +i: Nat
  for +j: Nat
  for e: {Spec.legal(k, b, i, j) == False{} : Bool}
  {Core.step(Core.Game{c, k, s, b, h}, Core.Mv{i, j}) == Core.Rejected{Core.why(k, b, i, j)} : Core.Outcome}

# Law 3 and Law 4: a move takes exactly the top bead
# ---------------------------------------------------
# For any movable pair of columns, transfer (which a legal move performs, by
# legal_is_played) leaves the source column as it
# was without its top bead, puts that bead on top of the target column, and
# changes no other column and no column count.

law transfer_source:
  for +b: List<&2, List<&2, Nat>>
  for +i: Nat
  for +j: Nat
  for +w: Spec.Holds(Spec.movable(b, i, j))
  {Spec.column(Core.transfer(b, i, j), i) == Spec.rest(Spec.column(b, i)) : List<&2, Nat>}

law transfer_target:
  for +b: List<&2, List<&2, Nat>>
  for +i: Nat
  for +j: Nat
  for +w: Spec.Holds(Spec.movable(b, i, j))
  {Spec.column(Core.transfer(b, i, j), j) == Spec.moved(Spec.column(b, i), Spec.column(b, j)) : List<&2, Nat>}

law transfer_others:
  for +b: List<&2, List<&2, Nat>>
  for +i: Nat
  for +j: Nat
  for +k: Nat
  for wi: Spec.Holds(Bool.not(Nat.is_eq(k, i)))
  for wj: Spec.Holds(Bool.not(Nat.is_eq(k, j)))
  {Spec.column(Core.transfer(b, i, j), k) == Spec.column(b, k) : List<&2, Nat>}

law transfer_width:
  for +b: List<&2, List<&2, Nat>>
  for +i: Nat
  for +j: Nat
  {Spec.width(Core.transfer(b, i, j)) == Spec.width(b) : Nat}

# Law 1: bead conservation
# ------------------------
# Any move, legal or not, keeps the number of beads of every colour, and the
# number of beads in all.

law conserves_colours:
  for +c: Nat
  for +g: Core.Game
  for +m: Core.Move
  {Spec.count(c, Core.board(Core.apply(g, m))) == Spec.count(c, Core.board(g)) : Nat}

law conserves_beads:
  for +g: Core.Game
  for +m: Core.Move
  {Spec.total(Core.board(Core.apply(g, m))) == Spec.total(Core.board(g)) : Nat}

# Law 2: column capacity
# ----------------------
# If no column is over capacity, none is after any move.

law keeps_capacity:
  for +g: Core.Game
  for +m: Core.Move
  for w: Spec.Holds(Spec.fits(Core.cap(g), Core.board(g)))
  Spec.Holds(Spec.fits(Core.cap(g), Core.board(Core.apply(g, m))))

# Law 5: an illegal move changes nothing
# --------------------------------------
# Not the board, not the history, not the move count.

law refused_changes_nothing:
  for +g: Core.Game
  for +m: Core.Move
  for e: {Spec.legal(Core.cap(g), Core.board(g), Core.from(m), Core.to(m)) == False{} : Bool}
  {Core.apply(g, m) == g : Core.Game}

# Law 9: undo
# -----------
# Undoing a legal move restores the exact game before it: board, history and
# move count. With no moves to undo, undo changes nothing.

law undo_takes_back:
  for +g: Core.Game
  for +m: Core.Move
  for e: {Spec.legal(Core.cap(g), Core.board(g), Core.from(m), Core.to(m)) == True{} : Bool}
  {Core.undo(Core.apply(g, m)) == g : Core.Game}

law undo_without_moves:
  for +colours: Nat
  for +cap: Nat
  for +start: List<&2, List<&2, Nat>>
  for +b: List<&2, List<&2, Nat>>
  {Core.undo(Core.Game{colours, cap, start, b, Nil{}}) == Core.Game{colours, cap, start, b, Nil{}} : Core.Game}

# Law 8: victory
# --------------
# On a valid board, the engine's check is exactly the four conditions of
# section 3.3 (Spec.solved). The engine does not check condition 1 (each
# colour in exactly one column): on a valid board it follows from the others.

law victory_is_solved:
  for +colours: Nat
  for +cap: Nat
  for +b: List<&2, List<&2, Nat>>
  for +w: Spec.Holds(Spec.valid(colours, cap, b))
  {Core.is_solved(cap, b) == Spec.solved(colours, cap, b) : Bool}

# Restart and replay (rest of law 9)
# ----------------------------------
# Restart returns to the puzzle's first board with no moves, never a new
# puzzle. Replaying a game's history from that first board rebuilds the game
# exactly, for every game reached by playing moves, legal or not.

law restart_goes_back:
  for +g: Core.Game
  {Core.restart(g) == Core.new(Core.colours(g), Core.cap(g), Core.start(g)) : Core.Game}

law replay_rebuilds:
  for +ms: List<&2, Core.Move>
  for +colours: Nat
  for +cap: Nat
  for +s: List<&2, List<&2, Nat>>
  g = Core.replay(ms, Core.new(colours, cap, s))
  {Core.replay(List.reverse(&2, Core.Move, Core.history(g)), Core.restart(g)) == g : Core.Game}
