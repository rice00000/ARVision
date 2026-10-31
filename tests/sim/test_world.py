"""Play the object scene, switch to motion through the menu, and retain both saves."""

import csv
from pathlib import Path
import unittest

from support import Actor, Child, Facilitator, SimCase


class Adventure(SimCase):
    def button(self, sim, button_id):
        menu = sim.observe()["world"]["menu"]
        return next(b for b in menu["buttons"] if b["id"] == button_id)

    def menu_at(self, sim, place, timeout=15.0):
        """Waits until `place`'s menu is open; returns the world observation."""
        for _ in range(int(timeout / 0.5)):
            world = sim.observe()["world"]
            if world["place"] == place and world["menu"] and world["menu"]["open"]:
                return world
            sim.wait(0.5)
        self.fail(f"no open menu at {place}: {sim.observe()['world']}")

    def press(self, sim, actor, button_id):
        actor.touch("right", tuple(self.button(sim, button_id)["position"]), radius=0.01)  # poke the middle

    def last_said(self, sim):
        return sim.events("said")[-1]["text"]

    def switch_scene(self, sim, scene):
        facilitator = Facilitator(sim)
        facilitator.open()
        facilitator.press("fac_scenes")
        facilitator.press("fac_scene_" + scene)
        sim.wait(0.6)
        self.assertEqual(sim.observe()["scene"], scene)
        self.assertFalse(sim.observe()["paused"])

    def test_table_then_switch_to_the_wall(self):
        sim = self.launch(None, profile="test_sim_world", seat=(0.0, 0.0, 40))
        actor = Actor(sim)
        self.assertEqual(sim.observe()["view"]["title"], "Normal", "the room starts in normal colour")
        for _ in range(30):
            if sim.observe()["world"]["guide"]["visible"]:
                break
            sim.wait(0.5)
        self.assertTrue(sim.observe()["world"]["guide"]["visible"], "seated 40 degrees away: the guide shows the way")
        self.assertIn("Turn to your alchemy table", self.last_said(sim))

        actor.swivel(-40)  # turns the chair to the table
        world = self.menu_at(sim, "Alchemy table", timeout=5)
        self.assertFalse(world["guide"]["visible"])
        self.assertEqual([(b["id"], b["open"]) for b in world["menu"]["buttons"]],
                         [(f"task_tidy_shelf_{n}", n == 1) for n in range(1, 6)], "the table's own list")
        self.press(sim, actor, "task_tidy_shelf_2")
        self.assertIn("still locked", self.last_said(sim))
        self.press(sim, actor, "task_tidy_shelf_1")
        self.assertEqual(sim.events("reported", "task_chosen")[-1]["data"], {"task": "tidy_shelf", "level": 1})
        Child(sim, seed=3).play()
        self.assertTrue(sim.run_until(("reported", "task_done"), timeout=10))
        ends = self.round_ends(sim)
        self.assertEqual(len(ends), 2)
        self.assertTrue(all(e["data"]["view"]["title"] == "Normal" for e in ends), "played in normal colour")
        self.assertTrue(all(e["data"]["level"] == 0.0 and e["data"]["values"]["things"] == 3 for e in ends), "level 1: three things")
        with open(Path(sim.observe()["profile_dir"]) / "picks.csv", encoding="utf-8") as file:
            picks = list(csv.DictReader(file))
        self.assertEqual({row["game"] for row in picks}, {"Tidy the shelf, level 1"}, "every put in the CSV")
        puts = self.reports(sim, "put")
        self.assertEqual([row["correct"] == "1" for row in picks], [put["correct"] for put in puts], "a row per put")

        world = self.menu_at(sim, "Alchemy table")
        self.assertEqual(sim.observe()["view"]["title"], "Normal", "completing the shelf keeps normal colour")
        self.assertFalse(world["guide"]["visible"], "motion lives in another scene")
        self.assertEqual([b["open"] for b in world["menu"]["buttons"]], [True, True, False, False, False],
                         "level 2 opened here too")

        actor.look_at(tuple(sim.observe()["work_surface"]["position"]))  # back at the menu, not the last toy
        self.switch_scene(sim, "global_motion")
        world = self.menu_at(sim, "Spell wall", timeout=15)
        self.assertFalse(world["guide"]["visible"], "nothing new left elsewhere: the guide rests")
        self.assertEqual([(b["id"], b["open"]) for b in world["menu"]["buttons"]],
                         [("task_break_wall_1", True), ("task_break_wall_2", False)], "the wall's own list")
        self.press(sim, actor, "task_break_wall_1")
        Child(sim, seed=4).play()
        self.assertTrue(sim.run_until(("reported", "task_done"), timeout=15))
        ends = [e for e in self.round_ends(sim) if e["skill"] != "visual_matching"]
        self.assertEqual(len(ends), 3, "three wall rounds")
        self.assertTrue(all(e["data"]["view"]["title"] == "Normal" for e in ends))
        world = self.menu_at(sim, "Spell wall")
        self.assertEqual(sim.observe()["view"]["title"], "Normal", "completing the wall keeps normal colour")
        self.assertEqual(len(sim.events("reported", "place_entered")), 2, "one place in each scene")
        self.assert_log_ok(sim)
        sim.close(keep_profile=True)

        again = self.launch(None, profile="test_sim_world", keep_profile=True)
        world = self.menu_at(again, "Alchemy table")
        self.assertEqual(world["done"], {"tidy_shelf": [0], "break_wall": [0]}, "saved")
        self.assertEqual(again.observe()["view"]["title"], "Normal", "relaunching keeps normal colour")
        self.assertFalse(world["guide"]["visible"], "everything open was seen before: no nagging")

    def test_every_button_is_in_reach_of_every_body(self):
        for body in ("small", "medium", "large"):
            with self.subTest(body=body):
                sim = self.launch(None, profile=f"test_sim_world_reach_{body}", body=body)
                actor = Actor(sim, body)
                for place, scene in (("Alchemy table", "find_object"), ("Spell wall", "global_motion")):
                    if scene == "global_motion":
                        self.switch_scene(sim, scene)
                    menu = self.menu_at(sim, place)["menu"]
                    points = [tuple(button["position"]) for button in menu["buttons"]]
                    actor.look_at(tuple(sum(axis) / len(points) for axis in zip(*points)))
                    for point in points:
                        side = "left" if actor.body.local(point)[0] < 0 else "right"
                        actor.body.path(side, actor.body.ready(side), point)  # ConstraintError if out of reach
                        actor.body.check_view(sim.observe()["head"], point)
                sim.close()


if __name__ == "__main__":
    unittest.main()
