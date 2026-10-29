# Global motion (RDK in 3D)

`trials/motion/`. Original design, shader and gesture logic by Megan ([Mgharv](https://github.com/Mgharv)), ported from XRVision.

**What it measures:** motion coherence in depth. A cloud of dots floats 2.2 m ahead; a fraction (coherence) moves right, left, toward or away, the rest is noise. The child sweeps a hand the way the flow goes; no pinch. The moment the hand has gone the right way the round is won and the dots align into streaks. A sweep the wrong way counts a try once the hand stops, and the stimulus stays; one that turns straight into the right way was a wind-up and counts nothing.

- **Defs:** `motion.tres` (random-direction noise, skill `global_motion`) and `motion_competing.tres` (noise is one opposite flow, skill `global_motion_competing`, coherence never below 0.55). Plan: `-- --plan=res://content/sessions/motion.tres`.
- **Axes:** coherence (driven, 0.9 to 0.15), then fixed: `direction` (0 random, 1-4 right, left, toward, away, 5 random lateral; the tech demo uses 5), `dots`, `speed`, `dot_lifetime`, cloud `half_*`, `distance`, `tolerance` (judged on the level direction).
- **Logged per round:** `heading`, `plane` (lateral / depth), `flow`, `signal_dots`, `seed`, `tries`, `hint`, `first_attempt_correct`, `attempts` (angle, distance, duration, onset, where it set off, hand, help, coherence shown), `windups`. Attempts and forgiven wind-ups also go out as `motion_attempt` / `motion_windup` events. Onset means when the hand set off; distance and duration run to the moment of judging. Rescore strictly with `first_try` and `windups == 0`.
- **Help:** only when the child raises a hand, one level: every dot follows the flow. Never in probes.
- **Time limit:** 30 s without a right sweep ends the round as a miss (`timed_out`).
- **Sweeps** (`rig/pointer.gd`): the hand going faster than 0.3 m/s at least 0.12 m sideways, toward or away, from where it was last slower, moving mostly up or down, or turned back: a raised hand sweeps nothing, one lifted on its way sweeps from where it levels out. `Events.sweeping` comes every tick of it (a white streak and a whoosh show it, right or wrong alike: `sweep_trail.gd`), `Events.swept` once the hand has been slow 0.4 s (a turn is quicker). Set off in a round's first 0.8 s: hands settling, ignored. Judged in the cloud's frame frozen at round start. Pausing or losing tracking drops an unfinished sweep.
- **Tried before:** pinch-sweep-release (Quest drops the pinch as the hand moves); the first leg of a move (the pull-back before a sweep counted a wrong try); the longest leg of a whole move (waited up to 2 s for the hand to rest, and a pull-back as long as the sweep won).
- **Staircase:** moves on `first_try` (solved with no wrong try, no help), like every trial. Pin a level with the facilitator or `Block.difficulty`; pin a direction with `Block.pins`.

**Limits:** coherence is a stimulus parameter, not a clinical threshold; the geometry differs from a calibrated 2D RDK, and toward / away may rest on size and binocular cues. Thresholds and the 0.8 s dot lifetime are provisional. Leniency: a wrong sweep straight back without a stop finds the right way (logged as a wind-up). Noise directions are redrawn each lifetime.

**Still to check on a headset:** all four directions with both hands, tracking loss, system-menu pause, help vs probe, reach comfort, dot visibility over passthrough at 2.2 m, frame rate, `tracking_changed` firing for tracked hands, sweep speed thresholds with children.
