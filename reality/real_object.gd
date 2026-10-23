class_name RealObject
extends Node3D
## A thing in a simulated room that a camera could recognise: the simulated
## detector reports it while the eyes can see it. Use the COCO class names a real
## detector (YOLO) uses, so trials work the same with either.

const GROUP := &"real_object"

@export var label := "cup"


func _enter_tree() -> void:
	add_to_group(GROUP)


## World-space box around its meshes.
func box() -> AABB:
	var found := AABB()
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		var part := mesh.global_transform * mesh.get_aabb()
		found = part if found.size == Vector3.ZERO else found.merge(part)
	return found


func centre() -> Vector3:
	return box().get_center()


## Half its middle extent: about how wide it looks (a bottle is as wide as it
## is deep, not as tall).
func radius() -> float:
	var size := box().size
	return (size.x + size.y + size.z - size[size.max_axis_index()] - size[size.min_axis_index()]) * 0.5


## The object's own colliders, which must not count as hiding it.
func bodies() -> Array[RID]:
	var rids: Array[RID] = []
	for body: CollisionObject3D in find_children("*", "CollisionObject3D", true, false):
		rids.append(body.get_rid())
	return rids
