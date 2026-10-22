class_name PassthroughReality
extends Reality
## Reality on a Quest: the passthrough image behind the app, surfaces from the
## Meta room scan, Meta's passthrough filters for the View, and passthrough
## camera frames for CV. Needs a headset; desktop and tests use SimReality.

const SceneAnchor := preload("res://reality/scene_anchor.tscn")
const DimShader := preload("res://reality/dim_sphere.gdshader")

var _passthrough: OpenXRFbPassthroughExtension
var _black_white := Gradient.new()
var _dim := ShaderMaterial.new()
var _camera: QuestCamera


func kind() -> String:
	return "passthrough"


func _ready() -> void:
	get_viewport().transparent_bg = true
	var environment := get_world_3d().environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0, 0, 0, 0)
	App.xr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
	_passthrough = Engine.get_singleton("OpenXRFbPassthroughExtension")
	_black_white.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	_black_white.offsets = PackedFloat32Array([0.0, 0.5])
	_black_white.colors = PackedColorArray([Color.BLACK, Color.WHITE])
	_dim.shader = DimShader
	var sphere := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 30.0
	mesh.height = 60.0
	mesh.flip_faces = true
	sphere.mesh = mesh
	sphere.material_override = _dim
	sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	App.rig.head.add_child(sphere)
	var scan: OpenXRFbSceneManager = OpenXRFbSceneManager.new()
	scan.default_scene = SceneAnchor
	scan.scene_setup_method = &"setup_scene"
	scan.auto_create = true
	scan.openxr_fb_scene_data_missing.connect(scan.request_scene_capture)
	App.rig.add_child(scan)
	_camera = QuestCamera.new()
	add_child(_camera)
	_apply()


func camera_frame() -> CameraFrame:
	return _camera.frame()


func _apply() -> void:
	if view.black_and_white:
		_passthrough.set_color_map(_black_white)
	elif view.is_graded():
		_passthrough.set_brightness_contrast_saturation(view.brightness, view.contrast, view.saturation)
	else:
		_passthrough.set_passthrough_filter(OpenXRFbPassthroughExtension.PASSTHROUGH_FILTER_DISABLED)
	_passthrough.set_edge_color(view.edges)
	_dim.set_shader_parameter(&"dim", view.dim)
	_dim.set_shader_parameter(&"focus", Vector4(_focus.x, _focus.y, _focus.z, view.focus_radius))
