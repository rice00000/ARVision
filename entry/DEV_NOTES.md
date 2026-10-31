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

## Layout chat (C), round 4 (Oct 31): `entry-layout-4`

**Onion's spots in the zone map** (`EntryLayout`; zones `onion_mouth`, `onion_aside`, `onion_lifted`, `onion_aside_after`,
`onion_lifted_after`, and the teaching hand's sweeps `hand_tap`, `hand_pinch`, `hand_place`, plus a `socket` ring zone):
* The hand's sweep is MEASURED, not guessed: in the scene, over a whole loop of each gesture, from the real hand's
  skeleton (bone positions), relative to the point it works on (rim point, gear middle, socket), at `DemoHand.HAND_SCALE`
  0.6 (it scales with that constant): the tap reaches 0..14 cm to the child's right, 10 cm toward them and 3 cm away, up to
  23 cm high; the pinch 1 cm left to 17 cm right, 8 cm toward and 9 cm away; the lowering 1..15 cm right, 7 cm toward, 9 cm
  away. The index fingertip is the anchor, so the hand's body always lies to the child's RIGHT. 1.2 cm of flesh is added.
* Onion's body (6.3 x 6.7 cm, 11 cm tall, measured) must keep 1 cm from that box (`HAND_CLEAR`) while the gesture shows.
  Result on every table 1.0 x 0.7 m and larger, near edge 30-40 cm out, eyes 45-55 cm above, reach 0 / 50 / 60 / 72 cm (42
  cases, in `tests/entry_layout_test.gd`): no overlap of Onion with the hand, the socket ring, the panel, the gear's landing
  spot, the bench, shelf or things. Beside the mouth Onion is 7 cm out (the story chat's offset kept: 3.5 cm to the left, 6 cm
  toward the child) and 1.3 cm clear of the tap hand. `Entry._beside_mouth()` now reads `EntryLayout.onion_mouth_offset` (same
  value on the usual tables; the layout would move it if a table ever made the hand touch Onion).
* **Fixed: Onion did not follow the cauldron at the reveal.** After the seating Onion rises to `aside + 10 cm`, but
  `_make_way()` only took Onion along if it was AT the aside spot (within 5 cm), so Onion stayed hovering over the old place
  while the cauldron glided aside. `_make_way()` now takes it along from either spot; the lifted spots are
  `EntryLayout.onion_lifted` (opening) and `onion_lifted_after` (after the cauldron moved), read by the new `Entry._lifted_spot()`
  (used after the seating and by the `reveal`/`shelf` jumps).
