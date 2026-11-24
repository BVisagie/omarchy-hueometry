# Hueometry: what the game interface may call.
#
# bin/engine compiles this file to qml/Hueometry/js/engine.mjs. Every def
# here is exported under its own name; the interface reaches the engine only
# through these, via qml/Hueometry/js/rules.mjs.

import Base
import ../SPEC.bend as Spec
import ./core.bend as Core
import ./gen.bend as Gen
import ./hint.bend as Hint

def new_game(colours: Nat, cap: Nat, +b: List<&2, List<&2, Nat>>) -> Core.Game:
  Core.new(colours, cap, b)

# The new game, or why the move was refused.
def play(+g: Core.Game, from: Nat, to: Nat) -> Core.Outcome:
  Core.step(g, Core.Mv{from, to})

def undo(g: Core.Game) -> Core.Game:
  Core.undo(g)

def restart(g: Core.Game) -> Core.Game:
  Core.restart(g)

def replay(g: Core.Game, ms: List<&2, Core.Move>) -> Core.Game:
  Core.replay(ms, g)

def solved(g: Core.Game) -> Bool:
  Core.solved(g)

def moves(g: Core.Game) -> Nat:
  Core.moves(g)

# For each column: one colour and full?
def complete(g: Core.Game) -> List<&2, Bool>:
  Core.complete(g)

# The columns the top bead of column i may move to.
def targets(g: Core.Game, +i: Nat) -> List<&2, Nat>:
  Core.targets(g, i)

# Is b a valid puzzle board for these colours and capacity (SPEC.bend)?
def valid(+colours: Nat, +cap: Nat, +b: List<&2, List<&2, Nat>>) -> Bool:
  Spec.valid(colours, cap, b)

# A puzzle from a seed: its board and a solution (not a short one), or None.
def generate(+colours: Nat, +cap: Nat, +seed: U32) -> Maybe<&2, Gen.Puzzle>:
  Gen.generate(colours, cap, seed)

# A hint along sol, a solution of g's first board, oldest move first.
def hint(+g: Core.Game, +sol: List<&2, Core.Move>) -> Hint.Hint:
  Hint.hint(g, sol)
