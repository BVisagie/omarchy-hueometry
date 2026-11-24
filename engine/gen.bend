# Hueometry: puzzle generation and hints.
#
# A puzzle starts as a solved board and is scrambled by legal moves chosen by
# a seeded random number generator, so the same seed always gives the same
# puzzle. Every move is reversible, so the scramble reversed is a solution:
# the certificate. `generate` returns a puzzle only after checking, through
# the engine's own replay, that the certificate solves it (law
# generated_puzzles_solve). The certificate is a valid solution, not a short
# one; par scores come from the level tools, never from it.

import Base
import ../SPEC.bend as Spec
import ./core.bend as Core

type Puzzle is Data:
  Puzzle{board: List<&2, List<&2, Nat>>, cert: List<&2, Core.Move>}

# Random numbers
# --------------

# xorshift32. Seed 0 would stay 0 forever, so it is moved to another value.
def rng.next(+x: U32) -> U32:
  +a = U32.xor(x, U32.shln(x, 13n))
  +b = U32.xor(a, U32.shrn(a, 17n))
  U32.xor(b, U32.shln(b, 5n))

def rng.seed(+s: U32) -> U32:
  rng.next(Bool.pick(U32, U32.is_eq(s, 0), 2654435769, s))

# a number below n (0 when n is 0)
def rng.below(+x: U32, +n: Nat) -> Nat:
  Bool.pick(Nat, Nat.is_eq(n, 0n), 0n, U32.to_nat(U32.mod(x, U32.from_nat(n))))

# Boards
# ------

def column_of(+c: Nat, n: Nat) -> List<&2, Nat>:
  match n:
    case 0n:
      Nil{}
    case 1n+p:
      c <> column_of(c, p)

# k full columns of colours from, from+1, ..., then one empty column
def solved.go(k: Nat, +cap: Nat, +from: Nat) -> List<&2, List<&2, Nat>>:
  match k:
    case 0n:
      [Nil{}]
    case 1n+p:
      column_of(from, cap) <> solved.go(p, cap, 1n+from)

# The solved board: colour c fills column c, and the last column is empty.
def solved_board(+colours: Nat, +cap: Nat) -> List<&2, List<&2, Nat>>:
  solved.go(colours, cap, 0n)

# every legal move from column i, in target order
def moves_from(+i: Nat, ts: List<&2, Nat>) -> List<&2, Core.Move>:
  match ts:
    case Nil{}:
      Nil{}
    case t <> r:
      Core.Mv{i, t} <> moves_from(i, r)

def legal_moves.go(+cap: Nat, +b: List<&2, List<&2, Nat>>, +k: Nat, acc: List<&2, Core.Move>) -> List<&2, Core.Move>:
  match k:
    case 0n:
      acc
    case 1n+p:
      legal_moves.go(cap, b, p, List.append(&2, Core.Move, moves_from(p, Core.targets.go(cap, b, p, Spec.width(b), Nil{})), acc))

def legal_moves(+cap: Nat, +b: List<&2, List<&2, Nat>>) -> List<&2, Core.Move>:
  legal_moves.go(cap, b, Spec.width(b), Nil{})

def nth(ms: List<&2, Core.Move>, n: Nat) -> Maybe<&2, Core.Move>:
  match ms n:
    case Nil{} _:
      None{}
    case m <> r 0n:
      Some{m}
    case m <> r 1n+p:
      nth(r, p)

def is_move(+m: Core.Move, +i: Nat, +j: Nat) -> Bool:
  Nat.is_eq(Core.from(m), i) && Nat.is_eq(Core.to(m), j)

def drop_move(+i: Nat, +j: Nat, ms: List<&2, Core.Move>) -> List<&2, Core.Move>:
  match ms:
    case Nil{}:
      Nil{}
    case +m <> r:
      +rest = drop_move(i, j, r)
      Bool.pick(List<&2, Core.Move>, is_move(m, i, j), rest, m <> rest)

