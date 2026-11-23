import QtQuick
import "../../../qml/Hueometry"

Item {
  width: 1920; height: 1080
  Game { anchors.fill: parent; host: MemoryHost { files: ({ "settings.json": JSON.stringify({ muted: true }) }) } }
}
