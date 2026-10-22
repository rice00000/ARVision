class_name SimSurface
extends Marker3D
## Marks a flat surface in a simulated room, at the centre of its top face with
## +Y up: what a Quest room scan would report there.

const GROUP := &"sim_surface"

@export var kind := &"table"
## Width (X) and depth (Z), metres.
@export var size := Vector2(1.2, 0.7)


func _enter_tree() -> void:
	add_to_group(GROUP)
