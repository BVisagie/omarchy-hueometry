import QtQuick
import Quickshell
import "plugin" as P

// Runs the plugin's overlay in a separate Quickshell instance, with a
// stand-in qs.Ui, and checks the game gets its host, loads its settings and
// saves into XDG_DATA_HOME, and that the bar widget loads. Run by
// tools/check/overlay.sh.
ShellRoot {
  // overlay.sh writes in the assembled manifest's version, as the shell
  // passes the whole manifest
  P.Overlay { id: overlay; manifest: ({ id: "io.github.bvisagie.hueometry", version: "@MANIFEST_VERSION@" }) }
  P.BarWidget { id: orb }
  Timer { interval: 300; running: true; onTriggered: { overlay.open("{}"); later.start() } }
  Timer {
    id: later
    interval: 800
    onTriggered: {
      const window = overlay.children.find(c => c.shown !== undefined)
      const game = window.children[0].item
      const ok = !!game && !!game.host && game.host.kind === "plugin" && game.screen === "menu" && game.settings.muted === true
        && orb.moduleName === "io.github.bvisagie.hueometry"
        && game.host.version.indexOf("@MANIFEST_VERSION@") === 0
      if (!ok) { console.log("OVERLAY broken"); Qt.quit(); return }
      game.start({ kind: "tutorial", index: 0 })
      started.game = game
      started.start()
    }
  }
  // the puzzle is prepared on a worker; wait for it to be saved
  Timer {
    id: started
    property var game: null
    property int tries: 0
    interval: 100
    repeat: true
    onTriggered: {
      tries += 1
      if (game.current && game.current.session) { console.log("OVERLAY ok"); Qt.quit() }
      else if (tries > 100) { console.log("OVERLAY broken: no puzzle"); Qt.quit() }
    }
  }
}
