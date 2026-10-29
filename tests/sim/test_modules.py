"""Unplugging modules on the real app (the launch option deletes their nodes before boot)."""

import unittest

from support import Child, Facilitator, SimCase, block, plan

SHORT = plan(block("find", rounds=2), block("point_real", rounds=1), block("motion", rounds=1))


class Unplugged(SimCase):
    def test_without_the_detector_the_cv_block_is_skipped(self):
        sim = self.launch("demo", unplug=["Detector"])
        observation = sim.observe()
        self.assertNotIn("Detector", observation["modules"])
        Child(sim, seed=1).play()
        self.assertEqual(self.reports(sim, "block_skipped"), [{"trial": "point_real", "missing": ["Detector"]}])
        ends = self.round_ends(sim)
        self.assertEqual(len(ends), 18)
        self.assertNotIn("point_real", {e["data"]["trial"] for e in ends})
        self.assertEqual([b["info"]["trial"] for b in sim.events("block_started")], ["find"] * 4 + ["motion"])
        self.assertEqual(sim.observe()["detections"], [])
        self.assert_log_ok(sim)

    def test_without_voice_sessions_still_run(self):
        sim = self.launch(SHORT, unplug=["Voice"])
        self.assertIsNone(sim.observe()["subtitle"])
        child = Child(sim, seed=2)
        self.assertFalse(child.hears)
        child.play()
        self.assertEqual(len(sim.events("session_finished")), 1)
        self.assertEqual([e["data"]["trial"] for e in self.round_ends(sim)], ["find", "find", "point_real", "motion"])
        self.assertTrue(sim.events("said"), "the guide still speaks on the bus; nobody voices it")
        self.assert_log_ok(sim)

    def test_without_feedback_sessions_still_run(self):
        sim = self.launch(SHORT, unplug=["Feedback"])
        Child(sim, seed=3).play()
        self.assertEqual(len(self.round_ends(sim)), 4)
        self.assertTrue(sim.events("feedback"), "judgements still go out; nothing shows them")
        self.assert_log_ok(sim)

    def test_without_the_facilitator_menu_does_nothing(self):
        sim = self.launch(plan(block("find", rounds=1)), unplug=["Facilitator"])
        sim.run_until("trial_started")
        Facilitator(sim).toggle()
        observation = sim.observe()
        self.assertFalse(observation["paused"])
        self.assertIsNone(observation["facilitator"])
        self.assertEqual(sim.events("facilitator_toggled"), [])

    def test_everything_optional_unplugged(self):
        sim = self.launch("demo", unplug=["Voice", "Feedback", "Detector", "Facilitator", "Magic", "Picks"])
        self.assertEqual(sim.observe()["modules"], [])
        Child(sim, perception="strong", seed=4).play()
        self.assertEqual(len(self.round_ends(sim)), 18)
        self.assert_log_ok(sim)


if __name__ == "__main__":
    unittest.main()
