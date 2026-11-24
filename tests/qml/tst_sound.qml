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
    // each area family has its own play theme; the menu has its own
    function test_theme_follows_the_area() {
      tryVerify(() => normal.available || normal.missing, 3000)
      if (!normal.available) skip("Qt Multimedia is not installed")
      const bank = normal.children.find(c => c.item !== undefined).item
      compare(String(bank.themeSource).split("/").pop(), "music-menu.ogg")
      normal.inPlay = true
      normal.area = 2
      compare(String(bank.themeSource).split("/").pop(), "music-river.ogg")
      normal.area = 3
      compare(String(bank.themeSource).split("/").pop(), "music-temple.ogg")
      normal.area = 0
      compare(String(bank.themeSource).split("/").pop(), "music-forest.ogg")
      // muted: no critters either
      verify(!bank.crittersOn)
      normal.inPlay = false
    }
  }
}
