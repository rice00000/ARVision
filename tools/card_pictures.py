"""Draws the level-card pictures (content/tasks/pictures/*.svg): big, simple, high contrast,
for children who cannot read the titles yet. Each Task level names its picture.

    python3 tools/card_pictures.py
"""
import math, random, sys
from pathlib import Path

OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "content/tasks/pictures"
LIGHT, DARK = "#f7f1e3", "#13202b"
INK = "#2a323a"
SIL = "#5d6570"
PAPER, PAPER_EDGE = "#e6dfcd", "#a89e88"
RED, BLUE, YELLOW, GREEN, PURPLE, ORANGE = "#ef4b3f", "#3f8cf0", "#f8c935", "#43b96a", "#9a68e3", "#f59a2f"
WOOD, WOOD_DARK = "#b07a45", "#7b5130"
ODD_BLUE, ODD_ORANGE, ODD_TEAL, ODD_NEAR = "#4c9cd9", "#cb8740", "#12a3c8", "#429ed6"


def svg(name, body, tile=LIGHT):
    (OUT / f"{name}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">\n'
        f'<rect x="4" y="4" width="248" height="248" rx="34" fill="{tile}" stroke="#2a323a" stroke-width="6"/>\n{body}\n</svg>\n')


def ball(x, y, r, c):
    return (f'<circle cx="{x}" cy="{y}" r="{r}" fill="{c}" stroke="{INK}" stroke-width="5"/>'
            f'<circle cx="{x - r * .35}" cy="{y - r * .35}" r="{r * .22}" fill="#ffffff" opacity=".7"/>')


def block(x, y, s, c):
    return f'<rect x="{x - s / 2}" y="{y - s / 2}" width="{s}" height="{s}" rx="{s * .12}" fill="{c}" stroke="{INK}" stroke-width="5"/>'


def cone(x, y, s, c, stroke=INK):
    return f'<path d="M{x} {y - s * .6} L{x + s * .5} {y + s * .4} L{x - s * .5} {y + s * .4} Z" fill="{c}" stroke="{stroke}" stroke-width="5" stroke-linejoin="round"/>'


def sticker(x, y, w, h):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="{PAPER}" stroke="{PAPER_EDGE}" stroke-width="4"/>'


def arrow(x1, y1, x2, y2, c=INK, w=9):
    a = math.atan2(y2 - y1, x2 - x1)
    hx, hy = x2 - 20 * math.cos(a), y2 - 20 * math.sin(a)
    l, r = (hx + 13 * math.cos(a + math.pi / 2), hy + 13 * math.sin(a + math.pi / 2)), (hx - 13 * math.cos(a + math.pi / 2), hy - 13 * math.sin(a + math.pi / 2))
    return (f'<line x1="{x1}" y1="{y1}" x2="{hx}" y2="{hy}" stroke="{c}" stroke-width="{w}" stroke-linecap="round"/>'
            f'<path d="M{x2} {y2} L{l[0]:.1f} {l[1]:.1f} L{r[0]:.1f} {r[1]:.1f} Z" fill="{c}"/>')


def butterfly(x, y, s, angle, c=ORANGE):
    """Seen from above, flying toward [angle] degrees."""
    w = (f'<ellipse cx="-.45" cy="-.38" rx=".42" ry=".34" fill="{c}" stroke="{INK}" stroke-width=".09"/>'
         f'<ellipse cx=".45" cy="-.38" rx=".42" ry=".34" fill="{c}" stroke="{INK}" stroke-width=".09"/>'
         f'<ellipse cx="-.32" cy=".3" rx=".3" ry=".26" fill="{c}" stroke="{INK}" stroke-width=".09"/>'
         f'<ellipse cx=".32" cy=".3" rx=".3" ry=".26" fill="{c}" stroke="{INK}" stroke-width=".09"/>'
         f'<ellipse cx="0" cy="0" rx=".09" ry=".5" fill="{INK}"/>')
    return f'<g transform="translate({x:.1f} {y:.1f}) rotate({angle + 90:.1f}) scale({s})">{w}</g>'


def ring_path(cx, cy, r, clockwise, c=INK):
    """A dashed circle with an arrowhead showing the way round."""
    a = -40 if clockwise else 220
    t = math.radians(a)
    px, py = cx + r * math.cos(t), cy + r * math.sin(t)
    d = 1 if clockwise else -1
    tx, ty = -math.sin(t) * d, math.cos(t) * d
    nx, ny = math.cos(t), math.sin(t)
    tip = (px + tx * 20, py + ty * 20)
    head = f'M{tip[0]:.1f} {tip[1]:.1f} L{px + nx * 13:.1f} {py + ny * 13:.1f} L{px - nx * 13:.1f} {py - ny * 13:.1f} Z'
    return (f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="none" stroke="{c}" stroke-width="6" stroke-dasharray="14 12" opacity=".55"/>'
            f'<path d="{head}" fill="{c}"/>')


