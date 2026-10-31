"""Launch the real app on the simulated room and drive it through tools/sim/server.gd.

Standard library only. The engine runs in lockstep: game time passes only while
a command runs (wait, run, head/hand moves), one 1/60 s frame at a time.

    with Sim(plan(block("find", rounds=2)), profile="test_sim_demo") as sim:
        sim.run_until("trial_started", timeout=10)
        print(sim.observe()["stimuli"])
"""

import json
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import godot  # noqa: E402

ROOT = godot.ROOT
TRIALS = {
    "find": "res://trials/find/find.tres",
    "point_real": "res://trials/point_real/point_real.tres",
    "motion": "res://trials/motion/motion.tres",
    "motion_competing": "res://trials/motion/motion_competing.tres",
    "tidy": "res://trials/tidy/tidy.tres",
}
VIEWS = ["normal", "high_contrast", "greyscale", "black_white", "edges", "dim", "spotlight"]
PLANS = {"demo": "res://content/sessions/demo.tres", "motion": "res://content/sessions/motion.tres",
         "tech_demo": "res://content/sessions/tech_demo.tres"}


def block(trial, rounds=1, probe=False, difficulty=-1.0, pins=None, view=None, intro="", pause_between=0.5, ray=True):
    """One Block of a plan spec (see server.gd). ray=False: the child must reach what it picks."""
    spec = {"trial": TRIALS[trial], "rounds": rounds, "probe": probe, "difficulty": difficulty,
            "pins": pins or {}, "intro": intro, "pause_between": pause_between, "ray": ray}
    if view:
        spec["view"] = f"res://content/views/{view}.tres"
    return spec


def plan(*blocks, greeting="", farewell=""):
    return {"greeting": greeting, "farewell": farewell, "blocks": list(blocks)}


class SimError(RuntimeError):
    pass


