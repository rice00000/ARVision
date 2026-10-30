# Native-route tests (Megan's Quest 3)

Log of setup, tests and decisions for running ARVision (Wei's project, GitHub `rice00000`) on Megan's Quest 3 and checking it against her browser/WebXR results. Branch `megan-native-quest-AR`. Newest at the bottom of each table. Every test: Goal, Question, How, Result, Conclusion, Next.

## Session goal (Oct 29)

Get ARVision building and running on the headset. Later sessions: camera frames (N2), detection speed (N3), label accuracy (N4).

## Plan

| Step | Question | Status |
|---|---|---|
| N0 | Does the Mac see the headset, and what is its factory camera calibration? | Done Oct 29 |
| N1 | Does ARVision run on the Quest (passthrough, hands, tables)? | Pass Oct 29 (table not checked) |
| N2 | Do passthrough camera frames reach Godot? | Pass Oct 30 (CV Lab v1) |
| N3 | Detections per second on the headset vs the browser (11–12/s); A/B: interval 0, 320 px input, more threads | Baseline Oct 30: 3.0/s |
| N4 | Do labels land on real objects? Compare with browser test 4.3 (2–3 cm); use this headset's own focal length | — |

## Setup (Mac)

| Date | Step | Result |
|---|---|---|
| Oct 29 | `adb devices` | First `unauthorized`; after allowing USB debugging in the headset, `device`. USB debugging works on this headset (it never did on the club headset). |
| Oct 29 | Godot | 4.7.2.stable.official already installed |
| Oct 29 | Repo | Now at `~/quest-cv/ARVision`, branch `megan-native-quest-AR`. The first clone in `Documents/Virtual Reality` broke because Documents syncs to iCloud (`git status`: "unable to map index file: Operation timed out"). Keep Git repos out of iCloud. |
| Oct 29 | Java 17 | Azul Zulu 17.0.21 via `brew install --cask zulu@17` (needs the Mac login password) |
| Oct 29 | Android SDK | Android Studio 2026.2.2 setup wizard (Standard) → `~/Library/Android/sdk` |
| Oct 30 | USB debugging | Headset showed `unauthorized` with no prompt, even after `adb kill-server`. Fix: restart the headset, then replug while wearing it. |
| Oct 29 | Godot Editor Settings → Export → Android | Java SDK Path `/Library/Java/JavaVirtualMachines/zulu-17.jdk/Contents/Home`, Android SDK Path `~/Library/Android/sdk`; debug keystore made automatically |
| Oct 29 | Export templates + Android build template | 4.7.2 installed |
| Oct 29 | OpenXR Vendors 5.1.0 | From the GitHub release `5.1.0-stable` (`godotopenxrvendorsaddon.zip`) into `addons/godotopenxrvendors/`; the export preset already enables the Meta plugin |

## N0 · Factory camera calibration (Oct 29)

- **Goal:** know this headset's real camera numbers instead of hand-measured ones.
- **Question:** what are camera 50's (left passthrough) intrinsics and pose, and how do they compare with `quest_camera.gd` and the browser estimate?
- **How:** `adb shell dumpsys media.camera`, read camera 50's `android.lens.*` fields.
- **Result:**

| | This Quest | `quest_camera.gd` | Browser test 4.3 (club headset) |
|---|---|---|---|
| Focal length, 1280 px wide | 869.4 px | 864.6 px | 845 px |
| Principal point (1280×1280 sensor) | (637.8, 639.8) → (637.8, 479.8) after the 1280×960 crop | image centre | (640, 480) |
| Position from the pose reference (gyroscope) | 3.2 cm left, 1.8 cm down, 6.3 cm ahead | same | — |
| Tilt | ≈ 11° down | 11.1° | ≈ 10° |

- **Conclusion:** focal length differs per headset (0.6% here); the camera position matches the code exactly, so it is likely a design value. The browser estimate was about 3% low. Cropping keeps focal length and moves the centre; scaling changes both.
- **Next:** for N4 on this headset, use f = 869.4 (at 640×480: f = 434.7, `FOV_Y` ≈ 57.8° instead of 58.1°).

## N1 · Does ARVision run on this Quest? (Oct 29)

- **Goal:** prove the Mac toolchain builds and installs to this headset before testing CV.
- **Question:** does the app launch with passthrough, hands and the game?
- **How:** Remote Deploy from Godot 4.7.2 (preset "Meta Quest 3"), over USB.
- **Result:** builds and launches. Passthrough works (real hand visible). The adventure starts with its grey-spell filter, strong enough that the table couldn't be judged; the facilitator panel (left palm toward you, pinch) pauses play, and Next view reaches normal colours. First failure: Java SDK Path had three leading spaces from pasting (Godot: "Missing 'bin' directory").
- **Conclusion:** PASS for the toolchain and passthrough. The game is too busy to test CV in.
- **Next:** a separate CV Lab app with no game (see Decisions), for N2–N4.

## N2 · Do camera frames reach our code? (Oct 30)

- **Goal:** confirm the frames YOLO will see are the real room, before any detection.
- **Question:** does `QuestCamera` deliver correct 640×480 images on this headset?
- **How:** CV Lab v1 (`tools/cv_lab/`, its own app `edu.mit.arvision.cvlab`): passthrough, the camera texture on a head-locked panel, a once-a-second readout; first frame saved with `save_png("user://frame.png")`, pulled with `adb exec-out run-as edu.mit.arvision.cvlab cat files/frame.png`.
- **Result:** feed `50 | BACK` (left camera), datatype 3 (separate Y and CbCr planes), YUV_420_888. The camera offers 11 sizes from 320×240 to 1280×1280, including 640×480. Saved frame: 640×480, correct colours, the real room (library aisle; bottle, bag, chair, person, books in view). The panel was purple/black noise at first, then correct.
- **Problems on the way:** (1) scene missing from the app: the copied preset excluded `tools/*`; now `tools/sim/*` like the Recorder. (2) "no camera yet": the new app needs its own camera permission (`adb shell pm grant edu.mit.arvision.cvlab horizonos.permission.HEADSET_CAMERA`).
- **Conclusion:** PASS. Frames reach our code in the right format; Wei's "Quest camera unverified" can be marked verified on this headset.
- **Next:** N3, YOLO on these frames with a detections-per-second readout. Saved frames can show people: keep them out of the repo.

## N3 · How fast is YOLO on the headset? Baseline (Oct 30)

- **Goal:** know the real detection speed before changing anything, and where the time goes.
- **Question:** detections per second, and model time vs total time, for Wei's YOLO11n (640 px, ONNX Runtime on the CPU, XNNPACK, 2 threads)?
- **How:** CV Lab v2: send the next frame as soon as the last answer arrives (no timer), readout once a second: rate, plugin `ms`, total ms from grab to answer, top labels ≥ 0.4.
- **Result:** 3.0 detections/s; model ≈ 285 ms; total ≈ 300+ ms (to confirm). Detected laptop, person, book (library desk).
- **Conclusion:** BASELINE. The model step is almost all of the time; copying and JPEG add little. About 4× slower than the browser (11–12/s, COCO-SSD at ~300 px on the GPU). Wei's game timer (0.5 s) already caps it at 2/s.
- **Next:** one change at a time: (a) 4 threads instead of 2; (b) YOLO11n exported at 320 px; (c) a GPU/NPU execution provider (NNAPI).
- **Debugging on the way:** the scene's root node was hidden (`visible = false` from the eye icon), which hid the panel and label (children of the hidden node). Found by print checkpoints (YOLO answered) plus a YOLO-off switch (still nothing), which pointed away from the code.

## Decisions

| Date | Decision | Why |
|---|---|---|
| Oct 29 | Try speed changes in ARVision before considering Unity | Speed depends on model input size and CPU vs GPU, not the engine; ARVision has depth and the team game |
| Oct 29 | Build a separate CV Lab app for N2–N4, following Wei's Recorder pattern (own export preset + feature tag + scene with the Rig, using `QuestCamera` and the Yolo plugin directly) | The game's filters and menus hide what the detector sees; a separate package (`edu.mit.arvision.cvlab`) installs beside the game without changing it |

## To review later

- `rig/rig.tscn` and `rig/rig.gd`, `rig/pointer.gd`: how the Rig tracks the head and hands, and how pointing and pinching become choices.

## Next session (from Oct 30)

1. Confirm N3 total ms (Output prints `CVLAB readout:` once a second).
2. Commit and push: keep `tools/cv_lab/`, `docs/native-tests.md`, `export_presets.cfg`, `project.godot`; discard Godot's rewrites of Wei's `.tres` files and `main.tscn`.
3. Game-tied N4: run Wei's `point_real` trial on the headset (`demo` session) — does the marker land on the real object; what happens on misses.
4. Speed experiments (threads, 320 px) only if `point_real` feels slow.
5. If USB stops being detected: restart the headset, replug while wearing it.

## M1 · Global motion on the headset (from Oct 30)

- **Goal:** find what is wrong with the global-motion trial on a real Quest before anyone changes code; agree fixes with Wei.
- **Question:** which items on Wei's "Still to check on a headset" list (docs/global-motion.md) pass, and what looks wrong?
- **How:** app "ARVision Motion" (preset "Meta Quest 3 Motion", package `edu.mit.arvision.motion`, starts `content/sessions/motion.tres`). Hands only.

| Check | What to do | Observed | OK? |
|---|---|---|---|
| Four directions, both hands | Sweep right, left, toward, away; once with each hand | | |
| Dots visible over passthrough at 2.2 m | Can you see the cloud clearly in your room? | | |
| Radial "gathering" motion | Does toward/away look right, or wrong / too hard? | | |
| Frame rate | Smooth, or stutters? | | |
| Help vs probe | Raise a hand: do all dots follow the flow? (not in probes) | | |
| Tracking loss | Hide a hand, bring it back | | |
| System-menu pause | Open the Quest menu mid-round, come back | | |
| Reach comfort | Sweeps comfortable seated? | | |
| Sweep thresholds | Do gentle sweeps count? (child-speed later) | | |

- **Result / Conclusion / Next:** after the run.
