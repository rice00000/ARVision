class_name Entry
extends Node3D
## Entry: the arrival in the child's magical AR home (direction of Oct 30).
## A calm introduction in the child's real room: Onion, the cream-and-sage cauldron
## and quiet piano. Activating the cauldron lets things out through its opening, and
## a gentle ripple spreads through the nearby room and shows its hidden workshop.
## Then Wei's shelf activity (his World) starts inside that workshop, with Onion
## staying beside the child as the one guide.
##
## Not decided yet, so only placeholders here: what comes out of the cauldron, how
## the child activates it (now: touch it), the workshop's real assets.
## Only the sample lines are spoken. Every say("...") literal is baked by Wei's
## speech baker, so new lines go in only once the interaction is chosen.
## The Intro scene (scenes/intro.tscn): Main starts it with [method run] when there is no
## session plan, and it ends by switching to the Find the object scene (the World).

## Seconds after a line, at least, when there is no voice to wait for.
const PAUSE := 1.2
## The breath after a line the voice has finished, seconds.
const BREATH := 0.5
## How high above the brew Onion stands once it has popped up and settled, metres.
const PEEK_LIFT := 0.06
## Without a headset (desktop), only a click presses: moving the mouse over a button
## doesn't. Tests turn this on to drive the hands by fingertip.
@export var poke_in_sim := false

## The cauldron (CC0) and how wide it should be on the table, metres.
const CAULDRON := preload("res://entry/assets/cauldron-cream-sage.glb")
const CAULDRON_WIDTH := 0.22
## The guide: "Onion the Wisp" by Edvin Borkovskij, CC BY 4.0 (credit in entry/assets/CREDITS.md).
const ONION := preload("res://entry/assets/onion_the_wisp.glb")
## How tall Onion is, metres.
const ONION_HEIGHT := 0.11
## Quiet piano under the opening (CC0, see entry/assets/CREDITS.md).
const MUSIC := preload("res://entry/assets/calm-piano-1.mp3")
## Music volume, decibels: well under the voice.
const MUSIC_DB := -15.0

## DEMO: the child stays seated. Everything to reach or look at closely sits inside
## this circle around the head (seen from above). TO TEST: comfortable reach and view.
const PLAY_RADIUS := 0.75
## The shelf and the things to tidy stand this much farther along the table than Wei's
## original, metres, so they are not right in front of the player. See TidyTrial.push.
const SHELF_PUSH := EntryLayout.SHELF_PUSH
## The back of Wei's shelf from the eyes before the push: SHELF_AHEAD 0.31 + DEPTH 0.09, metres.
const SHELF_BACK := EntryLayout.SHELF_BACK
## The cauldron stands near the middle, a little left, this far from the eyes. TO TEST: reach.
## WHERE everything stands (the cauldron's angle, the shelf's, the panel, the gear's landing spot,
## Onion's spots, the setup panel, the dev buttons) is worked out in entry/layout.gd (EntryLayout).
const CAULDRON_DISTANCE := EntryLayout.CAULDRON_DISTANCE
## Size of the things that come out (placeholders), metres. Must fit through the opening.
## Seconds the ripple takes to spread across the play circle. Slow and soft: no flash.
const RIPPLE_SECONDS := 5.0

## DEBUG: show the beat in the headset and in Output.
const DEBUG := true
## TESTING: how fast the opening plays (0.5 = half speed, 1.0 = normal). Speech
## itself stays normal; everything around it (moves, pauses, the ripple) slows.
const TEST_SPEED := 1.0
## Draw each hand's pointing ray (Wei's pointer casts it but only draws it on the
## desktop). Only while pointing is on (his [method Pointer.ray_on]).
const SHOW_RAYS := true
## TESTING: before the opening, show where the table was found and ask to confirm it
## (or point at the real table and pinch).
const CONFIRM_TABLE := true
## TESTING: a rough line outline of each tracked hand (headset only).
const SHOW_HANDS := true
## TESTING: in setup, beside Start, buttons that play one part on its own (set up
## as that part needs it), then come back. Start plays everything, into Wei's World.
const JUMP_PANEL := true
## TESTING: skip the four setup steps (the table is the one found, reach and sound are the
## defaults) and go straight to the Start screen. Tests turn it off ([member skip_setup]).
const SKIP_SETUP := true
## Megan chose pop A. Set this to show the DEV "Pop sound" button again to compare it with C.
const POP_AUDITION := false
## The build chat's first guess at Onion's waiting behaviour in the Tap beat (gaze to the rim and
## back). Megan did not like it; off until the story chat decides the staging.
const TAP_STAGING := false
## The parts, in order: button id suffix -> label.
const PARTS := {hello = "Hello", touch = "Tap", emerge = "Gear", pickup = "Pick up", place = "Set in", reveal = "Reveal", shelf = "Shelf", dots = "Dots"}
## The interaction chat's Carry is not real yet: until it is (set this), a stand-in plays the child
## picking the gear up and setting it in.
const USE_REAL_CARRY := true
## Tests set this: a pretend child picks the gear up and sets it in (a headset has no tests).
var simulate_child := false
## Setup has four steps: hands, table, reach, sound and room.
const SETUP_STEPS := 4
## TESTING: a screen "pass the headset to the child" before the reach step, which measures
## whoever wears the headset then. Off: the same person does all four steps.
const HANDOFF_BEFORE_REACH := false

var _table: Surface
var _box := Node3D.new()            # the cauldron on the table
var _rim := 0.15                    # height of the rim above the table, metres (measured)
var _mouth := Vector3.ZERO          # centre of the opening (the brew's surface), world
var _mouth_radius := 0.05           # radius of the opening, metres (measured)
var _left := Vector3.LEFT           # the child's left, flat (set when the cauldron is placed)
var _music := AudioStreamPlayer.new()
var _orb := Node3D.new()            # holds Onion and its glow; moves around
var _onion: Node3D                  # the wisp model, turned to face the child
var _face := Vector3.FORWARD        # which way Onion's eyes point, in its own space
var _glow: OmniLight3D              # Onion's light; pulses while it talks
var _talk_until := 0.0              # seconds (game time) until Onion stops "talking"
var _cue := false                   # the cauldron glows slowly: "something here"
var _clock := 0.0
var _onion_rest_y := 0.0            # Onion's height in its holder when still
var _gear: Node3D                   # the planetary gear: origin at the middle of its base
var _gear_spin: GearSpin
var _carry: Carry                   # the child picks up the gear and sets it in (interaction chat)
var _demo: DemoHand                 # the teaching hand (interaction chat)
var _gear_height := 0.08            # unscaled, metres
var _gear_rest := Vector3.ZERO      # where it lands after coming out of the cauldron
var _mechanism: Node3D              # the table panel with the socket
var _mech_spin: GearSpin            # the little cog in the panel's window
var _socket_at := Vector3.ZERO      # the middle of the socket, world
var _ripple_origin := Vector3.ZERO  # where the ripple starts: the socket
var _details: Array[Node3D] = []    # the workshop, shown as the ripple reaches each
var _motes: Array[Node3D] = []      # drifting specks of light, after the reveal
var _surface_points: Array[Dictionary] = []   # real surfaces the depth rays found: {position, normal}
var _beat_label := Label3D.new()    # DEBUG: which beat is playing, in view
var _shelf: ShelfCopy               # Wei's shelf, built by his own code, shown by the ripple
var _bench := Transform3D.IDENTITY  # Wei's bench frame: at the eyes, facing the work surface
var _bench_below := 0.35            # its top, metres below that frame
var _bench_half := 0.27             # its half width, metres
var _ahead := Vector3.FORWARD       # straight ahead from the seat, flat (at the start)
var _on_table: Variant = null       # where the cauldron goes on the confirmed table, or null (no real table)

## Sent when the child touches (or points at and pinches) the cauldron.
signal _part_over(how: StringName)   # a part &"finished", or a jump button &"interrupted" it
## TESTING: a confirm button: its id.
signal _confirm_pressed(id: StringName)
## TESTING: a Start or jump button: which part (&"all" for Start).
signal _part_pressed(part: StringName)
## DEBUG: Onion's soft halo.
var _halo: StandardMaterial3D

# Pressing: pokes, pinches, hover (the code is under "Pressing" below).
## How far back a pinch looks for what was aimed at, seconds: the aim shifts as the fingers close.
const PINCH_LOOKBACK := 0.15
## ...but only when the ray has moved less than this since, radians (5 degrees): a slip, not a move.
const PINCH_DRIFT := 0.087
## A button ignores a second press this soon after the first, seconds (a poke and a pinch together).
const PRESS_GAP := 0.6
## The ray stays drawn this long after the hand's aim is lost, seconds, so a brief drop doesn't blink it.
const RAY_GRACE := 0.3
## "Exit app" quits on a second press within this many seconds, so a stray pinch can't close the app.
const EXIT_WINDOW := 3.0
var _real := 0.0                    # seconds that pass at normal speed, whatever TEST_SPEED is
var _buttons: Array[EntryButton] = []
var _poking: Dictionary = {}        # side -> the button its fingertip is in
var _pressed_at: Dictionary = {}    # button id -> _real when last pressed
var _aim_log: Dictionary = {}       # side -> [[_real, Target aimed at], ...], the last 0.4 s
var _cauldron_target: Target
var _in_cauldron: Dictionary = {}   # side -> its fingertip is in the cauldron's reach
var _ray_seen: Dictionary = {}      # side -> _real when the aim pose was last there
var _hand_state: Dictionary = {}    # side -> last logged "aim ... joints ..." text
var _hand_logged: Dictionary = {}   # side -> _real of that log line
var _panel: SetupPanel              # the setup panel (see setup_panel.gd)
var _presses: Array[StringName] = []   # ids of buttons pressed since a step last looked
var _early_part: StringName = &""   # a jump button pressed during setup: skip the rest, play this
var _show_hands_now := false        # the hands step shows the outlines even with SHOW_HANDS off
## Where things stand, degrees off straight ahead (shelf: to the right, cauldron: to the left).
## Variables so a picture or a test can try another layout; the constants are the defaults.
var shelf_push := SHELF_PUSH
var _cauldron_distance := CAULDRON_DISTANCE   # metres from the eyes; the reach step may bring it in
var _reach_seen := 0.0              # the farthest the hand slid out along the table, metres
var skip_setup := SKIP_SETUP
var _sounds: Sounds
var _pop_button: EntryButton   # DEV: switches Onion's pop between candidates A and C
var _actions: OnionActions          # where Onion looks, its hop and lean, the ? and ! marks
var _tapped := false               # the child has tapped the cauldron (it counts from when Onion is up)
var _tap_open := false             # a tap on the cauldron counts now, even before it is asked for
var _rattle_amp := 0.0             # how much the cauldron trembles, radians
var _reach_measured := 0.0          # the reach the layout uses: _reach_seen when Done was pressed, else 0
var _layout: EntryLayout            # WHERE everything stands (entry/layout.gd), worked out once after setup
var _zones: EntryZoneOverlay        # DEV: the zone map drawn on the table (the "Zones" button)
var _made_way := false              # the cauldron and the panel stand at their spots for the revealed room
var _runner: PartRunner             # what the playing part waits on; freed to cancel it
var _part_running := false          # a part is playing (a jump button cuts in on it)
var _pending: StringName = &""      # the part a jump button asked for while another was playing
var _exit_button: EntryButton
var _exit_armed := -100.0           # _real when "Exit app" was first pressed; a second press within EXIT_WINDOW quits


## Wei's tidy trial, only to build his shelf: the same object the child then plays
## with. It doesn't play (no _ready: no input, not in the trials group).
class ShelfCopy extends "res://trials/tidy/tidy_trial.gd":
	func _ready() -> void:
		pass

	## Where the bench is: its frame (at the eyes, facing the work surface) and how far its top is below.
	func frame() -> Transform3D:
		return _frame

	func top_below() -> float:
		return _below

	## The bench's half width, metres (as Wei builds it).
	func half_wide() -> float:
		return (THINGS_WIDE + 0.06) * 0.5

	func shelf() -> Node3D:
		return _shelf


func _exit_tree() -> void:
	# This opening owns what it hung on the persistent head (the beat label) and whatever
	# it made but never added; the rest goes with the scene.
	Engine.time_scale = 1.0
	if _onion != null:   # not handed over to the first visit: the shelf goes back to Wei's place
		ShelfCopy.push = 0.0
		show_sim_props(true)
	if is_instance_valid(_beat_label):
		_beat_label.free()
	for node in [_orb, _box, _music]:
		if is_instance_valid(node) and node.get_parent() == null:
			node.free()


## Plays the arrival, then starts the World.
func run() -> void:
	_runner = PartRunner.new()
	add_child(_runner)
	Events.touched.connect(func(_hand: StringName, target: Target) -> void:
		if _hand_pokes():
			_on_target(target))
	Events.selected.connect(func(hand: StringName, target: Target, _o: Vector3, direction: Vector3) -> void: _on_target(_pinched(hand, target, direction)))
	# Onion moves while any line plays, Wei's too: one voice, one guide.
	Events.said.connect(func(text: String) -> void: _talk_until = _clock + maxf(1.5, text.length() * 0.065))
	# Setup is quiet: Wei's "Got it. That's your table." is not for the child.
	if &"announce_table" in App.reality:
		App.reality.announce_table = false
	if not App.reality.is_settled:
		await App.reality.settled
	if DEBUG:
		_debug_buttons()
	show_sim_props(false)
	await _setup()
	ShelfCopy.push = shelf_push   # set by the reach step, or the usual SHELF_PUSH
	_ahead = Vector3(-App.head().global_basis.z.x, 0.0, -App.head().global_basis.z.z).normalized()
	_on_table = _cauldron_on_table()
	_shelf_to_the_side()
	_table = App.reality.work_surface()
	# One cauldron, one Onion, one shelf, one workshop for every part.
	_build_shelf()
	_build_cauldron(await _cauldron_spot())
	_build_mechanism()
	_build_gear()
	_build_onion()
	_build_workshop()

	# Nothing plays until the adult presses Start (or a part to jump to). A jump button also
	# cuts in on a part that is still playing, and a jump skips the story's own pauses.
	while true:
		var part := _pending
		_pending = &""
		if part == &"":
			part = await _choose_part()
		if not _music.playing:
			_start_music()
		Engine.time_scale = TEST_SPEED
		var fast := part != &"all"
		_set_up_for(&"hello" if part == &"all" else part)
		if part == &"shelf":
			await _to_shelf(true)
			return
		if part == &"dots":
			_to_dots()
			return
		_part_running = true
		_play(part, fast, _runner)   # not awaited: a jump button can cut in
		var how: StringName = await _part_over
		_part_running = false
		if how == &"interrupted":
			continue
		Engine.time_scale = 1.0
		if part == &"all":
			await _to_shelf(false)
			return
		print("ENTRY jump: ", part, " done")


