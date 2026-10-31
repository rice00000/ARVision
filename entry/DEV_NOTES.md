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
| `entry/layout.gd` (`EntryLayout`) | WHERE everything stands: the zone map, the overlap checker, the dev and setup panel spots, the ? ! mark constants (layout chat) |
| `entry/zone_overlay.gd` | DEV "Zones" button: the zone map drawn on the table, overlaps in red |
| `tests/entry_layout_test.gd` | the layout's tests (9): 42 table/reach cases, the checker, the panels, the marks, the opening in the scene |
| `tools/entry_layout_shots.gd` | layout pictures from a seated child's eyes (`-- --prefix=x --zones`) |

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

* Lines changed: "Nearly ready." (the later UPDATE shortened it again; the pause, sheepish glance and half-lean carry the hesitation); after seating "Ah. There we go." (do NOT say the room is waking up);
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

## Interaction chat changes, round 3 (branch `entry-interaction-3`)
* `Carry.reset()` now cancels a running align or settle and forgets everything, with no signal and no click (before, a jump button pressed while carrying left a settle tween fighting the story's own gear placement). `stop()` is unchanged (lets go and settles).
* `Carry.begin()` called again for the SAME gear while it is held, aligning or docked forgets nothing (only `reset()` forgets); for a fresh start it works as before. New `Carry.follow(cauldron, panel)`: the settle spot and the docked gear's facing use where they stand NOW (they move at the reveal). Far throws float back more slowly (up to 1.6 s). Nonsense poses and a freed gear are ignored.
* `DemoHand`: asking again for the gesture already showing (same gesture, same target) is a no-op, so the story's hand and the reminder never make it blink. `pinch_lift(thing)` works for any thing and stays within about 13 cm of it, never going to a place.
* Hook in `entry.gd` (story's `_child_sets_in`, first lines): `if USE_REAL_CARRY and _carry.has_docked(): return`. Without it a child who sets the gear in while Onion is still talking leaves the story waiting for a `docked` that already happened. Also `_carry.follow(_box, _mechanism)` in `_configure_interaction()`. The reminder delay is one constant, `Entry.PICKUP_REMINDER_SECONDS` (0 = never).

## PROPOSAL (not built): sharing `Carry` with Wei's tidy trial. For Megan's approval; nothing of Wei's changes before that
**Today there are two pinch-and-carry implementations.** Wei's (`trials/tidy/tidy_trial.gd`, about 100 of its 644 lines: `_on_button`, `_take`, `_physics_process`, `_return`, `_let_go`, `_on_tracking`, `_notification`) and mine (`entry/carry.gd`).

| | Wei's tidy trial | `Carry` (the gear) |
|---|---|---|
| Things / hands | many things, one per hand, two hands at once | one gear, either hand, the first to pinch holds it |
| Grab | pinch within `size*0.7 + 0.02` of a thing's centre (about 4 to 8 cm), nearest wins | pinch within 9 cm of the gear's middle |
| Follow | the thing is set to the hand's pose each physics frame, offset kept, no smoothing | the same offset, a little smoothing, never through the table |
| Release | 0.12 s debounce, then within 5 cm of a sticker: judged (right clicks in, wrong goes home, a try is counted); else home in 0.25 s | within a generous volume of the socket: auto-aligns, one click, never judged; else floats to the nearest free table spot within reach |
| Tracking lost / pause | the thing goes home at once | 0.25 s grace, then settled quietly |
| Data | reports `taken` and `put` with timings; the sim reads `layout()` (`carried`) | signals only |

**What sharing would look like (recommended shape, staged).** One small node, `Carrier`, that owns only the mechanics: pick-up by pinch distance, the contact offset, following, the release debounce, tracking loss and pause. Everything that differs is a callback: `grab_radius(thing)`, `on_release(thing, point)` (Wei: judge and put or return home; gear: dock or settle) and `on_lost(thing)` (Wei: home; gear: settle). `Carry` becomes a thin layer on it; the tidy trial keeps `_put`, hints, layout and scoring and gives up its ~100 mechanics lines.
* Stage 1 (no Wei files): build `Carrier` with tests, move `Carry` onto it, same behaviour.
* Stage 2 (needs approval, Wei's file): the tidy trial adopts it behind a flag, default OFF, so his original runs unchanged; run `tidy`, `world`, `scene` and the python sim (`tests/sim/test_tidy.py`) both ways.
* Stage 3 (after a look by Megan and Wei): flip the default, or leave the flag.

**What it would change for the child:** the same grab and release feel for the gear and for the shelf things (they learn it once; the teaching hand means the same everywhere), shelf things could not be pushed through the table, a tracking blink under 0.25 s would not send a thing home. Wei's debounce, snap, per-thing grab size and home-return stay as they are.

**Risks.** (1) The tidy trial is measurement code: grab radius, smoothing or release delay change what is measured; any difference must be switchable and noted in the data's version, and compared in the sim before and after. (2) Wei's files move: a change there conflicts with whatever he edits. (3) Making one node handle many things and two hands adds complexity to the gear's now well-tested behaviour; tests must stay green on both. (4) The python sim and `layout()` read Wei's private `_carried`; they would need the same data from `Carrier`. (5) Tracking loss means different things on purpose (home vs settle): it must stay a callback. (6) About a day of work with tests; no new assets or licences.

**The alternative:** leave them separate and only line up the numbers in a table (as above): no risk, two slightly different feels. **My recommendation:** Stage 1 only after the first test with a real child, since it is invisible to them and safe; Stage 2 only if testing shows the two feels confuse a child. **Decision wanted from Megan:** none yet; say "go" for Stage 1 or "leave it".
## Layout chat (C), round 2 (Oct 31): `entry-layout-2`

**Merge check.** `_make_way()` and `EntryLayout.dev_spot` came through right. One fix: `_set_up_for` now treats
`pickup` and `place` as opening parts too (`_make_way(0.0, part in [hello, touch, emerge, pickup, place])`); before,
jumping to them put the cauldron and the panel at their after-the-reveal spots (the panel behind the shelf).

**DEV buttons.** The jumps are two columns of four, in story order (Hello, Tap, Gear, Pick up | Set in, Reveal, Shelf,
Dots), the pop A/C button under them; Restart / Exit app / Zones on the right. Both 63 degrees off straight ahead, 50 cm
out, their middle 10 cm above the eyes: outside the child's 110-degree view, above the table and the hands, under 65 cm
from the eyes (a seated adult reaches them). All positions come from `EntryLayout.dev_jump_spot / dev_pop_spot /
dev_right_spot / dev_jump_label`; the test checks every button is in reach and none overlaps another.

**Zone map.** Covers setup, the opening, the reveal and the shelf scene / first_visit (the bench, shelf and things stay
where the reveal showed them: `ShelfCopy.push` and the moved table point). Clean for every table at least 1.0 x 0.7 m
whose near edge is at least 15 cm inside the reach (42 cases in the test). Reported, not fixable by placement: a
0.8 x 0.5 desk (Wei's 54 cm bench covers it), and a table starting near the end of the reach. The setup's table step
says "Small: N things overlap" / "Far: hard to reach" from the same map. Changes: a short reach can put the cauldron
just beyond the reach (its near rim stays in reach for the tap) so the gear lands in front of it; the landing spot is
searched over the whole table strip (it could land off the table's near edge before); the shelf's push is at least
10 cm (`EntryLayout.PUSH_MIN`: at 0 Wei's things lay 16 cm from the eyes and 113 degrees wide).

**The ? and ! marks** (`EntryLayout.MARK_*`, read by `onion_actions.gd`): 6 degrees tall from the child's eyes at any
distance (about 5 cm at 50 cm), 3.5 cm above Onion's top, outline 22% of the font size, about 1.6 s in all. Default
style is now 1 = cream with a DARK sage outline (0.2, 0.32, 0.22): 7.7:1 between fill and outline, about 7:1 against a
white wall and 9:1 against a dark room. Style 0 (sage with a cream outline) is 2.7:1, and its cream outline disappears
against a bright wall (1.1:1). `mark_style` still switches them.

**Seated reach** (`EntryLayout`, a 1.0 x 0.6 m table, near edge 30 cm from the eyes; cm, flat distance from the eyes
unless marked 3D):

| eye height | table | eyes above table | reach | cauldron mouth (3D) | gear landing (middle) | socket | socket to table edge | shelf near edge | cubbies | Wei's bench above the real table | problems |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 100 | 55 | 45 | 45 | 62 | 51 (near edge 43) | 44 | 14 | 21 | 46 | 3 | none |
| 100 | 55 | 45 | 55 | 57 | 51 | 44 | 13 | 21 | 46 | 3 | none |
| 115 | 62 | 53 | 45 | 66 | 51 | 44 | 14 | 21 | 46 | 11 | none |
| 115 | 62 | 53 | 55 | 62 | 51 | 44 | 13 | 21 | 46 | 11 | none |
| 130 | 72 | 58 | 45 | 69 | 51 | 44 | 14 | 21 | 46 | 16 | none |
| 130 | 72 | 58 | 55 | 66 | 51 | 44 | 13 | 21 | 46 | 16 | none |
| 130 | 62 | 68 | 55 | 73 | 51 | 44 | 13 | 21 | 46 | **26** | none |
| 100 | 72 | 28 | 55 | 49 | 51 | 44 | 13 | 21 | 46 | 0 | the shelf top rises above the eyes; it covers the dev/setup panels in view |

For Wei / the organizer: his bench stays 28-42 cm below the eyes whatever the table (`BENCH_HIGHEST/LOWEST` in
`tidy_trial.gd`), so for a child sitting high at a low table it floats 11-26 cm above the real table, while the cauldron
and the panel stand on the table. Clamping it to the real top (when one is confirmed) would fix it; his file, his call.
The "shelf near edge" (21 cm) is the bench's front; Wei's nearest things lie about 19-20 cm from the eyes.

**Sounds** (suggestions; the headset check is Megan's). Measured loudness (EBU R128): the voice clips -22.6 to -17.1
LUFS (median -19.4); piano -18.4; pre-rattle -31.1; device rattle -38.6 (a very quiet file); pop A -16.0; pop C -14.1;
reveal -17.7; the seat click is 0.19 s, RMS -17.5 dB, true peak +2.4 dBFS (it clips). `AudioStreamPlayer3D` with
`unit_size = 3.0` adds the full `max_db` (+3 dB) to everything nearer than 3 m, so each sound plays 3 dB over its
LEVEL, and the A/C pops differ by 1.9 dB. Suggested, for the voice clearly on top (sounds 9-13 dB under it, music 14):

```gdscript
# in Sounds.play: no near-field boost; it falls off naturally beyond 1 m
player.unit_size = 1.0
player.max_db = 0.0
const LEVEL := {pre_rattle = -1.0, device_rattle = 8.0, seat = -16.0, pop_a = -13.0, pop_c = -15.0, reveal = -12.0}
# entry.gd: MUSIC_DB := -15.0
```
(device_rattle +8 dB because the file is so quiet: better to normalise the file to about -24 LUFS and use -5.) Where
they play from is right: the rattles at the cauldron (could be its mouth, `_mouth`, a few cm up), the pop at the peek
spot, the click at the socket, the reveal pad at the socket (where the ripple starts). The voice is not positional
(Wei's Voice module): Onion speaks from the middle of the head, not from where it floats. A positional voice
(`AudioStreamPlayer3D` on Onion) would help a child find Onion by ear: Wei's module, a proposal.

**Setup panel** for a grown-up new to it: "Step 2 of 4" in the bar (the step dots read left to right, the current one
bigger); every check line says its state without colour: a tick and dimmed when done, "!" when worth a look; the first
line still waiting stays bright with its dot breathing (what to do now); a line at the foot: "To press: touch a button
with a fingertip, or point at it and pinch." The panel stands 12 cm above the eyes so its buttons stay above the shelf
in view.

**Not done** (next): the UI audit and proposals for Wei's World (task menu, level announcements, subtitles: when
the child looks at the things, the subtitle (25 degrees over the gaze) lies on the shelf's top row by 4.5 degrees; 36 degrees (`Voice.above_gaze`)
would clear it).

## Interaction chat, round 4: the real teaching hand (branch `entry-interaction-4`)
* `DemoHand` now shows the MRTK right hand (`entry/assets/hand/`, MIT notice kept; `USE_GLB_HAND := true`). If the file is missing or is not a hand, the primitive stand-in is built instead (same calls, same behaviour). API unchanged: `tap`, `pinch_lift`, `lower_release`, `stop`.
* The clips are scrubbed, never played: the keyframe table's `open` 1.0 -> `pinch` at 0, 0.0 -> 1.0 (tips meet at the origin); the tap scrubs `tap` along `TAP_DOWN`/`TAP_UP`/`TAP_BACK`. `idle` is set to loop in code (the import gives no loop flag). A tap points: the three other fingers are folded (their closed-pinch pose) and the hand is placed so the INDEX FINGERTIP lands on the rim.
* The material is ours (`material_override`: cream 0.96/0.90/0.80, alpha 0.4, glow 0.35, no shadows), so the fade works whatever the file brings. After `stop()` and the fade the whole hand is freed (no node left); it is built again on the next gesture.
* Constants Megan may tune in the headset, all at the top of `demo_hand.gd`: `HAND_SCALE` (0.6; the file is 23 cm wrist to fingertip), `HAND_FIX_YAW` (PI: the file's fingers point +Z, ours -Z), `HAND_FIX_TRIM` (-0.72, straightens the file's diagonal hand), `HAND_ROLL` (-0.6, so the gap between thumb and index shows from a seat looking down; the pinch point does not move), `YAW` (1.3: the hand comes in from the right, fingers pointing left, so a child sees it from the side).
* Pictures: `tools/entry_shots_interaction.gd` (frames of each gesture in the opening, seat and side) and `tools/hand_closeups.gd` (the hand alone against a table colour with a marker at the pinch point and the finger joints printed).
## Layout chat (C), round 3 (Oct 31): `entry-layout-3`

**Headset test sheet:** `entry/HEADSET_TEST.md`, one section per beat (Setup, Hello, Tap, Gear, Pick up, Set in, Reveal,
First visit): what to see and hear in the story's words as built now, what to judge or measure, tick boxes; ⚠ marks
what is not built yet (the real teaching hand, the knock sound, the lead-in line, the workshop's real assets).

**Gear landing (fix).** Since the round-2 landing search, on the sim table the gear could hop from the cauldron right
over the panel and land on its far side (in "Pick up" it sat far right, beyond the socket). Now its hop must not cross
the panel and stays short (23-30 cm on the usual tables); the panel search keeps room for the landing on the
cauldron's side. Only when very little table is in reach (reach 45-50 cm, table starting 30 cm out) does it still hop
over the panel, as a last resort; the layout line in Output then says "(it hops over the panel: little table in reach)"
(`EntryLayout.hops_over_panel()`). The plan takes about 0.3 s once, after setup.

**Subtitles: proposal for Wei's `Voice` (not edited).** Today `above_gaze = 25`, `above_horizon = 20`. Looking at the
things on the bench, the line lies across the shelf's TOP row of cubbies (about 4.5 degrees; the bottom row and the
things stay clear). Proposed: **`above_gaze = 36`, `above_horizon = 12`.** Then, looking at the things, the line is above
the whole shelf (usual and long reach); looking at Onion beside the shelf it sits above Onion, about 10 degrees over the
horizon instead of up to 19 (no looking up). At a short reach (shelf 10 cm back, so near and tall in view) it can
still touch the top row; never the first row. Pictures: `tools/round3_shots.gd -- --part=sub` (build/round3/sub_*).
Also worth Wei's look: the line is 48 px x 0.0006 = about 2.9 cm tall at 75 cm (2.2 degrees): small for a child who
sees poorly; 64 px would be about 3 degrees.

**Teaching hand size.** right_hand_demo.glb is not in the repo or on the Mac yet, so this was measured with the
stand-in hand scaled to the real one's length (23 cm x scale), from a seated child's eyes, over 3 s of each loop; the
share of the target the hand hides (most / average):

| scale (length) | tap: cauldron rim | pinch: gear | set in: socket |
|---|---|---|---|
| 0.4 (9 cm) | 27% / 5% | 8% / 4% | 27% / 13% |
| 0.5 (12 cm) | 29% / 9% | 20% / 9% | 29% / 13% |
| 0.6 (14 cm) | 35% / 11% | 29% / 9% | not measured |

At 0.6 it never hides more than about a third of a target, and only for a moment (it is also see-through, alpha 0.4).
Best for a 0.4-0.6 m view: **0.5 to 0.55** (11.5-12.5 cm, a young child's hand length): the gear stays clearly visible
while pinched (at most 20%), and the hand still reads as a hand at 50 cm (about 14 degrees). 0.6 is acceptable. The
real hand has all five fingers, so it may hide a little more: rerun `tools/round3_shots.gd` with it (set
`STANDIN_LENGTH` to its own pinch-to-wrist length). Note for chat A: jumping straight to "Set in" without holding the
gear, after 14 s the reminder replaces the lower-and-open hand with the pinch on the gear (fine for the story; confusing
in a jump test).

**DEV panels:** Dots and Pop sound A/C sit clear (two columns of four, the pop button under them, 63 degrees left);
`test_the_opening_puts_things_where_the_map_says...` checks every DEV button is in reach and none overlaps another.

Tests: 73 of the opening's (entry*) pass on this branch.

## PROPOSAL (not built): the shelf reminder, brief step 13. For Megan's approval; nothing of Wei's changes
**A finding first.** Wei's own help starts the clock when the round starts (`hint_after` is 10 s in `tidy.tres`, plus 1 s per round) and its first level shows the answer: the first thing not yet in hops AND its sticker wiggles (that is the right cubby); the second level makes the cubby shine and the guide says so. In the first visit the round starts while Onion is still speaking its two lines (about 7 s), so a child gets about **3 seconds** after "Can you find a place for one of these?" before the answer is shown. A grab-only reminder has no room in that gap as it is.

**What the reminder would be.** A new node `entry/shelf_reminder.gd` (mine), added by `first_visit.gd` with one line once Onion has said its second line (`add_child(ShelfReminder.new())`; the story chat's file). After `ShelfReminder.DELAY` seconds (one constant, 12.0; 0 = never) it shows `DemoHand.pinch_lift(thing)` on ONE thing: the unplaced thing nearest the child's eyes, read from Wei's public `layout()` (never his "first thing" order, which is the order of his hints). The hand pinches it, lifts it at most 5 cm and lowers it, and loops until the child takes something. It never moves toward a cubby (a test would check what the existing `pinch_lift` test checks: within 13 cm of the thing, never near any cubby or sticker). It does not touch Wei's things, stickers or hints: it only reads `layout()` and Wei's `taken` / `put` reports.

**It is skipped, or stops, when:** any thing is already carried (`layout().things[].carried`); any `taken` or `put` report since the line (the child has shown they can); Wei's hint level is above 0 (his hop is already running: two things would hop); the round ends or the scene is left.

**Fixing the timing (three ways).** (a) *Recommended:* the first-visit plan uses a copy of Wei's tidy trial definition with `hint_after = 30`: a sub-resource in `entry/first_visit_plan.tres` (the story chat's file) with one number changed, so Wei's `tidy.tres` and code stay as they are; the reminder then comes about 19 s into the round and Wei's own help at 30 s. (b) Leave his 10 s and do without the reminder. (c) A reminder about 2 s after the question: too early to mean anything.

**Risks.** The plan's copy of the definition could drift from `tidy.tres` if Wei edits it; the delay needs tuning with a real child; the hand always comes in from the right, so a thing at the far left edge is reached across the table (we could mirror it for that case later). **Decision wanted from Megan:** approve (a), or choose (b).

## Interaction chat, round 5 (branch `entry-interaction-5`)
**Hooks in `entry.gd` (for the build chat to know about).** (1) In my `# --- Interaction` region (`_configure_interaction`): `Events.selected.connect(_on_desktop_click)`, `_carry.picked_up.connect(_glow_gear.bind(false))`, `_carry.was_reset.connect(...)` (glow off, teaching hand stopped); new function `_on_desktop_click`. (2) `_pickup()`, first lines: `if USE_REAL_CARRY and not _carry.enabled: _carry.begin(...)`, so a jump straight to the beat lets the child grab during the ask, as in the full flow. (3) `_place()`: the same two lines, and `lower_release` + the instruction + `_child_sets_in()` are skipped when `_carry.has_docked()` (the child set it in while Onion was still talking; before, Onion asked for something already done). New in Carry: signal `was_reset` (emitted by `reset()`, nothing else comes with it).
**Fixed.** *The flaky mouse click on the cauldron (desktop):* the mouse hand sits at a depth the wheel and W/S change; once it is farther out than the cauldron its own ray starts beyond it and points away, so the click found nothing (it worked at hand depths up to 0.45 m and failed from 0.6 m out). A click whose line passes through the cauldron's tap sphere now counts, at any depth, on desktop only; a click well beside it does nothing. *A jump button left the pick-up glow on the gear and the teaching hand showing:* `reset()` now clears both (and the glow goes the moment the gear is grabbed, not when Onion's line ends). *The tap demo:* the index bends 1.8 times as far as the clip alone, a soft ring spreads from the rim at the contact, the hand rests on the rim a little longer; the loop is still 3.0 s, so `_tap_cycle`'s `wait(6.0)` is still two loops.
**Reviewed by simulation (all in `tests/entry_interaction_test.gd`):** grabbing during the ask; a jump button with the glow showing and mid-carry (the grown-up presses with the other hand); setting the gear in before Onion finishes (neither beat waits, the instruction is not spoken); tracking lost mid-carry in the set-in beat (set down, the beat keeps waiting, a new pinch finishes it); gear let go around the panel edge (5 directions) and over the cauldron mouth and rim, in the opening layout and after the reveal's make-way: it never lands on the panel or in the cauldron; both hands in the first visit's shelf (Wei's carry: each hand its own thing, losing one hand returns only its thing, unscored). Not a problem found in Wei's carry. Left as it is (story chat's words): with an early dock, "There you go." and "Quite a little thing, isn't it?" are still said later, and the seat click sounds at the end of the set-in beat.
**The real hand with Onion (`tools/hand_with_onion.gd`, numbers in `build/onion_hand/overlap.txt`):** *Tap:* Onion stands against the cauldron's left rim (-0.27, 0.89, -0.37) and at the press (0.8 s into the loop) the hand's joints are 1.1 cm INSIDE Onion's box (4 px inside its screen outline, seat view): in the pictures the bodies do not overlap but touch distance; **layout chat: move Onion's tap spot about 3 to 4 cm farther from the mouth, away from the hand** (`_beside_mouth()` uses 0.07 m sideways; about 0.11 m would clear it). *Pinch:* Onion at (-0.47, 0.94, -0.43), 42 cm from the hand: clear; but the gear's rest spot is low in the desktop seat view (the hand is near the bottom edge). *Set in:* the hand over the socket, Onion 43 cm away at the cauldron's left: clear (Onion is not "beside the socket" now but beside the cauldron).
