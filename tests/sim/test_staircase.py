"""The 2-up / 1-down staircase: what moves it and what never does."""

import unittest

from support import Child, SimCase, block, plan

START = 0.3  # core/profile.gd START_LEVEL
STEP = 0.1


class Staircase(SimCase):
    def test_probe_rounds_never_move_the_level(self):
        sim = self.launch(plan(block("find", rounds=4, probe=True, difficulty=0.5)))
        child = Child(sim, seed=1)
        child.play(scripts={("find", 0): ["right"], ("find", 1): ["wrong", "right"],
                            ("find", 2): ["help", "wrong", "help", "right"], ("find", 3): ["wrong", "wrong", "right"]})
        ends = self.round_ends(sim)
        self.assertEqual(len(ends), 4)
        self.assertTrue(all(e["data"]["probe"] and e["data"]["level"] == 0.5 for e in ends))
        self.assertEqual([e["data"]["hint"] for e in ends], [0, 0, 0, 0], "no help in a check-in, even when asked")
        self.assertEqual(len(self.reports(sim, "help_asked")), 2, "the asking is still logged")
        self.assertEqual(self.reports(sim, "hint"), [])
        self.assertEqual(self.reports(sim, "level"), [])
        self.assertEqual(sim.observe()["levels"], {"objects_in_clutter": START})
        self.assert_log_ok(sim)

    def test_only_first_try_unaided_rounds_count_as_right(self):
        sim = self.launch(plan(block("find", rounds=6)))
        child = Child(sim, seed=2)
        child.play(scripts={("find", 0): ["right"], ("find", 1): ["right"], ("find", 2): ["wrong", "right"],
                            ("find", 3): ["help", "right"], ("find", 4): ["right"], ("find", 5): ["right"]})
        ends = self.round_ends(sim)
        self.assertTrue(all(e["success"] for e in ends), "every round ends solved")
        self.assertEqual([e["data"]["first_try"] for e in ends], [True, True, False, False, True, True])
        levels = self.reports(sim, "level")
        self.assertEqual([lv["first_try"] for lv in levels], [e["data"]["first_try"] for e in ends])
        afters = [round(lv["after"], 6) for lv in levels]
        self.assertEqual(afters, [0.3, 0.4, 0.3, 0.2, 0.2, 0.3], "two in a row step up, any miss steps down")
        self.assertEqual([round(e["data"]["level"], 6) for e in ends], [0.3, 0.3, 0.4, 0.3, 0.2, 0.2],
                         "each round runs at the level the previous one left")
        self.assertEqual([round(e["data"]["values"]["clutter"], 6) for e in ends],
                         [round(2 + 7 * e["data"]["level"], 6) for e in ends], "the level drives clutter only")
        self.assertEqual(len(ends[2]["data"]["picks"]), 2, "the wrong pick and the right one are logged")
        self.assertEqual(ends[2]["data"]["picks"][-1], ends[2]["data"]["values"]["target"])
        self.assert_log_ok(sim)

    def test_a_fixed_difficulty_block_leaves_the_staircase_alone(self):
        sim = self.launch(plan(block("find", rounds=3, difficulty=0.6)))
        Child(sim, seed=3).play(scripts={"find": ["wrong", "right"]})
        self.assertTrue(all(abs(e["data"]["level"] - 0.6) < 1e-6 for e in self.round_ends(sim)))
        self.assertEqual(self.reports(sim, "level"), [])
        self.assertEqual(sim.observe()["levels"]["objects_in_clutter"], START)

    def test_a_strong_child_climbs_and_a_weak_one_descends(self):
        finals = {}
        for perception in ("strong", "weak"):
            sim = self.launch(plan(block("find", rounds=14)), profile=f"test_sim_climb_{perception}")
            Child(sim, perception=perception, seed=7).play()
            levels = self.reports(sim, "level")
            self.assertEqual(len(levels), 14)
            finals[perception] = levels[-1]["after"]
            self.assert_log_ok(sim)
        self.assertGreaterEqual(finals["strong"], START + 3 * STEP - 1e-6, finals)
        self.assertLessEqual(finals["weak"], START - 2 * STEP + 1e-6, finals)

    def test_a_strong_child_reaches_harder_motion(self):
        sim = self.launch(plan(block("motion", rounds=8, pause_between=2.0)), body="large")
        Child(sim, body="large", perception="strong", seed=4).play()
        ends = self.round_ends(sim)
        coherence = [e["data"]["values"]["coherence"] for e in ends]
        self.assertLess(coherence[-1], coherence[0], "coherence falls as the level rises")
        self.assertGreater(self.reports(sim, "level")[-1]["after"], START)


if __name__ == "__main__":
    unittest.main()
