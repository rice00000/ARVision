extends Trial
## Everyday outline matching. No target changes appearance before a release.

const Visuals := preload("res://trials/desk/desk_visuals.gd")
const StudyEnding := preload("res://trials/desk/study_ending.gd")
const RELEASE_DELAY := 0.12
const TAKE_PAUSE := 0.5
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

var _desk: Node3D
var _things: Array[Target] = []
var _keys: Dictionary[Target, String] = {}
var _homes: Dictionary[Target, Transform3D] = {}
var _outlines: Dictionary[String, MeshInstance3D] = {}
var _placed: Dictionary[Target, bool] = {}
var _carried: Dictionary[StringName, Target] = {}
var _offsets: Dictionary[StringName, Transform3D] = {}
var _release_at: Dictionary[StringName, float] = {}
var _free_at: Dictionary[StringName, float] = {}
var _moves: Dictionary[Target, Tween] = {}
var _puts: Array[Dictionary] = []
var _ending: Node3D
var _celebrating := false


func _setup(round_condition: TrialCondition) -> void:
	_clear()
	_desk = Node3D.new()
	_desk.name = "Desk"
	add_child(_desk)
	var head := App.head().global_position
	var table := App.reality.work_surface()
	var toward := table.transform.origin - head
	var ahead := Vector3(toward.x, 0, toward.z).normalized()
	var height := head.y - App.rig.global_position.y
	var reach_scale := clampf(height / 1.22, 0.83, 1.0)
	var below := clampf(head.y - table.transform.origin.y - 0.012, 0.28, 0.40)
	var setback := clampf(0.4 * (height - 1.0), 0.01, 0.07)
	_desk.global_transform = Transform3D(Basis.looking_at(ahead).scaled(Vector3.ONE * reach_scale),
		head + ahead * setback + Vector3.DOWN * below)
	Visuals.build_table(_desk)
	# Mirror the packed tray between rounds; the narrow pieces never hide beneath a bigger prop.
	var order: Array[String] = Visuals.KEYS.duplicate()
	order.shuffle()
	var mirror := randf() < 0.5
	round_condition.set_value(&"tray_order", ",".join(order))
	round_condition.set_value(&"tray_mirrored", mirror)
	for i in order.size():
		var key := order[i]
		var size := Visuals.size_of(key)
		var thing := Target.new()
		thing.id = StringName("desk_" + key)
		thing.name = String(thing.id)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size.max(Vector3.ONE * 0.025) + Vector3.ONE * 0.008
		collision.shape = shape
		thing.add_child(collision)
		var look: Node3D = Visuals.MODELS[key].instantiate()
		look.name = "Model"
		look.position.y = -size.y * 0.5
		thing.add_child(look)
		_desk.add_child(thing)
		var home: Vector3 = HOMES[key]
		if mirror:
			home.x = -0.39 - home.x
		thing.position = home + Vector3.UP * size.y * 0.5
		# Small turns make the tray look casually scattered; matching never checks precision of rotation.
		thing.rotation.y = randf_range(-0.08, 0.08)
		_things.append(thing)
		_keys[thing] = key
		_homes[thing] = thing.transform
		var line := Visuals.outline(key)
		_desk.add_child(line)
		line.position = SPOTS[key]
		_outlines[key] = line
	_ending = StudyEnding.new()
	_desk.add_child(_ending)
	_ending.completed.connect(_study_finished)
	say("Match each thing to its outline. Pinch, carry, then let go.")


func _on_button(hand: StringName, action: StringName, pressed: bool) -> void:
	if action != &"trigger_click" or _celebrating:
		return
	if not pressed:
		if _carried.has(hand):
			_carried[hand].global_transform = App.rig.pointer(hand).grip() * _offsets[hand]
			_release_at[hand] = seconds() + RELEASE_DELAY
		return
	_release_at.erase(hand)
	if _carried.has(hand) or seconds() < _free_at.get(hand, 0.0):
		return
	var pointer := App.rig.pointer(hand)
	if not pointer.tracked():
		return
	var nearest: Target
	var distance := INF
	for thing in _things:
		if _placed.has(thing) or thing in _carried.values():
			continue
		var local := thing.to_local(pointer.grip().origin)
		var half := Visuals.size_of(_keys[thing]).max(Vector3.ONE * 0.025) * 0.5 + Vector3.ONE * 0.025
		if absf(local.x) > half.x or absf(local.y) > half.y or absf(local.z) > half.z:
			continue
		var gap := local.length()
		if gap < distance:
			nearest = thing
			distance = gap
	if nearest:
		_stop_move(nearest)
		_carried[hand] = nearest
		_offsets[hand] = pointer.grip().affine_inverse() * nearest.global_transform
		Events.report(&"taken", {thing = _keys[nearest], hand = hand})


func _physics_process(_delta: float) -> void:
	if not is_running() or _celebrating:
		return
	for hand: StringName in _carried.keys():
		var pointer := App.rig.pointer(hand)
		if not pointer.tracked():
			_return(hand)
			continue
		var thing := _carried[hand]
		if not _release_at.has(hand):
			thing.global_transform = pointer.grip() * _offsets[hand]
		elif seconds() >= _release_at[hand]:
			_put(hand)


