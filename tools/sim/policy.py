"""What the simulated child answers. A seeded TEST DRIVER, not a model of vision.

It turns engine facts (angular size, clutter, coherence, the view filter, the
hint level) into plausible right and wrong answers, help requests and timeouts,
so whole sessions can be played and the framework's reactions checked. The
curves and numbers are made up for coverage; they say nothing about how a
child who gained sight late actually sees.
"""

from dataclasses import dataclass
import math
import random

from body import Body, distance

HEADINGS = ["right", "left", "toward", "away"]
FLOWS = {"right": (1, 0, 0), "left": (-1, 0, 0), "toward": (0, 0, 1), "away": (0, 0, -1)}  # cloud frame


@dataclass(frozen=True)
class Perception:
    name: str
    acuity: float           # angular size (deg) at which a toy is recognised half the time
    accuracy: float         # best chance of a right answer
    clutter_cost: float     # chance lost per distractor
    motion_threshold: float  # coherence halfway between guessing and best
    motion_slope: float
    depth_cost: float       # extra coherence needed toward / away
    aim_error: float        # pointing scatter, degrees (sd)
    asks_help_after: int    # wrong tries in a round before pressing B / Y; 0 = never
    freeze: float           # chance a round gets no answer at all (it times out)
    touch: float            # chance of touching a toy in reach instead of pointing
    search: float           # seconds of looking per toy
    fumble: float           # chance a sweep is too small to count
    colour_gap: float       # hue difference (fraction of the wheel) told apart half the time


def logistic(x):
    return 1.0 / (1.0 + math.exp(-max(-60.0, min(60.0, x))))


def view_factor(view, at_focus):
    """How much the view filter changes the odds (made up, monotonic, for coverage)."""
    factor = 1.0
    if view["dim"] > 0 and not at_focus:
        factor *= 1.0 - 0.4 * view["dim"]
    if view["black_and_white"]:
        factor *= 0.85
    if view["edges"][3] > 0:
        factor *= 0.95
    factor *= 1.0 + 0.05 * max(0.0, min(view["contrast"], 2.0) - 1.0)
    return factor


class Policy:
    def __init__(self, perception, seed):
        self.perception = perception
        self.rng = random.Random(seed)

    def chance(self, p):
        return self.rng.random() < p

    # -- find it ---------------------------------------------------------------

    def find_odds(self, eye, target, others, view, hint, glow, same_colour, focus, colour_gap=None):
        """colour_gap: the target differs from the others only by this much hue."""
        p = self.perception
        size = Body.angular_size(eye, target["centre"], max(target["extent"]))
        odds = p.accuracy * logistic((size - p.acuity) / (0.25 * p.acuity))
        odds *= (1.0 - p.clutter_cost) ** len(others)
        if colour_gap is not None:
            odds *= logistic((colour_gap - p.colour_gap) / (0.25 * p.colour_gap))
        elif not same_colour and view["saturation"] < 1.0:
            odds *= 0.9 + 0.1 * view["saturation"]  # colour no longer tells the toys apart
        at_focus = view["focus_radius"] > 0 and distance(target["centre"], focus) <= view["focus_radius"]
        odds *= view_factor(view, at_focus)
        if hint >= 1:
            odds += (1.0 - odds) * 0.5  # it hops
        if glow:
            odds += (1.0 - odds) * 0.8
        return max(min(odds, 1.0), 1.0 / (len(others) + 1))

    def confuse(self, target, others):
        """A wrong toy: usually one close to the right one."""
        ranked = sorted(others, key=lambda toy: distance(toy["centre"], target["centre"]))
        return ranked[0] if self.chance(0.6) else self.rng.choice(others)

    # -- tidy up ----------------------------------------------------------------

    def tidy_odds(self, eye, thing, free, layout, hint):
        """Putting `thing` on its own sticker among `free` stickers left."""
        p = self.perception
        size = Body.angular_size(eye, thing["centre"], thing["size"])
        odds = p.accuracy * logistic((size - p.acuity) / (0.25 * p.acuity))
        odds *= (1.0 - p.clutter_cost) ** (free - 1)
        if layout["outline"]:
            odds *= 0.95  # only the edge to go by
        if layout["match"] == 1:
            odds *= 0.9  # sizes look alike from afar
        if hint >= 1:
            odds += (1.0 - odds) * 0.5  # its sticker wiggles
        if hint >= 2:
            odds += (1.0 - odds) * 0.8  # its cubby shines
        return max(min(odds, 1.0), 1.0 / free)

    # -- read the flow -----------------------------------------------------------

    def motion_odds(self, coherence, plane, competing):
        p = self.perception
        guess = 0.5 if competing else 0.25
        threshold = p.motion_threshold + (p.depth_cost if plane == "depth" else 0.0)
        return guess + (p.accuracy - guess) * logistic((coherence - threshold) / p.motion_slope)

    def wrong_heading(self, heading, competing):
        opposite = {"right": "left", "left": "right", "toward": "away", "away": "toward"}[heading]
        if competing and self.chance(0.7):
            return opposite
        return self.rng.choice([h for h in HEADINGS if h != heading])

    # -- real objects ----------------------------------------------------------------

    def real_odds(self, eye, obj):
        p = self.perception
        size = Body.angular_size(eye, obj["centre"], max(obj["extent"]))
        return p.accuracy * logistic((size - p.acuity) / (0.25 * p.acuity))

    # -- behaviour -----------------------------------------------------------------------

    def aim_offset(self, eye, point):
        """`point` moved by a random pointing error of about aim_error degrees."""
        error = math.radians(abs(self.rng.gauss(0.0, self.perception.aim_error)))
        turn = self.rng.uniform(0.0, 2.0 * math.pi)
        reach = distance(eye, point) * math.tan(error)
        return (point[0] + reach * math.cos(turn), point[1] + reach * math.sin(turn) * 0.5, point[2])

    def freezes(self, can_time_out):
        return can_time_out and self.chance(self.perception.freeze)

    def wants_help(self, tries):
        after = self.perception.asks_help_after
        return after > 0 and tries >= after and tries % after == 0
