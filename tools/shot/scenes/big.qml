import QtQuick
import "../../../qml/Hueometry"

// A small window at 150% interface size: the word after the output name
// picks the screen (menu, map, settings); the last item is focused.
Item {
  id: root
  width: 1280; height: 720
  readonly property var args: Qt.application.arguments
  function has(a) { return args.indexOf(a) >= 0 }
  Game {
    id: g
    anchors.fill: parent
    host: MemoryHost { files: ({
      "settings.json": JSON.stringify({ muted: true, scale: 1.5 }),
      "progress-app.json": JSON.stringify({ done: { "tutorial/0": { best: 3 } }, current: { ref: { kind: "tutorial", index: 1 }, moves: [] }, currentAt: 1 })
    }) }
    Component.onCompleted: g.show(root.has("map") ? "map" : root.has("settings") ? "settings" : "menu")
  }
  SequentialAnimation {
    running: true
    PauseAnimation { duration: 100 }
    ScriptAction { script: root.has("map") ? g.current.area = 6 : root.has("settings") ? g.current.cursor = 6 : g.current.cursor = g.current.items.length - 1 }
  }
}
