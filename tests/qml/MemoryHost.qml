import QtQuick

// A host that keeps saves in memory, for previews and screenshots.
QtObject {
  property string kind: "app"
  property bool canFullscreen: false
  property string version: ""
  // muted, so the tests make no sound
  property var files: ({ "settings.json": JSON.stringify({ muted: true }) })
  // true to act like a full disk
  property bool failWrites: false
  function readText(name) { return files[name] || "" }
  function writeText(name, text) {
    if (failWrites) return false
    const f = Object.assign({}, files); f[name] = text; files = f; return true
  }
  function quit() {}
  function toggleFullscreen() {}
}
