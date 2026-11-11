class_name MotionVisit
extends Node
## Onion's unscored demonstration, the Steady Flow level, and the closing.

const Motion := preload("res://trials/motion/motion_trial.gd")
const Tidy := preload("res://trials/tidy/tidy_trial.gd")
const SHELF_TASK := preload("res://content/tasks/tidy_shelf.tres")
const WALL_TASK := preload("res://content/tasks/break_wall.tres")
## Seconds a successful round's effect (Wei's wall break) is left to settle before Onion speaks.
const SETTLE := 1.8
const QUIET_END := 3.0
var _plan: SessionPlan = WALL_TASK.level_by_id(&"steady_flow").plan
var _onion: Workshop
var _rounds_ended := 0
var _rounds_won := 0
var _first_success := false
var _in_motion := false
var _choice: StringName = &""
var _shelf_level := 1            # the next of Wei's shelf levels "more to sort" plays (level 2 first)
var _buttons: Array[EntryButton] = []

@onready var _narrator := get_parent()


func _ready() -> void:
	Events.selected.connect(func(_hand: StringName, target: Target, _o: Vector3, _d: Vector3) -> void: _on_press(target))
	Events.trial_ended.connect(_on_trial_ended)


func _exit_tree() -> void:
	Motion.onion_voice = false


## After the shelf's closing: offer another shelf level or the motion demonstration.
func run_after_shelf() -> void:
	_onion = App.main.get_node_or_null(^"Workshop") as Workshop
	await _narrator.say("There's more to sort, if you'd like to carry on.")
	await get_tree().create_timer(1.0, false).timeout
	await _narrator.say("Oh! And they're here!")
	while true:
		SceneMarker.show_text("Choice")
		var picked := await _choose()
		if picked == &"motion":
			await run_motion()
			return
		await _more_shelf()


## The motion part on its own (also the DEV jump "Motion").
func run_motion() -> void:
	_onion = App.main.get_node_or_null(^"Workshop") as Workshop
	SceneMarker.show_text("Tutorial")
	if _onion != null:
		_onion.attend(null)
	await _narrator.say("Watch what happens when they move together.")
	await _narrator.say("Here, let me show you.")
	await _tutorial()
	await _narrator.say("Your turn.")
	await _narrator.say("Watch which way the dots are moving, then sweep your hand that way.")
	SceneMarker.show_text("Motion")
	Motion.onion_voice = true
	_in_motion = true
	_rounds_ended = 0
	_rounds_won = 0
	var dev: EntryMotionDev
	if PlayMode.is_dev():
		dev = EntryMotionDev.new(_plan.blocks[0])
		add_child(dev)
	await App.session.play(_plan, false)
	_in_motion = false
	if dev != null:
		dev.queue_free()
	await _ending()


## The approved ending and closing (story chat, whatever the success count): the last earned effect
## finishes (a time-out gets none: Wei's trial only plays it on a right sweep), the dots are gone (Wei's
## session frees its trial) and the teaching cues stop; Onion thanks the child; the gears slow and stop;
## the gear goes home into the cauldron; Onion promises to be ready next time, a rattle gives it away;
## a goodbye bob and Onion ducks inside. Then the end-session control; the workshop stays until it is
## pressed.
func _ending() -> void:
	await get_tree().create_timer(SETTLE, false).timeout
	if _onion != null:
		_onion.attend(null)
	await get_tree().create_timer(1.0, false).timeout
	await _narrator.say("Thank you for trying that with me.")
	await get_tree().create_timer(1.2, false).timeout
	await _narrator.say("It's been lovely having you here.")
	Motion.onion_voice = false
	SceneMarker.show_text("Closing")
	if _onion != null:
		await _onion.slow_gears()
		await _onion.cauldron_back()
		_onion.attend(_onion.mouth())   # watches it land
		await _onion.gear_home()
		await get_tree().create_timer(0.5, false).timeout
		_onion.attend(null)   # turns back
	await _narrator.say("I'll have everything ready for your next visit.")
	if _onion != null:
		_onion.attend(_onion.mouth())   # a glance toward the rattle
		await _onion.rattle()
		await get_tree().create_timer(0.3, false).timeout
		_onion.attend(null)
		_onion.tilt(true)   # back, with a sheepish tilt
	await _narrator.say("Well. I'll do my best.")
	if _onion != null:
		_onion.tilt(false)
		await _onion.goodbye()
	Events.report(&"motion_visit_done", {rounds = _rounds_ended, successes = _rounds_won})
	await get_tree().create_timer(QUIET_END, false).timeout
	_end_session_control()


