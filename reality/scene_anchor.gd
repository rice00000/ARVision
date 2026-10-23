extends Node3D
## One object of the Meta room scan (a table, the floor, a wall...). The scene
## manager calls [method setup_scene]; it becomes a [Surface] and a collider on
## the "reality" physics layer. Checked on the PC with Meta XR Simulator rooms
## (tools/xrsim.py).


func setup_scene(entity: OpenXRFbSpatialEntity) -> void:
	var anchor := get_parent() as XRAnchor3D
	while not anchor.get_has_tracking_data(): # its pose arrives a frame or more after it is made
		await get_tree().process_frame
	var labels := entity.get_semantic_labels()
	var label := labels[0].to_lower() if not labels.is_empty() else "other"
	var body := StaticBody3D.new()
	body.collision_layer = Reality.REALITY_LAYER
	body.collision_mask = 0
	body.add_child(entity.create_collision_shape())
	add_child(body)
	var shape := entity.create_mesh_instance() as MeshInstance3D
	var box := shape.transform * shape.get_aabb()
	shape.free()
	var face := top_face(box, global_basis)
	var frame: Transform3D = global_transform * face.frame
	App.reality.add_surface(Surface.new(StringName(label), frame, face.size, self))
	PassthroughReality.note(&"room_surface", {kind = label, size = face.size, centre = frame.origin, normal = frame.basis.y})


## The surface of a scanned entity with local bounds [param box] whose axes point
## along [param world] (its global basis): [code]frame[/code] (local, +Y the
## normal) and [code]size[/code]. A scanned plane (floor, table top, wall) is
## flat along local Z and keeps that normal, as OpenXR defines it. A box (a
## table or couch scanned as a volume) is used from the top: the local axis
## nearest straight up, whatever the plugin's mesh layout.
static func top_face(box: AABB, world: Basis) -> Dictionary:
	var up := 2
	var sign := 1.0
	if box.size.z > 0.01:
		for i in [0, 1]:
			if absf(world[i].normalized().y) > absf(world[up].normalized().y):
				up = i
		sign = signf(world[up].y)
	var across := (up + 1) % 3
	var normal := Vector3.ZERO
	normal[up] = sign
	var x := Vector3.ZERO
	x[across] = 1.0
	var centre := box.get_center()
	centre[up] = box.end[up] if sign > 0.0 else box.position[up]
	return {frame = Transform3D(Basis(x, normal, x.cross(normal)), centre),
		size = Vector2(box.size[across], box.size[(up + 2) % 3])}
