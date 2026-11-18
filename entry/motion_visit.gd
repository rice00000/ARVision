class_name MotionVisit
extends Node
## The dots activity (Onion's unscored demonstration the first time, then Wei's Steady Flow level) and the
## visit's closing. The hub (WorkshopController) decides when each runs.

const Motion := preload("res://trials/motion/motion_trial.gd")
const WALL_TASK := preload("res://content/tasks/break_wall.tres")
## Seconds a successful round's effect (Wei's wall break) is left to settle before Onion speaks.
const SETTLE := 1.8
const QUIET_END := 3.0
## Scene 9 (Megan, Nov 17): the room dims to 60 % for the whole dots visit (Wei's own View, logged per round),
## fading in from the room's edges over HAZE_IN s ("bad energy"); after the last round, whatever the score, the
## dots push it back once (HAZE_OUT s). Never per right answer: the contrast stays fixed.
const DIM := preload("res://content/views/dim.tres")
const HAZE_IN := 2.0
const HAZE_OUT := 1.5
## Onion's calm lines during the rounds (Scene 9, Megan approved): a wrong sweep, and a nudge before the 30 s
## time-out (once per round). Help stays silent.
const WRONG_LINE := "Have another look. Which way are they moving?"
const NUDGE_LINE := "Take your time. Watch them for a moment."
const NUDGE_AFTER := 20.0
## Subtitles sit under the dot cloud while the dots are up (degrees below the horizon, straight ahead).
const SUBTITLE_BELOW := -24.0
var _plan: SessionPlan = WALL_TASK.level_by_id(&"steady_flow").plan
var _onion: Workshop
var _rounds_ended := 0
var _rounds_won := 0
var _first_success := false
var _in_motion := false
var _plays := 0                  # dots visits so far (the demonstration is the first time only)
var _round_serial := 0           # counts rounds, so a nudge only speaks in the round it was timed for
var _answered := false           # the child swept in this round
var _left := false               # the exit token ended the dots early

@onready var _narrator := get_parent()


func _ready() -> void:
	Events.trial_ended.connect(_on_trial_ended)
	Events.trial_started.connect(_on_trial_started)
	Events.reported.connect(func(what: StringName, _data: Dictionary) -> void:
		if not _in_motion:
			return
		if what == &"motion_attempt":
			_answered = true
		if what == &"motion_wrong":
			_narrator.say(WRONG_LINE))


func _exit_tree() -> void:
	Motion.onion_voice = false
	if _veil_node != null and is_instance_valid(_veil_node):
		_veil_node.queue_free()


func in_motion() -> bool:
	return _in_motion


## The dots activity, once (also the DEV jump "Motion"): the first time, Onion's demonstration and
## instructions; after that, straight into Wei's rounds. Returns &"done" (at least one round won),
## &"left" or &"interrupted".
func run_motion() -> StringName:
	_onion = App.main.get_node_or_null(^"Workshop") as Workshop
	_plays += 1
	if _onion != null:
		_onion.attend(null)
	_left = false
	await _haze(true)   # Scene 9: the bad energy creeps in before the dots rise
	_subtitles_under_cloud(true)
	if _plays == 1:
		SceneMarker.show_text("Tutorial")
		# Story chat, Nov 18 (revision): thoughtful curiosity, a shared discovery; Onion studies the dots.
		if _onion != null:
			_onion.attend(App.head().global_position - App.head().global_basis.z * 1.2)
		await _narrator.say("So many little dots. It all looks a bit jumbled, doesn't it?")
		await get_tree().create_timer(0.7, false).timeout
		await _narrator.say("But look—some of them are moving together.")
		await get_tree().create_timer(0.7, false).timeout
		await _narrator.say("Watch which way they go.")
		if _onion != null:
			_onion.attend(null)
		await _tutorial()
		await _narrator.say("Your turn! Sweep your hand the same way the dots are moving.")
	SceneMarker.show_text("Motion")
	Motion.onion_voice = true
	_in_motion = true
	_rounds_ended = 0
	_rounds_won = 0
	var dev: EntryMotionDev
	if PlayMode.is_dev():
		dev = EntryMotionDev.new(_plan.blocks[0])
		add_child(dev)
	var block := _plan.blocks[0]
	var block_view := block.view
	block.view = DIM   # every round runs (and is logged) in the dimmed room
	await App.session.play(_plan, false)
	block.view = block_view
	_in_motion = false
	if dev != null:
		dev.queue_free()
	if not _left:
		await get_tree().create_timer(SETTLE, false).timeout   # the last earned effect finishes
		# Story chat, Nov 18: the dots fly away; "There! You did that." (whatever the score); Onion follows them
		# briefly, then turns back to the child.
		if _onion != null:
			_onion.attend(App.head().global_position + Vector3.UP * 0.6 - App.head().global_basis.z * 1.5)
		await _narrator.say("There! You did that.")
		await get_tree().create_timer(0.6, false).timeout
		if _onion != null:
			_onion.attend(null)
	Motion.onion_voice = false
	await _haze(false)   # the dots push the bad energy back, once, whatever the score
	_subtitles_under_cloud(false)
	Events.report(&"motion_visit_done", {rounds = _rounds_ended, successes = _rounds_won, left = _left})
	if _left:
		await _narrator.say(WorkshopController.LEFT_EARLY)
	var outcome := &"left" if _left or _rounds_won == 0 else &"done"
	_left = false
	return outcome