## "End session": stays until the grown-up presses it; the workshop stays visible meanwhile.
func _end_session_control() -> void:
	SceneMarker.show_text("End of session")
	var eye := App.head().global_transform
	var ahead := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	_add_button("End session", &"visit_end_session", eye.origin + ahead.rotated(Vector3.UP, deg_to_rad(-35.0)) * 0.45 + Vector3.DOWN * 0.05, Color(0.45, 0.3, 0.3))


func _on_trial_ended(_skill: StringName, success: bool, _data: Dictionary) -> void:
	if not _in_motion:
		return
	_rounds_ended += 1
	if success:
		_rounds_won += 1
	if success and not _first_success:   # the full reaction, on the first success only
		_first_success = true
		await get_tree().create_timer(SETTLE, false).timeout
		await _narrator.say("There! You did that.")
		await _narrator.say("The room has a few surprises left in it.")


## The unscored demonstration (chat A's MotionTutorial): dots at full coherence, the teaching hand's
## sideways sweep, Wei's effect once; nothing logged, no round. Onion turns to follow it.
func _tutorial() -> void:
	var tutorial := MotionTutorial.new()
	add_child(tutorial)
	var condition := _motion_condition()
	var eye := App.head().global_transform
	var ahead := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	var frame := Transform3D(Basis.looking_at(ahead), eye.origin + ahead * MotionCloud.distance(condition))
	tutorial.effect_started.connect(func() -> void:
		if _onion != null:
			_onion.attend(frame.origin))
	tutorial.play(condition, frame)
	await tutorial.settled
	tutorial.queue_free()
	if _onion != null:
		_onion.attend(null)


func _motion_condition() -> TrialCondition:
	var block := _plan.blocks[0]
	return block.trial.condition(block.difficulty, 0, block.probe, block.pins)


## The shelf and motion choices sit side by side.
func _choose() -> StringName:
	_clear_buttons()
	var eye := App.head().global_transform
	var ahead := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	var right := ahead.cross(Vector3.UP)
	var at := eye.origin + ahead * 0.42 + Vector3.DOWN * 0.12
	var spots := _motion_layout()
	if spots != null:   # chat C: a row on the table straight ahead, inside the reach
		at = spots.choice_spot(0, 2)
	_add_button("More shapes", &"visit_more_shelf", at - right * 0.06 if spots == null else at, Color(0.55, 0.42, 0.28))
	var disc := MotionChoice.new()   # chat A: a still disc of dots, pressed deliberately (never a look)
	add_child(disc)
	if spots != null:
		disc.global_transform = _buttons[0].global_transform
		disc.global_position = spots.choice_spot(1, 2)
		var place: Dictionary = spots.onion_without_shelf(2)
		if _onion != null:
			_onion.float_to(place.at, 1.0)   # beside the row, out of the dots' view
	else:
		disc.place_beside(_buttons[0], 0.1)
	disc.open()
	disc.chosen.connect(func() -> void: _choice = &"motion")
	_choice = &""
	while _choice == &"":
		await get_tree().process_frame
	disc.close()
	disc.queue_free()
	_clear_buttons()
	return _choice


## "More to sort": Wei's next shelf level (his own lines this time), then back to the choice.
func _more_shelf() -> void:
	var level := SHELF_TASK.levels[_shelf_level]
	SceneMarker.show_text("Shelf, level %d" % (_shelf_level + 1))
	Tidy.onion_voice = false
	await App.session.play(level.plan)
	if App.session.won:
		App.main.progress.complete(SHELF_TASK, level)
	# After the last level, "More shapes" replays it for its configured repeat reward.
	_shelf_level = mini(_shelf_level + 1, SHELF_TASK.levels.size() - 1)


func _on_press(target: Target) -> void:
	if target == null:
		return
	match target.id:
		&"visit_more_shelf":
			_choice = &"shelf"
		&"visit_end_session":
			Events.report(&"session_ended", {by = "end_session_button"})
			_clear_buttons()
			get_tree().quit.call_deferred()


func _add_button(text: String, id: StringName, at: Vector3, colour: Color) -> void:
	var button := EntryButton.new()
	add_child(button)
	button.setup(text, id, colour, Vector2(0.2, 0.06), 0.01)
	button.global_position = at
	var head := App.head().global_position
	button.look_at(Vector3(head.x, at.y, head.z), Vector3.UP)
	button.rotate_object_local(Vector3.UP, PI)
	_buttons.append(button)


## Chat C's motion layout on the opening's zone map, or null (no map: the plain placement is used).
func _motion_layout() -> EntryMotionLayout:
	if _onion == null or _onion.layout == null:
		return null
	return EntryMotionLayout.new(_onion.layout, _motion_condition())


func _clear_buttons() -> void:
	for button in _buttons:
		if is_instance_valid(button):
			button.queue_free()
	_buttons.clear()
