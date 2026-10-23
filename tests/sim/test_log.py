"""The research log and the child's profile, as files on disk."""

import json
from pathlib import Path
import unittest

from support import Child, SimCase, block, plan, research_log


class ResearchLog(SimCase):
    def test_a_whole_session_logs_every_round_attributably(self):
        sim = self.launch(plan(block("find", rounds=3, probe=True, difficulty=0.3), block("find", rounds=3, view="greyscale"),
                               block("point_real", rounds=2), block("motion", rounds=2)))
        Child(sim, perception="typical", seed=8).play()
        lines = self.assert_log_ok(sim)
        header = lines[0]
        self.assertEqual((header["profile"], header["reality"]), (sim.profile, "sim"))
        self.assertEqual([line["index"] for line in lines if line["type"] == "block"], [0, 1, 2, 3])
        view = None
        for line in lines:
            if line["type"] == "view":
                view = line["view"]
            if line["type"] == "trial_end":
                data = line["data"]
                self.assertEqual(data["view"], view, "each round logs the view it ran under")
                self.assertEqual(data["skill"], line["skill"])
                if not line["success"]:
                    self.assertTrue(data["timed_out"], "only the clock ends a round unsolved")
                    continue  # its picks / attempts are not logged (reported as a gap)
                {"find": lambda: self.assertEqual(data["picks"][-1], data["values"]["target"]),
                 "point_real": lambda: self.assertEqual(data["object"], data["values"]["object"]),
                 "motion": lambda: self.assertIsInstance(data["attempts"][0]["direction"], list)}[data["trial"]]()
        hints = [line["data"] for line in lines if line["type"] == "event" and line["what"] == "hint"]
        self.assertTrue(all({"trial", "level"} <= hint.keys() for hint in hints))
        levels = [line for line in lines if line["type"] == "event" and line["what"] == "level"]
        self.assertEqual(len(levels), 7, "every scored training round, no check-in")
        self.assertEqual(lines[-1]["type"], "session_end")

    def test_the_checker_catches_broken_logs(self):
        good = [{"type": "session", "profile": "test", "reality": "sim", "time": 1},
                {"type": "trial_start", "trial": "find", "condition": self.condition(), "time": 2},
                {"type": "trial_end", "skill": "s", "success": True, "time": 3,
                 "data": {**self.condition(), "seconds": 1.0, "tries": 0, "hint": 0, "first_try": True}},
                {"type": "event", "what": "level", "time": 3,
                 "data": {"skill": "s", "first_try": True, "before": 0.3, "after": 0.4}}]
        self.assertEqual(research_log.problems(good), [])
        cases = {
            "first_try disagrees": lambda lines: lines[2]["data"].update(tries=1),
            "level report disagrees": lambda lines: lines[3]["data"].update(first_try=False),
            "not a 2-up / 1-down step": lambda lines: lines[3]["data"].update(after=0.6),
            "a probe round moved the level": lambda lines: lines[2]["data"].update(probe=True),
            "lacks": lambda lines: lines[2]["data"].pop("hint"),
            "without its trial_start": lambda lines: lines.pop(1),
            "time goes backwards": lambda lines: lines[3].update(time=0),
        }
        for problem, corrupt in cases.items():
            lines = json.loads(json.dumps(good))
            corrupt(lines)
            self.assertTrue(any(problem in found for found in research_log.problems(lines)), problem)

    @staticmethod
    def condition():
        view = dict.fromkeys(research_log.VIEW, 0)
        return {"trial": "find", "skill": "s", "level": 0.3, "round": 0, "probe": False, "view": view, "values": {}}


class Profiles(SimCase):
    def progress(self, sim):
        return json.loads((Path(sim.profile_dir) / "progress.json").read_text(encoding="utf-8"))

    def test_levels_persist_across_a_relaunch(self):
        spec = plan(block("find", rounds=2))
        first = self.launch(spec, profile="test_sim_persist")
        Child(first, seed=1).play(scripts={"find": ["right"]})
        self.assertAlmostEqual(first.observe()["levels"]["objects_in_clutter"], 0.4)
        first_log = first.observe()["log_path"]
        first.close(keep_profile=True)
        again = self.launch(spec, profile="test_sim_persist", keep_profile=True)
        self.assertAlmostEqual(again.observe()["levels"]["objects_in_clutter"], 0.4, msg="read back from progress.json")
        Child(again, seed=2).play(scripts={("find", 0): ["right"], ("find", 1): ["wrong", "right"]})
        self.assertEqual([round(e["data"]["level"], 6) for e in self.round_ends(again)], [0.4, 0.4])
        self.assertAlmostEqual(self.progress(again)["levels"]["objects_in_clutter"], 0.3)
        logs = sorted((Path(again.profile_dir) / "logs").glob("*.jsonl"))
        sessions = [line for path in logs for line in research_log.read(path) if line["type"] == "session"]
        self.assertEqual(len(sessions), 2, "both runs are in the profile's logs")
        self.assertTrue(Path(first_log).exists())

    def test_two_profiles_stay_separate(self):
        spec = plan(block("find", rounds=2))
        asha = self.launch(spec, profile="test_sim_asha")
        Child(asha, seed=1).play(scripts={"find": ["right"]})
        ravi = self.launch(spec, profile="test_sim_ravi")
        Child(ravi, seed=2).play(scripts={"find": ["wrong", "right"]})
        self.assertAlmostEqual(self.progress(asha)["levels"]["objects_in_clutter"], 0.4)
        self.assertAlmostEqual(self.progress(ravi)["levels"]["objects_in_clutter"], 0.1)
        self.assertNotEqual(asha.profile_dir, ravi.profile_dir)
        for sim in (asha, ravi):
            lines = self.assert_log_ok(sim)
            self.assertEqual(lines[0]["profile"], sim.profile)
            self.assertTrue(Path(sim.observe()["log_path"]).is_relative_to(sim.profile_dir))


if __name__ == "__main__":
    unittest.main()
