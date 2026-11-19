"""A progress report for staff: one page, a section per child (save), from the saves and logs.

    python3 tools/progress.py local     # this computer's desktop runs
    python3 tools/progress.py pull      # from the Quest (adb), every save on the headset
    python3 tools/progress.py local --root <folder>   # a copy of ARVision's user data

Writes build/progress/index.html (open it in a browser; it needs no internet) and
build/progress/progress.csv (every check-in, one row per skill, for a spreadsheet).

What it shows per child:
  check-ins     no-help rounds on things the child never trains on (modules/check_ins):
                the score per skill over time, the clearest sign of change
  training      each skill's level (0 easiest .. 1 hardest) as the staircase moved it
  practice      rounds played, right first time, help used, per skill
  vision        the child's current vision profile (core/vision.gd)
Test saves (names starting "test") are left out unless --tests.
"""

import argparse
import csv
import html
import io
import json
import os
import subprocess
import sys
import tarfile
import tempfile
from collections import defaultdict
from datetime import datetime
from pathlib import Path

import godot

PACKAGE = "edu.mit.arvision"
OUT = godot.ROOT / "build" / "progress"

SKILL_NAMES = {
    "visual_matching": "Shapes on the shelf",
    "colour_discrimination": "Odd colour",
    "global_motion": "Moving dots",
    "global_motion_competing": "Dots against dots",
    "butterfly_catch": "Catching butterflies",
    "butterfly_swarm": "Butterfly swarm",
    "objects_in_clutter": "Find it",
    "real_object_recognition": "Real objects",
    "desk_outline_matching": "Ready to study",
    "bookshelf_shape_matching": "Bookshelf",
    "sandwich_spatial_order": "Sandwich",
}
COLOURS = ["#2a6fdb", "#d9822b", "#2f9e6a", "#b54aa8", "#c43d3d", "#5c6bc0", "#8d6e3f", "#00838f"]


def skill_name(skill):
    """A level's own staircase ("visual_matching.similar_shadows") reads "Shapes on the shelf · Similar shadows"."""
    base, _, level = skill.partition(".")
    name = SKILL_NAMES.get(base, base.replace("_", " ").capitalize())
    return f"{name} · {level.replace('_', ' ').capitalize()}" if level else name


def user_data():
    """Godot's user:// for ARVision on this computer."""
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Application Support" / "Godot" / "app_userdata" / "ARVision"
    if sys.platform == "win32":
        return Path(os.environ["APPDATA"]) / "Godot" / "app_userdata" / "ARVision"
    return Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local" / "share")) / "godot" / "app_userdata" / "ARVision"


def pull(into):
    from frames import adb
    tar = subprocess.run([adb(), "exec-out", "run-as", PACKAGE, "tar", "-C", "files", "-cf", "-", "profiles", "profiles.cfg"],
                         capture_output=True, check=True).stdout
    with tarfile.open(fileobj=io.BytesIO(tar)) as archive:
        archive.extractall(into, filter="data")
    return Path(into)


# -- reading ------------------------------------------------------------------------

def native(value):
    """Godot's JSON.from_native encoding ("s:", "sn:", "i:", "f:", typed containers) as plain Python."""
    if isinstance(value, str):
        kind, _, rest = value.partition(":")
        if kind in ("s", "sn"):
            return rest
        if kind == "i":
            return int(rest)
        if kind == "f":
            return float(rest)
        return value
    if isinstance(value, list):
        return [native(item) for item in value]
    if isinstance(value, dict) and "type" in value:
        args = value.get("args", [])
        if value["type"] == "Dictionary":
            return {native(args[i]): native(args[i + 1]) for i in range(0, len(args), 2)}
        return [native(item) for item in args]
    return value


def names(root):
    """Save id -> the name staff gave it (user://profiles.cfg)."""
    found, section = {}, ""
    path = root / "profiles.cfg"
    if path.exists():
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("["):
                section = line.strip("[]")
            elif section == "names" and "=" in line:
                key, _, value = line.partition("=")
                found[key.strip().strip('"')] = json.loads(value.strip())
    return found


def read_save(folder):
    path = folder / "save.json"
    if not path.exists():
        return {}
    data = native(json.loads(path.read_text(encoding="utf-8")))
    return data.get("nodes", {}) if isinstance(data, dict) else {}