## Plays [param part] on [param runner]; it never gets to the end if the runner is freed.
func _play(part: StringName, fast: bool, runner: PartRunner) -> void:
	await get_tree().process_frame   # the main loop is waiting for _part_over by now
	match part:
		&"all":
			await _hello(false)
			await _touch()
			await _out()
			await _pickup()
			await _place()
			await _reveal(false)
		&"hello": await _hello(fast)
		&"touch": await _touch()
		&"emerge": await _out()
		&"pickup": await _pickup()
		&"place": await _place()
		&"reveal": await _reveal(fast)
	if runner == _runner and _part_running:
		_part_over.emit(&"finished")


## A jump button was pressed while a part was playing: cancel that part and play [param part].
func _interrupt(part: StringName) -> void:
	print("ENTRY jump: cutting in with ", part)
	_pending = part
	_runner.process_mode = Node.PROCESS_MODE_DISABLED   # nothing it holds resumes
	_runner.queue_free()
	_runner = PartRunner.new()
	add_child(_runner)
	get_tree().call_group(&"entry_transient", "queue_free")   # rings and glints left by the old part
	_cue = false
	_part_over.emit(&"interrupted")


## 1. Arrival: a soft rattle in the cauldron, Onion pops up with a little overshoot and says hello,
## glances inside, is interrupted by a knock, introduces itself and asks for help.
## The lines are the story chat's final ones (BUILD_CHAT_UPDATE, last section).
func _hello(fast := false) -> void:
	_beat("1: hello")
	_rattle(0.0)
	if not fast:
		await _wait(2.0)   # nothing rushes the child
	_rattle(0.012)   # a soft rattle: something moves about in there
	_sounds.play(&"pre_rattle", _box.global_position)
	await _wait(0.6 if fast else 1.6)
	await _pop()
	_rattle(0.006)   # fainter, until the child taps the cauldron
	_tap_open = true   # a tap counts from here on, even before it is asked for
	await say("Oh! Hello there.")
	# Approved staging (story chat): Onion is fetching the gear to wake the table and wants to look
	# prepared. It leans over the opening and searches a little; the knock (the gear shifting) gives
	# it away; a startled hop and an angled peek; "nearly ready" is a sheepish correction to the
	# child, said while still half over the cauldron; then it straightens up and faces the child.
	_attend(_peer_point())
	_actions.lean_in(_runner, true)
	_search()   # one or two small searching movements, while it speaks
	await say("I was getting things ready.")
	await _knock()   # the gear shifts against the cauldron's inside
	_actions.hop(_runner)   # a small startled hop
	await _wait(0.5)   # then an angled peek into the opening
	_attend(null)   # a glance back at the child, still leaning over the cauldron
	await say("Nearly ready.")
	_actions.lean_in(_runner, false)   # straightens up
	await _wait(0.4)
	await say("I'm Onion, by the way.")
	_attend(_peer_point())   # turns to the cauldron, glances back
	await _wait(0.5)
	_attend(null)
	_actions.mark(_runner, "?", 2.4)
	await say("Could you help me with something?")


## 2. Asks for one tap on the cauldron (a hand shows it), waits for it; a tap already given counts.
## Onion peers in, thanks the child, and says it should loosen.
func _touch() -> void:
	_beat("2: tap the cauldron")
	_tap_open = true
	if not _tapped:
		_cue = true   # the cauldron glows slowly
		_tap_cycle()   # the hand shows the tap twice, then rests; the interval and one slow straighten
		# During the instruction Onion moves beside the mouth (the hand keeps the rim to itself),
		# turns toward the rim and leans a little toward the contact point.
		_attend(_rim_point())
		_actions.lean_to(_runner, 0.2, 0.7)
		_move(_orb, _beside_mouth(), 0.7)
		await say("Give the cauldron a little tap.")
		if not _tapped:
			await _runner.cauldron_touched
		_demo.stop()
	_cue = false
	_rattle(0.0)   # an accepted touch stops the rattle
	_actions.lift(_runner, -0.012, 0.6)   # a small dip, as if listening
	_attend(null)   # "Thank you." turns toward the child briefly
	_later(1.1, func() -> void:   # "Something's caught in there." turns back, leaning toward the opening
		_attend(_peer_point())
		_actions.lean_to(_runner, 0.35, 0.4))
	await say("Thank you. Something's caught in there.")
	_attend(_peer_point())   # holds the listening pose through the next line
	await say("That should loosen it.")
	_actions.lean_to(_runner, 0.0, 0.5)   # then straightens; _out drifts it aside (0.8 s) before the launch
	_attend(null)


## The tap demonstration twice, a quiet interval, and (after 10 s of nothing) one slow straighten
## toward the child, then it starts again. Runs until the cauldron has been tapped or the part ends.
func _tap_cycle() -> void:
	var runner := _runner
	var waited := 0.0
	var straightened := false
	while not _tapped and runner == _runner and is_instance_valid(runner):
		_demo.tap(_rim_point())
		await runner.wait(6.0)   # two loops of the hand
		if _tapped or runner != _runner or not is_instance_valid(runner):
			break
		_demo.stop()
		await runner.wait(4.0)   # a quiet interval
		waited += 10.0
		if not straightened and not _tapped and runner == _runner and is_instance_valid(runner):
			straightened = true
			_attend(null)
			_actions.lean_to(runner, 0.0, 0.8)   # once, slowly, then it stays still
			await runner.wait(0.9)


## Runs [param what] after [param seconds] on the part's runner (cancelled with the part).
func _later(seconds: float, what: Callable) -> void:
	var runner := _runner
	await runner.wait(seconds)
	if runner == _runner and is_instance_valid(runner):
		what.call()


## Beside the mouth, on the side away from the demonstration hand's body: the layout's offset
## (EntryLayout.onion_mouth_offset: the story chat's 7 cm to the child's left, moved only if the
## hand's measured sweep would touch Onion).
func _beside_mouth() -> Vector3:
	return _peek_spot() + _layout.onion_mouth_offset


## 3. Onion clears the opening; a heavier rattle; the gear pops up, Onion hops back with a "!"
## (see _surprise), and says the table's missing piece is here.
func _out() -> void:
	_beat("3: the gear comes out")
	await _onion_aside()   # beside the cauldron, watching its mouth (0.8 s, clear of the opening)
	_attend(_mouth)
	_actions.lean_to(_runner, -0.15, 0.4)   # one slight backward lean as the rattle builds
	_rattle(0.03)   # the device's rattle: heavier than Onion's, still playful
	_sounds.play(&"device_rattle", _box.global_position)
	await _wait(0.9)
	_rattle(0.0)
	await _emerge_gear()   # at launch _surprise: the small backward hop and the !
	_actions.lean_to(_runner, 0.0, 0.5)
	await _wait(0.3)
	_attend(_gear)   # the settled gear
	if USE_REAL_CARRY:
		_carry.begin(_gear, _socket_at)   # the child may already pick it up while Onion talks
	_later(1.3, func() -> void: _attend(_socket_at))   # "The table's missing piece.": once, slowly, to the socket
	await say("There it is! The table's missing piece.")
	_attend(null)   # "I've been looking for that." turns back to the child
	await say("I've been looking for that.")


## 4. Asks the child to pick the gear up, with a hand that shows the pinch; ends when it is held.
func _pickup() -> void:
	_beat("4: pick it up")
	var already := USE_REAL_CARRY and _carry.has_been_picked_up()   # the child did it before being asked
	if not already:
		_attend(_gear)   # looks at the gear with a small curious lean; the gear stays still
		_actions.lean_to(_runner, 0.15, 0.5)
		_glow_gear(true)   # a soft, steady highlight on the casing while the hand shows it
		await say("Would you pick it up for me?")   # picking it up is the child agreeing to help
		if not (USE_REAL_CARRY and _carry.has_been_picked_up()):
			_demo.pinch_lift(_gear)   # shows the gesture; the real gear stays where it is
			await say("Pinch your fingers together, and keep them closed.")
	await _child_picks_up()
	_demo.stop()
	_glow_gear(false)   # grabbed: the highlight goes
	_actions.lean_to(_runner, 0.0, 0.4)
	_actions.lift(_runner, 0.02, 0.6)   # a small pleased lift
	_attend(_gear)   # follows the held gear gently (the look is smoothed, so hand tremor is ignored)
	await say("There you go.")
	await say("Quite a little thing, isn't it?")   # quiet time to look at it; no answer expected
	await _wait(2.0)
	_attend(null)


## A soft steady glow over the whole gear (the casing) while its pick-up is being shown.
func _glow_gear(on: bool) -> void:
	var overlay: StandardMaterial3D = null
	if on:
		overlay = StandardMaterial3D.new()
		overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		overlay.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		overlay.albedo_color = Color(1.0, 0.93, 0.62, 0.22)
		overlay.no_depth_test = false
	for mesh in _gear.find_children("*", "MeshInstance3D", true, false):
		(mesh as MeshInstance3D).material_overlay = overlay


## 5. The child sets the gear into the socket. (The lead-in line to this is not approved yet:
## nothing is spoken before the instruction.) Then the gears and the panel's cog turn.
func _place() -> void:
	_beat("5: set it in")
	_glow_gear(false)
	_actions.lean_to(_runner, 0.3, 0.8)   # moves beside the socket (0.8 s), looks down and holds
	_move(_orb, _aside_spot(), 0.8)
	_attend(_socket_at)
	_demo.lower_release(_socket_at)
	await say("Set it in here, then open your fingers.")
	await _child_sets_in()
	_demo.stop()
	_sounds.play(&"seat", _socket_at)   # once, on the completed seating
	_dock_at_once()   # settled, upright, and now turning
	_actions.lean_to(_runner, 0.0, 0.4)
	_actions.lift(_runner, 0.02, 0.6)   # lifts slightly
	_attend(_mechanism)   # and looks at the connected mechanism
	await say("Ah. There we go.")
	# Onion rises and turns to the room.
	_attend(_ahead * 1.5 + App.head().global_position)
	await _move(_orb, _lifted_spot(), 1.0)


## 6. The reveal: a gentle ripple from the socket shows the nearby workshop and shelf; Onion has
## been looking forward to it; a pause to enjoy the room; then it notices the scattered things.
func _reveal(fast := false) -> void:
	_beat("6: the reveal")
	await _make_way()   # layout chat: what stands where the bench goes glides aside first
	_actions.lean_to(_runner, 0.0, 0.5)
	_attend(_shelf)   # as the ripple spreads Onion straightens and turns to one revealed feature (the shelf)
	await _ripple()
	_attend(null)   # "I've been looking forward..." turns back to the child and holds a welcoming pose
	await say("I've been looking forward to showing you this.")
	if not fast:
		await _wait(3.0)   # time to enjoy the room first: quiet floating, no scanning
	_attend(_shelf.global_position + Vector3.DOWN * 0.25)   # then it notices the scattered things:
	_actions.lean_to(_runner, 0.3, 0.8)   # turns downward over 0.8 s
	await _wait(1.2)   # a brief pause
	await say("Oh!")
	await say("Things come through, but they don't always land in the right place.")
	await say("Would you help me put them where they belong?")
	_actions.lean_to(_runner, 0.0, 0.5)
	_attend(null)


## 5. Into the shelf activity, inside the revealed workshop. Onion stays.
func _to_shelf(fast := false) -> void:
	_beat("5: to the shelf")
	_keep_pinned()   # TESTING: Wei's World uses the chosen table
	Engine.time_scale = 1.0   # Wei's World at normal speed
	_hand_over()
	_beat("done: Wei's World")
	App.main.change_scene.call_deferred(&"first_visit")   # Onion leads the first shelf level


## The global motion task (Wei's dots scene) in the same passthrough room. Onion and the
## cauldron are not carried over to it yet.
func _to_dots() -> void:
	_beat("jump: the dots")
	_keep_pinned()
	Engine.time_scale = 1.0
	_hand_over()
	App.main.change_scene.call_deferred(&"global_motion")


# --- Setup: four steps, for the grown-up -------------------------------------

## The pre-game setup: hands, table, reach, sound and room, one after another on the setup
## panel. Each step returns true when a jump button was pressed (the rest is skipped).
## Ends with the panel hidden; [method _choose_part] then shows "All set".
func _setup() -> void:
	_panel = SetupPanel.new()
	add_child(_panel)
	_panel.make_button = _button
	_panel.place(App.head().global_transform)
	if skip_setup:
		_panel.hide_all()
		print("ENTRY setup: skipped (SKIP_SETUP)")
		return
	var skipped := await _step_hands()
	if not skipped and CONFIRM_TABLE:
		skipped = await _step_table()
	if not skipped:
		skipped = await _step_reach()
	if not skipped:
		skipped = await _step_sound_and_room()
	_panel.hide_all()
	print("ENTRY setup: ", "skipped by a jump button" if skipped else "all four steps done")