## The exit token ended the dots early: the round is dropped (skipped) and the haze clears as at the end.
func leave() -> void:
	if not _in_motion and _plays == 0:
		return
	_left = true
	App.session.skip_block()


## The "bad energy": the room's dim fades in from 0 to 60 % over HAZE_IN s ([param on]), or back out. Only
## before the dots appear and after they've gone: nothing moves beside the dots while they're up.
func _haze(on: bool) -> void:
	var reality := App.reality
	var from := 0.0 if on else DIM.dim
	var to := DIM.dim if on else 0.0
	var seconds := HAZE_IN if on else HAZE_OUT
	var step := View.new()
	var t := 0.0
	while t < seconds:
		t += get_process_delta_time()
		step.dim = lerpf(from, to, clampf(t / seconds, 0.0, 1.0))
		reality.view = step
		reality._apply()   # no log line per step; the last one is logged below
		await get_tree().process_frame
	reality.apply_view(DIM if on else App.session.base_view)


func _subtitles_under_cloud(on: bool) -> void:
	var voice := App.module(&"Voice")
	if voice != null and &"fixed_elevation" in voice:
		voice.fixed_elevation = SUBTITLE_BELOW if on else NAN


## The closing (Scene 10, Megan Nov 17), started only by Finish visit on the gear: the ring has sunk into the
## cauldron (WorkshopController); Onion: "It's been lovely having you here." ("Thank you for trying that with me."
## is cut); the gears slow and stop; the gear goes home into the cauldron (with "found its place"); Onion
## promises to be ready next time, a rattle gives it away; a goodbye bob, Onion ducks inside and the empty
## socket fades into the table. The workshop stays quietly; the grown-up ends the session in Staff tools
## (no End-session button in the room).
func closing() -> void:
	_onion = App.main.get_node_or_null(^"Workshop") as Workshop
	if _onion != null:
		_onion.attend(null)
	await get_tree().create_timer(1.0, false).timeout
	await _narrator.say("It's been lovely having you here.")
	Motion.onion_voice = false
	SceneMarker.show_text("Closing")
	if _onion != null:
		await _onion.slow_gears()
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
		_onion.fade_socket()   # the empty socket fades into the table as Onion ducks in
		await _onion.goodbye()
	Events.report(&"visit_closed")
	await get_tree().create_timer(QUIET_END, false).timeout
	SceneMarker.show_text("End of session")
	App.results_after_closing = true   # Staff tools opens on Results; End session is there


## Scene 11: Home on the gear → Wei's room (his VR room, pets, stones, shop), through a slow, stationary fade
## to dark, and back to the workshop exactly as it was. The room is Wei's Home module (☰ Menu → My room).
func visit_home() -> void:
	var home := App.module(&"Home")
	if home == null or not home.has_method(&"open"):
		return
	await _fade(true)
	Events.room_requested.emit()
	await _fade(false)
	while home.get(&"is_open"):
		await get_tree().process_frame
	await _fade(true)
	await _fade(false)


## A slow fade to dark and back (no camera movement), the same in and out of Wei's room.
## A black sphere on the head, not a 2D layer: 2D layers don't reach the headset.
func _fade(to_dark: bool, seconds := 0.8) -> void:
	var material := _veil()
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(material, ^"albedo_color:a", 1.0 if to_dark else 0.0, seconds)
	await tween.finished
	_veil_node.visible = material.albedo_color.a > 0.0


var _veil_node: MeshInstance3D
func _veil() -> StandardMaterial3D:
	if _veil_node == null or not is_instance_valid(_veil_node):
		_veil_node = MeshInstance3D.new()
		_veil_node.name = "HomeVeil"
		var sphere := SphereMesh.new()
		sphere.radius = 0.25
		sphere.height = 0.5
		sphere.flip_faces = true
		_veil_node.mesh = sphere
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.no_depth_test = true
		material.render_priority = 127   # over everything, the room's panels included
		material.albedo_color = Color(0, 0, 0, 0)
		_veil_node.material_override = material
		App.head().add_child(_veil_node)
	_veil_node.visible = true
	return _veil_node.material_override


func _on_trial_ended(_skill: StringName, success: bool, _data: Dictionary) -> void:
	if not _in_motion:
		return
	_rounds_ended += 1
	if success:
		_rounds_won += 1
	if success and not _first_success:
		_first_success = true   # (story chat, Nov 18: Onion stays quiet during the measured rounds; "There! You did
		# that." moved to the end, as the dots fly away)


func _on_trial_started(_trial: StringName, _condition: Dictionary) -> void:
	if not _in_motion:
		return
	_round_serial += 1
	_answered = false
	var serial := _round_serial
	await get_tree().create_timer(NUDGE_AFTER, false).timeout
	if _in_motion and serial == _round_serial and not _answered:
		_narrator.say(NUDGE_LINE)   # once per round, before the 30 s time-out


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


## Chat C's motion layout on the opening's zone map, or null (no map: the plain placement is used).
func _motion_layout() -> EntryMotionLayout:
	if _onion == null or _onion.layout == null:
		return null
	return EntryMotionLayout.new(_onion.layout, _motion_condition())


