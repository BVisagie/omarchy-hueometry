import QtQuick

// The celebration card after a puzzle is solved.
Item {
  id: root
  property var result: null
  property int moves: 0
  property int par: 0
  property bool hasNext: false
  property int cursor: hasNext ? 1 : 0
  signal replay()
  signal next()
  signal leave()

  readonly property var cheers: [qsTr("Wonderful!"), qsTr("You did it!"), qsTr("Brilliant sorting!"), qsTr("The temple glows!"), qsTr("Splendid!")]

  function handleKey(event) {
    switch (event.key) {
    case Qt.Key_Left: case Qt.Key_Right: case Qt.Key_Tab:
      if (hasNext) cursor = 1 - cursor
      return true
    case Qt.Key_Space: case Qt.Key_Return: case Qt.Key_Enter:
      if (cursor === 1 && hasNext) next(); else replay()
      return true
    case Qt.Key_Escape: leave(); return true
    }
    return false
  }

  Rectangle { anchors.fill: parent; color: "#66000000" }
  MouseArea { anchors.fill: parent }

  Card {
    id: card
    anchors.centerIn: parent
    width: Math.min(parent.width - Theme.em * 4, Theme.em * 30)
    height: column.implicitHeight + Theme.em * 3
    scale: root.visible ? 1 : 0.85
    Behavior on scale { NumberAnimation { duration: Theme.ms(260); easing.type: Easing.OutBack } }

    Column {
      id: column
      anchors.centerIn: parent
      width: parent.width - Theme.em * 3
      spacing: Theme.em * 0.8

      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.result ? root.cheers[(root.moves * 7) % root.cheers.length] : ""
        color: Theme.gold
        font.family: Theme.font
        font.pixelSize: Theme.em * 2.4
        font.bold: true
        style: Text.Raised
        styleColor: "#A0000000"
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        text: root.moves === 1 ? qsTr("Solved in 1 move.") : qsTr("Solved in %1 moves.").arg(root.moves)
        color: Theme.ink
        font.family: Theme.font
        font.pixelSize: Theme.em * 1.4
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        visible: text !== ""
        color: Theme.inkSoft
        font.family: Theme.font
        font.pixelSize: Theme.em * 1.1
        text: {
          if (!root.result) return ""
          const r = root.result
          // a hinted solve never replaces a best made without hints
          if (r.assisted && r.best && !r.best.assisted)
            return qsTr("You used a hint this time. Your best without hints is %1.").arg(r.best.best)
          if (r.record === "first") return root.par > 0 ? qsTr("Par for this puzzle is %1.").arg(root.par) : ""
          if (r.record === "better") return qsTr("New personal best! Your last best was %1.").arg(r.previous.best)
          if (r.record === "same") return qsTr("You matched your best of %1.").arg(r.previous.best)
          return qsTr("Your best is %1. Want to try for fewer moves?").arg(r.previous.best)
        }
      }
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: !!root.result && root.result.record === "better"
        width: badge.implicitWidth + Theme.em * 2
        height: Theme.em * 2.2
        radius: height / 2
        color: Theme.gold
        Text {
          id: badge
          anchors.centerIn: parent
          text: qsTr("New record")
          color: Theme.inkDark
          font.family: Theme.font
          font.pixelSize: Theme.em
          font.bold: true
        }
      }
      Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.em
        TextButton { text: qsTr("Play again"); icon: "restart"; wide: Theme.em * 11; focused: root.cursor === 0; onActivated: root.replay() }
        TextButton { text: qsTr("Next"); icon: "play"; wide: Theme.em * 11; primary: true; visible: root.hasNext; focused: root.cursor === 1; onActivated: root.next() }
      }
    }
  }
}
