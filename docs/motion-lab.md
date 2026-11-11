# Motion stimulus lab

## November 10 additions: setup before replay, blur, three results graphs

From the Nov 10 updates in `MOTION_BUILD_DIRECTION_PLAN.md`. Same lab, same launch (`-- --block`). Everything below is an **exploratory usability feature**, not a measurement protocol.

**Change setup** (in the menu, after a set, or from Pause, where it ends the running set as `ended_for_setup_change`; the next set is a new block). Coherence, dot speed and **blur (dots only)** are on top. *More visibility settings* holds the field shape (rectangle or reference-sized circle), number of dots, dot size and exposure time. **Reset to defaults**, **Preview (unscored)** (one look at the pending setup with the direction revealed; never scored, never in results), then **Start a set**. A set snapshots its whole setup when it starts; nothing changes a running set. Ranges are developer bounds in `block_config.gd` `RANGES` (coherence 5–100 %, speed 0.10–0.60 m/s, blur 0–0.50° σ, exposure 0.5–2.0 s, dot radius 1–4 cm, dots 15–300), not clinical ranges. Tip from the plan: change one thing at a time if you want to compare.

**Blur** blurs the dots only: each dot is a flat disc whose edge follows a Gaussian profile (`blur_dot.gdshader`, alpha = Φ((r − d)/σ), logistic approximation). Panels, text and buttons stay sharp. It is exact when σ is small next to the dot radius and underestimates the spread as σ nears the radius (dot radius ≈ 0.52° at 2.2 m; σ max 0.50°). It is not a simulation of any diagnosis and not a treatment. The record keeps `blur_sigma_deg` and `blur_impl`. In block mode all dots are drawn as these discs (`dot_render`), sharp when σ = 0.

**Datasets.** Results accumulate only inside one **non-identifying dataset label** (e.g. `review-2026-11-10-3fa1`), shown on the setup screen. **New dataset** starts another (a different person or visit). Override with `-- --dataset=LABEL`. The scripted walkthrough always uses its own folder and a `SCRIPTED-WALKTHROUGH-…` dataset; tests use `SYNTHETIC-FIXTURE-not-participant-data` in their own folder. Neither can mix into a review dataset.

**See results** (optional, after a set; never required to continue or leave). Three graphs:
1. **Trial outcomes** (primary): trial number vs correct (●) / incorrect (✕), with direction and realized coherence under each trial; *correct k of n eligible*. Eligible = an answered review trial with no assistance. Interrupted, abandoned, assisted and unanswered attempts are counted separately and drawn as gaps or squares, never as wrong answers.
2. **Time to registered answer** (secondary): seconds from **response enabled** (dots off) to the accepted answer, per trial; median over eligible trials with its n. A post-exposure response latency on the app's monotonic clock, **not** motion-onset reaction time; it includes deciding, moving and input recognition. Missing answers are gaps, not zeros. There is no speed target.
3. **Accuracy versus coherence**: tested (realized) coherence vs observed accuracy, one point per tested level with *k/n* and a **95 % Wilson interval**. No fitted curve, no threshold, no 82 % line. *This block* / *whole dataset* scope. The dataset view pools only blocks with the same dataset AND the same condition (everything except coherence, seeds and direction: field, dots, dot size, speed, lifetime, noise, contrast, blur, exposure, renderer/XR and input). Other conditions are separate series (*Next condition series*). Pooling is recomputed from the saved records each time, de-duplicated per attempt, so reopening never double-counts. With no eligible data it says so.

**Record additions (schema 2):** `dataset_id`, `clock`, `latency_definition`, `coherence_definition`; per block `condition_key`, `condition_label`, `input`; per attempt `times.response_enabled_ms`, `input_modality`, `coherence_requested`, `signal_dots`, `total_dots`, `coherence_realized` (round(requested × dots) / dots: e.g. 90 % of 15 dots is 14/15 = 93.3 %). No gesture-onset time exists, because there is no hand input yet.

**Verified Nov 10 (desktop only):** 15 lab tests pass (the 9 from Nov 9 plus: synthetic 3/6 at 40 % → 50 % [Wilson 18.8–81.2 %] and 5/6 at 80 % → 83.3 % [43.6–97.0 %]; repeated same-condition blocks pool to 7/12; blur and speed changes split the series; teaching, interrupted and assisted trials stay out of the denominator; re-reading never double-counts; other datasets excluded; empty state; a known timing fixture of 0.25 / 0.50 / 0.75 s plots exactly, with unanswered trials as gaps; setup changes only reach a new block; requested vs realized coherence). The scripted walkthrough now also covers results, setup with blur, an unscored preview, a second set at 40 % + blur (a separate series in the dataset view) and a set ended for a setup change. Screens were inspected; blur leaves all UI sharp.

