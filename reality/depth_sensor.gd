class_name DepthSensor
extends Node3D
## The room as live points from the Quest 3's environment depth, which needs no
## room scan (Quest refuses that to unregistered apps: ERROR_PACKAGE_UNTRUSTED).
## A child of the Rig (XROrigin3D). Twice a second a shader turns an N x N grid
## of left-eye depth pixels into play-space points (the plugin's own CPU readback
## is broken on Vulkan, #517); [member grid] is the latest look.

signal refreshed

const N := 48
const INTERVAL := 0.5
## Every this many looks, the cost of reading the grid back is logged.
const LOG_EVERY := 20
const SHADER := """
shader_type canvas_item;
render_mode unshaded, blend_disabled;
global uniform bool META_ENVIRONMENT_DEPTH_AVAILABLE;
global uniform highp sampler2DArray META_ENVIRONMENT_DEPTH_TEXTURE : filter_nearest, repeat_disable, hint_default_black;
global uniform highp mat4 META_ENVIRONMENT_DEPTH_INV_PROJECTION_VIEW_LEFT;
void fragment() {
	highp float d = texture(META_ENVIRONMENT_DEPTH_TEXTURE, vec3(UV, 0.0)).r;
	highp vec4 p = META_ENVIRONMENT_DEPTH_INV_PROJECTION_VIEW_LEFT * vec4(UV * 2.0 - 1.0, d * 2.0 - 1.0, 1.0);
	COLOR = vec4(p.xyz / p.w, (META_ENVIRONMENT_DEPTH_AVAILABLE && d > 0.0 && d < 1.0) ? 1.0 : 0.0);
}
"""

## The latest look, or null before the first.
var grid: DepthGrid

var _view := SubViewport.new()
var _looks := 0


## Starts the depth and looks every [constant INTERVAL] seconds from now on.
func start() -> void:
	if not OpenXRMetaEnvironmentDepthExtension.is_environment_depth_supported():
		PassthroughReality.note(&"depth", {supported = false})
		return
	OpenXRMetaEnvironmentDepthExtension.start_environment_depth()
	OpenXRMetaEnvironmentDepthExtension.set_hand_removal_enabled(true)
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = SHADER # after start: the depth globals exist only then
	_view.size = Vector2i(N, N)
	_view.use_hdr_2d = true
	_view.transparent_bg = true
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var rect := ColorRect.new()
	rect.size = Vector2(N, N)
	rect.material = material
	_view.add_child(rect)
	add_child(_view)
	var timer := Timer.new()
	timer.wait_time = INTERVAL
	timer.timeout.connect(_look)
	add_child(timer)
	timer.start()


## The first real surface along a ray ([method DepthGrid.hit]), or empty.
func hit(from: Vector3, direction: Vector3) -> Dictionary:
	return grid.hit(from, direction) if grid else {}


func _look() -> void:
	_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var began := Time.get_ticks_usec()
	var image := _view.get_texture().get_image()
	var read_ms := (Time.get_ticks_usec() - began) / 1000.0
	var to_world := (get_parent() as Node3D).global_transform
	var points := PackedVector3Array()
	var valid := PackedByteArray()
	points.resize(N * N)
	valid.resize(N * N)
	for y in N:
		for x in N:
			var pixel := image.get_pixel(x, y)
			points[y * N + x] = to_world * Vector3(pixel.r, pixel.g, pixel.b)
			valid[y * N + x] = 1 if pixel.a > 0.5 else 0
	grid = DepthGrid.new(N, points, valid)
	if _looks % LOG_EVERY == 0:
		PassthroughReality.note(&"depth", {points = grid.count(), read_ms = read_ms,
			ahead = hit(App.head().global_position, -App.head().global_basis.z)})
	_looks += 1
	refreshed.emit()
