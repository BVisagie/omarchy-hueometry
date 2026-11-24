import QtQuick
// A stand-in for the Omarchy shell's WidgetButton.
Item {
  property var bar: null
  property string text: ""
  property string tooltipText: ""
  signal pressed(int buttonCode)
  implicitWidth: 24
  implicitHeight: 24
}
