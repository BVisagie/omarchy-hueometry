import QtQuick

// The backdrop: the Lost Jungle Temple, one look per area. (Checkpoint 4
// replaces this with the full drawn scene.)
Item {
  id: root
  property int area: 0
  property bool restored: false

  Rectangle {
    anchors.fill: parent
    gradient: Gradient {
      GradientStop { position: 0.0; color: "#1D4A2C" }
      GradientStop { position: 0.55; color: "#123321" }
      GradientStop { position: 1.0; color: "#0A1A10" }
    }
  }
}
