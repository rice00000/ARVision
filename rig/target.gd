class_name Target
extends Area3D
## Something virtual the child can point at or touch. Pointers hit it on the
## "targets" physics layer and report it through [Events]; [member id] tells
## the trial (and the tests) which one it was.

@export var id: StringName


## A Target named [param target_id] with a sphere of [param radius] around its origin.
static func sphere(target_id: StringName, radius: float) -> Target:
	var target := Target.new()
	target.id = target_id
	target.name = String(target_id)
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	(shape.shape as SphereShape3D).radius = radius
	target.add_child(shape)
	return target


func _init() -> void:
	collision_layer = Pointer.TARGET_LAYER
	collision_mask = 0
	monitoring = false
