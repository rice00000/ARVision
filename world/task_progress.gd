class_name TaskProgress
extends Node
## Shared by the activity scenes and the Onion tutorial.

## Freeze the shipped positional order for old saves, independent of menu edits.
const LEGACY_IDS := {
	&"tidy_shelf": [&"shadow", &"similar_shadows", &"outline", &"size", &"color", &"clutter"],
	&"break_wall": [&"steady_flow", &"mixed_flow"],
}

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


static func key(task: Task, level: TaskLevel) -> String:
	return "%s:%s" % [task.id, level.id]
