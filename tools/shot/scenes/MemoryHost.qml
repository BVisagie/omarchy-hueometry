import QtQuick

// A host that keeps saves in memory, for previews and screenshots.
QtObject {
  property string kind: "app"
  property bool canFullscreen: false
  property var files: ({})
  function readText(name) { return files[name] || "" }
  function writeText(name, text) { const f = Object.assign({}, files); f[name] = text; files = f; return true }
  function quit() {}
  function toggleFullscreen() {}
}
