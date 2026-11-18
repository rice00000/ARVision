"""Build and serve the sandwich through tracked pinch gestures."""

from support import Child, ConstraintError, SimCase, block, plan


class Sandwich(SimCase):
    def test_each_body_can_reach_and_stack_all_four_ingredients(self):
        for body in ("small", "medium", "large"):
            with self.subTest(body=body):
                sim = self.launch(plan(block("sandwich", difficulty=0.0, ray=False)),
                                  body=body, profile=f"test_sim_sandwich_{body}")
                child = Child(sim, body=body, seed=8)
                started = sim.run_until("trial_started")
                layout = sim.observe()["stimuli"]["layout"]
                self.assertEqual(set(layout["recipe"][:-1]), {"lettuce", "tomato", "cheese"})
                self.assertEqual(layout["recipe"][-1], "bread")
                self.assertEqual({thing["key"] for thing in layout["things"]}, set(layout["recipe"]))
                for point in [t["centre"] for t in layout["things"]] + [layout["plate"]]:
                    for side in ("left", "right"):
                        try:
                            child.actor.body.check_reach(side, tuple(point), comfortable=True)
                            break
                        except ConstraintError:
                            continue
                    else:
                        self.fail(f"{body}: no comfortable reach to {point}")
                result = child.play_round(started, ["right"] * 4)
                self.assertTrue(result["success"] and result["data"]["first_try"])
                self.assertEqual(result["data"]["ending"], "served")
                self.assertEqual([entry["target"] for entry in self.reports(sim, "sandwich_layer")], layout["recipe"])
                self.assertEqual([entry["phase"] for entry in self.reports(sim, "sandwich_serving")], ["showcase", "served"])
                self.assert_log_ok(sim)
                sim.close()

    def test_wrong_layer_recovery_and_next_round(self):
        sim = self.launch(plan(block("sandwich", rounds=2, difficulty=0.0, ray=False)))
        child = Child(sim, seed=2)
        first = sim.run_until("trial_started")
        end = child.play_round(first, ["wrong", *["right"] * 4])
        self.assertEqual(end["data"]["tries"], 1)
        self.assertEqual([entry["correct"] for entry in self.reports(sim, "sandwich_layer")], [False] + [True] * 4)
        second = sim.run_until("trial_started")
        layout = sim.observe()["stimuli"]["layout"]
        self.assertEqual((layout["stage"], layout["placed"], layout["celebrating"]), ("building", 0, False))
        self.assertTrue(all(t["home"] == t["centre"] for t in layout["things"]))
        self.assertTrue(child.play_round(second, ["right"] * 4)["data"]["first_try"])
