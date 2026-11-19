"""tools/progress.py: reads Godot's typed save JSON and the logs, and writes the staff report."""

import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
import progress  # noqa: E402


def typed(value):
    """Plain Python as Godot's JSON.from_native writes it (the subset saves use)."""
    if isinstance(value, bool) or value is None:
        return value
    if isinstance(value, str):
        return "s:" + value
    if isinstance(value, int):
        return f"i:{value}"
    if isinstance(value, float):
        return f"f:{value}"
    if isinstance(value, list):
        return [typed(item) for item in value]
    args = []
    for key, item in value.items():
        args += ["sn:" + key, typed(item)]
    return {"type": "Dictionary", "args": args}


class Report(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        folder = self.root / "profiles" / "s1"
        (folder / "logs").mkdir(parents=True)
        (self.root / "profiles.cfg").write_text('[profiles]\n\nsaves=["s1"]\n\n[names]\n\ns1="Asha"\n')
        week = 7 * 86400.0
        history = [{"place": "table", "title": "Alchemy table", "time": 1.79e9 + i * week, "done": True,
                    "scores": {"visual_matching": {"rounds": 3, "right": right, "levels": {"0.00": [1, 1]}}}}
                   for i, right in enumerate([1, 3])]
        history.append({"place": "table", "title": "Alchemy table", "time": 1.79e9 + 3 * week, "done": False, "scores": {}})
        save = {"version": 1, "nodes": {"levels": {"levels": {"visual_matching": 0.4}, "streaks": {}},
                                        "check_ins": {"history": history, "asked": []},
                                        "vision": {"view": {"title": "High contrast"}, "size_scale": 1.5, "revision": 2}}}
        (folder / "save.json").write_text(json.dumps(typed(save)))
        lines = [{"type": "session", "time": 1.79e9},
                 {"type": "trial_end", "skill": "visual_matching", "success": True, "time": 1.79e9 + 60,
                  "data": {"first_try": True, "hint": 0, "probe": False, "seconds": 12.0}},
                 {"type": "trial_end", "skill": "visual_matching", "success": True, "time": 1.79e9 + 120,
                  "data": {"first_try": False, "hint": 1, "probe": True, "seconds": 20.0}},
                 {"type": "event", "what": "level", "time": 1.79e9 + 60,
                  "data": {"skill": "visual_matching", "before": 0.3, "after": 0.4}},
                 {"type": "event", "what": "task_done", "time": 1.79e9 + 130, "data": {}}]
        (folder / "logs" / "a.jsonl").write_text("\n".join(json.dumps(line) for line in lines) + "\n{cut off")
        (self.root / "profiles" / "test_s1").mkdir()

    def test_godot_typed_json_reads_as_plain_python(self):
        self.assertEqual(progress.native({"type": "Dictionary", "args": ["sn:a", "f:0.5", "s:b", ["i:2", True]]}),
                         {"a": 0.5, "b": [2, True]})

    def test_a_child_from_their_save_and_logs(self):
        kids = progress.children(self.root, tests=False)
        self.assertEqual([kid["name"] for kid in kids], ["Asha"], "named as staff named the save; test saves left out")
        kid = kids[0]
        self.assertEqual(len(kid["check_ins"]), 3)
        self.assertEqual(kid["practice"]["visual_matching"]["rounds"], 1, "check-in rounds are not practice")
        self.assertEqual([level for _, level in kid["levels"]["visual_matching"]], [0.4], "the level at the end of the day")
        self.assertEqual(kid["finished"], 1)
        self.assertEqual(kid["vision"]["size_scale"], 1.5)

    def test_the_page_shows_check_ins_and_leaves_out_unfinished_ones(self):
        page = progress.page(progress.children(self.root, tests=False), "a test")
        self.assertIn("Asha", page)
        self.assertIn("Shapes on the shelf", page)
        self.assertIn("1 check-in was started but not finished", page)
        self.assertEqual(page.count("<tr><td>"), 3, "two finished check-ins and one practice row")
        self.assertIn("High contrast", page)


if __name__ == "__main__":
    unittest.main()
