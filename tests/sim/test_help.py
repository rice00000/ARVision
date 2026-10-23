"""Help that arrives by itself and fades, help on B / Y, none in check-ins, and time limits."""

import unittest

from support import Child, SimCase, block, plan

FRAME = 1 / 60


class Help(SimCase):
    def hint_times(self, sim, started):
        """Seconds from a round's start to each of its hints."""
        later = sim.events("reported", "hint", since=started["seq"])
        end = next(e for e in sim.events(since=started["seq"]) if e["event"] == "trial_ended")
        return [round(e["t"] - started["t"], 3) for e in later if e["seq"] < end["seq"]]

    def test_help_escalates_by_itself_and_fades_round_by_round(self):
        sim = self.launch(plan(block("find", rounds=3)))
        child = Child(sim, seed=1)
        starts = []
        for _ in range(3):
            starts.append(sim.run_until("trial_started"))
            child.play_round(starts[-1], ["freeze"])
        trial = sim.observe()["session"]["trial"]
        hint_after, fade, limit = trial["hint_after"], trial["hint_fade"], trial["time_limit"]
        for index, started in enumerate(starts):
            first = hint_after + fade * index
            times = self.hint_times(sim, started)
            self.assertEqual(len(times), 2, f"round {index}: two levels, then no more ({times})")
            self.assert_close(times[0], first, 2 * FRAME, f"round {index} first hint")
            self.assert_close(times[1], 2 * first, 2 * FRAME, f"round {index} second hint")
        ends = self.round_ends(sim)
        for end, started in zip(ends, starts):
            self.assertFalse(end["success"])
            self.assertTrue(end["data"]["timed_out"])
            self.assertEqual(end["data"]["hint"], 2)
            self.assert_close(end["t"] - started["t"], limit, 2 * FRAME, "time limit")
        self.assertEqual([round(lv["after"], 6) for lv in self.reports(sim, "level")], [0.2, 0.1, 0.0],
                         "a timed-out round is a miss")
        self.assert_log_ok(sim)

    def test_a_wrong_try_restarts_the_hint_clock(self):
        sim = self.launch(plan(block("find", rounds=1)))
        child = Child(sim, seed=2)
        started = sim.run_until("trial_started")
        child.play_round(started, ["wait:2", "wrong", "freeze"])
        wrong = next(e for e in sim.events("feedback", since=started["seq"]) if e["kind"] == "bad")
        hint = sim.events("reported", "hint", since=started["seq"])[0]
        self.assertTrue(2.0 < wrong["t"] - started["t"] < 7.0, "wrong before the first hint was due")
        self.assert_close(hint["t"] - wrong["t"], 7.0, 2 * FRAME, "a child who tries is not stuck")

    def test_b_and_y_ask_for_the_next_level_at_once(self):
        sim = self.launch(plan(block("find", rounds=1)))
        child = Child(sim, seed=3)
        started = sim.run_until("trial_started")
        child.actor.help("right")  # B
        first = sim.observe()["stimuli"]
        self.assertEqual(sim.observe()["session"]["trial"]["hint"], 1)
        child.actor.wait(1.0)
        moved = sim.observe()["stimuli"]
        named = [t for t in first["targets"] if t["id"].endswith("_" + first["named"])][0]
        named_now = [t for t in moved["targets"] if t["id"] == named["id"]][0]
        self.assertNotEqual(named["position"][1], named_now["position"][1], "hint 1: the named toy hops")
        child.actor.help("left")  # Y
        observation = sim.observe()
        self.assertEqual(observation["session"]["trial"]["hint"], 2)
        glowing = [t["id"] for t in observation["stimuli"]["targets"] if t["glow"]]
        self.assertEqual(glowing, [named["id"]], "hint 2: only the named toy glows")
        self.assertRegex(sim.events("said")[-1]["text"], r"^Look for the \w+, on your (left|right|front)\.$")
        child.actor.help("right")
        self.assertEqual(sim.observe()["session"]["trial"]["hint"], 2, "no level above max_hint")
        self.assertEqual(len(self.reports(sim, "help_asked")), 3)
        self.assertEqual([h["level"] for h in self.reports(sim, "hint")], [1, 2])
        self.assertEqual([f["kind"] for f in sim.events("feedback")], ["hint", "hint"])
        child.play_round(started, ["right"])
        end = self.round_ends(sim)[0]
        self.assertTrue(end["success"])
        self.assertEqual(end["data"]["hint"], 2)
        self.assertFalse(end["data"]["first_try"])

    def test_check_ins_get_no_help_but_still_time_out(self):
        sim = self.launch(plan(block("find", rounds=1, probe=True, difficulty=0.3)))
        child = Child(sim, seed=4)
        started = sim.run_until("trial_started")
        child.play_round(started, ["help", "wait:20", "help", "freeze"])
        end = self.round_ends(sim)[0]
        self.assertTrue(end["data"]["timed_out"] and not end["success"])
        self.assertEqual(self.reports(sim, "hint"), [])
        self.assertEqual(end["data"]["hint"], 0)
        self.assertEqual(self.reports(sim, "level"), [])

    def test_motion_help_comes_only_when_asked(self):
        sim = self.launch(plan(block("motion", rounds=1, difficulty=1.0, pins={"direction": 2})))
        child = Child(sim, seed=5)
        started = sim.run_until("trial_started")
        child.actor.wait(30)
        self.assertEqual(self.reports(sim, "hint"), [], "no help by itself")
        cloud = sim.observe()["stimuli"]["cloud"]
        self.assertEqual(cloud["signal_count"], 30)
        child.actor.help("left")
        cloud = sim.observe()["stimuli"]["cloud"]
        self.assertEqual(cloud["signal_count"], cloud["dot_count"], "help: every dot follows the flow")
        child.play_round(started, ["right"])
        self.assertEqual(self.round_ends(sim)[0]["data"]["hint"], 1)

    def test_motion_check_in_ignores_help(self):
        sim = self.launch(plan(block("motion", rounds=1, probe=True, difficulty=0.5)))
        child = Child(sim, seed=6)
        started = sim.run_until("trial_started")
        before = sim.observe()["stimuli"]["cloud"]["signal_count"]
        child.actor.help()
        self.assertEqual(sim.observe()["stimuli"]["cloud"]["signal_count"], before)
        child.play_round(started, ["right"])
        self.assertEqual(self.round_ends(sim)[0]["data"]["hint"], 0)

    def test_real_objects_time_out_after_their_limit(self):
        sim = self.launch(plan(block("point_real", rounds=1)))
        child = Child(sim, seed=7)
        started = sim.run_until("trial_started")
        child.play_round(started, ["freeze"])
        end = self.round_ends(sim)[0]
        self.assertTrue(end["data"]["timed_out"])
        self.assert_close(end["t"] - started["t"], 60.0, 2 * FRAME, "point_real time limit")
        self.assertEqual(end["data"]["hint"], 2)
        self.assertTrue(sim.events("reported", "hint"))


if __name__ == "__main__":
    unittest.main()
