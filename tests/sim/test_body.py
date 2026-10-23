"""The simulated body refuses what a seated child cannot do, before anything reaches the engine."""

from dataclasses import replace
import math
import unittest

from support import Actor, Child, ConstraintError, SimCase, block, plan
from body import Body, add, load, sub, unit
from policy import Perception, Policy, view_factor
from child import perceptions

BODIES, LIMITS, _ = load()
RIG = {"position": [0, 0, 0], "x": [1, 0, 0], "y": [0, 1, 0], "z": [0, 0, 1]}


def first_hit(origin, at, toys):
    """The toy whose collision sphere a ray from `origin` towards `at` enters first."""
    direction = unit(sub(at, origin))
    hits = []
    for toy in toys:
        to = sub(tuple(toy["position"]), origin)
        along = sum(a * b for a, b in zip(to, direction))
        miss = math.sqrt(max(0.0, sum(a * a for a in to) - along * along))
        if along > 0 and miss <= toy["radius"]:
            hits.append((along - math.sqrt(toy["radius"] ** 2 - miss ** 2), toy))
    return min(hits, key=lambda hit: hit[0])[1]


class Recorder:
    """Stands in for the engine: answers observations, records everything sent."""

    def __init__(self, body):
        self.body = Body(body, LIMITS, RIG)
        self.sent = []

    def observe(self):
        hands = {side: {"position": list(self.body.rest(side)), "tracked": True} for side in ("left", "right")}
        head = {"position": list(self.body.neck), "forward": [0, 0, -1], "x": [1, 0, 0], "y": [0, 1, 0], "z": [0, 0, 1]}
        return {"rig": RIG, "head": head, "hands": hands}

    def __getattr__(self, op):
        return lambda *args, **kwargs: self.sent.append(op) or {"clear": True}


class Limits(unittest.TestCase):
    def setUp(self):
        self.body = Body(BODIES["medium"], LIMITS, RIG)

    def refuses(self, code, action):
        with self.assertRaises(ConstraintError) as refused:
            action()
        self.assertEqual(refused.exception.code, code, refused.exception)
        return refused.exception

    def test_reach_ends_at_the_arm(self):
        shoulder = self.body.shoulder("right")
        self.body.check_reach("right", add(shoulder, (0, 0, -BODIES["medium"].arm_length)))
        error = self.refuses("reach", lambda: self.body.check_reach("right", add(shoulder, (0, 0, -BODIES["medium"].arm_length - 0.001))))
        self.assertEqual(error.evidence["limit"], BODIES["medium"].arm_length)
        self.refuses("reach", lambda: self.body.check_reach("right", add(shoulder, (0, 0, -0.53)), comfortable=True))

    def test_every_body_reaches_its_own_ready_and_rest_poses(self):
        for profile in BODIES.values():
            body = Body(profile, LIMITS, RIG)
            for side in ("left", "right"):
                body.check_hand(side, body.ready(side))
                body.check_hand(side, body.rest(side))

    def test_hands_stay_out_of_the_torso(self):
        chest = self.body.world((0, BODIES["medium"].eye_height - 0.35, 0.02))
        self.refuses("torso", lambda: self.body.check_hand("right", chest))
        start, end = self.body.world((0.2, 0.75, -0.02)), self.body.world((-0.2, 0.75, -0.02))
        self.body.check_hand("right", start)
        self.refuses("torso", lambda: self.body.path("right", start, end))

    def test_head_turns_within_its_limits(self):
        eye = self.body.neck
        self.body.check_head(eye, unit((math.sin(math.radians(74)), 0, -math.cos(math.radians(74)))))
        self.refuses("head_yaw", lambda: self.body.check_head(eye, unit((math.sin(math.radians(76)), 0, -math.cos(math.radians(76))))))
        self.refuses("head_yaw", lambda: self.body.check_head(eye, (0, 0, 1)))
        self.refuses("head_pitch", lambda: self.body.check_head(eye, unit((0, -2, -1))))
        self.refuses("head_pitch", lambda: self.body.check_head(eye, unit((0, 1, -1))))
        self.refuses("head_lean", lambda: self.body.check_head(add(eye, (0.2, 0, 0)), (0, 0, -1)))

    def test_targets_must_be_in_view(self):
        head = Recorder(BODIES["medium"]).observe()["head"]
        self.body.check_view(head, add(self.body.neck, (0.3, -0.3, -0.6)))
        self.refuses("behind_head", lambda: self.body.check_view(head, add(self.body.neck, (0, 0, 0.5))))
        self.refuses("out_of_view", lambda: self.body.check_view(head, add(self.body.neck, (1.0, 0, -0.3))))

    def test_hands_move_no_faster_than_the_profile(self):
        start, end = (0, 1, -0.3), (0.25, 1, -0.3)
        self.assertGreater(self.body.hand_seconds(start, end), 0.25 / BODIES["medium"].hand_speed)
        self.body.hand_seconds(start, end, 0.13)
        self.refuses("hand_speed", lambda: self.body.hand_seconds(start, end, 0.05))

    def test_profiles_cannot_be_impossible(self):
        with self.assertRaises(ValueError):
            replace(BODIES["small"], comfortable_reach=1.0)
        with self.assertRaises(ValueError):
            replace(BODIES["small"], arm_length=0.0)

    def test_a_refused_action_sends_nothing(self):
        engine = Recorder(BODIES["small"])
        actor = Actor(engine, "small")
        setup = list(engine.sent)
        far = add(actor.body.neck, (0.1, -0.3, -0.9))
        self.refuses("reach", lambda: actor.touch("right", far, 0.05))
        self.refuses("head_yaw", lambda: actor.look_at(add(actor.body.neck, (0, 0, 1))))
        self.refuses("behind_head", lambda: actor.point("right", add(actor.body.neck, (0, 0, 1)), look=False))
        self.refuses("hand_speed", lambda: actor.sweep("right", (1, 0, 0), length=0.25, seconds=0.02))
        self.assertEqual(engine.sent[len(setup):], [], "every refusal came before any movement")


