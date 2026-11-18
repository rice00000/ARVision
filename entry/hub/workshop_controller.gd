class_name WorkshopController
extends Node
## The workshop after the opening (Scene 7, Megan's decisions of Nov 17, `SCENE_REVIEW_DECISIONS.md`):
## hub → game → hub → … → Finish visit → closing.
##
## * **The games** sit in a ring on the cauldron's still fog ([ImpressionRing]). One press picks any (a side one
##   turns to the front first). The first visit offers the shelf alone: it rises out of the cauldron, Onion says
##   "Welcome to the workshop." and looks at it; after ~5 s with no choice the teaching hand shows aim-and-pinch.
##   After the first game the dots rise into the ring ("There are more waiting.", once). Turn to fit joins
##   only when it can run. Nothing shown can't be pressed (no sealed choices).
## * **The gear** on the table is the child's menu ([GearMenu]): Finish visit, and Home (Wei's room) from after the
##   first game, its line "The room has a few surprises left in it." after the next game (≤ 2 lines between
##   the child's actions). The gear's buttons are off during a game.
## * **During a game** the ring goes quiet (halos and fog fade) and the exit-task token stands low beside the
##   cauldron: a pinch on it ends the game (the round is skipped), "We can come back to these.", back to the hub.
## * **Pause** (headset menu, Staff tools) pauses the world; the running game is told (Summonable.pause/resume).
##   Nothing in the hub times out, and a lost hand never counts as a choice.

signal _picked_signal

const CUE_AFTER := 5.0          # seconds without a choice before the teaching hand shows aim-and-pinch (first visit)
const WELCOME := "Welcome to the workshop."
const MORE := "There are more waiting."
const SURPRISES := "The room has a few surprises left in it."
const LEFT_EARLY := "We can come back to these."
const ORDER: Array[StringName] = [&"shelf", &"dots", &"turn_to_fit"]

var workshop: Workshop
var activities: Array[Summonable] = []
var ring: ImpressionRing
var gear: GearMenu
var exit_token: HubButton
var current: Summonable
var state := &"idle"            # &"hub", &"game", &"home", &"closing", &"closed"
var played: Array[StringName] = []
var said_more := false
var said_surprises := false
var _picked: StringName = &""
var _demo: DemoHand
var _was_paused := false
var _exited := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # sees the pause come and go


## Runs the workshop until the closing has played. [param first]: a DEV jump's game to start with
## (&"shelf" / &"dots"; &"motion" = &"dots"), or &"". [param welcome]: the opening's own flow (first visit).
## [param closing]: the visit's closing (MotionVisit.closing). [param home]: goes to Wei's room and back.
func run(on: Workshop, list: Array, first := &"", welcome := false, closing := Callable(), home := Callable()) -> void:
	workshop = on
	for a in list:
		activities.append(a as Summonable)
		add_child(a)
	_demo = DemoHand.new()
	add_child(_demo)
	_build_ring()
	_build_gear()
	_build_exit()
	if first == &"motion":
		first = &"dots"
	var activity := _activity(first)
	if activity != null:
		await _offer(activity, false)
		await _run(activity)
	else:
		await _offer(_activity(&"shelf"), welcome)
	while true:
		_picked = &""
		var choice := await _hub()
		if choice == &"gear_finish":
			break
		if choice == &"gear_home":
			if home.is_valid():
				state = &"home"
				gear.set_enabled(false)
				ring.quiet()
				ring.visible = false   # not over Wei's room
				await home.call()
				ring.visible = true
				ring.wake()
			continue
		await _run(_activity(choice))
	state = &"closing"
	await _closing_starts()
	if closing.is_valid():
		await closing.call()
	state = &"closed"


# --- The hub ---------------------------------------------------------------------------------------

