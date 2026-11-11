class_name DesktopDriver
extends Node
## Play without a headset: the mouse drives the right hand through SimInput, so
## trials get exactly the hand input a Quest would send.
##
##   Right drag            look around
##   Left press / release  pinch / let go where the cursor points
##   Left drag             sweep the hand across the view (wheel: nearer / farther)
##   H                     raise the left hand (help)
##   M                     left-hand menu pinch (facilitator panel)

## How far in front of the eye the hand sits, metres.
var depth := 0.45
## How far a press looks for a thing to reach to, metres.
const REACH := 1.2

var _rest_depth := -1.0   # the depth to go back to when a reach-press is let go
var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	var input := App.sim_input
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_yaw -= event.relative.x * 0.004
			_pitch = clampf(_pitch - event.relative.y * 0.004, -1.3, 1.3)
			App.rig.head.rotation = Vector3(_pitch, _yaw, 0.0)
		_place_hand(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_reach_to_target(event.position)
			elif _rest_depth > 0.0:
				depth = _rest_depth   # let go: back to the usual depth
				_rest_depth = -1.0
			_place_hand(event.position)
			input.press(&"right", &"trigger_click", event.pressed)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			depth = clampf(depth + (0.03 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.03), 0.2, 0.9)
			_place_hand(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			_raise_left_hand()
		elif event.keycode == KEY_M:
			input.menu()


func _raise_left_hand() -> void:
	var input := App.sim_input
	var down := App.rig.left.global_transform
	var eye := App.head().global_transform
	var ahead := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	var up := eye.origin + ahead * 0.3 + ahead.cross(Vector3.UP) * -0.2 + Vector3.UP * 0.25
	input.set_hand(&"left", Transform3D(Basis.looking_at(ahead), up))
	await get_tree().create_timer(App.rig.pointer(&"left").raise_seconds + 0.2).timeout
	input.set_hand(&"left", down)


## Megan, Nov 10: on a laptop a pinch at a shape on the bench missed, because the hand sat at [member depth]
## (45 cm) and the shapes are further. A press now first puts the hand at the distance of the thing the cursor
## points at (a Target within [constant REACH]), so a click on a shape takes it; the hand then stays at that
## distance while dragging, and goes back to [member depth] when let go.
func _reach_to_target(cursor: Vector2) -> void:
	var camera := App.rig.head
	var from := camera.project_ray_origin(cursor)
	var direction := camera.project_ray_normal(cursor)
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * REACH)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.collider is Target:
		_rest_depth = depth
		depth = clampf(from.distance_to(hit.position) - 0.015, 0.2, REACH)   # just in front: its own ray still hits it


func _place_hand(cursor: Vector2) -> void:
	var camera := App.rig.head
	var direction := camera.project_ray_normal(cursor)
	var origin := camera.project_ray_origin(cursor) + direction * depth
	App.sim_input.set_hand(&"right", Transform3D(Basis.looking_at(direction), origin))
