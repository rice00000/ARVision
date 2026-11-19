class_name Place
extends Resource
## Somewhere in the real room with its own list of tasks. The guide points the
## child there; facing it unfolds its task menu. Lives in content/places/.

@export var title := ""
## "table": the work surface. "behind": the other way, behind the seated child.
@export_enum("table", "behind") var where: String = "table"
## The guide says this while pointing the way.
@export var turn_to := ""
## Said when the child faces the place and its menu unfolds.
@export var arrive := ""
@export var tasks: Array[Task] = []
## A few no-help rounds on new things, played before the menu when due
## (see CheckIns). Null = this place never checks in.
@export var check_in: SessionPlan
