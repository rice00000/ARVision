"""Real objects through the Detector (sim backend): field of view, line of sight, pointing."""

import math
import unittest

from support import Child, SimCase, block, plan

VIEW_ANGLE = 45.0  # modules/cv/detector.gd view_angle
TABLE = {"cup", "apple", "book", "bottle"}


def angle(head, point):
    to = [p - e for p, e in zip(point, head["position"])]
    cos = sum(a * b for a, b in zip(to, head["forward"])) / math.sqrt(sum(a * a for a in to))
    return math.degrees(math.acos(max(-1.0, min(1.0, cos))))


class Detector(SimCase):
    def detected(self, sim, child):
        child.actor.wait(0.6)  # the detector looks twice a second
        return {d["label"] for d in sim.observe()["detections"]}

    def assert_sees(self, seen, observation):
        """Detected = inside the view cone with nothing real in the way (within half a degree of its edge)."""
        def within(margin):
            return {o["label"] for o in observation["real_objects"]
                    if angle(observation["head"], o["centre"]) <= VIEW_ANGLE + margin and o["clear"]}
        self.assertLessEqual(within(-0.5), seen)
        self.assertLessEqual(seen, within(0.5))

    def test_only_objects_in_the_field_of_view_are_detected(self):
        sim = self.launch(plan(block("point_real", rounds=1)))
        child = Child(sim, seed=1)
        child.actor.look_at((0.0, 0.75, -0.8))
        seen = self.detected(sim, child)
        self.assertTrue(TABLE <= seen, seen)
        self.assert_sees(seen, sim.observe())
        body = child.actor.body
        child.actor.look_at(body.world((math.sin(math.radians(75)), 0.0, -math.cos(math.radians(75)))))
        turned = self.detected(sim, child)
        self.assertFalse(TABLE & turned, f"the table is out of view: {turned}")
        self.assertIn("chair", turned)
        self.assert_sees(turned, sim.observe())

    def test_an_object_hidden_behind_another_is_not_detected(self):
        # Seated at the table's end, the bottle stands between the eyes and the cup.
        sim = self.launch(plan(block("point_real", rounds=1)), seat=(1.15, -0.8, 90), body="small")
        child = Child(sim, body="small", seed=2)
        cup = [o for o in sim.observe()["real_objects"] if o["label"] == "cup"][0]
        child.actor.look_at(tuple(cup["centre"]))
        observation = sim.observe()
        hidden = [o for o in observation["real_objects"] if o["label"] == "cup"][0]
        self.assertFalse(hidden["clear"])
        self.assertEqual(hidden["blocker"], "Bottle")
        self.assertLess(angle(observation["head"], cup["centre"]), 5.0, "the child looks straight at it")
        seen = self.detected(sim, child)
        self.assertNotIn("cup", seen)
        self.assertIn("bottle", seen)
        child.actor.lean((0.1, 0.0, 0.0), tuple(cup["centre"]))  # lean right, around the bottle
        seen = self.detected(sim, child)
        self.assertIn("cup", seen)
        self.assert_sees(seen, sim.observe())

    def test_pointing_at_the_named_object_succeeds_and_at_another_fails(self):
        sim = self.launch(plan(block("point_real", rounds=3)))
        child = Child(sim, seed=3)
        child.play(scripts={"point_real": ["wrong", "right"]})
        ends = self.round_ends(sim)
        self.assertTrue(all(e["success"] and e["data"]["tries"] == 1 for e in ends))
        for end in ends:
            attempts = end["data"]["attempts"]
            self.assertEqual(len(attempts), 2)
            self.assertGreater(attempts[0]["angle"], end["data"]["values"]["tolerance"])
            self.assertLessEqual(attempts[1]["angle"], end["data"]["values"]["tolerance"])
            self.assertEqual(end["data"]["object"], end["data"]["values"]["object"])
        objects = [e["data"]["object"] for e in ends]
        self.assertTrue(all(a != b for a, b in zip(objects, objects[1:])), f"not the same object twice: {objects}")
        self.assertEqual([f["kind"] for f in sim.events("feedback")], ["bad", "good"] * 3)
        self.assertTrue(any(e["text"].startswith("Not quite. Find the ") for e in sim.events("said")))
        self.assert_log_ok(sim)

    def test_help_marks_the_object_then_says_where(self):
        sim = self.launch(plan(block("point_real", rounds=1)))
        child = Child(sim, seed=4)
        started = sim.run_until("trial_started")
        child.actor.wait(0.6)
        child.actor.help()
        observation = sim.observe()
        named = [o for o in observation["real_objects"] if o["label"] == observation["stimuli"]["named"]][0]
        markers = observation["stimuli"]["markers"]
        self.assertEqual(len(markers), 1, "hint 1: a marker")
        offset = [m - c for m, c in zip(markers[0]["position"], named["centre"])]
        self.assertLess(abs(offset[0]) + abs(offset[2]), 1e-3, "right above the object")
        self.assertTrue(0.19 <= offset[1] <= 0.26, offset)
        child.actor.help()
        self.assertRegex(sim.events("said")[-1]["text"], r"^The .+ is on your (left|right|front)\.$")
        child.play_round(started, ["right"])
        self.assertEqual(sim.observe()["stimuli"]["markers"], [], "the marker goes with the round")
        self.assertEqual(self.round_ends(sim)[0]["data"]["hint"], 2)

    def test_nothing_in_view_asks_the_child_to_look_around(self):
        # Turned away from the table: the guide waits until the camera sees something.
        sim = self.launch(plan(block("point_real", rounds=1)), seat=(0.0, 0.0, 100))
        child = Child(sim, seed=5)
        started = sim.run_until("trial_started")
        self.assertEqual(sim.events("said")[-1]["text"], "Look around the room.")
        self.assertEqual(sim.observe()["stimuli"]["named"], "")
        child.play_round(started, ["right"])
        end = self.round_ends(sim)[0]
        self.assertTrue(end["success"])
        self.assertIn(end["data"]["object"], {o["label"] for o in sim.observe()["real_objects"]})
        named = [e["text"] for e in sim.events("said") if e["text"].startswith("Point at the ")]
        self.assertEqual(len(named), 1)

    def test_seated_facing_an_empty_room_the_round_times_out(self):
        sim = self.launch(plan(block("point_real", rounds=1)), seat=(0.0, 0.0, 180))
        child = Child(sim, seed=6)
        started = sim.run_until("trial_started")
        child.play_round(started, ["freeze"])
        end = self.round_ends(sim)[0]
        self.assertTrue(end["data"]["timed_out"])
        self.assertNotIn("object", end["data"]["values"])
        self.assertEqual([e["text"] for e in sim.events("said", since=started["seq"])],
                         ["Look around the room."] * 2, "both hints can only say look around")
        self.assertEqual(sim.events("feedback"), [], "no hint mark without an object")


if __name__ == "__main__":
    unittest.main()
