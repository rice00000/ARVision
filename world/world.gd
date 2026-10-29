class_name World
extends Node
## Plays the [Adventure] when the Session has no plan. The room starts in black
## and white. Each [Place] has its own list of tasks. The guide points the way to
## the first place ("this way"); once the child turns to face it, its
## [TaskMenu] unfolds there. The chosen task plays at the chosen level, and the
## first time a task is done colour comes back. Then the menu of the same place
## comes back; if a level opened somewhere else that the child has not seen on a
## menu yet, the guide points there too. Turning to face another place folds this menu and opens that one. Only
## the body's turn counts for now, so it can be tested seated.
##
## Each level done the first time puts a treasure in the [Cabinet].
##
## Saved as "world" (see Save): the levels done of each task, the levels seen open, the colour, the treasures.

## Degrees within which the head faces a place (left-right only).
const FACING := 25.0
## Seconds the child keeps facing a place before its menu unfolds.
const FACING_SECONDS := 0.5
## How far behind the child a place "behind" is, metres.
const BEHIND := 1.5

@export var adventure: Adventure
## Start once the app is up, when the Session has no plan. Tests switch it off and call [method run].
@export var autostart := true

var save_key := "world"
## Task id -> the levels done (0 = level 1).
var done: Dictionary = {}
## Index into [member Adventure.colours].
var colour := 0
## "<task id>:<level>" of every level shown open on a menu.
var seen: Array = []
## "<task id>:<level>" -> the treasure that level put in the cabinet: {shape, colour (html)}.
var treasures: Dictionary = {}
## The open menu, or null.
var menu: TaskMenu
## The place the child is at, or null before the first.
var place: Place

var _guide := Guide.new()
## Built the first time it is needed, once the save is loaded.
var _cabinet: Cabinet
## What the child found in the last solved round of the level being played: {shape, colour}, or {}.
var _found: Dictionary = {}
## While true, facing a place other than [member place] for long enough sends [signal _picked].
var _watching := false
var _faced_for: Dictionary[Place, float] = {}

## [Task, level] chosen on the menu, or [Place] turned to.
signal _picked(result: Array)


func _ready() -> void:
	Events.trial_ended.connect(func(_skill: StringName, success: bool, data: Dictionary) -> void:
		if success and data.has("found"):
			_found = data.found)
	App.world = self
	add_child(_guide)
	if autostart and App.session.plan == null:
		run.call_deferred()


func save_state() -> Dictionary:
	return {done = done, colour = colour, seen = seen, treasures = treasures}


func load_state(data: Dictionary) -> void:
	done = data.get("done", {})
	colour = data.get("colour", 0)
	seen = data.get("seen", [])
	treasures = data.get("treasures", {})


func run() -> void:
	_show_colour()
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
		_found = {}
		await App.session.play(task.levels[level])
		await _complete(task, level)


func is_done(task: Task, level := -1) -> bool:
	var levels: Array = done.get(task.id, [])
	return not levels.is_empty() if level < 0 else level in levels


## Every task it needs is done, at any level.
func is_unlocked(task: Task) -> bool:
	return task.requires.all(func(needed: Task) -> bool: return is_done(needed))


## [param level] (0 = level 1) can be chosen: the task is unlocked and the level before is done.
func can_play(task: Task, level: int) -> bool:
	return is_unlocked(task) and (level == 0 or is_done(task, level - 1))


## A level at [param where] can be chosen and has not been seen on a menu yet.
func has_new(where: Place) -> bool:
	for task in where.tasks:
		for level in task.levels.size():
			if can_play(task, level) and not key(task, level) in seen:
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
	var eye := App.head().global_position
	var to_place := position_of(where) - eye
	cabinet().place_beside(eye, Vector3(to_place.x, 0.0, to_place.z).normalized())
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
			if can_play(task, level) and not key(task, level) in seen:
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


## The treasure cabinet, built on first use.
func cabinet() -> Cabinet:
	if _cabinet == null:
		_cabinet = Cabinet.new(self)
		add_child(_cabinet)
	return _cabinet


## A level done the first time gives a treasure, a task done the first time
## brings colour back; saves.
func _complete(task: Task, level: int) -> void:
	var more_colour := not is_done(task) and task.colour > 0 and colour < adventure.colours.size() - 1
	var report := {task = task.id, level = level + 1}
	if not is_done(task, level):
		var levels: Array = done.get(task.id, [])
		levels.append(level)
		done[task.id] = levels
		var treasure := _found if not _found.is_empty() else \
			{shape = "gem", colour = Color.from_ok_hsl(fposmod(0.55 + 0.18 * level, 1.0), 0.75, 0.65).to_html(false)}
		treasures[key(task, level)] = treasure
		report.merge({treasure = treasure, slot = cabinet().slot_position(task, level), size = Cabinet.TREASURE,
			arrive = Cabinet.ARRIVE})
		cabinet().receive(task, level, treasure)
	if more_colour:
		colour = mini(colour + task.colour, adventure.colours.size() - 1)
		_show_colour()
	report.colour = colour
	Events.report(&"task_done", report)
	Save.write()
	await say(adventure.new_treasure if report.has("treasure") else adventure.level_done)
	if more_colour:
		Events.feedback.emit(&"good", App.head().global_position + App.head().global_basis * Vector3(0.0, -0.1, -0.5))
		await say("Look! Colour is coming back to your room." if colour < adventure.colours.size() - 1
			else "Your room has all its colours back!")


## Says [param text] and waits about as long as it takes to hear it.
func say(text: String) -> void:
	Events.say(text)
	await get_tree().create_timer(clampf(text.length() * 0.06, 1.5, 6.0), false).timeout


func _show_colour() -> void:
	App.session.base_view = adventure.colours[colour]
	App.reality.apply_view(App.session.base_view)
