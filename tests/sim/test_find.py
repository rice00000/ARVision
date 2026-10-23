"""Find it on the real table: the layout the child sees, touching, and the virtual patch."""

import math
import unittest

from support import Child, ConstraintError, SimCase, block, plan


def rise(head, point):
    """Degrees `point` sits above the gaze, in the child's view."""
    relative = [p - e for p, e in zip(point, head["position"])]
    y, z = (sum(a * b for a, b in zip(relative, head[axis])) for axis in ("y", "z"))
    return math.degrees(math.atan2(y, -z))


ROUND = {"cup", "bottle", "apple", "vase"}  # cylinders and balls in the simulated room


def footprint_gap(point, thing):
    """Metres from `point` to the edge of `thing`'s footprint on the table (negative inside)."""
    dx, dz = (abs(point[i] - thing["centre"][i]) for i in (0, 2))
    if thing["label"] in ROUND:
        return math.hypot(dx, dz) - thing["extent"][0] / 2
    ex, ez = thing["extent"][0] / 2, thing["extent"][2] / 2
    if dx < ex and dz < ez:
        return -min(ex - dx, ez - dz)
    return math.hypot(max(dx - ex, 0.0), max(dz - ez, 0.0))


class FindIt(SimCase):
    def test_toys_lie_on_the_table_as_the_condition_says(self):
        sim = self.launch(plan(block("find", rounds=4, difficulty=0.6)))
        child = Child(sim, seed=1)
        seeds = set()
        for _ in range(4):
            started = sim.run_until("trial_started")
            observation = sim.observe()
            values = started["condition"]["values"]
            surface = observation["work_surface"]
            toys = observation["stimuli"]["targets"]
            self.assertEqual(surface["kind"], "table")
            self.assertEqual(len(toys), int(values["clutter"]) + 1)
            self.assertEqual(values["toys"], len(toys))
            self.assertEqual(sum(t["id"].endswith("_" + values["target"]) for t in toys), 1, "one toy of the named shape")
            for toy in toys:
                local = [sum((toy["position"][i] - surface["position"][i]) * surface[axis][i] for i in range(3))
                         for axis in ("x", "y", "z")]
                self.assertAlmostEqual(local[1], values["size"] / 2, places=4)
                self.assertLessEqual(abs(local[0]), surface["size"][0] / 2 - values["size"] + 1e-6)
                self.assertLessEqual(abs(local[2]), surface["size"][1] / 2 - values["size"] + 1e-6)
            gaps = [math.dist(a["position"], b["position"]) for i, a in enumerate(toys) for b in toys[i + 1:]]
            self.assertGreaterEqual(min(gaps), values["size"] * values["spacing"] - 1e-6)
            seeds.add(values["seed"])
            child.play_round(started, ["right"])
        self.assertEqual(len(seeds), 4, "a new layout every round")

    def test_toys_never_stand_on_real_objects(self):
        sim = self.launch(plan(block("find", rounds=6, difficulty=1.0)))
        child = Child(sim, seed=4)
        for _ in range(6):
            started = sim.run_until("trial_started")
            observation = sim.observe()
            size = started["condition"]["values"]["size"]
            for thing in observation["real_objects"]:
                if thing["centre"][1] - thing["extent"][1] / 2 > observation["work_surface"]["position"][1] + 0.01:
                    continue  # not standing on the table
                for toy in observation["stimuli"]["targets"]:
                    self.assertGreaterEqual(footprint_gap(toy["position"], thing), size / 2 - 1e-4,
                                            f"{toy['id']} on the {thing['label']}")
            child.play_round(started, ["right"])

    def test_the_subtitle_stays_clear_of_the_toys(self):
        sim = self.launch(plan(block("find", rounds=1, difficulty=1.0)))
        child = Child(sim, seed=5)
        started = sim.run_until("trial_started")
        surface = sim.observe()["work_surface"]
        child.actor.look_at(tuple(surface["position"]))
        observation = sim.observe()
        head, subtitle = observation["head"], observation["subtitle"]
        self.assertTrue(subtitle["visible"])
        line = math.degrees(math.atan(2 * 0.0006 * 48 / 0.75))  # two subtitle lines, half above and half below
        for toy in observation["stimuli"]["targets"]:
            self.assertGreater(rise(head, subtitle["position"]) - line, rise(head, toy["position"]) + 3.0, toy["id"])
        child.actor.look_at(tuple(a + b for a, b in zip(head["position"], (0.0, 0.0, -2.0))))
        observation = sim.observe()
        up = [s - e for s, e in zip(observation["subtitle"]["position"], observation["head"]["position"])]
        self.assert_close(math.degrees(math.asin(up[1] / math.hypot(*up))), 20.0, 0.5, "looking ahead: over the horizon")
        child.play_round(started, ["right"])

    def test_touching_a_toy_in_reach_counts_like_pointing(self):
        sim = self.launch(plan(block("find", rounds=10)), seat=(0.0, -0.1, 0), body="large")
        child = Child(sim, body="large", seed=2)
        touched = pointed = 0
        while True:
            started = sim.run_until("trial_started", "session_finished")
            if started["event"] == "session_finished":
                break
            target, _ = child.toys(started, sim.observe())
            try:
                child.actor.body.check_reach("right", tuple(target["centre"]), comfortable=True)
                child.play_round(started, ["touch"])
                self.assertEqual(sim.events("touched")[-1]["target"], target["id"])
                touched += 1
            except ConstraintError:
                child.play_round(started, ["right"])
                pointed += 1
        self.assertTrue(all(e["success"] and e["data"]["first_try"] for e in self.round_ends(sim)))
        self.assertGreater(touched, 0, "some named toys lay within reach")
        self.assertEqual(touched + pointed, 10)

    def test_without_a_table_in_reach_toys_go_on_a_patch_in_front(self):
        sim = self.launch(plan(block("find", rounds=1)), seat=(0.0, 1.0, 0))
        child = Child(sim, seed=3)
        started = sim.run_until("trial_started")
        observation = sim.observe()
        surface = observation["work_surface"]
        eye = observation["head"]["position"]
        self.assertEqual([round(v, 5) for v in surface["size"]], [0.8, 0.5])
        self.assertAlmostEqual(surface["position"][1], eye[1] - 0.4, places=4)
        self.assertAlmostEqual(eye[2] - surface["position"][2], 0.4, places=4)
        for toy in observation["stimuli"]["targets"]:
            self.assertAlmostEqual(toy["position"][1], eye[1] - 0.4 + 0.035, places=4)
        child.play_round(started, ["right"])
        self.assertTrue(self.round_ends(sim)[0]["success"])


if __name__ == "__main__":
    unittest.main()
