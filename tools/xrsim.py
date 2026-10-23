"""Runs the real Quest code path (PassthroughReality, the Meta room scan, hands) on
the PC with Meta XR Simulator, in an injected room. No headset needed.

    python tools/xrsim.py run tests/xrsim/rooms/desk.json   # print what the app read
    python tools/xrsim.py test                              # the room tests (tests/xrsim/)

A room is the simulator's scene-anchor JSON (see room() below, or record a real
room with the simulator's SceneDataRecorder.apk). Meta's JSON room server serves it;
the simulator runs in batch mode with its own config, chosen per process
(XR_RUNTIME_JSON, META_XRSIM_CONFIG_JSON): the system's OpenXR runtime is untouched.
The app prints one "ARVision {json}" line per room step (PassthroughReality.note).
"""

import json
import math
import os
from pathlib import Path
import socket
import subprocess
import sys
import time
import uuid

import godot

SIMULATOR = Path(os.environ.get("XRSIM", r"C:\Program Files\MetaXRSimulator\v207.1"))
SES_PORT = 33792  # json_server.exe's default, where the simulator looks for a room
OUT = godot.ROOT / "build" / "xrsim"


def available():
    return (SIMULATOR / "meta_openxr_simulator.json").exists()


# -- rooms ---------------------------------------------------------------------

def _quat(axis, degrees):
    half = math.radians(degrees) / 2
    x, y, z = axis
    return {"x": x * math.sin(half), "y": y * math.sin(half), "z": z * math.sin(half), "w": math.cos(half)}


def _mul(a, b):
    return {"w": a["w"] * b["w"] - a["x"] * b["x"] - a["y"] * b["y"] - a["z"] * b["z"],
            "x": a["w"] * b["x"] + a["x"] * b["w"] + a["y"] * b["z"] - a["z"] * b["y"],
            "y": a["w"] * b["y"] - a["x"] * b["z"] + a["y"] * b["w"] + a["z"] * b["x"],
            "z": a["w"] * b["z"] + a["x"] * b["y"] - a["y"] * b["x"] + a["z"] * b["w"]}


def plane(label, centre, size, yaw=0.0, facing="up"):
    """A flat thing (floor, table top, wall): OpenXR planes lie in local XY, +Z the normal.
    Positions are in the simulator's space: the head starts near the origin, -Z ahead."""
    tilt = {"up": _quat((1, 0, 0), -90), "down": _quat((1, 0, 0), 90), "back": _quat((0, 1, 0), 0)}[facing]
    return {"label": label, "pose": (centre, _mul(_quat((0, 1, 0), yaw), tilt)), "plane": size}


def volume(label, base, size, yaw=0.0):
    """A box standing on the floor at `base` (centre of its bottom): size = (width, depth, height).
    Like Meta's own rooms, its pose is the centre of its top face and the box hangs below it."""
    x, y, z = base
    return {"label": label, "pose": ((x, y + size[2], z), _mul(_quat((0, 1, 0), yaw), _quat((1, 0, 0), -90))),
            "volume": size}


def _floats(value):
    if isinstance(value, dict):
        return {k: _floats(v) for k, v in value.items()}
    if isinstance(value, list):
        return [_floats(v) for v in value]
    return float(value) if isinstance(value, int) and not isinstance(value, bool) else value


def room(*things):
    """Scene-anchor JSON for json_server.exe: each thing plus a room that contains them all.
    Every number is a float: the server quits silently on a JSON integer."""
    anchors, comps = [], {"Locatable": [], "SemanticLabels": [], "Bounded2D": [], "Bounded3D": []}
    for thing in things:
        anchor = str(uuid.uuid4())
        anchors.append(anchor)
        (x, y, z), orientation = thing["pose"]
        comps["Locatable"].append({"anchor": anchor, "enabled": False,
                                   "pose": {"orientation": orientation, "position": {"x": x, "y": y, "z": z}}})
        comps["SemanticLabels"].append({"anchor": anchor, "enabled": True, "labels": [thing["label"]]})
        if "plane" in thing:
            w, h = thing["plane"]
            comps["Bounded2D"].append({"anchor": anchor, "enabled": True,
                                       "rect2D": {"extent": {"width": w, "height": h}, "offset": {"x": -w / 2, "y": -h / 2}}})
        else:
            w, d, h = thing["volume"]
            # Laid out as in Meta's sample rooms: centred across, hanging height metres below the pose.
            comps["Bounded3D"].append({"anchor": anchor, "enabled": True, "rect3D": {
                "extent": {"width": w, "height": h, "depth": d}, "offset": {"x": -w / 2, "y": -h, "z": -d / 2}}})
    if anchors:  # the room itself: the plugin finds everything through its layout and container
        container = str(uuid.uuid4())
        by_label = lambda label: [a for a, t in zip(anchors, things) if t["label"] == label]
        if not (by_label("FLOOR") and by_label("CEILING")):
            raise ValueError("a room needs a FLOOR and a CEILING (the server quits without them), like every real scan")
        comps["RoomLayout"] = [{"anchor": container, "enabled": True, "floor": by_label("FLOOR")[0],
                                "ceiling": by_label("CEILING")[0], "walls": by_label("WALL_FACE")}]
        comps["SpaceContainer"] = [{"anchor": container, "enabled": True, "spaces": list(anchors)}]
        anchors.append(container)
    return _floats({"anchors": anchors, "components": {k: v for k, v in comps.items() if v}})


