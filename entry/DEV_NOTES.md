# Entry scene: dev notes for the chats that work on it

The opening ("scene one") is `entry/` in Wei's ARVision (Godot 4.7.2, Quest 3). Megan's branch is
`megan-native-quest-AR`; her clone is `~/quest-cv/ARVision` on her Mac. Wei's `master` is merged in
(scene switching: the opening is the `intro` scene, it ends with `App.main.change_scene(&"find_object")`).

## What is where

| File | What |
|---|---|
| `entry/entry.gd` | the opening: setup (4 steps for the grown-up), the parts (`_hello`, `_touch`, `_out`, `_reveal`, `_to_shelf`), Onion, cauldron, gear, panel, ripple, hand-over |
| `entry/setup_panel.gd`, `entry_button.gd` | the setup panel and its buttons (poke / pinch / hover, forgiving hit boxes) |
| `entry/part_runner.gd` | everything a part waits on lives on one runner; a jump button frees it to cancel the part |
| `entry/workshop.gd` | what survives the scene switch: Onion, cauldron, panel, gear (it becomes the shelf scene's guide) |
| `entry/gear_spin.gd` | turns the gear's parts at steady speeds, for ever |
| `entry/carry.gd`, `entry/demo_hand.gd` | the seam between the two chats: STUBS with the agreed API |
| `tests/entry_test.gd` | the opening's tests (20) |
| `tools/entry_shots*.gd` | pictures without a headset |

Story and decisions: `~/Documents/Virtual Reality/assets/entry-scene/BUILD_CHAT_UPDATE_2026-10-31.md`
(the 13-beat storyboard, lines, asset notes). Read it first. Decisions made since: Onion + cauldron + the
installed mechanism persist across the scene switch (the `Workshop`); the gear is a light stand-in
(the real 57k-triangle gear is optional and NOT CC0); the shelf stands back along the table (`push`,
set by the child's measured reach); the child's reach is measured in setup step 3.

## Two chats, one seam

* **Interaction chat** owns `carry.gd`, `demo_hand.gd` and their tests (`tests/entry_interaction_test.gd`).
  It may touch `entry.gd` ONLY in `_build_gear()` (to configure `_carry`/`_demo`) and by adding a new
  region `# --- Interaction`. It does not edit lines, Onion, the part functions, `_play`, `_set_up_for`.
* **Story chat** owns the beats and everything about Onion: `_hello`, `_touch`, `_out`, `_reveal`,
  `_play`, `_set_up_for`, `PARTS`, `say()` lines, Onion's actions (`entry/onion_actions.gd`, new),
  `?`/`!` marks, the cauldron's rattle and Onion's pop, the ripple, sounds, and `tests/entry_story_test.gd`.
  It calls the interaction chat's API; until that is real it uses the stubs.
* Do not rewrite `tests/entry_test.gd`; fix it only where your change breaks it.
* Each chat works on its own branch from the same base and **never touches Megan's working tree**:
  deliver by fetching the bundle into a branch ref (below). Megan tests with `git checkout <branch>`;
  one integrator merges.

### The API the two chats agree on

```gdscript
# Carry (child of Entry as `_carry`)
signal picked_up
signal released(docked: bool)
signal docked
var enabled: bool          # the child may pick it up now
var held: bool
func begin(gear: Node3D, socket_at: Vector3) -> void   # start watching
func stop() -> void
func simulate(after := 1.0) -> void                    # stub / tests: pretend the child did it

# DemoHand (child of Entry as `_demo`)  each shows ONE gesture, looping, until stop()
func tap(at: Vector3) -> void
func pinch_lift(gear: Node3D) -> void
func lower_release(socket_at: Vector3) -> void
func stop() -> void
```
Change this API only by telling the other chat (add a line to this file's "API changes" below).

API changes: (none yet)

## Setting up a cloud copy (each chat)

1. Godot 4.7.2: download `Godot_v4.7.2-stable_linux.x86_64.zip` from the godotengine GitHub release, unzip.
2. Get the repo: on Megan's Mac (`device_bash`, folder `~/quest-cv/ARVision`): `git bundle create tools/.in.bundle <branch>`;
   `device_stage_files` that file; in the cloud `git clone -b <branch> /mnt/user-data/uploads/ARVision/tools/.in.bundle`.
   Delete the bundle from her folder afterwards.
3. The cloud Godot has no Quest plugin, so add one stand-in file (never commit it; add it to `.git/info/exclude`):
   `tools/_cloud_stub_hand_mesh.gd` = `class_name OpenXRFbHandTrackingMesh` / `extends MeshInstance3D` / `var hand := 0` / `var material: Material`.
   Then `godot --headless --import --path .` (also needed after adding any new `class_name` script).
   The messages "OpenXRFb... not declared", `scene_anchor.gd`, "Compile Error: Failed to compile depended scripts" are expected.
4. Tests: `godot --headless --xr-mode off --fixed-fps 60 --path . res://tests/run.tscn -- --profile=test --only=entry`
   (`--only=` matches a file name; about 4 minutes for `entry`; run it in the BACKGROUND with `nohup ... > log &` and poll with short sleeps).
   Other suites to keep green: `scene`, `tidy`, `world`, `speech`, `smoke`, `input`, `hand`, `reality`, `session`, `modules`.
5. Pictures: `xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . res://tools/entry_shots2.tscn -- --profile=test_capture`.
   Tilt the head down (`App.rig.head.rotation.x = -0.55`) to see the table. Look at them before reporting.

## Delivering to Megan (no working-tree changes)

1. Cloud: `git commit`, then `git bundle create out.bundle <base>..HEAD` (put it in `/mnt/user-data/outputs/`).
2. `device_commit_files` it to `~/quest-cv/ARVision/tools/.<name>.bundle`. **Check its size on her Mac against the cloud file:
   the first write of a re-used file name can be stale; write again if the sizes differ.**
3. On her Mac: `git fetch tools/.<name>.bundle HEAD:refs/heads/<your-branch>` (updates a ref only), then delete the bundle.
   Never `git checkout` or merge in her working tree. Her Godot is open and she tests with `git checkout <branch>`.
4. Git on her Mac leaves `.git/objects/maintenance.lock` and `.git/HEAD.lock` behind ("Operation not permitted"):
   remove them (after she has approved file deletion for the folder once per session) or `mv` them aside, never `.git/index.lock` if git is running.

## Quirks that cost time

* `device_commit_files` of the SAME file name twice in a row: the second can write stale content. Always compare hashes/sizes.
* Parts of the opening are cancellable: every wait in a part must go through `_runner` (`_wait`, `_move`, `say`,
  `_runner.create_tween()`, `_runner.tick`, `_runner.cauldron_touched`). A bare `get_tree().create_timer` or
  `create_tween()` in a part keeps running after a jump button cuts in. Things a part leaves lying around should join the
  group `entry_transient`.
* A line spoken with `say()` waits for the Voice module's `line_finished`. A line with no baked clip warns and ends after
  its subtitle time. New lines are baked when Megan opens the project in Godot (`Speech: ready` in the editor) and the new
  `content/voice/generated/*.ogg` + `index.json` changes must be committed.
* Input without a headset: mouse = right hand, left-click = pinch, wheel = hand distance, W/A/S/D/Q/E move the head, arrow keys
  look, R resets; `Entry.poke_in_sim` (tests set it) lets a fingertip press things in the sim.
* Be short with Megan: she is often tired, a visual learner, and wants pictures and plain words. Never make her wait on a
  long silent step: say what you are doing and roughly how long.