## The nearest outline underneath the released object, independent of the held object's identity.
func _slot_at(point: Vector3) -> String:
	var local := _desk.to_local(point)
	var closest := ""
	var distance := INF
	for key: String in SPOTS:
		if not _outlines[key].visible:
			continue
		var delta: Vector3 = local - SPOTS[key]
		var size := Visuals.size_of(key)
		var half := Vector2(size.x, size.z) * 0.5 + Vector2.ONE * 0.025
		if absf(delta.x) > half.x or absf(delta.z) > half.y or delta.y < -0.025 or delta.y > 0.17:
			continue
		var gap := Vector2(delta.x, delta.z).length()
		if gap < distance:
			distance = gap
			closest = key
	return closest


func _put(hand: StringName) -> void:
	var thing := _carried[hand]
	var key := _keys[thing]
	var slot := _slot_at(thing.global_position)
	_let_go(hand)
	if slot.is_empty():
		_move(thing, _homes[thing])
		return
	var right := key == slot
	pick(slot, key)
	_puts.append({thing = key, slot = slot, correct = right, seconds = snappedf(seconds(), 0.01)})
	Events.report(&"put", _puts.back())
	if not right:
		count_try()
		judge(&"bad", thing.global_position)
		say("Those shapes are different. Look at the outlines and try again.")
		_move(thing, _homes[thing])
		return
	_placed[thing] = true
	_outlines[key].hide()
	var rest: Vector3 = SPOTS[key] + Vector3.UP * Visuals.size_of(key).y * 0.5
	_move(thing, Transform3D(Basis.IDENTITY, rest))
	judge(&"good", _desk.to_global(rest))
	_arm_hint()
	if _placed.size() == _things.size():
		_celebrate()


func _celebrate() -> void:
	_celebrating = true
	_hint_at = 0.0
	condition.set_value(&"tidy_seconds", snappedf(seconds(), 0.01))
	for thing in _things:
		thing.collision_layer = 0
	say("All tidy! Someone can study here now.")
	_ending.start(_keys)


func _study_finished() -> void:
	say("The desk is ready. Time to learn!")
	finish(true, {puts = _puts.duplicate(), ending = "studying"})


func _hint(_level: int) -> void:
	if not _celebrating:
		say("Compare the whole shape, including handles and openings. You can turn a thing in your hand before choosing an outline.")


func escalate() -> void:
	if not _celebrating:
		super.escalate()


func _on_tracking(hand: StringName, tracked: bool) -> void:
	if not tracked and _carried.has(hand):
		_return(hand)


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_PAUSED:
		for hand: StringName in _carried.keys():
			_return(hand)


func _let_go(hand: StringName) -> void:
	_carried.erase(hand)
	_offsets.erase(hand)
	_release_at.erase(hand)
	_free_at[hand] = seconds() + TAKE_PAUSE


func _return(hand: StringName) -> void:
	var thing := _carried[hand]
	_let_go(hand)
	_move(thing, _homes[thing])


func _stop_move(thing: Target) -> void:
	if _moves.has(thing):
		_moves[thing].kill()
		_moves.erase(thing)


func _move(thing: Target, to: Transform3D) -> void:
	_stop_move(thing)
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_moves[thing] = tween
	tween.tween_property(thing, ^"transform", to, 0.28)
	tween.finished.connect(func() -> void: _moves.erase(thing))


func _teardown() -> void:
	for hand: StringName in _carried.keys():
		_return(hand)
	if _ending:
		_ending.stop()
	_celebrating = false


func _clear() -> void:
	for tween: Tween in _moves.values():
		tween.kill()
	_moves.clear()
	if _desk:
		_desk.free()
	_things.clear()
	_keys.clear()
	_homes.clear()
	_outlines.clear()
	_placed.clear()
	_carried.clear()
	_offsets.clear()
	_release_at.clear()
	_free_at.clear()
	_puts.clear()
	_celebrating = false


func focus_point() -> Vector3:
	return _desk.to_global(Vector3(0, 0.03, -0.25))


func layout() -> Dictionary:
	var things := []
	for thing in _things:
		var key := _keys[thing]
		things.append({id = thing.id, key = key, centre = thing.global_position,
			size = Visuals.size_of(key).length() * _desk.scale.x, home = _desk.to_global(_homes[thing].origin),
			placed = _placed.has(thing), carried = _carried.find_key(thing) if thing in _carried.values() else &""})
	var cells := []
	for key: String in SPOTS:
		cells.append({id = "outline_" + key, key = key,
			position = _desk.to_global(SPOTS[key] + Vector3.UP * Visuals.size_of(key).y * 0.5),
			filled = not _outlines[key].visible, outline_visible = _outlines[key].visible})
	return {things = things, cells = cells, outline = true, match = 0, release_delay = RELEASE_DELAY,
		ending = _ending.phase, celebrating = _celebrating}