## Step 1: both hands seen and a pinch. The outlines show for this step.
func _step_hands() -> bool:
	_presses.clear()
	_beat("setup 1: the hands")
	_show_hands_now = true
	_panel.show_step(1, SETUP_STEPS, "Check the hands", "Hold both hands up where the headset can see them. Then pinch thumb and finger.",
			[["Left hand seen", &"wait"], ["Right hand seen", &"wait"], ["Pinch works", &"wait"]],
			[["Next", &"entry_step_next", SetupPanel.GREY]])
	var seen := {pinch = false}
	var on_button := func(_side: StringName, action: StringName, down: bool) -> void:
		if action == &"trigger_click" and down:
			seen.pinch = true
	Events.button.connect(on_button)
	var skipped := false
	while true:
		var left := _hand_seen(&"left")
		var right := _hand_seen(&"right")
		_panel.set_check(0, &"good" if left else &"wait")
		_panel.set_check(1, &"good" if right else &"wait")
		_panel.set_check(2, &"good" if seen.pinch else &"wait")
		var ready: bool = left and right and seen.pinch
		_panel.set_button_colour(&"entry_step_next", SetupPanel.GREEN if ready else SetupPanel.GREY)
		var pressed := _take_press([&"entry_step_next"])
		if pressed == &"skip":
			skipped = true
			break
		if pressed == &"entry_step_next" and ready:
			break
		await get_tree().process_frame
	Events.button.disconnect(on_button)
	_show_hands_now = false
	return skipped


## Whether the game counts [param side]'s hand as tracked (what its touches need).
func _hand_seen(side: StringName) -> bool:
	return App.rig.pointer(side).tracked()


## Step 3: how far the child reaches. A hand rests on the table and slides out as far as is
## easy; the farthest it gets (near table height) sets how far away the cauldron goes: three
## quarters of it, between 35 and 60 cm. "Use usual spot" keeps the usual 50 cm.
func _step_reach() -> bool:
	_presses.clear()
	if HANDOFF_BEFORE_REACH:
		_panel.show_step(3, SETUP_STEPS, "Pass the headset", "Hand the headset to the child. Next they find how far they reach.",
				[], [["Ready", &"entry_step_next", SetupPanel.GREEN]])
		var handed := &""
		while handed == &"":
			handed = _take_press([&"entry_step_next"])
			if handed == &"":
				await get_tree().process_frame
		if handed == &"skip":
			return true
		_presses.clear()
	_beat("setup 3: the reach")
	var table := App.reality.work_surface()
	_reach_seen = 0.0
	_panel.show_step(3, SETUP_STEPS, "Find the reach", "Sitting comfortably, rest a hand on the table and slide it out as far as feels easy. Then press Done.",
			[["Reach not measured yet", &"wait"]],
			[["Done", &"entry_step_next", SetupPanel.GREY], ["Use usual spot", &"entry_step_alt", SetupPanel.GREY]])
	var used := false
	while true:
		var eye := App.head().global_position
		for side: StringName in [&"left", &"right"]:
			var tip: Variant = _fingertip(side)
			if tip != null and absf((tip as Vector3).y - table.transform.origin.y) < 0.1:
				var far := Vector2((tip as Vector3).x - eye.x, (tip as Vector3).z - eye.z).length()
				if far <= 1.0:
					_reach_seen = maxf(_reach_seen, far)
		var measured := _reach_seen > 0.0
		_panel.set_check(0, &"good" if measured else &"wait",
				"Reach: %d cm from the eyes" % roundi(_reach_seen * 100.0) if measured else "Reach not measured yet")
		_panel.set_button_colour(&"entry_step_next", SetupPanel.GREEN if measured else SetupPanel.GREY)
		var pressed := _take_press([&"entry_step_next", &"entry_step_alt"])
		if pressed == &"skip":
			return true
		if pressed == &"entry_step_next" and measured:
			used = true
			break
		if pressed == &"entry_step_alt":
			break
		await get_tree().process_frame
	_reach_measured = _reach_seen if used else 0.0
	_cauldron_distance = EntryLayout.cauldron_out(_reach_measured)
	# The shelf's back (its farthest cubby, SHELF_BACK from the play set's start) stands at about
	# 90% of the easy reach: at least 10 cm back (Wei's things then never lie under the chin or
	# wider than the view), never more than 30 cm. See EntryLayout.shelf_push.
	shelf_push = EntryLayout.shelf_push(_reach_measured)
	print("ENTRY reach: ", snappedf(_reach_seen, 0.01) if used else "not measured", " m; the cauldron goes ",
			snappedf(_cauldron_distance, 0.01), " m out, the shelf stands ", snappedf(shelf_push, 0.01), " m back")
	return false


## Step 4: a soft chime (the same sound as a touch) and the room scan, shown honestly:
## how much of the fan of depth rays finds a real surface. It re-scans while you look around.
func _step_sound_and_room() -> bool:
	_presses.clear()
	_beat("setup 4: sound and room")
	_panel.show_step(4, SETUP_STEPS, "Sound and room", "Listen for a soft chime. Did you hear it?",
			[["Room scan", &"wait"], ["Sound", &"wait"]],
			[["Yes, I heard it", &"entry_step_next", SetupPanel.GREEN], ["Play again", &"entry_step_alt", SetupPanel.GREY]])
	await _wait(0.5)
	_chime()
	var next_scan := 0.0
	while true:
		if _real >= next_scan:
			next_scan = _real + 0.6
			_room_check()
		var pressed := _take_press([&"entry_step_next", &"entry_step_alt"])
		if pressed == &"skip":
			return true
		if pressed == &"entry_step_alt":
			_chime()
		elif pressed == &"entry_step_next":
			_panel.set_check(1, &"good", "Sound: heard")
			break
		await get_tree().process_frame
	return false


## The room scan line: good when half the rays or more find something real.
func _room_check() -> void:
	var share := _scan_room().size() / float(GLINT_ROWS * GLINT_COLUMNS)
	if share >= 0.5:
		_panel.set_check(0, &"good", "Room scan: good (%d%% seen)" % roundi(share * 100.0))
	elif share >= 0.25:
		_panel.set_check(0, &"warn", "Room scan: patchy. Look around slowly")
	else:
		_panel.set_check(0, &"warn", "Room scan: little seen. Look around")


## A soft chime half a metre ahead (Wei's touch feedback: a sound and a small mark).
func _chime() -> void:
	var head := App.head().global_transform
	var ahead := Vector3(-head.basis.z.x, 0.0, -head.basis.z.z).normalized()
	Events.feedback.emit(&"hint", head.origin + ahead * 0.5 + Vector3.DOWN * 0.2)


# --- TESTING: Start, and jumping to one part ----------------------------------

## The last screen of setup: "All set" with Start. Waits for Start (or a jump button, which
## is always there at the left). Returns the part, or &"all" for Start.
func _choose_part() -> StringName:
	if _early_part != &"":
		var early := _early_part
		_early_part = &""
		print("ENTRY setup: jumped to ", early, " from an earlier step")
		return early
	_beat("setup done: press Start" + (" or jump to a part" if JUMP_PANEL else ""))
	_panel.show_step(SETUP_STEPS, SETUP_STEPS, "All set", "Hand the headset to the child. Press Start when they are ready.",
			[], [["Start", &"entry_part_all", SetupPanel.GREEN]])
	_presses.clear()
	var part := &""
	while part == &"":
		await get_tree().process_frame
		part = _take_part()
	_panel.hide_all()
	print("ENTRY setup: ", "Start" if part == &"all" else "jump to " + part)
	return part


## The part named by the last jump or Start press, or &"".
func _take_part() -> StringName:
	var found := &""
	for id in _presses:
		if String(id).begins_with("entry_part_"):
			found = StringName(String(id).trim_prefix("entry_part_"))
	_presses.clear()
	return found


## The first of [param ids] pressed since last asked, or &"". A jump button counts as
## &"skip": the rest of setup is skipped and that part is remembered for later.
func _take_press(ids: Array) -> StringName:
	var result := &""
	for id in _presses:
		if String(id).begins_with("entry_part_"):
			_early_part = StringName(String(id).trim_prefix("entry_part_"))
			result = &"skip"
		elif id in ids and result == &"":
			result = id
	_presses.clear()
	return result


## Puts everything as [param part] finds it, at once: Onion's place, the things on
## the table, the workshop hidden or shown. Same cauldron, Onion and shelf each time.
func _set_up_for(part: StringName) -> void:
	_make_way(0.0, part in [&"hello", &"touch", &"emerge", &"pickup", &"place"])   # layout chat: the cauldron and panel where this part finds them
	_cue = false
	_tapped = false
	_tap_open = false
	_rattle_amp = 0.0
	_actions.attention = null
	_actions.hop_y = 0.0
	_actions.lean = 0.0
	if USE_REAL_CARRY:
		_carry.reset()
	_surface_points.clear()
	_gear.visible = false
	_gear_spin.running = false
	_mech_spin.running = false
	for detail in _details:
		if is_instance_valid(detail):
			_show_detail(detail, false)
	match part:
		&"hello":
			_orb.global_position = _inside()
		&"touch":
			_orb.global_position = _peek_spot()
			_tap_open = true
		&"emerge":
			_orb.global_position = _peek_spot()
			_tap_open = true
			_tapped = true
		&"pickup", &"place":
			_orb.global_position = _aside_spot()
			_gear_to_rest()
		&"reveal", &"shelf":
			_orb.global_position = _lifted_spot()
			_dock_at_once()
	if part == &"shelf":
		for detail in _details:
			if is_instance_valid(detail):
				_show_detail(detail, true)
	print("ENTRY jump: set up for ", part)


## Shows (at full size) or hides one part of the workshop, at once.
func _show_detail(detail: Node3D, shown: bool) -> void:
	detail.set_meta(&"shown", shown)
	detail.visible = shown
	detail.scale = detail.get_meta(&"size", Vector3.ONE) if shown else Vector3.ONE * 0.001


## Leaves Onion and the cauldron standing for the next scene: a [Workshop] under Main takes
## them (and the piano, which fades out), glides Onion beside the shelf, and in Find the
## object makes Onion the body of the World's "this way" guide.
func _hand_over() -> void:
	var workshop := Workshop.new()
	App.main.add_child(workshop)
	workshop.take({onion = _orb, model = _onion, face = _face, rest_y = _onion_rest_y, glow = _glow,
			halo = _halo, cauldron = _box, rest = _beside_shelf(), music = _music, mechanism = _mechanism, gear = _gear})
	if is_instance_valid(_cauldron_target):
		_cauldron_target.queue_free()   # nothing to touch there any more
	_onion = null   # this opening's Onion code stops; the workshop looks after it


## Speaks [param text] (baked audio + subtitle) and waits for the voice to finish it, then a
## short breath. Without a voice module, or if it never says so, it waits about as long as
## the line should take.
func say(text: String) -> void:
	var voice := App.module(&"Voice")
	if voice == null or not voice.has_signal(&"line_finished"):
		Events.say(text)
		await _wait(maxf(PAUSE, text.length() * 0.07 + 0.6))
		return
	var done := {finished = false}
	var on_finished := func(spoken: String, _completed: bool) -> void:
		if spoken == text:
			done.finished = true
	voice.line_finished.connect(on_finished)
	Events.say(text)
	var limit := _real + maxf(6.0, text.length() * 0.2)   # never stuck on a line that cannot end
	while not done.finished and _real < limit:
		await _runner.tick
	voice.line_finished.disconnect(on_finished)
	await _wait(BREATH)


func _wait(seconds: float) -> void:
	await _runner.wait(seconds)


func _on_target(target: Target) -> void:
	if get_tree().paused:
		return
	if target != null and String(target.id).begins_with("entry_") and target.id != &"entry_cauldron":
		# One press, whether it came as a poke, a pinch or both.
		if _real - float(_pressed_at.get(target.id, -100.0)) < PRESS_GAP:
			return
		_pressed_at[target.id] = _real
		_presses.append(target.id)
		if target.get_parent() is EntryButton:
			(target.get_parent() as EntryButton).flash()
	if target != null and target.id == &"entry_pop_toggle":
		var pick := _sounds.toggle_pop()
		_pop_button.set_text("Pop sound: " + pick.to_upper())
		_sounds.play_pop(_peek_spot())   # hear it right away
		return
	if target != null and target.id == &"entry_debug_restart":
		print("ENTRY DEBUG: restart")
		Engine.time_scale = 1.0
		get_tree().reload_current_scene.call_deferred()
		return
	if target != null and target.id == &"entry_debug_zones":   # layout chat: the zone map, on and off
		_toggle_zones()
		return
	if target != null and target.id == &"entry_debug_exit":
		if _real - _exit_armed > EXIT_WINDOW:
			_exit_armed = _real
			if _exit_button != null:
				_exit_button.set_text("Press again to exit")
			print("ENTRY DEBUG: exit asked; press again within ", EXIT_WINDOW, " s")
			return
		print("ENTRY DEBUG: exit")
		get_tree().quit()
		return
	if target != null and String(target.id).begins_with("entry_part_"):
		Events.feedback.emit(&"hint", target.global_position)
		var chosen := StringName(String(target.id).trim_prefix("entry_part_"))
		if _part_running:
			_interrupt(chosen)
		_part_pressed.emit(chosen)
		return
	if target != null and String(target.id).begins_with("entry_step"):
		Events.feedback.emit(&"hint", target.global_position)
		return
	if target != null and String(target.id).begins_with("entry_confirm"):
		Events.feedback.emit(&"hint", target.global_position)
		_confirm_pressed.emit(target.id)
		return
	if target == null or target.id != &"entry_cauldron" or not (_cue or _tap_open):
		return
	if DEBUG:
		print("ENTRY touched: ", target.id)
	# Touch feedback (tracked hands can't vibrate): Wei's Feedback module plays a
	# sound and shows a mark where the touch landed.
	Events.feedback.emit(&"hint", target.global_position)
	_tapped = true
	_runner.cauldron_touched.emit()


## DEBUG: the beat name in Output and floating low in view.
func _beat(text: String) -> void:
	if not DEBUG:
		return
	print("ENTRY beat ", text)
	if _beat_label.get_parent() == null:
		_beat_label.font_size = 24
		_beat_label.pixel_size = 0.0006
		_beat_label.modulate = Color(1, 1, 1, 0.6)
		_beat_label.no_depth_test = true
		_beat_label.position = Vector3(0, -0.22, -0.6)
		App.rig.head.add_child(_beat_label)
	_beat_label.text = "beat " + text


# --- The hand rays ------------------------------------------------------------

var _rays: Dictionary = {}   # side -> [beam, end dot, material]

