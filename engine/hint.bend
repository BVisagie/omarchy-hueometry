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

# FNV-1a over the beads, with a marker after each column: equal boards have
# equal hashes, so a board is compared in full only when its hash matches.
def mix(+h: U32, +x: U32) -> U32:
  U32.mul(U32.xor(h, x), 16777619)

def hash.col(col: List<&2, Nat>, +h: U32) -> U32:
  match col:
    case Nil{}:
      mix(h, 4294967295)
    case x <> r:
      hash.col(r, mix(h, U32.from_nat(x)))

def hash.go(b: List<&2, List<&2, Nat>>, +h: U32) -> U32:
  match b:
    case Nil{}:
      h
    case c <> r:
      hash.go(r, hash.col(c, h))

def hash(b: List<&2, List<&2, Nat>>) -> U32:
  hash.go(b, 2166136261)

# a board of the solution, with its hash
type Seen is Data:
  Seen{key: U32, board: List<&2, List<&2, Nat>>}

# Bend evaluates both sides of && and ||, so the choices here go through
# closures: a board is compared in full only when its hash matches, and the
# search stops at the first match.
def either(c: Bool, a: Unit -> Bool, b: Unit -> Bool) -> Bool:
  match c:
    case True{}:
      a(Unit{})
    case False{}:
      b(Unit{})

def on.hit(hit: Bool, +b: List<&2, List<&2, Nat>>, x: List<&2, List<&2, Nat>>, rest: Unit -> Bool) -> Bool:
  match hit:
    case True{}:
      either(same_board(b, x), u => True{}, rest)
    case False{}:
      rest(Unit{})

def on(+key: U32, +b: List<&2, List<&2, Nat>>, bs: List<&2, Seen>) -> Bool:
  match bs:
    case Nil{}:
      False{}
    case s <> r:
      match s:
        case Seen{+k, x}:
          on.hit(U32.is_eq(key, k), b, x, u => on(key, b, r))

# the boards a list of moves passes through from g, newest first, g's first
# board last
def boards(ms: List<&2, Core.Move>, +g: Core.Game, acc: List<&2, Seen>) -> List<&2, Seen>:
  match ms:
    case Nil{}:
      Seen{hash(Core.board(g)), Core.board(g)} <> acc
    case m <> r:
      boards(r, Core.apply(g, m), Seen{hash(Core.board(g)), Core.board(g)} <> acc)

# the last solution move played from a board equal to b, if any
def next_move(+b: List<&2, List<&2, Nat>>, ms: List<&2, Core.Move>, +g: Core.Game, found: Maybe<&2, Core.Move>) -> Maybe<&2, Core.Move>:
  match ms:
    case Nil{}:
      found
    case +m <> r:
      next_move(b, r, Core.apply(g, m), Bool.pick(Maybe<&2, Core.Move>, same_board(b, Core.board(g)), Some{m}, found))

# choose between two answers, computing only the chosen one
def lazy(c: Bool, a: Unit -> Nat, b: Unit -> Nat) -> Nat:
  match c:
    case True{}:
      a(Unit{})
    case False{}:
      b(Unit{})

# Undoes one move at a time (n moves at most) until the board is one the
# solution passes through; answers how many undos that took, or 0 if none.
def back.go(n: Nat, +sol: List<&2, Seen>, +g: Core.Game, +k: Nat) -> Nat:
  match n:
    case 0n:
      0n
    case 1n+p:
      +u = Core.undo(g)
      +b = Core.board(u)
      lazy(on(hash(b), b, sol), x => k, x => back.go(p, sol, u, 1n+k))

def hint.fin(+g: Core.Game, +sol: List<&2, Core.Move>, mm: Maybe<&2, Core.Move>) -> Hint:
  match mm:
    case Some{+m}:
      Bool.pick(Hint, Core.legal_move(g, m), Play{m}, NoHint{})
    case None{}:
      +steps = back.go(Core.moves(g), boards(sol, Core.restart(g), Nil{}), g, 1n)
      Bool.pick(Hint, Nat.is_eq(steps, 0n), NoHint{}, Back{steps})

# A hint for game g, following sol (a solution of g's first board, oldest
# move first).
def hint.solved(done: Bool, +g: Core.Game, +sol: List<&2, Core.Move>) -> Hint:
  match done:
    case True{}:
      Solved{}
    case False{}:
      hint.fin(g, sol, next_move(Core.board(g), sol, Core.restart(g), None{}))

def hint(+g: Core.Game, +sol: List<&2, Core.Move>) -> Hint:
  hint.solved(Core.solved(g), g, sol)
