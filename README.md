# ARVision

AR vision training for children who gained sight late (Project Prakash, ages 8–18). Measured trials run over the Quest 3's passthrough: virtual stimuli on the real table, real objects found by computer vision, and the real world itself filtered (contrast, greyscale, edges, dimming). Sister project of XRVision (VR), same stack.

Godot **4.7.2**, GDScript, Mobile renderer, OpenXR, Godot OpenXR Vendors **5.1.0**, Meta Quest 3.

## Run it

- **Quest 3:** put the Vendors plugin in `addons/godotopenxrvendors/` and install the Android build template, then run the **Meta Quest 3** export preset. Tables in the headset's room scan become work surfaces. A build not registered with Meta cannot read the scan (`ERROR_PACKAGE_UNTRUSTED`); tables and walls then come from the live depth. The app never opens Space Setup itself.
- **PC, no headset:** run the project. A simulated living room stands in for the real one. Mouse: right-drag looks, left click points and pinches, left-drag sweeps (wheel: nearer / farther). **H** raises a hand (help), **M** facilitator panel.
- **Meta XR Simulator:** runs as XR; without passthrough it uses the simulated room.
- Options after `--`: `--profile=<id>` (this save for this run only; tests), `--plan=res://content/sessions/<plan>.tres`, `--sim` (simulated room even with passthrough).

**The adventure** (default, `content/adventure.tres`; [world](docs/world.md)): you are a young alchemist tidying your workshop. The room stays in normal colour. A yellow orb points the way; turn to face a place and its menu unfolds: the alchemy table (tidy the shelf: put each thing back on its sticker, five levels; [tidy up](docs/tidy.md)) and behind you (break the spell wall, two). Touch a level (or point and pinch) to play; the glowing one is next, and a hand coming close hears which level it is. The next level, and the wall, unlock as you go. Progress is saved per save; the facilitator panel's **Saves** tab makes, names, copies and switches saves (one per child, as in XRVision). A fixed session instead: `--plan=res://content/sessions/tech_demo.tres` (find toys under four views, then break the wall) or `demo.tres` (training).

**Quest controls (hands, no controllers):** touch to choose (point and pinch also works, with no visible beam; a resting hand touches nothing). In tidy up, reach and pinch a thing, carry it to its sticker, then release. Sweep a hand to answer the dots; no pinch. Raise a hand above your eyes to ask for help. At the end, touch the yellow ball to play again. The left-hand menu pinch (left palm facing you, pinch) opens the facilitator panel, which pauses play.

## Test

```bash
python tools/test.py
```

Runs every suite headlessly on `test` profiles: GDScript unit tests and whole sessions played by a simulated child ([testing](docs/testing.md)). One GDScript suite: `godot --headless --xr-mode off --fixed-fps 60 --path . res://tests/run.tscn -- --profile=test --only=smoke`. Rendered walkthrough with screenshots: `python tools/sim/walkthrough.py` → `build/walkthrough/review.html`. Screenshots of every view: `godot --xr-mode off --path . res://tools/capture.tscn -- --profile=test_capture` → `build/captures/`.

## Where things are

```text
core/      Events (signal bus), App, Profile, Save, Log, Module
rig/       head and hands, Pointer, Target, SimInput, DesktopDriver
reality/   Reality API: PassthroughReality (Quest), SimReality + rooms/ (no headset), View, Surface
modules/   voice, feedback, cv (Detector), facilitator, magic (effects), picks (CSV): each one unpluggable
trials/    Trial, TrialDef, Session; one folder per trial
world/     World, Guide, TaskMenu; Adventure, Place, Task
content/   adventure.tres, places/, tasks/, views/, sessions/
tests/     unit tests, sim/ scenarios      tools/  test runner, sim/ simulated child, CV server
```

See [architecture](docs/architecture.md), [anticipated experiments](docs/experiments.md) and [adding a trial](docs/adding-a-trial.md).

## How to add things

- **Trial:** `trials/<kind>/` with a scene whose root extends `Trial` and a `TrialDef` `.tres`; add a `Block` to a session plan.
- **View preset:** a `View` `.tres` in `content/views/`.
- **Session:** a `SessionPlan` `.tres` in `content/sessions/`.
- **Task:** a `Task` `.tres` in `content/tasks/` (one plan per level, what it needs, rewards); add it to a `Place` in `content/places/`.
- **Saved state:** `save_state()` / `load_state()` on a node ([Save](core/save.gd), as in XRVision).
- **Guide speech:** write the line in `say(...)`; the editor bakes the audio. See [baked speech](docs/baked-speech.md).
- **Module:** a node under `Main/Modules` extending `Module`, talking through `Events`. Delete the node to unplug it.
- **Simulated room:** a scene in `reality/rooms/` with `SimSurface` markers and `RealObject`s.
- **Quest code without a headset:** `python tools/xrsim.py test` (Meta XR Simulator rooms); camera frames: `python tools/frames.py pull` / `check` (see docs/testing.md).
- **Pick data:** every pick is a row in `<save>/picks.csv` (time, save, game, round, target, picked, correct, seconds, accuracy; see [Picks](modules/picks/picks.gd)). One file for all saves: `python tools/picks.py pull` (Quest) or `local` → `build/picks.csv`.
- **CV on a Quest:** YOLO11n runs on the headset (`addons/yolo`, ONNX Runtime; about 0.3 s a look), no PC needed. The committed `addons/yolo/yolo.aar` is built from `addons/yolo/android/`; after changing the Kotlin, rebuild it with `./gradlew assembleRelease` there (JDK 17, `ANDROID_HOME`). Another model: export it with `yolo export model=<pt> format=onnx imgsz=640` to `modules/cv/yolo11n.onnx`.
