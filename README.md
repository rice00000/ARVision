# ARVision

AR vision training for children who gained sight late (Project Prakash, ages 8–18). Measured trials run over the Quest 3's passthrough: virtual stimuli on the real table, real objects found by computer vision, and the real world itself filtered (contrast, greyscale, edges, dimming). Sister project of XRVision (VR), same stack.

Godot **4.7.2**, GDScript, Mobile renderer, OpenXR, Godot OpenXR Vendors **5.1.0**, Meta Quest 3.

## Run it

- **Quest 3:** put the Vendors plugin in `addons/godotopenxrvendors/` and install the Android build template, then run the **Meta Quest 3** export preset. The first run asks to scan the room; tables become work surfaces.
- **PC, no headset:** run the project. A simulated living room stands in for the real one. Mouse: right-drag looks, left click points and pinches, left-drag sweeps (wheel: nearer / farther). **H** raises a hand (help), **M** facilitator panel.
- **Meta XR Simulator:** runs as XR; without passthrough it uses the simulated room.
- Options after `--`: `--profile=<child>`, `--plan=res://content/sessions/<plan>.tres`, `--sim` (simulated room even with passthrough).

**Quest controls (hands, no controllers):** point and pinch to choose (a fingertip touch also works; a resting hand touches nothing). Raise a hand above your eyes to ask for help. The left-hand menu pinch (left palm facing you, pinch) opens the facilitator panel, which pauses play.

## Test

```bash
python tools/test.py
```

Runs every suite headlessly on `test` profiles: GDScript unit tests and whole sessions played by a simulated child ([testing](docs/testing.md)). One GDScript suite: `godot --headless --xr-mode off --fixed-fps 60 --path . res://tests/run.tscn -- --profile=test --only=smoke`. Rendered walkthrough with screenshots: `python tools/sim/walkthrough.py` → `build/walkthrough/review.html`. Screenshots of every view: `godot --xr-mode off --path . res://tools/capture.tscn -- --profile=test_capture` → `build/captures/`.

## Where things are

```text
core/      Events (signal bus), App, Profile, Log, Module
rig/       head and hands, Pointer, Target, SimInput, DesktopDriver
reality/   Reality API: PassthroughReality (Quest), SimReality + rooms/ (no headset), View, Surface
modules/   voice, feedback, cv (Detector), facilitator: each one unpluggable
trials/    Trial, TrialDef, Session; one folder per trial
content/   views/ and sessions/ presets
tests/     unit tests, sim/ scenarios      tools/  test runner, sim/ simulated child, CV server
```

See [architecture](docs/architecture.md), [anticipated experiments](docs/experiments.md) and [adding a trial](docs/adding-a-trial.md).

## How to add things

- **Trial:** `trials/<kind>/` with a scene whose root extends `Trial` and a `TrialDef` `.tres`; add a `Block` to a session plan.
- **View preset:** a `View` `.tres` in `content/views/`.
- **Session:** a `SessionPlan` `.tres` in `content/sessions/`.
- **Module:** a node under `Main/Modules` extending `Module`, talking through `Events`. Delete the node to unplug it.
- **Simulated room:** a scene in `reality/rooms/` with `SimSurface` markers and `RealObject`s.
- **Quest code without a headset:** `python tools/xrsim.py test` (Meta XR Simulator rooms); camera frames: `python tools/frames.py pull` / `check` (see docs/testing.md).
- **CV on a Quest:** `pip install ultralytics`, `python tools/cv_server.py`, `adb reverse tcp:8765 tcp:8765`.
