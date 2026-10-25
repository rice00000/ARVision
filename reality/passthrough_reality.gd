class_name PassthroughReality
extends Reality
## Reality on a Quest: the passthrough image behind the app, surfaces from the
## Meta room scan or else the live depth ([DepthSensor]), Meta's passthrough
## filters for the View, and passthrough camera frames for CV. Needs a headset;
## desktop and tests use SimReality.
##
## The room scan is read when the headset has one and Quest lets this app read
## it (an unregistered build may not: ERROR_PACKAGE_UNTRUSTED). The app never
## opens Space Setup itself. Each step is logged ("room_..." and "depth..."
## events, also printed to logcat).
##
## Meta's extensions are engine singletons: call them by name
## (OpenXRFbPassthroughExtension.set_...). A variable typed with that name
## breaks debug builds ("Internal script error! Opcode: 28").

const SceneAnchor := preload("res://reality/scene_anchor.tscn")
const DimShader := preload("res://reality/dim_sphere.gdshader")

var _black_white := Gradient.new()
var _dim := ShaderMaterial.new()
var _sphere := MeshInstance3D.new()
var _camera: QuestCamera
var _scan := OpenXRFbSceneManager.new()
var _hands_flat := 0.0
var _hands_asked := false
var _found_table := false
var _depth := DepthSensor.new()


func kind() -> String:
	return "passthrough"


func _ready() -> void:
	get_viewport().transparent_bg = true
	var environment := get_world_3d().environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	App.xr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
	_black_white.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	_black_white.offsets = PackedFloat32Array([0.0, 0.5])
	_black_white.colors = PackedColorArray([Color.BLACK, Color.WHITE])
	_dim.shader = DimShader
	var mesh := SphereMesh.new()
	mesh.radius = 30.0
	mesh.height = 60.0
	mesh.flip_faces = true
	_sphere.mesh = mesh
	_sphere.material_override = _dim
	_sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	App.rig.head.add_child(_sphere)
	_scan.default_scene = SceneAnchor
	_scan.scene_setup_method = &"setup_scene"
	_scan.auto_create = true
	_scan.openxr_fb_scene_data_missing.connect(note.bind(&"room_missing", {}))
	App.rig.add_child(_scan)
	App.rig.add_child(_depth)
	_camera = QuestCamera.new()
	add_child(_camera)
	_apply()
	get_tree().create_timer(ROOM_READY_AFTER).timeout.connect(_room_ready)


## Seconds after start at which the room is summed up ("room_ready").
const ROOM_READY_AFTER := 4.0
## When neither the scan nor the depth gives a table, the child is asked to put
## both hands flat on it; held there this long, they mark it. Only after asking,
## and when the depth sees the place, only where it sees a surface at hand
## height (around the hands, which the depth leaves out): hands held level in
## the air are no table.
const HAND_TABLE_SECONDS := 1.0
const HAND_TABLE_SIZE := Vector2(1.0, 0.6)
## Seconds after "room_ready" without a table before the child is asked for the hands.
const ASK_HANDS_AFTER := 6.0
## The depth looks this far around the hands for the table top, metres.
const HAND_TABLE_RADIUS := 0.35
## Points on the table top around the hands it must see, when it sees the place at all.
const HAND_TABLE_POINTS := 12


## Logs a step of reading the room, and prints it as one JSON line (adb logcat, tools/xrsim.py).
static func note(what: StringName, data: Dictionary = {}) -> void:
	print("ARVision ", JSON.stringify(Log.plain({what = what, data = data})))
	Events.report(what, data)


