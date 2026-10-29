"""Every save's picks (modules/picks/picks.gd) in one CSV: build/picks.csv, oldest first.

    python tools/picks.py pull     # from the Quest (adb)
    python tools/picks.py local    # from this PC's desktop runs (test saves left out)
"""

import argparse
import csv
import io
import os
from pathlib import Path
import subprocess
import tarfile

import godot
from frames import adb

PACKAGE = "edu.mit.arvision"
OUT = godot.ROOT / "build" / "picks.csv"
LOCAL = Path(os.environ.get("APPDATA", Path.home() / ".local" / "share")) / "Godot" / "app_userdata" / "ARVision" / "profiles"


def quest_files():
    tar = subprocess.run([adb(), "exec-out", "run-as", PACKAGE, "tar", "-C", "files", "-cf", "-", "profiles"],
                         capture_output=True, check=True).stdout
    with tarfile.open(fileobj=io.BytesIO(tar)) as archive:
        for member in archive.getmembers():
            if member.name.endswith("/picks.csv"):
                yield archive.extractfile(member).read().decode("utf-8")


def local_files():
    for path in sorted(LOCAL.glob("*/picks.csv")):
        if not path.parent.name.startswith("test"):
            yield path.read_text(encoding="utf-8")


def merge(texts):
    header, rows = None, []
    for text in texts:
        lines = list(csv.reader(io.StringIO(text)))
        header = lines[0]
        rows += lines[1:]
    rows.sort(key=lambda row: row[0])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", newline="", encoding="utf-8-sig") as file:  # the BOM lets Excel read the names
        writer = csv.writer(file)
        if header:
            writer.writerow(header)
        writer.writerows(rows)
    print(f"{len(rows)} picks -> {OUT}")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", choices=["pull", "local"])
    merge(quest_files() if parser.parse_args().source == "pull" else local_files())


if __name__ == "__main__":
    main()
