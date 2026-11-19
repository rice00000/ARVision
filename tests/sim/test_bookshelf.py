"""The bookshelf is playable from its level card at three seated heights, and adapts: a new child
starts with three objects, and each right round brings more (up to all five)."""

from support import Child, ConstraintError, SimCase

KEYS = {"mug", "notebook", "pencil", "headphones", "plant"}
ROUNDS = 3


class BookshelfMatch(SimCase):
    def test_each_round_is_reachable_and_filling_the_cubbies_completes_the_level(self):
        for body in ("small", "medium", "large"):
            with self.subTest(body=body):
                sim = self.launch(None, body=body, profile=f"test_sim_bookshelf_{body}")
                child = Child(sim, body=body, seed=4)
                self.assertTrue(sim.run_until(("reported", "place_entered")))
                sim.wait(0.75)
                buttons = sim.observe()["world"]["menu"]["buttons"]
                card = next(b for b in buttons if b["id"] == "task_tidy_shelf_bookshelf")
                child.actor.point("right", tuple(card["position"]), expect=card["id"])
                counts = []
                for index in range(ROUNDS):
                    started = sim.run_until("trial_started")
                    self.assertEqual(started["trial"], "bookshelf")
                    layout = sim.observe()["stimuli"]["layout"]
                    cells = {c["key"]: c["position"] for c in layout["cells"] if not c["filled"]}
                    self.assertTrue(set(cells) <= KEYS and 3 <= len(cells) <= 5, cells)
                    counts.append(len(cells))
                    for point in list(cells.values()) + [t["centre"] for t in layout["things"]]:
                        for hand in ("left", "right"):
                            try:
                                child.actor.body.check_reach(hand, tuple(point), comfortable=True)
                                break
                            except ConstraintError:
                                pass
                        else:
                            self.fail(f"{body}: no comfortable reach to {point}")
                    wrong = ["wrong"] if body == "medium" and index == 0 else []
                    end = child.play_round(started, wrong + ["right"] * len(cells))
                    self.assertTrue(end["success"])
                    self.assertEqual(end["data"]["tries"], len(wrong))
                    self.assertEqual([p["correct"] for p in end["data"]["puts"]], [False] * len(wrong) + [True] * len(cells))
                    sim.wait(0.3)
                    final_layout = sim.observe()["stimuli"]["layout"]
                    self.assertTrue(all(c["filled"] for c in final_layout["cells"]))
                    for thing in final_layout["things"]:
                        self.assertEqual(thing["centre"], cells[thing["key"]])
                self.assertEqual(counts[0], 3, "a new child starts with three")
                if body != "medium":  # all right first time: the quick start brings more
                    self.assertGreater(counts[-1], counts[0])
                self.assertTrue(sim.run_until(("reported", "task_done")))
                self.assertEqual(sim.observe()["world"]["done"], {"tidy_shelf": ["bookshelf"]})
                self.assert_log_ok(sim)
                sim.close()
