import QtQuick
import QtTest
import "../../qml/Hueometry/js/rules.mjs" as R

// The Bend engine, run by Qt's own JavaScript engine: the one the game uses.
TestCase {
  name: "Engine"

  function test_moves_and_refusals() {
    let g = R.newGame(2, 2, [[0, 1], [1, 0], []])
    let r = R.play(g, 0, 2)
    verify(r.accepted)
    compare(R.view(r.game).columns, [[1], [1, 0], [0]])
    r = R.play(r.game, 0, 1)
    verify(!r.accepted)
    compare(r.reason, "full-target")
    compare(R.moves(r.game), 1)
  }

  function test_solve_undo_restart() {
    let g = R.newGame(2, 2, [[0, 1], [0, 1], []])
    for (const m of [[0, 2], [1, 2], [1, 0]]) g = R.play(g, m[0], m[1]).game
    verify(R.solved(g))
    compare(R.moves(R.undo(g)), 2)
    compare(R.view(R.restart(g)).columns, [[0, 1], [0, 1], []])
  }

  function test_long_replay() {
    // 600 legal moves on the Expert board size (6 colours of 10, 7 columns)
    const cols = []
    for (let c = 0; c < 6; c++) cols.push(Array(10).fill(c))
    cols.push([])
    let g = R.newGame(6, 10, cols)
    let n = 0
    const t0 = Date.now()
    for (let k = 0; n < 600 && k < 5000; k++) {
      const from = (k * 5 + 1) % 7, to = (k * 3 + 2) % 7
      const r = R.play(g, from, to)
      if (r.accepted) n++
      g = r.game
    }
    compare(n, 600)
    const t1 = Date.now()
    const again = R.replay(R.newGame(6, 10, cols), R.history(g))
    const t2 = Date.now()
    compare(R.view(again).columns, R.view(g).columns)
    console.log("timing: 600 moves", t1 - t0, "ms; replay", t2 - t1, "ms")
  }
}
