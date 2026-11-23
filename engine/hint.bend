# Hueometry: hints.
#
# A hint follows a known solution of the puzzle (from the level pack, or a
# generated puzzle's certificate). If the board is one the solution passes
# through, the hint is the solution's next move there, checked legal. If the
# player has left the solution, the hint is how many moves to undo to get
# back to a board on it. A hint never claims to be the shortest way.

import Base
import ../SPEC.bend as Spec
import ./core.bend as Core

type Hint is Data:
  Play{move: Core.Move}
  Back{steps: Nat}
  Solved{}
  NoHint{}

def same_col(a: List<&2, Nat>, b: List<&2, Nat>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Nil{} y <> s:
      False{}
    case x <> r Nil{}:
      False{}
    case x <> r y <> s:
      Nat.is_eq(x, y) && same_col(r, s)

def same_board(a: List<&2, List<&2, Nat>>, b: List<&2, List<&2, Nat>>) -> Bool:
  match a b:
    case Nil{} Nil{}:
      True{}
    case Nil{} y <> s:
      False{}
    case x <> r Nil{}:
      False{}
    case x <> r y <> s:
      same_col(x, y) && same_board(r, s)

def on(+b: List<&2, List<&2, Nat>>, bs: List<&2, List<&2, List<&2, Nat>>>) -> Bool:
  match bs:
    case Nil{}:
      False{}
    case x <> r:
      same_board(b, x) || on(b, r)

# the boards a list of moves passes through from g, newest first, g's first
# board last
def boards(ms: List<&2, Core.Move>, +g: Core.Game, acc: List<&2, List<&2, List<&2, Nat>>>) -> List<&2, List<&2, List<&2, Nat>>>:
  match ms:
    case Nil{}:
      Core.board(g) <> acc
    case m <> r:
      boards(r, Core.apply(g, m), Core.board(g) <> acc)

# the last solution move played from a board equal to b, if any
def next_move(+b: List<&2, List<&2, Nat>>, ms: List<&2, Core.Move>, +g: Core.Game, found: Maybe<&2, Core.Move>) -> Maybe<&2, Core.Move>:
  match ms:
    case Nil{}:
      found
    case +m <> r:
      next_move(b, r, Core.apply(g, m), Bool.pick(Maybe<&2, Core.Move>, same_board(b, Core.board(g)), Some{m}, found))

# moves since the newest history board that lies on the solution
def back.go(hs: List<&2, List<&2, List<&2, Nat>>>, +sol: List<&2, List<&2, List<&2, Nat>>>, +n: Nat) -> Nat:
  match hs:
    case Nil{}:
      n
    case h <> r:
      Bool.pick(Nat, on(h, sol), n, back.go(r, sol, 1n+n))

def hint.fin(+g: Core.Game, +sol: List<&2, Core.Move>, mm: Maybe<&2, Core.Move>) -> Hint:
  match mm:
    case Some{+m}:
      Bool.pick(Hint, Core.legal_move(g, m), Play{m}, NoHint{})
    case None{}:
      +start = Core.restart(g)
      +path = boards(sol, start, Nil{})
      # the history's boards, newest first, without the current one
      +hs = List.tail(&2, List<&2, List<&2, Nat>>, boards(Core.oldest_first(Core.history(g)), start, Nil{}))
      Bool.pick(Hint, List.is_empty(&2, List<&2, List<&2, Nat>>, hs), NoHint{}, Back{back.go(hs, path, 1n)})

# A hint for game g, following sol (a solution of g's first board, oldest
# move first).
def hint(+g: Core.Game, +sol: List<&2, Core.Move>) -> Hint:
  Bool.pick(Hint, Core.solved(g), Solved{}, hint.fin(g, sol, next_move(Core.board(g), sol, Core.restart(g), None{})))