* **To decide (story chat / Megan): Set in is not "beside the socket".** `_place()` sends Onion to `_aside_spot()`: beside the
  CAULDRON, the side away from the panel and the gear's landing spot, about 45 cm from the socket on the usual table (see
  `build/round4/hand_place_1.png`). The brief says beside the socket. A spot there would have to be BEHIND the panel (the
  landing spot is on the cauldron side and the teaching hand's body on the right), about 17 cm beyond its far edge, 10 cm up;
  from a seat it would look just above the socket. It is not built: it also makes the reveal glide Onion some 40 cm. One line
  to try it: a `onion_by_socket` spot in the layout and `_move(_orb, _beside_socket(), 0.8)` in `_place()`.
* DEV columns now 70 degrees out (63 before): with Onion lifted in view at about 45 degrees the old 63 overlapped a corner
  of the jump column by up to 3 degrees. Still 50 cm from the eyes, in a seated grown-up's reach.
* `POP_AUDITION := false` hides the pop button; the jump column is then two columns of four with room under it. Checked:
  every jump button, Dots included, and Zones / Restart / Exit are in reach (<65 cm) and none overlaps another
  (`test_the_opening_puts_things_where_the_map_says...`).
* Pictures (`tools/round4_shots.gd`, `-- --profile=test_capture` for the hands, `--part=visit` for the first visit):
  `build/round4/hand_tap_*.png`, `hand_pinch_*.png`, `hand_place_*.png`; none shows Onion touching the hand.

**First visit, seated** (`build/round4/visit_*`, Onion at rest beside the shelf, cauldron hidden): Onion stays clear of the
shelf and of its first row (it floats just left of the shelf's top corner, never in front of a cubby), and the cauldron is
gone, so the bench has the table's middle. The subtitle at Wei's `above_gaze` 25 / `above_horizon` 20 still lies across the
shelf's top row while the child looks at the things; at 36 / 12 it is above the whole shelf, and above Onion when the child
looks at it. Still only a PROPOSAL for Wei's `Voice`. One thing seen: the moved-aside panel (turning, still there) is
partly hidden behind the shelf and a thing from a seat; it is only looked at, not used.

### PROPOSAL (not built): a ripple that travels ALONG the room and its things

Today (`Entry._ripple()`): three flat rings (torus, 4 mm over the table's height) leave the socket and grow to about 1.7 m
in 5 s (ease-out), a second apart; `_spread()` shows each workshop detail when the ring reaches it, and puts a faint 12 cm
soft disc ("glint") on each of up to 105 depth-ray hits (the sim finds about 75 of them; the headset only what the depth
sees, about 100 degrees ahead). The reveal pad plays 3 s; `_ripple()` returns after about 7 s, then Onion says "I've been
looking forward to showing you this." The rings are flat discs in the air at table height, so they pass THROUGH the
cauldron and the panel and over the table's edge as if the table were not there.

What "along the objects" needs: the front must be a function of the distance from the socket measured over the surfaces
(`distance(p, socket) <= r(t)`), drawn ON those surfaces. Everything below keeps the ring's timing (r(t) = 1.7 m x
(1 - (1 - t/4.5 s)^2), band 8-10 cm wide with smooth edges), alpha at most 0.3-0.35, nothing that flashes or moves the
view, and ends by 5.5 s, so the line can start at 6 s (1 s earlier than now) or stay at 7 s.

**Cheap version (about a day; no new assets; GPU cost negligible).**
1. One small spatial shader, `entry/ripple_front.gdshader` (about 40 lines): uniforms `origin`, `radius`, `band`, `tint`; the
   fragment's world position gives `d = distance(world_pos.xz, origin.xz)`; alpha = smoothstep band around `radius`, additive
   tint, unshaded. Put it as `material_overlay` on the meshes of the things the child sees (the cauldron `_box`, the panel
   `_mechanism`, the gear, Wei's shelf and bench as they grow in): the front visibly climbs over each object as it passes.
   The gear glow already uses `material_overlay`, so this is a known path. In the SIMULATED room the same overlay goes on the
   room's visible meshes (table top, sideboard, chair, walls: `living_room.tscn` is ordinary scenery), so the sim shows
   the front running over the table and up the walls instead of only rings.
2. The table: replace the flat torus by one quad exactly the table's size and pose (`App.reality.work_surface()`: found
   table in the headset, the sim's table in the sim), same shader, discarded outside the rectangle: the ring is cut off by
   the table's edge instead of hanging in the air. A thin lit strip along each table edge fades in where the front touches
   it, so the front seems to run along the edge.
3. Real objects (headset): keep the depth glints, but make each an elongated soft streak across the front (along its
   tangent) and time it to the front exactly (it is already). No new data.
Risks: low. Needs a headset look for band width and brightness against a bright table (cream tint on a dark wood table can
vanish; use a warm gold at alpha 0.3).

**Better version (2-3 days incl. headset tuning; about 0.1-0.2 ms GPU).**
1. Headset: draw the same shader on the Scene API anchors (`reality/scene_anchor.gd`: the room's planes and volumes the
   child scanned: floor, walls, ceiling, table, furniture), depth-tested against themselves, so the front runs over the
   floor, up the walls and across the table and furniture in their real places. The passthrough video cannot be recoloured; it is
   the virtual anchor meshes that glow, so it only works where the child's room scan exists. Without a scan: the cheap version.
2. Dense depth sparkle: take ONE snapshot of the live depth points (`DepthGrid`, `read_once()` at the start of the reveal;
   a few thousand points within 3 m), put them in a MultiMesh of soft quads (one draw call) with the same front shader; each
   point flares for about 1 s as the front passes. The room "draws itself in points of light" along its real surfaces and
   objects (a cup, a laptop, the child's own arms are in the depth too, so mask what is within 25 cm of the eyes). In the
   sim use a fan of about 1000 `Reality.hit()` rays (about 1 ms) instead of the 105.
3. Table edge and legs: outline from the table `Surface` (finder size and pose) as a line mesh lit only up to the front.
4. Onion looks along with it: the story chat's `_attend()` already follows one revealed feature; a moving look-at point on the front
   (the nearest lit point) would read as Onion watching the ripple travel.
Risks: scene anchors missing or noisy rooms (needs the fallback), depth noise creating flicker (smooth with a 0.3 s fade in
and out per point, never faster), perceived brightness on a bright wall (cap total lit area; test with the brightest room).
Rule for both: no step in screen brightness larger than 10% in 100 ms, nothing inside 25 cm of the eyes, no change to the
camera, the voice timing or the reveal pad.



Tests (round 4): all 206 pass on `entry-layout-4` (the base's 203 plus 3 new layout tests: Onion clear of the hand, the socket,
the panel and the landing spot on 42 table/reach cases; the checker catches Onion on the hand's path; the zone map has the new spots).
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

**Controls bug (Mac): clicking worked in the shelf but nothing could move or turn.** The keys that move and turn the head (W/A/S/D/Q/E, the arrows, R) were handled only by `Entry._move_head` in the opening's own per-frame code; when the opening handed over to the first visit that code was freed, so only right-drag was left, which is hard on a trackpad (on a Mac, Control + click-drag acts as a right-drag). New `entry/desktop_keys.gd` (`DesktopKeys`): the same keys, same speeds, a child of Main so it survives every scene change; it keeps out of the way while `current_scene == &"intro"` (Entry does it there, so nothing moves twice). Added from `_configure_interaction()` (my region), no Wei file touched. For the build chat: a session that starts straight in another scene (a plan, `find_object`) never runs the opening, so it never gets the node: one line next to `add_child(DesktopDriver.new())` in `main.gd` (`add_child(DesktopKeys.new())`, name it "DesktopKeys") would cover that; then Entry's copy can be deleted and the intro guard dropped.

## Layout chat (C), round 5 (Oct 31): `entry-layout-5`

**1. The panel and gear never move: only where the table has room (6 of 42 table cases).** The layout now plans the
panel TOGETHER with the shelf and the cauldron: for each shelf angle (0-30 degrees right) and each cauldron place it looks for a
panel spot clear of the bench, shelf, things, cauldron, the gear's landing spot and Onion's tap spot, with the socket in
easy reach; then it scores overlaps, things out of reach or view, and how far the shelf had to turn. `EntryLayout.panel_fixed`
says whether it found one. **On 36 of the 42 cases (every usual reach) it cannot, and the panel still glides at the reveal
(`_make_way`, as before).** Why: Wei's bench with its things is 54 cm wide and starts 33 cm from the eyes; with the cauldron
(22 cm) and the panel (27 cm) that is about 130 degrees of view at a 45-60 cm reach, in a 110-degree view. The fixed plan
exists where the reach is long (72 cm on 1.2 x 0.7 and 1.6 x 0.9 m tables): shelf turned 30 degrees right, cauldron on the
child's far left or right, panel 15-40 degrees left. Things that would make it work on usual reaches (decisions, not mine):
a narrower bench or things zone (`THINGS_WIDE` 0.48 is Wei's), a smaller panel (0.26 x 0.22 m), the cauldron standing in the
shelf's footprint for the ripple (see below), or letting the shelf stand 30-40 degrees to the side as the fixed plan does.
The check, the 3D overlaps, the sim pictures and the headset sheet say which plan a table got (the Output line ends with
`[panel stays put]` or `[panel glides at the reveal: no clear fixed spot on this table]`).
* The cauldron may stand where the bench grows in (it is gone anyway). `EntryLayout.ripple_overlaps()` lists that. Where it
  is not empty `_reveal()` now sinks the cauldron as the ripple STARTS (a second before the first ring reaches the bench),
  otherwise right after the ripple as before (`_cauldron_gone` makes the second call a no-op).
* The shelf may stand up to 30 degrees to the side. Bench, shelf, things and Onion's rest are no longer required to be in the
  110-degree static view (the child turns to the shelf, as in Wei's World); the turn is a cost of the plan.
* The search runs on a worker thread (`WorkerThreadPool`, `_cauldron_on_table()` is now a coroutine awaited in `run()`): about
  0.4-1.5 s on the cloud, so a second or more on the Quest. `_make_way()` is a no-op when `panel_fixed` (nothing moves).
  Onion's follow-fix stays for the glide case.

**2. 3D zones.** Every zone is a real volume now: boxes (rect + height), cylinders (circle + height), the hands' room
(a ring slice + height), Onion's body as a vertical CAPSULE (6.7 cm wide, 11 cm tall, with its halo as room), the teaching
hand's sweep as a box (measured), and the gear's hop as a swept ball (`gear_arc`: 5.8 cm radius along the same parabola
`_emerge_gear` flies, from just over the rim to the landing spot). `EntryLayout.volume_gap(a, b)` is the exact distance
between any two (prism/prism, capsule/prism, capsule/capsule, path/anything; negative = how deep inside); `overlaps()` uses it;
`overlaps_flat()` is the old footprint-only report as a quick fallback (stricter: it ignores heights). The overlay
(`Zones` button) draws the wireframes: boxes and cylinders as edges, Onion as capsule rings, the gear's flight as rings along
its path, the hand sweep orange, Onion cyan, overlaps red, over a faint flat footprint (`build/round4/r5_zones_3d_set_in.png`).
New phase bit `ARC` (the Gear part) so the gear's flight is only checked against Onion where Onion is then.

**3. First things WITH the shelf (cheap version BUILT; the proper one is a proposal).**
* Built (`FIRST_THINGS := true` in `entry.gd`): when the opening builds its shelf it also has Wei's OWN code make the first
  round's things (`ShelfCopy.make_things`, the first visit plan's first condition, a fixed seed), hidden like the shelf; the
  ripple shows each as the ring reaches it: it grows in over 1.2 s and settles the last 4 cm onto the bench (`FIRST_THINGS_RISE`).
  `_to_shelf()` hands the SAME seed to Wei's trial, so the first visit's trial makes the same things in the same places
  with no drop-in. **Edits to Wei's `trials/tidy/tidy_trial.gd`: two single-use static flags like `push` / `onion_voice`:**
  `seed_next` (non-zero: the next round's random numbers, also the global generator for its shuffles, start from it) and
  `things_arrive` (false: the next round's things are simply there, no bounce); about 17 lines; defaults change nothing.
  Test: `test_the_first_things_appear_with_the_shelf_and_the_shelf_level_makes_the_same_ones` (same names, same positions, hidden
  until the ripple). The "Oh!" lines the organizer moved into the first visit can return to the reveal now (the things are
  there when Onion notices them): the story chat's call.
* Still a swap in the engine's eyes: the opening's things belong to the Intro scene and are freed on the scene switch, the
  trial's identical ones are made in the new scene. With no black fade (`Main.change_scene(id, false)`) the eye cannot see it
  (same shapes, colours and places, one frame), but anything that moved a thing in between (a child touching one during the
  reveal: things are inert in the opening) would reset.
* PROPER version (proposal, about a day; edits Wei's trial more): the trial ADOPTS the opening's shelf and things instead of
  rebuilding them: `Workshop` carries the shelf node and the things across the switch (it already carries Onion, the panel,
  the gear), and `Trial.adopt(shelf, things, stickers)` fills `_things`, `_home`, `_key`, `_size`, `_cell_*` from them. No
  second set, no seed, no flicker even for a touched thing; needs about 30 lines in `tidy_trial.gd` and its tests.

**4. Onion beside the socket for the set-in.** `EntryLayout.onion_socket` (and `onion_socket_after`, beside the moved panel):
the nearest spot to the socket (20-26 cm horizontally on every table tested, 9 cm up) that is clear of the plate's edge, the
gear's landing spot, the cauldron, the bench and the teaching hand's lowering (its body lies to the child's right, so Onion
ends on the left or behind); `Entry._place()` sends Onion there (`_beside_socket()`), then it rises 10 cm (`onion_lifted`) as
before. In `build/round4/r5_set_in_onion_beside_socket.png` Onion hangs just over the panel's left edge.



Pictures (`tools/round4_shots.gd -- --part=r5 [--reach=0.72]`, in `build/round4/`): `fixed_*` is a measured reach of 72 cm, the panel
stays put (nothing moves at the reveal; the shelf is 30 degrees to the right, the cauldron stays clear of it; things arrive with the
shelf); `r5_*` is the usual reach, where the panel glides; `*_zones_3d_set_in.png` is the wireframe overlay.

Tests (round 5): all 211 pass on `entry-layout-5` (the base's 207 plus 4 new layout tests: fixed panel where the table allows,
3D volumes, Onion beside the socket, the first things). Three existing tests needed a change from this round (the story chat's
`entry_test.gd`: Onion is now up beside the socket, not at the aside spot, after a jump to the ripple; the cauldron may stand in
the bench's way when the panel is fixed because it sinks as the ripple starts); my layout test waits for "All set" now that
the plan takes a second. `trials/tidy/tidy_trial.gd`: the two single-use flags only (see 3).

## Interaction chat, round 6 (branch `entry-interaction-6`)
**1. The first-visit reminder is built** (`entry/shelf_reminder.gd`, from the proposal; Wei's files and resources are untouched: no flag was needed in `tidy_trial.gd`). `first_visit.gd` (story chat's file; four small edits): it makes a `ShelfReminder`, plays `_reminder.prepare(plan)` instead of `plan`, and calls `_reminder.start()` when Onion's last line is done. `ShelfReminder.DELAY` (12 s after that line; 0 = never) and `HELP_AFTER` (40 s: Wei's first hint, which wiggles the right sticker, is held back by a COPY of the plan's trial definition; his `tidy.tres` stays 10 s). The hand (`DemoHand.pinch_lift(thing, true)`, new optional `straight_down`) pinches the thing nearest the child's eyes (from Wei's public `layout()`, not his hint order), lifts it 5 cm at most and never leans toward anything. It is skipped or stops when anything is carried, after any `taken` / `put` report (then the copy goes back to Wei's own 10 s timing, so a child who is stuck AFTER starting gets his normal help), or once his hint has begun.
**2. VR readiness** (checklist: section 9 of `entry/HEADSET_TEST.md`). Tests now run the headset code paths with a dummy OpenXR interface and fake hand joints (`App.xr`, `XRHandTracker`): the pinch point (middle of thumb and index tip) takes the gear, not the hand's aim; the gear follows the pinch point and the wrist's turn about the vertical, and never tips more than 0.6 rad from upright however the wrist rolls (new `Carry.MAX_TILT`; a mouse ray cannot roll, a real wrist can); a 0.1 s joint dropout is ignored and a lost hand lets go; the fingertip poke taps the cauldron once and only in the Tap beat; Wei's carry takes a thing near the pinch point and sends it home on tracking loss; the desktop click rule and the head keys do nothing in a headset. Found nothing else that only works with the mouse. Left to the headset (HEADSET_TEST section 9): how reliably real pinches register, and whether a LEFT-hand pinch with the palm to the face opens the grown-up panel (Meta's menu gesture).
**4. Skipping Onion's lines** (`entry/line_skip.gd`, a node under Main like `DesktopKeys`). A deliberate press on Onion (a click on desktop; a pinch aimed at it or a fingertip going in, in a headset) cuts the line it is speaking; `Voice` gets `speaking()` and `skip()` (modules/voice/voice.gd, two small additions: the audio stops, the subtitle goes, `line_finished(text, false)`), and `Entry.say()` / `FirstVisit._say()` return at once for a cut line (no breath). It cuts the CURRENT line only. Never skipped: the instruction the child still needs (guards: the tap while asked and not done; the pick-up while the gear glows and is not taken; the set-in while the hand shows it and the gear is not in; the first visit's invitation until a shape is taken). A press on a Target, or one that just took the gear or a shape, is never a skip; where Onion and the cauldron or gear are both in reach the press goes to whichever it is aimed at more closely, and a press on Onion is no longer a tap on the cauldron either (Onion stands inside the cauldron's tap sphere during the Tap beat). Hooks in `entry.gd`: `_configure_skip()` in my region, `_onion_closer()` in `_on_desktop_click`, the same check in `_poke_cauldron`, and the cut-line test in `say()`. Onion stops "talking" in the opening on a cut; the workshop's own talking animation (first visit) runs out its time (a small thing for the story chat).
## Round 6 (chat C): no plate, the socket track, the invitation, VR readiness, the handover freeze

**1. No plate.** The socket is a flat recessed ring at table height (rim disc, deeper step, brass lip) with the cog on the
table beside it; nothing stands up. `PANEL`/`SOCKET_Z` changed (footprint is ring + cog, `SOCKET_RADIUS` 6 cm). The outline
(Carry's hint) and the ripple origin stay at the socket. The cauldron never moves any more (`_make_way` only slides the
socket). **Socket stays put in 8 of 42 tables** (16 of 42 before the invitation zones and the no-cauldron-glide rule were
added; 6 of 42 in round 5). It stays where the table is long/deep with a long reach (e.g. 72 cm: `--reach=0.72`); the rest
use the track. Wei's bench with its things is 54 cm wide, so the cauldron, socket and bench do not fit side by side in a
110 degree view within a 60 cm reach.

**1b. Track.** Where the socket must move, `_socket_track()` (entry.gd, about 70 lines, well under an hour) draws a 3.6 cm
groove with lips from the socket to its new place (grows over 0.7 s), plays `device_rattle` quietly, rides the socket, cog and
lifted Onion along it linearly (0.3 m/s), then fades the groove (0.8 s) before the ripple. No words. Jumps (DEV buttons) move
instantly. `reveal` jumps now start at the opening spots (`_set_up_for`).

**2. Invitation.** Onion's 30 % lean was aimed at the world origin; it now aims at the real things on the bench
(`EntryLayout.things_centre()`, zones `onion_reveal`/`onion_invite`, `invite_fraction`). The plan checks it against shelf,
things and bench in 3D; `_onion_rest()` searches for a clear spot.

**3. VR readiness of the DEV panels.** `DEV_LIFT` 0, panel tilted 70 degrees out, buttons 15 cm apart, all inside the
measured reach. Proposal only: hide the DEV panels at Start so the child never sees them. The subtitle proposal
(`Voice.above_gaze` 25 -> 36, `above_horizon` 20 -> 12, Wei's file) is unchanged.

**5. Handover freeze (intro -> first_visit).** Measured headless: the dominant cost was `load("first_visit.tscn")` at the
switch, 56 ms and a 68 ms long frame. `Entry._preload_first_visit()` (called after `_build_workshop()`) starts
`ResourceLoader.load_threaded_request`; after: 0.018 ms and no long frame. Software render: 344 ms vs a steady 250 ms
frame; shader compile is not measurable headless. If the freeze persists on the headset, the proper adoption version (or no
scene switch) is still available.

Tests: 225 pass on `entry-layout-6` (the base's 222 plus mine; `entry_test` waits for the socket to settle after a jump to the ripple).

## Interaction chat: motion route, round 1 (branch `entry-interaction-7`)
**What is new (all additive; public names kept).** `DemoHand.sweep(from, to)`: a new gesture, an open hand sliding from one world point to the other, fingers leading the way it goes, waiting at each end (`SWEEP_START` 0.5 s, `SWEEP_END` 1.7 s, loop `SWEEP_LOOP` 3.2 s), looping until `stop()`, returns at once, one gesture at a time, nothing left after `stop()`; the way is read level. `MotionTutorial` (`entry/motion_tutorial.gd`), `MotionChoice` (`entry/motion_choice.gd`). One flag in Wei's file: `WallBreak.burst(eye, look, flow, style, log := true)` (`trials/motion/wall_break.gd`): `false` leaves out the research log's `wall_break` event (the log writes every `Events.report`); the default is unchanged, so his round does exactly what it did.
**The unscored tutorial.** `var t := MotionTutorial.new(); add_child(t); t.heading = &"right"` (or `&"left"`), `t.style = WallBreak.Style.CRACK`; `t.play(frame)` returns at once. `frame` is the cloud's place like Wei's own (`Trial.in_front`: level, its -Z pointing away from the child; where it stands is the layout chat's). Signals `sweep_started`, `effect_started`, `settled` (the dots are gone), `stopped`; `stop()` cuts it short (dots and hand go at once, nothing after). The dots are a separate copy of Wei's cloud (his scene's `Cloud`, shader and dot look; never added to the tree with his trial code), at the easiest level's dots, speed and size, EVERY dot following the flow, flowing sideways; after 1.5 s the hand sweeps 30 cm the same way with the white streak a child's own sweep leaves (`SweepTrail`, same whoosh); when the hand is across the dots all go together (alignment 0 to 1 in Wei's 0.6 s) and `WallBreak.burst` plays once (3.2 s CRACK, 6 s SPACE); then the dots fade. There is no Trial and no Session, no response timer, nothing judged and nothing logged: a test checks that no `reported`, `trial_started` or `trial_ended` event and no `Trial` node ever appears. The hand's path (`hand_from`, `hand_to`, default 38 cm ahead of the eyes, 22 cm below them: comfortable hand space, 60 cm or more from the cloud) can be set before `play`.
**The choice.** `MotionChoice` (`MotionChoice.new()`, `add_child`, `place_beside(menu, half_width)` to stand it to the right of the `TaskMenu`, `open()`, wait for `chosen`, `close()` when the child picks a shelf level instead, which `TaskMenu.chosen` says). A round disc with a still cluster of dots (nothing on it moves), bigger than a level's square button, a `Target` named `motion_choice`. Chosen only by a deliberate press: a pinch aimed at it, a fingertip touching its thin touch volume, or a click (desktop, at any hand depth, as for the cauldron). Never by looking, holding a hand near or resting a finger on it (no gaze and no dwell in it; a finger resting on it as it appears has to leave and come back); once per `open()`. A fingertip close in front lifts it a little, silently.
**Wei's sweep detection with real hands, by simulation** (`rig/pointer.gd`: the hand's aim position, speed at least `sweep_speed` 0.3 m/s smoothed over 0.05 s, 12 cm of level travel; stopped for 0.4 s ends it). A seated child's sweeps are bell-shaped (slow at both ends); the table below is a smooth sweep through the real rig, peak speed in brackets:
| sweep | seen? |
|---|---|
| 30 cm in 0.5 s (1.1 m/s), 0.8 s (0.7), 1.2 s (0.47); 45 cm in 1.0 s; 20 cm and 15 cm in 0.5 to 0.6 s | yes, and read the right way (0 to 3 degrees off) |
| rising 15 cm or 30 cm on the way, an 8 cm arc like a swinging wrist, 4 mm of tracking jitter at an ordinary pace | yes |
| 30 cm in 1.6 s (0.35 m/s, "slow and careful") | yes if the tracking is perfectly steady (but only 14 cm of the 30 are heard); **no with just 1.5 mm of jitter** |
| 30 cm in 2.2 s (0.26 m/s) | **no** |
| 10 cm movement | no (below Wei's 12 cm: right) |
A slow, careful child (the way a child may well sweep, with the hand seen at 0.35 m/s) is missed because the peak of the sweep sits just above Wei's threshold and any jitter takes it under. **Recommendation (Wei's file, needs Megan's OK): `sweep_speed` 0.3 to 0.2** (an export on `Pointer`, so it can also be set on the rig's pointers by the motion route only, e.g. `App.rig.pointer(side).sweep_speed = 0.2` while its rounds run, and put back): with 0.2 the slow-with-jitter and the very slow sweeps are seen, and a hand resting with 1.5 mm or 4 mm of jitter for 4 s, or drifting at 4 cm a second, still makes NO sweep (0.15 m/s also holds, not tested lower). Rising help: a hand above the eyes (+10 cm) for 0.4 s asks for help, so the sweep must stay below eye level: the tutorial's hand does (22 cm below). In a headset a hand in the lap may not be tracked at all: the example's path is at chest height in front.
## Motion route, round 1 (chat C): `entry/motion_layout.gd`, `entry/motion_dev.gd`

Wei's cloud (not changed): a box of half sizes **0.8 wide x 0.5 high x 0.8 deep** (motion.tres; a test checks them) round a
centre 2.2 m ahead at EYE height, so its near face is 1.4 m from the eyes (Wei's rule: at least 0.6) and it spans 60 degrees
across and 39 degrees up and down, seen from the near face.

1. **Where the dots appear and sit.** `EntryMotionLayout.entrance()`: the group (a ball of 18 cm) starts hidden 20 cm behind the
   table's far edge and 30 cm under the table top, rises past the far edge and eases into the cloud's middle in `RISE_SECONDS`
   (1.4 s), one soft swoosh (Wei's `SweepTrail` whoosh, quieter, until the swoosh is sourced). On all 42 test tables the far edge is at
   most 1.2 m out, so the cloud never touches the table, and the entrance is at least 0.4 m clear of the bench, shelf and things.
   Onion: the shelf scene's resting spot is INSIDE the dots' view (29 to 35 degrees left, the cloud reaches 30 degrees), so while
   the dots play `EntryMotionLayout.onion_spot()` moves him to the nearest clear spot along the shelf's end that is 4+ degrees out
   of the dots' view (about 40 degrees to the side, 10 to 20 degrees down, within 55 degrees: in view, not covering dots).
   **Subtitles: the line at Voice's 20 degrees covers the dots, and the proposed 12 degrees would cover them more** (the proposal
   was for the shelf; do not apply it to the motion part). To clear the dots the line has to be at 26 degrees or more
   (`Voice.above_horizon`, set by the motion scene while it plays, back after; a setting, not a code change in Wei's file).
2. **The choice panel** is not done: I need Wei's shelf-level choice targets (World's `task_menu`) to place the motion target
   beside them; say if the organizer wants them side by side above the shelf and I will lay it out next.
3. **Scene marker and coherence control (built, ready for the organizer's scene).** `EntryMotionDev`: add it as a child, call
   `set_scene(&"Motion")` (also `Opening`, `Tutorial`, `Shelf`). Head-locked top-left marker (34 degrees left, 18 up, 75 cm,
   outside the dots' 30 degrees and the subtitle). Under the DEV jump panel: a readout ("DEV · coherence 70 % (pinned, next
   round)") and buttons 90 / 70 / 50 / 30 / 15 and -5 / +5. They pin like Wei's Easier/Harder: `Session.pinned` plus a
   `level_pinned` event (with the percent and `source = dev_coherence`), so it is logged. Level 0 is 90 %, level 1 is 15 %
   (`EntryMotionLayout.level_for` / `percent_for`). A pin applies from the NEXT round (the round in play has its condition).
4. **The wall effect** (`build/round4/wall_*.png`, the simulated room, wall 3 m away, effect at eye height): the hole is
   2.4 x 1.7 m up to 3 m, shrinking in metres beyond (so about 43 x 32 degrees of view at up to 3 m, 33 x 24 at 4 m). It fills a
   third of the child's view width, and its lower part sits behind the shelf's top (the shelf reaches about 10 degrees under
   the horizon). CRACK: the picture ripples and cracks, quiet colours, 3 s; SPACE: a glowing yellow rim round a purple hole,
   6 s. **Proposal for "restrained" (Wei's constants, not changed): use CRACK, not SPACE; `HOLE_SIZE` 2.4 x 1.7 to 1.7 x 1.2
   (about 31 x 22 degrees at 3 m), centre it a little above the eye line so the shelf does not cover it; keep `STAY_SECONDS` 3.**

Tests: `entry_layout_test` has four new ones (the numbers against `motion.tres`; the dots on all 42 tables; the subtitle;
the coherence mapping and the marker). The pinning buttons are not tested with hands (needs the headset).
**Wei's sweep detection with real hands, by simulation, and the change Megan approved (Oct 31): `Pointer.sweep_speed` 0.3 to 0.2 m/s** (`rig/pointer.gd`, one number and a comment; sweeps are used only by the motion task). It judges the hand's aim position: speed of at least `sweep_speed` (smoothed over 0.05 s), 12 cm of level travel; stopped for 0.4 s ends it. A seated child's sweeps are bell-shaped (slow at both ends), so the test (`entry_interaction_test.gd`, `SWEEPTABLE` lines) sweeps smoothly through the real rig. At the OLD 0.3: 30 cm in 0.5 to 1.2 s (peak 1.1 to 0.47 m/s), 45 cm, 20 cm and 15 cm sweeps, rises of 27 and 45 degrees, an 8 cm arc and 4 mm of jitter at an ordinary pace were all seen and read the right way (0 to 3 degrees off); but 30 cm in 1.6 s (peak 0.35 m/s, "slow and careful") was seen only if the tracking was perfectly steady (14 cm of the 30 heard) and was MISSED with just 1.5 mm of jitter, and 30 cm in 2.2 s (peak 0.26) was missed. At **0.2** all of those are seen (heard 21 to 26 cm of 30 for the slow ones); a 10 cm movement still is not a sweep (Wei's 12 cm); and a hand resting with 1.5 mm or 4 mm of jitter for 4 s, or drifting at 4 cm a second, makes NO sweep (0.15 m/s held too, not tested lower; Wei's own 0.15 m/s "creep" test still passes). Rising help: a hand above the eyes (+10 cm) for 0.4 s asks for help, so the sweep must stay below eye level: the tutorial's hand does (22 cm below). In a headset a hand in the lap may not be tracked at all: the example's path is at chest height in front.
