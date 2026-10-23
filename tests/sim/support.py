"""Shared setup for the scenario suite: whole sessions on the real app, headless, lockstep."""

from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools" / "sim"))

from actor import Actor, Facilitator  # noqa: E402,F401
from body import ConstraintError, load  # noqa: E402,F401
from child import Child  # noqa: E402,F401
from client import Sim, block, plan  # noqa: E402,F401
import research_log  # noqa: E402


class SimCase(unittest.TestCase):
    """Each test launches its own app on its own test profile and always shuts it down."""

    def launch(self, plan_spec="demo", profile=None, body="medium", **options):
        """Boots the app with the child (`body`) already seated, eyes at its height."""
        profile = profile or "test_sim_" + self.id().split(".")[-1].removeprefix("test_")[:40]
        options.setdefault("eye", load()[0][body].eye_height)
        sim = Sim(plan_spec, profile=profile, **options)
        sim.start()
        self.addCleanup(sim.close)
        return sim

    def round_ends(self, sim):
        return sim.events("trial_ended")

    def reports(self, sim, what):
        return [e["data"] for e in sim.events("reported", what)]

    def assert_log_ok(self, sim):
        lines = research_log.read(sim.observe()["log_path"])
        self.assertEqual(research_log.problems(lines), [])
        return lines

    def assert_close(self, actual, expected, tolerance, what=""):
        self.assertLessEqual(abs(actual - expected), tolerance, f"{what}: {actual} vs {expected}")
