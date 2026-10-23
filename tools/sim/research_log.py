"""Checks a research log (user://profiles/<id>/logs/*.jsonl) against what the framework promises."""

import json
from pathlib import Path

VIEW = {"title", "brightness", "contrast", "saturation", "black_and_white", "edges", "dim", "focus_radius"}
CONDITION = {"trial", "skill", "level", "round", "probe", "view", "values"}
ROUND_END = CONDITION | {"seconds", "tries", "hint", "first_try"}
REQUIRED = {
    "session": {"profile", "reality", "time"},
    "block": {"index", "info", "time"},
    "trial_start": {"trial", "condition", "time"},
    "trial_end": {"skill", "success", "data", "time"},
    "view": {"view", "time"},
    "event": {"what", "data", "time"},
    "session_end": {"time"},
}


def read(path):
    """Every line, parsed. A line that is not JSON raises."""
    return [json.loads(line) for line in Path(path).read_text(encoding="utf-8").splitlines()]


def problems(lines, step=0.1):
    """Everything wrong with one log file, as sentences. Empty = fine."""
    found = []
    if not lines or lines[0].get("type") != "session":
        found.append("the first line is not the session header")
    last_end = None
    open_rounds = {}
    for number, line in enumerate(lines, 1):
        kind = line.get("type")
        missing = REQUIRED.get(kind, {"?"}) - line.keys()
        if kind not in REQUIRED or missing:
            found.append(f"line {number}: {kind} lacks {sorted(missing)}")
            continue
        if number > 1 and line["time"] < lines[number - 2]["time"]:
            found.append(f"line {number}: time goes backwards")
        if kind == "view" and VIEW - line["view"].keys():
            found.append(f"line {number}: view lacks {sorted(VIEW - line['view'].keys())}")
        if kind == "trial_start":
            condition = line["condition"]
            if CONDITION - condition.keys() or VIEW - condition["view"].keys():
                found.append(f"line {number}: trial_start condition is incomplete")
            open_rounds[(condition["trial"], condition["round"])] = number
        if kind == "trial_end":
            data = line["data"]
            if ROUND_END - data.keys() or VIEW - data["view"].keys():
                found.append(f"line {number}: trial_end lacks {sorted(ROUND_END - data.keys())}")
                continue
            if open_rounds.pop((data["trial"], data["round"]), None) is None:
                found.append(f"line {number}: trial_end without its trial_start")
            if data["first_try"] != (line["success"] and data["tries"] == 0 and data["hint"] == 0):
                found.append(f"line {number}: first_try disagrees with success, tries and hint")
            if data["probe"] and data["hint"]:
                found.append(f"line {number}: a probe round got help")
            last_end = line
        if kind == "event" and line["what"] == "round_abandoned":
            open_rounds.pop((line["data"]["trial"], line["data"]["round"]), None)
        if kind == "event" and line["what"] == "level":
            level = line["data"]
            if last_end is None or lines[number - 2] is not last_end:
                found.append(f"line {number}: a level change that does not follow a round")
                continue
            if last_end["data"]["probe"]:
                found.append(f"line {number}: a probe round moved the level")
            if level["skill"] != last_end["skill"] or level["first_try"] != last_end["data"]["first_try"]:
                found.append(f"line {number}: level report disagrees with its round's first_try")
            expected = [max(0.0, level["before"] - step)] if not level["first_try"] \
                else [level["before"], min(1.0, level["before"] + step)]
            if not any(abs(level["after"] - value) < 1e-6 for value in expected):
                found.append(f"line {number}: level {level['before']} -> {level['after']} is not a 2-up / 1-down step")
    return found
