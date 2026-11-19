extends "res://trials/prop_match_trial.gd"
## Everyday outline matching. No target changes appearance before a release.

const Visuals := preload("res://trials/desk/desk_visuals.gd")
const StudyEnding := preload("res://trials/desk/study_ending.gd")
const TOP := 0.008
const SPOTS := {
	"mug": Vector3(0.245, TOP, -0.17),
	"notebook": Vector3(0.065, TOP, -0.315),
	"pencil": Vector3(0.155, TOP, -0.30),
	"headphones": Vector3(0.07, TOP, -0.12),
	"plant": Vector3(0.26, TOP, -0.375),
}
const HOMES := {
	"mug": Vector3(-0.11, TOP, -0.10),
	"notebook": Vector3(-0.265, TOP, -0.30),
	"pencil": Vector3(-0.07, TOP, -0.20),
	"headphones": Vector3(-0.25, TOP, -0.12),
	"plant": Vector3(-0.10, TOP, -0.38),
}

var _ending: Node3D
var _celebrating := false


func _setup(round_condition: TrialCondition) -> void:
	_celebrating = false
	var head := App.head().global_position
	var table := App.reality.work_surface()
	var toward := table.transform.origin - head
	var ahead := Vector3(toward.x, 0, toward.z).normalized()
	var height := head.y - App.rig.global_position.y
	var reach_scale := clampf(height / 1.22, 0.83, 1.0)
	var below := clampf(head.y - table.transform.origin.y - 0.012, 0.28, 0.40)
	var setback := clampf(0.4 * (height - 1.0), 0.01, 0.07)
	_start_layout("Desk", Transform3D(Basis.looking_at(ahead).scaled(Vector3.ONE * reach_scale),
		head + ahead * setback + Vector3.DOWN * below))
	Visuals.build_table(_board)

	# Mirror the packed tray between rounds; the narrow pieces never hide beneath a bigger prop.
	# Fewer props are easier; the notebook and pencil always come, for the ending.
	var extras := ["mug", "headphones", "plant"]
	extras.shuffle()
	var count := clampi(roundi(round_condition.value(&"props", 5.0)), 3, 5)
	var order: Array = ["notebook", "pencil"] + extras.slice(0, count - 2)
	order.shuffle()
	var mirror := randf() < 0.5
	round_condition.set_value(&"tray_order", ",".join(order))
	round_condition.set_value(&"tray_mirrored", mirror)
	for key: String in order:
		var home: Vector3 = HOMES[key] + Vector3.UP * Props.size_of(key).y * 0.5
		if mirror:
			home.x = -0.39 - home.x
		# Small turns make the tray look casually scattered; matching never checks precision of rotation.
		_add_thing(key, Transform3D(Basis(Vector3.UP, randf_range(-0.08, 0.08)), home))
	for key: String in order:
		var line := Visuals.outline(key)
		line.position = SPOTS[key]
		_board.add_child(line)
		_guides[key] = line
		_spots[key] = Transform3D(Basis.IDENTITY, SPOTS[key] + Vector3.UP * Props.size_of(key).y * 0.5)
	_ending = StudyEnding.new()
	_board.add_child(_ending)
	_ending.completed.connect(_study_finished)
	instruct("Match each thing to its outline. Pinch, carry, then let go.")


## The nearest outline underneath the released object, independent of the held object's identity.
func _slot_at(point: Vector3) -> String:
	var closest := ""
	var distance := INF
	for key: String in SPOTS:
		if not _guides.has(key) or not _guides[key].visible:
			continue
		var delta: Vector3 = point - SPOTS[key]
		var size := Props.size_of(key)
		var half := Vector2(size.x, size.z) * 0.5 + Vector2.ONE * 0.025
		if absf(delta.x) > half.x or absf(delta.z) > half.y or delta.y < -0.025 or delta.y > 0.17:
			continue
		var gap := Vector2(delta.x, delta.z).length()
		if gap < distance:
			distance = gap
			closest = key
	return closest


func _wrong_match() -> void:
	say("Those shapes are different. Look at the outlines and try again.")


func _all_placed() -> void:
	_celebrating = true
	_hint_at = 0.0
	say("All tidy! Someone can study here now.")
	_ending.start(_keys)


func _study_finished() -> void:
	say("The desk is ready. Time to learn!")
	finish(true, {puts = _puts.duplicate(), ending = "studying"})


func _hint(_level: int) -> void:
	say("Compare the whole shape, including handles and openings. You can turn a thing in your hand before choosing an outline.")


func escalate() -> void:
	if not _celebrating:
		super.escalate()


func _teardown() -> void:
	super._teardown()
	_ending.stop()
	_celebrating = false


func focus_point() -> Vector3:
	return _board.to_global(Vector3(0, 0.03, -0.25))


func layout() -> Dictionary:
	var state := _match_layout("outline_", true)
	for cell: Dictionary in state.cells:
		cell.outline_visible = not cell.filled
	state.ending = _ending.phase
	state.celebrating = _celebrating
	return state
