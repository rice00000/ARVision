extends Node3D
## Room decoration made from the same mesh as the Find the object toy.

const SIZE := 0.36

@export var shape: StringName = &"ball"
@export var colour: Color = Color.WHITE


func _ready() -> void:
	var visual := MeshInstance3D.new()
	visual.mesh = Shapes.mesh(shape, SIZE)
	visual.position.y = -visual.mesh.get_aabb().position.y
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	visual.material_override = material
	add_child(visual)
