class_name Reality
extends Node3D
## The real world as the app sees it. Trials use only this API, so they run
## unchanged on a Quest ([PassthroughReality]) and in a simulated room
## ([SimReality]).
##
## Reality gives three things: flat surfaces to put stimuli on, how the real
## world is shown (a [View]: passthrough filter, dimming, focus) and camera
## frames for computer vision.

## Physics layer of real things: room-scan colliders, simulated furniture and objects.
const REALITY_LAYER := 2
## Without a table in reach, tabletop stimuli go on a virtual patch this far in
## front of the eyes and below them, metres.
const REACH := 0.4
const BELOW_EYE := 0.4
## A table farther than this from the eyes is out of reach, metres.
const TABLE_REACH := 1.2
## [method hit] looks this far along a ray, metres.
const HIT_RANGE := 6.0

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


## No real thing inside a ball of [param radius] resting on [param point]: room
## for something virtual of that size, e.g. a toy on the table between real objects.
func is_free(point: Vector3, radius: float) -> bool:
	var ball := SphereShape3D.new()
	ball.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * (radius + 0.005))
	query.collision_mask = REALITY_LAYER
	return get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


## The first real thing along the ray from [param from]: {position, normal}, the
## normal facing [param from]. Empty when nothing real is known there.
func hit(from: Vector3, direction: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * HIT_RANGE, REALITY_LAYER)
	var found := get_world_3d().direct_space_state.intersect_ray(query)
	return {position = found.position, normal = found.normal} if found else {}


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