class TestDriver(unittest.TestCase):
    """The response policy is a seeded test driver; check it is repeatable and monotonic."""

    VIEW = {"title": "Normal", "brightness": 0, "contrast": 1, "saturation": 1, "black_and_white": False,
            "edges": [0, 0, 0, 0], "dim": 0, "focus_radius": 0}

    def toy(self, z, extent=0.07):
        return {"centre": (0, 0.75, z), "extent": (extent, extent, extent)}

    def test_the_same_seed_gives_the_same_answers(self):
        perception = perceptions()["typical"]
        runs = [[Policy(perception, 9).chance(0.5) for _ in range(50)] for _ in range(2)]
        self.assertEqual(runs[0], runs[1])
        self.assertNotEqual(runs[0], [Policy(perception, 10).chance(0.5) for _ in range(50)])

    def test_odds_follow_size_clutter_hints_and_coherence(self):
        policy = Policy(perceptions()["typical"], 1)
        eye = (0, 1.1, 0)
        near, far = self.toy(-0.3), self.toy(-0.3, extent=0.01)
        others = [self.toy(-0.5)] * 3
        def odds(target, others, hint=0, glow=False, view=self.VIEW):
            return policy.find_odds(eye, target, others, view, hint, glow, False, (0, 0.72, -0.55))
        self.assertGreater(odds(near, others), odds(far, others), "bigger is easier")
        self.assertGreater(odds(near, others[:1]), odds(near, others * 3), "fewer distractors is easier")
        self.assertGreater(odds(far, others, hint=1), odds(far, others), "a hop helps")
        self.assertGreater(odds(far, others, hint=2, glow=True), odds(far, others, hint=1), "a glow helps more")
        self.assertGreaterEqual(odds(far, others), 1 / 4, "never below a guess")
        dim = {**self.VIEW, "dim": 0.6}
        self.assertLess(view_factor(dim, False), view_factor(self.VIEW, False))
        self.assertEqual(view_factor({**dim, "focus_radius": 0.35}, True), 1.0, "a spotlight spares its centre")
        self.assertGreater(policy.motion_odds(0.9, "lateral", False), policy.motion_odds(0.2, "lateral", False))
        self.assertGreater(policy.motion_odds(0.4, "lateral", False), policy.motion_odds(0.4, "depth", False))
        self.assertTrue(0.25 <= policy.motion_odds(0.0, "lateral", False) < 0.27, "no signal: a four-way guess")

    def test_help_and_freezing(self):
        perception = perceptions()["typical"]
        policy = Policy(replace(perception, freeze=1.0, asks_help_after=2), 1)
        self.assertFalse(policy.freezes(can_time_out=False), "never stall a round without a time limit")
        self.assertTrue(policy.freezes(can_time_out=True))
        self.assertEqual([policy.wants_help(t) for t in range(1, 6)], [False, True, False, True, False])
        self.assertFalse(Policy(replace(perception, asks_help_after=0), 1).wants_help(5))
        self.assertIsInstance(perception, Perception)


