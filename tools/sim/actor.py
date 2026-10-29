"""Hands and heads acting on the engine through the child's real input path.

Actor is the seated child: every action is checked against its Body first and
refused with ConstraintError before anything is sent. Facilitator is the adult
at the panel: the left-hand menu pinch, then point the left hand and pinch.
"""

import math

from body import Body, ConstraintError, add, distance, load, mul, require, sub, unit

TIP_REACH = 0.05  # rig/pointer.gd: the fingertip is this far ahead of the hand's aim point
RAISE = (0.14, 0.4)  # rig/pointer.gd: raise_height (+ a margin) and raise_seconds
CREEP_SPEED = 0.15  # m/s, under rig/pointer.gd's sweep_speed: a hand moved this slowly never sweeps
# Where a child moves the hand (body frame, from the ready pose) when the ray lands on the wrong thing.
REAIM = [(0, 0.08, 0), (0, 0.16, 0), (-0.08, 0.1, 0), (0.08, 0.1, 0), (0, 0.16, 0.08)]


class Actor:
    def __init__(self, sim, body="medium"):
        bodies, limits, _ = load()
        self.sim = sim
        self.body = Body(bodies[body], limits, sim.observe()["rig"])
        # Sitting down: eyes upright and level, hands resting. Setup, not a movement.
        b = self.body
        sim.head(position=b.neck, at=add(b.neck, b.forward))
        for side in ("left", "right"):
            sim.hand(side, b.rest(side), at=add(b.rest(side), b.direction((0, -0.3, -1))))
        self.observe()

    def observe(self):
        observation = self.sim.observe()
        self.body.check_posture(observation)
        return observation

    def wait(self, seconds):
        self.sim.wait(seconds)

    # -- head ---------------------------------------------------------------

    def look_at(self, point):
        head = self.observe()["head"]
        eye = tuple(head["position"])
        forward = unit(sub(point, eye))
        self.body.check_head(eye, forward)
        self.sim.head(at=point, seconds=self.body.head_seconds(head["forward"], forward))

    def lean(self, offset, at):
        """Moves the eyes `offset` (body frame, metres) from sitting upright, looking at `at`."""
        head = self.observe()["head"]
        eye = add(self.body.neck, sub(self.body.world(offset), self.body.origin))
        forward = unit(sub(at, eye))
        self.body.check_head(eye, forward)
        self.sim.head(position=eye, at=at, seconds=max(distance(head["position"], eye) / 0.3, 0.1))

    # -- hands --------------------------------------------------------------

    def move_hand(self, side, end, at, seconds=None):
        """Moves a hand along a straight path the body allows, at a speed it can manage."""
        hand = self.observe()["hands"][side]
        require(hand["tracked"], "untracked", hand=side)
        start = tuple(hand["position"])
        points = self.body.path(side, start, end)
        seconds = self.body.hand_seconds(start, end, seconds)
        probe = self.sim.probe(points, self.body.limits.hand_radius)
        require(probe["clear"], "path_blocked", hand=side, blocker=probe.get("blocker"), at=probe.get("at"))
        self.sim.hand(side, end, at=at, seconds=seconds)

    def point(self, side, point, look=True, aim=None, expect=None):
        """Turns to `point`, raises the hand and pulls the trigger with the ray on `aim` (default: the
        point). With `expect` (a Target id) the child watches the ray first and, if it lands on
        something else, holds the hand higher or to the side until it lands on `expect`."""
        if look:
            self.face(point)
        self.body.check_view(self.observe()["head"], point)
        ready = self.body.ready(side)
        self.move_hand(side, ready, at=aim or point)
        for offset in REAIM:
            if expect is None or self.observe()["hands"][side]["aimed"] == expect:
                break
            spot = add(ready, sub(self.body.world(offset), self.body.origin))
            try:
                self.move_hand(side, spot, at=point)
            except ConstraintError:
                continue  # not a place this hand can go
        self.sim.click(side, "trigger_click")

    def face(self, point):
        """Turns the head towards `point` as far as it goes."""
        head = self.observe()["head"]
        eye = tuple(head["position"])
        yaw, pitch = self.body.head_angles(unit(sub(point, eye)))
        p = self.body.profile
        yaw, pitch = (math.radians(max(-p.max_yaw, min(p.max_yaw, yaw))),
                      math.radians(max(-p.max_pitch_down, min(p.max_pitch_up, pitch))))
        forward = self.body.direction((math.sin(yaw) * math.cos(pitch), math.sin(pitch), -math.cos(yaw) * math.cos(pitch)))
        self.sim.head(at=add(eye, forward), seconds=self.body.head_seconds(head["forward"], forward))

    def touch(self, side, point, radius, look=True):
        """Reaches until the fingertip is inside something of `radius` at `point`, then pulls back."""
        ready = self.body.ready(side)
        along = unit(sub(point, ready))
        hand = sub(point, mul(along, TIP_REACH + radius * 0.6))
        self.body.path(side, ready, hand)
        if look:
            self.face(point)
        self.body.check_view(self.observe()["head"], point)
        self.move_hand(side, ready, at=point)
        self.move_hand(side, hand, at=point)
        self.wait(0.15)
        self.move_hand(side, ready, at=point)

    def sweep(self, side, direction, length=0.25, seconds=0.35):
        """Sweeps the hand `length` metres along `direction` (world) in `seconds`, then holds
        still: the right way is judged as the hand goes, a wrong way once it has stopped. The hand
        first creeps to the start (slower than a sweep)."""
        ready = self.body.ready(side)
        start = sub(ready, mul(direction, length / 2))
        end = add(ready, mul(direction, length / 2))
        self.body.path(side, start, end)  # all of it before the sweep begins
        self.body.hand_seconds(start, end, seconds)
        aim = self.body.direction((0, -0.3, -1))
        self.creep(side, start, at=add(start, aim))
        self.move_hand(side, end, at=add(end, aim), seconds=seconds)
        self.wait(0.55)  # a sweep is done once the hand has been slow 0.4 s (Pointer.sweep_stop_seconds)

    def creep(self, side, end, at):
        """Moves a hand slower than a sweep (CREEP_SPEED), then rests it a moment."""
        hand = self.observe()["hands"][side]
        self.move_hand(side, end, at=at, seconds=max(distance(tuple(hand["position"]), end) / CREEP_SPEED, 0.05))
        self.wait(0.2)

    def help(self, side="right"):
        """Raises the hand above the eyes, holds it there and brings it back down."""
        hand = self.observe()["hands"][side]
        down, ahead = tuple(hand["position"]), add(tuple(hand["position"]), tuple(hand["forward"]))
        x = self.body.profile.shoulder_half_width * (-1 if side == "left" else 1)
        up = self.body.world((x, self.body.profile.eye_height + RAISE[0], -0.25))
        self.move_hand(side, up, at=add(up, self.body.direction((0, 1, -1))))
        self.wait(RAISE[1] + 0.1)
        self.move_hand(side, down, at=ahead)

    def rest(self, side):
        rest = self.body.rest(side)
        self.move_hand(side, rest, at=add(rest, self.body.direction((0, -0.3, -1))))

    def lose_tracking(self, side):
        self.sim.track(side, False)

    def regain_tracking(self, side):
        self.sim.track(side, True)


class Facilitator:
    """The adult steering the session from the in-headset panel, through the same controllers."""

    def __init__(self, sim, side="left"):
        self.sim = sim
        self.side = side

    def panel(self):
        return self.sim.observe()["facilitator"]

    def toggle(self):
        self.sim.click("menu", "menu_pressed")

    def open(self):
        if not self.panel()["open"]:
            self.toggle()
        require(self.panel()["open"], "panel_closed")

    def press(self, button):
        """Points at a panel button and pulls the trigger, then puts the controller back."""
        observation = self.sim.observe()
        found = [b for b in observation["facilitator"]["buttons"] if b["id"] == button]
        require(found, "no_button", button=button)
        head = observation["head"]
        before = observation["hands"][self.side]["position"]
        x = -0.12 if self.side == "left" else 0.12
        origin = add(add(add(head["position"], mul(head["x"], x)), mul(head["y"], -0.25)), mul(head["forward"], 0.1))
        self.sim.hand(self.side, origin, at=found[0]["position"], seconds=0.3)
        self.sim.click(self.side, "trigger_click")
        self.sim.hand(self.side, before, seconds=0.3)