def read_logs(folder):
    lines = []
    for path in sorted((folder / "logs").glob("*.jsonl")):
        session = []
        for text in path.read_text(encoding="utf-8").splitlines():
            try:
                session.append(json.loads(text))
            except json.JSONDecodeError:
                continue # a line cut off when the app closed
        if session:
            lines.append(session)
    return lines


def child(folder, label):
    save = read_save(folder)
    sessions = read_logs(folder)
    levels = defaultdict(list)          # skill -> [(time, level)]
    practice = defaultdict(lambda: {"rounds": 0, "first_try": 0, "help": 0, "seconds": 0.0})
    finished, minutes, days = 0, 0.0, set()
    for session in sessions:
        times = [line["time"] for line in session if "time" in line]
        if times:
            minutes += (max(times) - min(times)) / 60.0
            days.add(datetime.fromtimestamp(min(times)).date())
        for line in session:
            if line.get("type") == "event" and line.get("what") == "level":
                data = line["data"]
                if not levels[data["skill"]]:
                    levels[data["skill"]].append((line["time"], data["before"]))
                levels[data["skill"]].append((line["time"], data["after"]))
            elif line.get("type") == "event" and line.get("what") in ("level_set",):
                levels[line["data"]["skill"]].append((line["time"], line["data"]["after"]))
            elif line.get("type") == "event" and line.get("what") == "task_done":
                finished += 1
            elif line.get("type") == "trial_end" and not line["data"].get("probe"):
                p = practice[line["skill"]]
                p["rounds"] += 1
                p["first_try"] += int(bool(line["data"].get("first_try")))
                p["help"] += int(line["data"].get("hint", 0) > 0)
                p["seconds"] += float(line["data"].get("seconds", 0.0))
    daily = {}  # one point a day: where the level ended that day
    for skill, values in levels.items():
        last = {}
        for time, level in sorted(values):
            last[datetime.fromtimestamp(time).date()] = (time, level)
        daily[skill] = sorted(last.values())
    history = save.get("check_ins", {}).get("history", [])
    current = save.get("levels", {}).get("levels", {})
    return {"id": folder.name, "name": label, "sessions": len(sessions), "days": len(days), "minutes": minutes,
            "finished": finished, "levels": daily, "current": current, "practice": dict(practice),
            "check_ins": history, "vision": save.get("vision", {}),
            "last": max((line["time"] for s in sessions for line in s if "time" in line), default=0)}


def children(root, tests):
    labels = names(root)
    found = []
    for folder in sorted((root / "profiles").iterdir()) if (root / "profiles").exists() else []:
        if folder.is_dir() and (tests or not folder.name.startswith("test")):
            found.append(child(folder, labels.get(folder.name, folder.name)))
    return found


# -- drawing ------------------------------------------------------------------------

def esc(text):
    return html.escape(str(text))


def day(time):
    return datetime.fromtimestamp(time).strftime("%d %b %Y")


def chart(series, low=0.0, high=1.0, percent=False, empty="Nothing yet."):
    """Lines over time: series = [(label, colour, [(time, value)])]. Inline SVG, no libraries."""
    points = [p for _, _, values in series for p in values]
    if not points:
        return f'<p class="empty">{esc(empty)}</p>'
    w, h, left, right, top, bottom = 640, 220, 44, 16, 12, 30
    t0, t1 = min(p[0] for p in points), max(p[0] for p in points)
    span = max(t1 - t0, 1.0)
    x = lambda t: left + (t - t0) / span * (w - left - right) if t1 > t0 else (w + left - right) / 2
    y = lambda v: top + (1 - (v - low) / (high - low)) * (h - top - bottom)
    out = [f'<svg viewBox="0 0 {w} {h}" role="img" class="chart">']
    for tick in (0, 0.25, 0.5, 0.75, 1.0):
        v = low + tick * (high - low)
        label = f"{v * 100:.0f}%" if percent else f"{v:.2f}"
        out.append(f'<line x1="{left}" x2="{w - right}" y1="{y(v):.1f}" y2="{y(v):.1f}" class="grid"/>'
                   f'<text x="{left - 6}" y="{y(v) + 4:.1f}" class="axis" text-anchor="end">{label}</text>')
    out.append(f'<text x="{left}" y="{h - 8}" class="axis">{day(t0)}</text>')
    if t1 > t0:
        out.append(f'<text x="{w - right}" y="{h - 8}" class="axis" text-anchor="end">{day(t1)}</text>')
    for label, colour, values in series:
        coords = [(x(t), y(v)) for t, v in values]
        if len(coords) > 1:
            out.append(f'<polyline points="{" ".join(f"{a:.1f},{b:.1f}" for a, b in coords)}" fill="none" '
                       f'stroke="{colour}" stroke-width="2.5" stroke-linejoin="round"/>')
        for (a, b), (t, v) in zip(coords, values):
            value = f"{v * 100:.0f}%" if percent else f"{v:.2f}"
            out.append(f'<circle cx="{a:.1f}" cy="{b:.1f}" r="4.5" fill="{colour}"><title>{esc(label)}: {value}, {day(t)}</title></circle>')
    out.append("</svg>")
    legend = "".join(f'<span><i style="background:{c}"></i>{esc(label)}</span>' for label, c, _ in series)
    return "".join(out) + f'<div class="legend">{legend}</div>'


