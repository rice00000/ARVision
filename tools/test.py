"""Run the headless suites in parallel, or select suites with --only."""

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
from uuid import uuid4

import godot

TESTS = godot.ROOT / "tests"
SCENARIOS = TESTS / "sim"


@dataclass(frozen=True)
class Suite:
    name: str
    directory: Path
    command: list[str]


def suites(run_id):
    yield Suite("speech manifest", godot.ROOT, [sys.executable, "tools/bake_speech.py", "--check"])
    scripts = sorted(TESTS.rglob("*_test.gd"), key=lambda path: (-path.stat().st_size, path))
    units = []
    for script in scripts:
        if script.is_relative_to(TESTS / "rendered"):
            continue
        name = script.relative_to(godot.ROOT).as_posix()
        profile = f"test_unit_{run_id}_{script.stem}"
        command = godot.headless("--fixed-fps", "60", "res://tests/run.tscn", "--",
                                 f"--profile={profile}", f"--only=res://{name}")
        units.append(Suite(name, godot.ROOT, command))

    # Start the large opening and layout suites before the simulation queue.
    yield from units[:6]
    for script in sorted(SCENARIOS.glob("test_*.py")):
        name = script.relative_to(godot.ROOT).as_posix()
        yield Suite(name, SCENARIOS, [sys.executable, "-m", "unittest", script.stem])
    yield from units[6:]


def run(suite, failure_logs):
    began = time.monotonic()
    with tempfile.TemporaryFile(mode="w+", encoding="utf-8", errors="replace") as output:
        done = subprocess.run(suite.command, cwd=suite.directory, stdout=output, stderr=subprocess.STDOUT)
        output.seek(0)
        summary = [line.strip() for line in output
                   if line.startswith(("TESTS:", "  FAILED ", "Ran ", "FAILED", "SPEECH_ERROR:"))]
        if done.returncode:
            failure_logs.mkdir(parents=True, exist_ok=True)
            log = failure_logs / (Path(suite.name).stem + ".log")
            output.seek(0)
            with log.open("w", encoding="utf-8") as destination:
                shutil.copyfileobj(output, destination)
            summary.append(str(log))
    return done.returncode == 0, time.monotonic() - began, " | ".join(summary)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", action="append", default=[], metavar="NAME",
                        help="run suites matching this name or path (repeat to select several)")
    parser.add_argument("--jobs", type=int, default=min(6, max(1, (os.cpu_count() or 4) // 2)),
                        help="maximum simultaneous suites (default: up to 6)")
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be at least 1")
    run_id = uuid4().hex[:8]
    selected = [suite for suite in suites(run_id)
                if not args.only or any(name in suite.name for name in args.only)]
    if not selected:
        parser.error("no suites match --only")

    began = time.monotonic()
    failures = []
    failure_logs = godot.ROOT / "build" / "test" / run_id
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        jobs = {pool.submit(run, suite, failure_logs): suite for suite in selected}
        for job in as_completed(jobs):
            suite = jobs[job]
            passed, seconds, summary = job.result()
            if not passed:
                failures.append(suite.name)
            print(f"{'PASS' if passed else 'FAIL'} {suite.name} ({seconds:.1f} s)"
                  + (f": {summary}" if summary else ""), flush=True)
    print(f"\n{len(selected) - len(failures)} of {len(selected)} suites passed in {time.monotonic() - began:.1f} s")
    return int(bool(failures))


if __name__ == "__main__":
    sys.exit(main())
