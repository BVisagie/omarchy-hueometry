import QtQuick
import QtTest
import "../../qml/Hueometry"
import "../../qml/Hueometry/js/store.mjs" as Store

// The whole game through its keyboard: menus, a tutorial puzzle solved with
// keys, the results card, and progress saved through the host.
Item {
  id: root
  width: 1280
  height: 720

  MemoryHost { id: memory }
  Component { id: hostMaker; MemoryHost {} }
  Component { id: gameMaker; Game { width: 1280; height: 720 } }
  Game { id: game; anchors.fill: parent; host: memory }
  SignalSpy { id: opened; signalName: "opened" }

  TestCase {
    name: "Game"
    when: windowShown

    // every test runs silent (MemoryHost starts muted; tests that replace
    // the settings keep it)
    // and the sound bank obeys it: no music or ambience is playing
    function playingPlayers() {
      const loader = game.sound.children.find(c => c.status !== undefined && c.item !== undefined)
      if (!loader || !loader.item) return 0
      // MediaPlayer.PlayingState, and the critters' clock counts as playing
      return loader.item.data.filter(d => d.playbackState === 1).length + (loader.item.crittersOn ? 1 : 0)
    }
    function init() { verify(game.settings.muted, "the game is muted"); compare(playingPlayers(), 0, "no music plays") }
    function cleanup() { verify(game.settings.muted, "the game is still muted"); compare(playingPlayers(), 0, "no music plays") }

    function keys(list) { for (const k of list) { keyClick(k); wait(0) } }

    function test_1_menu_to_tutorial() {
      game.forceActiveFocus()
      compare(game.screen, "menu")
      keyClick(Qt.Key_Return)                 // Adventure: a first visit goes straight to the first steps
      compare(game.screen, "play")
      compare(game.current.ref.kind, "tutorial")
      compare(game.current.ref.index, 0)
      tryVerify(() => game.current.session !== null, 5000)   // prepared on a worker
    }

    function test_2_solve_with_keys() {
      const sol = game.current.session.puzzle.solution
      // the board says when a move fills a pillar (Play rings its chime,
      // except on the winning move)
      opened.target = game.current.children.find(c => c.geom !== undefined && c.opened !== undefined)
      opened.clear()
      for (const m of sol) {
        keyClick(Qt.Key_1 + m.from)             // choose the pillar,
        keyClick(Qt.Key_Space)                  // lift,
        keyClick(Qt.Key_1 + m.to)
        keyClick(Qt.Key_Space)                  // and place
        tryVerify(() => !game.current.children.find(c => c.busy), 2000)
        wait(Theme.reducedMotion ? 0 : 500)
      }
      tryVerify(() => !!game.current.result, 3000)
      compare(game.current.view.moves, sol.length)
      verify(opened.count >= 1, "filling a pillar opened its flower")
      const saved = JSON.parse(memory.files["progress-app.json"])
      compare(saved.done[Store.key({ kind: "tutorial", index: 0 })].best, sol.length)
      compare(saved.current, null)
    }

    function test_3_undo_and_refuse() {
      keyClick(Qt.Key_Return)                 // Next: tutorial 2
      tryCompare(game.current.ref, "index", 1)
      tryVerify(() => game.current.session !== null, 5000)
      const before = game.current.view.moves
      keyClick(Qt.Key_3); keyClick(Qt.Key_Space)   // the empty pillar: nothing to lift
      compare(game.current.session.selected, -1)
      keyClick(Qt.Key_1)                           // a number only chooses
      compare(game.current.session.selected, -1)
      keyClick(Qt.Key_Space)
      compare(game.current.session.selected, 0)
      keyClick(Qt.Key_2); keyClick(Qt.Key_Space)   // full: refused, orb stays lifted
      compare(game.current.session.selected, 0)
      compare(game.current.view.moves, before)
      keyClick(Qt.Key_3); keyClick(Qt.Key_Space)   // legal
      compare(game.current.view.moves, before + 1)
      wait(600)
      keyClick(Qt.Key_U)
      compare(game.current.view.moves, before)
      keyClick(Qt.Key_H)
      verify(game.current.assisted)
      compare(JSON.parse(memory.files["progress-app.json"]).current.assisted, true, "the hint is saved with the game")
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
      compare(JSON.parse(memory.files["progress-app.json"]).current.ref.index, 1, "the unfinished puzzle is saved")
    }

    function test_5_reopen_after_part_of_the_tutorial() {
      // the first puzzle solved, the game closed from its results card
      const done = {}
      done[Store.key({ kind: "tutorial", index: 0 })] = { best: 3 }
      const host = hostMaker.createObject(root, { files: { "settings.json": JSON.stringify({ muted: true }), "progress-app.json": JSON.stringify({ done }) } })
      const g = gameMaker.createObject(root, { host })
      g.continueOrMap()
      compare(g.screen, "map", "a returning player is not sent back to the first steps")
      g.destroy(); host.destroy()
    }

    function test_6_a_failed_save_is_shown_and_kept() {
      memory.failWrites = true
      game.saveCurrent({ kind: "level", area: "clearing", index: 0 }, [], false)
      verify(game.saveFailed)
      game.continueOrMap()                    // reads the disk again
      compare(game.current.ref.area, "clearing", "the unsaved puzzle survives the reread")
      // settings changed while writes fail are all kept, and saved later
      game.setSetting("reducedMotion", true)
      game.setSetting("symbols", true)
      verify(game.saveFailed)
      verify(game.settings.reducedMotion && game.settings.symbols)
      memory.failWrites = false
      game.saveCurrent({ kind: "level", area: "clearing", index: 0 }, [], false)
      verify(game.saveFailed, "settings are still unsaved")
      game.setSetting("music", 0.5)
      verify(!game.saveFailed)
      const s = JSON.parse(memory.files["settings.json"])
      verify(s.reducedMotion && s.symbols)
      compare(s.music, 0.5)
      game.setSetting("reducedMotion", false); game.setSetting("symbols", false)
    }

    function test_8_a_bigger_size_keeps_its_row_in_view() {
      game.show("settings")
      const page = game.current
      const scroller = findChild(page, "scroller")
      page.cursor = page.rows.length - 1
      keyClick(Qt.Key_Right); keyClick(Qt.Key_Right); keyClick(Qt.Key_Right); keyClick(Qt.Key_Right)
      compare(game.settings.scale, 1.5)
      const row = scroller.contentItem.children[0].children.find(c => c.index === page.cursor && c.r !== undefined)
      verify(row.y >= scroller.contentY && row.y + row.height <= scroller.contentY + scroller.height + 1, "the size row is in view")
      game.setSetting("scale", 1)
      game.show("menu")
    }

    function test_9_screens_show_the_other_hosts_changes() {
      game.show("menu")
      // the plugin changed the music and finished the unfinished puzzle
      const s = JSON.parse(memory.files["settings.json"]); s.music = 0.2
      const done = JSON.parse(memory.files["progress-app.json"])
      const other = { done: done.done, current: null, currentAt: done.currentAt + 1 }
      memory.files = Object.assign({}, memory.files, { "settings.json": JSON.stringify(s), "progress-plugin.json": JSON.stringify(other) })
      game.show("settings")
      compare(game.settings.music, 0.2)
      game.show("menu")
      compare(game.progress.current, null, "no stale Continue")
    }

    function test_9b_starting_and_resuming_read_settings() {
      game.show("menu")
      const set = (layout) => {
        const s = JSON.parse(memory.files["settings.json"]); s.layout = layout
        memory.files = Object.assign({}, memory.files, { "settings.json": JSON.stringify(s) })
      }
      set("circle")
      game.start({ kind: "tutorial", index: 1 })
      compare(game.settings.layout, "circle", "start")
      tryVerify(() => game.current.session !== null, 5000)
      game.show("menu")
      set("line")
      game.continueOrMap()
      compare(game.settings.layout, "line", "resume")
      set("circle")
      tryVerify(() => game.current.session !== null, 5000)
      game.current.restart()
      compare(game.settings.layout, "circle", "restart")
      set("line")
      tryVerify(() => game.current.session !== null, 5000)
      game.show("menu")
    }

    function test_9bb_undo_during_a_flight_draws_the_engine_state() {
      game.start({ kind: "tutorial", index: 0 })
      tryVerify(() => game.current.session !== null, 5000)
      const m = game.current.session.puzzle.solution[0]
      game.current.touch(m.from); game.current.touch(m.to)
      const board = game.current.children.find(c => c.busy !== undefined && c.stack !== undefined)
      verify(board.busy || Theme.reducedMotion, "the orb is in flight")
      keyClick(Qt.Key_U)
      verify(!board.busy)
      compare(game.current.view.moves, 0)
      compare(JSON.stringify(board.stack), JSON.stringify(game.current.view.columns))
      game.show("menu")
    }

    function test_9bc_free_play_next_is_another_board() {
      for (let i = 0; i < 40; i++) {
        game.playNext({ kind: "free", difficulty: "beginner", index: 5 })
        verify(game.current.ref.index !== 5)
      }
      tryVerify(() => game.current.session !== null, 5000)
      game.show("menu")
    }

    function test_9bd_a_done_pillar_blooms_once_its_orb_lands() {
      // tutorial 1: columns [1,0] [0,1] [] (top first), capacity 2; after
      // 0->2 and 1->0, column 0 holds two 0s and is done
      game.start({ kind: "tutorial", index: 0 })
      tryVerify(() => game.current.session !== null, 5000)
      const board = game.current.children.find(c => c.bloomed !== undefined)
      game.current.touch(0); game.current.touch(2)
      tryVerify(() => !board.busy, 2000)
      compare(board.bloomed[0], false)
      game.current.touch(1); game.current.touch(0)
      compare(game.current.view.complete[0], true, "the engine says column 0 is done")
      if (!Theme.reducedMotion) compare(board.bloomed[0], false, "not before its orb lands")
      tryVerify(() => board.bloomed[0] === true, 2000)
      game.current.touch(0)
      compare(board.bloomed[0], false, "closed while its top orb is lifted")
      game.current.touch(0)
      tryVerify(() => board.bloomed[0] === true, 2000)
      const pillar = board.children.find(c => c.seed === 1)
      const opened = pillar.bloomTone.name
      keyClick(Qt.Key_U)
      compare(board.bloomed[0], false, "closed again after undo")
      compare(pillar.bloomTone.name, opened, "it closes in the colour it opened in")
      // open it again, then restart while another orb is in flight
      tryVerify(() => !board.busy, 2000)
      game.current.touch(1); game.current.touch(0)
      tryVerify(() => board.bloomed[0] === true, 2000)
      game.current.touch(1); game.current.touch(2)
      game.current.restart()
      compare(board.bloomed[0], false, "closed by the restart")
      compare(pillar.bloomTone.name, opened, "and still in its own colour")
      game.show("menu")
    }

    function test_9be_the_menu_shows_the_version() {
      game.show("menu")
      const label = findChild(game.current, "version")
      verify(!label.visible, "nothing when the host gives no version")
      memory.version = "1.2.3 · abc1234"
      compare(label.text, "v1.2.3 · abc1234")
      verify(label.visible)
      memory.version = ""
    }

    function test_9bf_redo_replays_an_undone_move() {
      game.start({ kind: "tutorial", index: 0 })
      tryVerify(() => game.current.session !== null, 5000)
      const board = game.current.children.find(c => c.bloomed !== undefined)
      const sol = game.current.session.puzzle.solution
      // every move but the winning one, then U and Ctrl+Shift+Z
      for (const m of sol.slice(0, -1)) { game.current.touch(m.from); game.current.touch(m.to); tryVerify(() => !board.busy, 2000) }
      const before = game.current.view.moves
      keyClick(Qt.Key_U)
      compare(game.current.view.moves, before - 1)
      keyClick(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier)
      tryVerify(() => !board.busy, 2000)
      compare(game.current.view.moves, before, "Ctrl+Shift+Z redid the move, and did not also undo")
      // and the game still plays on to its win
      const last = sol[sol.length - 1]
      game.current.touch(last.from); game.current.touch(last.to)
      tryVerify(() => !!game.current.won, 2000)
      game.show("menu")
    }

    function test_9bg_a_quick_touch_still_lands_the_orb_and_opens_its_flower() {
      // as in 9bd: 0->2, then 1->0 fills column 0; lifting again at once
      // must not swallow that landing (its flower, squash and chime)
      game.start({ kind: "tutorial", index: 0 })
      tryVerify(() => game.current.session !== null, 5000)
      const board = game.current.children.find(c => c.bloomed !== undefined)
      game.current.touch(0); game.current.touch(2)
      tryVerify(() => !board.busy, 2000)
      opened.target = board
      opened.clear()
      game.current.touch(1); game.current.touch(0)
      game.current.touch(1)                   // lift at once, mid-landing
      compare(opened.count, 1, "the filled pillar opened")
      compare(opened.signalArguments[0][0], 0)
      compare(board.bloomed[0], true)
      game.current.touch(1)                   // put it back: no chime
      tryVerify(() => !board.busy, 2000)
      compare(opened.count, 1, "putting an orb back opens nothing")
      game.show("menu")
    }

    function test_9bh_lifting_from_the_pillar_just_filled_still_opens_it() {
      game.start({ kind: "tutorial", index: 0 })
      tryVerify(() => game.current.session !== null, 5000)
      const board = game.current.children.find(c => c.bloomed !== undefined)
      game.current.touch(0); game.current.touch(2)
      tryVerify(() => !board.busy, 2000)
      opened.target = board
      opened.clear()
      game.current.touch(1); game.current.touch(0)   // fills column 0
      game.current.touch(0)                          // and lifts from it at once
      compare(opened.count, 1, "the filled pillar opened before the lift closed it")
      compare(board.bloomed[0], false, "closed while its top orb is lifted")
      game.current.touch(0)
      tryVerify(() => !board.busy, 2000)
      compare(opened.count, 1, "putting it back opens nothing")
      game.show("menu")
    }

    function test_9c_a_newer_save_is_never_overwritten() {
      const newer = JSON.stringify({ version: Store.VERSION + 1, music: 0.3, muted: true })
      memory.files = Object.assign({}, memory.files, { "settings.json": newer })
      game.setSetting("music", 0.9)
      compare(memory.files["settings.json"], newer)
      verify(game.newerSaves && game.saveFailed)
    }

    function test_7_a_move_after_the_clock_went_back_is_kept() {
      // the plugin saved its puzzle with a clock far ahead of this one
      const other = { done: {}, current: { ref: { kind: "tutorial", index: 2 }, moves: [], assisted: false, pack: Store.PACK }, currentAt: Date.now() + 1e9 }
      memory.files = Object.assign({}, memory.files, { "progress-plugin.json": JSON.stringify(other) })
      game.saveCurrent({ kind: "level", area: "river", index: 3 }, [], false)
      compare(JSON.parse(memory.files["progress-app.json"]).current.ref.area, "river")
    }
  }
}
