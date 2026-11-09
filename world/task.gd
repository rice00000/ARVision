class_name Task
extends Resource
## Something the child can choose at a [Place].
## Lives in content/tasks/; the file name is its id.
## Every level is always open.

@export var title := ""
## Menu order. Each project numbers its own entries in this order.
@export var levels: Array[TaskLevel] = []

var id: StringName:
	get:
		return StringName(resource_path.get_file().get_basename())


func level_by_id(level_id: StringName) -> TaskLevel:
	for level in levels:
		if level.id == level_id:
			return level
	return null


func project_number(level: TaskLevel) -> int:
	var number := 0
	for candidate in levels:
		if candidate.project == level.project:
			number += 1
		if candidate == level:
			return number
	return number
