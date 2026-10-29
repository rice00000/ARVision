"""Quest recordings (tools/record/record.gd, the recorder app): what the headset
sensed, kept for replay on the PC.

    python tools/recordings.py install           # export the recorder, install and start it on the Quest
    python tools/recordings.py pull              # adb: copy the recordings to build/recordings/
    python tools/recordings.py check build/recordings/<run>

check prints how long the run is, how often each stream came, and how much of
it each hand was tracked, and exits non-zero when a stream is missing.
"""

import argparse
from pathlib import Path
import io
import json
import subprocess
import sys
import tarfile

import godot
from frames import adb

PACKAGE = "edu.mit.arvision.record"
APK = godot.ROOT / "build" / "arvision-recorder.apk"
OUT = godot.ROOT / "build" / "recordings"


def install():
    subprocess.run([str(godot.executable(console=True)), "--headless", "--path", str(godot.ROOT),
                    "--export-debug", "Meta Quest 3 Recorder", str(APK)], check=True)
    subprocess.run([adb(), "install", "-r", str(APK)], check=True)
    subprocess.run([adb(), "shell", "am", "start", "-n", PACKAGE + "/com.godot.game.GodotAppLauncher"], check=True)


def pull():
    tar = subprocess.run([adb(), "exec-out", "run-as", PACKAGE, "tar", "-C", "files/recordings", "-cf", "-", "."],
                         capture_output=True, check=True).stdout
    OUT.mkdir(parents=True, exist_ok=True)
    with tarfile.open(fileobj=io.BytesIO(tar)) as archive:
        archive.extractall(OUT, filter="data")
    for run in sorted(p for p in OUT.iterdir() if p.is_dir()):
        print(run)


def poses(run):
    """The pose lines. Closing the app cuts the last one off; it is left out."""
    text = (run / "poses.jsonl").read_text()
    return [json.loads(line) for line in text[:text.rfind(chr(10))].splitlines()]


def check(run):
    lines = poses(run)
    frames = sorted(run.glob("frames/*.json"))
    looks = sorted(run.glob("depth/*.json"))
    seconds = (lines[-1]["t"] - lines[0]["t"]) / 1e6
    print(f"{run.name}: {seconds:.1f} s, {len(lines)} poses ({len(lines) / seconds:.0f}/s), "
          f"{len(frames)} camera frames, {len(looks)} depth looks, "
          f"{'finished' if (run / 'done.json').exists() else 'cut off (app closed early)'}")
    for side in ("left", "right"):
        aim = sum(line[side]["aim"] is not None for line in lines) / len(lines)
        joints = sum(line[side]["joints"] is not None for line in lines) / len(lines)
        pinches = sum(1 for a, b in zip(lines, lines[1:]) if b[side]["pinch"] and not a[side]["pinch"])
        print(f"  {side}: tracked {aim:.0%}, joints {joints:.0%}, {pinches} pinches")
    gaps = [(b["t"] - a["t"]) / 1e3 for a, b in zip(lines, lines[1:])]
    print(f"  longest gap between poses {max(gaps):.0f} ms")
    if not frames or not looks:
        sys.exit("a stream is missing")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("install")
    sub.add_parser("pull")
    sub.add_parser("check").add_argument("run", type=Path)
    args = parser.parse_args()
    if args.command == "check":
        check(args.run)
    else:
        {"install": install, "pull": pull}[args.command]()


if __name__ == "__main__":
    main()