def on_ring(cx, cy, r, count, clockwise, s, c, start=0, jitter=0.0, rng=None):
    out = []
    for i in range(count):
        a = start + 360 * i / count
        t = math.radians(a)
        heading = a + (90 if clockwise else -90)
        if jitter and rng.random() < jitter:
            heading = rng.uniform(0, 360)
        out.append(butterfly(cx + r * math.cos(t), cy + r * math.sin(t), s, heading, c))
    return "".join(out)


def dots(flow_share, rng, count=22):
    out = []
    for i in range(count):
        x, y = rng.uniform(40, 216), rng.uniform(40, 216)
        a = 0.0 if rng.random() < flow_share else rng.uniform(0, 2 * math.pi)
        tail = 26
        out.append(f'<line x1="{x - tail * math.cos(a):.1f}" y1="{y - tail * math.sin(a):.1f}" x2="{x:.1f}" y2="{y:.1f}" '
                   f'stroke="#9fd3ff" stroke-width="6" stroke-linecap="round" opacity=".55"/>'
                   f'<circle cx="{x:.1f}" cy="{y:.1f}" r="8" fill="#ffffff"/>')
    return "".join(out)


rng = random.Random(7)
svg("shadow", sticker(132, 52, 104, 152) + f'<circle cx="184" cy="128" r="38" fill="{SIL}"/>' + ball(70, 168, 44, RED) + arrow(70, 104, 128, 80))
svg("similar_shadows", sticker(118, 34, 122, 188) + f'<ellipse cx="179" cy="82" rx="28" ry="36" fill="{SIL}"/><circle cx="179" cy="172" r="33" fill="{SIL}"/>'
    + f'<ellipse cx="62" cy="150" rx="38" ry="50" fill="{YELLOW}" stroke="{INK}" stroke-width="5"/>')
mug_outline = f'<path d="M150 112 h58 v64 a10 10 0 0 1 -10 10 h-38 a10 10 0 0 1 -10 -10 Z M208 126 h14 a14 14 0 0 1 0 28 h-14" fill="none" stroke="{INK}" stroke-width="5" stroke-dasharray="11 8"/>'
mug = f'<path d="M40 90 h62 v70 a12 12 0 0 1 -12 12 h-38 a12 12 0 0 1 -12 -12 Z" fill="{BLUE}" stroke="{INK}" stroke-width="5"/><path d="M102 106 h14 a16 16 0 0 1 0 32 h-14" fill="none" stroke="{INK}" stroke-width="9"/>'
svg("study", f'<rect x="16" y="190" width="224" height="22" rx="6" fill="{WOOD}" stroke="{WOOD_DARK}" stroke-width="4"/>' + mug_outline.replace("112", "122").replace("v64", "v64")
    + mug + arrow(118, 70, 160, 92))
shelf = f'<rect x="26" y="40" width="204" height="176" rx="8" fill="{WOOD}" stroke="{WOOD_DARK}" stroke-width="6"/>'
for cx in (60, 128, 196):
    for cy in (84, 172):
        shelf += f'<rect x="{cx - 30}" y="{cy - 36}" width="60" height="72" rx="4" fill="#5b3b22"/>'
glass = 'fill="#cfeaff" fill-opacity=".55" stroke="#ffffff" stroke-width="5"'
shelf += f'<circle cx="60" cy="88" r="20" {glass}/><path d="M128 64 L150 108 L106 108 Z" {glass}/><rect x="176" y="68" width="40" height="40" rx="5" {glass}/>'
shelf += f'<path d="M60 152 l18 18 l-18 18 l-18 -18 Z" {glass}/><circle cx="128" cy="176" r="20" fill="none" stroke="#ffffff" stroke-width="9" stroke-opacity=".8"/>'
svg("bookshelf", shelf)
sw = (f'<ellipse cx="128" cy="200" rx="104" ry="24" fill="#ffffff" stroke="{INK}" stroke-width="5"/>'
      f'<rect x="44" y="160" width="168" height="30" rx="12" fill="#d9a35b" stroke="{INK}" stroke-width="5"/>'
      f'<path d="M38 156 q14 -16 28 0 q14 -16 28 0 q14 -16 28 0 q14 -16 28 0 q14 -16 28 0 q14 -16 28 0 v-8 h-168 Z" fill="{GREEN}" stroke="{INK}" stroke-width="4"/>'
      f'<rect x="50" y="122" width="156" height="22" rx="10" fill="{RED}" stroke="{INK}" stroke-width="5"/>'
      f'<rect x="44" y="102" width="168" height="18" rx="4" fill="{YELLOW}" stroke="{INK}" stroke-width="5"/>'
      f'<path d="M44 100 q0 -44 84 -44 q84 0 84 44 Z" fill="#d9a35b" stroke="{INK}" stroke-width="5"/>')
