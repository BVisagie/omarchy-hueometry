import QtQuick
import "js/session.mjs" as S
import "js/layout.mjs" as Layout

// Playing one puzzle: the board, the move count, undo, restart and hint, and
// the results when it is solved. All rule changes go through session.mjs.
Item {
  id: play
  required property var game

  property var session: null
  property var ref: null
  property bool assisted: false
  property var hint: null
  property string message: ""
  property int focusColumn: 0
  property bool confirmRestart: false
  property var result: null

  readonly property var view: session ? S.view(session) : null
  readonly property bool showPar: !!session && !!ref && ref.kind !== "tutorial"
    && !(ref.kind === "level" && (ref.area === "clearing" || ref.area === "river"))
    && !(ref.kind === "free" && (ref.difficulty === "beginner" || ref.difficulty === "easy"))

  function open(r, savedMoves) {
    const p = S.puzzle(r)
    if (!p) { game.goBack(); return }
    ref = r
    session = savedMoves ? S.resume(p, savedMoves) : S.start(p)
    assisted = false
    hint = null
    result = null
    message = r.kind === "tutorial" ? play.tutorialText(r.index) : ""
    focusColumn = 0
    confirmRestart = false
    game.saveCurrent(ref, S.history(session))
  }

  function tutorialText(i) {
    return [
      qsTr("Click a pillar to lift its top orb, then click another pillar to put it there. Make each pillar one colour!"),
      qsTr("Any orb can go on any colour. Use the empty pillar as a place to wait."),
      qsTr("Three colours now. Try to finish in as few moves as you can."),
    ][i] || ""
  }

  function touch(column) {
    if (!session || result) return
    const out = S.touch(session, column)
    session = out.state
    focusColumn = column
    hint = null
    if (out.effect.kind === "move") message = ""
    board.effect(out.effect)
    game.sound.effect(out.effect)
    if (out.effect.kind === "move") {
      game.saveCurrent(ref, S.history(session))
      if (S.view(session).solved) board.celebrating = true
    }
  }

  function cancel() {
    if (session && session.selected >= 0) touch(session.selected)
  }

  function undo() {
    if (!session || result || S.view(session).moves === 0) return
    session = S.undo(session)
    hint = null
    game.sound.cue("undo")
    game.saveCurrent(ref, S.history(session))
  }

  function restart() {
    if (!session) return
    session = S.restart(session)
    hint = null
    result = null
    confirmRestart = false
    board.celebrating = false
    game.sound.cue("restart")
    game.saveCurrent(ref, S.history(session))
  }

  function askHint() {
    if (!session || result) return
    session = S.cancel(session)
    const h = S.hint(session)
    assisted = true
    game.sound.cue("hint")
    if (h.kind === "play") {
      hint = h
      focusColumn = h.from
      message = qsTr("Try lifting from one shining pillar and placing on the other.")
    } else if (h.kind === "back") {
      hint = null
      message = h.steps === 1 ? qsTr("That way is hard. Undo 1 move to get back on track.")
                              : qsTr("That way is hard. Undo %1 moves to get back on track.").arg(h.steps)
    } else {
      hint = null
      message = qsTr("No hint here. You can always start again.")
    }
  }

  function finished() {
    if (!session || !S.view(session).solved || result) return
    const r = game.recordSolved(ref, S.view(session).moves, assisted)
    result = r
    game.sound.cue("solved")
    sparkles.burst()
  }

  function handleKey(event) {
    if (result) return results.handleKey(event)
    const order = board.geom.order
    const ctrl = event.modifiers & Qt.ControlModifier
    switch (event.key) {
    case Qt.Key_Left: case Qt.Key_Up:
      focusColumn = Layout.step(order, focusColumn, -1); return true
    case Qt.Key_Right: case Qt.Key_Down: case Qt.Key_Tab:
      focusColumn = Layout.step(order, focusColumn, 1); return true
    case Qt.Key_Space: case Qt.Key_Return: case Qt.Key_Enter:
      touch(focusColumn); return true
    case Qt.Key_Escape:
      if (session && session.selected >= 0) cancel()
      else if (confirmRestart) confirmRestart = false
      else game.goBack()
      return true
    case Qt.Key_U: undo(); return true
    case Qt.Key_Z: if (ctrl) { undo(); return true } return false
    case Qt.Key_H: askHint(); return true
    case Qt.Key_R:
      if (confirmRestart) restart()
      else { confirmRestart = true; restartTimer.restart() }
      return true
    }
    if (event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
      const c = event.key - Qt.Key_1
      if (view && c < view.columns.length) { focusColumn = c; touch(c) }
      return true
    }
    return false
  }

  Timer { id: restartTimer; interval: 3000; onTriggered: play.confirmRestart = false }

  // top bar
  Item {
    id: bar
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Theme.em
    height: Theme.em * 4.6

    Row {
      spacing: Theme.em * 0.8
      anchors.left: parent.left
      anchors.top: parent.top
      RoundButton { icon: "back"; label: qsTr("Back"); onActivated: play.game.goBack() }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -Theme.em * 0.6
        spacing: Theme.em * 0.1
        Text {
          text: play.ref ? play.game.titleOf(play.ref) : ""
          color: Theme.ink
          font.family: Theme.font
          font.pixelSize: Theme.em * 1.35
          font.bold: true
          style: Text.Raised
          styleColor: "#90000000"
        }
        Text {
          text: play.view ? (play.showPar ? qsTr("Moves: %1  ·  Par: %2").arg(play.view.moves).arg(play.session.puzzle.par)
                                          : qsTr("Moves: %1").arg(play.view.moves)) : ""
          color: Theme.inkSoft
          font.family: Theme.font
          font.pixelSize: Theme.em * 1.05
          style: Text.Raised
          styleColor: "#90000000"
        }
      }
    }

    Row {
      spacing: Theme.em * 0.8
      anchors.right: parent.right
      anchors.top: parent.top
      RoundButton { icon: "undo"; label: qsTr("Undo"); enabled: !!play.view && play.view.moves > 0; onActivated: play.undo() }
      RoundButton { icon: "restart"; label: play.confirmRestart ? qsTr("Press R") : qsTr("Hold: restart"); hold: 700; lit: play.confirmRestart; onActivated: play.restart() }
      RoundButton { icon: "hint"; label: qsTr("Hint"); onActivated: play.askHint() }
      RoundButton { icon: "help"; label: qsTr("Keys"); onActivated: play.game.showHelp() }
    }
  }

  Board {
    id: board
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: bar.bottom
    anchors.bottom: tip.top
    anchors.margins: Theme.em
    view: play.view
    pattern: play.game.settings.layout
    focusColumn: play.focusColumn
    hint: play.hint
    onTouched: function(c) { play.touch(c) }
    onCancelled: play.cancel()
    onSettled: play.finished()
  }

  // a gentle line of guidance under the board
  Rectangle {
    id: tip
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Theme.em
    width: Math.min(parent.width - Theme.em * 4, tipText.implicitWidth + Theme.em * 2.4)
    height: play.message !== "" ? tipText.implicitHeight + Theme.em * 1.2 : 0
    radius: Theme.em * 0.8
    color: Theme.card
    border.color: Theme.cardEdge
    visible: height > 0
    Text {
      id: tipText
      anchors.centerIn: parent
      width: Math.min(implicitWidth, play.width - Theme.em * 6)
      text: play.message
      wrapMode: Text.WordWrap
      horizontalAlignment: Text.AlignHCenter
      color: Theme.ink
      font.family: Theme.font
      font.pixelSize: Theme.em * 1.1
    }
  }

  Sparkles {
    id: sparkles
    anchors.fill: board
  }

  Results {
    id: results
    anchors.fill: parent
    visible: !!play.result
    result: play.result
    moves: play.view ? play.view.moves : 0
    par: play.showPar && play.session ? play.session.puzzle.par : 0
    hasNext: !!play.ref && !!play.game.nextRef(play.ref)
    onReplay: play.restart()
    onNext: play.game.playNext(play.ref)
    onLeave: play.game.goBack()
  }

  // a friend from the jungle cheers each solved puzzle
  Friend {
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.rightMargin: Theme.em * 2
    anchors.bottomMargin: -Theme.em * 0.5
    size: Math.min(play.width, play.height) * 0.26
    kind: play.ref && ["river", "waterfall", "heart"].indexOf(play.ref.area || play.ref.difficulty) >= 0 ? "frog" : "toucan"
    cheering: !!play.result
  }
}
