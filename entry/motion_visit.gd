class_name MotionVisit
extends Node
## The motion route after the first shelf level (MOTION_STORY_BUILD_BRIEF.md): the choice, the
## dots' arrival, the unscored demonstration, the child's turn on Wei's own motion rounds (his
## stimulus, judging and log unchanged: `Session.play` with a copy of his break-the-wall level 1,
## no intro, Onion speaking for it), the first-success lines, and the approved ending.
##
## Placeholders, for the other chats: the dots' entrance from below/behind the table and the
## preview (chat C/A), the demonstration itself (chat A: `_tutorial()` only waits now), the
## choice panel's layout (chat C: two plain buttons in front for now).

const Motion := preload("res://trials/motion/motion_trial.gd")
const Tidy := preload("res://trials/tidy/tidy_trial.gd")
const SHELF_TASK := preload("res://content/tasks/tidy_shelf.tres")
const BREATH := 0.25
## Seconds a successful round's effect (Wei's wall break) is left to settle before Onion speaks.
const SETTLE := 1.8
const QUIET_END := 3.0
## DEV: buttons that set the coherence of the next rounds (pinning the level, so it is logged).
const DEV_COHERENCE := true
const COHERENCES := [0.9, 0.7, 0.5, 0.3, 0.15]

@export var plan: SessionPlan

var _onion: Workshop
var _speaking := false
var _rounds_ended := 0
var _rounds_won := 0
var _first_success := false
var _in_motion := false
var _rounds_running := false
var _choice: StringName = &""
var _shelf_level := 1            # the next of Wei's shelf levels "more to sort" plays (level 2 first)
var _buttons: Array[EntryButton] = []
var _coherence_level := NAN      # the level the DEV buttons pinned, NAN: Wei's own for the plan
var _coherence_label: Label3D
var _dev: EntryMotionDev


func _ready() -> void:
	Events.touched.connect(func(_hand: StringName, target: Target) -> void: _on_press(target))
	Events.selected.connect(func(_hand: StringName, target: Target, _o: Vector3, _d: Vector3) -> void: _on_press(target))
	Events.trial_ended.connect(_on_trial_ended)


func _exit_tree() -> void:
	Motion.onion_voice = false


## After the shelf's closing: the offer to carry on, the dots' arrival and the choice.
func run_after_shelf() -> void:
	_onion = App.main.get_node_or_null(^"Workshop") as Workshop
	await say("There's more to sort, if you'd like to carry on.")
	await _entrance()
	await say("Oh! And they're here!")
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
	await say("Watch what happens when they move together.")
	await say("Here, let me show you.")
	await _tutorial()
	await say("Your turn.")
	await say("Watch which way the dots are moving, then sweep your hand that way.")
	SceneMarker.show_text("Motion")
	Motion.onion_voice = true
	_in_motion = true
	_rounds_ended = 0
	_rounds_won = 0
	if DEV_COHERENCE:
		_dev = EntryMotionDev.new()   # chat C: readout + buttons that pin the level (logged)
		add_child(_dev)
		_dev.set_scene(&"Motion")
	_rounds_running = true
	_play_rounds()   # not awaited here: the DEV coherence pin goes in right after play() clears it
	if not is_nan(_coherence_level):
		App.session.pinned = _coherence_level
	while _rounds_running:
		await get_tree().process_frame
	_in_motion = false
	_clear_buttons()
	if _dev != null:
		_dev.queue_free()
		_dev = null
	await _ending()


func _play_rounds() -> void:
	await App.session.play(plan)
	_rounds_running = false


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
	await say("Thank you for trying that with me.")
	await get_tree().create_timer(1.2, false).timeout
	await say("It's been lovely having you here.")
	Motion.onion_voice = false
	SceneMarker.show_text("Closing")
	if _onion != null:
		await _onion.slow_gears()
		await _onion.cauldron_back()
		_onion.attend(_onion.mouth())   # watches it land
		await _onion.gear_home()
		await get_tree().create_timer(0.5, false).timeout
		_onion.attend(null)   # turns back
	await say("I'll have everything ready for your next visit.")
	if _onion != null:
		_onion.attend(_onion.mouth())   # a glance toward the rattle
		await _onion.rattle()
		await get_tree().create_timer(0.3, false).timeout
		_onion.attend(null)
		_onion.tilt(true)   # back, with a sheepish tilt
	await say("Well. I'll do my best.")
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
		await say("There! You did that.")
		await say("The room has a few surprises left in it.")


# --- Placeholders for the other chats ------------------------------------------------

## The dots rise from below/behind the table as one group (chat C/A). Now: a short pause.
func _entrance() -> void:
	await get_tree().create_timer(1.0, false).timeout


## The unscored demonstration (chat A's MotionTutorial): dots at full coherence, the teaching hand's
## sideways sweep, Wei's effect once; nothing logged, no round. Onion turns to follow it.
func _tutorial() -> void:
	var tutorial := MotionTutorial.new()
	add_child(tutorial)
	tutorial.effect_started.connect(func() -> void:
		if _onion != null:
			_onion.attend(_dots_frame().origin))   # one smooth turn to the effect
	tutorial.play(_dots_frame())
	await tutorial.settled
	tutorial.queue_free()
	if _onion != null:
		_onion.attend(null)


