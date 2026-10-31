class_name DesktopKeys
extends Node
## The desktop keys that move and turn the head, for every scene after the opening. Without a headset:
## W / S forward and back, A / D left and right, Q / E down and up; the arrow keys look (left / right turn,
## up / down tilt); R puts the head back where the session started. (Right-drag looks too, but it is hard
## on a trackpad: on a Mac, Control + click-drag is a right-drag.) The mouse hand moves with the head, so the
## cursor stays on target.
##
## The opening (Entry) has done exactly this itself since the start, so it was lost the moment the opening
## handed over to the shelf: a click still worked but a Mac could neither move nor turn. This node is a child
## of Main, so it survives every scene change; during the opening it keeps out of Entry's way.

const SPEED := 0.5      # metres a second (a seated child only leans a little)
const TURN := 1.2       # radians a second

var _start := Vector3.ZERO


func _ready() -> void:
	if App.rig != null:
		_start = App.rig.head.global_position


func _process(delta: float) -> void:
	if App.xr != null or App.sim_input == null or App.rig == null:
		return
	if App.main != null and App.main.current_scene == &"intro":
		return   # the opening's own copy of this is running
	var head := App.rig.head
	if Input.is_physical_key_pressed(KEY_R):
		head.global_position = _start
		_look(Vector3.ZERO)
		_hand_to_cursor()
		return
	var turned := _turn(delta)
	var forward := Vector3.FORWARD.rotated(Vector3.UP, head.global_rotation.y)
	var right := forward.cross(Vector3.UP)
	var step := Vector3.ZERO
	step += forward * (float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
	step += right * (float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)))
	step += Vector3.UP * (float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q)))
	if step != Vector3.ZERO:
		head.global_position += step.normalized() * SPEED * delta / maxf(Engine.time_scale, 0.05)
	if step != Vector3.ZERO or turned:
		_hand_to_cursor()


## The arrow keys turn and tilt the head. True while one is down.
func _turn(delta: float) -> bool:
	var turn := float(Input.is_physical_key_pressed(KEY_LEFT)) - float(Input.is_physical_key_pressed(KEY_RIGHT))
	var tilt := float(Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_DOWN))
	if turn == 0.0 and tilt == 0.0:
		return false
	var amount := TURN * delta / maxf(Engine.time_scale, 0.05)
	var head := App.rig.head
	_look(Vector3(clampf(head.rotation.x + tilt * amount, -1.3, 1.3), head.rotation.y + turn * amount, 0.0))
	return true


## Points the head and tells the mouse driver, so its own right-drag carries on from here instead of jumping back.
func _look(angles: Vector3) -> void:
	App.rig.head.rotation = angles
	var driver := _driver()
	if driver != null:
		driver.set("_pitch", angles.x)
		driver.set("_yaw", angles.y)


func _driver() -> DesktopDriver:
	for sibling in get_parent().get_children():
		if sibling is DesktopDriver:
			return sibling as DesktopDriver
	return null


func _hand_to_cursor() -> void:
	var driver := _driver()
	if driver != null:
		driver._place_hand(get_viewport().get_mouse_position())
