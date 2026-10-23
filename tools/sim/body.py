"""A seated child's body: pure geometry, no Godot.

The body sits still on its chair (the rig): shoulders never move, the head turns
and leans a little, hands reach within the arm. Anything it cannot do raises
ConstraintError with a code (reach, torso, head_yaw, head_pitch, head_lean,
out_of_view, behind_head, hand_speed, path_blocked) and evidence. Profiles in
profiles.json are synthetic, not measured children.
"""

from dataclasses import asdict, dataclass
import json
import math
from pathlib import Path

PROFILES = Path(__file__).with_name("profiles.json")


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def mul(a, k):
    return tuple(x * k for x in a)


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def length(a):
    return math.sqrt(dot(a, a))


def unit(a):
    return mul(a, 1.0 / length(a))


def distance(a, b):
    return length(sub(a, b))


def degrees_between(a, b):
    return math.degrees(math.acos(max(-1.0, min(1.0, dot(unit(a), unit(b))))))


class ConstraintError(AssertionError):
    """Something this body cannot do. `code` names the limit; `evidence` says by how much."""

    def __init__(self, code, **evidence):
        self.code = code
        self.evidence = evidence
        super().__init__(f"{code}: {json.dumps(evidence, sort_keys=True, default=str)}")


def require(condition, code, **evidence):
    if not condition:
        raise ConstraintError(code, **evidence)


@dataclass(frozen=True)
class BodyProfile:
    name: str
    eye_height: float
    shoulder_half_width: float
    shoulder_drop: float
    arm_length: float
    comfortable_reach: float
    hand_speed: float
    head_speed: float
    max_yaw: float
    max_pitch_up: float
    max_pitch_down: float
    max_lean: float
    reaction: float

    def __post_init__(self):
        if any(not math.isfinite(v) or v <= 0 for k, v in asdict(self).items() if k != "name"):
            raise ValueError(f"{self.name}: body values must be finite and positive")
        if self.comfortable_reach > self.arm_length:
            raise ValueError(f"{self.name}: comfortable reach beyond the arm")


@dataclass(frozen=True)
class Limits:
    fov_h: float
    fov_v: float
    view_margin: float
    hand_radius: float
    torso_radius: float
    path_step: float


def load(path=PROFILES):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    bodies = {p["name"]: BodyProfile(**p) for p in data["bodies"]}
    return bodies, Limits(**data["limits"]), data


