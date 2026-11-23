import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Ui
import "Hueometry"

// Hueometry as an Omarchy shell overlay: the same game as the standalone app,
// full screen above the desktop. It is loaded only while summoned
// (keepLoaded is off), so closing it frees everything. Saves go to the same
// XDG folders as the app, never inside this plugin's folder (the shell
// reloads a plugin when a file in its folder changes).
Item {
  id: root
  property var shell: null
  property var manifest: null
  property bool opened: false

  readonly property string pluginId: (manifest && manifest.id) || "io.github.bvisagie.hueometry"
  readonly property string home: Quickshell.env("HOME")
  readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || home + "/.local/share") + "/hueometry"
  readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/hueometry"

  function open(payloadJson) { root.opened = true }
  function close() { root.opened = false }
  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
  }
  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  FileView { id: progressFile; path: root.dataDir + "/progress.json"; blockLoading: true; atomicWrites: true; printErrors: false }
  FileView { id: settingsFile; path: root.configDir + "/settings.json"; blockLoading: true; atomicWrites: true; printErrors: false }

  // what Game.qml needs from its host
  QtObject {
    id: host
    readonly property string kind: "plugin"
    readonly property bool canFullscreen: false
    function file(name) { return name === "progress.json" ? progressFile : name === "settings.json" ? settingsFile : null }
    function readText(name) {
      const f = file(name)
      if (!f) return ""
      f.reload()
      return f.text() || ""
    }
    function writeText(name, text) {
      const f = file(name)
      if (!f) return false
      f.setText(text)
      return true
    }
    function quit() { root.dismiss() }
    function toggleFullscreen() {}
  }

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "hueometry"

    Loader {
      id: game
      anchors.fill: parent
      active: root.opened
      sourceComponent: Game { host: host }
      onLoaded: item.forceActiveFocus()
    }
  }
}
