# Vision profile

Each child's save holds how the game should look and feel for them (`core/vision.gd`, autoload `Vision`, key `vision` in `save.json`). Staff edit it on the facilitator panel's **Vision** page (**M** on PC, palm pinch on Quest); every change shows at once, is saved, and is logged.

| Setting | Effect | Range |
|---|---|---|
| Filter | The child's passthrough view: contrast, brightness, colour (saturation), dim, spotlight, black and white, edges. Start from a view preset (`<` `>`) and adjust; a hand edit is titled "Custom". | as `View` |
| Start | Applies a profile preset from `content/vision/` (filter and the three scales; offsets and adaptive stay). | Normal, Low acuity, Light sensitive, Focus |
| Size | Times every axis tagged `scaled_by = &"size"`: find (up to 0.14 m) and tidy (up to 0.075 m, so the biggest thing still fits its cubby). | ×0.75–2 |
| Help wait | Times `hint_after` and `hint_fade`: ×0.5 = help twice as soon. Help that only comes on request stays so. | ×0.5–2 |
| Time | Times `time_limit`. | ×1–3 |
| Difficulty | For the level being played: an adaptive level's own staircase; with Adaptive off, an offset added to its start. | 0–1 / ±0.5 |
| Adaptive | On (the default): every menu level adapts within its own range ([adaptive levels](adaptive-levels.md)). Off: each plays fixed at its start. | on / off |
| Reset to normal | Everything back to neutral. | |

**Rules.**
- A block with its own `Block.view` (filter A/B in session plans) shows that view; the child's filter applies everywhere else (world, intro, blocks without a view). The page says when a block's view is in charge.
- Probes use the child's profile too, so pre and post match for that child. Each `block` log line carries the whole profile with its `revision`; two probes with different revisions ran under different profiles.
- Changes are `vision_changed` events with `before` and `after`. A facilitator pin (Training → Easier / Harder) still overrides everything for the session.
- Copying a save copies its profile; a new save starts neutral.

**Add a preset:** a `VisionPreset` `.tres` in `content/vision/`, listed in `Facilitator.vision_presets` in `main.tscn`.

**Grow another axis with size:** set `scaled_by = &"size"` on the `TrialAxis`, and `scaled_max` where the layout stops fitting.

**Not yet:** desk, bookshelf, sandwich, motion and butterflies have no size axis, so Size does not change them. Filter values are Meta's passthrough units and need checking with the headset worn.

Tests: `tests/vision_test.gd`.
