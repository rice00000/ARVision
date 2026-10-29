"""Find it on the real table: the layout the child sees, touching, and the virtual patch."""

import math
import unittest

from support import Child, ConstraintError, SimCase, block, plan


def rise(head, point):
    """Degrees `point` sits above the gaze, in the child's view."""
    relative = [p - e for p, e in zip(point, head["position"])]
    y, z = (sum(a * b for a, b in zip(relative, head[axis])) for axis in ("y", "z"))
    return math.degrees(math.atan2(y, -z))


ROUND = {"cup", "bottle", "apple", "vase"}  # cylinders and balls in the simulated room


def ok_hue(colour):
    """OKLab hue of an sRGB colour, as a fraction of the wheel (what Color.from_ok_hsl takes)."""
    r, g, b = (c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in colour[:3])
    l, m, s = (math.copysign(abs(v) ** (1 / 3), v) for v in (
        0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b,
        0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b,
        0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b))
    a = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
    b = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    return math.atan2(b, a) / (2 * math.pi) % 1.0


def segment_gap(point, start, end):
    """Metres from `point` to the straight line from `start` to `end`."""
    line = [e - s for s, e in zip(start, end)]
    t = max(0.0, min(1.0, sum((p - s) * l for p, s, l in zip(point, start, line)) / sum(l * l for l in line)))
    return math.dist(point, [s + t * l for s, l in zip(start, line)])


def footprint_gap(point, thing):
    """Metres from `point` to the edge of `thing`'s footprint on the table (negative inside)."""
    dx, dz = (abs(point[i] - thing["centre"][i]) for i in (0, 2))
    if thing["label"] in ROUND:
        return math.hypot(dx, dz) - thing["extent"][0] / 2
    ex, ez = thing["extent"][0] / 2, thing["extent"][2] / 2
    if dx < ex and dz < ez:
        return -min(ex - dx, ez - dz)
    return math.hypot(max(dx - ex, 0.0), max(dz - ez, 0.0))


