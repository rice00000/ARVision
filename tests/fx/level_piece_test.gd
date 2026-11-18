extends TestCase
## The level pictures for a game's own row (entry/fx/level_piece.gd; design chat with Megan, Nov 18,
## claude/DESIGN_LEVEL_PICTURES.md).

const SHELF := preload("res://content/tasks/tidy_shelf.tres")
const BUTTERFLIES := preload("res://content/tasks/catch_butterflies.tres")
const FIND_OBJECTS: Array[StringName] = [&"shadow", &"size", &"clutter", &"color", &"similar_shadows"]
const NETS: Array[StringName] = [&"one_way", &"both_ways"]


static func _meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		found.append(mesh)
	return found


static func _colour(mesh: MeshInstance3D) -> Color:
	var material := mesh.material_override as StandardMaterial3D
	if material == null and mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
		material = mesh.get_active_material(0) as StandardMaterial3D
	return material.albedo_color if material != null else Color(0, 0, 0, 0)


static func _count(node: Node, colour: Color) -> int:
	return _meshes(node).filter(func(m: MeshInstance3D) -> bool: return _colour(m).is_equal_approx(colour)).size()


## What a picture is made of: each mesh's kind and colour, sorted (two different pictures differ here).
static func _signature(node: Node) -> String:
	var parts: Array[String] = []
	for mesh in _meshes(node):
		parts.append("%s:%s" % [mesh.mesh.get_class(), _colour(mesh).to_html(false)])
	parts.sort()
	return ",".join(parts)


func _box(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh in _meshes(node):
		var world := mesh.global_transform * mesh.get_aabb()
		box = world if first else box.merge(world)
		first = false
	return box


func test_every_find_objects_and_butterfly_level_has_its_own_picture() -> void:
	await boot(null, &"intro")
	var seen := {}
	for level in SHELF.levels + BUTTERFLIES.levels:
		var wanted: bool = level.id in FIND_OBJECTS or level.id in NETS
		expect_eq(LevelPiece.has_picture(level.id), wanted, "%s has a picture" % level.id)
		if not wanted:
			continue
		var picture := LevelPiece.make(level.id)
		app.add_child(picture)
		seen[_signature(picture)] = level.id
	expect_eq(seen.size(), FIND_OBJECTS.size() + NETS.size(), "the seven pictures all differ (%s)" % str(seen.values()))


func test_the_frame_says_which_game() -> void:
	await boot(null, &"intro")
	for id in FIND_OBJECTS:
		var picture := LevelPiece.make(id)
		app.add_child(picture)
		expect(_count(picture, LevelPiece.WOOD) >= 1 and _count(picture, LevelPiece.TILE) >= 1,
				"%s: a wood ring round a cream disc" % id)
		expect_eq(_count(picture, LevelPiece.NAVY), 0, "%s: no navy" % id)
	for id in NETS:
		var picture := LevelPiece.make(id)
		app.add_child(picture)
		expect(_count(picture, LevelPiece.NAVY) >= 1, "%s: a navy disc" % id)
		expect_eq(_count(picture, LevelPiece.WOOD), 0, "%s: no wood" % id)


func test_pictures_fit_their_bubble_and_face_the_child() -> void:
	await boot(null, &"intro")
	for id: StringName in FIND_OBJECTS + NETS:
		var picture := LevelPiece.make(id)
		app.add_child(picture)
		var box := _box(picture)
		var middle := LevelPiece.MIDDLE
		var far := 0.0
		for corner in 8:
			far = maxf(far, (box.get_endpoint(corner) - middle).length())
		expect(far < Impression.BUBBLE_RADIUS, "%s fits inside its bubble (%.3f m)" % [id, far])
		expect(box.size.x >= 0.13 and box.size.y >= 0.13, "%s is about the disc's size (%s)" % [id, box.size])
		expect(box.size.z <= (0.08 if id in NETS else 0.04), "%s is flat-ish, facing the child (depth %.3f)" % [id, box.size.z])


func test_the_rules_read_by_count_and_colour() -> void:
	await boot(null, &"intro")
	var pictures := {}
	for id: StringName in FIND_OBJECTS + NETS:
		pictures[id] = LevelPiece.make(id)
		app.add_child(pictures[id])
	expect_eq(_count(pictures[&"color"], LevelPiece.ORANGE), 1, "Color Match: one orange block")
	expect_eq(_count(pictures[&"color"], LevelPiece.BLUE), 1, "Color Match: one blue block")
	expect_eq(_count(pictures[&"size"], LevelPiece.ORANGE), 2, "Size Match: two orange blocks")
	expect(_count(pictures[&"clutter"], LevelPiece.ORANGE) + _count(pictures[&"clutter"], LevelPiece.BLUE)
			+ _count(pictures[&"clutter"], LevelPiece.YELLOW) + _count(pictures[&"clutter"], LevelPiece.PURPLE)
			+ _count(pictures[&"clutter"], LevelPiece.GREEN) == 5, "Clutter Search: five mixed shapes")
	var flies_one := _count(pictures[&"one_way"], LevelPiece.ORANGE)
	var flies_two := _count(pictures[&"both_ways"], LevelPiece.ORANGE)
	expect(flies_one > 0 and flies_two == flies_one * 2, "Both Ways has two butterflies, Butterfly Circle one (%d, %d)" % [flies_one, flies_two])
	var shadows_match: int = pictures[&"shadow"].find_children("*", "MeshInstance3D", true, false).filter(
			func(m: MeshInstance3D) -> bool: return m.mesh is PrismMesh).size()
	expect_eq(shadows_match, 2, "Shadow Match: a triangle and its one shadow")


func test_dress_swaps_the_piece_and_leaves_levels_without_a_picture_alone() -> void:
	await boot(null, &"intro")
	var piece := Impression.make(&"shelf")
	app.add_child(piece)
	var before := _signature(piece)
	expect(not LevelPiece.dress(piece, SHELF.level_by_id(&"odd_color_1")), "Odd Color has no picture yet")
	expect_eq(_signature(piece), before, "the piece stays the shelf")
	expect(LevelPiece.dress(piece, SHELF.level_by_id(&"size")), "Size Match dresses the piece")
	await frames(1)
	expect(_signature(piece) != before and _count(piece, LevelPiece.WOOD) >= 1, "the piece now shows the Size Match picture")
	expect_eq(piece.get_meta(&"level_picture", &""), &"size", "it remembers which picture")
	expect(piece.target != null and is_instance_valid(piece.target), "it can still be pressed")
	piece.add_bubble()
	expect(piece.bubble != null, "it still takes its bubble")
	var fly := Impression.make(&"butterflies")
	app.add_child(fly)
	expect(LevelPiece.dress(fly, BUTTERFLIES.level_by_id(&"both_ways")), "Both Ways dresses the butterflies' piece")


func test_nothing_moves() -> void:
	await boot(null, &"intro")
	for id: StringName in FIND_OBJECTS + NETS:
		var picture := LevelPiece.make(id)
		app.add_child(picture)
		var where := {}
		for mesh in _meshes(picture):
			where[mesh] = mesh.global_transform
		expect(picture.find_children("*", "AnimationPlayer", true, false).is_empty()
				and picture.find_children("*", "GPUParticles3D", true, false).is_empty()
				and picture.find_children("*", "CPUParticles3D", true, false).is_empty(), "%s has nothing animated" % id)
		await frames(10)
		var still := true
		for mesh: MeshInstance3D in where:
			still = still and mesh.global_transform.is_equal_approx(where[mesh])
		expect(still, "%s stays still" % id)
