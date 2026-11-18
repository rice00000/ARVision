extends "res://trials/prop_match_trial.gd"
## Replace a glass model with its matching object by releasing it inside the cubby.

const GLASS := preload("res://trials/bookshelf/glass.gdshader")
const WIDTH := 0.562
const DEPTH := 0.152
const BOARD := 0.014
const FRONT := DEPTH * 0.5
const BACK := -DEPTH * 0.5 + BOARD
const MOUTH := 0.028
const FLOORS := [0.041, 0.226, 0.428]
const ROWS := [["headphones", "pencil", "mug"], ["notebook", "plant"]]
const SCALES := {"plant": 0.88, "pencil": 1.12}
const ROTATIONS := {
	"headphones": Vector3(1.20, 0, 0),
	"notebook": Vector3(1.24, 0, 0),
	"pencil": Vector3(0, PI * 0.5, 0),
}
const REST_DEPTH := {"headphones": 0.029, "notebook": -0.026, "pencil": 0.038}
const TRAY_TOP := 0.019
const TRAY_EDGE := 0.263
const TRAY_SPOTS := {
	"notebook": Vector3(-0.203, TRAY_TOP, 0.165),
	"mug": Vector3(-0.082, TRAY_TOP, 0.155),
	"headphones": Vector3(0.054, TRAY_TOP, 0.150),
	"plant": Vector3(0.193, TRAY_TOP, 0.158),
	"pencil": Vector3(0, TRAY_TOP, 0.231),
}

var _cubbies: Dictionary[String, AABB] = {}


func _setup(round_condition: TrialCondition) -> void:
	var head := App.head().global_position
	var table := App.reality.work_surface()
	var toward := table.transform.origin - head
	var ahead := Vector3(toward.x, 0.0, toward.z).normalized()
	var height := head.y - App.rig.global_position.y
	var scale_to_reach := clampf(height / 1.22, 0.84, 1.0)
	var distance := clampf(0.347 + 0.29 * (height - 1.02), 0.343, 0.41)
	var below := minf(-toward.y - 0.003, 0.41)
	_start_layout("Bookshelf", Transform3D(Basis.looking_at(ahead).scaled(Vector3.ONE * scale_to_reach),
		head + ahead * distance + Vector3.DOWN * below))
	var mirror_shelf := randf() < 0.5
	var mirror_tray := randf() < 0.5
	round_condition.set_value(&"shelf_mirrored", mirror_shelf)
	round_condition.set_value(&"tray_mirrored", mirror_tray)
	_build_shelf(mirror_shelf, (-toward.y - below) / scale_to_reach)
	for key: String in TRAY_SPOTS:
		var factor: float = SCALES.get(key, 1.0)
		var home: Vector3 = TRAY_SPOTS[key] + Vector3.UP * Props.size_of(key).y * factor * 0.5
		if mirror_tray:
			home.x = -home.x
		var turn := PI * 0.5 if key == "pencil" else 0.0
		_add_thing(key, Transform3D(Basis(Vector3.UP, turn), home), factor)
	instruct("Pinch a thing, carry it to its glass shape, then let go.")


func _build_shelf(mirrored: bool, foot_height: float) -> void:
	var wood := Props.material(Color("#dbc39d"))
	wood.albedo_texture = Props.WOOD
	wood.uv1_triplanar = true
	wood.uv1_scale = Vector3.ONE * 2.0
	var backing := Props.material(Color("#4e4e4a"))
	var top: float = FLOORS.back()
	var side := (WIDTH - BOARD) * 0.5
	Props.box(_board, Vector3(WIDTH, top, BOARD), Vector3(0, top * 0.5, BACK - BOARD * 0.5), backing)
	for x: float in [-side, side]:
		Props.box(_board, Vector3(BOARD, top, DEPTH - BOARD), Vector3(x, top * 0.5, BOARD * 0.5), wood)
		Props.box(_board, Vector3(0.036, foot_height, DEPTH), Vector3(x, -foot_height * 0.5, 0), wood)
	for y: float in FLOORS:
		Props.box(_board, Vector3(WIDTH - BOARD * 2, BOARD, DEPTH - BOARD), Vector3(0, y - BOARD * 0.5, BOARD * 0.5), wood)
	var tray_back := FRONT - BOARD
	var tray_depth := TRAY_EDGE - tray_back
	var tray_z := tray_back + tray_depth * 0.5
	Props.box(_board, Vector3(WIDTH, 0.017, tray_depth), Vector3(0, 0.0085, tray_z), wood)
	var felt := Props.material(Color("#555e56"))
	Props.box(_board, Vector3(WIDTH - 0.014, 0.002, tray_depth - 0.014), Vector3(0, 0.018, tray_z), felt)
	Props.box(_board, Vector3(WIDTH, 0.008, 0.006), Vector3(0, 0.021, TRAY_EDGE - 0.003), wood)
	for x: float in [-1.0, 1.0]:
		Props.box(_board, Vector3(0.006, 0.008, tray_depth), Vector3(x * (WIDTH * 0.5 - 0.003), 0.021, tray_z), wood)

	_cubbies.clear()
	var glass := ShaderMaterial.new()
	glass.shader = GLASS
	for row in ROWS.size():
		var keys: Array = ROWS[row].duplicate()
		if mirrored:
			keys.reverse()
		var pitch := (WIDTH - BOARD) / keys.size()
		var floor_y: float = FLOORS[row]
		var clear_height: float = FLOORS[row + 1] - BOARD - floor_y
		for column in keys.size():
			var left := -side + pitch * column
			if column > 0:
				Props.box(_board, Vector3(BOARD, clear_height, DEPTH - BOARD),
					Vector3(left, floor_y + clear_height * 0.5, BOARD * 0.5), wood)
			var key: String = keys[column]
			_cubbies[key] = AABB(Vector3(left + BOARD * 0.5, floor_y - 0.005, BACK),
				Vector3(pitch - BOARD, clear_height + 0.005, FRONT - BACK + MOUTH))
			_add_glass_model(key, left + pitch * 0.5, floor_y, glass)


func _add_glass_model(key: String, x: float, floor_y: float, glass: ShaderMaterial) -> void:
	var factor: float = SCALES.get(key, 1.0)
	var size := Props.size_of(key) * factor
	var turn := Basis.from_euler(ROTATIONS.get(key, Vector3.ZERO))
	var bounds := Transform3D(turn, Vector3.ZERO) * AABB(-size * 0.5, size)
	var rest := Transform3D(turn, Vector3(x, floor_y - bounds.position.y, REST_DEPTH.get(key, 0.003)))
	var ghost := Node3D.new()
	ghost.name = "Glass_" + key
	ghost.transform = rest
	var model := Props.centred_model(key, factor)
	ghost.add_child(model)
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		part.material_override = glass
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_board.add_child(ghost)
	_guides[key] = ghost
	_spots[key] = rest


func _slot_at(point: Vector3) -> String:
	for key: String in _cubbies:
		if _guides[key].visible and _cubbies[key].has_point(point):
			return key
	return ""


func _hint(_level: int) -> void:
	say("Look at the whole glass shape. You can turn what you're holding to compare it.")


func focus_point() -> Vector3:
	return _board.to_global(Vector3(0, 0.146, 0.066))


func layout() -> Dictionary:
	var state := _match_layout("glass_", false)
	state.focus = focus_point()
	return state