## A thin beam from each tracked hand, as far as what it meets: faint white, blue and
## brighter on something to press (a Target); a small dot where it lands.
func _draw_rays() -> void:
	if App.rig == null:
		return
	for side: StringName in [&"left", &"right"]:
		var pointer := App.rig.pointer(side)
		if not _rays.has(side):
			_rays[side] = _new_ray()
		var beam: MeshInstance3D = _rays[side][0]
		var dot: MeshInstance3D = _rays[side][1]
		var light: StandardMaterial3D = _rays[side][2]
		var on := pointer != null and pointer.ray_on() and _aim_there(side, pointer) and (App.xr != null or side == &"right")
		beam.visible = on
		dot.visible = on
		if not on:
			continue
		var from := pointer.global_position
		var direction := -pointer.global_basis.z
		var target := pointer.aimed
		var length := 0.8
		if target:
			length = maxf(0.05, (target.global_position - from).dot(direction))
		else:
			var found: Dictionary = App.reality.hit(from, direction) if App.reality else {}
			if not found.is_empty():
				length = minf(2.0, from.distance_to(found.position))
		if App.xr == null:
			# Desktop: the hand is on the line of sight through the cursor, so its ray would be seen
			# end-on, as a dot. Draw it from the lower right of the view to where it lands instead.
			var landed := from + direction * length
			from = App.head().global_transform * Vector3(0.22, -0.3, -0.2)
			length = from.distance_to(landed)
			direction = (landed - from) / maxf(length, 0.001)
		light.albedo_color = Color(0.45, 0.75, 1.0, 0.75) if target else Color(1.0, 1.0, 1.0, 0.3)
		var x := direction.cross(Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT).normalized()
		beam.global_transform = Transform3D(Basis(x, direction * length, x.cross(direction)), from + direction * length * 0.5)
		dot.global_position = from + direction * length


## Whether to draw [param side]'s ray: while the hand's aim pose is there (the game's
## own check wants the index tip, thumb and palm too, and blinks the ray out without
## them), and RAY_GRACE seconds after a brief loss. A change is logged, at most twice a second.
func _aim_there(side: StringName, pointer: Pointer) -> bool:
	var aim := App.rig.hand(side).get_has_tracking_data()
	var joints := pointer.tracked()
	if aim or joints:
		_ray_seen[side] = _real
	var state := "aim pose %s, hand check %s" % ["yes" if aim else "NO", "yes" if joints else "NO"]
	if state != _hand_state.get(side, "") and _real - float(_hand_logged.get(side, -10.0)) > 0.5:
		_hand_state[side] = state
		_hand_logged[side] = _real
		print("ENTRY hand ", side, ": ", state)
	return _real - float(_ray_seen.get(side, -10.0)) < RAY_GRACE


func _new_ray() -> Array:
	var light := _material(Color(1, 1, 1, 0.3), true)
	light.no_depth_test = App.xr == null   # desktop: the ray and its dot show over buttons
	var beam := MeshInstance3D.new()
	var line := CylinderMesh.new()
	line.top_radius = 0.0015
	line.bottom_radius = 0.0025
	line.height = 1.0
	line.radial_segments = 6
	line.material = light
	beam.mesh = line
	add_child(beam)
	var dot := MeshInstance3D.new()
	var end := SphereMesh.new()
	end.radius = 0.008
	end.height = 0.016
	end.material = light
	dot.mesh = end
	add_child(dot)
	return [beam, dot, light]


# --- DESKTOP: moving the head ------------------------------------------------

## Metres a second the head moves with the keys (a seated child only leans a little),
## and radians a second it turns.
const HEAD_SPEED := 0.5
const HEAD_TURN := 1.2
var _head_start: Variant = null

## Without a headset: W / S forward and back, A / D left and right, Q / E down and up; the
## arrow keys look (left / right turn, up / down tilt); R puts everything back where it
## started. (Right-drag looks too, but is hard on a trackpad.) The mouse hand moves with the
## head, so the cursor stays on target.
func _move_head(delta: float) -> void:
	if App.xr != null or App.sim_input == null or App.rig == null:
		return
	var head := App.rig.head
	if _head_start == null:
		_head_start = head.global_position
	if Input.is_physical_key_pressed(KEY_R):
		head.global_position = _head_start
		_look(Vector3.ZERO)
		_hand_to_cursor()
		return
	var turned := _turn_head(delta)
	var forward := Vector3.FORWARD.rotated(Vector3.UP, head.global_rotation.y)
	var right := forward.cross(Vector3.UP)
	var step := Vector3.ZERO
	step += forward * (float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
	step += right * (float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)))
	step += Vector3.UP * (float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)))
	if step != Vector3.ZERO:
		head.global_position += step.normalized() * HEAD_SPEED * delta / maxf(Engine.time_scale, 0.05)
	if step != Vector3.ZERO or turned:
		_hand_to_cursor()


## The arrow keys turn and tilt the head. True while one is down.
func _turn_head(delta: float) -> bool:
	var turn := float(Input.is_physical_key_pressed(KEY_LEFT)) - float(Input.is_physical_key_pressed(KEY_RIGHT))
	var tilt := float(Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_DOWN))
	if turn == 0.0 and tilt == 0.0:
		return false
	var amount := HEAD_TURN * delta / maxf(Engine.time_scale, 0.05)
	var head := App.rig.head
	_look(Vector3(clampf(head.rotation.x + tilt * amount, -1.3, 1.3), head.rotation.y + turn * amount, 0.0))
	return true


## Points the head ([param angles]: tilt, turn) and tells the mouse driver, so its own
## right-drag carries on from here instead of jumping back.
func _look(angles: Vector3) -> void:
	App.rig.head.rotation = angles
	var driver := _mouse_driver()
	if driver != null:
		driver.set("_pitch", angles.x)
		driver.set("_yaw", angles.y)


func _mouse_driver() -> DesktopDriver:
	for sibling in App.main.get_children():
		if sibling is DesktopDriver:
			return sibling as DesktopDriver
	return null


## Puts the mouse hand back under the cursor (it stays where it was in the room when the head moves).
func _hand_to_cursor() -> void:
	var driver := _mouse_driver()
	if driver != null:
		driver._place_hand(get_viewport().get_mouse_position())


# --- Pressing -----------------------------------------------------------------

## Remembers, for each hand, what its ray pointed at over the last 0.4 s.
func _log_aim() -> void:
	for side: StringName in [&"left", &"right"]:
		var log: Array = _aim_log.get_or_add(side, [])
		var pointer := App.rig.pointer(side)
		log.append([_real, pointer.aimed, -pointer.global_basis.z])
		while not log.is_empty() and _real - float(log[0][0]) > 0.4:
			log.pop_front()


## A pinch moves the aim a little as the fingers close. So a press counts what the ray
## pointed at PINCH_LOOKBACK seconds before the click, when that was a Target; else what
## it hits at the click.
func _pinched(side: StringName, at_click: Target, direction: Vector3) -> Target:
	var log: Array = _aim_log.get(side, [])
	var then: Variant = null
	var then_direction := Vector3.ZERO
	for sample: Array in log:
		if float(sample[0]) <= _real - PINCH_LOOKBACK:
			then = sample[1]
			then_direction = sample[2]
	if then != null and is_instance_valid(then) and then_direction.angle_to(direction) <= PINCH_DRIFT:
		return then as Target
	return at_click


## Whether touching counts: on a headset always; on desktop only when [member poke_in_sim].
func _hand_pokes() -> bool:
	return App.xr != null or poke_in_sim


## The index fingertip (world), or null. Only the index tip has to be tracked: the game's
## own check also wants the thumb and the palm, and drops the whole hand without them.
func _fingertip(side: StringName) -> Variant:
	if not _hand_pokes():
		return null
	if App.xr != null:
		var joints := App.rig.tracked_hand(side).joints()
		if joints == null or not joints.has_tracking_data:
			return null
		if (joints.get_hand_joint_flags(TrackedHand.INDEX) & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID) == 0:
			return null
		return App.rig.global_transform * joints.get_hand_joint_transform(TrackedHand.INDEX).origin
	var pointer := App.rig.pointer(side)
	return pointer.tip() if pointer.tracked() else null


## A fingertip that goes into a button's box presses it (the nearest button, when two boxes
## meet). A finger already in a box when the button appears does not press it: it has to
## leave and come back. Buttons light up under a fingertip or a ray.
func _poke_buttons() -> void:
	_buttons.assign(_buttons.filter(func(b: Variant) -> bool: return is_instance_valid(b) and not b.is_queued_for_deletion()))
	var hot: Array[EntryButton] = []
	for side: StringName in [&"left", &"right"]:
		var tip: Variant = _fingertip(side)
		var inside: EntryButton = null
		var best := INF
		if tip != null:
			for button in _buttons:
				if button.reaches(tip):
					var off := button.off_centre(tip)
					if off < best:
						best = off
						inside = button
		var was: Variant = _poking.get(side)
		_poking[side] = inside
		if inside != null:
			hot.append(inside)
			if inside != was and _real - inside.born > 0.8:
				_on_target(inside.target)
		var aimed := App.rig.pointer(side).aimed
		if aimed != null and aimed.get_parent() is EntryButton:
			hot.append(aimed.get_parent() as EntryButton)
	for button in _buttons:
		button.set_hot(button in hot)


## The same for the cauldron: a fingertip going into its reach touches it (while it glows).
func _poke_cauldron() -> void:
	if _cauldron_target == null:
		return
	for side: StringName in [&"left", &"right"]:
		var tip: Variant = _fingertip(side)
		var inside: bool = tip != null and (tip as Vector3).distance_to(_cauldron_target.global_position) <= CAULDRON_WIDTH * 0.6
		var was: bool = _in_cauldron.get(side, false)
		_in_cauldron[side] = inside
		if inside and not was and (_cue or _tap_open):
			_on_target(_cauldron_target)


# --- TESTING: the hands' outlines --------------------------------------------

## Wrist to each fingertip, through the knuckles (Godot's OpenXR hand joints).
const FINGERS := [[1, 2, 3, 4, 5], [1, 6, 7, 8, 9, 10], [1, 11, 12, 13, 14, 15], [1, 16, 17, 18, 19, 20], [1, 21, 22, 23, 24, 25]]
var _hand_lines: Dictionary = {}   # side -> [MeshInstance3D of lines, ImmediateMesh, joint dots]

## A rough outline of each tracked hand: a line along each finger and a small dot on
## each joint (lines alone are 1 pixel wide). Headset only: the desktop has no joints.
func _draw_hands() -> void:
	if App.rig == null or App.xr == null:
		return
	for side: StringName in [&"left", &"right"]:
		if not _hand_lines.has(side):
			_hand_lines[side] = _new_hand()
		var outline: MeshInstance3D = _hand_lines[side][0]
		var lines: ImmediateMesh = _hand_lines[side][1]
		var dots: MultiMeshInstance3D = _hand_lines[side][2]
		var hand := App.rig.tracked_hand(side)
		var joints := hand.joints()
		var seen := joints != null and joints.has_tracking_data
		outline.visible = seen
		dots.visible = seen
		if not seen:
			continue
		# Light blue while the game counts the hand as tracked; orange when it doesn't (the
		# outline still shows every joint the headset does see).
		var colour := Color(0.8, 0.95, 1.0, 0.7) if hand.has_joints() else Color(1.0, 0.6, 0.2, 0.8)
		(outline.material_override as StandardMaterial3D).albedo_color = colour
		(dots.multimesh.mesh.material as StandardMaterial3D).albedo_color = colour
		var to_world := App.rig.global_transform
		lines.clear_surfaces()
		lines.surface_begin(Mesh.PRIMITIVE_LINES)
		for finger: Array in FINGERS:
			for k in finger.size() - 1:
				if _joint_seen(joints, finger[k]) and _joint_seen(joints, finger[k + 1]):
					lines.surface_add_vertex(to_world * joints.get_hand_joint_transform(finger[k]).origin)
					lines.surface_add_vertex(to_world * joints.get_hand_joint_transform(finger[k + 1]).origin)
		lines.surface_end()
		for joint in 25:
			var shown := _joint_seen(joints, joint + 1)
			var at := to_world * joints.get_hand_joint_transform(joint + 1).origin if shown else Vector3.ZERO
			dots.multimesh.set_instance_transform(joint, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE if shown else Vector3.ZERO), at))


func _joint_seen(joints: XRHandTracker, joint: int) -> bool:
	return (joints.get_hand_joint_flags(joint) & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID) != 0


func _new_hand() -> Array:
	var lines := ImmediateMesh.new()
	var outline := MeshInstance3D.new()
	outline.mesh = lines
	outline.material_override = _material(Color(0.8, 0.95, 1.0, 0.7), true)
	outline.top_level = true
	add_child(outline)
	var ball := SphereMesh.new()
	ball.radius = 0.004
	ball.height = 0.008
	ball.radial_segments = 6
	ball.rings = 3
	ball.material = _material(Color(0.8, 0.95, 1.0, 0.7), true)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = ball
	many.instance_count = 25
	var dots := MultiMeshInstance3D.new()
	dots.multimesh = many
	dots.top_level = true
	add_child(dots)
	return [outline, lines, dots]


# --- DEBUG: restart and exit -------------------------------------------------

## Two small buttons up on the right, out of the way, for the whole run (Wei's World
## too): "Restart" plays the opening again from the start, "Exit app" closes the app.
## 15 cm apart, so each is easy to hit on its own.
func _debug_buttons() -> void:
	var head := App.head().global_transform
	var restart := _button("Restart", EntryLayout.dev_right_spot(head, 0), &"entry_debug_restart", Color(0.35, 0.35, 0.4))
	var leave := _button("Exit app", EntryLayout.dev_right_spot(head, 1), &"entry_debug_exit", Color(0.55, 0.25, 0.25))
	var zones := _button("Zones", EntryLayout.dev_right_spot(head, 2), &"entry_debug_zones", Color(0.3, 0.45, 0.4), 0.14, 0.01)
	_exit_button = leave
	print("ENTRY DEBUG: Restart / Exit / Zones ", _away(restart.global_position), " m away, ", EntryLayout.DEV_ANGLE, " degrees right, ",
			snappedf(restart.global_position.distance_to(leave.global_position), 0.01), " m apart")
	for button in [restart, leave, zones]:
		button.set_meta(&"debug", true)
	if JUMP_PANEL:
		_dev_jumps()


