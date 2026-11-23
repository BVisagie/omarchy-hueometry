import QtQuick
import "js/session.mjs" as S
import "js/store.mjs" as Store

// The whole game, for either host. `host` provides storage and window
// control (see docs/decisions.md): readText(name), writeText(name, text),
// quit(), kind ("app" or "plugin"), canFullscreen, toggleFullscreen().
Item {
  id: root
  required property var host

  property var settings: Store.settings(host.readText("settings.json"))
  property var progress: Store.progress(host.readText("progress.json"))
  property string screen: "menu"
  property int lastArea: 1
  property bool helpShown: false
  property bool confirmQuit: false
  property alias sound: sound
  // the screen showing now, for tests and previews
  readonly property var current: screens.item

  readonly property var areas: [
    { id: "tutorial", name: qsTr("First Steps") },
    { id: "clearing", name: qsTr("Jungle Clearing") },
    { id: "river", name: qsTr("The River Crossing") },
    { id: "ruins", name: qsTr("The Ancient Ruins") },
    { id: "waterfall", name: qsTr("The Waterfall Sanctuary") },
    { id: "temple", name: qsTr("The Hidden Temple") },
    { id: "heart", name: qsTr("The Heart of the Rainforest") },
  ]
  readonly property var freeNames: ({ beginner: qsTr("Sprout"), easy: qsTr("Explorer"), medium: qsTr("Adventurer"), hard: qsTr("Temple Keeper"), expert: qsTr("Legend") })

  focus: true

  Binding { target: Theme; property: "reducedMotion"; value: root.settings.reducedMotion }
  Binding { target: Theme; property: "symbols"; value: root.settings.symbols }
  Binding { target: Theme; property: "em"; value: Math.max(11, Math.min(root.width / 52, root.height / 34)) * root.settings.scale }

  // Saving
  // ------

  function saveProgress() {
    progress = Store.merge(Store.progress(host.readText("progress.json")), progress)
    host.writeText("progress.json", JSON.stringify(progress))
  }

  function setSetting(key, value) {
    const next = Object.assign({}, settings)
    next[key] = value
    settings = Store.settings(JSON.stringify(next))
    host.writeText("settings.json", JSON.stringify(settings))
  }

  function saveCurrent(ref, moves) {
    progress = Object.assign({}, progress, { current: { ref, moves: moves.map(m => [m.from, m.to]) } })
    saveProgress()
  }

  function recordSolved(ref, moves, assisted) {
    const out = Store.solved(progress, ref, moves, assisted)
    progress = out.progress
    saveProgress()
    return out
  }

  // Places
  // ------

  function areaIndex(ref) {
    if (!ref) return lastArea
    if (ref.kind === "tutorial") return 0
    if (ref.kind === "level") return Math.max(0, S.AREAS.indexOf(ref.area) + 1)
    return { beginner: 1, easy: 2, medium: 3, hard: 4, expert: 6 }[ref.difficulty] || 1
  }

  function titleOf(ref) {
    if (ref.kind === "tutorial") return qsTr("%1 · %2 of 3").arg(areas[0].name).arg(ref.index + 1)
    if (ref.kind === "level") return qsTr("%1 · %2 of 8").arg(areas[areaIndex(ref)].name).arg(ref.index + 1)
    return qsTr("Free play · %1").arg(freeNames[ref.difficulty] || "")
  }

  function nextRef(ref) {
    if (!ref) return null
    if (ref.kind === "tutorial") return ref.index < 2 ? { kind: "tutorial", index: ref.index + 1 } : { kind: "level", area: S.AREAS[0], index: 0 }
    if (ref.kind === "level") {
      if (ref.index < 7) return { kind: "level", area: ref.area, index: ref.index + 1 }
      const a = S.AREAS.indexOf(ref.area)
      return a + 1 < S.AREAS.length && Store.areaOpen(progress, S.AREAS, a + 1, 8) ? { kind: "level", area: S.AREAS[a + 1], index: 0 } : null
    }
    return { kind: "free", difficulty: ref.difficulty, index: -1 }
  }

  function show(name) {
    helpShown = false
    screen = name
    sound.cue("select")
  }

  function start(ref) {
    lastArea = areaIndex(ref)
    screen = "play"
    screens.item.open(ref, null)
  }

  function startFree(difficulty) {
    const count = S.puzzleCount(difficulty)
    start({ kind: "free", difficulty, index: Math.floor(Math.random() * count) })
  }

  function playNext(ref) {
    const n = nextRef(ref)
    if (!n) { goBack(); return }
    if (n.kind === "free") startFree(n.difficulty)
    else start(n)
  }

  function continueOrMap() {
    const c = progress.current
    if (c && S.puzzle(c.ref)) {
      lastArea = areaIndex(c.ref)
      screen = "play"
      screens.item.open(c.ref, c.moves.map(m => ({ from: m[0], to: m[1] })))
    } else {
      show(progress.tutorial ? "map" : "map")
    }
  }

  function goBack() {
    if (helpShown) { helpShown = false; return }
    if (screen === "play") {
      const ref = screens.item.ref
      show(ref && ref.kind === "free" ? "free" : "map")
    } else if (screen === "menu") {
      quit()
    } else {
      show("menu")
    }
  }

  function showHelp() { helpShown = true }

  function quit() {
    if (host.kind === "plugin") { host.quit(); return }
    if (confirmQuit) host.quit()
    else { confirmQuit = true; quitTimer.restart() }
  }

  Timer { id: quitTimer; interval: 3000; onTriggered: root.confirmQuit = false }

  Keys.onPressed: function(event) {
    if (helpShown) { helpShown = false; event.accepted = true; return }
    if (event.key === Qt.Key_Question || (event.key === Qt.Key_Slash && (event.modifiers & Qt.ShiftModifier))) { helpShown = true; event.accepted = true; return }
    if (event.key === Qt.Key_F11 && host.canFullscreen) { host.toggleFullscreen(); event.accepted = true; return }
    if (event.key === Qt.Key_Q && !(event.modifiers & Qt.ControlModifier)) { quit(); event.accepted = true; return }
    if (screens.item && screens.item.handleKey(event)) event.accepted = true
  }

  // Scene
  // -----

  Jungle {
    anchors.fill: parent
    area: root.screen === "play" ? root.areaIndex(screens.item ? screens.item.ref : null) : root.lastArea
  }

  Loader {
    id: screens
    anchors.fill: parent
    sourceComponent: ({ menu: menuScreen, map: mapScreen, free: freeScreen, settings: settingsScreen, play: playScreen })[root.screen]
  }

  Component { id: menuScreen; Menu { game: root } }
  Component { id: mapScreen; Map { game: root } }
  Component { id: freeScreen; FreePlay { game: root } }
  Component { id: settingsScreen; Settings { game: root } }
  Component { id: playScreen; Play { game: root } }

  Help {
    anchors.fill: parent
    visible: root.helpShown
    onClosed: root.helpShown = false
  }

  // "press Q again" when quitting the app
  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Theme.em * 5
    visible: root.confirmQuit
    width: quitText.implicitWidth + Theme.em * 2
    height: Theme.em * 2.6
    radius: height / 2
    color: Theme.card
    border.color: Theme.glow
    Text {
      id: quitText
      anchors.centerIn: parent
      text: qsTr("Press Q again to quit")
      color: Theme.ink
      font.family: Theme.font
      font.pixelSize: Theme.em * 1.1
    }
  }

  Sound {
    id: sound
    music: root.settings.music
    effects: root.settings.effects
    muted: root.settings.muted
    area: root.screen === "play" ? root.areaIndex(screens.item ? screens.item.ref : null) : 0
    playing: true
  }
}
