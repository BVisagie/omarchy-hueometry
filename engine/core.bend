# Hueometry: the rules engine.
#
# The authoritative game state and every rule that changes it. Pure: no IO,
# no @unsafe, no foreign code. It knows nothing of layout, theme or platform.
# LAWS.bend states what must hold of these definitions; PROOF.bend proves it.
#
# A board is a list of columns, numbered from 0; a column lists its beads from
# the top down; a bead is its colour's number. The reading words (column,
# size, legal, ...) come from SPEC.bend, so the engine and the laws share one
# meaning of them.

import Base
import ../SPEC.bend as Spec

# State
# -----

# Take the top bead of column `from` and put it on column `to`.
type Move is Data:
  Mv{from: Nat, to: Nat}

# A puzzle in play. `start` is the board it began from (restart returns to
# it); `history` lists the accepted moves, newest first. The move count is
# the length of the history, so it can never disagree with it.
type Game is Data:
  Game{colours: Nat, cap: Nat, start: List<&2, List<&2, Nat>>, board: List<&2, List<&2, Nat>>, history: List<&2, Move>}

# Why a move was refused, for the interface to explain gently.
type Reason is Data:
  NoSuchColumn{}
  SameColumn{}
  EmptySource{}
  FullTarget{}

# An accepted move also names the bead it moved, for the interface to animate.
type Outcome is Data:
  Accepted{game: Game, bead: Nat}
  Rejected{reason: Reason}

def new(colours: Nat, cap: Nat, +b: List<&2, List<&2, Nat>>) -> Game:
  Game{colours, cap, b, b, Nil{}}

def board(g: Game) -> List<&2, List<&2, Nat>>:
  match g:
    case Game{colours, cap, start, b, history}:
      b

def cap(g: Game) -> Nat:
  match g:
    case Game{colours, c, start, b, h}:
      c

def from(m: Move) -> Nat:
  match m:
    case Mv{i, j}:
      i

def to(m: Move) -> Nat:
  match m:
    case Mv{i, j}:
      j

def history(g: Game) -> List<&2, Move>:
  match g:
    case Game{colours, cap, start, b, h}:
      h

def colours(g: Game) -> Nat:
  match g:
    case Game{c, k, start, b, h}:
      c

def start(g: Game) -> List<&2, List<&2, Nat>>:
  match g:
    case Game{c, k, s, b, h}:
      s

# Counts with an accumulator: a game can have tens of thousands of moves, and
# the JavaScript target spends a stack frame per non-tail call.
def length.go(h: List<&2, Move>, n: Nat) -> Nat:
  match h:
    case Nil{}:
      n
    case m <> r:
      length.go(r, 1n+n)

def length(h: List<&2, Move>) -> Nat:
  length.go(h, 0n)

def moves(g: Game) -> Nat:
  length(history(g))

# The history oldest first, as replay takes it. Used by the laws; the
# interface reverses the history itself.
def oldest_first(h: List<&2, Move>) -> List<&2, Move>:
  match h:
    case Nil{}:
      Nil{}
    case m <> r:
      List.append(&2, Move, oldest_first(r), [m])

# Boards
# ------

# the board with column k replaced by v (unchanged when there is no column k)
def set_col(b: List<&2, List<&2, Nat>>, k: Nat, v: List<&2, Nat>) -> List<&2, List<&2, Nat>>:
  match b k:
    case Nil{} _:
      Nil{}
    case c <> r 0n:
      v <> r
    case c <> r 1n+p:
      c <> set_col(r, p, v)

def transfer.go(+b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat, src: List<&2, Nat>) -> List<&2, List<&2, Nat>>:
  match src:
    case Nil{}:
      b
    case h <> t:
      set_col(set_col(b, i, t), j, h <> Spec.column(b, j))

# Moves the top bead of column i onto column j, checking nothing. Moves go
# through `apply`, which checks the rules first; undo uses this directly,
# because the reverse of a legal move needs no capacity check.
def transfer(+b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat) -> List<&2, List<&2, Nat>>:
  transfer.go(b, i, j, Spec.column(b, i))

# Playing
# -------

def apply.fin(colours: Nat, cap: Nat, start: List<&2, List<&2, Nat>>, +b: List<&2, List<&2, Nat>>, history: List<&2, Move>, +i: Nat, +j: Nat, ok: Bool) -> Game:
  match ok:
    case True{}:
      Game{colours, cap, start, transfer(b, i, j), Mv{i, j} <> history}
    case False{}:
      Game{colours, cap, start, b, history}