def colour_of(skills):
    return {skill: COLOURS[i % len(COLOURS)] for i, skill in enumerate(skills)}


def section(kid):
    finished_checks = [c for c in kid["check_ins"] if c.get("done")]
    check_skills = []
    for entry in finished_checks:
        for skill in entry.get("scores", {}):
            if skill not in check_skills:
                check_skills.append(skill)
    colours = colour_of(sorted(set(check_skills) | set(kid["levels"]) | set(kid["practice"])))
    parts = [f'<section><h2>{esc(kid["name"])}</h2>',
             f'<p class="meta">{kid["days"]} day{"s" if kid["days"] != 1 else ""} played · {kid["sessions"]} sessions · '
             f'{kid["minutes"]:.0f} minutes · {kid["finished"]} levels finished'
             + (f' · last played {day(kid["last"])}' if kid["last"] else "") + "</p>"]

    parts.append("<h3>Check-ins</h3><p class=\"why\">No help, new things, the same rounds each time: "
                 "the score going up means the child sees better, not just that they know the game.</p>")
    series = []
    for skill in check_skills:
        values = [(c["time"], c["scores"][skill]["right"] / c["scores"][skill]["rounds"])
                  for c in finished_checks if skill in c.get("scores", {}) and c["scores"][skill]["rounds"]]
        series.append((skill_name(skill), colours[skill], values))
    parts.append(chart(series, percent=True, empty="No check-in finished yet. The first one comes before the first menu."))
    if finished_checks:
        rows = []
        for entry in reversed(finished_checks):
            for skill, score in entry["scores"].items():
                by_level = ", ".join(f"{float(level):.2f}: {r[1]}/{r[0]}" for level, r in sorted(score.get("levels", {}).items()))
                rows.append(f'<tr><td>{day(entry["time"])}</td><td>{esc(entry.get("title", entry.get("place", "")))}</td>'
                            f'<td>{esc(skill_name(skill))}</td><td class="num">{score["right"]}/{score["rounds"]}</td>'
                            f'<td class="small">{esc(by_level)}</td></tr>')
        parts.append('<table><tr><th>Date</th><th>Where</th><th>Skill</th><th>Right</th><th>By difficulty</th></tr>'
                     + "".join(rows) + "</table>")
    unfinished = len(kid["check_ins"]) - len(finished_checks)
    if unfinished:
        parts.append(f'<p class="small">{unfinished} check-in{"s were" if unfinished > 1 else " was"} started but not finished (left out above).</p>')

    parts.append("<h3>Training level</h3><p class=\"why\">Where each skill's difficulty stood at the end of each day "
                 "(0 easiest, 1 hardest). It moves up after two rounds right first time without help, down after a miss.</p>")
    parts.append(chart([(skill_name(s), colours[s], v) for s, v in sorted(kid["levels"].items())],
                       empty="No level has moved yet (menu levels at a fixed difficulty do not move it)."))

    if kid["practice"]:
        rows = []
        for skill, p in sorted(kid["practice"].items()):
            if not p["rounds"]:
                continue
            now = f'{kid["current"][skill]:.2f}' if skill in kid["current"] else "-"
            rows.append(f'<tr><td>{esc(skill_name(skill))}</td><td class="num">{p["rounds"]}</td>'
                        f'<td class="num">{p["first_try"] / p["rounds"] * 100:.0f}%</td>'
                        f'<td class="num">{p["help"] / p["rounds"] * 100:.0f}%</td>'
                        f'<td class="num">{p["seconds"] / p["rounds"]:.0f} s</td><td class="num">{now}</td></tr>')
        parts.append("<h3>Practice</h3><p class=\"why\">Every training round (check-ins left out).</p>"
                     "<table><tr><th>Skill</th><th>Rounds</th><th>Right first time</th><th>Needed help</th>"
                     "<th>Time a round</th><th>Level now</th></tr>" + "".join(rows) + "</table>")

    vision = kid["vision"]
    if vision:
        view = vision.get("view", {})
        settings = [f'Filter: {esc(view.get("title", "Normal"))}', f'size ×{vision.get("size_scale", 1):.2f}',
                    f'help wait ×{vision.get("help_scale", 1):.2f}', f'time ×{vision.get("time_scale", 1):.1f}',
                    "adaptive levels" if vision.get("adaptive_levels", vision.get("adaptive", True)) else "fixed levels"]
        if vision.get("preset"):
            settings.insert(0, f'started from {esc(vision["preset"])}')
        parts.append(f'<h3>Vision settings now</h3><p>{" · ".join(settings)} '
                     f'<span class="small">({vision.get("revision", 0)} changes so far)</span></p>')
    parts.append("</section>")
    return "".join(parts)