## DEV: one button per part, two columns of four out at the left (EntryLayout.DEV_ANGLE), in story
## order, there from the start; the pop sound A/C under them. Pressing one in the middle of setup
## skips the rest of setup and plays that part.
func _dev_jumps() -> void:
	var head := App.head().global_transform
	var words := Label3D.new()
	words.text = "DEV · jump to"
	words.font_size = 26
	words.pixel_size = 0.0006
	words.outline_size = 8
	words.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(words)
	words.global_position = EntryLayout.dev_jump_label(head)
	var names: Array = PARTS.keys()
	for i in names.size():
		_button(PARTS[names[i]], EntryLayout.dev_jump_spot(head, i), StringName("entry_part_" + names[i]), Color(0.3, 0.4, 0.6), EntryLayout.DEV_JUMP_WIDE, 0.005)
	if POP_AUDITION:
		_pop_button = _button("Pop sound: A", EntryLayout.dev_pop_spot(head), &"entry_pop_toggle", Color(0.5, 0.35, 0.55), 0.18, 0.005)


## DEV: shows or hides the zone map on the table (the "Zones" button, or SHOW_ZONES from the start).
func _toggle_zones() -> void:
	if _zones != null and is_instance_valid(_zones):
		_zones.queue_free()
		_zones = null
		print("ENTRY zones: hidden")
		return
	if _layout == null:
		print("ENTRY zones: nothing placed yet (after setup)")
		return
	_zones = EntryZoneOverlay.new()
	add_child(_zones)
	_zones.draw(_layout, EntryLayout.REVEAL | EntryLayout.SHELF if _made_way else EntryLayout.SETUP | EntryLayout.OPENING)
	print("ENTRY zones: shown\n", _layout.report() if _layout.report() != "" else "no overlaps")


# --- The shelf to the side ----------------------------------------------------

## Wei's bench faces his table point from the eyes. So to turn the shelf the layout's angle
## right, the found table's point moves there, along the same table. Only for a real table: the
## pretend one is always straight ahead. Wei's World follows: the alchemy table is that way.
func _shelf_to_the_side() -> void:
	var table := App.reality.work_surface()
	if not App.reality.surfaces(&"table").has(table):
		print("ENTRY shelf: no real table, so it stays straight ahead")
		return
	var eye := App.head().global_position
	var reach := Vector2(table.transform.origin.x - eye.x, table.transform.origin.z - eye.z).length()
	var angle := _layout.shelf_angle
	var point := eye + _ahead.rotated(Vector3.UP, -deg_to_rad(angle)) * reach
	point.y = table.transform.origin.y
	App.reality._surfaces.erase(table)   # TESTING: reaches into Reality's list (ask Wei for a hook)
	var moved := Surface.new(&"table", Transform3D(table.transform.basis, point), table.size)
	App.reality.add_surface(moved)
	if _pinned != null:
		_pinned = moved
	print("ENTRY shelf: ", angle, " degrees right, ", snappedf(reach, 0.01), " m away")


## Works out the layout (EntryLayout) from the confirmed table, the head and the reach, and
## returns the cauldron's spot on a real table (null without one: then [method _cauldron_spot]
## finds the height by depth).
func _cauldron_on_table() -> Variant:
	var table := App.reality.work_surface()
	var real := App.reality.surfaces(&"table").has(table)
	_layout = _new_layout(table, real, _reach_measured)
	_layout.plan()
	print("ENTRY layout: ", _layout.summary())
	var problems := _layout.report()
	if problems != "":
		print("ENTRY layout: ", problems.replace("\n", "; "))
	if not real:
		return null
	print("ENTRY spot: on the confirmed table, ", _away(_layout.cauldron), " m away")
	return _layout.cauldron


## A layout for [param table] from where the head is now, straight ahead from the seat.
func _new_layout(table: Surface, real: bool, measured: float) -> EntryLayout:
	var layout := EntryLayout.new()
	var head := App.head().global_transform
	layout.eye = head.origin
	layout.ahead = Vector3(-head.basis.z.x, 0.0, -head.basis.z.z).normalized()
	layout.table = table.transform
	layout.table_size = table.size
	layout.real_table = real
	layout.reach = measured
	return layout


## The point of [param table] nearest [param near] (seen from above), [param margin] in from its edges.
func _nearest_on(table: Surface, near: Vector3, margin: float) -> Vector3:
	var local := table.transform.affine_inverse() * near
	var half := (table.size * 0.5 - Vector2.ONE * margin).max(Vector2.ZERO)
	local.x = clampf(local.x, -half.x, half.x)
	local.z = clampf(local.z, -half.y, half.y)
	local.y = 0.0
	return table.transform * local


# --- TESTING: confirm the table ---------------------------------------------

## Shows where Wei's code thinks the table is (a soft outline) and two buttons:
## "Yes, that's the table" or "No: point at it". Pointing: a dot shows where the hand
## ray meets something, green on a flat tabletop; pinch on green and that is the table
## (no second confirm). Pinching off a tabletop says why and keeps waiting.
var _aiming := false
var _aim_dot: MeshInstance3D
var _aim_material: StandardMaterial3D
var _aim_hit: Dictionary = {}       # the last flat tabletop the ray found: {position, normal}
var _pinned: Surface                # TESTING: the table chosen here; kept over others later
func _step_table() -> bool:
	_presses.clear()
	_beat("TEST: is this the table?")
	var eye := App.head().global_transform
	var table := App.reality.work_surface()
	var real := App.reality.surfaces(&"table").has(table)
	var outline := _outline(table, real)
	print("ENTRY table: ", "found" if real else "NONE found: a virtual patch", " at ", snappedf(eye.origin.y - table.transform.origin.y, 0.01),
			" m below the eyes, ", _away(table.transform.origin), " m away, size ", table.size)
	_table_panel(table, real)
	var pressed := &""
	while pressed == &"":
		pressed = _take_press([&"entry_confirm_yes", &"entry_confirm_point"])
		if pressed == &"":
			await get_tree().process_frame
	outline.queue_free()
	if pressed == &"skip":
		return true
	if pressed == &"entry_confirm_yes":
		if real:
			_pinned = table
		print("ENTRY table: confirmed")
		return false
	_panel.show_step(2, SETUP_STEPS, "Point at the table", "Point at the tabletop: the dot turns green. Then pinch.", [], [])
	_beat("TEST: aim at the tabletop (green dot) and pinch")
	_start_aiming()
	var picked := {done = false, origin = Vector3.ZERO, direction = Vector3.ZERO}
	var on_selected := func(_side: StringName, _target: Target, origin: Vector3, direction: Vector3) -> void:
		picked.origin = origin
		picked.direction = direction
		picked.done = true
	Events.selected.connect(on_selected)
	var skipped := false
	while true:
		await get_tree().process_frame
		if _take_press([]) == &"skip":
			skipped = true
			break
		if picked.done:
			picked.done = false
			_aim_at(picked.origin, picked.direction)   # the pinch's own ray
			if not _aim_hit.is_empty():
				break
			_panel.set_body("Not a flat tabletop there. Point at the table (green dot), then pinch.")
			print("ENTRY table: pinched off the tabletop")
	Events.selected.disconnect(on_selected)
	_aiming = false
	_aim_dot.queue_free()
	if skipped:
		return true
	var at: Vector3 = _aim_hit.position
	var facing := Vector3(at.x - eye.origin.x, 0.0, at.z - eye.origin.z).normalized()
	_pinned = Surface.new(&"table", Transform3D(Basis.looking_at(facing), at), Vector2(0.8, 0.5))
	_keep_pinned()
	print("ENTRY table: pointed, ", _away(at), " m away, ", snappedf(eye.origin.y - at.y, 0.01), " m below the eyes")
	var shown := _outline(_pinned, true)
	await _wait(1.2)
	shown.queue_free()
	return false


## Step 2 on the panel: the outline question, and three honest checks on the table found.
func _table_panel(table: Surface, real: bool) -> void:
	var drop := App.head().global_position.y - table.transform.origin.y
	var comfy := drop >= 0.25 and drop <= 0.8
	var layout := _new_layout(table, real, 0.0).plan()
	var crowded := layout.overlaps().filter(func(o: Dictionary) -> bool: return o.how == "on the table").size()
	var far := layout.out_of_reach().size()
	var big := crowded == 0 and far == 0
	_panel.show_step(2, SETUP_STEPS, "Find the table", "Is the outline on your table?",
			[["Found by the headset" if real else "No table found: a pretend one", &"good" if real else &"warn"],
			["Comfortable height (%d cm down)" % roundi(drop * 100.0) if comfy else "Looks odd: %d cm below the eyes" % roundi(drop * 100.0), &"good" if comfy else &"warn"],
			["Room for everything" if big else ("Far: hard to reach" if far > 0 else "Small: %d things overlap" % crowded), &"good" if big else &"warn"]],
			[["Yes, that's the table", &"entry_confirm_yes", SetupPanel.GREEN], ["No, point at it", &"entry_confirm_point", SetupPanel.GREY]])


## TESTING ONLY: the chosen table replaces any other tables (Wei's depth finder can
## add one later; then his code would pick whichever is nearest). Reaches into
## Reality's list: a proper "use this table" hook would be Wei's call.
func _keep_pinned() -> void:
	if _pinned == null:
		return
	for other in App.reality.surfaces(&"table"):
		if other != _pinned:
			App.reality._surfaces.erase(other)
	if not App.reality.surfaces(&"table").has(_pinned):
		App.reality.add_surface(_pinned)


func _start_aiming() -> void:
	_aim_material = _material(Color(0.6, 0.6, 0.6, 0.8), true)
	_aim_material.no_depth_test = true
	_aim_dot = MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.015
	dot.height = 0.03
	dot.material = _aim_material
	_aim_dot.mesh = dot
	_aim_dot.visible = false
	add_child(_aim_dot)
	_aiming = true


## While aiming: where the hand ray (right hand, else left) meets something real;
## green when it is a flat, level top at table height.
func _aim() -> void:
	var ray: Node3D = null
	for side: StringName in [&"right", &"left"]:
		var pointer := App.rig.pointer(side)
		if pointer and pointer.tracked():
			ray = pointer
			break
	if ray == null:
		_aim_hit = {}
		_aim_dot.visible = false
		return
	_aim_at(ray.global_position, -ray.global_basis.z)


func _aim_at(origin: Vector3, direction: Vector3) -> void:
	_aim_hit = {}
	var found: Dictionary = App.reality.hit(origin, direction)
	if found.is_empty():
		_aim_dot.visible = false
		return
	var at: Vector3 = found.position
	_aim_dot.visible = true
	_aim_dot.global_position = at
	var eye := App.head().global_position
	var level := (found.normal as Vector3).y > 0.8 or _flat_at(eye, at + Vector3.UP * 0.1) != null
	var height_ok := eye.y - at.y > 0.2 and eye.y - at.y < 0.9
	if level and height_ok:
		_aim_hit = found
	_aim_material.albedo_color = Color(0.3, 0.95, 0.5, 0.9) if not _aim_hit.is_empty() else Color(0.6, 0.6, 0.6, 0.8)


## A soft rectangle over [param table]: green when it is a found table, orange for the virtual patch.
func _outline(table: Surface, real: bool) -> Node3D:
	var sheet := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = table.size
	plane.material = _material(Color(0.3, 0.9, 0.5, 0.25) if real else Color(1.0, 0.6, 0.2, 0.25), true)
	sheet.mesh = plane
	add_child(sheet)
	sheet.global_transform = table.transform.translated_local(Vector3.UP * 0.004)
	var words := Label3D.new()
	words.text = "table found" if real else "no table: pretend one"
	words.font_size = 32
	words.pixel_size = 0.0007
	words.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	words.position = Vector3.UP * 0.06
	sheet.add_child(words)
	return sheet


## A floating button with [param text]: poke it, or point at it and pinch. Its box is the
## plate plus [param margin] all round (see [EntryButton]).
func _button(text: String, at: Vector3, id: StringName, colour := Color(0.25, 0.45, 0.85),
		wide := 0.22, margin := 0.02) -> EntryButton:
	var button := EntryButton.new()
	add_child(button)
	button.setup(text, id, colour, Vector2(wide, 0.06 if wide > 0.15 else 0.05), margin)
	button.global_position = at
	button.born = _real
	button.look_at(Vector3(App.head().global_position.x, at.y, App.head().global_position.z), Vector3.UP)
	button.rotate_object_local(Vector3.UP, PI)   # its face to the child
	_buttons.append(button)
	return button


# --- The cauldron ------------------------------------------------------------

func _build_cauldron(spot: Vector3) -> void:
	add_child(_box)
	_box.global_position = spot
	# Handles to the sides: the cauldron's front faces the child.
	var to_child := App.head().global_position - spot
	_box.rotation.y = atan2(to_child.x, to_child.z)
	var cauldron: Node3D = CAULDRON.instantiate()
	_box.add_child(cauldron)
	_stand_upright(cauldron)
	# Scale it to CAULDRON_WIDTH and stand it on the table, whatever the model's own units.
	var bounds := _bounds(cauldron)
	cauldron.scale *= CAULDRON_WIDTH / maxf(bounds.size.x, bounds.size.z)
	bounds = _bounds(cauldron)
	cauldron.global_position += Vector3(spot.x - bounds.get_center().x, spot.y - bounds.position.y, spot.z - bounds.get_center().z)
	_rim = _bounds(cauldron).size.y
	var brew := _brew(cauldron)
	_mouth = spot + Vector3.UP * _rim if brew.size == Vector3.ZERO else brew.get_center()
	_mouth_radius = CAULDRON_WIDTH * 0.25 if brew.size == Vector3.ZERO else minf(brew.size.x, brew.size.z) * 0.5
	print("ENTRY cauldron: rim ", snappedf(_rim, 0.001), " m, opening radius ", snappedf(_mouth_radius, 0.001),
			" m, ", snappedf(spot.y + _rim - _mouth.y, 0.001), " m below the rim")
	var target := Target.sphere(&"entry_cauldron", CAULDRON_WIDTH * 0.6)
	target.position = Vector3.UP * _rim * 0.5
	_box.add_child(target)
	_cauldron_target = target


