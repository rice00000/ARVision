class_name FitsButton
extends Node3D
## Turn to fit's "It fits!" button (Megan, Nov 18, beat 4): a big round button with a check mark and no words,
## standing on the table in easy reach to the right of the real cup, facing the child. Cream face, a **brass rim
## and a green check** (Megan: so it never looks like the exit token, also a cream disc). A press is a touch or
## an aim-and-pinch; it has its own sound. Only shown (and pressable) in blind rounds.

signal pressed

const RADIUS := 0.045          # 9 cm across, like the hub's buttons
const PRESS_RADIUS := 0.065
const CREAM := Color(0.97, 0.93, 0.82)
const CHECK := Color(0.16, 0.55, 0.24)   # a deep green: dark enough on cream for low vision
const RIM := Color(0.78, 0.60, 0.26)     # brass

var open := false
var target: Target
var _face: Node3D


static func make(radius := RADIUS) -> FitsButton:
	var button := FitsButton.new()
	button.name = "FitsButton"
	button._face = Node3D.new()
	button.add_child(button._face)
	# A brass rim behind the cream face (and a thin dark ring under it: it reads on a light table and a dark one).
	button._face.add_child(_disc(radius * 1.22, 0.008, Color(0.20, 0.15, 0.10), -0.006))
	button._face.add_child(_disc(radius * 1.16, 0.010, RIM, -0.004))
	button._face.add_child(_disc(radius, 0.012, CREAM, 0.0))
	# The check mark: a short stroke and a long one.
	var k := radius / RADIUS
	button._face.add_child(_stroke(Vector3(0.020, 0.0075, 0.004) * Vector3(k, k, 1), Vector3(-0.012, -0.004, 0.009) * Vector3(k, k, 1), deg_to_rad(-45.0)))
	button._face.add_child(_stroke(Vector3(0.040, 0.0075, 0.004) * Vector3(k, k, 1), Vector3(0.008, 0.004, 0.009) * Vector3(k, k, 1), deg_to_rad(52.0)))
	button.target = Target.sphere(&"fit_fits", maxf(PRESS_RADIUS, radius * 1.4))
	button.target.collision_layer = 0
	button.add_child(button.target)
	return button


func _ready() -> void:
	Events.selected.connect(func(_hand: StringName, hit: Target, _o: Vector3, _d: Vector3) -> void: _on_press(hit))
	Events.touched.connect(func(_hand: StringName, hit: Target) -> void: _on_press(hit))


## Shows it and lets it be pressed (or hides it).
func set_open(on: bool) -> void:
	open = on
	visible = on
	if target:
		target.collision_layer = Pointer.TARGET_LAYER if on else 0


## Faces the child at [param eye] (front = +Z), leaning back a little so it reads from above.
func face(eye: Vector3) -> void:
	var at := Vector3(eye.x, global_position.y, eye.z)
	if at.distance_to(global_position) > 0.01:
		look_at(at, Vector3.UP, true)
	rotate_object_local(Vector3.RIGHT, deg_to_rad(-25.0))


## A press (tests and the desktop may call it).
func press() -> void:
	if not open or get_tree().paused:
		return
	var pulse := create_tween()
	pulse.tween_property(_face, "scale", Vector3.ONE * 1.1, 0.1)
	pulse.tween_property(_face, "scale", Vector3.ONE, 0.2)
	pressed.emit()


func _on_press(hit: Target) -> void:
	if hit == target:
		press()


static func _disc(radius: float, height: float, colour: Color, z: float) -> MeshInstance3D:
	var disc := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = 48
	disc.mesh = cylinder
	disc.material_override = _lit(colour)
	disc.rotation.x = PI * 0.5   # its face toward +Z (the child)
	disc.position.z = z
	return disc


static func _stroke(size: Vector3, at: Vector3, angle: float) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	part.mesh = box
	part.material_override = _lit(CHECK)
	part.position = at
	part.rotation.z = angle
	return part


static func _lit(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.8
	return material
