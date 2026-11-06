class_name EntryButton
extends Node3D
## An entry panel button. Pointer owns aiming and pinch confirmation.

const DEPTH := 0.03

var id: StringName
## The plate's width and height, metres.
var plate := Vector2(0.22, 0.06)
## Extra reach around the plate, metres, for rays.
var margin := 0.02
## What a ray hits, and what presses are reported as (a child of this node).
var target: UITarget

var _face: MeshInstance3D
var _words: Label3D
var _material: StandardMaterial3D
var _colour: Color
var _hover := 0.0
var _hot := false
var _push := 0.0


## Builds the plate, its words and its hit box. Call once, after [method Node.add_child].
func setup(text: String, button_id: StringName, colour: Color, size: Vector2, reach: float) -> void:
	id = button_id
	plate = size
	margin = reach
	_colour = colour
	_material = StandardMaterial3D.new()
	_material.albedo_color = colour
	_material.emission_enabled = true
	_material.emission = Color.BLACK
	var box := BoxMesh.new()
	box.size = Vector3(plate.x, plate.y, 0.01)
	box.material = _material
	_face = MeshInstance3D.new()
	_face.mesh = box
	add_child(_face)
	_words = Label3D.new()
	_words.text = text
	_words.font_size = 26 if plate.x > 0.15 else 24
	_words.pixel_size = 0.0006
	_words.position = Vector3(0, 0, 0.007)
	_face.add_child(_words)
	target = UITarget.new()
	target.id = id
	target.name = String(id)
	target.show_ray = not String(id).begins_with("entry_debug_")
	var shape := CollisionShape3D.new()
	var hit := BoxShape3D.new()
	hit.size = Vector3(plate.x + margin * 2.0, plate.y + margin * 2.0, DEPTH)
	shape.shape = hit
	target.add_child(shape)
	target.hover_changed.connect(set_hot)
	add_child(target)


## Changes the words on the plate.
func set_text(text: String) -> void:
	_words.text = text


func text() -> String:
	return _words.text


## A hand ray is on the button now.
func set_hot(on: bool) -> void:
	_hot = on


## Changes the plate's colour.
func set_colour(colour: Color) -> void:
	_colour = colour


## The press: the plate dips back a little.
func flash() -> void:
	_push = 0.012


func _process(delta: float) -> void:
	_hover = move_toward(_hover, 1.0 if _hot else 0.0, delta * 10.0)
	_push = move_toward(_push, 0.0, delta * 0.12)
	_material.albedo_color = _colour.lerp(Color.WHITE, 0.3 * _hover)
	_material.emission = _colour * (0.45 * _hover)
	_face.scale = Vector3.ONE * (1.0 + 0.08 * _hover)
	_face.position.z = -_push
