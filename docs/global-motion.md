# Global motion (RDK in 3D)

`trials/motion/`. Original design, shader and gesture logic by Megan ([Mgharv](https://github.com/Mgharv)), ported from XRVision.

**What it measures:** motion coherence in depth. A cloud of dots floats 2.2 m ahead; a fraction (coherence) moves right, left, toward or away, the rest is noise. The child sweeps a hand the way the flow goes and holds still; no pinch. A sweep too small, or mostly up or down (a hand raised for help), is *invalid* (no try). A wrong valid sweep counts a try and the stimulus stays; a right one ends the round and the dots align into streaks.

- **Defs:** `motion.tres` (random-direction noise, skill `global_motion`) and `motion_competing.tres` (noise is one opposite flow, skill `global_motion_competing`, coherence never below 0.55). Plan: `-- --plan=res://content/sessions/motion.tres`.
- **Axes:** coherence (driven, 0.9 to 0.15), then fixed: `direction` (0 random, 1-4 right, left, toward, away, 5 random lateral; the tech demo uses 5), `dots`, `speed`, `dot_lifetime`, cloud `half_*`, `distance`, `tolerance`, `min_sweep`.
- **Logged per round:** `heading`, `plane` (lateral / depth), `flow`, `signal_dots`, `seed`, `tries`, `hint`, `first_attempt_correct`, `attempts` (angle, distance, duration, onset, hand, help, coherence shown), `invalid_gestures`. Invalid sweeps and attempts also go out as `motion_invalid` / `motion_attempt` events. Onset means when the hand set off.
- **Help:** only when the child raises a hand, one level: every dot follows the flow. Never in probes.
- **Time limit:** 30 s without a right sweep ends the round as a miss (`timed_out`).
- **Sweeps** come from the rig (`Events.swept`, `rig/pointer.gd`): one move of a hand from rest to rest (or 2 s of moving), cut into legs where it turns back; the longest leg is the sweep, so a wind-up before it or the way back after it is not. The first 0.8 s of a round take no sweep (`early`, silent): hands are still settling from the last round. On a Quest 3 hand tracking dropped the pinch as the hand moved, so the old pinch-sweep-release was cut into pieces of a few centimetres. Sweeps are judged in the cloud's frame frozen at round start. Pausing and losing tracking drop an unfinished sweep.
- **Staircase:** moves on `first_try` (solved by the first valid sweep, no help), like every trial. Pin a level with the facilitator or `Block.difficulty`; pin a direction with `Block.pins`.

**Limits:** coherence is a stimulus parameter, not a clinical threshold; the geometry differs from a calibrated 2D RDK, and toward / away may rest on size and binocular cues. Thresholds and the 0.8 s dot lifetime are provisional. Noise directions are redrawn each lifetime.

**Still to check on a headset:** all four directions with both hands, tracking loss, system-menu pause, help vs probe, reach comfort, dot visibility over passthrough at 2.2 m, frame rate, `tracking_changed` firing for tracked hands, sweep speed thresholds with children.
