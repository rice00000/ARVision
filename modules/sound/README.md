# Sound

`Events.play(&"cue", at)` plays a cue from where it happens; without `at` it plays flat. Cues: `cues/` (mono when placed, stereo when flat). Feedback's chimes: `modules/feedback/sounds/`. The opening's sounds: `entry/assets/audio/`. Piano: `modules/music/`.

## Mix

Buses (`default_bus_layout.tres`): **Voice** (−2 dB, light compressor), then **SFX** (dips ~3 dB under speech), then **Music** (−13 dB, dips ~7 dB under speech), then a limiter on **Master** at −1 dB. Voice mixes first so the others can key off it. Levels inside the files (loudest 100 ms): voice ≈ −13 dBFS, win −16, good/place −19 to −21, bad/hint −22, foley −27, UI hover −33.

## Making them

`python tools/sound/design.py [name]` rebuilds them from the team's SFX library (`E:\SFXs`) plus tuned mallet and glass tones. Everything tonal is in C major, the key of the piano. Sources, by pack: Cinetools (Books & Magazines, Clinks & Clanks, Overtonics, Treasure Chest, Climax, Fantasy Game), CB Sounddesign Dreamcatcher (harp, guitar chord, bells), Deb Sound Pops-UI, Accusonus SFX Cellar whooshes, Articulated Sound (dice, kitchen), aXLsound (wing flaps), Carma Studio (crystal tick, door knock), Cinetools Treasure Chest (lock), aXLsound bubble burst, Blue box (wood block), Sonniss GDC 2024 Bluezone Tiny Gears, FilmCow (bubbles). Exact files: `SRC` in `design.py`.

Not put on targets on purpose: butterflies, toys and dots have no sound of their own, so children find them by looking, not by ear.
