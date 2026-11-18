class_name HomeUI
extends RefCounted
## Chunky world objects and generous ray hit areas; labels only supplement speech.

const INK := Color(0.07, 0.10, 0.15)
const CREAM := Color(0.95, 0.91, 0.78)
const GOLD := Color(1.0, 0.68, 0.15)
## The workshop's stones are teal (Megan, Nov 18: one stone look everywhere; violet was dropped). The
## workshop sets this while it runs; Wei's own game keeps his violet.
static var teal_stones := false
const TEAL := Color(0.16, 0.66, 0.68)


## A magic stone (Wei's model), teal in the workshop.
static func gem() -> Node3D:
	var stone: Node3D = load("res://content/items/visuals/magic_stone.tscn").instantiate()
	if teal_stones:
		var teal := material(TEAL)
		for mesh: MeshInstance3D in stone.find_children("*", "MeshInstance3D", true, false):
			mesh.material_override = teal
	return stone


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
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var face_size := Vector2(0.23, 0.064) if icon.is_empty() else Vector2(0.115, 0.105)
	box.size = Vector3(face_size.x + 0.02, face_size.y + 0.02, 0.04)
	shape.shape = box
	node.add_child(shape)
	node.set_meta(&"speech", speech)
	node.position = at
	parent.add_child(node)
	var face := box(node, Vector3(face_size.x, face_size.y, 0.025), Vector3.ZERO, CREAM)
	face.name = "Face"
	if icon.is_empty():
		var words := label(node, caption, Vector3(0, 0, 0.018))
		words.modulate = INK
		words.outline_size = 0
		return node
	elif icon == "house":
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
	elif icon == "pet":
		var pet: Node3D = load("res://content/pets/kenney/cat.glb").instantiate()
		pet.scale = Vector3.ONE * 0.045
		pet.position = Vector3(0, -0.036, 0.045)
		pet.rotation.y = 0.4
		node.add_child(pet)
	elif icon in ["left", "right"]:
		arrow(node, Vector3(0, 0, 0.03), 0.075, icon == "left")
	elif icon == "back":
		arrow(node, Vector3(-0.02, 0, 0.03), 0.045, true)
		box(node, Vector3(0.045, 0.022, 0.025), Vector3(0.022, 0, 0.03), INK)
	elif icon == "check":
		check(node, Vector3(0, 0, 0.025), 1.0)
	elif icon == "cross":
		for turn in [PI / 4, -PI / 4]:
			box(node, Vector3(0.08, 0.02, 0.02), Vector3(0, 0, 0.025), INK).rotation.z = turn
	elif icon == "box":
		box(node, Vector3(0.065, 0.045, 0.04), Vector3(0, -0.006, 0.035), GOLD)
		box(node, Vector3(0.07, 0.014, 0.045), Vector3(0, 0.023, 0.035), INK)
	elif icon == "door":
		box(node, Vector3(0.046, 0.078, 0.02), Vector3(0, 0, 0.025), INK)
		box(node, Vector3(0.011, 0.011, 0.012), Vector3(0.012, -0.004, 0.04), GOLD)
	elif icon == "cauldron":
		# Back to the workshop (Megan, Nov 18): a little cauldron with green brew, tipped toward the child so the
		# brew shows, with its two handles. Not a ✕ (in the workshop ✕ means stop or finish).
		var cauldron := Node3D.new()
		cauldron.position = Vector3(0, -0.008, 0.04)
		cauldron.rotation.x = 0.55
		node.add_child(cauldron)
		var pot := MeshInstance3D.new()
		var body := SphereMesh.new()
		body.radius = 0.03
		body.height = 0.05
		pot.mesh = body
		pot.material_override = material(Color(0.86, 0.82, 0.7))
		cauldron.add_child(pot)
		var brew := MeshInstance3D.new()
		var top := CylinderMesh.new()
		top.top_radius = 0.024
		top.bottom_radius = 0.024
		top.height = 0.004
		brew.mesh = top
		brew.material_override = material(Color(0.45, 0.72, 0.25))
		brew.position = Vector3(0, 0.024, 0)   # just under the rim, above the pot's own surface
		cauldron.add_child(brew)
		var rim := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.023
		ring.outer_radius = 0.03
		rim.mesh = ring
		rim.material_override = material(INK)
		rim.position = Vector3(0, 0.025, 0)
		cauldron.add_child(rim)
		for side in [-1.0, 1.0]:
			var handle := MeshInstance3D.new()
			var loop := TorusMesh.new()
			loop.inner_radius = 0.006
			loop.outer_radius = 0.01
			handle.mesh = loop
			handle.material_override = material(INK)
			handle.rotation.z = PI * 0.5
			handle.position = Vector3(side * 0.032, 0.006, 0)
			cauldron.add_child(handle)
	elif icon == "stone":
		var gem := gem()
		gem.scale = Vector3.ONE * 0.65
		gem.position = Vector3(0, -0.026, 0.04)
		node.add_child(gem)
	else:
		var glyph := label(node, icon, Vector3(0, 0, 0.018), 68)
		glyph.modulate = INK
		glyph.outline_size = 0
	label(node, caption, Vector3(0, -0.078, 0.02), 27)
	return node


