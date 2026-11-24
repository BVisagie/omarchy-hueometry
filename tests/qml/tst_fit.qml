import QtQuick
import QtTest
import "../../qml/Hueometry"

// At the default interface size every screen fits the window without
// scrolling, on every common shape and size of screen (in logical pixels):
// the menu with all five buttons, free play, the map, Settings, the keys,
// a puzzle and its results card. (docs/decisions.md: every screen fits
// 52x34em at 100%.)
Item {
  id: root
  width: 1280
  height: 720

  MemoryHost { id: memory }
  Game { id: game; anchors.fill: parent; host: memory }

  TestCase {
    name: "Fit"
    when: windowShown

    readonly property var sizes: [
      [720, 540], [1024, 768], [1280, 720], [1600, 900], [1920, 1080], [1920, 1200],
      [2048, 1280], [2560, 1440], [3440, 1440], [3840, 2160],
    ]

    function initTestCase() {
      // the metrics are Nunito's, not a fallback font's
      tryVerify(() => Theme.regular.status === FontLoader.Ready && Theme.bold.status === FontLoader.Ready, 3000)
      game.setSetting("scale", 1)
      compare(game.settings.scale, 1)
      // no sound player at all, on any machine: Settings then has no note
      // that Qt Multimedia is missing (tested on its own below)
      game.sound.bankSource = ""
      verify(!game.sound.missing)
      // a build's version, as long as the menu ever shows one
      memory.version = "0.2.1 · abc1234"
    }

    // an unfinished puzzle, so the menu shows Continue as well
    function leaveOneUnfinished() {
      if (game.progress.current) return
      game.start({ kind: "level", area: "clearing", index: 0 })
      tryVerify(() => game.current.session !== null, 5000)
      const m = game.current.session.puzzle.solution[0]
      game.current.touch(m.from); game.current.touch(m.to)
      tryVerify(() => !!game.progress.current, 3000)
    }

    function cleanupTestCase() {
      memory.version = ""
      root.width = 1280; root.height = 720
      game.show("menu")
    }

    // every visible Flickable under `o`, the scrolling views of a screen
    function scrollers(o, out, seen) {
      if (!o || seen.indexOf(o) >= 0 || o.visible === false) return out
      seen.push(o)
      if (o.flickableDirection !== undefined && o.height > 0) out.push(o)
      for (const c of (o.children || [])) scrollers(c, out, seen)
      return out
    }

    // every visible item under `o` for which `test` is true
    function found(o, test, out, seen) {
      if (!o || seen.indexOf(o) >= 0 || o.visible === false) return out
      seen.push(o)
      if (test(o)) out.push(o)
      for (const c of (o.children || [])) found(c, test, out, seen)
      return out
    }

    function rect(item) {
      const p = item.mapToItem(game, 0, 0)
      return { x: p.x, y: p.y, w: item.width, h: item.height }
    }

    function inside(item, what) {
      const r = rect(item)
      verify(r.x >= -1 && r.y >= -1 && r.x + r.w <= game.width + 1 && r.y + r.h <= game.height + 1,
             what + " lies inside the window (" + Math.round(r.x) + "," + Math.round(r.y) + " "
             + Math.round(r.w) + "x" + Math.round(r.h) + " in " + game.width + "x" + game.height + ")")
    }

    function apart(a, b, what) {
      const r = rect(a), q = rect(b)
      verify(r.x + r.w <= q.x || q.x + q.w <= r.x || r.y + r.h <= q.y || q.y + q.h <= r.y, what)
    }

    // the screen (or `scope` on it) shows at least one view with something
    // in it, and nothing in any view needs scrolling
    function fits(what, scope) {
      wait(0)
      const views = scrollers(scope || game, [], [])
      verify(views.some(v => v.contentHeight > 0 && v.contentItem.childrenRect.height > 0), what + " shows its content")
      const over = views.filter(v => v.contentHeight > v.height + 1)
        .map(v => (v.objectName || "a view") + " by " + ((v.contentHeight - v.height) / Theme.em).toFixed(1) + "em")
      compare(over.join(", "), "", what + " fits without scrolling")
      compare(found(game, c => c.objectName === "more", [], []).length, 0, what + " shows no more cue")
    }

    function data() { return sizes.map(s => ({ tag: s[0] + "x" + s[1], w: s[0], h: s[1] })) }

    function test_screens_fit_data() { return data() }
    function test_screens_fit(d) {
      root.width = d.w; root.height = d.h
      const where = " at " + d.tag

      leaveOneUnfinished()
      game.show("menu")
      fits("the menu" + where)
      // all five buttons are drawn, through Quit, inside the window and clear
      // of the version in the corner
      const buttons = found(game.current, c => c.primary !== undefined && c.focused !== undefined && c.wide !== undefined, [], [])
      compare(buttons.map(b => b.text).join(", "), "Continue, Free play, Adventure map, Settings, Quit", "the menu's buttons" + where)
      for (const b of buttons) inside(b, b.text + where)
      const version = found(game.current, c => c.objectName === "version", [], [])[0]
      verify(!!version && version.text !== "", "the version shows" + where)
      for (const b of buttons) apart(b, version, b.text + " clears the version" + where)

      game.show("free")
      fits("free play" + where)

      game.show("map")
      fits("the map" + where)
      compare(found(game.current, c => c.open !== undefined && c.done !== undefined, [], []).length, 7, "all seven areas" + where)
      // a full area: eight puzzles
      game.current.area = 1
      game.current.depth = 1
      fits("an area's puzzles" + where)
      const stones = found(game.current, c => ("rec" in c) && c.index !== undefined, [], [])
      compare(stones.length, 8, "all eight puzzles" + where)
      for (const s of stones) inside(s, "puzzle " + (stones.indexOf(s) + 1) + where)

      game.show("settings")
      fits("Settings" + where)
      // its title clears the card
      const title = game.current.children.find(c => c.text === "Settings")
      const card = game.current.children.find(c => c.overflows !== undefined && c.radius !== undefined)
      verify(title.mapToItem(game, 0, title.height).y <= card.mapToItem(game, 0, 0).y, "the Settings title clears its card" + where)

      game.show("menu")
      game.showHelp()
      // the keys card itself, with every key's row
      const help = found(game, c => c.keys !== undefined && c.quitsAtOnce !== undefined, [], [])[0]
      verify(!!help, "the keys show" + where)
      fits("the keys" + where, help)
      const words = found(help, c => c.text !== undefined && c.font !== undefined, [], []).map(t => t.text)
      for (const k of help.keys) verify(words.indexOf(k[0]) >= 0 && words.indexOf(k[1]) >= 0, "the keys list " + k[0] + where)
      game.helpShown = false
    }

    // where a screen still scrolls (a larger interface in a small window),
    // its cues show, the wheel over a cue's strip scrolls it, and the first
    // button brings the title back
    function test_where_a_screen_scrolls_it_can_be_reached() {
      root.width = 1280; root.height = 720
      game.setSetting("scale", 1.25)
      leaveOneUnfinished()
      game.show("menu")
      wait(0)
      const view = scrollers(game.current, [], [])[0]
      verify(view.contentHeight > view.height + 1, "the menu scrolls at 125%")
      const cues = () => found(game.current, c => c.objectName === "more", [], [])
      compare(cues().map(c => c.up).join(), "false", "a cue below, none above, at the top")
      const strip = game.height - Theme.em
      mouseWheel(game, game.width / 2, strip, 0, -120)
      verify(view.contentY > 0, "the wheel over the strip scrolls the menu")
      compare(cues().map(c => c.up).sort().join(), "false,true", "cues above and below, midway")
      game.current.cursor = 4
      game.current.cursor = 0
      compare(view.contentY, 0, "the first button brings the title back")
      // Settings too: the wheel over its cue's strip scrolls its list
      game.show("settings")
      wait(0)
      const list = scrollers(game.current, [], [])[0]
      verify(list.contentHeight > list.height + 1, "Settings scrolls at 125%")
      const below = list.mapToItem(game, 0, list.height)
      mouseWheel(game, game.width / 2, below.y + Theme.em * 0.6, 0, -120)
      verify(list.contentY > 0, "the wheel over Settings' cue strip scrolls its list")
      // the card never covers the Back button, at any interface size
      for (const [w, h, scale] of [[1280, 720, 1.25], [1920, 1080, 1.5], [1024, 768, 1.25], [720, 540, 1.5], [1920, 1080, 1]]) {
        root.width = w; root.height = h
        game.setSetting("scale", scale)
        wait(0)
        const back = found(game.current, c => c.label === "Back" && c.icon === "back", [], [])[0]
        const card = game.current.children.find(c => c.overflows !== undefined && c.radius !== undefined)
        apart(back, card, "the Settings card clears Back at " + w + "x" + h + " and " + scale * 100 + "%")
      }
      root.width = 1280; root.height = 720
      game.setSetting("scale", 1)
      game.show("menu")
    }

    // with the note that sound needs Qt Multimedia, Settings may scroll, and
    // then says so
    function test_the_sound_note_scrolls_settings_with_a_cue() {
      root.width = 1920; root.height = 1080
      game.sound.bankSource = "NoSuchBank.qml"
      tryVerify(() => game.sound.missing, 3000)
      game.show("settings")
      wait(0)
      const view = scrollers(game.current, [], [])[0]
      verify(view.contentHeight > view.height + 1, "the list scrolls with the note")
      compare(found(game.current, c => c.objectName === "more", [], []).length, 1, "and shows its cue")
      game.sound.bankSource = ""
      tryVerify(() => !game.sound.missing, 3000)
      game.show("menu")
    }

    function test_a_puzzle_and_its_results_fit_data() { return data() }
    function test_a_puzzle_and_its_results_fit(d) {
      root.width = d.w; root.height = d.h
      const where = " at " + d.tag
      game.start({ kind: "level", area: "heart", index: 7 })
      tryVerify(() => game.current.session !== null, 5000)
      const page = game.current
      const board = page.children.find(c => c.geom !== undefined && c.bloomed !== undefined)
      verify(board.geom.columns.length > 0, "the board has room" + where)
      const pillars = found(board, c => c.seed !== undefined && c.px !== undefined, [], [])
      compare(pillars.length, board.geom.columns.length, "a pillar drawn for every column" + where)
      for (const p of pillars) inside(p, "pillar " + p.seed + where)
      // the results card, after solving a tutorial puzzle
      game.start({ kind: "tutorial", index: 0 })
      tryVerify(() => game.current.session !== null, 5000)
      for (const m of game.current.session.puzzle.solution) { game.current.touch(m.from); game.current.touch(m.to) }
      tryVerify(() => !!game.current.result, 5000)
      const results = game.current.children.find(c => c.result !== undefined && c.cheers !== undefined)
      verify(results.visible, "the results show" + where)
      const card = results.children.find(c => c.overflows !== undefined)
      tryVerify(() => card.scale === 1, 2000)
      inside(card, "the results card" + where)
      fits("the results card" + where)
      game.show("menu")
    }
  }
}
