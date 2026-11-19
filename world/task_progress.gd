class_name TaskProgress
extends Node
## Shared by the activity scenes and the Onion tutorial.

## Freeze the shipped positional order for old saves, independent of menu edits.
const LEGACY_IDS := {
	&"tidy_shelf": [&"shadow", &"similar_shadows", &"outline", &"size", &"color", &"clutter"],
	&"break_wall": [&"steady_flow", &"mixed_flow"],
}

## An adaptive level is the one to play next until the child has climbed this far up its range.
const READY_AT := 0.7

var save_key := "world"
var done: Dictionary = {}
var seen: Array = []


func save_state() -> Dictionary:
	return {stable_ids = true, done = done, seen = seen}


func load_state(data: Dictionary) -> void:
	if data.get("stable_ids", false):
		done = data.get("done", {})
		seen = data.get("seen", [])
		return
	done = {}
	seen = []
	var old_done: Dictionary = data.get("done", {})
	var old_seen: Array = data.get("seen", [])
	for task_id: StringName in LEGACY_IDS:
		var ids: Array = LEGACY_IDS[task_id]
		for index: int in old_done.get(task_id, []):
			if index >= 0 and index < ids.size():
				if not done.has(task_id): done[task_id] = []
				done[task_id].append(ids[index])
		for index in ids.size():
			if "%s:%d" % [task_id, index] in old_seen:
				seen.append("%s:%s" % [task_id, ids[index]])


func is_done(task: Task, level: TaskLevel) -> bool:
	return level.id in done.get(task.id, [])


func reward(task: Task, level: TaskLevel) -> int:
	return level.repeat_reward if is_done(task, level) else level.first_reward


func complete(task: Task, level: TaskLevel) -> int:
	var stones := reward(task, level)
	if not is_done(task, level):
		var completed: Array = done.get(task.id, [])
		completed.append(level.id)
		done[task.id] = completed
	var position := task.levels.find(level) + 1
	Events.level_won.emit(task.id, position, stones)
	Save.write()
	return stones


## Marks every level of [param task] finished, with no reward (the menu's Cheat button, for testing).
func finish_all(task: Task) -> void:
	var completed: Array = done.get(task.id, [])
	for level in task.levels:
		if level.id not in completed:
			completed.append(level.id)
	done[task.id] = completed
	Save.write()


## The level to play next among [param levels] (easiest first), or null: the first not yet finished, or finished
## but not yet climbed to [constant READY_AT] of its range (an adaptive level). Endless levels are never next.
func next(task: Task, levels: Array[TaskLevel]) -> TaskLevel:
	for level in levels:
		if level.plan != null and level.plan.is_endless():   # Turn to fit's one level has no plan
			continue
		if not is_done(task, level) or (level.climbed() >= 0.0 and level.climbed() < READY_AT):
			return level
	return null


static func key(task: Task, level: TaskLevel) -> String:
	return "%s:%s" % [task.id, level.id]
