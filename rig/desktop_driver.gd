class_name DesktopDriver
extends Node
## Play without a headset: the mouse drives the right hand through SimInput, so
## trials get exactly the controller input a Quest would send.
##
##   Right drag            look around
##   Left press / release  pull / let go of the trigger where the cursor points
##   Left drag             sweep the hand across the view (wheel: nearer / farther)
##   H                     help (B / Y)
##   M                     facilitator panel (left Menu)

## How far in front of the eye the hand sits, metres.
var depth := 0.45
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
			_place_hand(event.position)
			input.press(&"right", &"trigger_click", event.pressed)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			depth = clampf(depth + (0.03 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -0.03), 0.2, 0.9)
			_place_hand(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_H:
			input.click(&"right", &"by_button")
		elif event.keycode == KEY_M:
			input.click(&"left", &"menu_button")


func _place_hand(cursor: Vector2) -> void:
	var camera := App.rig.head
	var direction := camera.project_ray_normal(cursor)
	var origin := camera.project_ray_origin(cursor) + direction * depth
	App.sim_input.set_hand(&"right", Transform3D(Basis.looking_at(direction), origin))
