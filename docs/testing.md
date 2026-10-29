# Testing

`python tools/test.py` runs everything headless, in parallel, in about 15 s; non-zero exit on any failure.

- **GDScript unit tests** `tests/*_test.gd` (`TestCase`): one piece at a time on the real app.
- **Scenarios** `tests/sim/test_*.py` (`unittest`): whole sessions on the real `main.tscn`, played by a simulated child.

`python tools/sim/walkthrough.py` renders a walkthrough to `build/walkthrough/` (PNGs + `review.html`) and runs `tests/rendered/` against `tools/cv_server.py --fake`. Open the pictures: a finished script is not a visual pass.

## The simulated child

- `tools/sim/server.gd` boots `main.tscn` on `SimReality` and answers JSON lines on 127.0.0.1. Lockstep: game time moves only while a command runs, 1/60 s per frame (`--fixed-fps 60`). It acts only through `SimInput` (head and hand poses moved over time, buttons, tracking) and only reads engine facts (`observe.gd`). Options: plan or plan spec, `--unplug=Detector,Voice`, `--seat`, `--eye`, `--keep-profile`, `--cv-server`.
- `client.py` launches it (`Sim`); `body.py` + `profiles.json`: seated bodies that refuse the impossible with a coded `ConstraintError` (reach, torso, head_yaw/pitch/lean, out_of_view, behind_head, hand_speed, path_blocked); `actor.py`: the child's and the facilitator's hands; `policy.py`: a seeded **test driver** that turns facts (angular size, clutter, coherence, view, hints) into right and wrong answers, help and timeouts. It is not a model of vision. `child.py` plays rounds by policy or by script; `research_log.py` checks logs.
- Profiles start with `test` and are wiped. Layouts are random: read facts, never predict them.

## Quest code on the PC (Meta XR Simulator)

`python tools/xrsim.py test` runs the real Quest path (`PassthroughReality`, the Meta room scan, hands) on Meta XR Simulator in injected rooms, about 10 s per room, no headset. `python tools/xrsim.py run <room.json>` prints what the app read. Needs the simulator in `C:\Program Files\MetaXRSimulator\v207.1` (or `XRSIM`); the system's OpenXR runtime is left alone.

- Rooms are the simulator's scene-anchor JSON, built in tests with `xrsim.room(plane(...), volume(...))`. They need a FLOOR and a CEILING, floats only. Record a real room with the simulator's `scene_data_recorder/SceneDataRecorder.apk`.
- The app prints `ARVision {json}` lines (`room_missing`, `room_surface`, `room_ready`, `depth`, `depth_table`, `room_depth_table`, `room_table_lost`, `room_hands_in_air`), also in adb logcat on a Quest.
- Not simulated: the live depth and the passthrough camera. Debug builds on a Quest keep the first 60 s of depth looks in `user://depth/<run>/` (pull with `adb exec-out run-as edu.mit.arvision tar -C files -cf - depth`); `DepthGrid.table` can be replayed on them. `tests/table_finder_test.gd` replays a real session (headset off and on again, then play) from `tests/data/headset_off_on.depth.gz`.

## Quest camera frames

Debug builds on a Quest keep the frames the Detector sends (`user://frames/<run>/`, 240 per run). `python tools/frames.py pull` copies them to `build/frames/`; `python tools/frames.py check build/frames/<run>` flags black frames, colour casts, size or field-of-view mismatches, runs YOLO (`pip install ultralytics onnxruntime`; `--fake` without), compares it with what the headset's own YOLO saw (`<frame>.seen.json`, with timing) and writes `review.html`. On-device check: install a debug build, `adb shell am broadcast -a com.oculus.vrpowermanager.prox_close` so it runs unworn, launch, wait 2 min, `pull`, `check`.