STYLE = """
:root { --bg:#f6f4ef; --card:#ffffff; --ink:#1f2933; --soft:#5b6670; --line:#e3ded3; color-scheme: light dark; }
@media (prefers-color-scheme: dark) { :root { --bg:#14181d; --card:#1d232a; --ink:#e8e6e1; --soft:#a3abb3; --line:#2e363f; } }
body { margin:0; background:var(--bg); color:var(--ink); font:16px/1.5 system-ui, -apple-system, Segoe UI, sans-serif; }
main { max-width:760px; margin:0 auto; padding:24px 16px 64px; }
h1 { font-size:28px; margin:0 0 4px; } h2 { font-size:22px; margin:0 0 2px; } h3 { font-size:17px; margin:24px 0 2px; }
section { background:var(--card); border:1px solid var(--line); border-radius:14px; padding:20px; margin:20px 0; }
.meta, .why, .small, .empty { color:var(--soft); } .why, .small { font-size:14px; margin:0 0 8px; }
.chart { width:100%; height:auto; } .grid { stroke:var(--line); } .axis { fill:var(--soft); font-size:12px; }
.legend { display:flex; flex-wrap:wrap; gap:4px 16px; font-size:14px; }
.legend i { display:inline-block; width:12px; height:12px; border-radius:3px; margin-right:6px; vertical-align:-1px; }
table { width:100%; border-collapse:collapse; font-size:14px; margin-top:8px; display:block; overflow-x:auto; }
th, td { text-align:left; padding:6px 8px; border-bottom:1px solid var(--line); } .num { text-align:right; white-space:nowrap; }
"""


def page(kids, source):
    body = "".join(section(kid) for kid in kids) or "<section><p>No saves found.</p></section>"
    return (f'<!doctype html><html lang="en"><head><meta charset="utf-8">'
            f'<meta name="viewport" content="width=device-width, initial-scale=1"><title>ARVision progress</title>'
            f"<style>{STYLE}</style></head><body><main><h1>ARVision progress</h1>"
            f'<p class="meta">{len(kids)} child{"ren" if len(kids) != 1 else ""} · from {esc(source)} · made {datetime.now().strftime("%d %b %Y %H:%M")}</p>'
            f"{body}</main></body></html>")


def write_csv(kids, path):
    with path.open("w", newline="", encoding="utf-8-sig") as file:
        writer = csv.writer(file)
        writer.writerow(["child", "save", "date", "place", "skill", "rounds", "right", "finished"])
        for kid in kids:
            for entry in kid["check_ins"]:
                for skill, score in entry.get("scores", {}).items():
                    writer.writerow([kid["name"], kid["id"], datetime.fromtimestamp(entry["time"]).isoformat(timespec="minutes"),
                                     entry.get("place", ""), skill_name(skill), score["rounds"], score["right"], int(bool(entry.get("done")))])


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", choices=["local", "pull"])
    parser.add_argument("--tests", action="store_true", help="include test saves")
    parser.add_argument("--root", type=Path, help="read this folder instead (a copy of ARVision's user data)")
    args = parser.parse_args()
    with tempfile.TemporaryDirectory() as temporary:
        root = pull(temporary) if args.source == "pull" else (args.root or user_data())
        kids = children(root, args.tests)
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "index.html").write_text(page(kids, "the Quest" if args.source == "pull" else "this computer"), encoding="utf-8")
    write_csv(kids, OUT / "progress.csv")
    print(f"{len(kids)} children -> {OUT / 'index.html'}")


if __name__ == "__main__":
    main()
