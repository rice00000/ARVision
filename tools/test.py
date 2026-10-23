"""Runs every automated suite headlessly, in parallel. Exit code 0 = everything passed.

GDScript unit tests (tests/*_test.gd) and the scenario suite (tests/sim/test_*.py),
which plays whole sessions on the real app with a simulated child. Each uses its
own "test..." profile, so it never touches a real child's progress. The rendered
walkthrough is separate: python tools/sim/walkthrough.py
"""

from concurrent.futures import ThreadPoolExecutor
import os
import subprocess
import sys
import time

import godot

SCENARIOS = godot.ROOT / "tests" / "sim"
suites = [("GDScript unit tests", godot.headless("--fixed-fps", "60", "res://tests/run.tscn", "--", "--profile=test"))]
suites += [(f"scenarios {path.stem}", [sys.executable, "-m", "unittest", path.stem])
           for path in sorted(SCENARIOS.glob("test_*.py"))]


def run(suite):
    name, command = suite
    began = time.monotonic()
    done = subprocess.run(command, cwd=SCENARIOS if command[0] == sys.executable else godot.ROOT,
                          capture_output=True, text=True, encoding="utf-8", errors="replace")
    return name, done.returncode, done.stdout + done.stderr, time.monotonic() - began


began = time.monotonic()
failed = []
with ThreadPoolExecutor(max_workers=max(2, (os.cpu_count() or 4) // 2)) as pool:
    for name, code, output, seconds in pool.map(run, suites):
        lines = [line for line in output.splitlines() if line.startswith(("TESTS:", "Ran ", "OK", "FAILED"))
                 or "FAIL" in line or "Error" in line]
        print(f"{'PASS' if code == 0 else 'FAIL'} {name} ({seconds:.1f} s): {' | '.join(lines[-3:])}", flush=True)
        if code:
            failed.append(name)
            print(output)
print(f"\n{len(suites) - len(failed)} of {len(suites)} suites passed in {time.monotonic() - began:.1f} s")
sys.exit(1 if failed else 0)
