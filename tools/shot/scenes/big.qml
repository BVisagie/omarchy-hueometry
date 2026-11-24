import QtQuick
import "../../../qml/Hueometry"

// Settings at 150% on a small window: the list must scroll.
Item {
  width: 1280; height: 720
  Game {
    id: g
    anchors.fill: parent
    host: MemoryHost { files: ({ "settings.json": JSON.stringify({ muted: true, scale: 1.5 }) }) }
    Component.onCompleted: g.show("settings")
  }
  SequentialAnimation {
    running: true
    PauseAnimation { duration: 100 }
    ScriptAction { script: g.current.cursor = 6 }
  }
}
