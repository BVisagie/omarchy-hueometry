# Hueometry: what the game interface may call.
#
# bin/engine compiles this file to qml/Hueometry/js/engine.mjs. Every def
# here is exported under its own name; the interface reaches the engine only
# through these, via qml/Hueometry/js/rules.mjs.

import Base
import ./core.bend as Core

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

# The columns the top bead of column i may move to.
def targets(g: Core.Game, +i: Nat) -> List<&2, Nat>:
  Core.targets(g, i)
