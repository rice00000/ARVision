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

## Three chats, one seam

* **Interaction chat (A)** owns `carry.gd`, `demo_hand.gd` and `tests/entry_interaction_test.gd`. In `entry.gd` it may touch
  ONLY `_build_gear()` (to configure `_carry` / `_demo`) and add a region `# --- Interaction`.
* **Story chat (B)** owns the beats and Onion: `_hello`, `_touch`, `_out`, `_reveal`, `_play`, `_set_up_for`, `PARTS`, every
  `say()` line, `entry/onion_actions.gd` (new), `entry/sounds.gd` (new), the ? and ! marks, the ripple's look and sound,
  `tests/entry_story_test.gd`. It calls A's API (stubs until real).
* **Layout and UI chat (C)** owns WHERE things stand and how the UI looks: a new `entry/layout.gd` (the zone map), the placement
  code in `entry.gd` (constants `CAULDRON_*`, `SHELF_*`, `PANEL*`, `SOCKET_*`, `GEAR_*SCALE`, and `_cauldron_on_table`,
  `_cauldron_spot`, `_shelf_to_the_side`, `_clearance`, `_mechanism_spot`, `_slot_clearance`, `_aside_spot`, `_beside_shelf`,
  `_gear_rest`), the setup panel and dev buttons (`setup_panel.gd`, `entry_button.gd`, `_step_*`, `_debug_buttons`, `_dev_jumps`),
  `tests/entry_layout_test.gd`. For Wei's World UI (the task menu, level announcements, guide, subtitles in `world/` and
  `modules/`) C produces PROPOSALS with pictures first and edits only what Megan approves, on its own branch: Wei's files move.
* Everyone: do not rewrite `tests/entry_test.gd`; fix it only where your change breaks it. Each chat works on its own branch from the
  same base (`entry-interaction`, `entry-story`, `entry-layout`) and **never touches Megan's working tree**: deliver by fetching a
  bundle into a branch ref (below). Megan tests with `git checkout <branch>`; one integrator merges.

### The API the chats agree on

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

# DemoHand (child of Entry as `_demo`)  each shows ONE gesture, looping, until stop(); it never carries the gear
func tap(at: Vector3) -> void
func pinch_lift(gear: Node3D) -> void
func lower_release(socket_at: Vector3) -> void
func stop() -> void
```
Change this API only by telling the other chats: add a line to "API changes" below.

API changes: Carry gained (nothing removed): `configure(floor_y, eyes, reach, yaw, keep_clear_at, keep_clear_radius)` (Entry calls it from `_configure_interaction()`), `has_been_picked_up()`, `has_docked()`, static `Carry.middle_of(gear)`. `begin()` resets the memory, so a jump button can replay the part. DemoHand calls return at once (nothing to await); the hand shows until `stop()`. Carry also has `remind_after` and the signal `reminder_due` (once per `begin()`, when the gear has been in view and untouched that long); Entry's `# --- Interaction` region sets 14 s and, by default, shows `_demo.pinch_lift(_gear)` then and hides the hand on `picked_up` / `docked`, so the story chat need not do it (it may still show the hand itself). DEBUG key **G** (`Entry._try_carry()`): puts the gear out on the table and turns Carry on, for trying pick-up, carry and set-in with the mouse hand (left-click-hold, drag, let go; wheel = distance); it turns the gear when it docks. NOTE for chat C: `Entry._mouse_driver()` looks among Entry's siblings but the `DesktopDriver` is a child of Main, so it returns null (`_look`, `_hand_to_cursor` do nothing); `_desktop_driver()` in the Interaction region finds it. After `docked` the gear stays in the socket (Carry no longer picks it up); `released(false)` is emitted at the moment of release, `released(true)` together with `docked`.

## Decisions from the story chat's final UPDATE (BUILD_CHAT_UPDATE_2026-10-31.md, last section; it supersedes earlier lines)

* Lines changed: "Uh... nearly ready." (not "Nearly ready."); after seating "Ah. There we go." (do NOT say the room is waking up);
  after the reveal "I've been looking forward to showing you this."; then, after a pause to enjoy the room: "Oh!" / "Things come
  through, but they don't always land in the right place." / "Would you help me put them where they belong?"; the first shelf round:
  "The shapes on the shelf show where things go." / "Can you find a place for one of these?"; the first placement only: "It fits.
  Let's find places for the others." then quiet. The lead-in to placement ("Let's see if we can wake this place up") is NOT approved:
  leave that beat unspoken. A tiny sheepish laugh is only an audition idea.
* Picking the gear up IS the child accepting to help: no yes button, no speech recognition. A delayed grab-hand reminder is allowed
  (configurable inactivity delay) but must never carry the object to the right answer; skip it if the child already holds one.
* Sounds (SELECTED, not downloaded or edited yet; put the files in `entry/assets/audio/` with the original names and keep licence notes):
  cauldron movement before Onion: "Dinner Plate Impact with Vibration" (OwlStorm, CC0); the gear's entrance: "Door Rattle" (SumiXIV, CC0);
  seating click: "Ceramic Click" (Mafon2, CC0), once, after release and successful seating, never on hover; reveal: "Floating Pad Magic"
  (humordome, Pixabay licence), gentle onset and fade. Onion's pop: keep BOTH for an in-scene A/B audition, no layering, same timing and
  comparable loudness, played as Onion clears the rim and finished before the greeting: A "Gentle Air Bubble Burst" (humordome), C "Light
  Bubble Pop" (Virtual_Vibes), both Pixabay licence. Do not reopen "Pop or Bloop". Keep the intro piano; no persistent loops under tasks.
* Marks: bold solid ? and ! silhouettes, sage with a cream outline AND cream with a sage outline (choose by readability in the scene);
  brief, no flashing or particles, never a target. ? when Onion asks for help at the cauldron, ! at the surprised hop as the gear pops out.
  The final graphics are pending: use a bold Label3D stand-in with both colourings switchable.
* The demonstration hand: the Hand Coach GLBs are rigged but NOT animated: until clips are authored, a primitive stand-in hand.
* First-visit shelf flow (the World's second alchemist welcome, task menu, level announcement, long block intro) conflicts with a seamless
  Onion-led visit. NOT to implement now: only proposals (chat C), never a silent global change to the menu behaviour. After the first shelf
  level a new activity may be introduced by a cauldron/room event: not ready, do not build it.

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

## Story chat changes after the merge (Oct 31)
* `first_visit` scene (`scenes/first_visit.tscn`, `entry/first_visit.gd`, plan `entry/first_visit_plan.tres`): the opening hands over to it instead of Wei's World; Wei's `Session.play` runs his level-1 plan unchanged. Edits to Wei's files: one scene line + one branch in `main.gd`; `static var onion_voice` and three `if not onion_voice:` guards in `tidy_trial.gd` (silences his instruction, "It fits!" and "All tidy!" only while Onion leads; wrong-match and hint lines stay).
* `Carry.reset()` added (forgets picked-up/docked for the jump buttons). `USE_REAL_CARRY := true`; `Entry.simulate_child` lets tests pretend the child.
* `Sounds` (`entry/sounds.gd`): pre-rattle, pop A/C (DEV button "Pop sound"), device rattle, seat click (once, on completed seating), reveal pad faded after ~3 s. Files in `entry/assets/audio/` (kept out of the commit: they were added by the sourcing chat).
* `Workshop.attend()` / `cheer()`; Onion stays through the first visit; it leaves with the next scene.