# Plays m if the rules allow it (Spec.legal); otherwise the game is unchanged,
# move count included.
def apply(g: Game, m: Move) -> Game:
  match g m:
    case Game{colours, +cap, start, +b, history} Mv{+i, +j}:
      apply.fin(colours, cap, start, b, history, i, j, Spec.legal(cap, b, i, j))

def why(+cap: Nat, +b: List<&2, List<&2, Nat>>, +i: Nat, +j: Nat) -> Reason:
  +w = Spec.width(b)
  Bool.pick(Reason, Bool.not(Nat.is_lt(i, w) && Nat.is_lt(j, w)), NoSuchColumn{},
    Bool.pick(Reason, Nat.is_eq(i, j), SameColumn{},
      Bool.pick(Reason, Spec.is_empty(Spec.column(b, i)), EmptySource{}, FullTarget{})))

def lifted(g: Game, m: Move) -> Nat:
  match g m:
    case Game{colours, cap, start, b, history} Mv{i, j}:
      Spec.top(Spec.column(b, i))

def step.fin(ok: Bool, +g: Game, +m: Move) -> Outcome:
  match ok:
    case True{}:
      Accepted{apply(g, m), lifted(g, m)}
    case False{}:
      match g m:
        case Game{colours, +cap, start, +b, history} Mv{+i, +j}:
          Rejected{why(cap, b, i, j)}

def legal_move(g: Game, m: Move) -> Bool:
  match g m:
    case Game{colours, +cap, start, +b, history} Mv{+i, +j}:
      Spec.legal(cap, b, i, j)

# What the interface calls: the new game, or why the move was refused.
def step(+g: Game, +m: Move) -> Outcome:
  step.fin(legal_move(g, m), g, m)

def undo.go(colours: Nat, cap: Nat, start: List<&2, List<&2, Nat>>, +b: List<&2, List<&2, Nat>>, h: List<&2, Move>) -> Game:
  match h:
    case Nil{}:
      Game{colours, cap, start, b, Nil{}}
    case m <> r:
      match m:
        case Mv{+i, +j}:
          Game{colours, cap, start, transfer(b, j, i), r}

# Takes back the newest accepted move. With no moves to take back, nothing
# changes.
def undo(g: Game) -> Game:
  match g:
    case Game{colours, cap, start, +b, h}:
      undo.go(colours, cap, start, b, h)

# Back to the puzzle's first board, with no moves. Never a new puzzle.
def restart(g: Game) -> Game:
  match g:
    case Game{colours, cap, +start, b, h}:
      Game{colours, cap, start, start, Nil{}}

# Plays the moves in order, as apply does.
def replay(ms: List<&2, Move>, g: Game) -> Game:
  match ms:
    case Nil{}:
      g
    case m <> r:
      replay(r, apply(g, m))

# Victory
# -------

# Every occupied column is one colour and full, and exactly one column is
# empty. On a valid board this is the whole of section 3.3: each colour then
# fills exactly one column (law victory_is_solved).
def is_solved(+cap: Nat, +b: List<&2, List<&2, Nat>>) -> Bool:
  Spec.occupied_full_uniform(cap, b) && Nat.is_eq(Spec.empties(b), 1n)

def solved(g: Game) -> Bool:
  match g:
    case Game{colours, cap, start, b, h}:
      is_solved(cap, b)

# For each column, in order: is it done, holding beads of one colour only and
# full? This is the per-column test of Spec.occupied_full_uniform, without
# its empty case. The interface draws a flower on a done column.
def complete.go(+cap: Nat, b: List<&2, List<&2, Nat>>) -> List<&2, Bool>:
  match b:
    case Nil{}:
      Nil{}
    case +col <> r:
      (Bool.not(Spec.is_empty(col)) && Spec.uniform(col) && Nat.is_eq(Spec.size(col), cap)) <> complete.go(cap, r)

def complete(g: Game) -> List<&2, Bool>:
  match g:
    case Game{colours, +cap, start, +b, h}:
      complete.go(cap, b)

# The columns a bead lifted from column i may land on, in column order.
def targets.go(+cap: Nat, +b: List<&2, List<&2, Nat>>, +i: Nat, +k: Nat, +acc: List<&2, Nat>) -> List<&2, Nat>:
  match k:
    case 0n:
      acc
    case 1n+p:
      targets.go(cap, b, i, p, Bool.pick(List<&2, Nat>, Spec.legal(cap, b, i, p), p <> acc, acc))

def targets(g: Game, +i: Nat) -> List<&2, Nat>:
  match g:
    case Game{colours, +cap, start, +b, h}:
      targets.go(cap, b, i, Spec.width(b), Nil{})