class InTheRoom(SimCase):
    """Constraints that need the engine: the real table and objects are in the way."""

    def refused(self, code, action, *args):
        with self.assertRaises(ConstraintError) as refused:
            action(*args)
        self.assertEqual(refused.exception.code, code, refused.exception)
        return refused.exception

    def test_paths_through_the_table_are_caught(self):
        sim = self.launch(plan(block("find", rounds=1)))
        actor = Child(sim, body="medium", seed=1).actor
        sim.run_until("trial_started")
        before = sim.observe()["hands"]["right"]["position"]
        under = actor.body.world((0.15, 0.62, -0.32))  # under the table top, within the arm
        error = self.refused("path_blocked", actor.move_hand, "right", under, add(under, (0, -1, -1)))
        self.assertEqual(error.evidence["blocker"], "Table")
        self.assertEqual(sim.observe()["hands"]["right"]["position"], before, "the hand never moved")

    def test_reaching_into_a_real_object_is_caught(self):
        sim = self.launch(plan(block("point_real", rounds=1)), seat=(1.0, -0.8, 90), body="large")
        actor = Child(sim, body="large", seed=2).actor
        bottle = [o for o in sim.observe()["real_objects"] if o["label"] == "bottle"][0]
        error = self.refused("path_blocked", actor.move_hand, "left", tuple(bottle["centre"]), (0, 0.8, -0.8))
        self.assertEqual(error.evidence["blocker"], "Bottle")

    def test_far_toys_are_out_of_reach_but_can_be_pointed_at(self):
        sim = self.launch(plan(block("find", rounds=1, difficulty=1.0)), body="small")
        actor = Child(sim, body="small", seed=3).actor
        sim.run_until("trial_started")
        toys = sim.observe()["stimuli"]["targets"]
        far = [t for t in toys if math.dist(actor.body.shoulder("right"), t["centre"]) > BODIES["small"].arm_length + 0.1]
        self.assertTrue(far, "ten toys on the table: some lie beyond a small arm")
        self.refused("reach", actor.touch, "right", tuple(far[0]["centre"]), far[0]["radius"])
        self.assertEqual(sim.events("touched"), [])
        self.assertLess(math.dist(sim.observe()["hands"]["right"]["position"], actor.body.rest("right")), 1e-5)
        actor.point("right", tuple(far[0]["centre"]))
        expected = first_hit(actor.body.ready("right"), tuple(far[0]["centre"]), toys)
        self.assertEqual(sim.events("selected")[-1]["target"], expected["id"],
                         "the ray reaches what the arm cannot, stopping at the first toy on its way")

    def test_things_behind_or_beside_the_head_cannot_be_pointed_at(self):
        sim = self.launch(plan(block("point_real", rounds=1)))
        actor = Child(sim, seed=4).actor
        behind = add(actor.body.neck, (0, 0, 1.5))
        self.refused("head_yaw", actor.look_at, behind)
        self.refused("behind_head", actor.point, "right", behind)  # turned as far as the neck goes
        self.refused("behind_head", actor.point, "right", behind, False)
        actor.look_at((0, 0.75, -0.8))
        aside = (1.5, 1.0, -0.7)
        self.refused("out_of_view", actor.point, "right", aside, False)
        self.assertEqual(sim.events("selected"), [], "no trigger was pulled")
        actor.point("right", aside)  # after turning to look, it works
        self.assertEqual(len(sim.events("selected")), 1)


if __name__ == "__main__":
    unittest.main()
