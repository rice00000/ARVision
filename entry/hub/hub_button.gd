class_name HubButton
extends Node3D
## One big, solid round button of the workshop (the gear's buttons, the exit-task token): a cream face with a
## dark outline and a dark icon, standing up and facing the child. No words: an icon with its own silhouette
## (low vision; Hindi-speaking children). A press is a touch or an aim-and-pinch; [member pinch_only] leaves
## out the touch (the exit token: a sweep through it must never count).

signal pressed(id: StringName)

const RADIUS := 0.045          # 9 cm across (Megan, Nov 17: bigger for low vision)
const PRESS_RADIUS := 0.06
const CREAM := Color(0.97, 0.93, 0.82)
const INK := Color(0.12, 0.10, 0.09)
const GEM := Color(0.55, 0.36, 0.95)

var id: StringName
var icon := &""
var pinch_only := false
var open := false
var target: Target
var _face: Node3D
var _count: Label3D


## A button [param button_id] showing [param icon_kind] (&"home", &"finish", &"stones", &"exit").
static func make(button_id: StringName, icon_kind: StringName, radius := RADIUS) -> HubButton:
	var button := HubButton.new()
	button.id = button_id
	button.icon = icon_kind
	button.name = String(button_id)
	button._face = Node3D.new()
	button.add_child(button._face)
	var disc := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = 0.012
	cylinder.radial_segments = 48
	disc.mesh = cylinder
	disc.material_override = Impression._lit(CREAM, true)
	disc.rotation.x = PI * 0.5   # its face toward +Z (the child)
	button._face.add_child(disc)
	button._draw_icon(radius)
	if icon_kind != &"stones":
		button.target = Target.sphere(button_id, maxf(PRESS_RADIUS, radius * 1.4))
		button.target.collision_layer = 0
		button.add_child(button.target)
	return button


func _ready() -> void:
	Events.selected.connect(func(_hand: StringName, hit: Target, _o: Vector3, _d: Vector3) -> void: _on_press(hit))
	Events.touched.connect(func(_hand: StringName, hit: Target) -> void:
		if not pinch_only:
			_on_press(hit))


## Lets it be pressed (or not).
func set_open(on: bool) -> void:
	open = on
	if target:
		target.collision_layer = Pointer.TARGET_LAYER if on else 0


## The stones count (the stones badge only).
func set_count(count: int) -> void:
	if _count:
		_count.text = str(count)


## Faces the child at [param eye] (front = +Z).
func face(eye: Vector3) -> void:
	var at := Vector3(eye.x, global_position.y, eye.z)
	if at.distance_to(global_position) > 0.01:
		look_at(at, Vector3.UP, true)


func _on_press(hit: Target) -> void:
	if not open or target == null or hit != target or get_tree().paused:
		return
	var pulse := create_tween()
	pulse.tween_property(_face, "scale", Vector3.ONE * 1.1, 0.1)
	pulse.tween_property(_face, "scale", Vector3.ONE, 0.2)
	pressed.emit(id)


# --- Icons (dark on cream, one silhouette each) ----------------------------------------------------

func _draw_icon(radius: float) -> void:
	var k := radius / RADIUS
	var z := 0.008
	match icon:
		&"home":   # a house: a square and a roof
			_part(_box(Vector3(0.028, 0.022, 0.004)), Vector3(0, -0.008, z) * Vector3(k, k, 1), INK, k)
			var roof := PrismMesh.new()
			roof.size = Vector3(0.042, 0.018, 0.004)
			_part(roof, Vector3(0, 0.012, z) * Vector3(k, k, 1), INK, k)
		&"finish":   # a crescent moon: done for today
			_part(_disc(0.017), Vector3(-0.003, 0, z) * Vector3(k, k, 1), INK, k, true)
			_part(_disc(0.015), Vector3(0.005, 0.004, z + 0.002) * Vector3(k, k, 1), CREAM, k, true)
		&"exit":   # a little cauldron: back to the cauldron
			var pot := CylinderMesh.new()
			pot.top_radius = 0.016
			pot.bottom_radius = 0.012
			pot.height = 0.02
			pot.radial_segments = 24
			_part(pot, Vector3(0, -0.004, z + 0.004) * Vector3(k, k, 1), INK, k)
			_part(_box(Vector3(0.04, 0.005, 0.004)), Vector3(0, 0.008, z + 0.008) * Vector3(k, k, 1), INK, k)
			_part(_box(Vector3(0.004, 0.008, 0.004)), Vector3(-0.009, -0.017, z) * Vector3(k, k, 1), INK, k)
			_part(_box(Vector3(0.004, 0.008, 0.004)), Vector3(0.009, -0.017, z) * Vector3(k, k, 1), INK, k)
		&"stones":   # a gem and the count
			var gem := MeshInstance3D.new()
			gem.mesh = _box(Vector3(0.016, 0.016, 0.006))
			gem.material_override = Impression._lit(GEM, true)
			gem.rotation.z = PI * 0.25
			gem.position = Vector3(-0.011, 0, z) * Vector3(k, k, 1)
			gem.scale = Vector3.ONE * k
			_face.add_child(gem)
			_count = Label3D.new()
			_count.text = "0"
			_count.font_size = 96
			_count.pixel_size = 0.0003 * k
			_count.outline_size = 0
			_count.modulate = INK
			_count.position = Vector3(0.012, 0, z + 0.002) * Vector3(k, k, 1)
			_count.double_sided = false
			_face.add_child(_count)


func _part(mesh: Mesh, at: Vector3, colour: Color, k: float, flat := false) -> void:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = Impression._lit(colour, false)
	part.position = at
	part.scale = Vector3.ONE * k
	if flat:   # a disc facing the child
		part.rotation.x = PI * 0.5
	_face.add_child(part)


func _box(extent: Vector3) -> BoxMesh:
	var box := BoxMesh.new()
	box.size = extent
	return box


func _disc(radius: float) -> CylinderMesh:
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = 0.004
	disc.radial_segments = 32
	return disc
