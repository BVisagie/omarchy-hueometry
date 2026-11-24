import QtQuick
import QtQuick.Window
import "../qml/Hueometry"

// The standalone app's window. It opens full screen (a tiled window would be
// too small to play in); F11 switches.
Window {
  id: win
  title: "Hueometry"
  width: 1600
  height: 900
  // the smallest size every screen is checked at, up to 150% interface size
  // (docs/decisions.md); the plugin always fills a monitor
  minimumWidth: 720
  minimumHeight: 540
  visible: true
  visibility: Window.FullScreen
  color: "#0A1A10"

  QtObject {
    id: gameHost
    readonly property string kind: "app"
    readonly property bool canFullscreen: true
    // "0.1.0", or "0.1.0 · 9323709" for a build that is not the release
    readonly property string version: Qt.application.version + (appBuild ? " · " + appBuild : "")
    function readText(name) { return appHost.readText(name) }
    function writeText(name, text) { return appHost.writeText(name, text) }
    function quit() { Qt.quit() }
    function toggleFullscreen() { win.visibility = win.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen }
  }

  Game {
    anchors.fill: parent
    host: gameHost
    focus: true
  }
}
