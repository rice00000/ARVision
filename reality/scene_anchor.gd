extends Node3D
## One object of the Meta room scan (a table, the floor, a wall...). The scene
## manager calls [method setup_scene]; it becomes a [Surface] and a collider on
## the "reality" physics layer.


func setup_scene(entity: OpenXRFbSpatialEntity) -> void:
	if not is_inside_tree():
		await ready
	var labels := entity.get_semantic_labels()
	var label := labels[0].to_lower() if not labels.is_empty() else "other"
	var body := StaticBody3D.new()
	body.collision_layer = Reality.REALITY_LAYER
	body.collision_mask = 0
	body.add_child(entity.create_collision_shape())
	add_child(body)
	var shape := entity.create_mesh_instance() as MeshInstance3D
	var box := shape.get_aabb()
	shape.free()
	# Scanned planes are flat: their thinnest extent is the normal. Turn it to +Y,
	# pointing up for floors and tables.
	var axis := 0
	for i in [1, 2]:
		if box.size[i] < box.size[axis]:
			axis = i
	var normal := global_basis[axis].normalized()
	if normal.y < 0.0:
		normal = -normal
	var across := global_basis[(axis + 1) % 3].normalized()
	var frame := Basis(across, normal, across.cross(normal)).orthonormalized()
	var extent := Vector2(box.size[(axis + 1) % 3], box.size[(axis + 2) % 3])
	var centre := global_transform * box.get_center()
	App.reality.add_surface(Surface.new(StringName(label), Transform3D(frame, centre), extent, self))
