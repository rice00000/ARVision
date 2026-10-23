"""Every block's view is applied and logged with every round; spotlights follow the action."""

import math
import unittest

from support import Child, SimCase, block, plan

NEUTRAL = {"brightness": 0.0, "contrast": 1.0, "saturation": 1.0, "black_and_white": False,
           "edges": [0.0, 0.0, 0.0, 0.0], "dim": 0.0, "focus_radius": 0.0}
PRESETS = {
    "normal": {"title": "Normal"},
    "high_contrast": {"title": "High contrast", "contrast": 1.8},
    "greyscale": {"title": "Greyscale", "saturation": 0.0},
    "black_white": {"title": "Black and white", "black_and_white": True},
    "edges": {"title": "Edges", "edges": [1.0, 0.9, 0.2, 1.0]},
    "dim": {"title": "Dim room", "dim": 0.6},
    "spotlight": {"title": "Spotlight", "dim": 0.8, "focus_radius": 0.35},
}


def close(a, b):
    if isinstance(a, list):
        return len(a) == len(b) and all(close(x, y) for x, y in zip(a, b))
    return a == b if isinstance(a, (bool, str)) else math.isclose(a, b, abs_tol=1e-5)


class Views(SimCase):
    def assert_view(self, logged, preset):
        expected = {**NEUTRAL, **PRESETS[preset]}
        self.assertEqual(logged.keys(), expected.keys())
        for key, value in expected.items():
            self.assertTrue(close(logged[key], value), f"{preset}.{key}: {logged[key]} vs {value}")

    def test_each_block_view_is_applied_and_logged_on_every_round(self):
        order = ["spotlight", "normal", "high_contrast", "greyscale", "black_white", "edges", "dim", None]
        sim = self.launch(plan(*[block("find", rounds=2, view=view) for view in order]))
        child = Child(sim, seed=1)
        while True:
            started = sim.run_until("trial_started", "session_finished")
            if started["event"] == "session_finished":
                break
            index = sim.observe()["session"]["block_index"]
            self.assert_view(sim.observe()["view"], order[index] or "normal")
            child.play_round(started, ["right"])
        ends = self.round_ends(sim)
        self.assertEqual(len(ends), 16)
        for i, end in enumerate(ends):
            self.assert_view(end["data"]["view"], order[i // 2] or "normal")
        changes = [e["view"]["title"] for e in sim.events("view_changed")]
        self.assertEqual(changes, [PRESETS[v or "normal"]["title"] for v in order])
        lines = self.assert_log_ok(sim)
        self.assertEqual([line["view"]["title"] for line in lines if line["type"] == "view"], changes)
        starts = [line for line in lines if line["type"] == "trial_start"]
        self.assertEqual([s["condition"]["view"]["title"] for s in starts], [e["data"]["view"]["title"] for e in ends])

    def test_spotlight_centres_on_each_trials_action(self):
        sim = self.launch(plan(block("find", view="spotlight"), block("point_real", view="spotlight"),
                               block("motion", view="spotlight")))
        child = Child(sim, seed=2)
        started = sim.run_until("trial_started")
        observation = sim.observe()
        self.assertTrue(close(observation["focus"], observation["work_surface"]["position"]), "find: the table")
        child.play_round(started, ["right"])
        started = sim.run_until("trial_started")
        sim.wait(0.6)  # the detector names an object
        observation = sim.observe()
        named = [o for o in observation["real_objects"] if o["label"] == observation["stimuli"]["named"]][0]
        self.assertTrue(close(observation["focus"], named["centre"]), "real objects: the named one")
        child.play_round(started, ["right"])
        started = sim.run_until("trial_started")
        observation = sim.observe()
        self.assertTrue(close(observation["focus"], observation["stimuli"]["cloud"]["position"]), "motion: the cloud")
        child.play_round(started, ["right"])


if __name__ == "__main__":
    unittest.main()
