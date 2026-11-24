import QtQuick
import QtTest
import "../../qml/Hueometry"

// Every area draws its landmark; the map's still pictures never animate,
// and a moving scene does.
Item {
  id: root
  width: 640
  height: 360

  Component { id: maker; Jungle { width: 640; height: 360 } }

  TestCase {
    name: "Jungle"
    when: windowShown

    // everything under `o` that is running: animations, timers, particles
    function running(o, seen) {
      if (!o || seen.indexOf(o) >= 0) return 0
      seen.push(o)
      let n = o.running === true ? 1 : 0
      for (const c of (o.data || [])) n += running(c, seen)
      for (const c of (o.resources || [])) n += running(c, seen)
      for (const c of (o.children || [])) n += running(c, seen)
      if (o.item) n += running(o.item, seen)
      return n
    }

    function test_still_pictures_never_move() {
      for (let area = 0; area < 7; area++) {
        const j = createTemporaryObject(maker, root, { area: area, still: true })
        waitForRendering(j)
        compare(running(j, []), 0, "area " + area + " is still")
      }
    }

    function test_a_scene_moves_unless_motion_is_reduced() {
      if (Theme.reducedMotion) skip("motion is reduced on this machine")
      for (let area = 0; area < 7; area++) {
        const j = createTemporaryObject(maker, root, { area: area })
        waitForRendering(j)
        verify(running(j, []) > 0, "area " + area + " moves")
      }
    }

    // each area but the first steps has its own landmark
    function test_every_area_has_a_landmark() {
      for (let area = 1; area < 7; area++) {
        const j = createTemporaryObject(maker, root, { area: area })
        const loader = j.children.find(c => c.sourceComponent !== undefined)
        verify(loader && loader.item, "area " + area + " draws its landmark")
      }
    }
  }
}
