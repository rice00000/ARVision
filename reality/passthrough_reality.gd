class_name PassthroughReality
extends Reality
## Reality on a Quest: the passthrough image behind the app, surfaces from the
## Meta room scan, Meta's passthrough filters for the View, and passthrough
## camera frames for CV. Needs a headset; desktop and tests use SimReality.
##
## The room scan: when the headset has none, Quest's Space Setup is opened once
## per run. If the room still cannot be read after it, play goes on with the
## virtual table patch instead of asking again. Each step is logged
## ("room_..." events, also printed to logcat).
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
var _scan_asked := false


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
	_scan.openxr_fb_scene_data_missing.connect(_on_room_missing)
	_scan.openxr_fb_scene_capture_completed.connect(func(success: bool) -> void:
		note(&"room_scan_done", {success = success}))
	App.rig.add_child(_scan)
	_camera = QuestCamera.new()
	add_child(_camera)
	_apply()


## Logs a step of reading the room, and prints it for adb logcat.
static func note(what: StringName, data: Dictionary = {}) -> void:
	print("ARVision %s %s" % [what, data])
	Events.report(what, data)


func _on_room_missing() -> void:
	if _scan_asked:
		note(&"room_missing", {after_scan = true})
		return
	_scan_asked = true
	note(&"room_missing", {after_scan = false})
	_scan.request_scene_capture()


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
