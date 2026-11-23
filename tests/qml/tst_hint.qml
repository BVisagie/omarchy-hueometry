import QtQuick
import QtTest
import "../../qml/Hueometry/js/rules.mjs" as R

// Hints on the biggest board, in Qt's engine, stay quick.
TestCase {
  name: "Hint"

  function test_expert_hint_after_many_moves() {
    const p = R.generate(6, 10, 1)
    let g = R.newGame(6, 10, p.columns)
    let n = 0
    for (let k = 0; n < 3000 && k < 100000; k++) {
      const r = R.play(g, k % 7, (k * 3 + 1) % 7)
      if (r.accepted) n++
      g = r.game
    }
    compare(n, 3000)
    const t0 = Date.now()
    const h = R.hint(g, p.solution)
    const ms = Date.now() - t0
    console.log("timing: expert hint after 3000 moves", ms, "ms, kind", h.kind)
    verify(h.kind === "back" || h.kind === "play")
    verify(ms < 3000)
  }
}
