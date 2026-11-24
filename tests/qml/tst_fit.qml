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
      root.width = 1280; root.height = 720
      game.show("menu")
    }

    // every visible Flickable under `o` whose content is taller than its view
    function overflowing(o, out, seen) {
      if (!o || seen.indexOf(o) >= 0) return out
      seen.push(o)
      if (o.visible === false) return out
      if (o.flickableDirection !== undefined && o.height > 0 && o.contentHeight > o.height + 1)
        out.push((o.objectName || "a scroller") + " by " + ((o.contentHeight - o.height) / Theme.em).toFixed(1) + "em")
      for (const c of (o.children || [])) overflowing(c, out, seen)
      return out
    }

    function inside(item, what) {
      const p = item.mapToItem(game, 0, 0)
      verify(p.x >= -1 && p.y >= -1 && p.x + item.width <= game.width + 1 && p.y + item.height <= game.height + 1,
             what + " lies inside the window (" + Math.round(p.x) + "," + Math.round(p.y) + " "
             + Math.round(item.width) + "x" + Math.round(item.height) + " in " + game.width + "x" + game.height + ")")
    }

    function fits(what) {
      wait(0)
      const over = overflowing(game, [], [])
      compare(over.join(", "), "", what + " fits without scrolling")
    }

    function data() { return sizes.map(s => ({ tag: s[0] + "x" + s[1], w: s[0], h: s[1] })) }

    function test_screens_fit_data() { return data() }
    function test_screens_fit(d) {
      root.width = d.w; root.height = d.h
      const where = " at " + d.tag

      leaveOneUnfinished()
      game.show("menu")
      compare(game.current.items.length, 5, "the menu shows all five buttons")
      fits("the menu" + where)
      // its last button (Quit) lies inside the window
      const buttons = game.current.children[0].contentItem.children[0].children[0]
      const last = buttons.children.filter(c => c.text !== undefined && c.primary !== undefined).pop()
      inside(last, "the last menu button" + where)

      game.show("free")
      fits("free play" + where)

      game.show("map")
      fits("the map" + where)
      game.current.depth = 1
      fits("an area's puzzles" + where)

      game.show("settings")
      fits("Settings" + where)
      // its title clears the card
      const title = game.current.children.find(c => c.text === "Settings")
      const card = game.current.children.find(c => c.radius !== undefined && c.border !== undefined && c.children.some(k => k.objectName === "scroller"))
      verify(title.mapToItem(game, 0, title.height).y <= card.mapToItem(game, 0, 0).y, "the Settings title clears its card" + where)

      game.show("menu")
      game.showHelp()
      fits("the keys" + where)
      game.helpShown = false
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
      for (const p of board.children.filter(c => c.seed !== undefined && c.px !== undefined)) inside(p, "pillar " + p.seed + where)
      // the results card, after solving a tutorial puzzle
      game.start({ kind: "tutorial", index: 0 })
      tryVerify(() => game.current.session !== null, 5000)
      for (const m of game.current.session.puzzle.solution) { game.current.touch(m.from); game.current.touch(m.to) }
      tryVerify(() => !!game.current.result, 5000)
      const results = game.current.children.find(c => c.result !== undefined && c.cheers !== undefined)
      wait(0)
      const r = results.childrenRect
      verify(r.x >= -1 && r.y >= -1 && r.x + r.width <= results.width + 1 && r.y + r.height <= results.height + 1,
             "the results card lies inside the window" + where)
      game.show("menu")
    }
  }
}
