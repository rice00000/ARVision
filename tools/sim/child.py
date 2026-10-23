"""A simulated child playing whole sessions: an Actor's seated body answering with a Policy.

The policy is a test driver, not a model of vision (see policy.py). A round can
also follow a script of steps, for exact scenarios:

    right, wrong, touch    answer (touch: reach for the named toy instead of pointing)
    right:left             answer with the left hand
    invalid                a sweep too small to count (motion)
    help                   press B / Y
    wait:<seconds>         do nothing for a while
    freeze                 never answer: the round runs out of time
"""

import json
import math
import re

from actor import Actor
from body import PROFILES, ConstraintError, add, degrees_between, distance, mul, sub, unit
from policy import FLOWS, Perception, Policy

FIND_LINE = re.compile(r"^Find the (.+)!$")
POINT_LINE = re.compile(r"^Point at the (.+) and pull the trigger\.$")
SCAN = [0, -35, 35, -60, 60]


def perceptions():
    data = json.loads(PROFILES.read_text(encoding="utf-8"))
    return {p["name"]: Perception(**p) for p in data["perceptions"]}


class Child:
    def __init__(self, sim, body="medium", perception="typical", seed=1):
        self.sim = sim
        self.actor = Actor(sim, body)
        self.policy = Policy(perceptions()[perception], seed)
        self.hears = "Voice" in sim.observe()["modules"]  # unplugged, the guide is silent
        self.played = []  # (trial, round, steps taken)

    # -- sessions ---------------------------------------------------------------

    def play(self, scripts=None, timeout=900):
        """Plays every round until the session finishes. `scripts` maps a trial id, or
        (trial id, round index within the session), to a script; the rest use the policy."""
        scripts = scripts or {}
        count = 0
        while True:
            event = self.sim.run_until("trial_started", "session_finished", timeout=timeout)
            assert event, "the session stalled"
            if event["event"] == "session_finished":
                return
            script = scripts.get((event["trial"], count), scripts.get(event["trial"]))
            self.play_round(event, script)
            count += 1

    def play_round(self, started, script=None):
        steps = None if script is None else list(script)
        kind = started["trial"]
        taken = []
        self.actor.wait(self.actor.body.profile.reaction)
        can_time_out = self.sim.observe()["session"]["trial"]["time_limit"] > 0
        if steps is None and self.policy.freezes(can_time_out):
            steps = ["freeze"]
        while self.result(started) is None:
            step = steps.pop(0) if steps else None
            if steps is not None and step is None:
                break  # script done; the round goes on without the child
            step = step or self.decide(kind, started, taken)
            taken.append(step)
            self.act(kind, started, step)
            if len(taken) > 30:
                step = "freeze"
                self.act(kind, started, step)
        self.played.append((kind, started["condition"]["round"], taken))
        return self.result(started)

    def result(self, started):
        """The event that ended the round that began with `started`, or None while it runs."""
        for event in self.sim.events(since=started["seq"]):
            if event["event"] == "trial_ended" or (event["event"] == "reported" and event["what"] == "round_abandoned"):
                return event
            if event["event"] in ("trial_started", "session_finished"):
                return event
        return None

    # -- choosing -------------------------------------------------------------------

    def decide(self, kind, started, taken):
        tries = sum(1 for step in taken if step.startswith("wrong"))
        if taken and taken[-1].startswith("wrong") and self.policy.wants_help(tries):
            return "help"
        if kind.startswith("motion") and self.policy.chance(self.policy.perception.fumble):
            return "invalid"
        observation = self.actor.observe()
        return "right" if self.policy.chance(self.odds(kind, started, observation)) else "wrong"

    def odds(self, kind, started, observation):
        trial = observation["session"]["trial"]
        eye = observation["head"]["position"]
        view = observation["view"]
        if kind == "find":
            target, others = self.toys(started, observation)
            if target is None:
                return 1.0 / (len(others) or 1)  # never heard which: a guess
            same = trial["condition"]["values"]["same_colour"] > 0.5
            return self.policy.find_odds(eye, target, others, view, trial["hint"], target["glow"], same,
                                         observation["work_surface"]["position"])
        if kind.startswith("motion"):
            cloud = observation["stimuli"]["cloud"]
            values = trial["condition"]["values"]
            return self.policy.motion_odds(cloud["signal_count"] / cloud["dot_count"], values["plane"], cloud["competing"])
        named = self.real_object(started, observation)
        return self.policy.real_odds(eye, named) if named else 0.0

    # -- acting ---------------------------------------------------------------------------

    def act(self, kind, started, step):
        name, _, arg = step.partition(":")
        if name == "help":
            self.actor.help()
        elif name == "wait":
            self.actor.wait(float(arg))
            return
        elif name == "freeze":
            while self.result(started) is None:
                self.actor.wait(1.0)
            return
        elif kind == "find":
            self.find(started, name, arg or "right")
        elif kind.startswith("motion"):
            self.motion(started, name, arg or ("right" if started["condition"]["round"] % 2 == 0 else "left"))
        else:
            self.point_real(started, name, arg or "right")
        if self.result(started) is None:
            self.actor.wait(0.6 + self.policy.perception.search)  # looks again before the next go

    def find(self, started, name, side):
        observation = self.actor.observe()
        target, others = self.toys(started, observation)
        if target is None:  # did not hear which toy: any one
            target = self.policy.rng.choice(others)
            others = [toy for toy in others if toy is not target]
        toy = target if name in ("right", "touch") else self.policy.confuse(target, others)
        self.actor.wait(self.policy.perception.search * (len(others) + 1))
        point = tuple(toy["centre"])
        try:
            self.actor.body.check_reach(side, point, comfortable=True)
            reachable = True
        except ConstraintError:
            reachable = False
        if name == "touch" or (reachable and self.policy.chance(self.policy.perception.touch)):
            try:
                self.actor.touch(side, point, toy["radius"])
                return
            except ConstraintError:
                if name == "touch":
                    raise  # a scripted touch must happen; a chosen one falls back to pointing
        self.actor.face(point)
        self.actor.point(side, point, look=False, aim=self.policy.aim_offset(observation["head"]["position"], point),
                         expect=toy["id"])

    def toys(self, started, observation):
        """The named toy (None if the child did not hear or see which) and the others."""
        toys = observation["stimuli"]["targets"]
        heard = self.heard(started, FIND_LINE)
        hinted = observation["session"]["trial"]["hint"] > 0 and observation["stimuli"]["named"]
        named = heard or hinted  # the guide said it, or the help shows it
        target = next((toy for toy in toys if named and toy["id"].endswith("_" + named)), None)
        return target, [toy for toy in toys if toy is not target]

    def motion(self, started, name, side):
        observation = self.actor.observe()
        cloud = observation["stimuli"]["cloud"]
        heading = observation["session"]["trial"]["condition"]["values"]["heading"]
        self.actor.face(tuple(cloud["position"]))
        self.actor.wait(1.0)  # watch the dots
        if name == "invalid":
            self.actor.sweep(side, self.world(cloud, FLOWS[heading]), length=0.05)
            return
        if name == "wrong":
            heading = self.policy.wrong_heading(heading, cloud["competing"])
        self.actor.sweep(side, self.world(cloud, FLOWS[heading]))

    @staticmethod
    def world(frame, local):
        return unit(add(add(mul(frame["x"], local[0]), mul(frame["y"], local[1])), mul(frame["z"], local[2])))

    def point_real(self, started, name, side):
        observation = self.actor.observe()
        named = self.real_object(started, observation)
        if named is None:
            named = self.search(started)
            if named is None:
                return
            observation = self.actor.observe()
        hand = self.actor.body.ready(side)
        apart = lambda o: degrees_between(sub(tuple(o["centre"]), hand), sub(tuple(named["centre"]), hand))
        # A wrong pick is another object well off the named one's line: from the hand, something behind
        # or in front of it lies on the same ray, and the trial would count it as right.
        others = [o for o in self.seen(observation) if o["label"] != named["label"] and apart(o) > 20.0]
        point = tuple(named["centre"])
        if name == "wrong" and others:
            point = tuple(self.policy.rng.choice(others)["centre"])
        elif name == "wrong":  # nothing else in view: point well to the side of it
            point = add(point, mul(self.actor.body.direction((1, 0, 0)), distance(hand, point) * math.tan(math.radians(25))))
        self.actor.face(point)
        self.actor.point(side, point, look=False, aim=self.policy.aim_offset(observation["head"]["position"], point))

    def real_object(self, started, observation):
        label = self.heard(started, POINT_LINE)
        return next((o for o in observation["real_objects"] if o["label"] == label), None) if label else None

    def search(self, started):
        """Looks around until the guide names something."""
        body = self.actor.body
        for yaw in SCAN:
            ahead = add(body.neck, body.direction((math.sin(math.radians(yaw)), -0.3, -math.cos(math.radians(yaw)))))
            self.actor.face(ahead)
            self.actor.wait(1.0)  # the detector looks twice a second
            named = self.real_object(started, self.actor.observe())
            if named:
                return named
        return None

    def seen(self, observation):
        """Real objects the eyes have a clear line to and the head can turn to."""
        eye = tuple(observation["head"]["position"])
        found = []
        for obj in observation["real_objects"]:
            try:
                self.actor.body.check_head(eye, unit(sub(tuple(obj["centre"]), eye)))
            except ConstraintError:
                continue
            if obj["clear"] and distance(eye, obj["centre"]) < 4.0:
                found.append(obj)
        return found

    def heard(self, started, pattern):
        """What the guide named this round, if the child could hear it (Voice plugged in)."""
        if not self.hears:
            return None
        for event in self.sim.events("said", since=started["seq"] - 2):
            match = pattern.match(event["text"])
            if match:
                return match.group(1)
        return None
