import QtQuick
import "../../../qml/Hueometry"
// The marketplace preview (plugin/preview.png, at 1280x720): a puzzle,
// all but a few moves played, so flowers are open and the board is busy.
// Words: an area (default temple), and leftN for the moves still to play.
Item {
  id: root
  width: 1280; height: 720
  readonly property var args: Qt.application.arguments
  readonly property string area: ["clearing", "river", "ruins", "waterfall", "temple", "heart"].find(a => args.indexOf(a) >= 0) || "temple"
  readonly property int remaining: { for (const a of args) if (/^left\d+$/.test(a)) return parseInt(a.slice(4)); return 4 }
  Game {
    id: g
    anchors.fill: parent
    host: MemoryHost { files: ({ "settings.json": JSON.stringify({ muted: true }) }) }
    Component.onCompleted: g.start({ kind: "level", area: root.area, index: 3 })
  }
  Timer {
    interval: 200; running: true
    onTriggered: {
      const p = g.current
      const sol = p.session.puzzle.solution
      const left = Math.max(1, Math.min(sol.length, root.remaining))
      for (let i = 0; i < sol.length - left; i++) { p.touch(sol[i].from); p.touch(sol[i].to) }
      p.focusColumn = sol[sol.length - left].from
    }
  }
}
