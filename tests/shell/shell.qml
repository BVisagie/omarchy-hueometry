import QtQuick
import Quickshell
import "plugin" as P

// Runs the plugin's overlay in a separate Quickshell instance, with a
// stand-in qs.Ui, and checks the game gets its host, loads its settings and
// saves into XDG_DATA_HOME. Run by tools/check/overlay.sh.
ShellRoot {
  P.Overlay { id: overlay; manifest: ({ id: "io.github.bvisagie.hueometry" }) }
  Timer { interval: 300; running: true; onTriggered: { overlay.open("{}"); later.start() } }
  Timer {
    id: later
    interval: 800
    onTriggered: {
      const window = overlay.children.find(c => c.shown !== undefined)
      const game = window.children[0].item
      const ok = !!game && !!game.host && game.host.kind === "plugin" && game.screen === "menu" && game.settings.music >= 0
      if (ok) game.start({ kind: "tutorial", index: 0 })
      console.log("OVERLAY " + (ok ? "ok" : "broken"))
      Qt.quit()
    }
  }
}
