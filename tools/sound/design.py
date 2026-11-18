"""Builds the game's sound effects from the team's SFX library (E:/SFXs) and tuned synthesis.

Run: python tools/sound/design.py [name ...]   (no names: build all). Writes OGG files into the project.
Every tonal sound is in C major, the key of the piano loop, so effects sit inside the music.
Levels: the loudest 100 ms of each file is set to a target in dBFS; the voice clips sit near -13.
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sfx import *  # noqa: F401,F403

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
UP = '250811上官/'
SRC = {
    'pop1': UP + 'Deb Sound/Pops-UI（界面）/Pop_Mouth_Human_Drop_Droplet_01.wav',
    'pop9': UP + 'Deb Sound/Pops-UI（界面）/Pop_Mouth_Human_Drop_Droplet_09.wav',
    'pop14': UP + 'Deb Sound/Pops-UI（界面）/Pop_Mouth_Human_Drop_Droplet_14.wav',
    'pop6': UP + 'Deb Sound/Pops-UI（界面）/Pop_Mouth_Human_Drop_Droplet_06.wav',
    'air1': UP + 'Cinetools/CT012 Overtonics（动作恐怖科幻冒险）/Whooshes/OT_Whoosh_SoftAirMovement_v1_CT.wav',
    'air2': UP + 'Cinetools/CT012 Overtonics（动作恐怖科幻冒险）/Whooshes/OT_Whoosh_SoftAirMovement_v2_CT.wav',
    'air3': UP + 'Cinetools/CT012 Overtonics（动作恐怖科幻冒险）/Whooshes/OT_Whoosh_SoftAirMovement_v3_CT.wav',
    'air4': UP + 'Cinetools/CT012 Overtonics（动作恐怖科幻冒险）/Whooshes/OT_Whoosh_SoftAirMovement_v4_CT.wav',
    'wood': UP + 'Blue box/comic_effects - 漫画效果/percussion/wood_mix.wav',
    'crystal': UP + 'Carma Studio/CAFOFO/Interface（UI）/crystal_reward_tick.wav',
    'gem_g': UP + 'Cinetools/ST069 Treasure Chest（宝箱）/TCH_Gems_Green_1_ST.wav',
    'gem_y': UP + 'Cinetools/ST069 Treasure Chest（宝箱）/TCH_Gems_Yellow_1_ST.wav',
    'bells': UP + 'CB_Sounddesign/Dreamcatcher（悠扬梦幻氛围）/01_Accents/Bells_shaking_01.wav',
    'windbells': UP + 'CB_Sounddesign/Dreamcatcher（悠扬梦幻氛围）/01_Accents/Windbells_1.wav',
    'guitar_c': UP + 'CB_Sounddesign/Dreamcatcher（悠扬梦幻氛围）/01_Accents/Guitar_Dreamchord_C_Major.wav',
    'harp_e': UP + 'CB_Sounddesign/Dreamcatcher（悠扬梦幻氛围）/01_Accents/Harp_Glissando_13b.wav',
    'pickup1': UP + 'Cinetools/ST025 Books & Magazines（书籍杂志）/Books & Magazines/BM_Bookshelf_PickUp_1_ST.wav',
    'pickup3': UP + 'Cinetools/ST025 Books & Magazines（书籍杂志）/Books & Magazines/BM_Bookshelf_PickUp_3_ST.wav',
    'pickup4': UP + 'Cinetools/ST025 Books & Magazines（书籍杂志）/Books & Magazines/BM_Bookshelf_PickUp_4_ST.wav',
    'place1': UP + 'Cinetools/ST025 Books & Magazines（书籍杂志）/Books & Magazines/BM_Bookshelf_Placement_1_ST.wav',
    'place2': UP + 'Cinetools/ST025 Books & Magazines（书籍杂志）/Books & Magazines/BM_Bookshelf_Placement_2_ST.wav',
    'place3': UP + 'Cinetools/ST025 Books & Magazines（书籍杂志）/Books & Magazines/BM_Bookshelf_Placement_3_ST.wav',
    'place4': UP + 'Cinetools/ST025 Books & Magazines（书籍杂志）/Books & Magazines/BM_Bookshelf_Placement_4_ST.wav',
    'place6': UP + 'Cinetools/ST025 Books & Magazines（书籍杂志）/Books & Magazines/BM_Bookshelf_Placement_6_ST.wav',
    'slide1': UP + 'Cinetools/ST025 Books & Magazines（书籍杂志）/Books & Magazines/BM_Bookshelf_Slide_1_ST.wav',
    'slide2': UP + 'Cinetools/ST025 Books & Magazines（书籍杂志）/Books & Magazines/BM_Bookshelf_Slide_2_ST.wav',
    'die_wood1': UP + 'Articulated Sound/Dice 各种硬币 赌具 骰子/DICE on Hard Wood, Drop, Standard, 1 One Die, v1.wav',
    'die_wood2': UP + 'Articulated Sound/Dice 各种硬币 赌具 骰子/DICE on Hard Wood, Drop, Standard, 1 One Die, v2.wav',
    'die_tray1': UP + 'Articulated Sound/Dice 各种硬币 赌具 骰子/DICE on Wooden Tray, Drop, Standard, 1 One Die, v1.wav',
    'die_tray2': UP + 'Articulated Sound/Dice 各种硬币 赌具 骰子/DICE on Wooden Tray, Drop, Standard, 1 One Die, v2.wav',
    'wings_by': UP + 'aXLsound/Big Room Sound/Birds and Nature 大自然和鸟类音效/Bird,Wing Flaps,Glvs1,By 1.wav',
    'wings_away': UP + 'aXLsound/Big Room Sound/Birds and Nature 大自然和鸟类音效/Bird,WingFlaps,Glvs,Up,Awy1.wav',
    'blanket': UP + 'Cinetools/CT003 Climax（转场过场）/Raw Sources & Field Recordings/CL_Whoosh_Cotton_Blanket_CT.wav',
    'lid': UP + 'Articulated Sound/Essential Kitchen 必备厨房/Articulated--Essential_Kitchen--Sounds/KITCHEN pan lid opening closing.wav',
    'earthen': UP + 'Articulated Sound/Essential Kitchen 必备厨房/Articulated--Essential_Kitchen--Sounds/KITCHEN earthenware manipulating.wav',
    'gears_click': 'FreeSounds/GDCSonniss/2024/Sonniss.com-GDC2024-GameAudioBundle1of9/BluezoneCorp - Tiny Gears - Small Mechanism/Bluezone_BC0301_tiny_gears_small_mechanism_click_complex_011.wav',
    'gears_tick': 'FreeSounds/GDCSonniss/2024/Sonniss.com-GDC2024-GameAudioBundle1of9/BluezoneCorp - Tiny Gears - Small Mechanism/Bluezone_BC0301_tiny_gears_small_mechanism_click_003.wav',
    'plastic_gear': UP + 'Cinetools/ST022 Clinks and Clanks（金属碰撞的叮当声）/Clinks & Clanks/CC_ClinkClank_PlasticGear_ST.wav',
    'bubbles': 'FreeSounds/FilmCowSFX/FilmCow Recorded SFX/blowing bubbles 1.wav',
    'swish51': UP + 'Accusonus SFX Cellar/Whoosh/SFX Cellar - Whoosh 51.wav',
    'swish78': UP + 'Accusonus SFX Cellar/Whoosh/SFX Cellar - Whoosh 78.wav',
    'swish86': UP + 'Accusonus SFX Cellar/Whoosh/SFX Cellar - Whoosh 86.wav',
    'soft72': UP + 'Accusonus SFX Cellar/Whoosh/SFX Cellar - Whoosh 72.wav',
    'soft77': UP + 'Accusonus SFX Cellar/Whoosh/SFX Cellar - Whoosh 77.wav',
    'thumb': UP + 'aXLsound/Big Room Sound/User Interface Sounds 用户界面音效/Data,Beep,Notifier,Thumb Pluck.wav',
    'glassy': UP + 'aXLsound/Big Room Sound/User Interface Sounds 用户界面音效/Data,Beep,Glassy Pluck,High 2.wav',
    'soft54': UP + 'Accusonus SFX Cellar/Whoosh/SFX Cellar - Whoosh 54.wav',
}


def src(key, start=0.0, end=None):
    return load(SRC[key], start, end)


def out(rel):
    return os.path.join(ROOT, rel)


def sparkle(seconds=0.5, seed=0, hp_hz=5000):
    """A short glitter of tiny bells: a slice of shaken bells, high-passed and faded."""
    rng = np.random.default_rng(seed)
    start = 1.4 + rng.uniform(0, 5.0)
    s = src('bells', start, start + seconds)
    s = hp(s, hp_hz)
    return fade(s, 0.02, seconds * 0.8)


# ---- feedback (modules/feedback/sounds) -------------------------------------------------------

def good():
    """A right answer: two bright mallet notes rising a fourth, a pop under the first, a glitter on top."""
    variants = [('G5', 'C6'), ('E5', 'A5'), ('C5', 'G5')]
    for i, (a, b) in enumerate(variants):
        n1 = mix((celesta(a, 0.9, seed=i), 0, 0), (marimba(a, 0.5, seed=i), 0, -9))
        n2 = mix((celesta(b, 1.2, seed=i + 7), 0, 0), (marimba(b, 0.6, seed=i + 7), 0, -9))
        body = mix((n1, 0.0, -2.0), (n2, 0.085, 0.0),
                   (hp(src('pop14'), 600), 0.0, -14.0),
                   (sparkle(0.55, seed=i), 0.07, -17.0))
        body = eq(body, low=(250, -4), peaks=((3200, -2.0, 1.0),))
        y = verb(body, size=0.35, wet=0.16, damp=0.6, ring=0.4)
        y = length(trim(y, -60), 1.1, fout=0.4)
        export(level(y, -19.0), out(f'modules/feedback/sounds/good_{i + 1}.ogg'), channels=1)


def bad():
    """Not right, said kindly: a soft low wooden 'oh-oh', a falling minor third, no buzz or harshness."""
    variants = [('D4', 'B3'), ('E4', 'C4')]
    for i, (a, b) in enumerate(variants):
        n1 = marimba(a, 0.45, seed=i)
        n2 = marimba(b, 0.7, seed=i + 3)
        tok = cut(src('wood'), *WOOD_HITS[i % len(WOOD_HITS)])
        tok = lp(speed(tok, -7), 1800)
        body = mix((n1, 0.0, -1.0), (n2, 0.16, 0.0), (tok, 0.0, -16.0), (tok, 0.16, -19.0))
        body = lp(body, 2600)
        y = verb(body, size=0.25, wet=0.1, damp=0.7, ring=0.25)
        y = length(trim(y, -60), 0.95, fout=0.3)
        export(level(y, -23.0), out(f'modules/feedback/sounds/bad_{i + 1}.ogg'), channels=1)


def hint():
    """Look here: a soft glassy ping with a quick grace note and a faint glitter."""
    for i, (grace, note) in enumerate([('E6', 'A5'), ('G6', 'C6')]):
        g = glass(grace, 0.5, seed=i)
        n = mix((glass(note, 1.4, seed=i + 1), 0, 0), (celesta(note, 1.0, seed=i + 2), 0, -8))
        body = mix((g, 0.0, -10.0), (n, 0.045, 0.0), (sparkle(0.6, seed=10 + i), 0.05, -21.0))
        y = verb(body, size=0.45, wet=0.2, damp=0.5, ring=0.5)
        y = length(trim(y, -60), 1.3, fout=0.5)
        export(level(y, -22.0), out(f'modules/feedback/sounds/hint_{i + 1}.ogg'), channels=1)


def win():
    """A level won, timed to the trophy clip (modules/magic, 36 frames in 1.5 s): a pop as the cup appears
    (0.04 s), a quick C-major run and glitter as the confetti bursts (0.13-0.21 s), a warm chord and wind bells
    while it falls, fading with the clip at 1.25-1.5 s."""
    run = mix(*[(celesta(n, 1.2, seed=k), 0.035 * k, -2.0 + (1.5 if n == 'C6' else 0))
                for k, n in enumerate(['C5', 'E5', 'G5', 'C6', 'E6'])])
    chord = fade(src('guitar_c', 0.0, 2.0), 0.0, 1.0)
    glitter = hp(fade(src('windbells', 0.2, 1.8), 0.02, 0.9), 3500)
    low = lp(marimba('C3', 1.6, seed=4), 900)
    y = mix((hp(src('pop6'), 250), 0.0, -6.0), (plucks(['C5'], 0), 0.0, -4.0), (run, 0.06, -3.0),
            (sparkle(0.5, seed=21), 0.13, -12.0), (chord, 0.15, -6.0), (low, 0.15, -12.0), (glitter, 0.18, -15.0))
    y = eq(y, low=(180, -3))
    y = verb(y, size=0.5, wet=0.18, damp=0.45, ring=0.6)
    y = length(trim(y, -60), 2.0, fout=0.75)
    export(level(y, -16.0), out('modules/feedback/sounds/win.ogg'), channels=2)


# Single wood-block hits inside wood_mix.wav (start, end seconds).
WOOD_HITS = [(0.368, 0.56), (0.806, 1.0), (1.243, 1.43), (1.734, 1.93), (2.171, 2.36), (2.64, 2.83), (2.971, 3.16)]


CUES = 'modules/sound/cues/'


def cue(y, name, target, stereo=False):
    """Writes one cue file: mono for sounds placed in the room, stereo for sounds that are not."""
    return export(level(y, target), out(CUES + name + '.ogg'), channels=2 if stereo else 1)


def chatter(sources, count, gap, spread=0.35, decay=0.85, seed=0, semis=(0, 0)):
    """A rattle made of separate small hits in a quick, uneven run (a lid chattering on a pot).
    [sources]: list of (signal, start) hits to draw from; each grain is 0.12 s."""
    rng = np.random.default_rng(seed)
    layers = []
    t = 0.0
    g = 0.0
    for _ in range(count):
        y, s = sources[rng.integers(len(sources))]
        grain = fade(cut(y, s, s + 0.12), 0.0, 0.08)
        grain = speed(grain, rng.uniform(*semis))
        layers.append((grain, t, g + rng.uniform(-3, 0)))
        t += gap * rng.uniform(1 - spread, 1 + spread)
        g += 20 * np.log10(decay)
    return mix(*layers)


# ---- interface (2D unless said) ------------------------------------------------------------------

def ui():
    """Ray lands on a button: a tiny droplet. Pinch on a button: a soft rounded pop with a wooden tick."""
    hover = hp(speed(src('pop9'), 5), 900)
    cue(length(hover, 0.09, 0.05), 'ui_hover', -33.0)
    for i, (p, w) in enumerate([('pop1', 2), ('pop14', 4)]):
        tick = lp(speed(cut(src('wood'), *WOOD_HITS[w]), 7), 4000)
        y = mix((hp(src(p), 250), 0, 0), (tick, 0.0, -11.0))
        cue(length(trim(y, -50), 0.22, 0.08), f'ui_press_{i + 1}', -24.0)


def thumb(note):
    """The warm thumb-piano pluck the interface is built on."""
    return pitched(src('thumb'), 576.2, note)


def glassy(note):
    """A clean high glass pluck, layered quietly an octave above [thumb] for a crisp edge."""
    return pitched(src('glassy'), 1949.4, note)


def pitched(y, f0, note):
    """[y] trimmed and varispeeded so its pitch [f0] (Hz) lands on [note]."""
    return speed(trim(y, -50), 12 * np.log2(note_hz(note) / f0))


def plucks(notes, gap):
    """[notes] in a quick run, each a thumb pluck with its glass octave."""
    return mix(*[(mix((thumb(n), 0, 0), (glassy(n[:-1] + str(int(n[-1]) + 1)), 0, -12)), k * gap, -k * 0.7)
                 for k, n in enumerate(notes)])


def menu():
    """The panel shows and hides on the same frame, so both hit at once: a fifth rising to open, falling to close."""
    cue(length(verb(plucks(['C5', 'G5'], 0.055), 0.25, 0.1, ring=0.3), 0.32, 0.18), 'menu_open', -26.0, stereo=True)
    cue(length(verb(plucks(['G5', 'C5'], 0.055), 0.25, 0.1, ring=0.3), 0.3, 0.17), 'menu_close', -28.0, stereo=True)


def transition():
    """A scene changes behind a 0.18 s fade: a short soft puff of air that peaks in the dark, a low pluck under it."""
    air = fade(hp(src('air3', 1.6, 2.0), 300), 0.06, 0.3)
    y = mix((air, 0, -4), (lp(thumb('C4'), 2500), 0.0, -6), (glassy('G5'), 0.0, -20))
    cue(length(y, 0.5, 0.3), 'transition', -30.0, stereo=True)


def room():
    """Into My room: a quick rising C-major run with a light harp and wind bells. Out: the run falling."""
    harp = fade(speed(src('harp_e', 0.0, 1.4), -4), 0.01, 0.8)
    bells = hp(fade(src('windbells', 0.2, 1.4), 0.02, 0.9), 3500)
    y = mix((plucks(['C5', 'E5', 'G5', 'C6'], 0.045), 0, 0), (harp, 0.03, -12), (bells, 0.12, -18))
    cue(length(verb(y, 0.45, 0.16, ring=0.5), 1.3, 0.8), 'room_enter', -24.0, stereo=True)
    y = plucks(['G5', 'E5', 'C5'], 0.045)
    cue(length(verb(y, 0.35, 0.14, ring=0.4), 0.6, 0.35), 'room_exit', -27.0, stereo=True)


# ---- handling things (placed where it happens) ----------------------------------------------------

def handling():
    """Pick up, set down, slide back home, and small toys dropping onto the bench."""
    for i, (k, s) in enumerate([('pickup3', 0.10), ('pickup3', 0.75), ('pickup4', 0.73)]):
        y = hp(cut(src(k), s, s + 0.3), 180)
        y = mix((y, 0, 0), (hp(speed(src('blanket', 0.1, 0.35), 6), 1500), 0.0, -18))
        cue(fade(y, 0.004, 0.15), f'grab_{i + 1}', -27.0)
    for i, (k, s) in enumerate([('place3', 0.043), ('place6', 0.107), ('place2', 0.949), ('place4', 0.672)]):
        y = cut(src(k), s - 0.005, s + 0.32)
        y = eq(hp(y, 90), low=(200, 2), peaks=((2500, -3, 1.0),))
        cue(fade(y, 0.002, 0.15), f'place_{i + 1}', -21.0)
    for i, (k, s, e) in enumerate([('slide1', 0.12, 0.62), ('slide2', 0.02, 0.5)]):
        y = speed(hp(cut(src(k), s, e), 200), 2)
        cue(fade(y, 0.06, 0.2), f'slide_{i + 1}', -28.0)
    for i, k in enumerate(['die_wood1', 'die_wood2', 'die_tray1', 'die_tray2']):
        y = speed(trim(src(k), -45), -4)          # a 6 cm toy, a little heavier than a die
        y = eq(y, low=(300, 2), high=(6000, -4))
        cue(fade(y, 0.0, 0.1), f'drop_{i + 1}', -27.0)


def butterflies():
    """Net swing swish, a catch (a soft cloth flump with two quick wing beats), and released butterflies."""
    for i, k in enumerate(['swish51', 'swish78', 'swish86']):
        y = hp(src(k), 350)
        y = mix((y, 0, 0), (hp(speed(src('blanket'), 3), 600), 0.0, -12))
        cue(fade(trim(y, -45), 0.01, 0.15), f'swish_{i + 1}', -27.0)
    flaps = src('wings_by')
    for i, s in enumerate([2.80, 3.30]):
        beats = speed(hp(cut(flaps, s, s + 0.35), 400), 9)    # small wings, fast
        y = mix((hp(speed(src('blanket'), 4), 200), 0, 0), (beats, 0.04, -6), (hp(src('pop6'), 400), 0.02, -14))
        cue(fade(y, 0.003, 0.12), f'catch_{i + 1}', -25.0)
    away = speed(hp(src('wings_away', 4.6, 6.9), 500), 10)
    cue(fade(away, 0.15, 0.6), 'flutter_away', -31.0)


def sweep():
    """A sweeping hand in the motion game: a soft low breath of air."""
    for i, k in enumerate(['soft72', 'soft77', 'soft54']):
        y = lp(hp(src(k), 150), 6000)
        cue(fade(trim(y, -45), 0.05, 0.3), f'sweep_{i + 1}', -30.0)


# ---- rewards and magic ---------------------------------------------------------------------------

def rewards():
    """A magic stone taken: a crystal tick and a gem clink with a high note. Buying: a little cascade of them."""
    tick = trim(src('crystal'), -50)
    gem = trim(src('gem_g'), -50)
    y = mix((tick, 0, 0), (fade(gem, 0, 0.3), 0.03, -6), (celesta('E6', 0.9), 0.0, -10), (sparkle(0.4, 3), 0.05, -16))
    cue(length(verb(y, 0.3, 0.14, ring=0.3), 1.0, 0.35), 'stone', -21.0)
    gems = mix((fade(trim(src('gem_y'), -50), 0, 0.3), 0, 0), (fade(gem, 0, 0.3), 0.11, -2), (tick, 0.2, -3))
    notes = mix((celesta('G5', 1.0), 0, 0), (celesta('C6', 1.0, 1), 0.1, 0), (celesta('E6', 1.2, 2), 0.2, 0))
    y = mix((gems, 0, 0), (notes, 0.02, -9), (sparkle(0.6, 4), 0.15, -15))
    cue(length(verb(y, 0.35, 0.16, ring=0.4), 1.4, 0.5), 'purchase', -20.0)


def magic():
    """Something appears; something is put away; a pet hops; Onion's little mark pops up."""
    y = mix((hp(src('pop6'), 300), 0, -2), (glass('G5', 1.0), 0.01, -8), (glass('C6', 1.0, 1), 0.05, -12),
            (sparkle(0.5, 5), 0.03, -14))
    cue(length(verb(y, 0.35, 0.15, ring=0.4), 1.0, 0.4), 'appear', -25.0)
    shimmer = sparkle(0.5, 6)[::-1]
    air = fade(hp(src('air4', 1.7, 2.3), 300), 0.02, 0.3)
    tok = lp(cut(src('place6'), 0.1, 0.4), 1500)
    y = mix((shimmer, 0, -10), (air, 0.3, -4), (tok, 0.5, -6))
    cue(fade(y, 0.05, 0.2), 'stash', -26.0)
    y = mix((hp(speed(src('blanket'), 7), 500), 0, 0), (speed(src('pop9'), -3), 0.1, -6))
    cue(fade(trim(y, -45), 0.005, 0.1), 'hop', -31.0)
    y = mix((speed(src('pop14'), 4), 0, 0), (glass('E6', 0.5), 0.0, -10))
    cue(length(y, 0.35, 0.15), 'mark', -29.0)
    rise = fade(glass('C6', 0.6), 0.0, 0.0)[::-1]                # a note breathed in backwards
    y = mix((fade(rise, 0.2, 0.01), 0, -6), (sparkle(0.45, 9)[::-1], 0.1, -14), (speed(src('pop6'), -5), 0.58, 0))
    cue(fade(y, 0.05, 0.25), 'vanish', -25.0)


