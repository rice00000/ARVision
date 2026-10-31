class_name FirstVisit
extends Node
## Scene one's last part: Onion leads the first shelf level, the same level Wei's World offers,
## but without the World's welcome, menu, announcements and closing (Onion speaks for them).
## Wei's code is used as it is: Session.play(plan) with a copy of his level-1 plan.
##
## The brief (SCENE_ONE_CURRENT_BUILD_BRIEF.md, steps 13-15): the shelf rule, one short line at
## the first correct placement, then, when the level is done, the closing, a bob and quiet.

const Tidy := preload("res://trials/tidy/tidy_trial.gd")

@export var plan: SessionPlan

## DEV jump: &"motion" starts straight at the motion route (the shelf level is skipped). Single use.
static var start_with: StringName = &""

## Seconds of quiet at the very end of scene one.
const QUIET_END := 4.0
const BREATH := 0.25

var _fits_said := false
var _started := false      # the child picked a shape up or placed one: the invitation is over
var _speaking := false     # one line at a time: a later line waits, it never cuts an earlier one off
var _rounds_won := 0
var _rounds_ended := 0
var _onion: Workshop
var _shelf_spot := Vector3.INF
var _reminder: ShelfReminder   # a hand that shows how to pick a shape up, if the child waits (interaction chat)


func run() -> void:
	Tidy.onion_voice = true
	_onion = App.main.get_node_or_null(^"Workshop") as Workshop
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
	App.reality.apply_view(App.session.base_view)
	if not App.reality.is_settled:
		await App.reality.settled
	if start_with == &"motion":
		start_with = &""
		Tidy.onion_voice = false
		await get_tree().create_timer(0.5, false).timeout
		await (get_node(^"../Motion") as MotionVisit).run_motion()
		return
	SceneMarker.show_text("Shelf")
	_play()   # not awaited: Onion speaks while the first round sets up
	for _frame in 30:
		await get_tree().process_frame
		if App.session.trial is Node3D:
			_shelf_spot = (App.session.trial as Node3D).global_position
			break
	# The shapes and Onion's invitation came in the reveal; the shelf level starts with the rule.
	# Picking a shape up is acceptance: the remaining lines are skipped, so nothing holds the child up;
	# "It fits..." still comes at the first correct placement.
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


func _invitation_open() -> bool:
	return not _started


func _play() -> void:
	await App.session.play(_reminder.prepare(plan))   # Wei's first hint is held back so the reminder comes first
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
	var motion := get_node_or_null(^"../Motion") as MotionVisit
	if motion != null:
		motion.run_after_shelf()   # "There's more to sort..." and the motion route (it runs on its own)


func _on_reported(what: StringName, data: Dictionary) -> void:
	if what == &"taken" or what == &"put":
		_started = true
	if what == &"put" and data.get("correct", false) and not _fits_said:
		_fits_said = true
		await say("It fits. Let's find places for the others.")   # the first placement only


func _exit_tree() -> void:
	Tidy.onion_voice = false
	Tidy.push = 0.0   # the opening's shelf distance ends with the first visit
	Entry.show_sim_props(true)


## Speaks [param text] (baked audio + subtitle) and waits for the voice to finish it, then a breath.
func say(text: String) -> void:
	while _speaking:
		await get_tree().process_frame
	_speaking = true
	await _say(text)
	_speaking = false


func _say(text: String) -> void:
	var voice := App.module(&"Voice")
	if voice == null or not voice.has_signal(&"line_finished"):
		Events.say(text)
		await get_tree().create_timer(maxf(1.5, text.length() * 0.07 + 0.6), false).timeout
		return
	var done := {finished = false, completed = true}
	var on_finished := func(spoken: String, completed: bool) -> void:
		if spoken == text:
			done.finished = true
			done.completed = completed
	voice.line_finished.connect(on_finished)
	Events.say(text)
	var waited := 0.0
	var limit := maxf(6.0, text.length() * 0.2)
	while not done.finished and waited < limit:
		await get_tree().process_frame
		waited += get_process_delta_time()
	voice.line_finished.disconnect(on_finished)
	if not done.completed:
		return   # cut short (the child pressed Onion): on at once, with no breath
	await get_tree().create_timer(BREATH, false).timeout
