class_name Task
extends Resource
## Something the child can choose at a [Place]: a [SessionPlan] played at one
## of [member levels]. Lives in content/tasks/; the file name is its id.
##
## Locked until every task in [member requires] is done at some level. Level 1
## is open once the task is; each next level opens when the one before is done.

@export var title := ""
@export var plan: SessionPlan
## The difficulty (0-1) each level runs every round at, easiest first.
@export var levels: PackedFloat32Array = [0.1, 0.4, 0.7]
@export var requires: Array[Task] = []

@export_group("Rewards")
## Steps of colour given back the first time the task is done.
@export var colour := 0
## Magic stones for each level done the first time.
@export var stones := 1

var id: StringName:
	get:
		return StringName(resource_path.get_file().get_basename())
