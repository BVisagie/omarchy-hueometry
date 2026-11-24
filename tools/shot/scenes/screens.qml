import QtQuick
import "../../../qml/Hueometry"
import "../../../qml/Hueometry/js/store.mjs" as Store

// Any screen: the word after the output name picks it (map, levels, free,
// settings, help).
Item {
  id: root
  width: 1920; height: 1080
  readonly property var args: Qt.application.arguments
  function has(a) { return args.indexOf(a) >= 0 }
  // the tutorial and some of the first two areas solved, under this pack's keys
  readonly property var done: {
    const d = {}
    const put = (ref, best) => { d[Store.key(ref)] = { best } }
    for (let i = 0; i < 3; i++) put({ kind: "tutorial", index: i }, 3 + i)
    ;[7, 9, 6, 8, 10].forEach((b, i) => put({ kind: "level", area: "clearing", index: i }, b))
    put({ kind: "level", area: "river", index: 0 }, 15)
    return d
  }
  Game {
    id: g
    anchors.fill: parent
    host: MemoryHost { files: ({
      "settings.json": JSON.stringify({ muted: true, symbols: root.has("symbols") }),
      "progress-app.json": JSON.stringify({ tutorial: true, done: root.done })
    }) }
    Component.onCompleted: {
      if (root.has("map") || root.has("levels")) g.show("map")
      if (root.has("free")) g.show("free")
      if (root.has("settings")) g.show("settings")
      if (root.has("help")) g.showHelp()
      if (root.has("levels")) { g.current.area = 1; g.current.depth = 1 }
    }
  }
}
