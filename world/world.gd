class_name World
extends Node
## Plays the active scene's [Adventure]. Main owns when it starts and stops.
## Each [Place] has its own list of tasks. The guide points the way to
## the first place ("this way"); once the child turns to face it, its
## [TaskMenu] unfolds there. The chosen task plays at the chosen level, then
## the menu of the same place comes back. If a level opened somewhere else that
## the child has not seen on a menu yet, the guide points there too.
## Turning to face another place folds this menu and opens that one. Only
## the body's turn counts for now, so it can be tested seated.
##
## Saved as "world" (see Save): the levels done of each task and the levels seen open.

## Degrees within which the head faces a place (left-right only).
const FACING := 25.0
## Seconds the child keeps facing a place before its menu unfolds.
const FACING_SECONDS := 0.5
## How far behind the child a place "behind" is, metres.
const BEHIND := 1.5

@export var adventure: Adventure

var save_key := "world"
## Task id -> the levels done (0 = level 1).
var done: Dictionary = {}
## "<task id>:<level>" of every level shown open on a menu.
var seen: Array = []
## The open menu, or null.
var menu: TaskMenu
## The place the child is at, or null before the first.
var place: Place

var _guide := Guide.new()
## While true, facing a place other than [member place] for long enough sends [signal _picked].
var _watching := false
var _faced_for: Dictionary[Place, float] = {}

## [Task, level] chosen on the menu, or [Place] turned to.
signal _picked(result: Array)


func _ready() -> void:
	App.world = self
	add_child(_guide)


func save_state() -> Dictionary:
	return {done = done, seen = seen}


func load_state(data: Dictionary) -> void:
	done = data.get("done", {})
	seen = data.get("seen", [])


func run() -> void:
	App.reality.apply_view(App.session.base_view)
	await say(adventure.greeting)
	if not App.reality.is_settled:
		await App.reality.settled
	var first := _new_elsewhere()
	if first == null: # everything open was seen in an earlier run
		first = adventure.places[0]
	if _facing(first):
		_enter(first)
	else:
		_guide.point_to(position_of(first))
		Events.say(first.turn_to)
		_enter((await _watch())[0])
	while true:
		var picked: Array = await _choose()
		if picked.size() == 1:
			_enter(picked[0])
			continue
		var task: Task = picked[0]
		var level: int = picked[1]
		await App.session.play(task.levels[level])
		await _complete(task, level)


func is_done(task: Task, level := -1) -> bool:
	var levels: Array = done.get(task.id, [])
	return not levels.is_empty() if level < 0 else level in levels


## The first level of [param task] not done yet (0 = level 1), -1 when all are.
## Every level is open; this is just the one the menu lights up.
func current(task: Task) -> int:
	for level in task.levels.size():
		if not is_done(task, level):
			return level
	return -1


## A level at [param where] has not been seen on a menu yet.
func has_new(where: Place) -> bool:
	for task in where.tasks:
		for level in task.levels.size():
			if not key(task, level) in seen:
				return true
	return false


## "<task id>:<level>": how saves name one level of a task.
static func key(task: Task, level: int) -> String:
	return "%s:%d" % [task.id, level]


## Where [param where] is in the room: the table, or [constant BEHIND] metres
## the other way from the eyes, at eye height.
func position_of(where: Place) -> Vector3:
	var table := App.reality.work_surface().transform.origin
	if where.where == "table":
		return table
	var eye := App.head().global_position
	return eye + Vector3(eye.x - table.x, 0.0, eye.z - table.z).normalized() * BEHIND


## The first place other than [member place] with something new, else null
## (before the first place: the first with something new).
func _new_elsewhere() -> Place:
	for candidate in adventure.places:
		if candidate != place and has_new(candidate):
			return candidate
	return null


func _enter(where: Place) -> void:
	place = where
	_guide.stop()
	Events.report(&"place_entered", {place = where.title})


## Waits until the child has faced a place other than [member place]: [Place].
func _watch() -> Array:
	_faced_for.clear()
	_watching = true
	var result: Array = await _picked
	_watching = false
	return result


func _process(delta: float) -> void:
	if not _watching:
		return
	for candidate in adventure.places:
		if candidate == place:
			continue
		_faced_for[candidate] = _faced_for.get(candidate, 0.0) + delta if _facing(candidate) else 0.0
		if _faced_for[candidate] >= FACING_SECONDS:
			_picked.emit([candidate])
			return


## The head is turned toward [param where], left-right within [constant FACING] degrees.
func _facing(where: Place) -> bool:
	var eye := App.head().global_transform
	var gaze := Vector2(-eye.basis.z.x, -eye.basis.z.z)
	var to_place := position_of(where) - eye.origin
	return rad_to_deg(absf(gaze.angle_to(Vector2(to_place.x, to_place.z)))) <= FACING


## Unfolds [member place]'s menu, the guide pointing to anything new elsewhere,
## and waits for a task and level ([Task, int]) or a turn to another place ([Place]).
func _choose() -> Array:
	menu = TaskMenu.new(place, self)
	App.stage.add_child(menu)
	var eye := App.head().global_position
	var to_place := position_of(place) - eye
	menu.place_at(eye, Vector3(to_place.x, 0.0, to_place.z).normalized())
	menu.chosen.connect(_picked.emit)
	for task in place.tasks:
		for level in task.levels.size():
			if not key(task, level) in seen:
				seen.append(key(task, level))
	Save.request()
	var elsewhere := _new_elsewhere()
	if elsewhere:
		_guide.point_to(position_of(elsewhere))
		Events.say(elsewhere.turn_to)
	else:
		Events.say(place.arrive)
	var picked: Array = await _watch()
	_guide.stop()
	menu.fold()
	menu = null
	if picked.size() == 2:
		Events.report(&"task_chosen", {task = picked[0].id, level = picked[1] + 1})
		await say("%s, level %d!" % [picked[0].title, picked[1] + 1])
	return picked


## Records the completed level and saves.
func _complete(task: Task, level: int) -> void:
	if not is_done(task, level):
		var levels: Array = done.get(task.id, [])
		levels.append(level)
		done[task.id] = levels
	Events.report(&"task_done", {task = task.id, level = level + 1})
	Save.write()
	await say(adventure.level_done)


## Says [param text] and waits about as long as it takes to hear it.
func say(text: String) -> void:
	Events.say(text)
	await get_tree().create_timer(clampf(text.length() * 0.06, 1.5, 6.0), false).timeout