def inverse(m: Core.Move) -> Core.Move:
  match m:
    case Core.Mv{i, j}:
      Core.Mv{j, i}

# Scrambling
# ----------

# A scramble in progress: the board, the random state, the last move, the
# moves made (newest first), and whether it has stopped.
type Walk is Data:
  Walk{cap: Nat, board: List<&2, List<&2, Nat>>, x: U32, last: Core.Move, done: List<&2, Core.Move>}

def walk.pick(+x: U32, +all: List<&2, Core.Move>, +fresh: List<&2, Core.Move>) -> Maybe<&2, Core.Move>:
  +pool = Bool.pick(List<&2, Core.Move>, List.is_empty(&2, Core.Move, fresh), all, fresh)
  nth(pool, rng.below(x, Core.length.go(pool, 0n)))

def walk.apply(+cap: Nat, +b: List<&2, List<&2, Nat>>, +x: U32, +last: Core.Move, done: List<&2, Core.Move>, mm: Maybe<&2, Core.Move>) -> Walk:
  match mm:
    case None{}:
      Walk{cap, b, x, last, done}
    case Some{+m}:
      Walk{cap, Core.transfer(b, Core.from(m), Core.to(m)), rng.next(x), m, m <> done}

# one random legal move, never undoing the move just made unless it is the
# only one
def walk.step(w: Walk) -> Walk:
  match w:
    case Walk{+cap, +b, +x, +last, done}:
      +all = legal_moves(cap, b)
      walk.apply(cap, b, x, last, done, walk.pick(x, all, drop_move(Core.to(last), Core.from(last), all)))

def walk(n: Nat, w: Walk) -> Walk:
  match n:
    case 0n:
      w
    case 1n+p:
      walk(p, walk.step(w))

# the first column other than `skip` with room, if any
def room.go(+cap: Nat, b: List<&2, List<&2, Nat>>, +skip: Nat, +at: Nat) -> Maybe<&2, Nat>:
  match b:
    case Nil{}:
      None{}
    case +c <> r:
      Bool.pick(Maybe<&2, Nat>, Nat.is_lt(Spec.size(c), cap) && Bool.not(Nat.is_eq(at, skip)), Some{at}, room.go(cap, r, skip, 1n+at))

# the column with the fewest beads (the first such)
def fewest.go(b: List<&2, List<&2, Nat>>, +at: Nat, +best: Nat, +size: Nat) -> Nat:
  match b:
    case Nil{}:
      best
    case +c <> r:
      +n = Spec.size(c)
      fewest.go(r, 1n+at, Bool.pick(Nat, Nat.is_lt(n, size), at, best), Bool.pick(Nat, Nat.is_lt(n, size), n, size))

def gather.apply(+cap: Nat, +e: Nat, +b: List<&2, List<&2, Nat>>, +x: U32, +last: Core.Move, done: List<&2, Core.Move>, to: Maybe<&2, Nat>) -> Walk:
  match to:
    case None{}:
      Walk{cap, b, x, last, done}
    case Some{+t}:
      Walk{cap, Core.transfer(b, e, t), x, Core.Mv{e, t}, Core.Mv{e, t} <> done}

def gather.step(+e: Nat, w: Walk) -> Walk:
  match w:
    case Walk{+cap, +b, +x, +last, done}:
      gather.apply(cap, e, b, x, last, done, room.go(cap, b, e, 0n))

# Empties column e onto the first columns with room, one bead per step:
# afterwards every other column is full, because a valid board has exactly
# one column of room.
def gather(n: Nat, +e: Nat, w: Walk) -> Walk:
  match n:
    case 0n:
      w
    case 1n+p:
      gather(p, e, gather.step(e, w))

def pour.step(+a: Nat, +e: Nat, w: Walk) -> Walk:
  match w:
    case Walk{cap, +b, x, last, done}:
      Walk{cap, Core.transfer(b, a, e), x, Core.Mv{a, e}, Core.Mv{a, e} <> done}

