extends Trial

const Visuals := preload("res://trials/sandwich/sandwich_visuals.gd")
const Serving := preload("res://trials/sandwich/sandwich_serving.gd")
const PLATE := Vector3(0.167, 0.004, -0.160)
const SAMPLE := Vector3(0.167, 0.0, -0.369)
const WELL_POSITIONS: Array[Vector3] = [Vector3(-0.25, 0.005, -0.283), Vector3(-0.087, 0.005, -0.283),
	Vector3(-0.25, 0.005, -0.119), Vector3(-0.087, 0.005, -0.119)]
const RELEASE_DELAY := 0.12
const DROP_RADIUS := 0.102
const TAKE_PAUSE := 0.32

var _counter: Node3D
var _sample: Node3D
var _stack: Node3D
var _serving: Node3D
var _recipe: Array[String] = []
var _layers: Array[Node3D] = []
var _things: Dictionary[String, Target] = {}
var _homes: Dictionary[String, Transform3D] = {}
var _moves: Dictionary[String, Tween] = {}
var _stack_height := 0.0
var _placed := 0
var _assembly_seconds := 0.0
var _held := ""
var _hand: StringName
var _offset := Vector3.ZERO
var _release_at := -1.0
var _take_at := 0.0
var _celebrating := false


func _setup(round_condition: TrialCondition) -> void:
	_clear()
	var head := App.head().global_position
	var table := App.reality.work_surface().transform.origin
	var forward := Vector3(table.x - head.x, 0, table.z - head.z).normalized()
	var eye_height := head.y - App.rig.global_position.y
	var reach_scale := clampf(eye_height / 1.22, 0.83, 1.0)
	var below := clampf(head.y - table.y - 0.02, 0.26, 0.37)
	var setback := clampf(0.4 * (eye_height - 1.0), 0.02, 0.07)
	_counter = Node3D.new()
	_counter.name = "Counter"
	add_child(_counter)
	_counter.global_transform = Transform3D(Basis.looking_at(forward).scaled(Vector3.ONE * reach_scale),
		head + forward * setback + Vector3.DOWN * below)
	Visuals.counter(_counter, WELL_POSITIONS, PLATE)
	_recipe = ["lettuce", "tomato", "cheese"]
	_recipe.shuffle() # fewer fillings are easier
	_recipe = _recipe.slice(0, clampi(roundi(round_condition.value(&"fillings", 3.0)), 1, 3))
	_recipe.append("bread")
	var tray := _recipe.duplicate()
	tray.shuffle()
	round_condition.set_value(&"recipe", _recipe.duplicate())
	round_condition.set_value(&"tray_order", tray.duplicate())
	_sample = Node3D.new()
	_sample.name = "Sample"
	_counter.add_child(_sample)
	_sample.position = SAMPLE
	Visuals.sample(_sample, _recipe)
	_stack = Node3D.new()
	_stack.name = "Stack"
	_counter.add_child(_stack)
	_stack.position = PLATE + Vector3.UP * 0.014
	var toast := Visuals.model("bread")
	_stack.add_child(toast)
	_layers.append(toast)
	_stack_height = Visuals.SIZES["bread"].y
	for index in tray.size():
		_add_ingredient(tray[index], WELL_POSITIONS[index])
	_serving = Serving.new()
	_counter.add_child(_serving)
	_serving.position = PLATE
	_serving.completed.connect(_served)
	instruct("Copy the sample from the bottom up. Pinch a piece, then let go above the plate.")


func _add_ingredient(key: String, at: Vector3) -> void:
	var size: Vector3 = Visuals.SIZES[key]
	var thing := Target.new()
	thing.id = StringName("sandwich_" + key)
	thing.name = String(thing.id)
	var shape := BoxShape3D.new()
	shape.size = size + Vector3(0.010, 0.020, 0.010)
	var hitbox := CollisionShape3D.new()
	hitbox.shape = shape
	thing.add_child(hitbox)
	var model := Visuals.model(key)
	thing.add_child(model)
	model.position.y = -size.y * 0.5
	_counter.add_child(thing)
	thing.position = at + Vector3.UP * size.y * 0.5
	thing.rotation.y = randf_range(-0.16, 0.16)
	_things[key] = thing
	_homes[key] = thing.transform