## The model lies on its side (its brew faces +Z): turn it so the brew faces up.
func _stand_upright(cauldron: Node3D) -> void:
	var brew := _brew(cauldron)
	var all := _bounds(cauldron)
	if brew.size == Vector3.ZERO or brew.size.y <= minf(brew.size.x, brew.size.z):
		return   # already upright
	var flat_z := brew.size.z < brew.size.x
	var side := (brew.get_center() - all.get_center()).z if flat_z else (brew.get_center() - all.get_center()).x
	if flat_z:
		cauldron.rotate_x(-PI * 0.5 if side > 0.0 else PI * 0.5)
	else:
		cauldron.rotate_z(PI * 0.5 if side > 0.0 else -PI * 0.5)


## The brew's surface ("SageBrew" material) in world space, or an empty box.
func _brew(cauldron: Node3D) -> AABB:
	for mesh: MeshInstance3D in cauldron.find_children("*", "MeshInstance3D", true, false):
		for s in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(s)
			if material == null or not material.resource_name.contains("Brew"):
				continue
			var points: PackedVector3Array = mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var box := AABB(mesh.global_transform * points[0], Vector3.ZERO)
			for point in points:
				box = box.expand(mesh.global_transform * point)
			return box
	return AABB()


## Wei's shelf, as his trial builds it, where his trial will put it. Hidden until
## the ripple reaches it. When his trial builds its own, this copy goes.
func _build_shelf() -> void:
	_shelf = ShelfCopy.new()
	add_child(_shelf)
	_shelf._build_shelf()
	_bench = _shelf.frame()
	_bench_below = _shelf.top_below()
	_bench_half = _shelf.half_wide()
	var frame := _bench
	# A pivot under the bench's middle, so the shelf can grow in from there.
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.global_transform = frame.translated_local(Vector3(0.0, -_shelf.top_below(), -0.26))
	_shelf.shelf().reparent(pivot)
	_detail(pivot, pivot.global_position)
	get_tree().node_added.connect(_on_node_added)
	print("ENTRY shelf: bench top ", snappedf(_shelf.top_below(), 0.01), " m below the eyes")


## Wei's trial built its own shelf: the copy goes (they stand in the same place).
func _on_node_added(node: Node) -> void:
	if node.name == &"Shelf" and _shelf != null and node != _shelf.shelf():
		get_tree().node_added.disconnect(_on_node_added)
		_shelf.shelf().get_parent().queue_free()
		_shelf.queue_free()
		_shelf = null
		print("ENTRY shelf: Wei's trial has its own now")


## Where the cauldron goes: the layout's spot (EntryLayout: left of the middle, in reach, clear of the
## panel). At the real table's height when depth finds a flat, level patch there (a lap doesn't
## count), else the found table's height, else the bench's. The layout follows its real height.
func _cauldron_spot() -> Vector3:
	var eye := _bench.origin
	_left = _ahead.rotated(Vector3.UP, PI * 0.5)
	var spot := _layout.cauldron
	if _on_table != null:
		var flat: Variant = _flat_at(eye, Vector3(spot.x, eye.y, spot.z))   # the real top's height, if depth sees it
		if flat != null and absf((flat as Vector3).y - spot.y) < 0.05:
			spot.y = (flat as Vector3).y
		print("ENTRY spot: cauldron on the confirmed table, ", snappedf(eye.y - spot.y, 0.01), " m below the eyes")
		return spot
	spot.y = eye.y - _bench_below
	for attempt in 12:   # about 3 s
		var flat: Variant = _flat_at(eye, Vector3(spot.x, eye.y, spot.z))
		if flat != null:
			print("ENTRY spot: real table by depth, ", _away(flat), " m away, ", snappedf(eye.y - (flat as Vector3).y, 0.01), " m below the eyes")
			return flat
		await _wait(0.25)
	if App.reality.surfaces(&"table").has(_table):
		spot.y = _table.transform.origin.y
		print("ENTRY spot: at the table's height (depth saw no flat patch there), ", _away(spot), " m away")
	else:
		print("ENTRY spot: no table; at the bench's height, ", _away(spot), " m away")
	return spot


## Seen from above, how far [param point] is from the head, metres.
func _away(point: Vector3) -> float:
	var eye := App.head().global_position
	return snappedf(Vector2(point.x - eye.x, point.z - eye.z).length(), 0.01)


## The tabletop under [param above] if it is level and flat over 16 cm at table
## height below [param eye]; else null.
func _flat_at(eye: Vector3, above: Vector3) -> Variant:
	var heights: Array[float] = []
	for offset: Vector3 in [Vector3.ZERO, Vector3(0.08, 0, 0), Vector3(-0.08, 0, 0), Vector3(0, 0, 0.08), Vector3(0, 0, -0.08)]:
		var found: Dictionary = App.reality.hit(above + offset, Vector3.DOWN)
		if found.is_empty() or found.normal.y < 0.95:
			return null
		heights.append(found.position.y)
	var drop := eye.y - heights[0]
	if drop < 0.25 or drop > 0.8 or heights.max() - heights.min() > 0.015:
		return null
	return Vector3(above.x, heights[0], above.z)


## The box around every mesh under [param root], in world space.
func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var part := mesh.global_transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


## Flat, from the cauldron toward the child.
func _toward_child() -> Vector3:
	var to := App.head().global_position - _box.global_position
	return Vector3(to.x, 0.0, to.z).normalized()


# --- Onion -------------------------------------------------------------------

func _build_onion() -> void:
	add_child(_orb)
	_orb.global_position = _inside()
	_onion = ONION.instantiate()
	_orb.add_child(_onion)
	# Scale Onion to ONION_HEIGHT and centre it on the holder.
	var bounds := _bounds(_onion)
	_onion.scale *= ONION_HEIGHT / bounds.size.y
	bounds = _bounds(_onion)
	_onion.global_position -= bounds.get_center() - _orb.global_position
	_onion_rest_y = _onion.position.y
	# Which way the eyes look: from the body's centre to the eyes' centre.
	for mesh: MeshInstance3D in _onion.find_children("*Eyes*", "MeshInstance3D", true, false):
		var eyes := (mesh.global_transform * mesh.get_aabb()).get_center()
		var towards := eyes - bounds.get_center()
		_face = _orb.global_transform.basis.inverse() * Vector3(towards.x, 0, towards.z).normalized()
	# A soft light around Onion, so it glows on the cauldron and table.
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.85, 0.2)
	_glow.omni_range = 0.6
	_glow.light_energy = 0.6
	_orb.add_child(_glow)
	# A small, soft halo around Onion in its own body colour, always facing the child.
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * ONION_HEIGHT * 1.5
	# Normal (mixed) blending: over passthrough, an added glow can vanish.
	var tint := _body_colour()
	tint.a = 0.22
	_sounds = Sounds.new()
	_sounds.name = "Sounds"
	add_child(_sounds)
	_actions = OnionActions.new()
	_actions.name = "OnionActions"
	add_child(_actions)
	_actions.setup(_orb, ONION_HEIGHT)
	_halo = _material(tint, true)
	_halo.albedo_texture = _soft_dot()
	_halo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = _halo
	halo.mesh = quad
	_orb.add_child(halo)


## Onion's body colour: the average of its texture where the body's UVs fall
## (light blue). If the texture can't be read on this device, the value measured on the desktop.
func _body_colour() -> Color:
	var measured := Color(0.57, 0.84, 0.91)
	for mesh: MeshInstance3D in _onion.find_children("*", "MeshInstance3D", true, false):
		if mesh.name.contains("Eye"):
			continue
		var material := mesh.mesh.surface_get_material(0) as BaseMaterial3D
		if material == null or material.albedo_texture == null:
			continue
		var image := material.albedo_texture.get_image()
		if image == null:
			break
		if image.is_compressed() and image.decompress() != OK:
			break
		var uvs: PackedVector2Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		var sum := Color(0, 0, 0, 0)
		var count := 0
		for i in range(0, uvs.size(), 7):
			var x := clampi(int(fposmod(uvs[i].x, 1.0) * image.get_width()), 0, image.get_width() - 1)
			var y := clampi(int(fposmod(uvs[i].y, 1.0) * image.get_height()), 0, image.get_height() - 1)
			sum += image.get_pixel(x, y)
			count += 1
		if count > 0:
			print("ENTRY Onion's colour: ", sum / count)
			return Color(sum.r / count, sum.g / count, sum.b / count)
	print("ENTRY Onion's colour: measured value (texture not readable here)")
	return measured


## Where Onion hides: under the brew, out of sight.
func _inside() -> Vector3:
	return _mouth + Vector3.DOWN * (ONION_HEIGHT * 0.5 + 0.02)


## Onion faces the child; bobs and glows while talking. The cauldron's cue and the
## workshop's motes move here too.
func _process(delta: float) -> void:
	_clock += delta
	_real += delta / maxf(Engine.time_scale, 0.05)
	_move_head(delta)
	if _exit_button != null and is_instance_valid(_exit_button) and _real - _exit_armed > EXIT_WINDOW and _exit_button.text() != "Exit app":
		_exit_button.set_text("Exit app")
	if App.rig != null:
		_log_aim()
		_poke_buttons()
		_poke_cauldron()
	if SHOW_RAYS:
		_draw_rays()
	if SHOW_HANDS or _show_hands_now:
		_draw_hands()
	if _aiming:
		_aim()
	for i in _motes.size():
		var mote := _motes[i]
		var home: Vector3 = mote.get_meta(&"home")
		mote.global_position = home + Vector3(sin(_clock * 0.3 + i), sin(_clock * 0.4 + i * 1.7) * 0.6, cos(_clock * 0.25 + i * 0.9)) * 0.03
	if _onion == null or App.rig == null:
		return
	_box.rotation.x = sin(_clock * 31.0 + 1.0) * _rattle_amp * 0.6
	_box.rotation.z = sin(_clock * 38.0) * _rattle_amp
	var talking := _clock < _talk_until
	var bob := sin(_clock * TAU / 4.5) * 0.0035   # story: only a gentle float, 5-8 mm over 4-5 s, talking or not
	_onion.position.y = lerpf(_onion.position.y, _onion_rest_y + bob + _actions.hop_y, minf(1.0, delta * 10.0))
	_onion.rotation.x = lerpf(_onion.rotation.x, _actions.lean, minf(1.0, delta * 8.0))
	_halo.albedo_color.a = 0.3 if talking else 0.22
	if talking:
		_glow.light_energy = 0.6 + 0.35 * (0.5 + 0.5 * sin(_clock * 9.0))
	elif _cue:
		_glow.light_energy = 0.5 + 0.5 * (0.5 + 0.5 * sin(_clock * 2.0))   # slow: about 3 s a breath
	else:
		_glow.light_energy = 0.6
	var to_look := _actions.look_point() - _orb.global_position
	to_look.y = 0
	if to_look.length() < 0.01:
		return
	var turn := atan2(_face.x, _face.z) - atan2(to_look.x, to_look.z)
	_orb.global_rotation.y = lerp_angle(_orb.global_rotation.y, -turn, minf(1.0, delta * 9.0))


## Onion rises just over the rim.
func _peek() -> void:
	await _move(_orb, _peek_spot(), 0.6)


func _peek_spot() -> Vector3:
	return _mouth + Vector3.UP * PEEK_LIFT


## Onion ducks back under the brew.
func _duck() -> void:
	await _move(_orb, _inside(), 0.3)


## Onion comes up through the opening, then moves aside: to the right of the cauldron
## (seen by the child), away from where the things will land.
func _onion_aside() -> void:
	await _move(_orb, _aside_spot(), 0.8)


## Where Onion waits while the gear comes out: beside the cauldron, away from the panel and the
## landing spot (EntryLayout). After the cauldron made way, beside it there.
func _aside_spot() -> Vector3:
	return _layout.onion_aside_after if _made_way else _layout.onion_aside


## Where Onion rises to after the seating, and waits for the reveal: above the aside spot (EntryLayout).
func _lifted_spot() -> Vector3:
	return _layout.onion_lifted_after if _made_way else _layout.onion_lifted


## Moves Onion smoothly to [param where].
func _orb_to(where: Vector3) -> void:
	_move(_orb, where, 1.2)


## Just beyond the shelf's end on the cauldron's side, high up: where Onion waits during Wei's
## World, never over a cubby, the things or the panel (EntryLayout.onion_rest).
func _beside_shelf() -> Vector3:
	return _layout.onion_rest


# --- The gear and the table mechanism ---------------------------------------

## The prototype's gear is a light stand-in built from a few primitives (a base, a ring, three
## planets on a carrier, a sun gear: a few hundred triangles). The real planetary gear (Hamid
## Bairouk, Blendkit royalty-free, NOT CC0, about 57k triangles) works too: put it at GEAR_FILE and
## set USE_REAL_GEAR. Check its licence and whether the repository is public before committing it.
const GEAR_FILE := "res://entry/assets/planetary-gears.glb"
const USE_REAL_GEAR := false
## It comes out of the cauldron small (the opening is about 9 cm across) and grows to its playing size.
const GEAR_OUT_SCALE := 0.4
const GEAR_PLAY_SCALE := 0.6
## The table panel: width, thickness and depth, metres; the socket's radius, and how far toward
## the child from the panel's middle it sits.
const PANEL := Vector3(0.26, 0.012, 0.22)
const SOCKET_RADIUS := 0.06
const SOCKET_Z := 0.03

var _cog: Node3D


## The gear, hidden until it comes out: a holder whose origin is the middle of the gear's base,
## so it can be set down on a surface by placing the holder there.
func _build_gear() -> void:
	_gear = Node3D.new()
	_gear.name = "Gear"
	add_child(_gear)
	_gear_spin = GearSpin.new()
	_gear.add_child(_gear_spin)
	var model: Node3D
	var player: AnimationPlayer
	if USE_REAL_GEAR and ResourceLoader.exists(GEAR_FILE):
		model = (load(GEAR_FILE) as PackedScene).instantiate()
		_gear.add_child(model)
		player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	else:
		model = _standin_gear()
		_gear.add_child(model)
	var box := _bounds(model)
	_gear_height = box.size.y
	model.position = Vector3(-box.get_center().x, -box.position.y, -box.get_center().z)
	if player != null:
		_gear_spin.read(player.get_node(player.root_node), player.get_animation(player.get_animation_list()[0]))
		player.queue_free()   # the clip does not loop; the parts are turned directly
	_gear.visible = false
	_carry = Carry.new()
	_carry.name = "Carry"
	add_child(_carry)
	_demo = DemoHand.new()
	_demo.name = "DemoHand"
	add_child(_demo)
	_configure_interaction()
	print("ENTRY gear: ", snappedf(box.size.x, 0.001), " m wide, ", snappedf(_gear_height, 0.001), " m high at full size, ", "real" if player != null else "stand-in")


