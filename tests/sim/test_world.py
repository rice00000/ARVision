"""The adventure played by a seated child: turn to the table, pick a game from its menu by hand,
play it, get colour back, and find it all again after a relaunch."""

import unittest

from support import Actor, Child, SimCase


class Adventure(SimCase):
    def button(self, sim, button_id):
        menu = sim.observe()["world"]["menu"]
        return next(b for b in menu["buttons"] if b["id"] == button_id)

    def open_menu(self, sim, actor):
        """Turns to the table and waits for its menu to unfold."""
        actor.look_at(tuple(sim.observe()["work_surface"]["position"]))
        self.assertTrue(sim.run_until(("reported", "place_entered"), timeout=5), "facing the table opens its menu")
        sim.wait(0.5)
        self.assertTrue(sim.observe()["world"]["menu"]["open"])

    def press(self, sim, actor, button_id):
        actor.touch("right", tuple(self.button(sim, button_id)["position"]), radius=0.01)  # poke the middle: the buttons are 2 cm thick

    def test_turn_pick_play_and_colour_comes_back(self):
        sim = self.launch(None, profile="test_sim_world", seat=(0.0, 0.0, 40))
        actor = Actor(sim)
        self.assertEqual(sim.observe()["view"]["title"], "Black and white", "the room starts without colour")
        for _ in range(30):
            observation = sim.observe()
            if observation["world"]["guide"]["visible"]:
                break
            sim.wait(0.5)
        self.assertTrue(observation["world"]["guide"]["visible"], "seated 40 degrees away: the guide shows the way")
        self.assertIsNone(observation["world"]["menu"])
        self.assertIn("Turn to the table", [e["text"] for e in sim.events("said")][-1])

        self.open_menu(sim, actor)
        self.assertFalse(sim.observe()["world"]["guide"]["visible"])
        self.press(sim, actor, "task_break_wall_1")
        self.assertIn("still locked", sim.events("said")[-1]["text"])
        self.assertIsNotNone(sim.observe()["world"]["menu"], "a locked game starts nothing")

        self.press(sim, actor, "task_find_toys_1")
        self.assertEqual(sim.events("reported", "task_chosen")[-1]["data"], {"task": "find_toys", "level": 1})
        Child(sim, seed=3).play()
        self.assertTrue(sim.run_until(("reported", "task_done"), timeout=10))
        ends = self.round_ends(sim)
        self.assertEqual(len(ends), 3)
        self.assertTrue(all(e["data"]["view"]["title"] == "Black and white" for e in ends), "played without colour")
        self.assertTrue(all(abs(e["data"]["level"] - 0.1) < 1e-6 for e in ends), "at level 1's difficulty")
        for _ in range(30):  # still at the table: the menu comes back without turning again
            world = sim.observe()["world"]
            if world["menu"] and world["menu"]["open"]:
                break
            sim.wait(0.5)
        self.assertTrue(world["menu"] and world["menu"]["open"], "back to the table's menu")
        self.assertEqual(len(sim.events("reported", "place_entered")), 1, "no second turn needed")
        self.assertEqual((world["stones"], world["colour"]), (1, 1))
        self.assertEqual(sim.observe()["view"]["title"], "A little colour")
        open_now = {b["id"] for b in world["menu"]["buttons"] if b["open"]}
        self.assertEqual(open_now, {"task_find_toys_1", "task_find_toys_2", "task_break_wall_1"})
        self.assertEqual([b["done"] for b in world["menu"]["buttons"] if b["id"] == "task_find_toys_1"], [True])
        self.assert_log_ok(sim)
        sim.close(keep_profile=True)

        again = self.launch(None, profile="test_sim_world", seat=(0.0, 0.0, 40), keep_profile=True)
        again.wait(1.0)
        world = again.observe()["world"]
        self.assertEqual((world["done"], world["stones"], world["colour"]), ({"find_toys": [0]}, 1, 1), "saved")
        self.assertEqual(again.observe()["view"]["title"], "A little colour", "the colour stays")

    def test_every_button_is_in_reach_of_every_body(self):
        for body in ("small", "medium", "large"):
            with self.subTest(body=body):
                sim = self.launch(None, profile=f"test_sim_world_reach_{body}", body=body)
                actor = Actor(sim, body)
                for _ in range(30):
                    menu = sim.observe()["world"]["menu"]
                    if menu and menu["open"]:
                        break
                    sim.wait(0.5)
                self.assertTrue(menu and menu["open"], "seated facing the table: the menu unfolds")
                points = [tuple(button["position"]) for button in menu["buttons"]]
                actor.look_at(tuple(sum(axis) / len(points) for axis in zip(*points)))
                for button in menu["buttons"]:
                    point = tuple(button["position"])
                    side = "left" if actor.body.local(point)[0] < 0 else "right"
                    actor.body.path(side, actor.body.ready(side), point)  # ConstraintError if out of reach
                    actor.body.check_view(sim.observe()["head"], point)
                sim.close()


if __name__ == "__main__":
    unittest.main()
