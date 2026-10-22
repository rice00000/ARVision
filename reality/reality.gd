class_name Reality
extends Node3D
## The real world as the app sees it. Trials use only this API, so they run
## unchanged on a Quest ([PassthroughReality]) and in a simulated room
## ([SimReality]).
##
## Reality gives three things: flat surfaces to put stimuli on, how the real
## world is shown (a [View]: passthrough filter, dimming, focus) and camera
## frames for computer vision.

## Without a table in reach, tabletop stimuli go on a virtual patch this far in
## front of the eyes and below them, metres.
const REACH := 0.45
const BELOW_EYE := 0.4
## A table farther than this from the eyes is out of reach, metres.
const TABLE_REACH := 1.2

## How the real world is shown now. Change it with [method apply_view].
var view := View.new()

var _surfaces: Array[Surface] = []
var _focus := Vector3.ZERO


## &"passthrough" or &"sim", for the log.
func kind() -> String:
	return ""


## Known flat surfaces of [param surface_kind] (&"table", &"floor", &"wall"...),
## nearest the eyes first.
func surfaces(surface_kind: StringName) -> Array[Surface]:
	var eye := App.head().global_position
	var found: Array[Surface] = []
	found.assign(_surfaces.filter(func(surface: Surface) -> bool: return surface.kind == surface_kind))
	found.sort_custom(func(a: Surface, b: Surface) -> bool:
		return a.transform.origin.distance_to(eye) < b.transform.origin.distance_to(eye))
	return found


## Where tabletop stimuli go: the nearest table in reach, else a virtual patch
## in front of the child (no room scan, or no table in it).
func work_surface() -> Surface:
	var eye := App.head().global_transform
	for table in surfaces(&"table"):
		if table.transform.origin.distance_to(eye.origin) < TABLE_REACH:
			return table
	var forward := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	var centre := eye.origin + forward * REACH + Vector3.DOWN * BELOW_EYE
	return Surface.new(&"table", Transform3D(Basis.looking_at(forward), centre), Vector2(0.8, 0.5))


func add_surface(surface: Surface) -> void:
	_surfaces.append(surface)


## Shows the real world through [param new_view] from now on.
func apply_view(new_view: View) -> void:
	view = new_view
	_apply()
	Events.view_changed.emit(view.to_log())


## Dimming spares the region around [param point] (radius from the view).
func focus_on(point: Vector3) -> void:
	_focus = point
	_apply()


## The latest camera image of the real world, for CV. Null when there is none.
func camera_frame() -> CameraFrame:
	return null


## Push [member view] and the focus to the platform.
func _apply() -> void:
	pass