# moves n beads from column a onto column e, one at a time
def pour(n: Nat, +a: Nat, +e: Nat, w: Walk) -> Walk:
  match n:
    case 0n:
      w
    case 1n+p:
      pour(p, a, e, pour.step(a, e, w))

# After the gather, column e is empty and every other column is full. Pour a
# random full column into it: its bottom beads come out on top, which a
# random walk alone reaches only rarely.
def round.pour(+e: Nat, w: Walk) -> Walk:
  match w:
    case Walk{+cap, +b, +x, last, done}:
      +k = rng.below(x, Nat.sub(Spec.width(b), 1n))
      +a = Bool.pick(Nat, Nat.is_lt(k, e), k, 1n+k)
      pour(cap, a, e, Walk{cap, b, rng.next(x), last, done})

def round.gather(w: Walk) -> Walk:
  match w:
    case Walk{+cap, +b, x, last, done}:
      +e = fewest.go(b, 0n, 0n, 1n+cap)
      round.pour(e, gather(cap, e, Walk{cap, b, x, last, done}))

# rounds of: a random walk, gather the room into one column, pour a column
# into it. Each round ends with one empty column and the others full.
def rounds(n: Nat, +steps: Nat, w: Walk) -> Walk:
  match n:
    case 0n:
      w
    case 1n+p:
      rounds(p, steps, round.gather(walk(steps, w)))

# Mixing
# ------

# adjacent beads of different colours in a column
def breaks.go(t: List<&2, Nat>, +h: Nat) -> Nat:
  match t:
    case Nil{}:
      0n
    case +x <> r:
      Spec.bump(Bool.not(Nat.is_eq(h, x)), breaks.go(r, x))

def breaks(col: List<&2, Nat>) -> Nat:
  match col:
    case Nil{}:
      0n
    case h <> t:
      breaks.go(t, h)

def all_breaks(b: List<&2, List<&2, Nat>>) -> Nat:
  match b:
    case Nil{}:
      0n
    case c <> r:
      Nat.add(breaks(c), all_breaks(r))

def any_done(+cap: Nat, b: List<&2, List<&2, Nat>>) -> Bool:
  match b:
    case Nil{}:
      False{}
    case +c <> r:
      (Bool.not(Spec.is_empty(c)) && Spec.uniform(c) && Nat.is_eq(Spec.size(c), cap)) || any_done(cap, r)

# Well mixed: no column is already finished, and the colour changes inside
# columns are at least 80% of what a random board has on average. Of the
# colours * (cap - 1) neighbouring pairs, a random board has a fraction
# (colours * cap - cap) / (colours * cap - 1) of different colours.
def mixed(+colours: Nat, +cap: Nat, +b: List<&2, List<&2, Nat>>) -> Bool:
  +beads = Nat.mul(colours, cap)
  +expected = Nat.mul(Nat.mul(colours, Nat.sub(cap, 1n)), Nat.sub(beads, cap))
  Bool.not(any_done(cap, b)) && Nat.is_le(Nat.mul(4n, expected), Nat.mul(Nat.mul(5n, all_breaks(b)), Nat.sub(beads, 1n)))

# Generating
# ----------

# What generate promises (law generated_puzzles_solve), checked through the
# engine's own replay, plus the mixing test. Valid with exactly one empty
# column means every other column is full: the start shape of section 3.1.
def sound(+colours: Nat, +cap: Nat, +b: List<&2, List<&2, Nat>>, +cert: List<&2, Core.Move>) -> Bool:
  Spec.valid(colours, cap, b) && Nat.is_eq(Spec.empties(b), 1n) && Bool.not(Spec.solved(colours, cap, b)) && Core.solved(Core.replay(cert, Core.new(colours, cap, b)))

