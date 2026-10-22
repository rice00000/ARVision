class_name SimReality
extends Reality
## A virtual stand-in for the real room: desktop preview and tests run on it.
##
## The room scene is plain scenery. Its [SimSurface] markers become surfaces,
## its [RealObject]s are what the simulated detector can see, and its colliders
## belong on the "reality" physics layer. Every mesh gets the reality filter as
## an overlay, which grades the room the way the passthrough filter grades the
## camera image, so views look roughly as they will on a Quest.

const FILTER := preload("res://reality/reality_filter.tres")

var room: PackedScene


func kind() -> String:
	return "sim"


func _ready() -> void:
	var scene := room.instantiate()
	add_child(scene)
	for mesh: GeometryInstance3D in scene.find_children("*", "GeometryInstance3D", true, false):
		mesh.material_overlay = FILTER
	for marker: SimSurface in get_tree().get_nodes_in_group(SimSurface.GROUP):
		add_surface(Surface.new(marker.kind, marker.global_transform, marker.size, marker))
	_apply()


## Every real object in the room.
func objects() -> Array[RealObject]:
	var found: Array[RealObject] = []
	found.assign(get_tree().get_nodes_in_group(RealObject.GROUP))
	return found


## What the eyes see, when the app renders (not headless).
func camera_frame() -> CameraFrame:
	if DisplayServer.get_name() == "headless":
		return null
	return CameraFrame.new(get_viewport().get_texture().get_image(), App.head().global_transform, App.head().fov)


func _apply() -> void:
	RenderingServer.global_shader_parameter_set(&"reality_filter",
		Vector4(view.brightness / 100.0, view.contrast, view.saturation, float(view.black_and_white)))
	RenderingServer.global_shader_parameter_set(&"reality_edges", view.edges)
	RenderingServer.global_shader_parameter_set(&"reality_focus",
		Vector4(_focus.x, _focus.y, _focus.z, view.focus_radius))
	RenderingServer.global_shader_parameter_set(&"reality_dim", view.dim)