func _physics_process(delta: float) -> void:
	if not _hands_asked or _found_table or work_surface() in _surfaces:
		return
	var eye := App.head().global_position
	var tips: Array[Vector3] = []
	for side: StringName in [&"left", &"right"]:
		var pointer := App.rig.pointer(side)
		var tip := pointer.tip()
		var ahead := Vector2(tip.x - eye.x, tip.z - eye.z).length()
		if App.rig.hand(side).get_has_tracking_data() and pointer.resting() and ahead > 0.25 				and eye.y - tip.y > 0.25 and eye.y - tip.y < 0.8:
			tips.append(tip)
	var flat := tips.size() == 2 and absf(tips[0].y - tips[1].y) < 0.06
	_hands_flat = _hands_flat + delta if flat else 0.0
	if _hands_flat < HAND_TABLE_SECONDS:
		return
	_hands_flat = 0.0
	var top := (tips[0] + tips[1]) * 0.5 + Vector3.DOWN * 0.015
	if _depth.grid:
		var seen := _depth.grid.around(top, HAND_TABLE_RADIUS)
		if seen.y >= HAND_TABLE_POINTS and seen.x < HAND_TABLE_POINTS:
			note(&"room_hands_in_air", {at = top, on_level = seen.x, around = seen.y})
			return
	var ahead := -App.head().global_basis.z
	ahead = Vector3(ahead.x, 0.0, ahead.z).normalized()
	_set_table(top + ahead * 0.15, HAND_TABLE_SIZE, &"room_hand_table")


## The real thing along a ray: the room scan's colliders first, else the live depth.
func hit(from: Vector3, direction: Vector3) -> Dictionary:
	var found := super(from, direction)
	return found if found else _depth.hit(from, direction)


func _look_for_table() -> void:
	if _found_table:
		_depth.refreshed.disconnect(_look_for_table)
		return
	var forward := -App.head().global_basis.z
	var table := _depth.grid.table(App.head().global_position, Vector3(forward.x, 0.0, forward.z).normalized())
	note(&"depth_table", {support = table.support})
	if table.has("centre"):
		_depth.refreshed.disconnect(_look_for_table)
		_set_table(table.centre, table.size, &"room_depth_table")


## A table found without the room scan (hands or depth); toys go on it from the
## next round. It hangs on the depth sensor, so it stays put when the headset recentres.
func _set_table(at: Vector3, size: Vector2, how: StringName) -> void:
	_found_table = true
	var forward := -App.head().global_basis.z
	forward = Vector3(forward.x, 0.0, forward.z).normalized()
	add_surface(Surface.new(&"table", Transform3D(Basis.looking_at(forward), at), size, _depth))
	Events.say("Got it. That's your table.")
	note(how, {centre = at, size = size})


func _room_ready() -> void:
	var surface := work_surface()
	_depth.start()
	if not surface in _surfaces:
		# No scanned table: find it in the depth, and ask for the hands if that fails.
		_depth.refreshed.connect(_look_for_table)
		get_tree().create_timer(ASK_HANDS_AFTER).timeout.connect(func() -> void:
			if not _found_table:
				_hands_asked = true
				Events.say("Put both hands flat on the table for a moment."))
	note(&"room_ready", {head = App.head().global_position, surfaces = _surfaces.size(),
		camera = {feeds = CameraServer.get_feed_count(), frame = camera_frame() != null},
		work_surface = {kind = surface.kind, scanned = surface in _surfaces, centre = surface.transform.origin,
			normal = surface.transform.basis.y, size = surface.size}})


func camera_frame() -> CameraFrame:
	return _camera.frame()


func _apply() -> void:
	if view.black_and_white:
		OpenXRFbPassthroughExtension.set_color_map(_black_white)
	elif view.is_graded():
		OpenXRFbPassthroughExtension.set_brightness_contrast_saturation(view.brightness, view.contrast, view.saturation)
	else:
		OpenXRFbPassthroughExtension.set_passthrough_filter(OpenXRFbPassthroughExtension.PASSTHROUGH_FILTER_DISABLED)
	OpenXRFbPassthroughExtension.set_edge_color(view.edges)
	_sphere.visible = view.dim > 0.0 # a full-view transparent pass costs frame time on a Quest
	_dim.set_shader_parameter(&"dim", view.dim)
	_dim.set_shader_parameter(&"focus", Vector4(_focus.x, _focus.y, _focus.z, view.focus_radius))