## The hub: waits for a game's choice or a gear button.
func _hub() -> StringName:
	state = &"hub"
	SceneMarker.show_text("Hub")
	ring.wake()
	gear.set_enabled(true)
	exit_token.visible = false
	exit_token.set_open(false)
	if workshop != null:
		workshop.float_to(_onion_spot(), 1.0)
	var waited := 0.0
	var cued := false
	while _picked == &"":
		await get_tree().process_frame
		if get_tree().paused:
			continue
		waited += get_process_delta_time()
		if played.is_empty() and not cued and waited > CUE_AFTER and ring.front() != null:
			cued = true
			_demo.aim_pinch(ring.front().target)   # shows aim-and-pinch on the shelf: no words
	_demo.stop()
	print("HUB choice: ", _picked)
	return _picked


## A game's impression rises out of the cauldron into the ring (and comes to the front).
## [param welcome]: Onion's "Welcome to the workshop." then a look at it (the first visit).
func _offer(activity: Summonable, welcome := false) -> void:
	if activity == null or _impression_of(activity) != null:
		return
	var impression := activity.make_impression() as Impression
	if impression == null:
		return
	await ring.add(impression, _mouth())
	if welcome:
		await Onion.line(WELCOME, self)
	if workshop != null:
		workshop.attend(impression.global_position)   # Onion looks at it (attention cue, no words)


func _run(activity: Summonable) -> void:
	if activity == null:
		return
	state = &"game"
	current = activity
	_exited = false
	gear.set_enabled(false)
	_demo.stop()
	ring.quiet(0.3)
	await HubGlow.quiet_all(0.3)
	await ring.sink(_mouth(), 0.9)   # Megan, Nov 18: the pieces sink into the cauldron with the fog during a game
	exit_token.visible = true
	exit_token.set_open(true)
	if workshop != null:
		workshop.attend(null)
	print("HUB game: ", activity.id())
	# Wei's bench board can reach the socket at the front right too (Megan's laptop test, Nov 18): it always fades
	# under the board during the shelf, as before (the layout's zones miss the board's real edge on some tables).
	var under_bench := activity.id() == &"shelf" and workshop != null
	if under_bench:
		workshop.hide_socket(true)
	activity.summon(_workspace())
	var outcome: StringName = await activity.finished
	if under_bench:
		workshop.hide_socket(false)
	exit_token.set_open(false)
	exit_token.visible = false
	print("HUB ", activity.id(), " finished: ", outcome)
	Events.report(&"hub_activity_finished", {activity = activity.id(), outcome = outcome})
	activity.fold()
	current = null
	await ring.rise(_mouth())   # and rise again with it, back at the hub
	var first_game := played.is_empty()
	if not played.has(activity.id()):
		played.append(activity.id())
	ring.wake()
	# After the first game: the dots rise in, Home appears on the gear. One line each, at most 2 lines
	# before the child's next action (the game's own ending line was the first).
	var dots := _activity(&"dots")
	if not said_more and dots != null and dots.is_available() and _impression_of(dots) == null:
		said_more = true
		await _offer(dots)
		await Onion.line(MORE, self)
	elif first_game == false and gear.has_home() and not said_surprises:
		said_surprises = true
		await Onion.line(SURPRISES, self)
	if not gear.has_home():
		gear.set_home(true)   # silent now: its line comes after the next game (the line budget)
	for a in activities:   # Turn to fit (or anything) that can run now
		if a.is_available() and _impression_of(a) == null and a.id() != &"dots":
			await _offer(a)


## A game is left early through the exit token: its round is dropped (skipped), "We can come back to these."
func _exit_game() -> void:
	if current == null or _exited:
		return
	_exited = true
	print("HUB exit: ", current.id())
	Events.report(&"task_exited", {activity = current.id()})
	current.leave()


func _closing_starts() -> void:
	gear.set_enabled(false)
	_demo.stop()
	exit_token.visible = false
	await ring.sink(_mouth())   # Scene 10: the ring and its fog sink quietly into the cauldron first


# --- Building ----------------------------------------------------------------------------------------

func _build_ring() -> void:
	var mouth := _mouth()
	ring = ImpressionRing.make(self, [] as Array[Impression], Vector3(mouth.x, mouth.y + ImpressionRing.ABOVE_RIM, mouth.z), App.head().global_position, mouth)
	ring.chosen.connect(func(impression: Impression) -> void: _pick(impression.kind))
	Events.selected.connect(func(_hand: StringName, target: Target, _o: Vector3, _d: Vector3) -> void: _on_ring_press(target))
	Events.touched.connect(func(_hand: StringName, target: Target) -> void: _on_ring_press(target))


