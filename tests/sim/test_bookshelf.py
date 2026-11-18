"""The bookshelf is playable from its level card at three seated heights."""

from support import Child, ConstraintError, SimCase


class BookshelfMatch(SimCase):
    def test_all_five_cubbies_are_reachable_and_filling_them_completes_the_level(self):
        for body in ("small", "medium", "large"):
            with self.subTest(body=body):
                sim = self.launch(None, body=body, profile=f"test_sim_bookshelf_{body}")
                child = Child(sim, body=body, seed=4)
                self.assertTrue(sim.run_until(("reported", "place_entered")))
                sim.wait(0.75)
                buttons = sim.observe()["world"]["menu"]["buttons"]
                card = next(b for b in buttons if b["id"] == "task_tidy_shelf_bookshelf")
                child.actor.point("right", tuple(card["position"]), expect=card["id"])
                started = sim.run_until("trial_started")
                self.assertEqual(started["trial"], "bookshelf")
                layout = sim.observe()["stimuli"]["layout"]
                cells = {c["key"]: c["position"] for c in layout["cells"] if not c["filled"]}
                self.assertEqual(set(cells), {"mug", "notebook", "pencil", "headphones", "plant"})
                for point in list(cells.values()) + [t["centre"] for t in layout["things"]]:
                    for hand in ("left", "right"):
                        try:
                            child.actor.body.check_reach(hand, tuple(point), comfortable=True)
                            break
                        except ConstraintError:
                            pass
                    else:
                        self.fail(f"{body}: no comfortable reach to {point}")

                wrong = ["wrong"] if body == "medium" else []
                end = child.play_round(started, wrong + ["right"] * 5)
                self.assertTrue(end["success"])
                self.assertEqual(end["data"]["tries"], len(wrong))
                self.assertEqual([p["correct"] for p in end["data"]["puts"]], [False] * len(wrong) + [True] * 5)
                sim.wait(0.3)
                final_layout = sim.observe()["stimuli"]["layout"]
                self.assertTrue(all(c["filled"] for c in final_layout["cells"]))
                for thing in final_layout["things"]:
                    self.assertEqual(thing["centre"], cells[thing["key"]])
                self.assertTrue(sim.run_until(("reported", "task_done")))
                self.assertEqual(sim.observe()["world"]["done"], {"tidy_shelf": ["bookshelf"]})
                self.assert_log_ok(sim)
                sim.close()