svg("sandwich", sw)
svg("size", f'<rect x="16" y="196" width="224" height="10" rx="5" fill="{PAPER_EDGE}"/>' + block(40, 174, 36, BLUE) + block(106, 162, 60, BLUE) + block(188, 147, 90, BLUE))
svg("color", sticker(14, 60, 70, 140) + sticker(93, 60, 70, 140) + sticker(172, 60, 70, 140) + cone(49, 132, 56, RED) + cone(128, 132, 56, BLUE) + cone(207, 132, 56, YELLOW))
junk = ""
for i in range(14):
    x, y = rng.uniform(34, 222), rng.uniform(34, 222)
    if math.hypot(x - 128, y - 128) < 58:
        continue
    k = rng.random()
    if k < .4:
        junk += f'<rect x="{x - 26:.0f}" y="{y - 5:.0f}" width="52" height="10" rx="4" fill="#8d8270" transform="rotate({rng.uniform(0, 180):.0f} {x:.0f} {y:.0f})"/>'
    elif k < .7:
        junk += f'<circle cx="{x:.0f}" cy="{y:.0f}" r="13" fill="#b9b2a2" stroke="#8d8270" stroke-width="3"/>'
    else:
        junk += f'<path d="M{x - 16:.0f} {y - 10:.0f} l30 4 l-6 20 l-26 -6 Z" fill="#a7a091"/>'
svg("clutter", junk + f'<circle cx="128" cy="128" r="40" fill="none" stroke="{INK}" stroke-width="30"/><circle cx="128" cy="128" r="40" fill="none" stroke="{GREEN}" stroke-width="20"/>')


def odd(name, odd_colour, extra=""):
    svg(name, block(56, 140, 58, ODD_BLUE) + block(128, 140, 58, ODD_BLUE) + block(200, 140, 58, odd_colour) + extra)


odd("odd_color_1", ODD_ORANGE)
odd("odd_color_2", ODD_TEAL)
steps = f'<path d="M150 70 h20 v-16 h20 v-16 h20 v-16 h12 v58 h-72 Z" fill="{INK}" opacity=".85"/>'
odd("odd_color_adaptive", "#7cc0ee", steps.replace("v58", "v58"))
svg("steady_flow", dots(1.0, rng) + arrow(70, 226, 186, 226, "#ffd75e", 10), DARK)
svg("mixed_flow", dots(0.55, rng, 28) + arrow(70, 226, 186, 226, "#ffd75e", 10), DARK)
SKY = "#e3f1df"
svg("one_way", ring_path(128, 128, 84, True) + on_ring(128, 128, 84, 4, True, 34, ORANGE, start=20), SKY)
svg("both_ways", ring_path(128, 128, 96, True) + ring_path(128, 128, 50, False, "#2f5f9e")
    + on_ring(128, 128, 96, 5, True, 26, ORANGE, start=10) + on_ring(128, 128, 50, 3, False, 24, BLUE, start=60), SKY)
svg("swarm", ring_path(128, 128, 88, True) + on_ring(128, 128, 88, 10, True, 22, ORANGE, start=5)
    + on_ring(128, 128, 54, 6, True, 18, ORANGE, start=30), SKY)
svg("busy_swarm", ring_path(128, 128, 88, True) + on_ring(128, 128, 92, 14, True, 18, ORANGE, start=5, jitter=.45, rng=rng)
    + on_ring(128, 128, 56, 9, True, 16, ORANGE, start=20, jitter=.45, rng=rng), SKY)
cup = f'<path d="M150 70 h72 l-10 110 h-52 Z" fill="{SIL}" transform="rotate(14 186 125)"/>'
cup += f'<path d="M44 92 h72 l-10 110 h-52 Z" fill="{ORANGE}" stroke="{INK}" stroke-width="5"/><ellipse cx="80" cy="92" rx="36" ry="10" fill="#c8641f" stroke="{INK}" stroke-width="5"/>'
cup += f'<path d="M62 52 a40 40 0 0 1 56 6" fill="none" stroke="{INK}" stroke-width="8"/><path d="M122 46 l2 22 l-20 -6 Z" fill="{INK}"/>'
svg("turn_to_fit", cup)
print("\n".join(sorted(p.name for p in OUT.glob("*.svg"))))
