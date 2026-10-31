class_name SetupPanel
extends Node3D
## The pre-game setup panel, for the grown-up: a sage strip "SETUP · for the grown-up" with
## the step dots, a title, a line of words, a few check lines (a coloured dot and words)
## and up to two buttons. One panel; each step replaces what is on it. The Entry does the
## checking and listening; this is only the look. It stands upright, facing the head.
##
## Dot colours: [constant GOOD] done, [constant WARN] worth a look, [constant WAIT] not yet.

const SIZE := Vector2(0.46, 0.34)
const SAGE := Color(0.62, 0.74, 0.6)
const SLATE := Color(0.13, 0.15, 0.19)   # opaque: a see-through plate gets drawn over the words
const GOOD := Color(0.4, 0.85, 0.5)
const WARN := Color(1.0, 0.65, 0.25)
const WAIT := Color(0.55, 0.58, 0.62)
const GREEN := Color(0.25, 0.65, 0.35)
const GREY := Color(0.38, 0.4, 0.45)

## The Entry's button maker: (text, world position, id, colour, wide, margin) -> EntryButton.
var make_button: Callable
## The buttons on the panel now.
var buttons: Array[EntryButton] = []
## The step shown (1-based) and how many there are.
var step := 0
var steps := 4

var _title: Label3D
var _body: Label3D
var _dots: Array[MeshInstance3D] = []
var _checks: Array[Dictionary] = []   # {dot: MeshInstance3D, words: Label3D}


func _ready() -> void:
	_plate(SIZE, Vector3(0, 0, 0), SLATE, 0.008)
	_plate(Vector2(SIZE.x, 0.036), Vector3(0, SIZE.y * 0.5 - 0.018, 0.001), SAGE, 0.008)
	var head := _label("SETUP  ·  for the grown-up", 22, Color(0.1, 0.17, 0.1))
	head.position = Vector3(-SIZE.x * 0.5 + 0.012, SIZE.y * 0.5 - 0.018, 0.006)
	_title = _label("", 44, Color.WHITE)
	_title.position = Vector3(-SIZE.x * 0.5 + 0.015, 0.1, 0.006)
	_body = _label("", 28, Color(0.86, 0.89, 0.92))
	_body.width = 690.0
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_body.position = Vector3(-SIZE.x * 0.5 + 0.015, 0.072, 0.006)
	for i in 6:
		var dot := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.006
		ball.height = 0.012
		ball.radial_segments = 8
		ball.rings = 4
		dot.mesh = ball
		dot.material_override = _flat(Color(0.1, 0.17, 0.1))
		dot.position = Vector3(SIZE.x * 0.5 - 0.016 - i * 0.02, SIZE.y * 0.5 - 0.018, 0.008)
		add_child(dot)
		_dots.append(dot)
	visible = false


## Stands the panel [param distance] metres ahead of [param head], facing it.
func place(head: Transform3D, distance := 0.55) -> void:
	var ahead := Vector3(-head.basis.z.x, 0.0, -head.basis.z.z).normalized()
	add_to_group(&"entry_panel")
	global_position = head.origin + ahead * distance + Vector3.UP * 0.02
	look_at(Vector3(head.origin.x, global_position.y, head.origin.z), Vector3.UP)
	rotate_object_local(Vector3.UP, PI)   # its face (+z) to the child


## Shows step [param number] of [param total]: title, words, check lines
## ([[text, state], ...]) and up to two buttons ([[text, id, colour], ...]), replacing what was there.
func show_step(number: int, total: int, title: String, words: String, checks: Array, button_defs: Array) -> void:
	step = number
	steps = total
	clear_buttons()
	for check in _checks:
		(check.dot as Node).queue_free()
		(check.words as Node).queue_free()
	_checks.clear()
	_title.text = title
	_body.text = words
	for i in _dots.size():
		_dots[i].visible = i < total
		(_dots[i].material_override as StandardMaterial3D).albedo_color = Color(0.1, 0.17, 0.1) if (total - 1 - i) < number else Color(0.62, 0.74, 0.6).darkened(0.25)
	for i in checks.size():
		var y := -0.005 - i * 0.03
		var dot := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.008
		ball.height = 0.016
		ball.radial_segments = 10
		ball.rings = 5
		dot.mesh = ball
		dot.material_override = _flat(WAIT)
		dot.position = Vector3(-SIZE.x * 0.5 + 0.026, y, 0.008)
		add_child(dot)
		var line := _label(str(checks[i][0]), 28, Color.WHITE)
		line.position = Vector3(-SIZE.x * 0.5 + 0.045, y, 0.006)
		_checks.append({dot = dot, words = line})
		set_check(i, checks[i][1])
	var count := button_defs.size()
	for i in count:
		var def: Array = button_defs[i]
		var wide := 0.215 if count > 1 else 0.24
		var x := (i - (count - 1) * 0.5) * 0.23
		var button: EntryButton = make_button.call(str(def[0]), to_global(Vector3(x, -0.125, 0.012)), def[1], def[2], wide, 0.012)
		button.global_basis = global_basis   # parallel to the panel, not turned toward the head on its own
		buttons.append(button)
	visible = true


## Changes the line of words under the title.
func set_body(words: String) -> void:
	_body.text = words


## Sets check line [param index] to [param state] (and its words, when given).
func set_check(index: int, state: StringName, words := "") -> void:
	if index >= _checks.size():
		return
	var colour := GOOD if state == &"good" else WARN if state == &"warn" else WAIT
	((_checks[index].dot as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = colour
	if words != "":
		(_checks[index].words as Label3D).text = words


func check_state(index: int) -> StringName:
	var colour := ((_checks[index].dot as MeshInstance3D).material_override as StandardMaterial3D).albedo_color
	return &"good" if colour.is_equal_approx(GOOD) else &"warn" if colour.is_equal_approx(WARN) else &"wait"


## Recolours the button with [param id], if it is on the panel.
func set_button_colour(id: StringName, colour: Color) -> void:
	for button in buttons:
		if button.id == id:
			button.set_colour(colour)


func clear_buttons() -> void:
	for button in buttons:
		if is_instance_valid(button):
			button.queue_free()
	buttons.clear()


## Takes the panel (and its buttons) away.
func hide_all() -> void:
	clear_buttons()
	visible = false


func _plate(size: Vector2, at: Vector3, colour: Color, depth: float) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x, size.y, depth)
	mesh.mesh = box
	mesh.material_override = _flat(colour)
	mesh.position = at
	add_child(mesh)


func _label(text: String, font_size: int, colour: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = font_size
	label.pixel_size = 0.0006
	label.modulate = colour
	label.outline_size = 0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(label)
	return label


func _flat(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	if colour.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
