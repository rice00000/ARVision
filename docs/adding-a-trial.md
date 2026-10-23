# Adding a trial

`trials/find/` is the worked example.

1. **Folder** `trials/<kind>/` holding `<kind>_trial.gd`, `<kind>.tscn`, `<kind>.tres`.
2. **Script** `extends Trial`:
   - `_setup(condition)`: build the round from `condition.value(&"axis")`; `condition.set_value()` anything else you choose (target, seed) so the log can replay it; `say()` the instruction. Never `finish()` here.
   - Judge input in `_on_selected(hand, target, origin, direction)`, `_on_touched(hand, target)`, `_on_button(hand, action, pressed)` or `_on_tracking(hand, tracked)`. They only run during a live, unpaused round, so drop half-done gestures in `_notification(NOTIFICATION_PAUSED)`.
   - Right: `judge(&"good", at)` then `finish(true, extra)`. Wrong: `judge(&"bad", at)` and `count_try()`. The staircase only counts rounds solved on the first try without help.
   - `_hint(level)`: help from gentlest (1) to `max_hint`. `_teardown()`: stop what the round started.
   - Place things with `App.reality.work_surface()`, `surfaces(kind)` or `in_front(distance)`. Clickable things are `Target`s.
   - Override `focus_point()` when the action is not on the work surface (spotlight views centre there).
3. **Scene** whose root has the script. Child nodes are fine; the instance lives for one block. Mark materials the script changes `resource_local_to_scene`.
4. **TrialDef** `.tres`: `scene`, `skill`, `axes` (one `driven`), help timing, `time_limit`, and `requires` (e.g. `&"Detector"`).
5. **Plan:** add a `Block` to a `content/sessions/` plan (`Block.pins` fixes axes for that block), or test it alone with `TestCase.plan_of(def, rounds, ...)`.
6. **Test:** a `tests/<kind>_test.gd` extending `TestCase` that plays rounds through `input` (SimInput). For whole sessions, teach `tools/sim/child.py` how to answer it and add a scenario in `tests/sim/` ([testing](testing.md)).

Use only `Events`, `App` and the Reality API. No headset checks, no input polling, no own logging.
