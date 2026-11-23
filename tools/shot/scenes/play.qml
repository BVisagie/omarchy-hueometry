import QtQuick
import "../../../qml/Hueometry"

// A level being played: words after the output name choose the layout
// ("circle"), symbols ("symbols") and how far to go ("lifted", "flying",
// "hint", "solved", "refused").
Item {
  id: root
  width: 1920; height: 1080
  readonly property var args: Qt.application.arguments
  function has(a) { return args.indexOf(a) >= 0 }

  function first() {
    const p = g.current
    if (has("solved")) {
      for (const m of p.session.puzzle.solution) { p.touch(m.from); p.touch(m.to) }
    } else if (has("hint")) {
      p.askHint()
    } else if (has("lifted") || has("flying") || has("refused")) {
      p.touch(0)
    }
  }

  function second() {
    if (has("flying")) g.current.touch(6)
    if (has("refused")) g.current.touch(1)
  }

  Game {
    id: g
    anchors.fill: parent
    host: MemoryHost { files: ({ "settings.json": JSON.stringify({ muted: true, layout: root.has("circle") ? "circle" : "line", symbols: root.has("symbols") }) }) }
    Component.onCompleted: {
      const areas = ["clearing", "river", "ruins", "waterfall", "temple", "heart"]
      const pick = areas.find(a => root.has(a)) || "temple"
      g.start(root.has("solved") ? { kind: "tutorial", index: 0 } : { kind: "level", area: pick, index: 2 })
    }
  }

  SequentialAnimation {
    running: true
    PauseAnimation { duration: 200 }
    ScriptAction { script: root.first() }
    PauseAnimation { duration: 300 }
    ScriptAction { script: root.second() }
  }
}
