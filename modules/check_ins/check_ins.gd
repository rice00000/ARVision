class_name CheckIns
extends Module
## Check-ins: a few no-help rounds at fixed difficulties, on things the child
## never trains on, so the team can see whether seeing itself is improving
## (design brief: "checked by no-help check-ins on new objects, not game scores").
##
## Each [Place] may name a [member Place.check_in] plan of probe blocks. The World
## asks [method due] before a place's menu unfolds: the first visit (the
## baseline), then once [member every_days] days have passed since the last
## finished one. A check-in that was skipped is not asked again the same day.
## Staff can ask for one now (facilitator → Training → Check-in).
##
## Results are saved with the child (key "check_ins") and logged as "check_in"
## events; tools/progress.py and the facilitator's Progress page read them.
## Probes earn no stones and never move the staircase.
##
## Delete the node to unplug it: the World then never runs check-ins.

## What staff and the report call each skill.
const SKILL_NAMES := {
	visual_matching = "Shapes on the shelf",
	colour_discrimination = "Odd colour",
	global_motion = "Moving dots",
	global_motion_competing = "Dots against dots",
	butterfly_catch = "Catching butterflies",
	butterfly_swarm = "Butterfly swarm",
	objects_in_clutter = "Find it",
	real_object_recognition = "Real objects",
	desk_outline_matching = "Ready to study",
	bookshelf_shape_matching = "Bookshelf",
	sandwich_spatial_order = "Sandwich",
}
const DAY := 86400.0
## Hours after any attempt before asking again: a skipped check-in waits for another day.
const RETRY_HOURS := 12.0

@export var every_days := 7.0

var save_key := "check_ins"
## Oldest first: {place, title, time, done, scores = {skill: {rounds, right, levels = {"0.30": [rounds, right]}}}, vision}.
var history: Array[Dictionary] = []

## Places staff asked a check-in for, by key; &"*" = the next place.
var _asked: Dictionary[StringName, bool] = {}
var _current: Dictionary = {}


func _ready() -> void:
	Events.trial_ended.connect(_on_trial_ended)


func save_state() -> Dictionary:
	return {history = history, asked = _asked.keys()}


func load_state(data: Dictionary) -> void:
	history.assign(data.get("history", []))
	_asked.clear()
	for key: Variant in data.get("asked", []):
		_asked[StringName(key)] = true


static func key(place: Place) -> StringName:
	return StringName(place.resource_path.get_file().get_basename())


## A level's own staircase reads "Shapes on the shelf · Similar shadows".
static func skill_name(skill: StringName) -> String:
	var parts := String(skill).split(".", true, 1)
	var name: String = SKILL_NAMES.get(StringName(parts[0]), parts[0].capitalize())
	return name if parts.size() == 1 else "%s · %s" % [name, parts[1].replace("_", " ").capitalize()]


## Whether [param place] should check in before its menu unfolds.
func due(place: Place, now := Time.get_unix_time_from_system()) -> bool:
	if place.check_in == null:
		return false
	if _asked.has(key(place)) or _asked.has(&"*"):
		return true
	var tried := last(place, false)
	if not tried.is_empty() and now - float(tried.time) < RETRY_HOURS * 3600.0:
		return false
	var done := last(place, true)
	return done.is_empty() or now - float(done.time) >= every_days * DAY


## The latest check-in at [param place] ({} if none); [param finished] only finished ones.
func last(place: Place, finished := true) -> Dictionary:
	for i in range(history.size() - 1, -1, -1):
		if history[i].place == String(key(place)) and (history[i].done or not finished):
			return history[i]
	return {}


## Staff: check in at the next place the child opens (or [param place]).
func ask(place: Place = null) -> void:
	_asked[key(place) if place else &"*"] = true
	Events.report(&"check_in_asked", {place = String(key(place)) if place else "next"})
	Save.request()


func asked() -> bool:
	return not _asked.is_empty()


## Plays [param place]'s check-in and records it, finished or not.
func run(place: Place) -> void:
	_asked.erase(key(place))
	_asked.erase(&"*")
	var plan := place.check_in
	var expected := 0
	for block in plan.blocks:
		expected += block.rounds
	_current = {place = String(key(place)), title = place.title, time = Time.get_unix_time_from_system(),
		done = false, scores = {}, vision = Vision.to_log()}
	Events.report(&"check_in_started", {place = _current.place})
	await App.session.play(plan)
	var scored := 0
	for skill: String in _current.scores:
		scored += _current.scores[skill].rounds
	_current.done = scored == expected
	history.append(_current)
	Events.report(&"check_in", _current.duplicate(true))
	_current = {}
	Save.request()


## Finished check-ins of [param skill], oldest first: [{time, rounds, right}].
func results(skill: StringName) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for entry in history:
		if entry.done and entry.scores.has(String(skill)):
			var score: Dictionary = entry.scores[String(skill)]
			found.append({time = entry.time, rounds = score.rounds, right = score.right})
	return found


## Every skill a finished check-in measured, in the order first measured.
func skills() -> Array[StringName]:
	var found: Array[StringName] = []
	for entry in history:
		if entry.done:
			for skill: String in entry.scores:
				if not StringName(skill) in found:
					found.append(StringName(skill))
	return found


func _on_trial_ended(skill: StringName, _success: bool, data: Dictionary) -> void:
	if _current.is_empty() or not data.get("probe", false):
		return
	var score: Dictionary = _current.scores.get_or_add(String(skill), {rounds = 0, right = 0, levels = {}})
	var right := int(data.get("first_try", false))
	score.rounds += 1
	score.right += right
	var at: Array = score.levels.get_or_add("%.2f" % float(data.level), [0, 0])
	at[0] += 1
	at[1] += right