## A planetary gear from primitives: a base, a ring, three planets on a carrier and a sun gear
## on a shaft. About 17.5 cm wide, 8 cm tall, like the real one. Registers its turning parts.
func _standin_gear() -> Node3D:
	var root := Node3D.new()
	var brass := _lit(Color(0.72, 0.55, 0.25), 0.4)
	var steel := _lit(Color(0.62, 0.65, 0.68), 0.6)
	var sage := _lit(Color(0.42, 0.55, 0.45))
	root.add_child(_disc(0.0875, 0.012, 0.006, sage))
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.07
	torus.outer_radius = 0.0875
	torus.material = brass
	ring.mesh = torus
	ring.position.y = 0.03
	root.add_child(ring)
	var carrier := Node3D.new()
	carrier.position.y = 0.024
	root.add_child(carrier)
	carrier.add_child(_disc(0.06, 0.005, 0.0, steel))
	_gear_spin.add(carrier, 0.5)
	for i in 3:
		var planet := _cogwheel(0.02, 8, brass)
		planet.position = Vector3(0.042, 0.012, 0.0).rotated(Vector3.UP, i * TAU / 3.0)
		carrier.add_child(planet)
		_gear_spin.add(planet, -1.5)
	var sun := _cogwheel(0.022, 8, brass)
	sun.position.y = 0.036
	root.add_child(sun)
	_gear_spin.add(sun, 2.0)
	root.add_child(_disc(0.006, 0.078, 0.039, steel))   # the shaft: gives its full height
	return root


func _disc(radius: float, height: float, y: float, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 24
	cylinder.material = material
	mesh.mesh = cylinder
	mesh.position.y = y
	return mesh


## A toothed wheel: a hub with [param teeth] little blocks around it. A node that turns about Y.
func _cogwheel(radius: float, teeth: int, material: Material) -> Node3D:
	var wheel := Node3D.new()
	wheel.add_child(_disc(radius, 0.012, 0.0, material))
	for i in teeth:
		var arm := Node3D.new()
		arm.rotation.y = i * TAU / teeth
		arm.add_child(_slab(Vector3(0.008, 0.012, 0.009), Vector3(radius + 0.002, 0, 0), material))
		wheel.add_child(arm)
	return wheel


## The table panel, shallow, with the socket for the gear and a little window showing a cog
## that turns when the gear is in. Lies on the table where it is clear of the cauldron and the
## shelf, facing the child. The ripple will start from its socket.
func _build_mechanism() -> void:
	_mechanism = Node3D.new()
	_mechanism.name = "Mechanism"
	add_child(_mechanism)
	var spot := _mechanism_spot()
	_mechanism.global_position = spot
	var eye := App.head().global_position
	_mechanism.rotation.y = atan2(eye.x - spot.x, eye.z - spot.z)   # its front (+z) to the child
	var brass := _lit(Color(0.72, 0.55, 0.25), 0.4)
	var sage := _lit(Color(0.36, 0.46, 0.39))
	var dark := _lit(Color(0.07, 0.08, 0.09))
	_mechanism.add_child(_slab(Vector3(PANEL.x + 0.012, 0.006, PANEL.z + 0.012), Vector3(0, 0.003, 0), brass))
	_mechanism.add_child(_slab(Vector3(PANEL.x, 0.006, PANEL.z), Vector3(0, 0.009, 0), sage))
	var well := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = SOCKET_RADIUS
	disc.bottom_radius = SOCKET_RADIUS
	disc.height = 0.002
	disc.material = dark
	well.mesh = disc
	well.position = Vector3(0, PANEL.y + 0.0005, SOCKET_Z)
	_mechanism.add_child(well)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = SOCKET_RADIUS
	torus.outer_radius = SOCKET_RADIUS + 0.008
	torus.material = brass
	ring.mesh = torus
	ring.position = Vector3(0, PANEL.y + 0.0015, SOCKET_Z)
	_mechanism.add_child(ring)
	_mechanism.add_child(_slab(Vector3(0.20, 0.003, 0.04), Vector3(0, PANEL.y + 0.0005, -0.085), dark))   # the window
	_cog = Node3D.new()
	_cog.position = Vector3(0, PANEL.y + 0.004, -0.085)
	_mechanism.add_child(_cog)
	var hub := MeshInstance3D.new()
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.011
	hub_mesh.bottom_radius = 0.011
	hub_mesh.height = 0.004
	hub_mesh.material = brass
	hub.mesh = hub_mesh
	_cog.add_child(hub)
	for i in 8:
		var arm := Node3D.new()
		arm.rotation.y = i * TAU / 8.0
		arm.add_child(_slab(Vector3(0.005, 0.004, 0.006), Vector3(0.0125, 0, 0), brass))
		_cog.add_child(arm)
	_mech_spin = GearSpin.new()
	_mechanism.add_child(_mech_spin)
	_mech_spin.add(_cog, 1.2)
	_socket_at = _mechanism.to_global(Vector3(0, PANEL.y, SOCKET_Z))
	_ripple_origin = _socket_at
	# Where the gear lands: beside the cauldron, clear of it and the panel, in reach (EntryLayout).
	_gear_rest = _layout.gear_rest
	print("ENTRY mechanism: ", _away(spot), " m away at ", snappedf(rad_to_deg(_ahead.signed_angle_to(Vector3(spot.x - eye.x, 0.0, spot.z - eye.z).normalized(), Vector3.UP)), 1), " degrees")


## Where the panel goes in the opening (EntryLayout): on the table, the socket in reach, clear of
## the cauldron and of where the gear lands. The layout first takes the cauldron's real height.
func _mechanism_spot() -> Vector3:
	_layout.set_cauldron(_box.global_position, _rim)
	return _layout.mechanism


## The cauldron and the panel (with the gear in it) at their spots for the revealed room, where
## Wei's bench will be clear of them (EntryLayout.MAKE_WAY): gliding there over [param seconds], or
## at once (0). Onion, if waiting beside the cauldron, goes along. The ripple starts from the socket
## where it ends up. Back to the opening's spots with [param back].
func _make_way(seconds := 1.2, back := false) -> void:
	if _layout == null or _made_way != back:
		return
	_made_way = not back
	var pot := _layout.cauldron if back else _layout.cauldron_after
	var plate := _layout.mechanism if back else _layout.mechanism_after
	var yaw := _layout.mechanism_yaw if back else _layout.mechanism_yaw_after
	pot.y = _box.global_position.y
	plate.y = _mechanism.global_position.y
	var lift := pot - _box.global_position
	var slide := plate - _mechanism.global_position
	var from_aside := _layout.onion_aside_after if back else _layout.onion_aside
	var from_lifted := _layout.onion_lifted_after if back else _layout.onion_lifted
	# Onion goes along with the cauldron if it waits at its aside spot or at the lifted one (after the
	# seating), to the same kind of spot for the new places.
	var lifted := _orb.global_position.distance_to(from_lifted) < 0.05
	var orb_goes := lifted or _orb.global_position.distance_to(from_aside) < 0.05
	var orb_to := _lifted_spot() if lifted else _aside_spot()
	var gear_goes := is_instance_valid(_gear) and _gear.visible and _gear.global_position.distance_to(_socket_at) < 0.02
	if _zones != null and is_instance_valid(_zones):
		_zones.draw(_layout, EntryLayout.REVEAL | EntryLayout.SHELF if _made_way else EntryLayout.SETUP | EntryLayout.OPENING)
	_mouth += lift
	_socket_at = _layout.socket if back else _layout.socket_after
	_socket_at.y = _mechanism.global_position.y + PANEL.y
	_ripple_origin = _socket_at
	if lift.length() < 0.005 and slide.length() < 0.005:
		return
	print("ENTRY make way: the cauldron ", snappedf(lift.length() * 100.0, 1), " cm, the panel ", snappedf(slide.length() * 100.0, 1), " cm",
			" (back to the opening)" if back else "")
	if seconds <= 0.0:
		_box.global_position = pot
		_mechanism.global_position = plate
		_mechanism.rotation.y = yaw
		if gear_goes:
			_gear.global_position = _socket_at
			_gear.rotation.y = yaw
		if orb_goes:
			_orb.global_position = orb_to
		return
	var tween := _runner.create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_box, "global_position", pot, seconds)
	tween.tween_property(_mechanism, "global_position", plate, seconds)
	tween.tween_property(_mechanism, "rotation:y", yaw, seconds)
	if gear_goes:
		tween.tween_property(_gear, "global_position", _socket_at, seconds)
		tween.tween_property(_gear, "rotation:y", yaw, seconds)
	if orb_goes:
		tween.tween_property(_orb, "global_position", orb_to, seconds)
	await tween.finished


