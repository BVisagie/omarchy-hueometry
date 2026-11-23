import QtQuick

// The main menu.
Item {
  id: menu
  required property var game
  property int cursor: 0

  readonly property var items: [
    { text: game.progress.current ? qsTr("Continue") : qsTr("Adventure"), icon: "play", act: function() { game.continueOrMap() }, primary: true },
    { text: qsTr("Free play"), icon: "play", act: function() { game.show("free") } },
    { text: qsTr("Adventure map"), icon: "settings", act: function() { game.show("map") }, hidden: !game.progress.current },
    { text: qsTr("Settings"), icon: "settings", act: function() { game.show("settings") } },
    { text: game.host.kind === "plugin" ? qsTr("Close") : qsTr("Quit"), icon: "close", act: function() { game.quit() } },
  ].filter(i => !i.hidden)

  function handleKey(event) {
    switch (event.key) {
    case Qt.Key_Up: case Qt.Key_Left: cursor = (cursor + items.length - 1) % items.length; return true
    case Qt.Key_Down: case Qt.Key_Right: case Qt.Key_Tab: cursor = (cursor + 1) % items.length; return true
    case Qt.Key_Space: case Qt.Key_Return: case Qt.Key_Enter: items[cursor].act(); return true
    case Qt.Key_Escape: game.quit(); return true
    }
    return false
  }

  Column {
    anchors.centerIn: parent
    spacing: Theme.em * 1.2
    Title {
      anchors.horizontalCenter: parent.horizontalCenter
      size: Math.min(menu.width / 7, Theme.em * 5.5)
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text: qsTr("The Lost Jungle Temple")
      color: Theme.inkSoft
      font.family: Theme.font
      font.pixelSize: Theme.em * 1.5
      font.italic: true
      style: Text.Raised
      styleColor: "#A0000000"
    }
    Item { width: 1; height: Theme.em }
    Repeater {
      model: menu.items.length
      TextButton {
        required property int index
        anchors.horizontalCenter: parent.horizontalCenter
        text: menu.items[index].text
        icon: menu.items[index].icon
        primary: !!menu.items[index].primary
        focused: menu.cursor === index
        onActivated: menu.items[index].act()
      }
    }
  }
}
