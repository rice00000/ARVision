class_name Pet
extends Node3D
## One pet. It earns a magic stone per [method minutes] of training and carries
## it to the child in the room. Petting it raises its level, which shortens that.
##
## An offered palm suspends floor behaviour until the pet lands again.

enum Act {PETTED, DELIVER, REST, WANDER, IDLE, COME, JUMP_UP, ON_HAND, JUMP_DOWN}

const MAX_LEVEL := 5
## A pet counts toward the next level only this long after the last one that did.
const PET_GAP := 60.0
const SIZE := 0.2
const HAND_SIZE := 0.065
const SPEED := 0.45
const COME_SPEED := 0.90
const JUMP_UP_SECONDS := 0.52
const JUMP_DOWN_SECONDS := 0.42
const STONE_OFFSET := Vector3(0, 0.155, 0.2)
## The body's centre above the feet, and how near a fingertip pets it.
const BODY := 0.17
const PET_RADIUS := 0.17

var id: StringName
var level := 0
## Pets counted toward the next level.
var pets := 0
## Training seconds toward the next stone.
var progress := 0.0
## A stone is waiting in its mouth.
var has_stone := false
var act := Act.IDLE
var stone := Target.sphere(&"pet_stone", 0.08)

var _home: Node
var _model: Node3D
var _anim: AnimationPlayer
var _since_pet := PET_GAP
var _petted_for := 0.0
var _mood := Act.IDLE
var _mood_for := 0.0
var _spot := Vector3.ZERO
var _path := PackedVector3Array()
var _retry_route_at := 0.0
var _delivery_at := Vector3.INF
var _hand: StringName
var _palm := Vector3.ZERO
var _palm_ready := false
var _planned_palm := Vector3.ZERO
var _takeoff := Vector3.INF
var _jump_from := Vector3.ZERO
var _jump_to := Vector3.ZERO
var _jump_for := 0.0
var _jump_size := SIZE
var _touching: Dictionary[StringName, bool] = {}
var _clock := 0.0


func setup(pet_id: StringName, home: Node, saved: Dictionary) -> void:
	id = pet_id
	name = String(pet_id)
	_home = home
	level = saved.get("level", 0)
	pets = saved.get("pets", 0)
	progress = saved.get("progress", 0.0)
	has_stone = saved.get("stone", false)
	_model = ItemDef.find(id).scene.instantiate()
	_model.scale = Vector3.ONE * SIZE
	add_child(_model)
	_anim = _model.get_node(^"AnimationPlayer")
	for clip in _anim.get_animation_list():
		_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	var gem: Node3D = load("res://content/items/visuals/magic_stone.tscn").instantiate()
	gem.position.y = -0.045
	stone.add_child(gem)
	stone.position = STONE_OFFSET
	add_child(stone)
	leave_room()


## Minutes of training for one stone.
func minutes() -> int:
	return 10 - level


## Pets still needed for the next level.
func pets_needed() -> int:
	return 2 * level + 1 - pets


func train(delta: float) -> void:
	if has_stone: return
	progress += delta
	if progress >= minutes() * 60.0:
		progress = 0.0
		has_stone = true
		Events.report(&"pet_stone_ready", {pet = id, level = level})


func enter_room(at: Vector3) -> void:
	position = at
	rotation.y = randf() * TAU
	_mood_for = 0.0
	_petted_for = 0.0
	_touching.clear()
	set_process(true)


func leave_room() -> void:
	_stand()
	act = Act.IDLE
	_hand = &""
	_delivery_at = Vector3.INF
	_path.clear()
	_retry_route_at = 0.0
	stone.collision_layer = 0
	set_process(false)


func is_grounded() -> bool:
	return act not in [Act.JUMP_UP, Act.ON_HAND, Act.JUMP_DOWN]


func approach_hand(side: StringName, palm: Vector3, takeoff: Vector3) -> void:
	_stand()
	act = Act.COME
	_mood = Act.IDLE
	_mood_for = 0.0
	_path.clear()
	_retry_route_at = 0.0
	_hand = side
	_planned_palm = palm
	_takeoff = takeoff
	follow_hand(palm, true)


