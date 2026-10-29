class_name Place
extends Resource
## Somewhere in the real room with its own tasks. The guide points the child
## there; facing it unfolds its task menu. For now every place is the table
## (App.reality.work_surface()). Lives in content/places/.

@export var title := ""
## The guide says this while pointing the way.
@export var turn_to := ""
## Said when the child faces the place and its menu unfolds.
@export var arrive := ""
@export var tasks: Array[Task] = []
