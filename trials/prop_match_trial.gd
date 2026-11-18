extends Trial
## Shared reach, carry and release rules for matching everyday objects.

const Props := preload("res://trials/study_props.gd")
const RELEASE_DELAY := 0.12
const TAKE_PAUSE := 0.5

var _board: Node3D
var _things: Array[Target] = []
var _keys: Dictionary[Target, String] = {}
var _sizes: Dictionary[Target, Vector3] = {}
var _homes: Dictionary[Target, Transform3D] = {}
var _spots: Dictionary[String, Transform3D] = {}
var _guides: Dictionary[String, Node3D] = {}
var _placed: Dictionary[Target, bool] = {}
var _carried: Dictionary[StringName, Target] = {}
var _offsets: Dictionary[StringName, Transform3D] = {}
var _release_at: Dictionary[StringName, float] = {}
var _free_at: Dictionary[StringName, float] = {}
var _moves: Dictionary[Target, Tween] = {}
var _puts: Array[Dictionary] = []


func _start_layout(board_name: String, frame: Transform3D) -> void:
	for tween: Tween in _moves.values():
		tween.kill()
	_moves.clear()
	if _board:
		_board.free()
	_things.clear()
	_keys.clear()
	_sizes.clear()
	_homes.clear()
	_spots.clear()
	_guides.clear()
	_placed.clear()
	_carried.clear()
	_offsets.clear()
	_release_at.clear()
	_free_at.clear()
	_puts.clear()
	_board = Node3D.new()
	_board.name = board_name
	add_child(_board)
	_board.global_transform = frame


func _add_thing(key: String, home: Transform3D, factor := 1.0) -> void:
	var size := Props.size_of(key) * factor
	var thing := Target.new()
	thing.id = StringName("%s_%s" % [condition.trial, key])
	thing.name = String(thing.id)
	thing.transform = home
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size.max(Vector3.ONE * 0.025) + Vector3.ONE * 0.008
	collision.shape = shape
	thing.add_child(collision)
	thing.add_child(Props.centred_model(key, factor))
	_board.add_child(thing)
	_things.append(thing)
	_keys[thing] = key
	_sizes[thing] = size
	_homes[thing] = home


func _on_button(hand: StringName, action: StringName, pressed: bool) -> void:
	if action != &"trigger_click":
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
	var grip := pointer.grip()
	var nearest: Target
	var distance := INF
	for thing in _things:
		if _placed.has(thing) or thing in _carried.values():
			continue
		var local := thing.to_local(grip.origin)
		var half := _sizes[thing].max(Vector3.ONE * 0.025) * 0.5 + Vector3.ONE * 0.025
		if absf(local.x) > half.x or absf(local.y) > half.y or absf(local.z) > half.z:
			continue
		var gap := local.length_squared()
		if gap < distance:
			nearest = thing
			distance = gap
	if nearest:
		_stop_move(nearest)
		_carried[hand] = nearest
		_offsets[hand] = grip.affine_inverse() * nearest.global_transform
		Events.play(&"grab", nearest.global_position)
		Events.report(&"taken", {thing = _keys[nearest], hand = hand})


func _physics_process(_delta: float) -> void:
	if not is_running():
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


func _put(hand: StringName) -> void:
	var thing := _carried[hand]
	var key := _keys[thing]
	var slot := _slot_at(_board.to_local(thing.global_position))
	_let_go(hand)
	if slot.is_empty():
		Events.play(&"slide", thing.global_position)
		_move(thing, _homes[thing])
		return
	var right := key == slot
	pick(slot, key)
	_puts.append({thing = key, slot = slot, correct = right, seconds = snappedf(seconds(), 0.01)})
	Events.report(&"put", _puts.back())
	if not right:
		count_try()
		judge(&"bad", thing.global_position)
		Events.play(&"slide", thing.global_position)
		_wrong_match()
		_move(thing, _homes[thing])
		return
	_placed[thing] = true
	_guides[key].hide()
	_move(thing, _spots[key])
	var rest := _board.to_global(_spots[key].origin)
	Events.play(&"place", rest)
	judge(&"good", rest)
	_arm_hint()
	if _placed.size() == _things.size():
		condition.set_value(&"tidy_seconds", snappedf(seconds(), 0.01))
		for placed in _things:
			placed.collision_layer = 0
		_all_placed()


## Return the open destination at this point in the furniture's local space.
func _slot_at(_point: Vector3) -> String:
	return ""


func _wrong_match() -> void:
	say("That's not its shape. Look again!")


func _all_placed() -> void:
	finish(true, {puts = _puts.duplicate()})


func _on_tracking(hand: StringName, tracked: bool) -> void:
	if not tracked and _carried.has(hand):
		_return(hand)


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_PAUSED:
		_teardown_grabs()


func _teardown() -> void:
	_teardown_grabs()


func _teardown_grabs() -> void:
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


func _match_layout(slot_prefix: String, outline: bool) -> Dictionary:
	var things := []
	for thing in _things:
		things.append({id = thing.id, key = _keys[thing], centre = thing.global_position,
			size = _sizes[thing].length() * _board.scale.x, home = _board.to_global(_homes[thing].origin),
			placed = _placed.has(thing), carried = _carried.find_key(thing) if thing in _carried.values() else &""})
	var cells := []
	for key: String in _spots:
		cells.append({id = slot_prefix + key, key = key, position = _board.to_global(_spots[key].origin),
			filled = not _guides[key].visible})
	return {things = things, cells = cells, outline = outline, match = 0, release_delay = RELEASE_DELAY}
