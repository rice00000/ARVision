class_name HomeUI
extends RefCounted
## Chunky world objects and generous ray hit areas; labels only supplement speech.

const INK := Color(0.07, 0.10, 0.15)
const CREAM := Color(0.95, 0.91, 0.78)
const GOLD := Color(1.0, 0.68, 0.15)


static func material(colour: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour
	mat.roughness = 0.85
	return mat


static func box(parent: Node3D, size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	(mesh.mesh as BoxMesh).size = size
	mesh.material_override = material(colour)
	mesh.position = at
	parent.add_child(mesh)
	return mesh


static func label(parent: Node3D, text: String, at: Vector3, font_size := 36) -> Label3D:
	var node := Label3D.new()
	node.text = text
	node.position = at
	node.font_size = font_size
	node.pixel_size = 0.00065
	node.outline_size = 6
	node.modulate = CREAM
	parent.add_child(node)
	return node


static func button(parent: Node3D, id: StringName, caption: String, speech: String, at: Vector3, icon := "") -> Target:
	var node := UITarget.new()
	node.collision_layer = Pointer.MENU_LAYER
	node.id = id
	node.name = String(id)
	node.show_ray = id != &"home_open"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.135, 0.125, 0.04)
	shape.shape = box
	node.add_child(shape)
	node.set_meta(&"speech", speech)
	node.position = at
	parent.add_child(node)
	var face := box(node, Vector3(0.115, 0.105, 0.025), Vector3.ZERO, CREAM)
	face.name = "Face"
	if icon == "house":
		box(node, Vector3(0.06, 0.042, 0.025), Vector3(0, -0.006, 0.025), INK)
		var roof := box(node, Vector3(0.047, 0.047, 0.015), Vector3(0, 0.019, 0.023), GOLD)
		roof.rotation.z = PI / 4
		box(node, Vector3(0.018, 0.027, 0.008), Vector3(0, -0.013, 0.043), CREAM)
	elif icon == "chair":
		var item: Node3D = load("res://content/items/visuals/chair.tscn").instantiate()
		item.scale = Vector3.ONE * 0.09
		item.position = Vector3(0, -0.038, 0.04)
		item.rotation.y = -0.4
		node.add_child(item)
	elif icon == "bag":
		box(node, Vector3(0.065, 0.045, 0.04), Vector3(0, -0.006, 0.035), GOLD)
		box(node, Vector3(0.07, 0.014, 0.045), Vector3(0, 0.023, 0.035), INK)
	else:
		var glyph := label(node, icon, Vector3(0, 0, 0.018), 68)
		glyph.modulate = INK
		glyph.outline_size = 0
	label(node, caption, Vector3(0, -0.078, 0.02), 27)
	return node


static func stones(parent: Node3D, count: int, at: Vector3, owned := -1) -> void:
	for i in mini(count, 9):
		var gem := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.012
		mesh.height = 0.03
		mesh.radial_segments = 6
		mesh.rings = 2
		gem.mesh = mesh
		gem.material_override = material(GOLD if owned < 0 or i < owned else Color(0.28, 0.31, 0.37))
		gem.position = at + Vector3((i - (mini(count, 9) - 1) * 0.5) * 0.032, 0, 0)
		parent.add_child(gem)


static func preview(parent: Node3D, item: ItemDef, at: Vector3, size: float) -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	var visual: Node3D = item.scene.instantiate()
	holder.add_child(visual)
	if item.kind == ItemDef.Kind.ROOM:
		visual.get_node(^"Sky").free()
		visual.get_node(^"Roof").free()
		visual.get_node(^"Front").free()
	var bounds := bounds_of(visual)
	var ratio := size / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	visual.scale = Vector3.ONE * ratio
	visual.position = -bounds.get_center() * ratio
	holder.position = at
	holder.rotation = Vector3(0.28, -0.35, 0) if item.kind == ItemDef.Kind.ROOM else Vector3(0.10, -0.35, 0)
	return holder


static func bounds_of(node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var local := node.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
		bounds = local if first else bounds.merge(local)
		first = false
	return bounds
