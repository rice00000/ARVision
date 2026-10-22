# Architecture

## One idea

Trials never touch the headset. They ask **`App.reality`** for the real world:

| Reality gives | `PassthroughReality` (Quest) | `SimReality` (no headset, tests) |
|---|---|---|
| Surfaces (`work_surface()`, `surfaces(kind)`) | Meta room scan | `SimSurface` markers in `reality/rooms/` |
| How it looks (`apply_view(View)`, `focus_on()`) | Meta passthrough filter + dim sphere | the same grading as a screen overlay |
| Camera frames (`camera_frame()`) | `QuestCamera` (Passthrough Camera API) | the rendered view |

Input works the same way: on a Quest the headset moves the `Rig`; without one, `SimInput` sets synthetic trackers, so trials get identical controller events. The desktop driver and the tests both use `SimInput`.

## Layers

`core` ← `rig`, `reality` ← `modules`, `trials` ← `content`. Modules and trials never call each other; they talk through `Events`. `App.module(name)` returns an optional module or null.

## A session

```text
Session ─ Block ─▶ apply View ─▶ instance trial scene ─▶ per round:
   TrialDef.condition(level) ─▶ Trial.begin ─▶ child input (Events) ─▶ Trial.finish
   ─▶ Events.trial_ended ─▶ Log line, Profile.adapt (2-up / 1-down)
```

- **Level:** one 0–1 number per skill (`Profile`). `TrialAxis` maps it to real values; keep one driven axis per trial.
- **Probe blocks** are unaided and do not move the level: no-help check-ins.
- **Help** escalates by itself (`hint_after`, later each round) or on B / Y; every hint is logged.
- **Log:** `user://profiles/<id>/logs/*.jsonl`, every round with its full condition and view.

## Modules

Children of `Main/Modules`; delete a node to unplug it. A trial that needs one lists it in `TrialDef.requires` and the session skips its blocks.

- **Voice:** subtitles + system text-to-speech.
- **Feedback:** sound, shape mark and vibration for good / bad / hint.
- **Detector:** CV. Sim backend reads `RealObject`s with line of sight; remote backend posts frames to `tools/cv_server.py` (YOLO). Labels are COCO names in both.
- **Facilitator:** in-headset panel: level, view, skip; pauses play.

## Not verified on a headset yet

Passthrough filters, room-scan surfaces and the passthrough camera follow the Vendors plugin docs but have only run in the simulated room.
