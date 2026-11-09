class_name TaskLevel
extends Resource
## Stable within the task. Edit the title, project and rewards in the Inspector.

@export var id: StringName
@export var project: StringName
@export var title := ""
@export_range(0, 9) var first_reward := 3
@export_range(0, 9) var repeat_reward := 2
@export var plan: SessionPlan
