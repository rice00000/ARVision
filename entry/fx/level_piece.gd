class_name LevelPiece
extends RefCounted
## The level pictures for a game's own row (design chat with Megan, Nov 18, 12:33-1:06 PM;
## claude/DESIGN_LEVEL_PICTURES.md). Once a level is finished, pressing a game opens its own row of levels;
## each level bubble shows a picture of its rule instead of the game's piece.
##
## Every picture sits on a round disc that says which game it is (Find Objects: a dark wood ring round a
## cream disc; Butterflies: a navy disc), with the rule drawn on it in solid, outlined shapes, facing the
## child (+Z). Nothing moves. Levels without a picture keep the game's own piece.
##
## The hub's one hook (WorkshopController._choose_level), after `piece.level = level`:
##     if not LevelPiece.dress(piece, level) and piece.kind == &"shelf":
##         piece.set_rows(_shelf_rows())
## Pictures of all of them: tools/level_pieces_preview.tscn.

const ORANGE := Color(0.91, 0.51, 0.16)    # #E8822A
const BLUE := Color(0.18, 0.44, 0.82)      # #2F6FD0 (orange/blue stays apart for the common colour-blind types)
const YELLOW := Color(0.85, 0.76, 0.23)
const PURPLE := Color(0.48, 0.31, 0.69)
const GREEN := Color(0.23, 0.64, 0.42)
const NAVY := Color(0.10, 0.14, 0.34)
const BRASS := Color(0.79, 0.64, 0.29)
const INK := Impression.INK
const TILE := Impression.TILE
const WOOD := Impression.WOOD

## The sketch's units: its disc was 44 units in radius; ours is 7.5 cm (Megan's 6 cm minimum, grown to
## match the other pieces, which are 12-16 cm across).
const U := 0.075 / 44.0
## The picture's middle: the impression's middle, so it sits in the middle of its bubble.
const MIDDLE := Impression.MIDDLE
const FACE := 0.008     # the front of the disc (z)
const THICK := 0.008    # the shapes' thickness
const EDGE := 0.0024    # the shapes' dark outline (thinner than the pieces' 5 mm: these shapes are small)

## The level ids with a picture, and which game's frame they sit in.
const PICTURES := {
	&"shadow": &"wood", &"size": &"wood", &"clutter": &"wood", &"color": &"wood", &"similar_shadows": &"wood",
	&"one_way": &"navy", &"both_ways": &"navy",
}


static func has_picture(level_id: StringName) -> bool:
	return PICTURES.has(level_id)


## Gives [param piece] the picture of [param level]'s rule in place of its game piece: Megan's own where she drew
## one, else the level's drawing ([member TaskLevel.picture]) in the game's frame. False (and the piece left as
## it was) when the level has neither.
static func dress(piece: Impression, level: TaskLevel) -> bool:
	if piece == null or level == null or not (has_picture(level.id) or level.picture != null):
		return false
	var body: Node3D = piece.get(&"_body")
	for child in body.get_children():
		body.remove_child(child)
		child.free()
	body.add_child(make(level.id) if has_picture(level.id) else drawn(level.picture, piece.kind))
	piece.set_meta(&"level_picture", level.id)
	return true


## The picture for [param level_id] on its own (null when there isn't one), its middle at [constant MIDDLE].
static func make(level_id: StringName) -> Node3D:
	if not has_picture(level_id):
		return null
	var root := Node3D.new()
	root.name = "level_%s" % level_id
	var p := LevelPiece.new()
	p._root = root
	if PICTURES[level_id] == &"wood":
		p._wood_frame()
	else:
		p._navy_frame()
	match level_id:
		&"shadow": p._shadow_match()
		&"size": p._size_match()
		&"clutter": p._clutter_search()
		&"color": p._color_match()
		&"similar_shadows": p._similar_shadows()
		&"one_way": p._butterflies(1)
		&"both_ways": p._butterflies(2)
	return root


