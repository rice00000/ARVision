# Sound

`Events.play(&"cue", at)` plays a cue from where it happens; without `at` it plays flat. Cues: `cues/` (mono when placed, stereo when flat). Feedback's chimes: `modules/feedback/sounds/`. The opening's sounds: `entry/assets/audio/`. Piano: `modules/music/`.

## Mix

Buses (`default_bus_layout.tres`): **Voice** (−2 dB, light compressor), then **SFX** (dips ~3 dB under speech), then **Music** (−13 dB, dips ~7 dB under speech), then a limiter on **Master** at −1 dB. Voice mixes first so the others can key off it. Levels inside the files (loudest 100 ms): voice ≈ −13 dBFS, win −16, good/place −19 to −21, bad/hint −22, foley −27, UI hover −33.