class Body:
    """`rig` is the chair's frame from an observation: {position, x, y, z} (world axes)."""

    def __init__(self, profile, limits, rig):
        self.profile = profile
        self.limits = limits
        self.origin = tuple(rig["position"])
        self.axes = (tuple(rig["x"]), tuple(rig["y"]), tuple(rig["z"]))
        self.neck = self.world((0.0, profile.eye_height, 0.0))  # the eyes sitting upright

    # -- frames -------------------------------------------------------------

    def world(self, local):
        return add(self.origin, tuple(sum(self.axes[j][i] * local[j] for j in range(3)) for i in range(3)))

    def local(self, point):
        relative = sub(point, self.origin)
        return tuple(dot(relative, axis) for axis in self.axes)

    def direction(self, local):
        return unit(tuple(sum(self.axes[j][i] * local[j] for j in range(3)) for i in range(3)))

    @property
    def forward(self):
        return mul(self.axes[2], -1.0)

    def shoulder(self, side):
        x = self.profile.shoulder_half_width * (-1 if side == "left" else 1)
        return self.world((x, self.profile.eye_height - self.profile.shoulder_drop, 0.0))

    def rest(self, side):
        """Hands resting at the table's near edge."""
        x = (self.profile.shoulder_half_width + 0.03) * (-1 if side == "left" else 1)
        return self.world((x, self.profile.eye_height - self.profile.shoulder_drop - 0.05, -0.15))

    def ready(self, side):
        """Where a hand is held up to point or sweep: in front of the shoulder."""
        x = self.profile.shoulder_half_width * (-1 if side == "left" else 1)
        return self.world((x, self.profile.eye_height - self.profile.shoulder_drop - 0.02, -0.22))

    # -- limits ---------------------------------------------------------------

    def check_reach(self, side, point, comfortable=False):
        limit = self.profile.comfortable_reach if comfortable else self.profile.arm_length
        measured = distance(self.shoulder(side), point)
        require(measured <= limit + 1e-6, "reach", hand=side, measured=round(measured, 3), limit=limit,
                body=self.profile.name, point=point)

    def check_hand(self, side, point):
        """A hand at `point`: within the arm and outside the torso."""
        self.check_reach(side, point)
        local = self.local(point)
        top = self.profile.eye_height - self.profile.shoulder_drop + 0.02  # torso: an upright cylinder
        beside = top - 0.5 <= local[1] <= top
        clearance = math.hypot(local[0], local[2] - 0.05) if beside else math.inf
        require(clearance >= self.limits.torso_radius + self.limits.hand_radius, "torso", hand=side,
                clearance=round(clearance, 3))

    def head_angles(self, forward):
        """Yaw (right +) and pitch (up +) of a gaze direction, relative to the body, degrees."""
        f = tuple(dot(forward, axis) for axis in self.axes)
        return math.degrees(math.atan2(f[0], -f[2])), math.degrees(math.atan2(f[1], math.hypot(f[0], f[2])))

    def check_head(self, eye, forward):
        yaw, pitch = self.head_angles(forward)
        # face() turns to exactly a limit; the engine's float32 pose lands a hair past it.
        require(abs(yaw) <= self.profile.max_yaw + 1e-3, "head_yaw", degrees=round(yaw, 1), limit=self.profile.max_yaw)
        require(-self.profile.max_pitch_down - 1e-3 <= pitch <= self.profile.max_pitch_up + 1e-3, "head_pitch",
                degrees=round(pitch, 1), up=self.profile.max_pitch_up, down=self.profile.max_pitch_down)
        lean = distance(eye, self.neck)
        require(lean <= self.profile.max_lean + 1e-6, "head_lean", metres=round(lean, 3), limit=self.profile.max_lean)

    def view_angles(self, head, point):
        """Horizontal and vertical angle of `point` off the gaze, and whether it is in front."""
        relative = sub(point, head["position"])
        x, y, z = (dot(relative, tuple(head[axis])) for axis in ("x", "y", "z"))
        return math.degrees(math.atan2(x, -z)), math.degrees(math.atan2(y, -z)), z < 0

    def check_view(self, head, point):
        """`point` must be in front of the eyes and inside the headset's view."""
        horizontal, vertical, ahead = self.view_angles(head, point)
        require(ahead, "behind_head", point=point)
        half_h = self.limits.fov_h / 2 - self.limits.view_margin
        half_v = self.limits.fov_v / 2 - self.limits.view_margin
        require(abs(horizontal) <= half_h and abs(vertical) <= half_v, "out_of_view",
                horizontal=round(horizontal, 1), vertical=round(vertical, 1), limit=[half_h, half_v])

    @staticmethod
    def angular_size(eye, centre, extent):
        """Visual angle of something `extent` metres across at `centre`, degrees."""
        return math.degrees(2.0 * math.atan(extent / 2.0 / max(distance(eye, centre), 1e-6)))

    def path(self, side, start, end):
        """Points every path_step along a straight hand move, each checked."""
        steps = max(1, math.ceil(distance(start, end) / self.limits.path_step))
        points = [add(start, mul(sub(end, start), i / steps)) for i in range(steps + 1)]
        for point in points:
            self.check_hand(side, point)
        return points

    def hand_seconds(self, start, end, seconds=None):
        """Duration of a hand move: half the top speed by default, or `seconds` if the hand can go that fast."""
        needed = distance(start, end) / self.profile.hand_speed
        if seconds is None:
            return max(2.0 * needed, 0.05)
        require(seconds >= needed - 1e-6, "hand_speed", metres=round(distance(start, end), 3),
                seconds=seconds, limit=self.profile.hand_speed)
        return seconds

    def head_seconds(self, from_forward, to_forward):
        return max(degrees_between(from_forward, to_forward) / self.profile.head_speed, 0.05)

    def check_posture(self, observation):
        """The engine still shows a body this one could be in."""
        rig = observation["rig"]
        require(distance(rig["position"], self.origin) < 1e-3, "body_moved", start=self.origin, now=rig["position"])
        head = observation["head"]
        self.check_head(tuple(head["position"]), tuple(head["forward"]))
        for side, hand in observation["hands"].items():
            if hand["tracked"]:
                self.check_hand(side, tuple(hand["position"]))
