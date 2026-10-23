"""The shipped plans played end to end by a simulated child."""

import unittest

from support import Child, SimCase


class ShippedPlans(SimCase):
    def test_demo_plan_end_to_end(self):
        sim = self.launch("demo")
        child = Child(sim, body="medium", perception="typical", seed=11)
        child.play()
        observation = sim.observe()
        self.assertFalse(observation["session"]["running"])
        blocks = sim.events("block_started")
        self.assertEqual([b["info"]["trial"] for b in blocks], ["find", "find", "find", "find", "point_real", "motion"])
        self.assertEqual([b["info"]["probe"] for b in blocks], [True, False, False, False, False, False])
        ends = self.round_ends(sim)
        self.assertEqual([e["data"]["trial"] for e in ends], ["find"] * 14 + ["point_real"] * 3 + ["motion"] * 4)
        self.assertTrue(all(e["data"]["probe"] == (i < 3) for i, e in enumerate(ends)))
        self.assertTrue(all(e["data"]["level"] == 0.3 for e in ends[:3]), "the check-in runs at its fixed level")
        self.assertEqual(len(self.reports(sim, "level")), 18, "every scored training round moves the staircase")
        views = [e["data"]["view"]["title"] for e in ends]
        self.assertEqual(views, ["Normal"] * 8 + ["High contrast"] * 3 + ["Spotlight"] * 3 + ["Normal"] * 7)
        said = [e["text"] for e in sim.events("said")]
        self.assertEqual(said[0], "Hi! Let's play a seeing game.")
        self.assertEqual(said[-1], "All done. Great work today!")
        lines = self.assert_log_ok(sim)
        self.assertEqual(lines[-1]["type"], "session_end")
        self.assertEqual(sum(1 for line in lines if line["type"] == "trial_end"), 21)

    def test_motion_plan_end_to_end(self):
        sim = self.launch("motion", body="small")
        child = Child(sim, body="small", perception="typical", seed=5)
        child.play()
        ends = self.round_ends(sim)
        self.assertEqual([e["skill"] for e in ends], ["global_motion"] * 6 + ["global_motion_competing"] * 6)
        for end in ends:
            values = end["data"]["values"]
            self.assertIn(values["heading"], ["right", "left", "toward", "away"])
            self.assertEqual(values["plane"], "lateral" if values["heading"] in ("right", "left") else "depth")
            self.assertTrue(end["success"], "a child who keeps trying finds the flow")
            self.assertGreaterEqual(len(end["data"]["attempts"]), 1)
        competing = [e["data"]["values"] for e in ends[6:]]
        self.assertTrue(all(v["competing"] == 1.0 and v["coherence"] >= 0.55 for v in competing))
        hands = {a["hand"] for e in ends for a in e["data"]["attempts"]}
        self.assertEqual(hands, {"left", "right"})
        self.assert_log_ok(sim)


if __name__ == "__main__":
    unittest.main()
