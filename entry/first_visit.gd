class_name FirstVisit
extends Node
## Onion leads Shadow Match, then offers more shapes or the motion activity.

const Tidy := preload("res://trials/tidy/tidy_trial.gd")
const SHELF_TASK := preload("res://content/tasks/tidy_shelf.tres")
const TUTORIAL_LEVEL := &"shadow"

## DEV jump: &"motion" starts straight at the motion route (the shelf level is skipped). Single use.
static var start_with: StringName = &""
## Set by the opening (entry.gd) when the shelf follows the reveal: Onion welcomes the child, notices the
## shapes and invites them HERE, with the shelf level already running from the moment the ripple has shown
## it, so the child can pick shapes up and sort while Onion talks (Megan, Nov 10 and 11). Picking one up
## ends the talk (the line being said finishes); finishing the level cuts it. Single use.
static var invite := false

## Seconds of quiet at the very end of scene one.
const QUIET_END := 4.0

var _fits_said := false
var _started := false      # the child picked a shape up or placed one: the invitation is over
var _rounds_won := 0
var _rounds_ended := 0
var _onion: Workshop
var _shelf_spot := Vector3.INF
var _reminder: ShelfReminder   # a hand that shows how to pick a shape up, if the child waits (interaction chat)

@onready var _motion: MotionVisit = $Motion


func run() -> void:
	_onion = App.main.get_node_or_null(^"Workshop") as Workshop
	App.reality.apply_view(App.session.base_view)
	if not App.reality.is_settled:
		await App.reality.settled
	if start_with == &"motion":
		start_with = &""
		Tidy.seed_next = 0
		Tidy.things_arrive = true
		await get_tree().create_timer(0.5, false).timeout
		await _motion.run_motion()
		return
	Tidy.onion_voice = true
	Events.reported.connect(_on_reported)
	Events.trial_ended.connect(func(_skill: StringName, success: bool, _data: Dictionary) -> void:
		_rounds_ended += 1
		if success:
			_rounds_won += 1)
	_reminder = ShelfReminder.new()
	add_child(_reminder)
	var skip := App.main.get_node_or_null(^"LineSkip") as LineSkip
	if skip != null:   # the invitation is an instruction until the child has taken a shape
		skip.guards.append(_invitation_open)
	SceneMarker.show_text("Shelf")
	_play()   # not awaited: Onion speaks while the first round sets up
	for _frame in 30:
		await get_tree().process_frame
		if App.session.trial is Node3D:
			_shelf_spot = (App.session.trial as Node3D).global_position
			break
	# The shelf level is running from here: the child may pick shapes up and sort while Onion talks.
	# Picking a shape up is acceptance: the remaining lines are skipped, so nothing holds the child up;
	# "It fits..." still comes at the first correct placement.
	if invite:
		invite = false
		await _invitation()
	else:
		await get_tree().create_timer(0.6, false).timeout
	if _onion != null and _shelf_spot != Vector3.INF:
		_onion.attend(_shelf_spot)   # looks toward the shelf
	if not _started:
		await say("The shapes on the shelf show where things go.")
	if not _started:
		await say("Pick whichever one you'd like to start with.")
	if _onion != null:
		_onion.attend(null)
	_reminder.start()   # the invitation is done: if the child waits, the hand shows how to pick one up


## Onion notices the shapes and invites the child (the approved reveal lines, moved here from entry.gd
## on Nov 10 so the shapes can already be played with). Each line only if no shape has been taken yet.
func _invitation() -> void:
	var things := _things_centre()
	if _onion != null:
		_onion.attend(things)
		var spot := _invite_spot(things)
		if spot != Vector3.INF:
			_onion.float_to(spot, 1.0)   # closer to the shapes (layout chat's invite spot), clear of them
	if not _started:
		await say("Welcome to the workshop.")
	if not _started:
		await say("Oh! I'd nearly forgotten about these.")
	if not _started:
		await say("They've come quite a long way.")
	if _onion != null and _shelf_spot != Vector3.INF:
		_onion.attend(_shelf_spot)   # looks across the shapes, then toward the shelf
	if not _started:
		await say("The house is very good at bringing things here.")
	if not _started:
		await say("But finding their place is usually my job.")
	if _onion != null:
		_onion.attend(null)   # turns toward the child
	if not _started:
		await say("You could join me, if you like.")


## The middle of the shapes on the bench (the layout's plan, as the reveal used), or INF.
func _things_centre() -> Vector3:
	if _onion != null and _onion.layout != null:
		return _onion.layout.things_centre()
	return Vector3.INF


## Where Onion floats to while it invites: the layout's invite spot if it still waits at the reveal spot,
## otherwise part of the way toward the shapes, at its own height (as the reveal did).
func _invite_spot(things: Vector3) -> Vector3:
	if _onion == null or _onion.layout == null or things == Vector3.INF:
		return Vector3.INF
	var layout := _onion.layout
	var at := _onion.onion_position()
	if at.distance_to(layout.onion_reveal) < 0.06:
		return layout.onion_invite
	return at.lerp(Vector3(things.x, at.y, things.z), layout.invite_fraction)


func _invitation_open() -> bool:
	return not _started


func _play() -> void:
	var level := SHELF_TASK.level_by_id(TUTORIAL_LEVEL)
	await App.session.play(_reminder.prepare(level.plan), false)
	if App.session.won:
		App.main.progress.complete(SHELF_TASK, level)
	_started = true   # done before Onion finished talking: no more of the invitation, and no waiting for it
	var voice := App.module(&"Voice")
	if voice != null and voice.has_method(&"skip"):
		voice.skip()
	await _closing()


func _closing() -> void:
	if _onion != null and _shelf_spot != Vector3.INF:
		_onion.attend(_shelf_spot)   # a look across the shelf first
	await get_tree().create_timer(1.0, false).timeout
	if _onion != null:
		_onion.attend(null)
	# Only a level the child actually finished gets "Everything's found its place." After a time-out
	# or an abandoned round Onion just thanks the child (no claim of success).
	if _rounds_ended > 0 and _rounds_won == _rounds_ended:
		await say("There. Everything's found its place.")
	await say("Thank you for helping.")
	if _onion != null:
		_onion.cheer()
	await get_tree().create_timer(QUIET_END, false).timeout
	Tidy.onion_voice = false
	Events.report(&"first_visit_done")
	_motion.run_after_shelf()


func _on_reported(what: StringName, data: Dictionary) -> void:
	if what == &"taken" or what == &"put":
		_started = true
	if what == &"put" and data.get("correct", false) and not _fits_said:
		_fits_said = true
		var ended := _rounds_ended
		await get_tree().process_frame
		if _rounds_ended == ended:   # not when that placement finished the round: there are no others
			await say("It fits. Let's find places for the others.")   # the first placement only


func _exit_tree() -> void:
	Tidy.onion_voice = false
	Tidy.shelf_frame = Transform3D.IDENTITY   # the opening's planned bench ends with the first visit
	Entry.show_sim_props(true)


## Speaks [param text] as Onion (baked audio and subtitle) and waits for it; see [method Onion.line].
func say(text: String) -> void:
	await Onion.line(text, self)
