"""The Quest room path on Meta XR Simulator: what PassthroughReality reads from a
room scan, and which surface the toys go on. Run: python tools/xrsim.py test"""

import math
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import xrsim  # noqa: E402
from xrsim import plane, room, volume  # noqa: E402

FLOOR = plane("FLOOR", (0, -1.15, -0.5), (4, 4))
CEILING = plane("CEILING", (0, 1.25, -0.5), (4, 4), facing="down")
HEAD_START = (0.0, 1.7, 0.0)  # where the simulator puts the eyes; room positions are relative to it


def world(sim):
    """A simulator-space point where the app sees it."""
    return tuple(s + h for s, h in zip(sim, (0.0, HEAD_START[1], 0.0)))


@unittest.skipUnless(xrsim.available(), "Meta XR Simulator is not installed")
class Room(unittest.TestCase):
    def play(self, *things, name):
        notes, errors = xrsim.run(room(*things) if things else None, seconds=6, name=name)
        self.assertEqual(errors, [], "no script errors")
        return notes

    def ready(self, notes):
        return next(n["data"] for n in notes if n["what"] == "room_ready")

    def surfaces(self, notes, kind):
        return [n["data"] for n in notes if n["what"] == "room_surface" and n["data"]["kind"] == kind]

    def assert_near(self, actual, expected, tolerance=0.01, what=""):
        self.assertLess(math.dist(actual, expected), tolerance, f"{what}: {actual} vs {expected}")

    def test_a_desk_in_front_is_the_work_surface(self):
        notes = self.play(FLOOR, CEILING, plane("TABLE", (0, -0.42, -0.55), (1.2, 0.7)), name="desk")
        ready = self.ready(notes)
        self.assert_near(ready["head"], HEAD_START, what="the eyes start where the room expects")
        surface = ready["work_surface"]
        self.assertTrue(surface["scanned"] and surface["kind"] == "table", surface)
        self.assert_near(surface["centre"], world((0, -0.42, -0.55)), what="on the table top")
        self.assert_near(surface["normal"], (0, 1, 0), what="facing up")
        self.assert_near(surface["size"], (1.2, 0.7), what="its width and depth")
        self.assertEqual(len(self.surfaces(notes, "floor")), 1)
        self.assertFalse(any(n["what"] == "room_missing" for n in notes), "the room was read: no scan asked for")

    def test_a_desk_scanned_as_a_box_uses_its_top(self):
        notes = self.play(FLOOR, CEILING, volume("TABLE", (0, -1.15, -0.55), (1.2, 0.7, 0.73)), name="desk_box")
        surface = self.ready(notes)["work_surface"]
        self.assertTrue(surface["scanned"], surface)
        self.assert_near(surface["centre"], world((0, -1.15 + 0.73, -0.55)), what="the top face, not the middle")
        self.assert_near(surface["normal"], (0, 1, 0), what="facing up")
        self.assert_near(surface["size"], (1.2, 0.7), what="its width and depth")

    def test_a_turned_desk_keeps_its_size_and_faces_up(self):
        notes = self.play(FLOOR, CEILING, plane("TABLE", (0.2, -0.42, -0.6), (1.2, 0.7), yaw=35), name="desk_turned")
        surface = self.ready(notes)["work_surface"]
        self.assertTrue(surface["scanned"], surface)
        self.assert_near(surface["centre"], world((0.2, -0.42, -0.6)))
        self.assert_near(surface["normal"], (0, 1, 0))
        self.assert_near(surface["size"], (1.2, 0.7))

    def test_a_table_out_of_reach_leaves_the_virtual_patch(self):
        notes = self.play(FLOOR, CEILING, plane("TABLE", (0, -0.42, -2.6), (1.2, 0.7)), name="table_far")
        self.assertEqual(len(self.surfaces(notes, "table")), 1, "the table is read")
        surface = self.ready(notes)["work_surface"]
        self.assertFalse(surface["scanned"], f"but too far to play on: {surface}")

    def test_no_room_asks_for_one_scan_and_plays_on(self):
        notes = self.play(name="no_room")
        missing = [n["data"]["after_scan"] for n in notes if n["what"] == "room_missing"]
        self.assertEqual(missing[0], False, "asks for a scan")
        self.assertLessEqual(missing.count(False), 1, f"only once: {missing}")
        self.assertLessEqual(len(missing), 2, f"no loop: {missing}")
        self.assertFalse(self.ready(notes)["work_surface"]["scanned"], "the virtual patch")

    def test_metas_furnished_room(self):
        meta_room = xrsim.SIMULATOR / "config" / "anchors" / "scene_anchors_room_with_furnitures.json"
        notes, errors = xrsim.run(meta_room, seconds=6, name="meta_furnished")
        self.assertEqual(errors, [])
        tables = [n["data"] for n in notes if n["what"] == "room_surface" and n["data"]["kind"] == "table"]
        self.assertEqual(len(tables), 1)
        self.assert_near(tables[0]["normal"], (0, 1, 0), what="its table faces up")
        self.assert_near(tables[0]["size"], (0.6, 1.15), what="0.6 m wide, 1.15 m deep, as scanned")
        floor = [n["data"] for n in notes if n["what"] == "room_surface" and n["data"]["kind"] == "floor"][0]
        self.assertAlmostEqual(tables[0]["centre"][1] - floor["centre"][1], 0.911, places=2, msg="0.91 m above the floor")


if __name__ == "__main__":
    unittest.main()
