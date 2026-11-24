import QtQuick
import QtTest
import "../../qml/Hueometry"

// Without its player (Qt Multimedia missing), Sound says so instead of
// failing quietly; with it, it does not.
Item {
  Sound { id: silent; bankSource: "NoSuchBank.qml"; muted: true }
  Sound { id: normal; muted: true }

  TestCase {
    name: "Sound"
    function test_missing_player_is_reported() {
      tryVerify(() => silent.missing, 3000)
      verify(!silent.available)
    }
    function test_present_player_is_not_reported() {
      tryVerify(() => normal.available || normal.missing, 3000)
      // on a machine without Qt Multimedia the real player is missing too
      compare(normal.missing, !normal.available)
    }
  }
}
