"""Everyday outlines: physical reach, full completion and restarting a complete desk."""
from support import Child, ConstraintError, SimCase, block, plan


class StudyDesk(SimCase):
    def test_each_body_can_reach_all_five_and_finish_the_study_sequence(self):
        for body in ("small", "medium", "large"):
            with self.subTest(body=body):
                sim = self.launch(plan(block("desk", difficulty=0.0, ray=False)),
                                  body=body, profile=f"test_sim_desk_{body}")
                child = Child(sim, body=body, seed=2)
                started = sim.run_until("trial_started")
                layout = sim.observe()["stimuli"]["layout"]
                self.assertEqual(len(layout["things"]), 5)
                self.assertTrue(all(c["outline_visible"] for c in layout["cells"]))
                for point in [t["centre"] for t in layout["things"]] + [c["position"] for c in layout["cells"]]:
                    reachable = False
                    for side in ("left", "right"):
                        try:
                            child.actor.body.check_reach(side, tuple(point), comfortable=True)
                            reachable = True
                        except ConstraintError:
                            pass
                    self.assertTrue(reachable, f"{body}: comfortable reach to {point}")
                child.play_round(started, ["right"] * 5)
                end = self.round_ends(sim)[0]
                self.assertTrue(end["success"] and end["data"]["first_try"])
                self.assertEqual(end["data"]["ending"], "studying")
                phases = [e["data"]["phase"] for e in sim.events("reported") if e["what"] == "desk_ending"]
                self.assertEqual(phases, ["arriving", "sitting", "opening", "studying"])
                self.assert_log_ok(sim)
                sim.close()

    def test_wrong_outline_then_all_correct_and_a_fresh_desk_next_round(self):
        sim = self.launch(plan(block("desk", rounds=2, difficulty=0.0, ray=False)))
        child = Child(sim, seed=1)
        first = sim.run_until("trial_started")
        child.play_round(first, ["wrong"] + ["right"] * 5)
        end = self.round_ends(sim)[0]
        self.assertEqual(end["data"]["tries"], 1)
        self.assertFalse(end["data"]["first_try"])
        second = sim.run_until("trial_started")
        layout = sim.observe()["stimuli"]["layout"]
        self.assertTrue(all(c["outline_visible"] for c in layout["cells"]))
        self.assertTrue(all(not t["placed"] for t in layout["things"]))
        self.assertFalse(layout["celebrating"])
        child.play_round(second, ["right"] * 5)
        self.assertTrue(self.round_ends(sim)[1]["data"]["first_try"])
