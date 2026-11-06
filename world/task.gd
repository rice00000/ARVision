class_name Task
extends Resource
## Something the child can choose at a [Place]: one [SessionPlan] per level.
## Lives in content/tasks/; the file name is its id.
## Every level is always open.

@export var title := ""
@export_range(1, 9) var reward_stones := 2
## Easiest first. Each block sets its own [member Block.difficulty] and
## [member Block.pins], so a level can change more than how hard it is.
@export var levels: Array[SessionPlan] = []

var id: StringName:
	get:
		return StringName(resource_path.get_file().get_basename())
