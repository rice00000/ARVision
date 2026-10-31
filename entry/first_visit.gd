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

## Seconds of quiet at the very end of scene one.
const QUIET_END := 4.0
const BREATH := 0.5

var _fits_said := false
var _onion: Workshop
var _shelf_spot := Vector3.INF


func run() -> void:
	Tidy.onion_voice = true
	_onion = App.main.get_node_or_null(^"Workshop") as Workshop
	Events.reported.connect(_on_reported)
	App.reality.apply_view(App.session.base_view)
	if not App.reality.is_settled:
		await App.reality.settled
	_play()   # not awaited: Onion speaks while the first round sets up
	for _frame in 30:
		await get_tree().process_frame
		if App.session.trial is Node3D:
			_shelf_spot = (App.session.trial as Node3D).global_position
			break
	await say("The shapes on the shelf show where things go.")
	await say("Can you find a place for one of these?")


func _play() -> void:
	await App.session.play(plan)
	await _closing()


func _closing() -> void:
	if _onion != null and _shelf_spot != Vector3.INF:
		_onion.attend(_shelf_spot)   # a look across the shelf first
	await get_tree().create_timer(1.0, false).timeout
	if _onion != null:
		_onion.attend(null)
	await say("There. Everything's found its place.")
	await say("Thank you for helping.")
	if _onion != null:
		_onion.cheer()
	await get_tree().create_timer(QUIET_END, false).timeout
	Tidy.onion_voice = false
	Events.report(&"first_visit_done")


func _on_reported(what: StringName, data: Dictionary) -> void:
	if what == &"put" and data.get("correct", false) and not _fits_said:
		_fits_said = true
		await say("It fits. Let's find places for the others.")   # the first placement only


func _exit_tree() -> void:
	Tidy.onion_voice = false
	Tidy.push = 0.0   # the opening's shelf distance ends with the first visit


## Speaks [param text] (baked audio + subtitle) and waits for the voice to finish it, then a breath.
func say(text: String) -> void:
	var voice := App.module(&"Voice")
	if voice == null or not voice.has_signal(&"line_finished"):
		Events.say(text)
		await get_tree().create_timer(maxf(1.5, text.length() * 0.07 + 0.6), false).timeout
		return
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