func follow_hand(palm: Vector3, steady: bool) -> void:
	_palm = palm
	_palm_ready = steady


func release_hand() -> void:
	_hand = &""
	_touching.clear()
	if act == Act.COME:
		act = Act.IDLE
		_path.clear()
		return
	var preferred: Vector3 = _home.hop_floor(position)
	_jump_to = _home.floor_near(preferred if preferred.is_finite() else _takeoff, self)
	if not _jump_to.is_finite(): _jump_to = _home.free_spot()
	_begin_jump(Act.JUMP_DOWN)


func can_give(side: StringName) -> bool:
	return has_stone and side != _hand and act not in [Act.JUMP_UP, Act.JUMP_DOWN]


## The child takes the stone from its mouth.
func give() -> void:
	has_stone = false
	_delivery_at = Vector3.INF
	_petted_for = 1.2
	App.module(&"Inventory").add(&"magic_stone")
	Events.play(&"stone", stone.global_position)
	Events.feedback.emit(&"good", stone.global_position)
	Events.report(&"pet_stone_taken", {pet = id, level = level})
	Events.say("A magic stone from your pet!")


func petted() -> void:
	_petted_for = 1.2
	if _since_pet < PET_GAP: return
	_since_pet = 0.0
	pets += 1
	Events.feedback.emit(&"good", global_position + Vector3.UP * BODY * 2.0)
	if level < MAX_LEVEL and pets_needed() == 0:
		level += 1
		pets = 0
		Events.say("Your pet likes you more. It will find magic stones faster.")
	Events.report(&"pet_petted", {pet = id, level = level, pets = pets, minutes = minutes()})


## Resting, or on its way to rest, on the cushion at [param spot].
func rests_at(spot: Vector3) -> bool:
	return _mood == Act.REST and _spot == spot


func to_save() -> Dictionary:
	return {level = level, pets = pets, progress = progress, stone = has_stone}


func _process(delta: float) -> void:
	_clock += delta
	_since_pet += delta
	_petted_for -= delta
	stone.visible = has_stone
	stone.collision_layer = Pointer.MENU_LAYER if has_stone and act not in [Act.JUMP_UP, Act.JUMP_DOWN] else 0
	match act:
		Act.COME:
			_approach(delta)
			return
		Act.JUMP_UP, Act.JUMP_DOWN:
			_jump(delta)
			return
		Act.ON_HAND:
			_on_hand()
			_feel_hands()
			return
	_feel_hands()
	if not has_stone:
		_mood_for -= delta
		if _mood_for <= 0.0: _new_mood()
	var next := _choose()
	if next != act:
		if act == Act.REST: _stand()
		act = next
		_path.clear()
	match act:
		Act.PETTED: _play(&"gesture-positive")
		Act.DELIVER: _deliver(delta)
		Act.REST: _rest(delta)
		Act.WANDER:
			if _walk(_spot, delta): _mood_for = 0.0
		Act.IDLE: _play(&"idle")


## The behaviours in priority order.
func _choose() -> Act:
	if _petted_for > 0.0: return Act.PETTED
	if has_stone: return Act.DELIVER
	return _mood


func _new_mood() -> void:
	var roll := randf()
	var cushion: Variant = _home.free_cushion(self) if roll < 0.4 else null
	if cushion != null:
		_mood = Act.REST
		_spot = cushion
		_mood_for = randf_range(20.0, 40.0)
	elif roll < 0.8:
		_mood = Act.WANDER
		_spot = _home.free_spot()
		_mood_for = 30.0
	else:
		_mood = Act.IDLE
		_mood_for = randf_range(3.0, 7.0)
	_path.clear()


## Only the free hand pets a pet on the palm.
func _feel_hands(respond := true) -> void:
	var ratio := _model.scale.x / SIZE
	for side: StringName in [&"left", &"right"]:
		var pointer := App.rig.pointer(side)
		var inside := side != _hand and pointer.tracked() \
			and pointer.tip().distance_to(global_position + Vector3.UP * BODY * ratio) < PET_RADIUS * ratio
		if respond and inside and not _touching.get(side, false): petted()
		_touching[side] = inside


