"""Finds Godot on each OS. Override with the GODOT environment variable."""

import os
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
WINDOWS_GODOT = Path(r"D:\Program Files\Portables\Godot_v4.7.2-stable_win64.exe")


def executable(console=False):
    """The Godot binary. On Windows, console=True picks the _console build so stdout reaches us."""
    if "GODOT" in os.environ:
        return Path(os.environ["GODOT"])
    if sys.platform == "win32":
        return WINDOWS_GODOT.with_stem(WINDOWS_GODOT.stem + "_console") if console else WINDOWS_GODOT
    if sys.platform == "darwin":
        return Path("/Applications/Godot.app/Contents/MacOS/Godot")
    return Path(shutil.which("godot") or "godot")


def headless(*args):
    """Command line for a headless, XR-off run of this project."""
    return [str(executable(console=True)), "--headless", "--xr-mode", "off", "--path", str(ROOT), *args]
