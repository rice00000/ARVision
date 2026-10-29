"""The facilitator's panel, used the way a facilitator does: left-hand menu pinch, point, pinch."""

import unittest

from support import Actor, Child, Facilitator, SimCase, block, plan


class Panel(SimCase):
    def setUp(self):
        self.sim = None

    def start(self, spec, **options):
        self.sim = self.launch(spec, **options)
        self.child = Child(self.sim, seed=1)
        self.facilitator = Facilitator(self.sim)
        return self.sim

    def pressed(self):
        return [r["button"] for r in self.reports(self.sim, "facilitator")]

    def test_menu_pauses_play(self):
        sim = self.start(plan(block("find", rounds=1)))
        started = sim.run_until("trial_started")
        self.child.actor.wait(2.0)
        self.facilitator.open()
        observation = sim.observe()
        self.assertTrue(observation["paused"])
        self.assertEqual([e["open"] for e in sim.events("facilitator_toggled")], [True])
        frozen = observation["session"]["trial"]["seconds"]
        self.child.actor.wait(60.0)  # longer than the hint delay and the time limit
        named = [t for t in sim.observe()["stimuli"]["targets"] if t["id"].endswith("_" + observation["stimuli"]["named"])][0]
        self.child.actor.point("right", tuple(named["centre"]))
        observation = sim.observe()
        self.assertEqual(observation["session"]["trial"]["seconds"], frozen, "paused time does not count")
        self.assertTrue(observation["session"]["trial"]["running"])
        self.assertTrue(sim.events("selected", since=started["seq"]), "the pointer still points")
        self.assertEqual(sim.events("feedback"), [], "but the trial does not judge")
        self.assertEqual(self.reports(sim, "hint"), [])
        self.facilitator.press("fac_close")
        self.assertFalse(sim.observe()["paused"])
        closed = sim.events("facilitator_toggled")[-1]
        hint = sim.run_until(("reported", "hint"), timeout=10)
        self.assert_close(hint["t"] - closed["t"], 7.0 - frozen, 3 / 60, "the hint clock carries on where it stopped")

    def test_closing_the_panel_is_not_an_answer(self):
        for trial in ("point_real", "find", "motion"):
            sim = self.start(plan(block(trial)), profile=f"test_sim_close_{trial}")
            started = sim.run_until("trial_started")
            self.child.actor.wait(0.6)
            self.facilitator.open()
            self.facilitator.press("fac_close")
            self.child.actor.wait(0.5)
            observation = sim.observe()
            self.assertFalse(observation["paused"])
            self.assertEqual(observation["session"]["trial"]["tries"], 0, f"{trial}: the Close press is not a try")
            self.assertEqual([e for e in sim.events("feedback", since=started["seq"]) if e["kind"] != "hint"], [], trial)
            self.assertEqual([e for e in sim.events("reported", since=started["seq"]) if e["what"].startswith("motion_")], [])
            self.child.play_round(started, ["right"])
            end = self.round_ends(sim)[0]
            self.assertTrue(end["data"]["first_try"], f"{trial}: still a first-try round")

    def test_easier_harder_and_auto_steer_the_level(self):
        sim = self.start(plan(block("find", rounds=4)))
        self.child.play_round(sim.run_until("trial_started"), ["wait:1"])
        self.facilitator.open()
        self.facilitator.press("fac_harder")
        self.assertIn("(pinned)", self.facilitator.panel()["status"])
        self.facilitator.press("fac_close")
        self.child.play_round(sim.events("trial_started")[0], ["right"])
        self.assertEqual(self.reports(sim, "level"), [], "no staircase while pinned")
        second = sim.run_until("trial_started")
        self.assertAlmostEqual(second["condition"]["level"], 0.4)
        self.assertAlmostEqual(second["condition"]["values"]["clutter"], 2 + 7 * 0.4)
        self.facilitator.open()
        self.facilitator.press("fac_easier")
        self.facilitator.press("fac_easier")
        self.assertAlmostEqual(sim.observe()["session"]["pinned"], 0.2)
        self.facilitator.press("fac_close")
        self.child.play_round(second, ["right"])
        third = sim.run_until("trial_started")
        self.assertAlmostEqual(third["condition"]["level"], 0.2)
        self.facilitator.open()
        self.facilitator.press("fac_auto")
        self.assertIn("(auto)", self.facilitator.panel()["status"])
        self.facilitator.press("fac_close")
        self.assertIsNone(sim.observe()["session"]["pinned"])
        self.child.play_round(third, ["right"])
        fourth = sim.run_until("trial_started")
        self.assertAlmostEqual(fourth["condition"]["level"], 0.3, msg="back on the staircase where it was")
        self.child.play_round(fourth, ["right"])
        self.assertEqual(len(self.reports(sim, "level")), 2, "rounds after Auto move the staircase")
        self.assertEqual(self.pressed(), ["fac_harder", "fac_close", "fac_easier", "fac_easier", "fac_close",
                                          "fac_auto", "fac_close"])
        self.assertEqual([round(r["level"], 6) for r in self.reports(sim, "level_pinned")], [0.4, 0.3, 0.2])
        self.assertEqual(len(self.reports(sim, "level_unpinned")), 1)
        self.assert_log_ok(sim)

    def test_next_view_lasts_until_the_next_block(self):
        sim = self.start(plan(block("find", rounds=2), block("find", rounds=1, view="dim")))
        first = sim.run_until("trial_started")
        self.facilitator.open()
        self.facilitator.press("fac_view")
        self.facilitator.press("fac_view")
        self.assertEqual(sim.observe()["view"]["title"], "Greyscale")
        self.assertIn("View: Greyscale", self.facilitator.panel()["status"])
        self.facilitator.press("fac_close")
        self.child.play_round(first, ["right"])
        self.child.play()
        views = [e["data"]["view"]["title"] for e in self.round_ends(sim)]
        self.assertEqual(views, ["Normal", "Greyscale", "Dim room"])
        self.assertEqual([e["view"]["title"] for e in sim.events("view_changed")],
                         ["Normal", "High contrast", "Greyscale", "Dim room"])
        self.assert_log_ok(sim)

    def test_skip_drops_the_round_and_moves_on(self):
        sim = self.start(plan(block("find", rounds=3), block("motion", rounds=1)))
        self.child.play_round(sim.run_until("trial_started"), ["right"])
        second = sim.run_until("trial_started")
        self.facilitator.open()
        self.facilitator.press("fac_skip")
        abandoned = self.reports(sim, "round_abandoned")
        self.assertEqual(abandoned, [{"trial": "find", "round": 1}])
        self.assertEqual(sim.events("block_started")[-1]["index"], 1, "the next block starts")
        self.assertIn("Read the flow", self.facilitator.panel()["status"])
        self.facilitator.press("fac_close")
        self.child.play()
        ends = self.round_ends(sim)
        self.assertEqual([(e["data"]["trial"], e["data"]["round"]) for e in ends], [("find", 0), ("motion", 0)])
        self.assertEqual(len(self.reports(sim, "level")), 2, "the dropped round is unscored")
        self.assertGreater(second["seq"], 0)
        lines = self.assert_log_ok(sim)
        self.assertTrue(any(line.get("what") == "round_abandoned" for line in lines))

    def test_buttons_between_blocks_do_nothing_harmful(self):
        sim = self.start(plan(block("find", rounds=2), greeting="Hello! Today we look for toys on the table."))
        self.facilitator.open()  # during the greeting: no block yet
        self.assertEqual(self.facilitator.panel()["status"], "No block running")
        for button in ("fac_easier", "fac_harder", "fac_skip"):
            self.facilitator.press(button)
        self.assertEqual(self.pressed(), [], "nothing to steer, nothing done")
        self.assertIsNone(sim.observe()["session"]["pinned"])
        self.facilitator.press("fac_auto")
        self.facilitator.press("fac_view")
        self.assertEqual(sim.observe()["view"]["title"], "High contrast")
        self.facilitator.press("fac_close")
        self.child.play(scripts={"find": ["right"]})
        ends = self.round_ends(sim)
        self.assertEqual(len(ends), 2, "the block still runs every round")
        self.assertEqual([e["data"]["view"]["title"] for e in ends], ["Normal", "Normal"], "the block's own view")
        self.assertEqual(len(self.reports(sim, "level")), 2)
        self.assertEqual(self.reports(sim, "round_abandoned"), [])
        self.facilitator.open()  # after the session
        for button in ("fac_easier", "fac_harder", "fac_skip", "fac_auto", "fac_view", "fac_close"):
            self.facilitator.press(button)
        self.assertFalse(sim.observe()["paused"])
        self.assertEqual(len(sim.events("session_finished")), 1)
        self.assertNotIn("level_pinned", [e["what"] for e in sim.events("reported")])

    def test_skip_during_an_intro_skips_the_whole_block(self):
        sim = self.start(plan(block("find", rounds=2, intro="Now we find toys. Look at the table, please."),
                              block("find", rounds=1, view="edges")))
        sim.run_until("block_started")
        self.facilitator.open()
        self.facilitator.press("fac_skip")
        self.facilitator.press("fac_close")
        self.child.play(scripts={"find": ["right"]})
        ends = self.round_ends(sim)
        self.assertEqual([e["data"]["view"]["title"] for e in ends], ["Edges"])
        self.assertEqual(self.reports(sim, "round_abandoned"), [], "no round had started")

    def test_saves_tab_makes_switches_and_copies_saves(self):
        sim = self.start(None, profile="test_sim_saves")
        actor = Actor(sim)
        menu = self.menu(sim)
        actor.touch("right", tuple(next(b for b in menu["buttons"] if b["id"] == "task_find_toys_1")["position"]), radius=0.01)
        Child(sim, seed=3).play()
        self.assertTrue(sim.run_until(("reported", "task_done"), timeout=10))
        self.menu(sim)
        self.facilitator.open()
        self.facilitator.press("fac_saves")
        panel = self.facilitator.panel()
        self.assertEqual(panel["playing"], "Playing: test_sim_saves")
        self.assertEqual(self.slots(panel), [("test_sim_saves", True)], "only this save, which cannot be opened again")
        self.facilitator.press("fac_new_save")
        for key in ("fac_key_B", "fac_key_E", "fac_key_N", "fac_erase", "fac_key_N"):
            self.facilitator.press(key)
        self.assertEqual(self.facilitator.panel()["name"], "Name: BEN_")
        self.facilitator.press("fac_create")
        sim.wait(0.5)
        observation = sim.observe()
        self.assertEqual((observation["profile"], observation["paused"], observation["facilitator"]["open"]),
                         ("test_sim_saves_s1", False, False), "plays the new save at once")
        self.assertEqual((observation["world"]["done"], observation["view"]["title"]), ({}, "Black and white"), "from the start")
        self.assertEqual([b["open"] for b in self.menu(sim)["buttons"]], [True, False, False, False, False])

        self.facilitator.open()
        self.facilitator.press("fac_saves")
        panel = self.facilitator.panel()
        self.assertEqual(panel["playing"], "Playing: BEN")
        self.assertEqual(self.slots(panel), [("test_sim_saves_s1", True), ("test_sim_saves", False)], "the one playing on top")
        self.facilitator.press("fac_slot_test_sim_saves")
        sim.wait(0.5)
        observation = sim.observe()
        self.assertEqual(observation["profile"], "test_sim_saves")
        self.assertEqual((observation["world"]["done"], observation["world"]["colour"]), ({"find_toys": [0]}, 1), "where it was left")
        self.assertEqual([b["open"] for b in self.menu(sim)["buttons"]], [True, True, False, False, False])

        self.facilitator.open()
        self.facilitator.press("fac_saves")
        self.facilitator.press("fac_new_save")
        self.facilitator.press("fac_copy")
        panel = self.facilitator.panel()
        self.assertTrue(panel["open"] and panel["playing"] == "Playing: test_sim_saves", "a copy does not switch")
        self.assertEqual(sorted(slot for slot, _ in self.slots(panel)), ["test_sim_saves", "test_sim_saves_s1", "test_sim_saves_s2"])
        self.facilitator.press("fac_slot_test_sim_saves_s2")
        sim.wait(0.5)
        observation = sim.observe()
        self.assertEqual(observation["profile"], "test_sim_saves_s2", observation["facilitator"])
        self.assertEqual(observation["world"]["done"], {"find_toys": [0]}, "the copy carries the progress")
        self.assertEqual([(r["from"], r["to"]) for r in self.reports(sim, "save_switched")],
                         [("test_sim_saves", "test_sim_saves_s1"), ("test_sim_saves_s1", "test_sim_saves"),
                          ("test_sim_saves", "test_sim_saves_s2")])
        self.assert_log_ok(sim)

    def menu(self, sim):
        """Faces the table and waits for its menu."""
        Actor(sim).look_at(tuple(sim.observe()["work_surface"]["position"]))
        for _ in range(40):
            menu = sim.observe()["world"]["menu"]
            if menu and menu["open"]:
                return menu
            sim.wait(0.5)
        self.fail(f"no menu: {sim.observe()['world']} {[e['text'] for e in sim.events('said')][-4:]}")

    @staticmethod
    def slots(panel):
        """(save id, cannot be pressed) for each row on the Saves page, top first."""
        return [(b["id"].removeprefix("fac_slot_"), b["disabled"]) for b in panel["buttons"] if b["id"].startswith("fac_slot_")]


if __name__ == "__main__":
    unittest.main()