func _deliver(delta: float) -> void:
	if not _delivery_at.is_finite():
		_delivery_at = _home.delivery_floor(self)
	if _delivery_at.is_finite() and _walk(_delivery_at, delta, COME_SPEED):
		_face_player()
		_play(&"idle")


func _approach(delta: float) -> void:
	if _planned_palm.slide(Vector3.UP).distance_to(_palm.slide(Vector3.UP)) > 0.11:
		_planned_palm = _palm
		_takeoff = _home.hop_floor(_palm)
	if not _takeoff.is_finite():
		_play(&"idle")
		return
	if not _walk(_takeoff, delta, COME_SPEED): return
	_face(_palm - position)
	_play(&"idle")
	if not _palm_ready: return
	if _home.can_hop(position, _palm):
		_begin_jump(Act.JUMP_UP)
	else:
		_planned_palm = _palm
		_takeoff = _home.hop_floor(_palm)


func _begin_jump(direction: Act) -> void:
	act = direction
	_jump_from = position
	_jump_for = 0.0
	_jump_size = _model.scale.x
	_play(&"idle")
	Events.play(&"hop", global_position)


func _jump(delta: float) -> void:
	var up := act == Act.JUMP_UP
	_jump_for += delta
	var t := minf(1.0, _jump_for / (JUMP_UP_SECONDS if up else JUMP_DOWN_SECONDS))
	var to := _palm if up else _jump_to
	var lift := 0.16 if up else 0.09
	position = _jump_from.lerp(to, t * (2.0 - t) if up else smoothstep(0.0, 1.0, t)) + Vector3.UP * sin(t * PI) * lift
	_resize(lerpf(_jump_size, HAND_SIZE if up else SIZE, smoothstep(0.12, 0.95, t)))
	if up: _face_player()
	else: _face(_jump_to - _jump_from)
	if t < 1.0: return
	position = to
	act = Act.ON_HAND if up else Act.IDLE
	if up: _feel_hands(false)
	else: _mood_for = 0.0


func _on_hand() -> void:
	position = _palm
	_face_player()
	_play(&"gesture-positive" if _petted_for > 0.0 else &"idle")


func _face_player() -> void:
	_face((get_parent() as Node3D).to_local(App.head().global_position) - position)


func _resize(size: float) -> void:
	var ratio := size / SIZE
	_model.scale = Vector3.ONE * size
	stone.position = STONE_OFFSET * ratio
	stone.scale = Vector3.ONE * maxf(0.60, ratio)


func _rest(delta: float) -> void:
	if not _home.cushions().has(_spot):
		_mood_for = 0.0   # the cushion was moved or put away
		return
	if not _walk(_spot, delta): return
	# Lying down: legs tucked into the cushion, slow breathing.
	_play(&"static")
	position.y = 0.08
	_model.position.y = -0.3 * SIZE
	_model.scale.y = SIZE * (1.0 + 0.03 * sin(_clock * 2.0))


func _stand() -> void:
	position.y = 0.0
	if _model:
		_model.position.y = 0.0
		_resize(SIZE)


## Walks toward [param to] around the furniture. True once there.
func _walk(to: Vector3, delta: float, speed := SPEED) -> bool:
	if Vector2(position.x - to.x, position.z - to.z).length() < 0.001: return true
	if _path.is_empty() or not _path[-1].is_equal_approx(to):
		if _clock < _retry_route_at: return false
		_path = _home.route(position, to)
		if _path.is_empty():
			_retry_route_at = _clock + 0.2
			_play(&"idle")
			return false
	var step := speed * delta
	while not _path.is_empty() and position.distance_to(_path[0]) <= step:
		step -= position.distance_to(_path[0])
		position = _path[0]
		_path.remove_at(0)
	if _path.is_empty(): return true
	var way := _path[0] - position
	position += way.normalized() * step
	_face(way)
	_play(&"walk", speed / SPEED)
	return false


func _face(way: Vector3) -> void:
	way.y = 0.0
	if way.length() > 0.001:
		basis = Basis.looking_at(way, Vector3.UP, true)


func _play(clip: StringName, speed := 1.0) -> void:
	_anim.speed_scale = speed
	if _anim.current_animation != clip:
		_anim.play(clip, 0.15)