## The gear pops up through the brew (small, with a little overshoot), clears the rim, then
## arcs out, tilting and growing, and stands within reach. No flash, no sound but its own.
func _emerge_gear() -> void:
	_gear.visible = true
	_gear.scale = Vector3.ONE * GEAR_OUT_SCALE
	_gear.rotation = Vector3.ZERO
	var start := _mouth + Vector3.DOWN * (_gear_height * GEAR_OUT_SCALE + 0.012)
	var clear := Vector3(_mouth.x, _box.global_position.y + _rim + 0.05, _mouth.z)
	_gear.global_position = start
	print("ENTRY gear: out of the cauldron, ", snappedf(_gear_height * GEAR_OUT_SCALE, 0.001), " m tall, to ", _away(_gear_rest), " m away")
	var tween := _runner.create_tween()
	tween.tween_property(_gear, "global_position", clear, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_surprise)
	tween.tween_method(_gear_arc.bind(clear, _gear_rest, 0.06), 0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


## One step of the arc from [param from] to [param to]: it grows, tilts, comes down upright.
func _gear_arc(k: float, from: Vector3, to: Vector3, height: float) -> void:
	_gear.global_position = from.lerp(to, k) + Vector3.UP * height * 4.0 * k * (1.0 - k)
	_gear.scale = Vector3.ONE * lerpf(GEAR_OUT_SCALE, GEAR_PLAY_SCALE, k)
	_gear.rotation = Vector3(sin(k * PI) * 0.35, 0.0, 0.0)


## PLACEHOLDER (the child will carry it): the gear lifts and sets itself into the socket, then
## the gears and the panel's cog start turning.
func _dock_gear() -> void:
	var from := _gear.global_position
	var tween := _runner.create_tween()
	tween.tween_method(func(k: float) -> void:
		_gear.global_position = from.lerp(_socket_at, k) + Vector3.UP * 0.05 * 4.0 * k * (1.0 - k)
		_gear.scale = Vector3.ONE * GEAR_PLAY_SCALE, 0.0, 1.0, 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_dock_at_once()
	Events.feedback.emit(&"hint", _socket_at)


## The gear in the socket, upright, turning; the panel's cog turning.
func _dock_at_once() -> void:
	_gear.visible = true
	_gear.scale = Vector3.ONE * GEAR_PLAY_SCALE
	_gear.global_position = _socket_at
	_gear.rotation = Vector3(0.0, _mechanism.rotation.y, 0.0)
	_gear_spin.running = true
	_mech_spin.running = true


## The gear standing on the table where it landed, not yet picked up.
func _gear_to_rest() -> void:
	_gear.visible = true
	_gear.scale = Vector3.ONE * GEAR_PLAY_SCALE
	_gear.global_position = _gear_rest
	_gear.rotation = Vector3.ZERO


## The front of the cauldron's rim: where a tap goes.
func _rim_point() -> Vector3:
	return _box.global_position + Vector3.UP * _rim + _toward_child() * (CAULDRON_WIDTH * 0.35)


## The simulated room (desktop and tests only) has loose props on its table: a cup, bottle, book
## and apple, for Wei's find-the-object task. The opening hides them so the table is clear and
## nothing looks like it came out of the cauldron; the first visit shows them again when it ends.
const SIM_PROPS := ["Cup", "Bottle", "Book", "Apple"]

static func show_sim_props(on: bool) -> void:
	if App.reality == null or not is_instance_valid(App.reality):
		return
	for prop_name: String in SIM_PROPS:
		var prop := App.reality.find_child(prop_name, true, false) as Node3D
		if prop != null:
			prop.visible = on


## Where Onion looks to peek into the opening from its spot at the rim: a point down in the
## cauldron, off to one side and away from the child, so it turns three-quarters (not straight down).
func _peer_point() -> Vector3:
	var away := -_toward_child()
	var side := away.cross(Vector3.UP).normalized()
	return _mouth + Vector3.DOWN * 0.04 + away * 0.05 + side * 0.04


## While the child has not tapped yet: Onion looks at the rim where the hand taps, then at the
## child, over and over, leaning a little toward the rim; after a long wait a small hop and
## a look at the rim ask again. Stops by itself when the tap comes (or the part is cut).
func _watch_for_tap() -> void:
	var runner := _runner
	var at_rim := true
	var waited := 0.0
	var hopped := false
	while not _tapped and runner == _runner and is_instance_valid(runner):
		_attend(_rim_point() if at_rim else null)
		_actions.lean_in(runner, at_rim)
		var seconds := 2.2 if at_rim else 1.4
		await runner.wait(seconds)
		waited += seconds
		at_rim = not at_rim
		if waited > 10.0 and not hopped:
			hopped = true
			_actions.hop(runner)
	if runner == _runner and is_instance_valid(runner):
		_attend(null)
		_actions.lean_in(runner, false)


## Onion shifts a little from side to side over the opening, twice: searching.
func _search() -> void:
	var rim := _peek_spot()
	var side := _toward_child().cross(Vector3.UP).normalized()
	await _move(_orb, rim + side * 0.015, 0.45)
	await _move(_orb, rim - side * 0.012, 0.6)
	await _move(_orb, rim, 0.4)


## Onion looks at [param what] (a Node3D or a position), or at the child when null.
func _attend(what: Variant) -> void:
	_actions.attention = what


## The cauldron trembles by [param amount] radians (0: still).
func _rattle(amount: float) -> void:
	_rattle_amp = amount


## One metallic knock from inside: the cauldron jolts once.
func _knock() -> void:
	_sounds.play(&"knock", _box.global_position)
	var tween := _runner.create_tween()
	tween.tween_property(self, "_rattle_amp", 0.06, 0.07)
	tween.tween_property(self, "_rattle_amp", 0.006, 0.3).set_trans(Tween.TRANS_SINE)
	await tween.finished


## Onion pops up out of the cauldron: a rounded rise with a small overshoot, then settles.
func _pop() -> void:
	_sounds.play_pop(_peek_spot())
	var tween := _runner.create_tween()
	tween.tween_property(_orb, "global_position", _peek_spot() + Vector3.UP * 0.01, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_orb, "global_position", _peek_spot(), 0.2).set_trans(Tween.TRANS_SINE)
	await tween.finished


## The gear is out: Onion hops with a surprised "!".
func _surprise() -> void:
	_recoil()   # a small backward hop (0.25 s), settling over 0.6 s
	_actions.mark(_runner, "!")
	_attend(_gear)   # follows the gear's flight with a smooth turn


func _recoil() -> void:
	var back := (_orb.global_position - _gear.global_position)
	back.y = 0.0
	back = back.normalized() * 0.04 if back.length() > 0.001 else Vector3.ZERO
	var home := _orb.global_position
	await _move(_orb, home + back, 0.25)
	await _move(_orb, home, 0.6)


## Waits for the child to pick the gear up. Until the interaction chat's Carry is real
## (USE_REAL_CARRY), a stand-in plays the child doing it.
func _child_picks_up() -> void:
	var runner := _runner
	if USE_REAL_CARRY and _carry.has_been_picked_up():
		return
	if USE_REAL_CARRY:
		if not _carry.enabled:
			_carry.begin(_gear, _socket_at)
		_carry.picked_up.connect(func() -> void:
			if is_instance_valid(runner):
				runner.picked_up.emit(), CONNECT_ONE_SHOT)
		if simulate_child:
			_pretend_pick_up(runner)
	else:
		_stand_in_pickup(runner)
	await runner.picked_up


func _pretend_pick_up(runner: PartRunner) -> void:
	await runner.wait(0.5)
	if is_instance_valid(runner):
		_carry.picked_up.emit()


func _stand_in_pickup(runner: PartRunner) -> void:
	await runner.wait(1.5)
	runner.picked_up.emit()


## Waits for the child to set the gear into the socket.
func _child_sets_in() -> void:
	var runner := _runner
	if USE_REAL_CARRY and _carry.has_docked():
		return   # the child already set it in, while Onion talked
	if USE_REAL_CARRY:
		if not _carry.held:   # a jump straight to Set in: the child has to pick it up as well
			_carry.begin(_gear, _socket_at)
		_carry.docked.connect(func() -> void:
			if is_instance_valid(runner):
				runner.docked.emit(), CONNECT_ONE_SHOT)
		if simulate_child:
			_carry.simulate(0.3)
	else:
		_stand_in_set_in(runner)
	await runner.docked


func _stand_in_set_in(runner: PartRunner) -> void:
	await runner.wait(1.2)
	await _dock_gear()
	runner.docked.emit()


func _slab(size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	box.material = material
	mesh.mesh = box
	mesh.position = at
	return mesh


func _lit(colour: Color, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = metallic
	material.roughness = 0.55
	return material


# --- The reveal --------------------------------------------------------------

## A slow, soft ring of light spreads from the cauldron across the play circle. As it
## passes each spot, that part of the workshop appears, and where it meets a real
## surface (depth) a faint glint shows on it: the ripple travels over the real room.
## No flash, no camera movement.
func _ripple() -> void:
	_sounds.play(&"reveal", _ripple_origin)
	_surface_points.clear()
	_sample_room()
	var reach := PLAY_RADIUS * 1.6 + _away(_ripple_origin)
	for wave in 3:   # three rings, a second apart, each fainter
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.96
		torus.outer_radius = 1.0
		torus.rings = 96
		var light := StandardMaterial3D.new()
		light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		light.albedo_color = Color(1.0, 0.85, 0.5, 0.35 - wave * 0.1)
		torus.material = light
		ring.mesh = torus
		add_child(ring)
		ring.add_to_group(&"entry_transient")
		ring.global_position = _ripple_origin + Vector3.UP * 0.004
		var spread := _runner.create_tween()
		spread.tween_method(_spread.bind(ring, light, reach, light.albedo_color.a, wave == 0), 0.0, 1.0, RIPPLE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		spread.tween_callback(ring.queue_free)
		await _wait(1.0)
	await _wait(RIPPLE_SECONDS - 1.0)


## One step of a ring: its radius grows, it fades; the first ring shows what it passes.
func _spread(k: float, ring: MeshInstance3D, light: StandardMaterial3D, reach: float, alpha: float, shows: bool) -> void:
	var radius := maxf(0.02, k * reach)
	ring.scale = Vector3(radius, 0.02, radius)
	light.albedo_color.a = alpha * (1.0 - k)
	if not shows:
		return
	for point in _surface_points:
		if not point.get(&"shown", false) and (point.position as Vector3).distance_to(_ripple_origin) <= radius:
			point.shown = true
			_glint(point.position, point.normal)
	for detail in _details:
		if is_instance_valid(detail) and not detail.get_meta(&"shown", false) and detail.global_position.distance_to(_ripple_origin) <= radius:
			detail.set_meta(&"shown", true)
			detail.visible = true
			_runner.create_tween().tween_property(detail, "scale", detail.get_meta(&"size", Vector3.ONE), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## PLACEHOLDER for a depth ripple (later: drawn on the depth image itself, every pixel).
## Casts a fan of depth rays from the eyes over what the headset sees and keeps the
## real surfaces they hit. Depth only covers what is in view, about 90 degrees ahead.
const GLINT_ROWS := 7
const GLINT_COLUMNS := 15
func _sample_room() -> void:
	_surface_points.append_array(_scan_room())
	print("ENTRY ripple: ", _surface_points.size(), " real surface points of ", GLINT_ROWS * GLINT_COLUMNS, " rays")


## The real surfaces the fan of depth rays hits now: [{position, normal}, ...].
func _scan_room() -> Array[Dictionary]:
	var points: Array[Dictionary] = []
	var eye := App.head().global_transform
	var ahead := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	for row in GLINT_ROWS:
		var down := lerpf(-10.0, 65.0, row / float(GLINT_ROWS - 1))   # a little above level to steeply down
		for column in GLINT_COLUMNS:
			var across := lerpf(-50.0, 50.0, column / float(GLINT_COLUMNS - 1))
			var ray := ahead.rotated(Vector3.UP, deg_to_rad(across))
			ray = ray.rotated(ray.cross(Vector3.UP).normalized(), -deg_to_rad(down))
			var found: Dictionary = App.reality.hit(eye.origin, ray)
			if not found.is_empty() and (found.position as Vector3).distance_to(eye.origin) < 3.0:
				points.append({position = found.position, normal = found.normal})
	return points


## A faint, soft disc of light lying on a real surface, fading out.
func _glint(at: Vector3, normal: Vector3) -> void:
	var disc := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.12
	var light := _material(Color(1.0, 0.85, 0.5, 0.0), true)
	light.albedo_texture = _soft_dot()
	quad.material = light
	disc.mesh = quad
	add_child(disc)
	disc.add_to_group(&"entry_transient")
	var up := normal.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	disc.global_transform = Transform3D(Basis(side, up.cross(side), up), at + up * 0.005)   # the quad's face along the normal
	var fade := _runner.create_tween()
	fade.tween_property(light, "albedo_color:a", 0.3, 0.5)
	fade.tween_property(light, "albedo_color:a", 0.0, 1.5)
	fade.tween_callback(disc.queue_free)


## A round, soft-edged dot, made once.
var _dot: GradientTexture2D
func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		_dot = GradientTexture2D.new()
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		var fall := Gradient.new()
		fall.set_color(0, Color(1, 1, 1, 1))
		fall.set_color(1, Color(1, 1, 1, 0))
		_dot.gradient = fall
	return _dot


## PLACEHOLDER workshop around the seated child: Wei's shelf (built at the start),
## drifting motes, and outside the play circle a soft doorway of light: a glimpse of
## a larger world. Real assets later.
func _build_workshop() -> void:
	var eye := App.head().global_position
	var ahead := -_left.rotated(Vector3.UP, PI * 0.5)
	var table_y := _box.global_position.y
	var around := func(degrees: float, distance: float, height: float) -> Vector3:
		return Vector3(eye.x, height, eye.z) + ahead.rotated(Vector3.UP, deg_to_rad(degrees)) * distance
	# Beyond the circle: a soft doorway of light, ahead and to the right. Only to look at.
	var door := Node3D.new()
	var glow := _shape(QuadMesh.new(), Vector3(0.45, 0.8, 1.0), _material(Color(1.0, 0.85, 0.6, 0.35), true))
	door.add_child(glow)
	var beyond := OmniLight3D.new()
	beyond.light_color = Color(1.0, 0.85, 0.6)
	beyond.light_energy = 0.3
	beyond.omni_range = 1.2
	beyond.position = Vector3(0, 0, 0.3)
	door.add_child(beyond)
	_detail(door, around.call(-30.0, PLAY_RADIUS + 0.8, eye.y))
	door.look_at(Vector3(eye.x, door.global_position.y, eye.z), Vector3.UP)
	door.rotate_object_local(Vector3.UP, PI)   # its face to the child
	print("ENTRY workshop: ", _details.size(), " details, the doorway ", _away(door.global_position), " m away")


## Puts [param detail] at [param where], hidden until the ripple reaches it.
func _detail(detail: Node3D, where: Vector3) -> void:
	if detail.get_parent() == null:
		add_child(detail)
	detail.global_position = where
	detail.set_meta(&"size", detail.scale)
	detail.scale = Vector3.ONE * 0.001
	detail.visible = false
	_details.append(detail)


func _shape(mesh: PrimitiveMesh, size: Vector3, material: Material) -> MeshInstance3D:
	mesh.material = material
	var shape := MeshInstance3D.new()
	shape.mesh = mesh
	if mesh is QuadMesh:
		(mesh as QuadMesh).size = Vector2(size.x, size.y)
	else:
		shape.scale = size / _unit(mesh)
	return shape


## The size of a primitive mesh at its defaults, metres.
func _unit(mesh: PrimitiveMesh) -> Vector3:
	return mesh.get_aabb().size.max(Vector3.ONE * 0.0001)


func _material(colour: Color, glows := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	if colour.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glows:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


# --- Helpers -----------------------------------------------------------------

## Moves [param thing] smoothly to [param where] in [param seconds].
func _move(thing: Node3D, where: Vector3, seconds: float) -> void:
	await _runner.move(thing, where, seconds)


## Quiet piano, fading in, looping.
func _start_music() -> void:
	var stream: AudioStreamMP3 = MUSIC.duplicate()
	stream.loop = true
	_music.stream = stream
	_music.volume_db = -60.0
	add_child(_music)
	_music.play()
	print("ENTRY music playing: ", _music.playing)
	create_tween().tween_property(_music, "volume_db", MUSIC_DB, 4.0)


# --- Interaction -------------------------------------------------------------
# What Carry needs to know about the room (the interaction chat's; Carry and DemoHand do the rest).

## THE delay: how long the gear waits in view, untouched, before the teaching hand shows how to pick it
## up (seconds; 0 = never). Only the gesture shows, on the gear itself: never a place, never an answer.
const PICKUP_REMINDER_SECONDS := 14.0
## DEBUG: this key puts the gear out on the table and turns Carry on, so a click-hold, a drag and
## a release (the mouse hand) try the whole pick-up and set-in without the story.
const TRY_CARRY_KEY := KEY_G

## Tells Carry where the table is, how far the child reaches, how the panel faces, and what to keep
## clear; and lets the teaching hand remind a child who has not picked the gear up. The hand only
## ever shows the gesture: it never carries the gear anywhere.
func _configure_interaction() -> void:
	_carry.configure(_gear_rest.y, App.head().global_position, maxf(_cauldron_distance, 0.45) + 0.15,
		_mechanism.rotation.y, _box.global_position, CAULDRON_WIDTH * 0.5 + 0.06)
	_carry.follow(_box, _mechanism)   # they move at the reveal
	_carry.remind_after = PICKUP_REMINDER_SECONDS
	_carry.reminder_due.connect(func() -> void: _demo.pinch_lift(_gear))
	_carry.picked_up.connect(_demo.stop)
	_carry.docked.connect(_demo.stop)


func _unhandled_key_input(event: InputEvent) -> void:
	if DEBUG and event is InputEventKey and event.pressed and not event.echo and event.keycode == TRY_CARRY_KEY:
		_try_carry()


## DEBUG: the gear on the table, ready to be picked up; when it docks it turns, like the story will.
func _try_carry() -> void:
	if _carry == null or _gear == null or _mechanism == null:
		return   # not built yet: the setup is still on
	_demo.stop()
	_gear.visible = true
	_gear.scale = Vector3.ONE * GEAR_PLAY_SCALE
	_gear.global_position = _gear_rest
	_gear.rotation = Vector3.ZERO
	_gear_spin.running = false
	_mech_spin.running = false
	_carry.begin(_gear, _socket_at)
	var driver := _desktop_driver()
	if driver != null:   # the mouse hand sits as far out as the gear, so a click on it takes it
		driver.depth = clampf(App.head().global_position.distance_to(Carry.middle_of(_gear)) - 0.05, 0.2, 0.9)
	_carry.docked.connect(func() -> void:
		_gear_spin.running = true
		_mech_spin.running = true, CONNECT_ONE_SHOT)
	print("ENTRY try-carry: the gear is out; click-hold it, drag it to the socket, let go")


## The mouse driver (a child of Main, not of the scene), or null in a headset.
func _desktop_driver() -> DesktopDriver:
	for child in App.main.get_children():
		if child is DesktopDriver:
			return child as DesktopDriver
	return null
