import QtQuick
import "../../../qml/Hueometry"

// Any screen: the word after the output name picks it (map, levels, free,
// settings, help).
Item {
  id: root
  width: 1920; height: 1080
  readonly property var args: Qt.application.arguments
  function has(a) { return args.indexOf(a) >= 0 }
  Game {
    id: g
    anchors.fill: parent
    host: MemoryHost { files: ({
      "settings.json": JSON.stringify({ muted: true, symbols: root.has("symbols") }),
      "progress.json": JSON.stringify({ tutorial: true, done: { "tutorial/0": { best: 3 }, "clearing/0": { best: 7 }, "clearing/1": { best: 9 }, "clearing/2": { best: 6 }, "clearing/3": { best: 8 }, "clearing/4": { best: 10 }, "river/0": { best: 15 } } })
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
