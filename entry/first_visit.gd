class_name FirstVisit
extends Node
## After the reveal: the workshop hub (WorkshopController, Scene 7) offers the games in a ring on the cauldron.
## This node holds the shelf's story (Scene 8): Onion leads Wei's Shadow Match the first time, his next levels
## after that; the shelf stands at Wei's bench while it plays (no glide); "found its place" on each fit.

const Tidy := preload("res://trials/tidy/tidy_trial.gd")
const SHELF_TASK := preload("res://content/tasks/tidy_shelf.tres")
const TUTORIAL_LEVEL := &"shadow"

## DEV jumps (single use): &"motion" starts straight at the dots, &"shelf" straight at the shelf (no hub
## first); both go on to the hub afterwards. &"" (the opening's own flow): the hub.
static var start_with: StringName = &""
## Set by the opening (entry.gd) for the first visit: Onion welcomes the child. Single use.
static var invite := false

var _fits_said := false
var _started := false      # the child picked a shape up or placed one: the invitation is over
var _rounds_won := 0
var _rounds_ended := 0
var _onion: Workshop
var _shelf_spot := Vector3.INF
var _reminder: ShelfReminder   # a hand that shows how to pick a shape up, if the child waits (interaction chat)
var _shelf_plays := 0      # how many times the shelf has been played in this visit
var controller: WorkshopController
var _left := false         # the child left the shelf early (the exit token)

@onready var _motion: MotionVisit = $Motion


func run() -> void:
	_onion = App.main.get_node_or_null(^"Workshop") as Workshop
	Events.celebrate = false   # the hub's stones replace Wei's trophy and fanfare in the workshop
	HubMemory.get_or_make()    # the child's saved look is the base view from here
	App.reality.apply_view(App.session.base_view)
	if not App.reality.is_settled:
		await App.reality.settled
	Events.reported.connect(_on_reported)
	Events.trial_ended.connect(func(_skill: StringName, success: bool, _data: Dictionary) -> void:
		if not _motion.in_motion():
			_rounds_ended += 1
			if success:
				_rounds_won += 1)
	_reminder = ShelfReminder.new()
	add_child(_reminder)
	var skip := App.main.get_node_or_null(^"LineSkip") as LineSkip
	if skip != null:   # the invitation is an instruction until the child has taken a shape
		skip.guards.append(_invitation_open)
	var home := App.module(&"Home")
	if home != null and &"hide_entry" in home:
		home.hide_entry = true   # the gear is the child's menu now (Scene 7/9)
	if home != null and &"workshop" in home:
		home.workshop = true     # Wei's room from the house: no Menu, a cauldron to go back, teal stones
	HomeUI.teal_stones = true
	controller = WorkshopController.new()
	controller.name = "WorkshopController"
	add_child(controller)
	var shelf := ShelfActivity.new(self)
	var dots := DotsActivity.new(_motion)
	var first := start_with
	start_with = &""
	var welcome := invite
	invite = false
	await controller.run(_onion, [shelf, dots, ButterflyActivity.new(), TurnToFitActivity.new()], first, welcome, _motion.closing, _go_home)


## Scene 11: Home on the gear → Wei's room and back (MotionVisit has the fade).
func _go_home() -> void:
	await _motion.visit_home()


## The shelf activity, once: [param level] (the hub's pick). Shadow Match with Onion's tutorial until this child
## has finished it; any other level (or a replay) as Wei's own. Returns &"done" (every round won), &"left" (not
## all won, or left early) or &"interrupted". The hub gives the stones (WorkshopController).
func play_shelf(level: TaskLevel = null) -> StringName:
	_shelf_plays += 1
	_left = false
	_rounds_ended = 0
	_rounds_won = 0
	if level == null:
		level = SHELF_TASK.level_by_id(TUTORIAL_LEVEL)
	if level.id != TUTORIAL_LEVEL or App.main.progress.is_done(SHELF_TASK, level):
		return await _more_shelf(level)
	Tidy.onion_voice = true
	_started = false
	SceneMarker.show_text("Shelf")
	var done := [false]
	var outcome := [&"left"]
	(func() -> void:
		outcome[0] = await _play()
		done[0] = true).call()
	for _frame in 30:
		await get_tree().process_frame
		if App.session.trial is Node3D:
			_shelf_spot = (App.session.trial as Node3D).global_position
			break
	# The shelf level is running from here: the child may pick shapes up and sort while Onion talks.
	if _onion != null and _shelf_spot != Vector3.INF:
		_onion.attend(_shelf_spot)   # looks toward the shelf
	if not _started:
		await say("The shapes on the shelf show where things go.")
	if not _started:
		await say("Pick whichever one you'd like to start with.")
	if _onion != null:
		_onion.attend(null)
	if not done[0]:
		_reminder.start()   # the invitation is done: if the child waits, the hand shows how to pick one up
	while not done[0]:
		await get_tree().process_frame
	return outcome[0]