# -- running ---------------------------------------------------------------------

def _wait_for_port(server, port, seconds=10.0):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        if server.poll() is not None:
            raise RuntimeError("the room server quit: is the room JSON valid (floats only)?")
        with socket.socket() as probe:
            if probe.connect_ex(("127.0.0.1", port)) == 0:
                return
        time.sleep(0.1)
    raise RuntimeError(f"room server did not open port {port}")


def run(room_json, seconds=8.0, name="run"):
    """Runs the app in `room_json` (a dict, a path, or None for a headset with no room scan)
    for `seconds`; returns (notes, errors)."""
    folder = OUT / name
    folder.mkdir(parents=True, exist_ok=True)
    room_path = folder / "room.json"
    if isinstance(room_json, (str, Path)):
        room_path.write_text(Path(room_json).read_text())
    elif room_json:
        room_path.write_text(json.dumps(room_json, indent=1))
    (folder / "app_anchors.json").write_text('{"anchors": [], "components": {}}')
    config = folder / "config.json"
    config.write_text(json.dumps({
        "use_batch_mode": True, "use_offscreen_mode": True, "device_profile": "Meta Quest 3",
        "userid_source_type": "generated", "log_location": str(folder / "meta_xrsim.log"),
        "scene_anchor_data": str(room_path), "app_anchor_data": str(folder / "app_anchors.json")}, indent=2))
    env = dict(os.environ, XR_RUNTIME_JSON=str(SIMULATOR / "meta_openxr_simulator.json"),
               META_XRSIM_CONFIG_JSON=str(config))
    server = None
    if room_json:  # no server = no room data, like a headset that was never scanned
        server = subprocess.Popen([str(SIMULATOR / "json_synthenv_server" / "json_server.exe"), str(room_path),
                                   "--port", str(SES_PORT)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        if server:
            _wait_for_port(server, SES_PORT)
        frames = int(seconds * 72)  # the simulated Quest 3 runs at 72 Hz
        done = subprocess.run([str(godot.executable(console=True)), "--path", str(godot.ROOT), "--xr-mode", "on",
                               "--quit-after", str(frames), "--", "--profile=test_xrsim"],
                              env=env, capture_output=True, text=True, encoding="utf-8", errors="replace",
                              timeout=seconds + 60)
    finally:
        if server:
            server.kill()
            server.wait()
    output = done.stdout + done.stderr
    (folder / "godot.txt").write_text(output, encoding="utf-8")
    notes = [json.loads(line[len("ARVision "):]) for line in output.splitlines() if line.startswith("ARVision {")]
    errors = [line for line in output.splitlines() if line.startswith("SCRIPT ERROR")]
    return notes, errors


if __name__ == "__main__":
    if not available():
        sys.exit(f"Meta XR Simulator not found at {SIMULATOR} (set XRSIM)")
    if sys.argv[1:2] == ["run"]:
        notes, errors = run(sys.argv[2])
        for note in notes:
            print(json.dumps(note))
        for error in errors:
            print(error)
    elif sys.argv[1:2] == ["test"]:
        sys.exit(subprocess.run([sys.executable, "-m", "unittest", "discover", "-s", "tests/xrsim", "-t", "tests/xrsim"],
                                cwd=godot.ROOT).returncode)
    else:
        sys.exit(__doc__)
