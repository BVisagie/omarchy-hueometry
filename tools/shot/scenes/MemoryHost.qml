import QtQuick

// A host that keeps saves in memory, for previews and screenshots.
QtObject {
  property string kind: "app"
  property bool canFullscreen: false
  // fixed, so screenshots do not change with every commit (plainly not a
  // real version, so it never needs bumping)
  property string version: "0.0.0 · preview"
  property var files: ({})
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
