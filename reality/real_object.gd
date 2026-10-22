class_name RealObject
extends Node3D
## A thing in a simulated room that a camera could recognise: the simulated
## detector reports it while the eyes can see it. Use the COCO class names a real
## detector (YOLO) uses, so trials work the same with either.

const GROUP := &"real_object"

@export var label := "cup"


func _enter_tree() -> void:
	add_to_group(GROUP)


## Centre of its meshes, world space.
func centre() -> Vector3:
	var box := AABB()
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		var part := mesh.global_transform * mesh.get_aabb()
		box = part if box.size == Vector3.ZERO else box.merge(part)
	return box.get_center()


## The object's own colliders, which must not count as hiding it.
func bodies() -> Array[RID]:
	var rids: Array[RID] = []
	for body: CollisionObject3D in find_children("*", "CollisionObject3D", true, false):
		rids.append(body.get_rid())
	return rids
