class_name DesktopDriver
extends Node
## Play without a headset: the mouse drives the right hand through SimInput, so
## trials get exactly the hand input a Quest would send.
##
##   Right drag            look around
##   Left press / release  pinch / let go where the cursor points
##   Left drag             sweep the hand across the view (wheel: nearer / farther)
##   WASD / Q / E          move the head; arrows turn and tilt; R resets it
##   H                     raise the left hand (help)
##   M                     left-hand menu pinch (facilitator panel)

const SPEED := 0.5
const TURN := 1.2

## How far in front of the eye the hand sits, metres.
var depth := 0.45
var _start := Vector3.ZERO
var _yaw := 0.0
var _pitch := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start = App.rig.head.global_position


func _process(delta: float) -> void:
	if App.xr != null or get_tree().paused:
		return
	var head := App.rig.head
	if Input.is_physical_key_pressed(KEY_R):
		head.global_position = _start
		_look(0.0, 0.0)
		_place_hand(get_viewport().get_mouse_position())
		return
	var seconds := delta / maxf(Engine.time_scale, 0.05)
	var turn := float(Input.is_physical_key_pressed(KEY_LEFT)) - float(Input.is_physical_key_pressed(KEY_RIGHT))
	var tilt := float(Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_DOWN))
	if turn != 0.0 or tilt != 0.0:
		_look(head.rotation.x + tilt * TURN * seconds, head.rotation.y + turn * TURN * seconds)
	var forward := Vector3.FORWARD.rotated(Vector3.UP, head.global_rotation.y)
	var right := forward.cross(Vector3.UP)
	var step := Vector3.ZERO
	step += forward * (float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
	step += right * (float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)))
	step += Vector3.UP * (float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)))
	if step != Vector3.ZERO:
		head.global_position += step.normalized() * SPEED * seconds
	if step != Vector3.ZERO or turn != 0.0 or tilt != 0.0:
		_place_hand(get_viewport().get_mouse_position())


func _unhandled_input(event: InputEvent) -> void:
	var input := App.sim_input
	if event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_look(_pitch - event.relative.y * 0.004, _yaw - event.relative.x * 0.004)
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
			_raise_left_hand()
		elif event.keycode == KEY_M:
			input.menu()


func _look(pitch: float, yaw: float) -> void:
	_pitch = clampf(pitch, -1.3, 1.3)
	_yaw = yaw
	App.rig.head.rotation = Vector3(_pitch, _yaw, 0.0)


func _raise_left_hand() -> void:
	var input := App.sim_input
	var down := App.rig.left.global_transform
	var eye := App.head().global_transform
	var ahead := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	var up := eye.origin + ahead * 0.3 + ahead.cross(Vector3.UP) * -0.2 + Vector3.UP * 0.25
	input.set_hand(&"left", Transform3D(Basis.looking_at(ahead), up))
	await get_tree().create_timer(App.rig.pointer(&"left").raise_seconds + 0.2).timeout
	input.set_hand(&"left", down)


func _place_hand(cursor: Vector2) -> void:
	var camera := App.rig.head
	var direction := camera.project_ray_normal(cursor)
	var origin := camera.project_ray_origin(cursor) + direction * depth
	App.sim_input.set_hand(&"right", Transform3D(Basis.looking_at(direction), origin))
