import QtQuick
import "../../../qml/Hueometry"

// A small window at 150% interface size: the word after the output name
// picks the screen (menu, map, free, settings, play, solved); the last item
// is focused.
Item {
  id: root
  width: 1280; height: 720
  readonly property var args: Qt.application.arguments
  function has(a) { return args.indexOf(a) >= 0 }
  Game {
    id: g
    anchors.fill: parent
    host: MemoryHost { files: ({ "settings.json": JSON.stringify({ muted: true, scale: 1.5 }) }) }
    Component.onCompleted: {
      if (root.has("play") || root.has("solved")) g.start(root.has("solved") ? { kind: "tutorial", index: 0 } : { kind: "level", area: "heart", index: 7 })
      else g.show(root.has("map") ? "map" : root.has("free") ? "free" : root.has("settings") ? "settings" : "menu")
    }
  }
  SequentialAnimation {
    running: true
    PauseAnimation { duration: 100 }
    ScriptAction {
      script: {
        const c = g.current
        if (root.has("map")) c.area = 6
        else if (root.has("settings")) c.cursor = 6
        else if (root.has("free")) c.cursor = 4
        else if (root.has("solved")) { c.askHint(); for (const m of c.session.puzzle.solution) { c.touch(m.from); c.touch(m.to) } }
        else if (!root.has("play")) c.cursor = c.items.length - 1
      }
    }
  }
}