## Where the dots stand: ahead at eye height, EntryMotionLayout.DOTS_DISTANCE away (like Wei's cloud).
func _dots_frame() -> Transform3D:
	var eye := App.head().global_transform
	var ahead := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	return Transform3D(Basis.looking_at(ahead, Vector3.UP), eye.origin + ahead * EntryMotionLayout.DOTS_DISTANCE)


## Two plain buttons in front of the child (chat C lays out the real choice). A press, never a look.
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
	SceneMarker.show_text("Shelf, level %d" % (_shelf_level + 1))
	Tidy.onion_voice = false
	if _shelf_level < SHELF_TASK.levels.size():
		await App.session.play(SHELF_TASK.levels[_shelf_level])
		_shelf_level += 1


func _coherence_panel() -> void:
	var eye := App.head().global_transform
	var ahead := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	var left := ahead.rotated(Vector3.UP, deg_to_rad(70.0))
	var at := eye.origin + left * 0.45 + Vector3.UP * 0.05
	_coherence_label = Label3D.new()
	_coherence_label.font_size = 22
	_coherence_label.pixel_size = 0.0006
	_coherence_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(_coherence_label)
	_coherence_label.global_position = at + Vector3.UP * 0.06
	_update_coherence_label()
	for i in COHERENCES.size():
		_add_button("%d%%" % roundi(COHERENCES[i] * 100.0), StringName("visit_coherence_%d" % i),
				at + Vector3.DOWN * (i * 0.055), Color(0.35, 0.35, 0.45), Vector2(0.09, 0.045))


func _update_coherence_label() -> void:
	if _coherence_label == null:
		return
	var shown := "Wei's level" if is_nan(_coherence_level) else "%d%%" % roundi(_coherence_at(_coherence_level) * 100.0)
	_coherence_label.text = "DEV · dots coherence: " + shown


func _on_press(target: Target) -> void:
	if target == null:
		return
	match target.id:
		&"visit_more_shelf":
			_choice = &"shelf"
		&"visit_motion":
			_choice = &"motion"
		&"visit_end_session":
			Events.report(&"session_ended", {by = "end_session_button"})
			_clear_buttons()
			get_tree().quit.call_deferred()
		_:
			var id := String(target.id)
			if id.begins_with("visit_coherence_"):
				var coherence: float = COHERENCES[int(id.trim_prefix("visit_coherence_"))]
				_coherence_level = level_for(coherence)
				if App.session != null:
					App.session.pinned = _coherence_level   # logged by the rounds' conditions (level)
					Events.report(&"level_pinned", {level = _coherence_level, coherence = coherence, by = "dev"})
				_update_coherence_label()


## The level of the plan's motion trial that shows [param coherence] (Wei's axis, searched).
func level_for(coherence: float) -> float:
	var low := 0.0
	var high := 1.0
	for _i in 30:
		var middle := (low + high) * 0.5
		if _coherence_at(middle) > coherence:
			low = middle
		else:
			high = middle
	return (low + high) * 0.5


func _coherence_at(level: float) -> float:
	var def: TrialDef = plan.blocks[0].trial
	return def.condition(level, 0, false).value(&"coherence")


func _add_button(text: String, id: StringName, at: Vector3, colour: Color, size := Vector2(0.2, 0.06)) -> void:
	var button := EntryButton.new()
	add_child(button)
	button.setup(text, id, colour, size, 0.01)
	button.global_position = at
	var head := App.head().global_position
	button.look_at(Vector3(head.x, at.y, head.z), Vector3.UP)
	button.rotate_object_local(Vector3.UP, PI)
	_buttons.append(button)


## Chat C's motion layout on the opening's zone map, or null (no map: the plain placement is used).
func _motion_layout() -> EntryMotionLayout:
	if _onion == null or _onion.layout == null:
		return null
	return EntryMotionLayout.new(_onion.layout)


func _clear_buttons() -> void:
	for button in _buttons:
		if is_instance_valid(button):
			button.queue_free()
	_buttons.clear()


## Speaks [param text] and waits for the voice to finish it, then a breath; one line at a time.
func say(text: String) -> void:
	while _speaking:
		await get_tree().process_frame
	_speaking = true
	var voice := App.module(&"Voice")
	if voice == null or not voice.has_signal(&"line_finished"):
		Events.say(text)
		await get_tree().create_timer(maxf(1.5, text.length() * 0.07 + 0.6), false).timeout
	else:
		var done := {finished = false}
		var on_finished := func(spoken: String, _completed: bool) -> void:
			if spoken == text:
				done.finished = true
		voice.line_finished.connect(on_finished)
		Events.say(text)
		var waited := 0.0
		var limit := maxf(6.0, text.length() * 0.2)
		while not done.finished and waited < limit:
			await get_tree().process_frame
			waited += get_process_delta_time()
		voice.line_finished.disconnect(on_finished)
		await get_tree().create_timer(BREATH, false).timeout
	_speaking = false
