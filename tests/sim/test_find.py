"""Find it on the real table: the layout the child sees, touching, and the virtual patch."""

import math
import unittest

from support import Child, ConstraintError, SimCase, block, plan


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
        self.assertAlmostEqual(eye[2] - surface["position"][2], 0.45, places=4)
        for toy in observation["stimuli"]["targets"]:
            self.assertAlmostEqual(toy["position"][1], eye[1] - 0.4 + 0.035, places=4)
        child.play_round(started, ["right"])
        self.assertTrue(self.round_ends(sim)[0]["success"])


if __name__ == "__main__":
    unittest.main()
