"""Runs every automated suite headlessly. Exit code 0 = everything passed.
Uses its own "test" profiles, so it never touches a real child's progress."""

import subprocess
import sys

import godot

commands = [
    godot.headless("res://tests/run.tscn", "--", "--profile=test"),
]
for command in commands:
    result = subprocess.call(command, cwd=godot.ROOT)
    if result:
        sys.exit(result)