**Still NOT verified:** anything on the Quest, the hand-sweep answer, children's understanding of the graphs, and whether any setting suits anyone. Graphs on 6 trials are descriptive only.


## Trial block (November 9 build): teaching, six trials, pause/leave, developer record

Built from `assets/entry-scene/worldbuilding/MOTION_BUILD_DIRECTION_PLAN.md`. It lives only in this lab: no production motion task, scoring, Session, dialogue or project setting was changed. **Desktop flow check only.** It is not a validated measurement, a rehabilitation dose or a threshold estimate.

**Launch straight into the block:**

```sh
/Applications/Godot.app/Contents/MacOS/Godot --xr-mode off --path . res://tools/motion_lab/motion_lab.tscn -- --block
```

(Or launch the lab as before and press **Trial block**. Press it again to go back to the stimulus preview.)

**Flow.** Menu → *Watch an example* (unscored, 2 s, the answer is revealed afterwards) / *Practise answering* (unscored, easy 100 % coherence, the answer is shown after the response) / *Start the trials*. Each trial: **Get ready…** with a neutral "+" (1 s, dots hidden) → dots (1 s) → dots off, "Which way did the dots go?" → one left/right answer → "Answer received: LEFT/RIGHT" (same wording whether right or wrong) → **Next**. Six trials, three left and three right in shuffled order, each with a fresh recorded dot seed, one stable configured condition. Then **Rest / Another set / Leave**.

**Rules the flow keeps.** One answer per trial, accepted whatever its correctness; correctness is stored but never shown in the block and never gates Next. Input during "Get ready" or the dots is *early*: logged, shown "Too early: wait until the dots are gone", never counted. A second answer is a *duplicate*: logged, ignored. No response timeout. **Pause** works in every phase; pausing before an answer marks the attempt *interrupted* (an interrupted exposure is never treated as a judgment), and **Resume** starts a fresh attempt for the same slot with a new identity and seed, so leftover input lands as early. **Leave** works anywhere; an unfinished block is saved as `left_early` and the open attempt as `abandoned`.

**Controls (desktop FALLBACK, not the intended hand sweep):** ←/→ keys or the Left/Right buttons answer; Space/Enter = Next/Continue; P = Pause/Resume; Esc = Leave. Menu-only DEV buttons switch the field and the coherence for the *next* block.

**Settings (all PROVISIONAL developer defaults, in `tools/motion_lab/block_config.gd`):** 1 s preparation, 1 s exposure, 2 s example exposure, 100 % teaching coherence, 6 trials, block coherence 90 % (DEV: 90 / 70 / 40). Two fields:
* `preview_rectangle`: the existing preview geometry (motion_demo.tres baseline, flat centres, 200 dots, about 40 × 26 deg at 2.2 m).
* `reference_circle_10deg`: 15 dots in a 10 deg circle, **sized** after Rajendran et al. 2020. Not a replication: dot speed/displacement, lifetime, dot size, contrast and the noise algorithm are the lab's own, and the display is uncalibrated. The circle re-enters dots at the opposite edge; the shader's rectangle path is unchanged when `circular` is off.

**Developer record.** Saved after every answer, early input, pause, leave and block end, to `user://motion_lab_records/` (on a Mac: `~/Library/Application Support/Godot/app_userdata/ARVision/motion_lab_records/`), one file per run plus `latest.json`. The path shows on screen. Contents: run seed and display info (renderer, window, refresh if known, `verified_on_headset: false`); teaching attempts kept apart from blocks; per block the id, status, planned order and its seed, and the exact configuration copied in; per attempt the id (`B1-T2-A2` = block 1, trial slot 2, second attempt), purpose, direction, dot seed, coherence, requested times, the answer and its source, `correct` stored separately, latency from dots off, early and duplicate inputs, assistance, interruption, and status (`answered`, `interrupted`, `abandoned`, `shown`). No participant data.