## A solid triangle pointing left or right.
static func arrow(parent: Node3D, at: Vector3, size: float, left: bool) -> void:
	var mesh := MeshInstance3D.new()
	mesh.mesh = PrismMesh.new()
	(mesh.mesh as PrismMesh).size = Vector3(size, size * 0.8, 0.025)
	mesh.material_override = material(INK)
	mesh.position = at
	mesh.rotation.z = PI / 2 if left else -PI / 2
	parent.add_child(mesh)


## A thick check mark.
static func check(parent: Node3D, at: Vector3, size: float, colour := INK) -> void:
	box(parent, Vector3(0.036, 0.02, 0.02) * size, at + Vector3(-0.024, -0.012, 0) * size, colour).rotation.z = -PI / 4
	box(parent, Vector3(0.072, 0.02, 0.02) * size, at + Vector3(0.012, 0.002, 0) * size, colour).rotation.z = PI / 3.6


## A magic stone and how many: the balance, or a price.
static func stones(parent: Node3D, count: int, at: Vector3) -> void:
	var gem := gem()
	gem.scale = Vector3.ONE * 0.5
	gem.position = at + Vector3(-0.03, -0.02, 0)
	parent.add_child(gem)
	label(parent, str(count), at + Vector3(0.03, 0, 0), 48)


## A price: the stone and its number, then a bar of fixed length that fills as
## the child's stones near the price, and a check mark once they are enough.
## Length and the mark carry it, not colour.
static func price(parent: Node3D, cost: int, owned: int, at: Vector3) -> void:
	stones(parent, cost, at + Vector3(-0.19, 0, 0))
	var length := 0.26
	var filled := length * minf(1.0, float(owned) / cost)
	box(parent, Vector3(length, 0.022, 0.01), at + Vector3(0.05, 0, 0), Color(0.28, 0.31, 0.37))
	if filled > 0:
		box(parent, Vector3(filled, 0.036, 0.018), at + Vector3(0.05 - (length - filled) * 0.5, 0, 0), GOLD)
	if owned >= cost:
		check(parent, at + Vector3(0.245, 0, 0.01), 0.8, GOLD)


static func preview(parent: Node3D, item: ItemDef, at: Vector3, size: float) -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	var visual: Node3D = item.scene.instantiate()
	holder.add_child(visual)
	if item.kind == ItemDef.Kind.ROOM:
		for part in [^"Sky", ^"Roof", ^"Front", ^"Sides"]:
			visual.get_node(part).free()
	var bounds := bounds_of(visual)
	var extent := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if item.kind == ItemDef.Kind.FURNITURE:
		# Leave room for the corners of wide furniture as the preview rotates.
		extent = maxf(extent, bounds.size.length() / 1.25)
	var ratio := size / extent
	visual.scale = Vector3.ONE * ratio
	visual.position = -bounds.get_center() * ratio
	holder.position = at
	holder.rotation = Vector3(0.31, -0.23, 0) if item.kind == ItemDef.Kind.ROOM else Vector3(0.10, -0.35, 0)
	return holder


static func bounds_of(node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var local := node.global_transform.affine_inverse() * mesh.global_transform * mesh.mesh.get_aabb()
		bounds = local if first else bounds.merge(local)
		first = false
	return bounds
