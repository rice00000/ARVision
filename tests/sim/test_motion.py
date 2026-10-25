"""Read the flow, swept by a seated body: directions, hands, invalid sweeps, pauses, tracking loss."""

import unittest

from support import Child, Facilitator, SimCase, block, plan
from body import add, mul
from policy import FLOWS

HEADINGS = ["right", "left", "toward", "away"]


class Motion(SimCase):
    def cloud_direction(self, sim, heading):
        return Child.world(sim.observe()["stimuli"]["cloud"], FLOWS[heading])

    def motion_reports(self, sim):
        return [e for e in sim.events("reported") if e["what"].startswith("motion_")]

    def test_every_direction_with_both_hands(self):
        for body in ("small", "large"):
            sim = self.launch(plan(*[block("motion", rounds=2, pins={"direction": d}, pause_between=2.0)
                                     for d in (1, 2, 3, 4)]), profile=f"test_sim_motion_{body}", body=body)
            Child(sim, body=body, seed=1).play(scripts={"motion": ["right"]})
            ends = self.round_ends(sim)
            self.assertEqual([e["data"]["values"]["heading"] for e in ends], [h for h in HEADINGS for _ in (0, 1)])
            self.assertEqual([e["data"]["attempts"][0]["hand"] for e in ends], ["right", "left"] * 4)
            for end in ends:
                self.assertTrue(end["success"] and end["data"]["first_attempt_correct"] and end["data"]["first_try"])
                self.assertLess(end["data"]["angle_degrees"], 1.0)
                self.assertGreaterEqual(end["data"]["attempts"][0]["distance_metres"], 0.24)
            self.assert_log_ok(sim)

    def test_invalid_sweeps_count_no_try(self):
        sim = self.launch(plan(block("motion", pins={"direction": 1})), body="large")
        child = Child(sim, body="large", seed=2)
        sim.run_until("trial_started")
        actor = child.actor
        right = self.cloud_direction(sim, "right")
        actor.sweep("right", right, length=0.05, seconds=0.08)  # brisk but too small
        actor.sweep("left", (0, 1, 0), length=0.2)  # up: a hand raised, not an answer
        invalid = self.reports(sim, "motion_invalid")
        self.assertEqual([r["reason"] for r in invalid], ["too_small", "vertical"])
        self.assertEqual([r["hand"] for r in invalid], ["right", "left"])
        self.assertEqual(sim.events("feedback"), [], "no right or wrong for an unusable sweep")
        said = [e["text"] for e in sim.events("said")]
        self.assertEqual(said[-1], "Sweep your hand a little farther.")
        self.assertEqual(said.count("Sweep your hand a little farther."), 1, "nothing said of a vertical move")
        trial = sim.observe()["session"]["trial"]
        self.assertTrue(trial["running"])
        self.assertEqual(trial["tries"], 0)
        actor.sweep("right", right)
        end = self.round_ends(sim)[0]
        self.assertEqual(end["data"]["invalid_gestures"], 2)
        self.assertTrue(end["data"]["first_attempt_correct"] and end["data"]["first_try"])

    def test_a_wave_back_is_part_of_no_sweep(self):
        sim = self.launch(plan(block("motion", pins={"direction": 1}, pause_between=2.0)))
        child = Child(sim, seed=6)
        sim.run_until("trial_started")
        actor = child.actor
        right = self.cloud_direction(sim, "right")
        ready = actor.body.ready("right")
        aim = actor.body.direction((0, -0.3, -1))
        start, end = add(ready, mul(right, -0.125)), add(ready, mul(right, 0.125))
        actor.creep("right", start, at=add(start, aim))
        actor.move_hand("right", end, at=add(end, aim), seconds=0.3)
        actor.move_hand("right", start, at=add(start, aim), seconds=0.3)  # straight back, no stop
        actor.wait(0.4)
        attempts = self.reports(sim, "motion_attempt")
        self.assertEqual(len(attempts), 1, "the sweep out was judged, the way back was not")
        self.assertTrue(attempts[0]["correct"])
        self.assertTrue(self.round_ends(sim)[0]["success"])

    def test_wrong_sweeps_count_tries_and_the_stimulus_stays(self):
        sim = self.launch(plan(block("motion", pins={"direction": 3}, pause_between=2.0)))
        child = Child(sim, seed=3)
        started = sim.run_until("trial_started")
        child.actor.sweep("right", self.cloud_direction(sim, "away"))
        child.actor.sweep("left", self.cloud_direction(sim, "right"))
        trial = sim.observe()["session"]["trial"]
        self.assertEqual(trial["tries"], 2)
        self.assertEqual(trial["condition"]["values"]["seed"], started["condition"]["values"]["seed"])
        child.actor.sweep("right", self.cloud_direction(sim, "toward"))
        end = self.round_ends(sim)[0]
        self.assertEqual([a["correct"] for a in end["data"]["attempts"]], [False, False, True])
        self.assertEqual([f["kind"] for f in sim.events("feedback")], ["bad", "bad", "good"])
        self.assertFalse(end["data"]["first_try"])
        sim.wait(0.7)
        self.assertEqual(sim.observe()["stimuli"]["cloud"]["alignment"], 1.0, "success: the dots align into streaks")

    def half_sweep(self, actor, side, direction):
        """A hand halfway through a sweep, still moving. Returns the end point and where to aim."""
        ready = actor.body.ready(side)
        start, end = add(ready, mul(direction, -0.125)), add(ready, mul(direction, 0.125))
        aim = add(start, actor.body.direction((0, -0.3, -1)))
        actor.creep(side, start, at=aim)
        actor.move_hand(side, ready, at=aim, seconds=0.2)
        return end, aim

    def test_a_pause_cancels_an_unfinished_sweep(self):
        sim = self.launch(plan(block("motion", pins={"direction": 2})))
        child = Child(sim, seed=4)
        facilitator = Facilitator(sim)
        sim.run_until("trial_started")
        left = self.cloud_direction(sim, "left")
        end, aim = self.half_sweep(child.actor, "right", left)
        facilitator.open()
        child.actor.move_hand("right", end, at=aim, seconds=0.2)  # finished while paused
        sim.wait(0.3)
        facilitator.press("fac_close")
        sim.wait(0.4)
        self.assertEqual(self.motion_reports(sim), [], "a sweep through a pause is never judged")
        self.assertTrue(sim.observe()["session"]["trial"]["running"])
        child.actor.sweep("left", left)
        self.assertTrue(self.round_ends(sim)[0]["success"], "the next sweep counts")

    def test_tracking_loss_cancels_an_unfinished_sweep(self):
        sim = self.launch(plan(block("motion", pins={"direction": 1})))
        child = Child(sim, seed=5)
        sim.run_until("trial_started")
        right = self.cloud_direction(sim, "right")
        end, aim = self.half_sweep(child.actor, "right", right)
        child.actor.lose_tracking("right")
        sim.wait(0.2)
        self.assertFalse(sim.observe()["hands"]["right"]["tracked"])
        child.actor.regain_tracking("right")
        sim.wait(0.1)
        child.actor.creep("right", end, at=aim)
        sim.wait(0.3)
        self.assertEqual([(e["hand"], e["tracked"]) for e in sim.events("hand_tracking")][-2:],
                         [("right", False), ("right", True)])
        self.assertEqual(self.motion_reports(sim), [], "a sweep through a tracking loss is dropped")
        end, aim = self.half_sweep(child.actor, "right", right)
        child.actor.lose_tracking("left")  # the other hand does not matter
        sim.wait(0.1)
        child.actor.move_hand("right", end, at=aim, seconds=0.1)
        sim.wait(0.4)
        self.assertTrue(self.round_ends(sim)[0]["success"])


if __name__ == "__main__":
    unittest.main()