**Requested vs measured timing.** `requested_onset_ms` / `requested_offset_ms` come from the flow's clock. `presented_ms` / `hidden_ms` are taken after the app actually drew the first frame with / without dots, giving `measured_exposure_ms` and `frames_drawn`. They measure the app's rendering, **not** photons on a display. In the Nov 9 desktop check (software renderer, about 20 fps) measured exposures were 998–1048 ms for 1 s requests. Before a warm-up step was added, the first exposure of a run was cut to 1654 ms of a 2 s request by shader compilation; the lab now pre-draws the dot material hidden when block mode opens.

**Scripted desktop walkthrough** (screenshots plus `example_record.json`; needs a rendering window): teaching, a full block with a deliberately wrong answer, an early and a duplicate input, a pause during the dots, then a second block on the reference circle left mid-exposure:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --xr-mode off --path . res://tools/motion_lab/motion_lab.tscn -- --block-walkthrough=res://build/motion_lab_block
```

**Verified (Nov 9, desktop only):** 9 lab tests pass (`--only=motion_lab`: state order, single-answer acceptance, early/duplicate handling, correctness-independent advancement, 3/3 balance and fresh seeds, pause-as-new-attempt, teaching kept separate, leave-early record retrieval, reference sizing). The scripted walkthrough ran end to end under software rendering, and its saved record matched every action.

**NOT verified:** the Quest (visibility, size in the headset, actual display timing, comfort), the intended hand-sweep response (not wired: the lab only has desktop fallback input), children's understanding of the question, and whether 1 s / 6 trials / 90 % suit anyone. All of that needs device and facilitator checks before any participant pilot. Deferred by the plan: adaptive difficulty, blur, the surrounding field, a coherence-comparison block.

## Stimulus preview (November 8)

November 9 design clarification: the expert-vision handoff selects a flat world-anchored window for controlled testing and a surrounding world-anchored field for AR exploration. This lab only compares a frontal volume with a flat-centre preview. Its volume mode is NOT the selected surrounding-field experience, and its flat mode is NOT yet a benchmark-faithful assessment. See the project research/GLOBAL_MOTION_README.md before interpreting either as the intended activity sequence. They are visual developer aids, not competing final choices for the whole game.

Developer-only **desktop stimulus preview**. It does not replace the motion activity, teach a gesture, score responses, estimate thresholds or write participant records. It has not been validated on Quest or with children.

Launch from the repository:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --xr-mode off --path . res://tools/motion_lab/motion_lab.tscn
```

Buttons select volume/flat, heading, 90/70/40% coherence, neutral panel visibility, or restart at seed 42. Both modes reuse baseline count, distance, speed, lifetime and field width/height from `motion_demo.tres`; both use the current 0.02 m unshaded sphere radius. Flat mode means **coplanar dot centres**, not flat disc meshes.

Volume mode uses the existing particle shader unchanged. Flat mode uses a separate shader: all centres stay at z=0, with unit-length random directions in XY. It retains cyclic exact signal count, lifetime respawning and rectangular wrap. It isn't a circular 2D literature RDK, a faithful replication or a calibrated display.

Geometry AND noise dimensionality change between modes. Perspective, projected dot size/density and screen-speed distributions also differ. Labels report centre-plane angular extent, not the whole volume's angular bounds or speed calibration. A visual preference between modes is not evidence of training benefit. Background-off is a plain simulated environment colour, not actual passthrough.

First review: field visibility/bounds, impression of depth, legibility at high coherence, and background interference. Make one selection at a time. Decide stimulus geometry before adding arrival animation or decorative feedback. Research/expert approval is still needed for a measured task and comparisons.

Render review images:

```sh
/Applications/Godot.app/Contents/MacOS/Godot --xr-mode off --path . res://tools/motion_lab/motion_lab.tscn -- --capture-dir=res://build/motion_lab
```

Tests: run `res://tests/run.tscn -- --profile=test --only=motion_lab` with headless/XR-off flags, then existing motion tests. Headless settings tests do not validate rendered trajectories or a headset's actual viewing conditions. No original production shader, task, scoring, script or project configuration needs changing to run this scene.

Validation November 8: 23 motion-related tests passed, including two new lab tests. The broader motion run emitted resource-in-use/leak warnings on shutdown; isolated lab tests exited cleanly. Both modes rendered on the desktop Metal renderer and their saved frames were visually inspected in build/motion_lab/. This is not headset or participant validation. The flat shader adapts the existing shader's hashing, cyclic signal assignment and respawning while changing geometry and noise dimensionality.
