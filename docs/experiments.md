# Anticipated experiments

What the team is likely to try (design doc, team sketch) and what the framework already gives each. "Ready" = runs today.

| Experiment | Skill / layer | Built from | Status |
|---|---|---|---|
| **Find it** on the real table: name a toy among virtual clutter | objects in clutter, perception | `trials/find`, `work_surface()` | ready |
| **Tidy up:** put each thing back on its shadow, outline, size or colour sticker | shape matching, vision for action | `trials/tidy` ([tidy up](tidy.md)) | ready (sim); headset unverified |
| **Real objects:** point at the real cup the camera sees | recognition, real world | `trials/point_real`, Detector | ready (sim); Quest camera unverified |
| **Global motion (RDK in 3D):** sweep in the dots' direction | motion perception | `trials/motion` (Megan's trial) | ready (sim); headset unverified |
| **Passthrough filter A/B:** same trial under normal vs high contrast / greyscale / B&W / edges | visual function, contrast | `Block.view`, `content/views/` | ready |
| **Less information:** dim the room, spotlight the work area | attention, clutter | `View.dim`, `focus_radius`, `Trial.focus_point()` | ready |
| **Help that fades:** motion, glow, voice; logged per round | all | `Trial._hint`, `TrialDef.hint_after / hint_fade` | ready |
| **Pre / post check-in** on new objects, no help | outcome measure | `Block.probe` | ready |
| **Contrast sensitivity:** patches on the real wall at falling contrast | visual function | new trial, `surfaces(&"wall")`, driven contrast axis | add a trial |
| **Reach and touch:** targets at varying depth | vision for action | new trial, `Events.touched`, `Pointer.tip()` | add a trial |
| **Which is nearer:** two objects in depth | getting around | new trial, `in_front()` | add a trial |
| **Faces / expressions** | people | new trial (virtual faces) | add a trial; CV faces later |
| **Feel it, then find it:** touch a real object, find its twin | touch to sight | Detector + new trial | later |
| **Selective passthrough:** real world only through a window | clutter | `OpenXRFbPassthroughGeometry` in `PassthroughReality` | later |

Changing one setting at a time: put the variable in **one** of a driven `TrialAxis`, a `Block.view` or a `Block.difficulty`, keep the rest fixed, and the log keeps every round attributable.
