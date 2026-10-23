# Testing

`python tools/test.py` runs everything headless, in parallel, in about 15 s; non-zero exit on any failure.

- **GDScript unit tests** `tests/*_test.gd` (`TestCase`): one piece at a time on the real app.
- **Scenarios** `tests/sim/test_*.py` (`unittest`): whole sessions on the real `main.tscn`, played by a simulated child.

`python tools/sim/walkthrough.py` renders a walkthrough to `build/walkthrough/` (PNGs + `review.html`) and runs `tests/rendered/` against `tools/cv_server.py --fake`. Open the pictures: a finished script is not a visual pass.

## The simulated child

- `tools/sim/server.gd` boots `main.tscn` on `SimReality` and answers JSON lines on 127.0.0.1. Lockstep: game time moves only while a command runs, 1/60 s per frame (`--fixed-fps 60`). It acts only through `SimInput` (head and hand poses moved over time, buttons, tracking) and only reads engine facts (`observe.gd`). Options: plan or plan spec, `--unplug=Detector,Voice`, `--seat`, `--eye`, `--keep-profile`, `--cv-server`.
- `client.py` launches it (`Sim`); `body.py` + `profiles.json`: seated bodies that refuse the impossible with a coded `ConstraintError` (reach, torso, head_yaw/pitch/lean, out_of_view, behind_head, hand_speed, path_blocked); `actor.py`: the child's and the facilitator's hands; `policy.py`: a seeded **test driver** that turns facts (angular size, clutter, coherence, view, hints) into right and wrong answers, help and timeouts. It is not a model of vision. `child.py` plays rounds by policy or by script; `research_log.py` checks logs.
- Profiles start with `test` and are wiped. Layouts are random: read facts, never predict them.
