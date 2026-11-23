import QtQuick
import QtTest
import "../../qml/Hueometry/js/levels.mjs" as Levels
import "../../qml/Hueometry/js/free.mjs" as Free

// Qt's engine imports the level pack modules the game ships.
TestCase {
  name: "Levels"

  function test_pack_loads() {
    compare(Levels.default.areas.length, 6)
    compare(Levels.default.tutorial.length, 3)
    verify(Free.default.puzzles.expert.puzzles.length >= 16)
  }
}
