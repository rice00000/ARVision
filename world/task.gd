class_name Task
extends Resource
## Something the child can choose at a [Place]: one [SessionPlan] per level.
## Lives in content/tasks/; the file name is its id.
##
## Locked until every task in [member requires] is done at some level. Level 1
## is open once the task is; each next level opens when the one before is done.

@export var title := ""
## Easiest first. Each block sets its own [member Block.difficulty] and
## [member Block.pins], so a level can change more than how hard it is.
@export var levels: Array[SessionPlan] = []
@export var requires: Array[Task] = []

var id: StringName:
	get:
		return StringName(resource_path.get_file().get_basename())