class FindIt(SimCase):
    def test_toys_lie_on_the_table_as_the_condition_says(self):
        sim = self.launch(plan(block("find", rounds=4, difficulty=0.6)))
        child = Child(sim, seed=1)
        seeds = set()
        for _ in range(4):
            started = sim.run_until("trial_started")
            observation = sim.observe()
            values = started["condition"]["values"]
            surface = observation["work_surface"]
            toys = observation["stimuli"]["targets"]
            self.assertEqual(surface["kind"], "table")
            self.assertEqual(len(toys), int(values["clutter"]) + 1)
            self.assertEqual(values["toys"], len(toys))
            self.assertEqual(sum(t["id"].endswith("_" + values["target"]) for t in toys), 1, "one toy of the named shape")
            for toy in toys:
                local = [sum((toy["position"][i] - surface["position"][i]) * surface[axis][i] for i in range(3))
                         for axis in ("x", "y", "z")]
                self.assertAlmostEqual(local[1], values["size"] / 2, places=4)
                self.assertLessEqual(abs(local[0]), surface["size"][0] / 2 - values["size"] / 2 + 1e-6, "on the table")
                self.assertLessEqual(abs(local[2]), surface["size"][1] / 2 - values["size"] / 2 + 1e-6, "on the table")
            gaps = [math.dist(a["position"], b["position"]) for i, a in enumerate(toys) for b in toys[i + 1:]]
            self.assertGreaterEqual(min(gaps), values["size"] * values["spacing"] - 1e-6)
            seeds.add(values["seed"])
            child.play_round(started, ["right"])
        self.assertEqual(len(seeds), 4, "a new layout every round")

    def test_toys_never_stand_on_real_objects(self):
        sim = self.launch(plan(block("find", rounds=6, difficulty=1.0)))
        child = Child(sim, seed=4)
        for _ in range(6):
            started = sim.run_until("trial_started")
            observation = sim.observe()
            size = started["condition"]["values"]["size"]
            for thing in observation["real_objects"]:
                if thing["centre"][1] - thing["extent"][1] / 2 > observation["work_surface"]["position"][1] + 0.01:
                    continue  # not standing on the table
                for toy in observation["stimuli"]["targets"]:
                    self.assertGreaterEqual(footprint_gap(toy["position"], thing), size / 2 - 1e-4,
                                            f"{toy['id']} on the {thing['label']}")
            child.play_round(started, ["right"])

    def test_the_subtitle_stays_clear_of_the_toys(self):
        sim = self.launch(plan(block("find", rounds=1, difficulty=1.0)))
        child = Child(sim, seed=5)
        started = sim.run_until("trial_started")
        surface = sim.observe()["work_surface"]
        child.actor.look_at(tuple(surface["position"]))
        observation = sim.observe()
        head, subtitle = observation["head"], observation["subtitle"]
        self.assertTrue(subtitle["visible"])
        line = math.degrees(math.atan(2 * 0.0006 * 48 / 0.75))  # two subtitle lines, half above and half below
        for toy in observation["stimuli"]["targets"]:
            self.assertGreater(rise(head, subtitle["position"]) - line, rise(head, toy["position"]) + 3.0, toy["id"])
        child.actor.look_at(tuple(a + b for a, b in zip(head["position"], (0.0, 0.0, -2.0))))
        observation = sim.observe()
        up = [s - e for s, e in zip(observation["subtitle"]["position"], observation["head"]["position"])]
        self.assert_close(math.degrees(math.asin(up[1] / math.hypot(*up))), 20.0, 0.5, "looking ahead: over the horizon")
        child.play_round(started, ["right"])

    def test_touching_a_toy_in_reach_counts_like_pointing(self):
        sim = self.launch(plan(block("find", rounds=10)), seat=(0.0, -0.1, 0), body="large")
        child = Child(sim, body="large", seed=2)
        touched = pointed = 0
        while True:
            started = sim.run_until("trial_started", "session_finished")
            if started["event"] == "session_finished":
                break
            target, others = child.toys(started, sim.observe())
            try:
                child.actor.body.check_reach("right", tuple(target["centre"]), comfortable=True)
                ready = child.actor.body.ready("right")
                if any(segment_gap(o["centre"], ready, target["centre"]) < o["radius"] + 0.04 for o in others):
                    raise ConstraintError("path_blocked")  # a child reaches round; this one points instead
                child.play_round(started, ["touch"])
                self.assertEqual(sim.events("touched")[-1]["target"], target["id"])
                touched += 1
            except ConstraintError:
                child.play_round(started, ["right"])
                pointed += 1
        self.assertTrue(all(e["success"] and e["data"]["first_try"] for e in self.round_ends(sim)))
        self.assertGreater(touched, 0, "some named toys lay within reach")
        self.assertEqual(touched + pointed, 10)

    def test_toys_lie_within_easy_reach_of_every_body(self):
        for body in ("small", "medium", "large"):
            with self.subTest(body=body):
                sim = self.launch(plan(block("find", rounds=3, difficulty=0.6, pins={"spacing": 1.4}, ray=False)),
                                  profile=f"test_sim_find_reach_{body}", body=body)
                child = Child(sim, body=body, seed=6)
                for _ in range(3):
                    started = sim.run_until("trial_started")
                    toys = sim.observe()["stimuli"]["targets"]
                    self.assertEqual(len(toys), int(started["condition"]["values"]["clutter"]) + 1, "a crowded level still fits")
                    for toy in toys:
                        self.assertTrue(self.easy(child.actor.body, tuple(toy["centre"])), f"{body}: {toy['id']} without stretching")
                    child.play_round(started, ["right"])
                sim.close()

    @staticmethod
    def easy(body, point):
        for side in ("left", "right"):
            try:
                body.check_reach(side, point, comfortable=True)
                return True
            except ConstraintError:
                pass
        return False

    def test_same_toys_but_one_colour_a_little_different(self):
        sim = self.launch(plan(block("find", rounds=3, difficulty=0.45, pins={"same_shape": 1.0, "colour_gap": 0.04})))
        child = Child(sim, seed=7)
        for _ in range(3):
            started = sim.run_until("trial_started")
            toys = sim.observe()["stimuli"]["targets"]
            said = [e["text"] for e in sim.events("said", since=started["seq"] - 2)]
            self.assertTrue(any(text.endswith(" with a different colour!") for text in said), said)
            odd = [toy for toy in toys if toy["id"].endswith("_odd")]
            others = [toy for toy in toys if toy not in odd]
            self.assertEqual((len(odd), started["condition"]["values"]["target"]), (1, "odd"))
            self.assertEqual(len({toy["id"].split("_", 2)[2] for toy in others}), 1, "one shape")
            self.assertTrue(all(math.dist(toy["extent"], odd[0]["extent"]) < 1e-4 for toy in others), "the different one too")
            self.assertEqual(len({tuple(round(c, 4) for c in toy["colour"]) for toy in others}), 1, "one colour")
            gap = abs(ok_hue(odd[0]["colour"]) - ok_hue(others[0]["colour"]))
            self.assert_close(min(gap, 1.0 - gap), 0.04, 0.002, "a little round the colour wheel")
            child.play_round(started, ["wrong", "right"])
            self.assertIn("That one is like the others. Find the different one!", [e["text"] for e in sim.events("said", since=started["seq"])])
        ends = self.round_ends(sim)
        self.assertTrue(all(e["success"] and e["data"]["picks"][-1] == "odd" for e in ends))
        self.assert_log_ok(sim)

    def test_without_a_table_in_reach_toys_go_on_a_patch_in_front(self):
        sim = self.launch(plan(block("find", rounds=1)), seat=(0.0, 1.0, 0))
        child = Child(sim, seed=3)
        started = sim.run_until("trial_started")
        observation = sim.observe()
        surface = observation["work_surface"]
        eye = observation["head"]["position"]
        self.assertEqual([round(v, 5) for v in surface["size"]], [0.8, 0.5])
        self.assertAlmostEqual(surface["position"][1], eye[1] - 0.4, places=4)
        self.assertAlmostEqual(eye[2] - surface["position"][2], 0.4, places=4)
        for toy in observation["stimuli"]["targets"]:
            self.assertAlmostEqual(toy["position"][1], eye[1] - 0.4 + 0.035, places=4)
        child.play_round(started, ["right"])
        self.assertTrue(self.round_ends(sim)[0]["success"])


if __name__ == "__main__":
    unittest.main()