class Sim:
    """One running app. `plan` is a plan name ("demo", "motion"), a plan spec dict, or None: the
    World's adventure (places, task menus)."""

    def __init__(self, plan="demo", profile="test_sim", unplug=(), seat=None, eye=None, rendered=False,
                 keep_profile=False, out=None, cv_server=None):
        assert profile.startswith("test"), "simulation profiles start with 'test': they get wiped"
        self.profile = profile
        self.rendered = rendered
        self.out = Path(out or ROOT / "build" / "sim" / profile).resolve()
        self.history = []
        self.cursor = 0
        self.process = None
        self.profile_dir = None  # known once the app answers
        self._socket = None
        self._stream = None
        self.out.mkdir(parents=True, exist_ok=True)
        args = [f"--profile={profile}", f"--out={self.out.as_posix()}"]
        if isinstance(plan, dict):
            spec = self.out / "plan.json"
            spec.write_text(json.dumps(plan, indent=1), encoding="utf-8")
            args.append(f"--plan-spec={spec.as_posix()}")
        elif plan:
            args.append(f"--plan={PLANS[plan]}")
        if unplug:
            args.append("--unplug=" + ",".join(unplug))
        if seat:
            args.append("--seat=%g,%g,%g" % tuple(seat))
        if eye:
            args.append(f"--eye={eye}")
        if keep_profile:
            args.append("--keep-profile")
        if cv_server:
            args.append(f"--cv-server={cv_server}")
        self._args = args

    def __enter__(self):
        self.start()
        return self

    def __exit__(self, *_exc):
        self.close()

    def start(self):
        with socket.socket() as probe:
            probe.bind(("127.0.0.1", 0))
            port = probe.getsockname()[1]
        engine = [str(godot.executable(console=True)), "--xr-mode", "off", "--fixed-fps", "60", "--path", str(ROOT)]
        if self.rendered:
            engine += ["--resolution", "1280x800", "--position", "40,40"]
        else:
            engine.insert(1, "--headless")
        command = engine + ["res://tools/sim/server.tscn", "--", f"--port={port}", *self._args]
        self._console = (self.out / "console.log").open("w", encoding="utf-8")
        self.process = subprocess.Popen(command, cwd=ROOT, stdout=self._console, stderr=subprocess.STDOUT,
                                        creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0)
        for _ in range(300):
            if self.process.poll() is not None:
                raise SimError("Godot exited at boot:\n" + self.console())
            try:
                self._socket = socket.create_connection(("127.0.0.1", port), timeout=0.2)
                break
            except OSError:
                time.sleep(0.1)
        else:
            self.close()
            raise SimError("the sim server did not answer:\n" + self.console())
        self._socket.settimeout(120)
        self._stream = self._socket.makefile("r", encoding="utf-8")
        self.profile_dir = Path(self.observe()["profile_dir"])

    def console(self):
        self._console.flush()
        return (self.out / "console.log").read_text(encoding="utf-8", errors="replace")

    def send(self, op, **args):
        self._socket.sendall((json.dumps({"op": op, **args}) + "\n").encode())
        line = self._stream.readline()
        if not line:
            raise SimError(f"the engine closed the connection during {op}:\n" + self.console()[-4000:])
        reply = json.loads(line)
        self.history.extend(reply.pop("events"))
        self.t = reply["t"]
        if not reply["ok"]:
            raise SimError(reply.get("error", str(reply)))
        return reply

    # -- engine facts ----------------------------------------------------------

    def observe(self):
        return self.send("observe")["observation"]

    def events(self, name=None, what=None, since=0):
        """Recorded events, optionally of one kind (and one reported `what`), after seq `since`."""
        return [e for e in self.history if e["seq"] > since and (name is None or e["event"] == name)
                and (what is None or e.get("what") == what)]

    # -- time ------------------------------------------------------------------

    def wait(self, seconds):
        return self.send("wait", seconds=seconds)

    def run_until(self, *specs, timeout=60.0):
        """The next event matching one of `specs` ("trial_started" or ("reported", "level")) after the
        last one this returned, playing on until it happens. None after `timeout` game seconds."""
        until = [{"event": s} if isinstance(s, str) else {"event": s[0], "what": s[1]} for s in specs]
        matched = next((e for e in self.history if e["seq"] > self.cursor and any(
            e["event"] == u["event"] and u.get("what", e.get("what")) == e.get("what") for u in until)), None)
        if matched is None:
            matched = self.send("run", until=until, timeout=timeout)["matched"]
        if matched:
            self.cursor = matched["seq"]
        return matched

    # -- the child's real input path (raw: no body limits; see actor.py) ---------

    def head(self, at=None, position=None, seconds=0.0):
        args = {"seconds": seconds}
        if at is not None:
            args["at"] = list(at)
        if position is not None:
            args["position"] = list(position)
        return self.send("head", **args)

    def hand(self, side, position, at=None, seconds=0.0):
        args = {"side": side, "position": list(position), "seconds": seconds}
        if at is not None:
            args["at"] = list(at)
        return self.send("hand", **args)

    def button(self, side, action, pressed):
        return self.send("button", side=side, action=action, pressed=pressed)

    def click(self, side, action, hold=0.1):
        self.button(side, action, True)
        self.wait(hold)
        return self.button(side, action, False)

    def track(self, side, on):
        return self.send("track", side=side, on=on)

    def probe(self, points, radius):
        return self.send("probe", points=[list(p) for p in points], radius=radius)["probe"]

    def capture(self, name):
        return self.send("capture", name=name)["path"]

    # -- shutdown ---------------------------------------------------------------

    def close(self, keep_profile=False):
        if self.process is None:
            return
        try:
            if self.process.poll() is None and self._stream:
                self.send("quit")
            self.process.wait(timeout=10)
        except (OSError, SimError, subprocess.TimeoutExpired, ValueError):
            self.process.kill()
            self.process.wait(timeout=10)
        finally:
            for closable in (self._stream, self._socket, self._console):
                if closable:
                    closable.close()
            self.process = None
        if not keep_profile and self.profile_dir and self.profile_dir.name.startswith("test"):
            shutil.rmtree(self.profile_dir, ignore_errors=True)
