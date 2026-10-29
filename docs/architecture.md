# Architecture

## One idea

Trials never touch the headset. They ask **`App.reality`** for the real world:

| Reality gives | `PassthroughReality` (Quest) | `SimReality` (no headset, tests) |
|---|---|---|
| Surfaces (`work_surface()`, `surfaces(kind)`) | Meta room scan, else live depth (`DepthSensor`) or both hands flat on the table | `SimSurface` markers in `reality/rooms/` |
| The real thing along a ray (`hit()`) | room-scan colliders, else live depth | room colliders |
| How it looks (`apply_view(View)`, `focus_on()`) | Meta passthrough filter + dim sphere | the same grading as a screen overlay |
| Camera frames (`camera_frame()`) | `QuestCamera` (Passthrough Camera API) | the rendered view |

Input works the same way: on a Quest the headset moves the `Rig`; without one, `SimInput` sets synthetic trackers, so trials get identical hand events. The desktop driver and the tests both use `SimInput`.

## Layers

`core` ← `rig`, `reality` ← `modules`, `trials` ← `world` ← `content`. Modules and trials never call each other; they talk through `Events`. `App.module(name)` returns an optional module or null.

## A session

```text
Session ─ waits for App.reality.settled (the table is known, or the search gave up) ─ Block ─▶ apply View ─▶ instance trial scene ─▶ per round:
   TrialDef.condition(level) ─▶ Trial.begin ─▶ child input (Events) ─▶ Trial.finish
   ─▶ Events.trial_ended ─▶ Log line, Profile.adapt (2-up / 1-down)
```

- **Level:** one 0–1 number per skill (`Profile`). `TrialAxis` maps it to real values; keep one driven axis per trial. `Block.pins` fixes other axes per block.
- **Staircase:** a round counts as right only when solved on the first try without help (`first_try` in the log); retries and help still end in success for the child.
- **Probe blocks** are unaided and do not move the level: no-help check-ins.
- **Help** escalates by itself (`hint_after`, later each round) or when the child raises a hand; every hint is logged.
- **Log:** `user://profiles/<id>/logs/*.jsonl`, every round with its full condition and view.
- **Save:** `user://profiles/<id>/save.json` (staircase levels, the adventure's progress), written through a temporary file. `user://profiles.cfg` lists the saves and the one in use (`Profile`, as in XRVision). Opening another save writes everything, then `Main.restart` frees the Session, World and stage and builds them fresh on the new files; room, rig and modules stay.

Without a plan the [World](world.md) chooses: it plays one `Task` level (a plan) at a time with `Session.play(plan)`.

## Modules

Children of `Main/Modules`; delete a node to unplug it. A trial that needs one lists it in `TrialDef.requires` and the session skips its blocks.

- **Voice:** subtitles + [baked speech](baked-speech.md) (audio files made ahead of time).
- **Feedback:** sound, shape mark and vibration for good / bad / hint.
- **Detector:** CV. Sim backend reads `RealObject`s with line of sight; headset backend runs YOLO on the Quest (`addons/yolo` Android plugin, `modules/cv/yolo11n.onnx`); remote backend posts frames to `tools/cv_server.py` (same model on a PC). Labels are COCO names in all.
- **Magic:** the story's effects: gold sparkles on a right pick; a new treasure shows below the eyes, turns and glides into its cabinet slot. Nothing flashes.
- **Picks:** one CSV row per pick (`Trial.pick()` → `Events.picked`), in `<save>/picks.csv`.
- **Facilitator:** in-headset panel, pauses play. Training tab: level, view, skip. Saves tab: list (a page of 4), + New save with an on-panel keyboard, Start fresh, Copy this save.

## Not verified on a headset yet

On a Quest 3 so far: the passthrough camera gives frames (left camera, feed `50`) and the live depth gives points at full frame rate. Not yet checked with the headset worn: that depth points and camera frames line up (the camera pose is the head pose, FOV approximate), passthrough filters.