func _on_ring_press(target: Target) -> void:
	if state != &"hub" or target == null or get_tree().paused:
		return
	var impression := ring.impression_for(target)
	if impression != null:
		ring.press(impression)


func _build_gear() -> void:
	var at := _mouth() + Vector3.RIGHT * 0.2
	# The socket (the gear turns in it): the gear node itself can be unplaced after a jump.
	var socket: Node3D = workshop.get("_mechanism") if workshop != null else null
	if socket != null and is_instance_valid(socket):
		at = socket.global_position + Vector3.UP * 0.03
	elif workshop != null and workshop.gear_node() != null:
		at = workshop.gear_node().global_position + Vector3.UP * 0.03
	gear = GearMenu.make(self, at, App.head().global_position, false)
	_update_stones()
	Events.inventory_changed.connect(_update_stones)
	gear.chosen.connect(_pick)
	gear.set_enabled(false)


func _build_exit() -> void:
	exit_token = HubButton.make(&"exit_task", &"exit", 0.05)
	exit_token.pinch_only = true   # a sweep through it never counts (a sweep is the dots' answer)
	add_child(exit_token)
	var pot := workshop.cauldron().global_position if workshop != null else _mouth()
	var eye := App.head().global_position
	var to_eye := Vector3(eye.x - pot.x, 0.0, eye.z - pot.z).normalized()
	# Low beside the cauldron, a little toward the middle of the table (Megan, Nov 17), and now IN FRONT of it,
	# toward the child: at its side it sat half under Wei's bench board (Megan's laptop test, Nov 18).
	var middle := workshop.layout.table.origin if workshop != null and workshop.layout != null else eye + Vector3(0, -0.5, -0.6)
	var inward := Vector3(middle.x - pot.x, 0.0, middle.z - pot.z)
	inward = (inward - to_eye * inward.dot(to_eye)).normalized()
	exit_token.global_position = pot + to_eye * 0.17 + inward * 0.06 + Vector3.UP * 0.06
	exit_token.face(eye)
	exit_token.visible = false
	exit_token.pressed.connect(func(_id: StringName) -> void: _exit_game())


func _update_stones() -> void:
	var inventory := App.module(&"Inventory")
	if gear != null and inventory != null and inventory.has_method(&"count"):
		gear.set_stones(inventory.count(&"magic_stone"))


func _pick(id: StringName) -> void:
	if _picked == &"" and state == &"hub":
		_picked = id
		_picked_signal.emit()


# --- Pause ---------------------------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var paused := get_tree().paused
	if paused == _was_paused:
		return
	_was_paused = paused
	print("HUB ", "paused" if paused else "resumed", " (", state, ")")
	if current != null:
		if paused:
			current.pause()
		else:
			current.resume()


# --- Helpers -------------------------------------------------------------------------------------------

func _impression_of(activity: Summonable) -> Impression:
	for impression in ring.impressions:
		if is_instance_valid(impression) and impression.kind == activity.id():
			return impression
	return null


func _activity(id: StringName) -> Summonable:
	for a in activities:
		if a.id() == id:
			return a
	return null


func _mouth() -> Vector3:
	if workshop != null and is_instance_valid(workshop):
		return workshop.mouth()
	return App.head().global_position + Vector3(0, -0.4, -0.6)


## Where Onion waits in the hub: beside the cauldron, lifted (the layout's reveal spot).
func _onion_spot() -> Vector3:
	if workshop != null and workshop.layout != null:
		return workshop.layout.onion_reveal
	return workshop.onion_position() if workshop != null else Vector3.ZERO


## Wei's bench frame (where the opening planned the shelf), or straight ahead.
func _workspace() -> Transform3D:
	if workshop != null and workshop.layout != null:
		return workshop.layout.bench
	return Transform3D(Basis.IDENTITY, App.head().global_position)