func _on_button(hand: StringName, action: StringName, pressed: bool) -> void:
	if action != &"trigger_click" or _celebrating:
		return
	var pointer := App.rig.pointer(hand)
	if not pressed:
		if hand == _hand:
			_things[_held].global_position = pointer.grip().origin + _offset
			_release_at = seconds() + RELEASE_DELAY
		return
	if hand == _hand:
		_release_at = -1.0
		return
	if not _held.is_empty() or seconds() < _take_at or not pointer.tracked():
		return
	var grip := pointer.grip().origin
	var best := INF
	for key: String in _things:
		var thing := _things[key]
		if thing.get_parent() == _stack or _moves.has(key):
			continue
		var local := thing.to_local(grip)
		var half: Vector3 = Visuals.SIZES[key] * 0.5 + Vector3(0.020, 0.029, 0.020)
		var gap := local.length_squared()
		if absf(local.x) <= half.x and absf(local.y) <= half.y and absf(local.z) <= half.z and gap < best:
			best = gap
			_held = key
	if not _held.is_empty():
		_hand = hand
		var thing := _things[_held]
		_offset = thing.global_position - grip
		Events.play(&"grab", thing.global_position)
		Events.report(&"sandwich_taken", {ingredient = _held, hand = hand})


func _physics_process(_delta: float) -> void:
	if not is_running() or _held.is_empty():
		return
	var pointer := App.rig.pointer(_hand)
	if not pointer.tracked():
		_return_held()
	elif _release_at < 0.0:
		_things[_held].global_position = pointer.grip().origin + _offset
	elif seconds() >= _release_at:
		_drop()


func _drop() -> void:
	var key := _held
	var thing := _things[key]
	var at := thing.global_position
	var offset := _stack.to_local(at) - Vector3.UP * _stack_height
	_release()
	if Vector2(offset.x, offset.z).length() > DROP_RADIUS or offset.y < -0.062 or offset.y > 0.155:
		Events.play(&"slide", at)
		_move(key, _homes[key])
		return
	var expected := _recipe[_placed]
	var correct := key == expected
	pick(expected, key)
	Events.report(&"sandwich_layer", {layer = _placed + 2, target = expected, ingredient = key, correct = correct})
	if not correct:
		count_try()
		judge(&"bad", _stack.to_global(Vector3.UP * _stack_height))
		say("Look at the sample again. Which layer comes next?")
		_move(key, _homes[key])
		return
	thing.reparent(_stack)
	thing.collision_layer = 0
	_layers.append(thing)
	var size: Vector3 = Visuals.SIZES[key]
	var turn := 0.18 if key == "cheese" else 0.0
	var to := Transform3D(Basis(Vector3.UP, turn), Vector3.UP * (_stack_height + size.y * 0.5))
	_move(key, to)
	_stack_height += size.y
	_placed += 1
	Events.play(&"place", _stack.to_global(to.origin))
	judge(&"good", _stack.to_global(to.origin))
	if _placed == _recipe.size():
		_celebrating = true
		_assembly_seconds = snappedf(seconds(), 0.01)
		_hint_at = 0.0
		say("Look at what you made!")
		_serving.start(_stack, _layers, _sample)
	else:
		_arm_hint()


func _move(key: String, to: Transform3D) -> void:
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_moves[key] = tween
	tween.tween_property(_things[key], ^"transform", to, 0.23)
	tween.finished.connect(func() -> void: _moves.erase(key))


func _served() -> void:
	finish(true, {assembly_seconds = _assembly_seconds, ending = "served"})


func _hint(_level: int) -> void:
	say("Look at the sample from the bottom up. Which layer goes just above the ones on your plate?")


func escalate() -> void:
	if not _celebrating:
		super.escalate()


func _release() -> void:
	_held = ""
	_hand = &""
	_release_at = -1.0
	_take_at = seconds() + TAKE_PAUSE


func _return_held() -> void:
	_things[_held].transform = _homes[_held]
	_release()


func _on_tracking(hand: StringName, tracked: bool) -> void:
	if not tracked and hand == _hand:
		_return_held()


func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_PAUSED and not _held.is_empty():
		_return_held()


func _teardown() -> void:
	if not _held.is_empty():
		_return_held()
	_serving.stop()
	_celebrating = false


func _clear() -> void:
	for tween: Tween in _moves.values():
		tween.kill()
	_moves.clear()
	if _counter:
		_counter.free()
	_things.clear()
	_homes.clear()
	_layers.clear()
	_placed = 0
	_take_at = 0.0


func focus_point() -> Vector3:
	return _counter.to_global(Vector3(0.014, 0.086, -0.24))


func layout() -> Dictionary:
	var things := []
	for key: String in _things:
		var thing := _things[key]
		things.append({key = key, centre = thing.global_position, home = _counter.to_global(_homes[key].origin),
			thickness = Visuals.SIZES[key].y * _counter.scale.x, placed = thing.get_parent() == _stack,
			carried = _hand if key == _held else &""})
	return {things = things, recipe = _recipe.duplicate(), placed = _placed, celebrating = _celebrating,
		stage = _serving.phase, plate = _stack.to_global(Vector3.UP * (_stack_height + 0.017)),
		sample = _counter.to_global(SAMPLE + Vector3.UP * 0.147), focus = focus_point(), release_delay = RELEASE_DELAY}
