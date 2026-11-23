# Prints generated puzzles, one per line, for comparison with the JavaScript
# build (tools/check/native.sh). Not part of the game.

import Base
import ../../engine/core.bend as Core
import ../../engine/gen.bend as Gen

def show_col(col: List<&2, Nat>) -> String:
  match col:
    case Nil{}:
      ""
    case h <> t:
      Nat.show(h) ++ "," ++ show_col(t)

def show_board(b: List<&2, List<&2, Nat>>) -> String:
  match b:
    case Nil{}:
      ""
    case c <> r:
      "[" ++ show_col(c) ++ "]" ++ show_board(r)

def show_moves(ms: List<&2, Core.Move>) -> String:
  match ms:
    case Nil{}:
      ""
    case m <> r:
      match m:
        case Core.Mv{i, j}:
          Nat.show(i) ++ ">" ++ Nat.show(j) ++ " " ++ show_moves(r)

def show(m: Maybe<&2, Gen.Puzzle>) -> String:
  match m:
    case None{}:
      "none"
    case Some{p}:
      match p:
        case Gen.Puzzle{b, cert}:
          show_board(b) ++ " " ++ show_moves(cert)

def line(+colours: Nat, +cap: Nat, +seed: U32) -> String:
  Nat.show(colours) ++ "x" ++ Nat.show(cap) ++ " " ++ U32.show(seed) ++ " " ++ show(Gen.generate(colours, cap, seed))

def seeds(+n: Nat, +colours: Nat, +cap: Nat) -> IO(Unit):
  match n:
    case 0n:
      IO.pure(Unit, Unit{})
    case 1n+p:
      do IO<Unit>:
        IO.print(line(colours, cap, U32.mul(U32.from_nat(p), 2654435761)))
        seeds(p, colours, cap)

def main() -> IO(Unit):
  do IO<Unit>:
    seeds(6n, 3n, 3n)
    seeds(6n, 4n, 4n)
    seeds(6n, 5n, 5n)
    seeds(6n, 6n, 6n)
    seeds(4n, 6n, 10n)