## [param picture] (a level's flat drawing, Wanchun's cards) cut round on [param game]'s disc: navy for the
## butterflies, wood for the rest. Its middle at [constant MIDDLE], like Megan's pictures.
static func drawn(picture: Texture2D, game: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = "drawn_%s" % game
	var p := LevelPiece.new()
	p._root = root
	if game == &"butterflies":
		p._navy_frame()
	else:
		p._wood_frame()
	var face := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 72.0 * U   # the frame's inner disc
	var paint := ShaderMaterial.new()
	paint.shader = ROUND
	paint.set_shader_parameter(&"picture", picture)
	quad.material = paint
	face.mesh = quad
	face.position = MIDDLE + Vector3(0, 0, FACE - 0.002)
	root.add_child(face)
	return root


## The card cut to a circle just inside its own square border (0.93 of the card).
const ROUND := preload("res://entry/fx/round_picture.gdshader")

var _root: Node3D


# --- Frames ------------------------------------------------------------------------------------------------

func _wood_frame() -> void:
	_disc(46.0, INK, -0.006)
	_disc(44.0, WOOD, -0.002)
	_disc(36.0, TILE, 0.002)


func _navy_frame() -> void:
	_disc(47.0, INK, -0.006)
	_disc(44.0, NAVY, -0.002)


# --- Find Objects ------------------------------------------------------------------------------------------

func _shadow_match() -> void:
	# An orange triangle and its one matching shadow, side by side.
	_triangle(Vector2(-12, 0), Vector2(28, 28), ORANGE, true)
	_triangle(Vector2(20, 0), Vector2(28, 28), INK, false)


func _size_match() -> void:
	# A big orange square and a small one, bottoms level.
	_rect(Vector2(-15, -1), Vector2(30, 30), ORANGE)
	_rect(Vector2(17, 7), Vector2(14, 14), ORANGE)


func _clutter_search() -> void:
	# A crowd of five small mixed shapes, overlapping a little, none touching the ring.
	_circle(Vector2(-16, -13), 6.0, GREEN, true, 0.0)
	_rect(Vector2(22, -10), Vector2(12, 12), PURPLE, 0.0)
	_rect(Vector2(-22, 0), Vector2(12, 12), BLUE, 0.002)
	_circle(Vector2(-6, 4), 8.0, YELLOW, true, 0.004)
	_triangle(Vector2(14, 4), Vector2(16, 16), ORANGE, true, 0.006)


func _color_match() -> void:
	# An orange square and a blue one, the same size and shape: colour is the only difference.
	_rect(Vector2(-16, 0), Vector2(24, 24), ORANGE)
	_rect(Vector2(16, 0), Vector2(24, 24), BLUE)


func _similar_shadows() -> void:
	# An orange circle on top; below, two shadows: a matching round one and a tall narrow oval.
	_circle(Vector2(0, -15), 11.0, ORANGE, true)
	_circle(Vector2(-15, 15), 11.0, INK, false)
	_oval(Vector2(15, 15), Vector2(6, 13), INK)


# --- Butterflies -------------------------------------------------------------------------------------------

func _butterflies(count: int) -> void:
	# A real-looking net in the middle; one small butterfly beside it (Butterfly Circle) or two, one each side
	# (Both Ways). The count is the difference, which survives blur.
	_net(Vector2(4, 0) if count == 1 else Vector2(-2, 0))
	_butterfly(Vector2(-29, -4), deg_to_rad(15.0))
	if count == 2:
		_butterfly(Vector2(29, -4), deg_to_rad(-15.0))


func _net(at: Vector2) -> void:
	# A brass handle down and to the right, a round brass hoop seen a little from above, and a hanging cream
	# mesh bag with a dark grid.
	var hoop_at := at + Vector2(0, -10)
	var along := Vector2(sin(deg_to_rad(35.0)), cos(deg_to_rad(35.0)))   # down and to the right (sketch y is down)
	var handle := _box(Vector3(6 * U, 26 * U, THICK), BRASS, true)
	handle.position = _at(at + Vector2(9, 10) + along * 13.0, 0.0)
	handle.rotation.z = deg_to_rad(35.0)
	var net := Node3D.new()
	net.position = _at(hoop_at, 0.012)
	net.rotation.x = deg_to_rad(20.0)   # its rim faces up, tipped 20° to the child: an oval hoop
	_root.add_child(net)
	var radius := 15.0 * U
	var depth := 28.0 * U
	var bag := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = radius
	cone.bottom_radius = 2.0 * U
	cone.height = depth
	cone.radial_segments = 32
	bag.mesh = cone
	bag.material_override = _lit(TILE, true)
	bag.position = Vector3(0, -depth * 0.5, 0)
	net.add_child(bag)
	for share: float in [0.3, 0.6]:   # the grid: two rings round the bag
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		var r := lerpf(radius, 2.0 * U, share)
		torus.inner_radius = r
		torus.outer_radius = r + 0.0024
		ring.mesh = torus
		ring.material_override = _lit(INK, false)
		ring.position = Vector3(0, -depth * share, 0)
		net.add_child(ring)
	for x: float in [-0.55, 0.0, 0.55]:   # ...and three lines down its front
		var rim := Vector3(x * radius, 0, sqrt(1.0 - x * x) * radius + 0.0008)
		var tip := Vector3(0, -depth, 0.0008)
		var line := MeshInstance3D.new()
		var stick := BoxMesh.new()
		stick.size = Vector3(0.0024, rim.distance_to(tip), 0.0024)
		line.mesh = stick
		line.material_override = _lit(INK, false)
		net.add_child(line)
		line.position = (rim + tip) * 0.5
		line.basis = Basis(Quaternion(Vector3.UP, (rim - tip).normalized()))
	var hoop := MeshInstance3D.new()
	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = radius - 0.0022
	rim_mesh.outer_radius = radius + 0.0038
	hoop.mesh = rim_mesh
	hoop.material_override = _lit(BRASS, true)
	net.add_child(hoop)


func _butterfly(at: Vector2, turn: float) -> void:
	# The game bubble's orange butterfly, small (about 3.5 cm across the wings).
	var fly := Node3D.new()
	fly.position = _at(at, 0.012)
	fly.rotation.z = turn
	_root.add_child(fly)
	for side: float in [-1.0, 1.0]:
		var upper := _sphere(0.0093, ORANGE, true)
		upper.scale = Vector3(1.0, 1.15, 0.3)
		upper.position = Vector3(side * 0.0102, 0.0052, 0)
		upper.rotation.z = side * -0.35
		fly.add_child(upper)
		var lower := _sphere(0.0068, ORANGE, true)
		lower.scale = Vector3(1.0, 1.1, 0.3)
		lower.position = Vector3(side * 0.0078, -0.0068, 0)
		lower.rotation.z = side * 0.4
		fly.add_child(lower)
	var body := MeshInstance3D.new()
	var stick := CylinderMesh.new()
	stick.top_radius = 0.0024
	stick.bottom_radius = 0.002
	stick.height = 0.024
	body.mesh = stick
	body.material_override = _lit(INK, false)
	body.position = Vector3(0, 0, 0.002)
	fly.add_child(body)


# --- Shapes (sketch units, y down as in the sketch) --------------------------------------------------------

func _at(sketch: Vector2, lift: float) -> Vector3:
	return MIDDLE + Vector3(sketch.x * U, -sketch.y * U, FACE + THICK * 0.5 + lift)


func _disc(radius_units: float, colour: Color, z: float) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius_units * U
	mesh.bottom_radius = radius_units * U
	mesh.height = 0.006
	mesh.radial_segments = 64
	disc.mesh = mesh
	disc.material_override = _lit(colour, false)
	disc.rotation.x = PI * 0.5
	disc.position = MIDDLE + Vector3(0, 0, z)
	_root.add_child(disc)
	return disc


func _rect(centre: Vector2, extent: Vector2, colour: Color, lift := 0.0) -> MeshInstance3D:
	var box := _box(Vector3(extent.x * U, extent.y * U, THICK), colour, true)
	box.position = _at(centre, lift)
	return box


func _triangle(centre: Vector2, extent: Vector2, colour: Color, outlined: bool, lift := 0.0) -> MeshInstance3D:
	var prism := PrismMesh.new()
	prism.size = Vector3(extent.x * U, extent.y * U, THICK)
	var tri := MeshInstance3D.new()
	tri.mesh = prism
	tri.material_override = _lit(colour, outlined)
	tri.position = _at(centre, lift)
	_root.add_child(tri)
	return tri


func _circle(centre: Vector2, radius: float, colour: Color, outlined: bool, lift := 0.0) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * U
	mesh.bottom_radius = radius * U
	mesh.height = THICK
	mesh.radial_segments = 48
	disc.mesh = mesh
	disc.material_override = _lit(colour, outlined)
	disc.rotation.x = PI * 0.5
	disc.position = _at(centre, lift)
	_root.add_child(disc)
	return disc


func _oval(centre: Vector2, radii: Vector2, colour: Color) -> MeshInstance3D:
	var oval := _circle(centre, 1.0, colour, false)
	oval.scale = Vector3(radii.x, 1.0, radii.y)   # the cylinder lies along z after its turn: y here is its depth
	return oval


func _box(extent: Vector3, colour: Color, outlined: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = extent
	instance.mesh = mesh
	instance.material_override = _lit(colour, outlined)
	_root.add_child(instance)
	return instance


func _sphere(radius: float, colour: Color, outlined: bool) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	instance.mesh = mesh
	instance.material_override = _lit(colour, outlined)
	return instance


## A plain lit colour, optionally with a thin dark outline drawn behind it (an inverted hull).
static func _lit(colour: Color, outlined: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.6
	if outlined:
		var outline := StandardMaterial3D.new()
		outline.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		outline.albedo_color = INK
		outline.cull_mode = BaseMaterial3D.CULL_FRONT
		outline.grow = true
		outline.grow_amount = EDGE
		material.next_pass = outline
	return material
