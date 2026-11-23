import QtQuick
import QtTest
import "../../qml/Hueometry"

// The whole game through its keyboard: menus, a tutorial puzzle solved with
// keys, the results card, and progress saved through the host.
Item {
  id: root
  width: 1280
  height: 720

  MemoryHost { id: memory }
  Game { id: game; anchors.fill: parent; host: memory }

  TestCase {
    name: "Game"
    when: windowShown

    function keys(list) { for (const k of list) { keyClick(k); wait(0) } }

    function test_1_menu_to_tutorial() {
      game.forceActiveFocus()
      compare(game.screen, "menu")
      keyClick(Qt.Key_Return)                 // Adventure
      compare(game.screen, "map")
      keyClick(Qt.Key_Left)                   // area 0: First Steps
      keyClick(Qt.Key_Return)                 // open it
      keyClick(Qt.Key_Return)                 // puzzle 1
      compare(game.screen, "play")
      compare(game.current.ref.kind, "tutorial")
    }

    function test_2_solve_with_keys() {
      const sol = game.current.session.puzzle.solution
      for (const m of sol) {
        keyClick(Qt.Key_1 + m.from)
        keyClick(Qt.Key_1 + m.to)
        tryVerify(() => !game.current.children.find(c => c.busy), 2000)
        wait(Theme.reducedMotion ? 0 : 500)
      }
      tryVerify(() => !!game.current.result, 3000)
      compare(game.current.view.moves, sol.length)
      const saved = JSON.parse(memory.files["progress.json"])
      compare(saved.done["tutorial/0"].best, sol.length)
      compare(saved.current, null)
    }

    function test_3_undo_and_refuse() {
      keyClick(Qt.Key_Return)                 // Next: tutorial 2
      tryCompare(game.current.ref, "index", 1)
      const before = game.current.view.moves
      keyClick(Qt.Key_3)                      // the empty pillar: nothing to lift
      compare(game.current.session.selected, -1)
      keyClick(Qt.Key_1)
      compare(game.current.session.selected, 0)
      keyClick(Qt.Key_2)                      // full: refused, orb stays lifted
      compare(game.current.session.selected, 0)
      compare(game.current.view.moves, before)
      keyClick(Qt.Key_3)                      // legal
      compare(game.current.view.moves, before + 1)
      wait(600)
      keyClick(Qt.Key_U)
      compare(game.current.view.moves, before)
      keyClick(Qt.Key_H)
      verify(game.current.hint !== null || game.current.message !== "")
    }

    function test_4_help_and_back() {
      keyClick(Qt.Key_Question)
      verify(game.helpShown)
      keyClick(Qt.Key_Space)
      verify(!game.helpShown)
      keyClick(Qt.Key_Escape)
      compare(game.screen, "map")
      keyClick(Qt.Key_Escape)
      compare(game.screen, "menu")
      compare(JSON.parse(memory.files["progress.json"]).current.ref.index, 1, "the unfinished puzzle is saved")
    }
  }
}