func _invitation_open() -> bool:
	return not _started


func _play() -> StringName:
	var level := SHELF_TASK.level_by_id(TUTORIAL_LEVEL)
	await App.session.play(_reminder.prepare(level.plan), false)
	_started = true   # done before Onion finished talking: no more of the invitation, and no waiting for it
	var voice := App.module(&"Voice")
	if voice != null and voice.has_method(&"skip"):
		voice.skip()
	return await _closing()


## The shelf's end (Scene 8): a look across it, then "There. Everything's found its place." when every round
## was won, or "We can come back to these." when not (or when the child left early). "Thank you for helping." is cut.
func _closing() -> StringName:
	if _onion != null and _shelf_spot != Vector3.INF:
		_onion.attend(_shelf_spot)   # a look across the shelf first
	await get_tree().create_timer(1.0, false).timeout
	if _onion != null:
		_onion.attend(null)
	var all_won := _rounds_ended > 0 and _rounds_won == _rounds_ended and not _left
	if all_won:
		await say("There. Everything's found its place.")
		if _onion != null:
			_onion.cheer()
	else:
		await say(WorkshopController.LEFT_EARLY)
	Tidy.onion_voice = false
	Events.report(&"first_visit_done")
	return &"done" if all_won else &"left"


## One of Wei's shelf levels (his own lines this time).
func _more_shelf(level: TaskLevel) -> StringName:
	SceneMarker.show_text("Shelf: %s" % level.title)
	Tidy.onion_voice = false
	await App.session.play(level.plan)
	var won := App.session.won and not _left
	if not won:
		await say(WorkshopController.LEFT_EARLY)
	return &"done" if won else &"left"


## The child left the shelf early (the exit token): its round is dropped, then the ending line.
func leave_shelf() -> void:
	_left = true
	_started = true
	App.session.skip_block()


func _on_reported(what: StringName, data: Dictionary) -> void:
	if what == &"taken" or what == &"put":
		_started = true
	if what == &"put" and data.get("correct", false) and not _motion.in_motion():
		_place_signal(StringName(str(data.get("thing", ""))))
	if what == &"put" and data.get("correct", false) and not _fits_said and _shelf_plays == 1:
		_fits_said = true
		var ended := _rounds_ended
		await get_tree().process_frame
		if _rounds_ended == ended:   # not when that placement finished the round: there are no others
			await say("It fits. Let's find places for the others.")   # the first placement only


func _exit_tree() -> void:
	Events.celebrate = true
	HomeUI.teal_stones = false
	var home := App.module(&"Home") if App != null else null
	if home != null and is_instance_valid(home) and &"workshop" in home:
		home.workshop = false
	Tidy.onion_voice = false
	Tidy.shelf_frame = Transform3D.IDENTITY   # the opening's planned bench ends with the first visit
	Entry.show_sim_props(true)


## "Found its place" (Scene 5's signal) where a shape has just settled in its cubby (Wei's trial moves it there
## over ~0.35 s first).
func _place_signal(key: StringName) -> void:
	var trial := App.session.trial
	if trial == null or not ("_key" in trial):
		return
	var keys: Dictionary = trial.get("_key")
	for thing: Variant in keys:
		if is_instance_valid(thing) and StringName(str(keys[thing])) == key:
			await get_tree().create_timer(0.4, false).timeout
			if is_instance_valid(thing):
				PlaceSignal.play(self, (thing as Node3D).global_position, Vector3.UP, 0.06)
			return


## Speaks [param text] as Onion (baked audio and subtitle) and waits for it; see [method Onion.line].
func say(text: String) -> void:
	await Onion.line(text, self)
