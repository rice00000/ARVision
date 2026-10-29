"""Quest camera frames, checked on the PC. A debug build on the Quest keeps the frames
its Detector sends (modules/cv/detector.gd, RECORD_LIMIT per run); record once,
then iterate on CV here without the headset.

    python tools/frames.py pull                  # adb: copy the Quest's runs to build/frames/
    python tools/frames.py check build/frames/<run> [--fake]
    python tools/frames.py clear                 # delete the runs on the Quest

check looks at every frame: size and field of view, brightness and colour balance
(a red or green cast means the YCbCr conversion is off), and what YOLO finds
(tools/cv_server.py; --fake skips the model). Frames the headset's own YOLO looked
at (<frame>.seen.json) are compared with the PC's answer, with its timing. It writes
<run>/review.html with the boxes drawn and exits non-zero when the camera looks
broken or the headset disagrees with the PC.
"""

import argparse
import html
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile

import godot
import cv_server

PACKAGE = "edu.mit.arvision"
OUT = godot.ROOT / "build" / "frames"


def adb():
    found = os.environ.get("ADB") or shutil.which("adb")
    return found or r"D:\Android\Sdk\platform-tools\adb.exe"


def pull():
    tar = subprocess.run([adb(), "exec-out", "run-as", PACKAGE, "tar", "-C", "files/frames", "-cf", "-", "."],
                         capture_output=True, check=True).stdout
    OUT.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(tar)) as archive:
        archive.extractall(OUT, filter="data")
    runs = sorted(p for p in OUT.iterdir() if p.is_dir())
    for run in runs:
        print(run, len(list(run.glob("*.jpg"))), "frames")


def clear():
    subprocess.run([adb(), "shell", "run-as", PACKAGE, "rm", "-rf", "files/frames"], check=True)


def stats(image):
    """Mean brightness, spread and per-channel means (0..255) of an RGB image."""
    small = image.convert("RGB").resize((64, 64))
    pixels = list(small.getdata())
    means = [sum(p[c] for p in pixels) / len(pixels) for c in range(3)]
    grey = [sum(p) / 3 for p in pixels]
    mean = sum(grey) / len(grey)
    spread = (sum((g - mean) ** 2 for g in grey) / len(grey)) ** 0.5
    return mean, spread, means


def problems(image, meta):
    """What looks wrong with one frame, as short sentences."""
    found = []
    mean, spread, (r, g, b) = stats(image)
    if mean < 15 or spread < 4:
        found.append("blank or black")
    elif max(r, g, b) > 1.6 * max(1.0, min(r, g, b)):
        found.append(f"colour cast (R {r:.0f}, G {g:.0f}, B {b:.0f})")
    if list(image.size) != list(meta["size"]):
        found.append(f"image is {image.size}, metadata says {meta['size']}")
    if not 30 <= meta["fov_y"] <= 120:
        found.append(f"odd vertical field of view {meta['fov_y']}")
    return found


def check(run, fake=False):
    from PIL import Image

    if fake:
        detect = cv_server.fake
    else:
        try:
            detect = cv_server.yolo(cv_server.MODEL)
        except ImportError:
            sys.exit("YOLO needs: pip install ultralytics onnxruntime   (or use --fake to check the frames only)")
    rows, labels, broken = [], {}, 0
    agree = differ = 0
    times = []
    frames = sorted(run.glob("*.jpg"))
    for path in frames:
        meta = json.loads(path.with_suffix(".json").read_text())
        image = Image.open(path)
        issues = problems(image, meta)
        broken += bool(issues)
        found = detect(path.read_bytes())
        for item in found:
            labels[item["label"]] = labels.get(item["label"], 0) + 1
        seen = path.with_suffix(".seen.json")
        if seen.exists() and not fake:
            headset = json.loads(seen.read_text())
            times.append(headset["ms"])
            missed = unmatched(found, headset["detections"])
            agree += not missed
            differ += bool(missed)
            if missed:
                issues.append("headset differs: " + ", ".join(missed))
        rows.append((path.name, image.size, issues, found))
    print(f"{len(frames)} frames, {broken} with problems")
    print("seen:", ", ".join(f"{k} x{v}" for k, v in sorted(labels.items(), key=lambda kv: -kv[1])) or "nothing")
    if times:
        times.sort()
        print(f"headset YOLO: {agree} of {agree + differ} frames agree with the PC; "
              f"{times[len(times) // 2]} ms median, {times[-1]} ms slowest")
    for name, _size, issues, _found in rows:
        if issues:
            print(f"  {name}: {'; '.join(issues)}")
    (run / "review.html").write_text(review(rows), encoding="utf-8")
    print("review:", run / "review.html")
    return 0 if frames and broken < len(frames) and labels and differ <= agree // 10 else 1


def unmatched(pc, headset):
    """Confident objects one side found and the other did not (same label, boxes overlapping)."""
    def missing(found, other):
        return [d["label"] for d in found if d["confidence"] >= 0.5 and not any(
            o["label"] == d["label"] and o["confidence"] >= 0.3 and overlap(o["box"], d["box"]) > 0.5 for o in other)]
    return [f"PC only {label}" for label in missing(pc, headset)] + [f"headset only {label}" for label in missing(headset, pc)]


def overlap(a, b):
    inter = max(0, min(a[2], b[2]) - max(a[0], b[0])) * max(0, min(a[3], b[3]) - max(a[1], b[1]))
    return inter / ((a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter)


def review(rows):
    cards = []
    for name, (w, h), issues, found in rows:
        boxes = "".join(
            f'<rect x="{b[0] * w}" y="{b[1] * h}" width="{(b[2] - b[0]) * w}" height="{(b[3] - b[1]) * h}"/>'
            f'<text x="{b[0] * w + 4}" y="{b[1] * h + 16}">{html.escape(d["label"])} {d["confidence"]:.2f}</text>'
            for d in found for b in [d["box"]])
        note = html.escape("; ".join(issues)) or "ok"
        cards.append(f'<figure><svg viewBox="0 0 {w} {h}"><image href="{name}" width="{w}" height="{h}"/>{boxes}</svg>'
                     f'<figcaption>{name}: {note}</figcaption></figure>')
    return ("<!doctype html><meta charset=utf-8><title>Quest frames</title><style>"
            "body{font:14px system-ui;margin:16px;background:#111;color:#eee}figure{display:inline-block;width:320px;margin:6px}"
            "svg{width:100%}rect{fill:none;stroke:#ff0;stroke-width:3}text{fill:#ff0;font-size:16px}</style>"
            + "".join(cards))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("command", choices=["pull", "check", "clear"])
    parser.add_argument("run", nargs="?", type=Path)
    parser.add_argument("--fake", action="store_true")
    args = parser.parse_args()
    if args.command == "pull":
        pull()
    elif args.command == "clear":
        clear()
    else:
        sys.exit(check(args.run, args.fake))
