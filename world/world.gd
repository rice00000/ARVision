class_name World
extends Node
## Plays the [Adventure] when the Session has no plan. The room starts in black
## and white. The guide points the way to a [Place] ("this way"); once the child
## turns to face it, its [TaskMenu] unfolds there. The chosen task plays at the
## chosen level; doing it gives back colour and magic stones, then the menu of
## the same place comes back without turning again. Only the body's turn counts
## for now, so it can be tested seated.
##
## Saved as "world" (see Save): the levels done of each task, colour, stones.

## Degrees within which the head faces a place (left-right only).
const FACING := 25.0
## Seconds the child keeps facing it before the menu unfolds.
const FACING_SECONDS := 0.5

@export var adventure: Adventure
## Start once the app is up, when the Session has no plan. Tests switch it off and call [method run].
@export var autostart := true

var save_key := "world"
## Task id -> the levels done (0 = level 1).
var done: Dictionary = {}
## Index into [member Adventure.colours].
var colour := 0
var stones := 0
## The open menu, or null.
var menu: TaskMenu
## The place being pointed at or visited, or null before the first.
var place: Place

var _guide := Guide.new()
var _faced_for := 0.0
var _awaiting_face := false

signal _faced


func _ready() -> void:
	App.world = self
	add_child(_guide)
	if autostart and App.session.plan == null:
		run.call_deferred()


func save_state() -> Dictionary:
	return {done = done, colour = colour, stones = stones}


func load_state(data: Dictionary) -> void:
	done = data.get("done", {})
	colour = data.get("colour", 0)
	stones = data.get("stones", 0)


func run() -> void:
	_show_colour()
	await say(adventure.greeting)
	if not App.reality.is_settled:
		await App.reality.settled
	while true:
		var next := _next_place()
		if next != place:
			await _go_to(next)
		var choice: Array = await _choose()
		var task: Task = choice[0]
		var level: int = choice[1]
		await App.session.play(task.plan, task.levels[level])
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


## Where [param _where] is in the room: the table, for now.
func position_of(_where: Place) -> Vector3:
	return App.reality.work_surface().transform.origin


## The first place with a level open and not done yet, else the first place.
func _next_place() -> Place:
	for candidate in adventure.places:
		for task in candidate.tasks:
			for level in task.levels.size():
				if can_play(task, level) and not is_done(task, level):
					return candidate
	return adventure.places[0]


## Points the way to [param where] until the child faces it.
func _go_to(where: Place) -> void:
	place = where
	if not _facing():
		_guide.point_to(position_of(where))
		Events.say(where.turn_to)
		_faced_for = 0.0
		_awaiting_face = true
		await _faced
		_guide.stop()
	Events.report(&"place_entered", {place = where.title})


func _process(delta: float) -> void:
	if not _awaiting_face:
		return
	_faced_for = _faced_for + delta if _facing() else 0.0
	if _faced_for >= FACING_SECONDS:
		_awaiting_face = false
		_faced.emit()


## The head is turned toward [member place], left-right within [constant FACING] degrees.
func _facing() -> bool:
	var eye := App.head().global_transform
	var gaze := Vector2(-eye.basis.z.x, -eye.basis.z.z)
	var to_place := position_of(place) - eye.origin
	return rad_to_deg(absf(gaze.angle_to(Vector2(to_place.x, to_place.z)))) <= FACING


## Unfolds [member place]'s menu and waits for a task and level: [Task, int].
func _choose() -> Array:
	menu = TaskMenu.new(place, self)
	App.stage.add_child(menu)
	var eye := App.head().global_position
	var to_place := position_of(place) - eye
	var ahead := Vector3(to_place.x, 0.0, to_place.z).normalized()
	menu.place_at(eye, ahead)
	Events.say(place.arrive)
	var choice: Array = await menu.chosen
	Events.report(&"task_chosen", {task = choice[0].id, level = choice[1] + 1})
	menu.fold()
	await say("%s, level %d!" % [choice[0].title, choice[1] + 1])
	menu = null
	return choice


## Gives the rewards for the first time [param task] is done at [param level] and saves.
func _complete(task: Task, level: int) -> void:
	var first_time := not is_done(task)
	var new_level := not is_done(task, level)
	if new_level:
		var levels: Array = done.get(task.id, [])
		levels.append(level)
		done[task.id] = levels
		stones += task.stones
	var more_colour := first_time and task.colour > 0 and colour < adventure.colours.size() - 1
	if more_colour:
		colour = mini(colour + task.colour, adventure.colours.size() - 1)
		_show_colour()
	Events.report(&"task_done", {task = task.id, level = level + 1, stones = stones, colour = colour})
	Save.write()
	if new_level and task.stones > 0:
		Events.feedback.emit(&"good", App.head().global_position + App.head().global_basis * Vector3(0.0, -0.1, -0.5))
		await say("You earned a magic stone!")
	if more_colour:
		await say("Look! Colour is coming back to your room." if colour < adventure.colours.size() - 1
			else "Your room has all its colours back!")


## Says [param text] and waits about as long as it takes to hear it.
func say(text: String) -> void:
	Events.say(text)
	await get_tree().create_timer(clampf(text.length() * 0.06, 1.5, 6.0), false).timeout


func _show_colour() -> void:
	App.session.base_view = adventure.colours[colour]
	App.reality.apply_view(App.session.base_view)
