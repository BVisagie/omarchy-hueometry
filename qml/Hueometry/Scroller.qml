import QtQuick

// Holds a screen's content centred when it fits, and lets it scroll when the
// interface is large on a small screen. Then it keeps a strip at its foot
// for a "more" cue, so the cue never covers what scrolls; show(item) keeps
// the focused item in view for keyboard players.
Item {
  id: root
  default property alias content: inner.data
  // taller than the space: the view gives up its foot to the cue
  readonly property bool overflows: inner.childrenRect.height > height + 1

  function show(item) {
    if (!item) return
    const top = item.mapToItem(inner, 0, 0).y + inner.y
    if (top < f.contentY) f.contentY = Math.max(0, top - Theme.em * 0.5)
    else if (top + item.height > f.contentY + f.height) f.contentY = Math.min(f.contentHeight - f.height, top + item.height - f.height + Theme.em * 0.5)
  }

  Flickable {
    id: f
    anchors.fill: parent
    anchors.bottomMargin: root.overflows ? Theme.em * 1.9 : 0
    clip: true
    contentWidth: width
    contentHeight: Math.max(height, inner.childrenRect.height)
    boundsBehavior: Flickable.StopAtBounds

    Item {
      id: inner
      width: f.width
      height: childrenRect.height
      y: Math.max(0, (f.height - childrenRect.height) / 2)
    }
  }

  MoreCue {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Theme.em * 0.25
    visible: root.overflows && !f.atYEnd
  }
}
