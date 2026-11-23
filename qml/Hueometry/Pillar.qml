import QtQuick
import QtQuick.Shapes

// A carved stone pillar, standing on its base at (x, y) of the board and
// growing in the direction of `angle` (degrees clockwise from straight up).
// Orbs are drawn by the board, on top.
Item {
  id: root
  property real px: 0
  property real py: 0
  property real w: 40
  property real h: 200
  property real angle: 0
  property bool focused: false
  property bool target: false
  property bool empty: false
  property bool hinted: false
  property real shake: 0

  width: w
  height: h
  x: px - w / 2
  y: py - h
  transformOrigin: Item.Bottom
  rotation: angle

  transform: Translate { x: root.shake }

  // where a legal move may land: a warm light rising from the base
  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    width: root.w * 1.9
    height: root.h * 1.08
    radius: width / 2
    opacity: root.target || root.hinted ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.ms(180) } }
    gradient: Gradient {
      GradientStop { position: 0.0; color: "transparent" }
      GradientStop { position: 0.6; color: Qt.alpha(root.hinted ? "#FFFFFF" : Theme.glow, 0.18) }
      GradientStop { position: 1.0; color: Qt.alpha(root.hinted ? "#FFFFFF" : Theme.glow, 0.42) }
    }
  }

  // plinth
  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    width: root.w * 1.32
    height: root.w * 0.34
    radius: height * 0.25
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: Theme.stoneDark }
      GradientStop { position: 0.35; color: Theme.stoneLight }
      GradientStop { position: 1.0; color: Theme.stoneDark }
    }
  }

  // shaft: a hollow channel the orbs sit in
  Rectangle {
    id: shaft
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.w * 0.3
    width: root.w
    height: root.h - root.w * 0.55
    radius: root.w * 0.22
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: Qt.darker(Theme.stone, 1.5) }
      GradientStop { position: 0.3; color: Theme.stoneLight }
      GradientStop { position: 0.62; color: Theme.stone }
      GradientStop { position: 1.0; color: Qt.darker(Theme.stone, 1.8) }
    }
    // the channel
    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      anchors.topMargin: root.w * 0.08
      anchors.bottomMargin: root.w * 0.08
      width: parent.width * 0.78
      radius: width * 0.45
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: "#2A2C22" }
        GradientStop { position: 0.5; color: "#3E4134" }
        GradientStop { position: 1.0; color: "#24261D" }
      }
    }
    // carved bands
    Repeater {
      model: Math.max(0, Math.floor(shaft.height / (root.w * 2.4)))
      Rectangle {
        required property int index
        x: 0
        width: shaft.width
        y: shaft.height - (index + 1) * root.w * 2.4
        height: root.w * 0.07
        color: "#30000000"
      }
    }
  }

  // capital
  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    y: 0
    width: root.w * 1.22
    height: root.w * 0.3
    radius: height * 0.3
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: Theme.stoneDark }
      GradientStop { position: 0.4; color: Theme.stoneLight }
      GradientStop { position: 1.0; color: Theme.stoneDark }
    }
  }

  // moss at the foot
  Repeater {
    model: 3
    Rectangle {
      required property int index
      x: root.w * (0.05 + index * 0.33)
      y: root.h - root.w * (0.42 + (index % 2) * 0.12)
      width: root.w * 0.42
      height: root.w * 0.22
      radius: height / 2
      color: Qt.alpha(Theme.moss, 0.85)
    }
  }

  // the empty socket glows faintly, so the spare pillar invites a bead
  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    y: root.h - root.w * 1.05
    width: root.w * 0.62
    height: width
    radius: width / 2
    visible: root.empty
    opacity: 0.55
    gradient: Gradient {
      GradientStop { position: 0.0; color: Qt.alpha(Theme.glow, 0.0) }
      GradientStop { position: 1.0; color: Qt.alpha(Theme.glow, 0.6) }
    }
  }

  // keyboard focus: a clear golden outline around the whole pillar
  Rectangle {
    anchors.fill: parent
    anchors.margins: -root.w * 0.22
    radius: root.w * 0.3
    color: "transparent"
    border.color: Theme.gold
    border.width: Math.max(3, root.w * 0.07)
    visible: root.focused
  }
}
