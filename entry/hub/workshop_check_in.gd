class_name WorkshopCheckIn
extends Node3D
## The optional Hub entry and the world-space status of an active check-in.

const INK := Color("#14272b")
const TEAL := Color("#25545a")
const TEXT := Color("#fff4df")
const MUTED := Color("#bcd1ce")
const GOLD := Color("#f4d298")
const EMPTY := Color("#587075")
const MARK_WIDTH := 0.012
const MARK_STEP := 0.017

var offer := EntryButton.new()
var back := EntryButton.new()
var _offered: Place
var _offer_detail: Label3D
var _status := Node3D.new()
var _title: Label3D
var _instruction: Label3D
var _progress: Label3D
var _subtitle := Marker3D.new()
var _motion := false
var _marks: Array[MeshInstance3D] = []
var _fill := StandardMaterial3D.new()
var _empty := StandardMaterial3D.new()


func _ready() -> void:
	name = "WorkshopCheckIn"
	add_child(offer)
	offer.setup("", &"hub_check_in", TEAL, Vector2(0.31, 0.078), 0.007)
	offer.target.show_ray = false
	_label(offer, "Quick check-in", Vector3(-0.133, 0.014, 0.009), 37, TEXT)
	_offer_detail = _label(offer, "", Vector3(-0.133, -0.016, 0.009), 26, MUTED)
	_label(offer, "›", Vector3(0.113, 0.001, 0.009), 54, GOLD)
	show_offer(null)

	add_child(_status)
	_plate(_status, Vector2(0.46, 0.112), Vector3.ZERO, INK)
	_plate(_status, Vector2(0.46, 0.003), Vector3(0.0, 0.054, 0.001), GOLD)
	_title = _label(_status, "", Vector3(-0.21, 0.028, 0.008), 35, TEXT)
	_instruction = _label(_status, "", Vector3(-0.21, -0.005, 0.008), 27, MUTED)
	_progress = _label(_status, "", Vector3(-0.21, -0.035, 0.008), 24, GOLD)
	_progress.name = "Progress"
	_status.add_child(_subtitle)
	_subtitle.add_to_group(App.SUBTITLE_SLOT)
	_status.add_child(back)
	back.position = Vector3(0.145, 0.005, 0.009)
	back.setup("Back to games", &"hub_check_in_back", TEAL, Vector2(0.142, 0.048), 0.008, 28)
	back.target.speech = "Games"
	back.target.show_ray = false
	_fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fill.albedo_color = GOLD
	_empty.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_empty.albedo_color = EMPTY
	clear_status()


func show_offer(place: Place) -> void:
	if _offered == place and offer.visible == (place != null):
		return
	_offered = place
	offer.visible = place != null
	offer.target.collision_layer = Pointer.UI_LAYER if offer.visible else 0
	if place != null:
		var subject := "Moving dots" if _is_motion(place) else "Shapes & colours"
		_offer_detail.text = "%s  ·  %d rounds" % [subject, place.check_in.round_count()]
		offer.target.speech = place.check_in.title


func place_offer(menu_at: Vector3) -> void:
	var to_eye := App.head().global_position - menu_at
	var frame := Transform3D(Basis.looking_at(to_eye, Vector3.UP, true), menu_at)
	offer.global_transform = frame.translated_local(Vector3(0.0, 0.162, 0.01))


func begin(place: Place) -> void:
	var head := App.head()
	_motion = _is_motion(place)
	_subtitle.position = Vector3(0.0, -0.133 if _motion else 0.121, 0.0)
	var focus := head.global_position - head.global_basis.z if _motion \
			else App.reality.work_surface().transform.origin + Vector3.UP * 0.1
	place_status(focus)
	var rounds := place.check_in.round_count()
	for i in rounds:
		var mark := _plate(_status, Vector2(MARK_WIDTH, 0.007),
				Vector3(-0.097 + i * MARK_STEP, -0.036, 0.006), EMPTY)
		_marks.append(mark)
	_status.show()
	back.show()
	back.target.collision_layer = Pointer.UI_LAYER
	_title.text = "Quick check-in"
	show_round(0, place.check_in.blocks[0].trial.skill)


## Settle the board in the direction of the real work, with room for the work and the guide's captions.
func place_status(focus: Vector3) -> void:
	var eye := App.head().global_position
	var towards := focus - eye
	var flat := Vector3(towards.x, 0.0, towards.z)
	var ahead := flat.normalized()
	var at := eye + ahead * 0.73 - Vector3.UP * 0.36
	if not _motion:
		# The upper cubbies reach about 20 cm above the shelf trial's focus point.
		var elevation := atan2(towards.y + 0.20, flat.length()) + deg_to_rad(8.0)
		at = eye + (ahead * cos(elevation) + Vector3.UP * sin(elevation)) * 0.73
	_status.global_transform = Transform3D(Basis.looking_at(eye - at, Vector3.UP, true), at)


func show_round(index: int, skill: StringName) -> void:
	match skill:
		&"global_motion":
			_instruction.text = "Sweep the way the dots move."
		&"colour_discrimination":
			_instruction.text = "Pinch the different colour."
		_:
			_instruction.text = "Match each shape to its shadow."
	_progress.text = "Round %d of %d" % [index + 1, _marks.size()]
	for i in _marks.size():
		_marks[i].material_override = _fill if i <= index else _empty


func returning() -> void:
	_title.text = "Returning to games…"
	_instruction.text = ""
	_progress.text = ""
	for mark in _marks:
		mark.hide()
	back.hide()
	back.target.collision_layer = 0


func complete() -> void:
	returning()
	_title.text = "Check-in complete"


func clear_status() -> void:
	_status.hide()
	back.target.collision_layer = 0
	for mark in _marks:
		mark.queue_free()
	_marks.clear()


static func _is_motion(place: Place) -> bool:
	return place.check_in.blocks[0].trial.skill == &"global_motion"


static func _label(parent: Node3D, words: String, at: Vector3, size: int, colour: Color) -> Label3D:
	var label := Label3D.new()
	label.text = words
	label.font_size = size
	label.pixel_size = 0.0006
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.modulate = colour
	label.outline_size = 0
	parent.add_child(label)
	label.position = at
	return label


static func _plate(parent: Node3D, size: Vector2, at: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mesh.mesh = quad
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	mesh.material_override = material
	parent.add_child(mesh)
	mesh.position = at
	return mesh
