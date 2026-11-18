"""Rendered walkthrough: plays the real app windowed (no headset) and leaves PNG checkpoints
plus build/walkthrough/review.html. Also runs tests/rendered/ against cv_server.py --fake.

    python tools/sim/walkthrough.py

The script checks engine facts as it goes; whether the pictures look right is for a person
(or agent) to judge by opening them. Script completion is not a visual pass.
"""

import html
from pathlib import Path
import socket
import subprocess
import sys

from actor import Facilitator
from child import Child
from client import ROOT, VIEWS, Sim, block, godot, plan

OUT = ROOT / "build" / "walkthrough"
CAPTIONS = {}


def free_port():
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 0))
        return probe.getsockname()[1]


def rendered_cv_test():
    """tests/rendered/ against the fake CV server. Returns the runner's exit code."""
    port = free_port()
    server = subprocess.Popen([sys.executable, str(ROOT / "tools" / "cv_server.py"), "--fake", "--port", str(port)],
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    try:
        server.stdout.readline()  # "CV server on ..."
        command = [str(godot.executable(console=True)), "--xr-mode", "off", "--audio-driver", "Dummy",
                   "--fixed-fps", "60", "--path", str(ROOT),
                   "res://tests/run.tscn", "--", "--profile=test_rendered", f"--cv-server=http://127.0.0.1:{port}/detect"]
        done = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
        print("\n".join(line for line in done.stdout.splitlines() if "::" in line or "TESTS" in line or "FAIL" in line))
        return done.returncode
    finally:
        server.terminate()
        server.wait(timeout=10)


def check(condition, what):
    if not condition:
        raise AssertionError(what)


def capture(sim, name, caption):
    sim.wait(0.1)
    path = Path(sim.capture(name))
    CAPTIONS[path.name] = caption
    print("IMAGE", path.name, "-", caption, flush=True)


def look_at_table(child):
    child.actor.look_at((0.0, 0.74, -0.6))


def walk(sim):
    child = Child(sim, seed=1)
    facilitator = Facilitator(sim)

    def named():
        stimuli = sim.observe()["stimuli"]
        return [t for t in stimuli["targets"] if t["id"].endswith("_" + stimuli["named"])][0]

    for index, view in enumerate(VIEWS):
        started = sim.run_until("trial_started")
        check(sim.observe()["view"]["title"] == started["condition"]["view"]["title"], "view applied")
        look_at_table(child)
        sim.wait(0.5)
        capture(sim, f"{index + 1:02d}-find-{view}", f"Find it under the {started['condition']['view']['title']} view; "
                f"guide: {sim.events('said')[-1]['text']}")
        if view == "normal":
            child.actor.help()
            sim.wait(0.12)
            capture(sim, "08-hint-1-hop", "Hint 1: the named toy hops (motion separates it from clutter); dot mark")
            child.actor.help("left")
            sim.wait(0.3)
            capture(sim, "09-hint-2-glow", "Hint 2: the named toy glows and the guide says where")
            check(named()["glow"], "the named toy glows")
            target, others = child.toys(started, sim.observe())
            wrong = child.policy.confuse(target, others)
            child.actor.point("right", tuple(wrong["centre"]), expect=wrong["id"])
            sim.wait(0.12)
            capture(sim, "10-wrong-cross", f"Wrong pick ({wrong['id']}): a cross over it and a falling tone")
            check(sim.events("feedback")[-1]["kind"] == "bad", "bad feedback")
            look_at_table(child)
            child.actor.point("right", tuple(target["centre"]), expect=target["id"])
            sim.wait(0.15)
            capture(sim, "11-success-ring", "Right pick: a ring over it, the toy lifts, a rising chime")
            check(sim.events("trial_ended")[-1]["success"], "solved")
        else:
            child.play_round(started, ["right"])
    # The facilitator panel, during the real-objects round.
    started = sim.run_until("trial_started")
    sim.wait(0.6)
    facilitator.open()
    panel = sim.observe()["facilitator"]["buttons"]
    centre = [sum(b["position"][i] for b in panel) / len(panel) for i in range(3)]
    sim.head(at=centre, seconds=0.2)
    capture(sim, "12-facilitator-panel", "Facilitator panel (left Menu); play is paused")
    facilitator.press("fac_close")
    check(not sim.observe()["paused"], "closed")
    observation = sim.observe()
    obj = [o for o in observation["real_objects"] if o["label"] == observation["stimuli"]["named"]][0]
    child.actor.face(tuple(obj["centre"]))
    child.actor.help()
    sim.wait(0.4)
    check(len(sim.observe()["stimuli"]["markers"]) == 1, "a marker over the object")
    capture(sim, "13-cv-hint-marker", f"Real objects: hint 1 marks the {obj['label']} the camera found")
    child.play_round(started, ["right"])
    # Read the flow.
    started = sim.run_until("trial_started")
    cloud = sim.observe()["stimuli"]["cloud"]
    child.actor.look_at(tuple(cloud["position"]))
    sim.wait(1.5)
    capture(sim, "14-motion-cloud", f"Read the flow: {started['condition']['values']['signal_dots']} of 200 dots go "
            f"{started['condition']['values']['heading']}")
    child.actor.sweep("right", Child.world(cloud, (1, 0, 0)))
    sim.wait(0.7)
    check(sim.observe()["stimuli"]["cloud"]["alignment"] == 1.0, "aligned")
    capture(sim, "15-motion-success-streaks", "Right sweep: every dot joins the flow as a streak")
    sim.run_until("session_finished", timeout=30)


def walk_desk(sim):
    child = Child(sim, seed=4)
    sim.run_until("trial_started")
    cells = sim.observe()["stimuli"]["layout"]["cells"]
    objects = sim.observe()["stimuli"]["layout"]["things"]
    middle = tuple((sum(c["position"][i] for c in cells) + sum(t["centre"][i] for t in objects)) / 10 for i in range(3))
    child.actor.look_at(middle)
    capture(sim, "16-desk-outlines", "Ready to Study: five everyday props, five neutral tabletop outlines")
    child.tidy("wrong", None)
    check(not sim.observe()["session"]["trial"]["tries"] == 0, "wrong outline judged only after release")
    capture(sim, "17-desk-wrong", "Wrong drop returns to the tray; no correct outline is revealed")
    for i in range(5):
        child.tidy("right", None)
        if i == 3:
            child.actor.look_at(middle)
            capture(sim, "18-desk-four-placed", "Four objects placed: their outlines are gone, the last remains")
    # Look up to include the child-sized person arriving on the far side of the table.
    child.actor.look_at((middle[0], middle[1] + 0.15, middle[2] - 0.12))
    capture(sim, "19-desk-arriving", "With everything tidy, a student walks to the chair")
    sim.wait(2.6)
    capture(sim, "20-desk-studying", "The student sits down, opens the notebook and writes")
    sim.run_until("trial_ended", timeout=10)
    check(sim.events("trial_ended")[-1]["success"], "the study animation completes before the result")


def gallery():
    figures = "\n".join(
        f'<figure><a href="{html.escape(p.name)}"><img src="{html.escape(p.name)}" loading="lazy"></a>'
        f'<figcaption><b>{html.escape(p.stem)}</b> {html.escape(CAPTIONS.get(p.name, ""))}</figcaption></figure>'
        for p in sorted(OUT.glob("*.png")))
    (OUT / "review.html").write_text(
        '<!doctype html><meta charset="utf-8"><title>ARVision walkthrough</title>'
        '<style>body{background:#151923;color:#eee;font:15px system-ui;margin:24px}'
        'main{display:grid;grid-template-columns:repeat(auto-fit,minmax(420px,1fr));gap:18px}'
        'figure{margin:0}img{width:100%}figcaption{padding:6px 2px}</style>'
        '<h1>ARVision walkthrough</h1><p>Rendered on the simulated room, no headset. '
        'Look at every picture: a finished script is not a visual pass.</p><main>' + figures + '</main>',
        encoding="utf-8")


def walk_sandwich(sim):
    child = Child(sim, seed=4)
    started = sim.run_until("trial_started")
    layout = sim.observe()["stimuli"]["layout"]
    child.actor.look_at(tuple(layout["focus"]))
    sim.wait(5.0)
    capture(sim, "21-sandwich-counter", "Make a Sandwich: a shuffled tray, an open stack and a 3D sample")
    for _ in range(2):
        child.sandwich("right")
    child.actor.look_at(tuple(layout["focus"]))
    capture(sim, "22-sandwich-building", "The player builds from the bottom, one pinch and release at a time")
    for _ in range(2):
        child.sandwich("right")
    plate = layout["plate"]
    sim.head(at=(plate[0], plate[1] + 0.123, plate[2] - 0.02), seconds=0.32)
    sim.wait(0.67)
    check(sim.observe()["stimuli"]["layout"]["stage"] == "showcase", "the finished sandwich lifts")
    capture(sim, "23-sandwich-showcase", "The finished stack opens into layers and spins amid golden sparks")
    sim.wait(1.85)
    sim.head(at=(plate[0], plate[1] + 0.045, plate[2] - 0.025), seconds=0.22)
    check(sim.observe()["stimuli"]["layout"]["stage"] == "served", "the stack settles back on its plate")
    capture(sim, "24-sandwich-served", "Ready to serve, before the results come in")
    check(sim.run_until("trial_ended", timeout=6)["success"], "the animation finishes before the result")
    check(child.result(started)["data"]["first_try"], "the whole sandwich was stacked correctly")


def walk_bookshelf(sim):
    child = Child(sim, seed=4)
    sim.run_until("trial_started")
    focus = tuple(sim.observe()["stimuli"]["layout"]["focus"])
    child.actor.lean((0.0, 0.015, 0.065), at=focus)
    sim.wait(4.5)
    for hand in ("left", "right"):
        sim.track(hand, False)
    capture(sim, "25-bookshelf-glass", "Bookshelf Match: five glass models in the cubbies and the matching objects on the tray")
    for hand in ("left", "right"):
        sim.track(hand, True)
    for _ in range(2):
        child.tidy("right", None)
    child.actor.look_at(focus)
    capture(sim, "26-bookshelf-matching", "Correctly placed objects replace their own glass models")
    for _ in range(3):
        child.tidy("right", None)
    check(sim.events("trial_ended")[-1]["success"], "all five things fit on the shelf")
    child.actor.look_at(focus)
    sim.wait(0.7)
    for hand in ("left", "right"):
        sim.track(hand, False)
    capture(sim, "27-bookshelf-tidy", "The finished bookshelf")
    check(sim.run_until("session_finished", timeout=6), "the bookshelf session completes")


def main():
    failed = rendered_cv_test()
    for old in OUT.glob("*.png"):
        old.unlink()
    spec = plan(*[block("find", rounds=1, difficulty=0.6, view=v, pause_between=1.0) for v in VIEWS],
                block("point_real", rounds=1), block("motion", rounds=1, difficulty=0.3, pins={"direction": 1},
                                                    pause_between=2.0))
    with Sim(spec, profile="test_walkthrough", rendered=True, out=OUT, eye=1.12) as sim:
        try:
            walk(sim)
        finally:
            gallery()
            print("GALLERY", OUT / "review.html")
    with Sim(plan(block("desk", difficulty=0.0, ray=False, pause_between=2.0)),
             profile="test_walkthrough_desk", rendered=True, out=OUT, eye=1.12) as sim:
        try:
            walk_desk(sim)
        finally:
            gallery()
    with Sim(plan(block("sandwich", difficulty=0.0, ray=False, pause_between=2.0)),
             profile="test_walkthrough_sandwich", rendered=True, out=OUT, eye=1.12) as sim:
        try:
            walk_sandwich(sim)
        finally:
            gallery()
    with Sim(plan(block("bookshelf", difficulty=0.0, ray=False, pause_between=2.0)),
             profile="test_walkthrough_bookshelf", rendered=True, out=OUT, eye=1.12) as sim:
        try:
            walk_bookshelf(sim)
        finally:
            gallery()
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
