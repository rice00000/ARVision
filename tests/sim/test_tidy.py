"""Tidy up: a seated child takes each thing off the bench and holds it on its sticker."""

import csv
import math
from pathlib import Path
import unittest

from support import Child, ConstraintError, SimCase, block, plan

STICKERS = {"shadow": {}, "outline": {"outline": 1.0}, "size": {"match": 1.0}, "colour": {"match": 2.0}}


class TidyUp(SimCase):
    def layout(self, sim):
        return sim.observe()["stimuli"]["layout"]

    def test_every_body_reaches_every_thing_and_sticker_without_stretching(self):
        for body in ("small", "medium", "large"):
            with self.subTest(body=body):
                sim = self.launch(plan(block("tidy", rounds=1, difficulty=1.0, ray=False)),
                                  profile=f"test_sim_tidy_reach_{body}", body=body)
                child = Child(sim, body=body, seed=6)
                started = sim.run_until("trial_started")
                layout = self.layout(sim)
                self.assertEqual(len(layout["things"]), 6)
                points = [t["centre"] for t in layout["things"]] + [c["position"] for c in layout["cells"]]
                for point in points:
                    self.assertTrue(any(self.reaches(child.actor.body, side, tuple(point)) for side in ("left", "right")),
                                    f"{body}: {point} without stretching")
                child.play_round(started, ["right"] * 6)
                self.assertTrue(self.round_ends(sim)[0]["data"]["first_try"], f"{body} put all six back")
                sim.close()

    @staticmethod
    def reaches(body, side, point):
        try:
            body.check_reach(side, point, comfortable=True)
            return True
        except ConstraintError:
            return False

    def test_a_wrong_put_bounces_back_and_the_round_still_ends_tidy(self):
        sim = self.launch(plan(block("tidy", rounds=1, difficulty=0.0, ray=False)))
        child = Child(sim, seed=2)
        started = sim.run_until("trial_started")
        child.play_round(started, ["wrong", "right", "right", "right"])
        end = self.round_ends(sim)[0]
        self.assertTrue(end["success"] and not end["data"]["first_try"])
        self.assertEqual(end["data"]["tries"], 1)
        self.assertEqual([p["correct"] for p in end["data"]["puts"]], [False, True, True, True])
        with open(Path(sim.observe()["profile_dir"]) / "picks.csv", encoding="utf-8") as file:
            picks = list(csv.DictReader(file))
        self.assertEqual([p["correct"] for p in picks], ["0", "1", "1", "1"], "every put is a row in the CSV")
        self.assertNotEqual(picks[0]["target"], picks[0]["picked"], "the sticker it was held at, and the thing")
        said = [e["text"] for e in sim.events("said", since=started["seq"])]
        self.assertIn("That's not its shape. Look again!", said)
        self.assertIn("All tidy! Everything is back home.", said)
        self.assert_log_ok(sim)

    def test_each_sticker_kind_plays_through_by_policy(self):
        sim = self.launch(plan(*[block("tidy", rounds=1, difficulty=0.67, pins=pins, ray=False) for pins in STICKERS.values()]))
        Child(sim, seed=5).play()
        ends = self.round_ends(sim)
        self.assertEqual(len(ends), 4)
        self.assertTrue(all(e["success"] or e["data"].get("timed_out") for e in ends))
        keys = [sorted(p["thing"] for p in e["data"]["puts"]) for e in ends]
        self.assertTrue(all(len(set(k)) == 5 for k in keys), keys)
        self.assertTrue(all("_" in k for k in keys[2] + keys[3]), "sizes and colours are named by shape and kind")
        self.assert_log_ok(sim)

    def test_the_bench_faces_the_table_and_stays_put_for_the_block(self):
        sim = self.launch(plan(block("tidy", rounds=2, difficulty=0.0, ray=False)))
        child = Child(sim, seed=3)
        first = sim.run_until("trial_started")
        cells = [c["card"] for c in self.layout(sim)["cells"]]
        eye = sim.observe()["head"]["position"]
        table = sim.observe()["work_surface"]["position"]
        middle = [sum(axis) / len(cells) for axis in zip(*cells)]
        bearing = lambda p: math.degrees(math.atan2(p[0] - eye[0], -(p[2] - eye[2])))
        self.assert_close(bearing(middle), bearing(table), 2.0, "the shelf stands toward the table")
        child.play_round(first, ["right"] * 3)
        second = sim.run_until("trial_started")
        child.actor.look_at(tuple(sim.observe()["work_surface"]["position"]))
        again = [c["card"] for c in self.layout(sim)["cells"]]
        self.assertTrue(all(math.dist(a, b) < 1e-4 for a, b in zip(cells, again)), "the same shelf")
        child.play_round(second, ["right"] * 3)


if __name__ == "__main__":
    unittest.main()
