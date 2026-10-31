class_name EntryButton
extends Node3D
## A floating button for the entry's setup and debug panels (TESTING). Forgiving to press:
## poke it (a fingertip enters its box, see [method reaches]), or point at it and pinch.
## Its hit box is the whole plate plus [member margin], and it lights up and nudges
## back when a ray or a fingertip is on it, so it is clear what a press will hit.
## The entry does the poking and routes the press; this node is the look and the box.

## How far in front of the plate a fingertip already counts, and how far behind
## (fingers go through a button in the air), metres.
const FRONT := 0.02
const BACK := 0.07

var id: StringName
## The plate's width and height, metres.
var plate := Vector2(0.22, 0.06)
## Extra reach around the plate, metres, for pokes and rays alike.
var margin := 0.02
## What a ray hits, and what presses are reported as (a child of this node).
var target: Target
## Game-clock seconds when it appeared: a finger already there then does not press it.
var born := 0.0

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
	_words.font_size = 28 if plate.x > 0.15 else 24
	_words.pixel_size = 0.0006
	_words.position = Vector3(0, 0, 0.007)
	_face.add_child(_words)
	# The hit box covers the plate and its margin, and runs from FRONT to BACK, so a ray or a
	# finger reaches it anywhere on the plate, not only at the middle.
	target = Target.new()
	target.id = id
	target.name = String(id)
	var shape := CollisionShape3D.new()
	var hit := BoxShape3D.new()
	hit.size = Vector3(plate.x + margin * 2.0, plate.y + margin * 2.0, FRONT + BACK)
	shape.shape = hit
	shape.position = Vector3(0, 0, (FRONT - BACK) * 0.5)
	target.add_child(shape)
	add_child(target)


## Whether a fingertip at [param world] is in the button's box (in front of it, on it, or pushed through it).
func reaches(world: Vector3) -> bool:
	var p := to_local(world)
	return absf(p.x) <= plate.x * 0.5 + margin and absf(p.y) <= plate.y * 0.5 + margin \
			and p.z <= FRONT and p.z >= -BACK


## How far [param world] is from the plate's middle, across the plate (to pick the nearest of two).
func off_centre(world: Vector3) -> float:
	var p := to_local(world)
	return Vector2(p.x, p.y).length()


## Changes the words on the plate.
func set_text(text: String) -> void:
	_words.text = text


func text() -> String:
	return _words.text


## A ray or fingertip is on the button now.
func set_hot(on: bool) -> void:
	_hot = on


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