# ---- the opening (entry/assets/audio) ------------------------------------------------------------

def opening():
    """The cauldron, Onion and the gear: rattles built hit by hit, a muffled knock, a bubbly pop, the seat."""
    lid, earthen = src('lid'), src('earthen')
    lid_hits = [(lid, s) for s in (12.117, 32.363, 38.56, 45.387, 47.157, 52.373)]
    pot_hits = [(earthen, s) for s in (3.851, 5.739, 11.627, 12.736, 13.621, 14.603, 15.755)]
    pre = chatter(lid_hits + pot_hits, 18, 0.07, seed=1, decay=0.97, semis=(-1, 2))
    pre = fade(lp(pre, 5000), 0.5, 0.35)                      # trembles in, not a crash
    export(level(pre, -27.0), out('entry/assets/audio/pre_rattle.ogg'), channels=1)
    soft = chatter(lid_hits, 7, 0.08, seed=2, decay=0.9, semis=(0, 2))
    export(level(fade(lp(soft, 4000), 0.1, 0.25), -31.0), out('entry/assets/audio/rattle_soft.ogg'), channels=1)
    gear = chatter([(src('plastic_gear'), s) for s in (0.021, 0.128, 0.203, 0.597, 0.789, 0.896)], 10, 0.075,
                   seed=3, decay=0.95, semis=(-3, -1))
    heavy = chatter(pot_hits, 14, 0.065, seed=4, decay=0.96, semis=(-4, -2))
    y = mix((heavy, 0, 0), (gear, 0.1, -9), (lp(speed(src('place3', 0.04, 0.4), -8), 900), 0.0, -8))
    export(level(fade(lp(y, 6000), 0.15, 0.4), -24.0), out('entry/assets/audio/device_rattle.ogg'), channels=1)
    thump = trim(lp(speed(cut(src('place6'), 0.1, 0.37), -6), 1100), -12)
    clink = hp(cut(lid, 32.363, 32.6), 800)
    y = mix((thump, 0, 0), (fade(clink, 0, 0.15), 0.035, -14), (lp(marimba('G2', 0.5), 500), 0, -14))
    export(level(fade(y, 0.002, 0.2), -22.0), out('entry/assets/audio/knock.ogg'), channels=1)
    bub = hp(cut(src('bubbles'), 0.0, 0.45), 300)
    y = mix((hp(src('pop6'), 200), 0, 0), (bub, 0.0, -10), (glass('C6', 0.9), 0.02, -12), (sparkle(0.5, 7), 0.04, -16))
    export(level(length(verb(y, 0.3, 0.14, ring=0.3), 0.9, 0.35), -20.0), out('entry/assets/audio/pop.ogg'),
           channels=1)
    y = mix((src('gears_click'), 0, 0), (lp(fade(cut(src('place6'), 0.1, 0.37), 0, 0.1), 2500), 0.05, -6),
            (celesta('G5', 1.0), 0.07, -12), (celesta('C6', 1.2, 1), 0.15, -11), (sparkle(0.5, 8), 0.15, -18))
    export(level(length(verb(y, 0.3, 0.12, ring=0.4), 1.2, 0.45), -20.0), out('entry/assets/audio/seat.ogg'),
           channels=1)
    y = mix((src('gears_tick'), 0, 0), (cut(src('place3'), 0.04, 0.4), 0.0, -3))
    export(level(fade(eq(y, low=(200, 2)), 0.002, 0.15), -23.0), out('entry/assets/audio/gear_land.ogg'), channels=1)
    swell = fade(hp(src('air2', 0.4, 1.9), 200), 1.0, 0.1)
    harp = fade(speed(src('harp_e', 0.0, 3.2), -4), 0.05, 1.4)
    chord = fade(src('guitar_c', 0.0, 3.0), 0.02, 1.8)
    bells = hp(fade(src('windbells', 0.2, 3.0), 0.1, 1.6), 3000)
    y = mix((swell, 0, -4), (harp, 1.2, -6), (chord, 1.5, -12), (bells, 1.5, -15),
            (lp(marimba('C3', 2.4), 700), 1.5, -14))
    y = verb(y, 0.6, 0.22, ring=0.8)
    export(level(length(y, 4.2, 1.6), -20.0), out('entry/assets/audio/reveal.ogg'), channels=1)


RECIPES = {f.__name__: f for f in [good, bad, hint, win, ui, menu, transition, room, handling, butterflies, sweep,
                                    rewards, magic, opening]}

if __name__ == '__main__':
    names = sys.argv[1:] or list(RECIPES)
    for name in names:
        RECIPES[name]()
        print('built', name)