def accept(+colours: Nat, +cap: Nat, +b: List<&2, List<&2, Nat>>, +cert: List<&2, Core.Move>) -> Bool:
  sound(colours, cap, b, cert) && mixed(colours, cap, b)

def reverse_inverse(ms: List<&2, Core.Move>, acc: List<&2, Core.Move>) -> List<&2, Core.Move>:
  match ms:
    case Nil{}:
      acc
    case m <> r:
      reverse_inverse(r, inverse(m) <> acc)

# m followed by its inverse returns to the same board, so such neighbours
# are dropped (repeatedly, as a stack): the certificate stays a solution, only
# shorter. Answers the kept moves newest first.
def cancel.push(+m: Core.Move, kept: List<&2, Core.Move>) -> List<&2, Core.Move>:
  match kept:
    case Nil{}:
      [m]
    case +t <> +r:
      Bool.pick(List<&2, Core.Move>, is_move(t, Core.to(m), Core.from(m)), r, m <> t <> r)

def cancel(ms: List<&2, Core.Move>, kept: List<&2, Core.Move>) -> List<&2, Core.Move>:
  match ms:
    case Nil{}:
      kept
    case +m <> r:
      cancel(r, cancel.push(m, kept))

# One scramble from the solved board: 2 * colours + 2 rounds of `steps`
# random moves, gather and pour. The moves are newest first, so the
# certificate is each move's inverse in that same order (the newest move is
# undone first).
def candidate.fin(w: Walk) -> Puzzle:
  match w:
    case Walk{cap, b, x, last, done}:
      Puzzle{b, List.reverse(&2, Core.Move, cancel(List.reverse(&2, Core.Move, reverse_inverse(done, Nil{})), Nil{}))}

def candidate(+colours: Nat, +cap: Nat, +x: U32, +steps: Nat) -> Puzzle:
  # `last` starts as a move between columns that do not exist, so no first
  # move is excluded
  candidate.fin(rounds(Nat.add(2n, Nat.mul(2n, colours)), steps, Walk{cap, solved_board(colours, cap), x, Core.Mv{1n+colours, 1n+colours}, Nil{}}))

# the first scramble that passes, or the rest of the attempts
def emit(ok: Bool, p: Puzzle, rest: Unit -> Maybe<&2, Puzzle>) -> Maybe<&2, Puzzle>:
  match ok:
    case True{}:
      Some{p}
    case False{}:
      rest(Unit{})

def attempt(+colours: Nat, +cap: Nat, p: Puzzle, rest: Unit -> Maybe<&2, Puzzle>) -> Maybe<&2, Puzzle>:
  match p:
    case Puzzle{+b, +cert}:
      emit(accept(colours, cap, b, cert), Puzzle{b, cert}, rest)

# the random state for attempt n of a seed: each attempt has its own stream,
# so a seed whose first scramble is rejected does not borrow another seed's
def rng.attempt(+seed: U32, +n: Nat) -> U32:
  rng.seed(U32.xor(seed, U32.mul(U32.from_nat(n), 2246822519)))

def tries(+n: Nat, +colours: Nat, +cap: Nat, +seed: U32, +steps: Nat) -> Maybe<&2, Puzzle>:
  match n:
    case 0n:
      None{}
    case 1n+p:
      attempt(colours, cap, candidate(colours, cap, rng.attempt(seed, n), steps), u => tries(p, colours, cap, seed, steps))

# A puzzle of `colours` colours in columns of `cap`, from `seed`, or None if
# 16 scrambles in a row were not mixed enough (or colours or cap is 0).
# Each scramble makes about 8 * colours * (colours + 1) * cap random moves.
# xorshift cannot start from 0, so for each attempt one pair of seeds
# shares a random stream; no seed is special.
def generate(+colours: Nat, +cap: Nat, +seed: U32) -> Maybe<&2, Puzzle>:
  tries(16n, colours, cap, seed, Nat.mul(4n, Nat.mul(1n+colours, cap)))
