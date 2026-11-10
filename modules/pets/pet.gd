class_name Pet
extends Node3D
## One pet. It earns a magic stone per [method minutes] of training and carries
## it to the child in the room. Petting it raises its level, which shortens that.
##
## In the room, every tick the first behaviour that wants to act wins
## ([method _choose]): a new behaviour is one more line there, never a new
## transition between two others.

enum Act {PETTED, DELIVER, COME, REST, WANDER, IDLE}

const MAX_LEVEL := 5
## A pet counts toward the next level only this long after the last one that did.
const PET_GAP := 60.0
const SIZE := 0.2
const SPEED := 0.45
## The body's centre above the feet, and how near a fingertip pets it.
const BODY := 0.17
const PET_RADIUS := 0.17
const STAY := 12.0

var id: StringName
var level := 0
## Pets counted toward the next level.
var pets := 0
## Training seconds toward the next stone.
var progress := 0.0
## A stone is waiting in its mouth.
var has_stone := false
var act := Act.IDLE
var perched := false
var stone := Target.sphere(&"pet_stone", 0.08)

var _home: Node
var _model: Node3D
var _anim: AnimationPlayer
var _since_pet := PET_GAP
var _petted_for := 0.0
var _called_for := 0.0
var _mood := Act.IDLE
var _mood_for := 0.0
var _spot := Vector3.ZERO
var _path := PackedVector3Array()
var _hop: Tween
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
	stone.position = Vector3(0, 0.155, 0.2)
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
	_called_for = 0.0
	_petted_for = 0.0
	_touching.clear()
	set_process(true)


func leave_room() -> void:
	_stand()
	perched = false
	act = Act.IDLE
	stone.collision_layer = 0
	set_process(false)


func call_over() -> void:
	_called_for = STAY


## The child takes the stone from its mouth.
func give() -> void:
	has_stone = false
	_called_for = STAY * 0.5
	_petted_for = 1.2
	App.module(&"Inventory").add(&"magic_stone")
	Events.feedback.emit(&"good", stone.global_position)
	Events.report(&"pet_stone_taken", {pet = id, level = level})
	Events.say("A magic stone from your pet!")


func petted() -> void:
	_petted_for = 1.2
	if perched: _called_for = maxf(_called_for, STAY * 0.5)
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
	_called_for -= delta
	_mood_for -= delta
	stone.visible = has_stone
	stone.collision_layer = Pointer.MENU_LAYER if has_stone else 0
	_feel_hands()
	if _hop and _hop.is_running(): return
	if _mood_for <= 0.0: _new_mood()
	var next := _choose()
	if next != act:
		if act == Act.REST: _stand()
		act = next
		_path.clear()
	if perched and act not in [Act.PETTED, Act.DELIVER, Act.COME]:
		_leave_stool()
		return
	match act:
		Act.PETTED: _play(&"gesture-positive")
		Act.DELIVER, Act.COME: _come(delta)
		Act.REST: _rest(delta)
		Act.WANDER:
			if _walk(_spot, delta): _mood_for = 0.0
		Act.IDLE: _play(&"idle")


## The behaviours in priority order.
func _choose() -> Act:
	if _petted_for > 0.0: return Act.PETTED
	if has_stone: return Act.DELIVER
	if _called_for > 0.0: return Act.COME
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


## A fingertip coming into the body pets it.
func _feel_hands() -> void:
	for side: StringName in [&"left", &"right"]:
		var pointer := App.rig.pointer(side)
		var inside := pointer.tracked() and pointer.tip().distance_to(global_position + Vector3.UP * BODY) < PET_RADIUS
		if inside and not _touching.get(side, false): petted()
		_touching[side] = inside


## Onto the stool beside the child, or next to it when another pet has it.
func _come(delta: float) -> void:
	if perched:
		_face(_home.seat() - position)
		_play(&"idle")
	elif _home.claim_stool(self):
		if _walk(_home.stool_foot(), delta):
			perched = true
			_jump(_home.stool_top())
	elif _walk(_home.beside_stool(), delta):
		_face(_home.seat() - position)
		_play(&"idle")


func _leave_stool() -> void:
	perched = false
	_home.release_stool(self)
	_jump(_home.stool_foot())


func _jump(to: Vector3) -> void:
	_play(&"idle")
	_face(to - position)
	var from := position
	_hop = create_tween()
	_hop.tween_method(func(t: float) -> void:
		position = from.lerp(to, t) + Vector3.UP * sin(t * PI) * 0.15, 0.0, 1.0, 0.4)


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
		_model.scale = Vector3.ONE * SIZE


## Walks toward [param to] around the furniture. True once there.
func _walk(to: Vector3, delta: float) -> bool:
	if Vector2(position.x - to.x, position.z - to.z).length() < 0.001: return true
	if _path.is_empty() or not _path[-1].is_equal_approx(to):
		_path = _home.route(position, to)
	var step := SPEED * delta
	while not _path.is_empty() and position.distance_to(_path[0]) <= step:
		position = _path[0]
		_path.remove_at(0)
	if _path.is_empty(): return true
	var way := _path[0] - position
	position += way.normalized() * step
	_face(way)
	_play(&"walk")
	return false


func _face(way: Vector3) -> void:
	way.y = 0.0
	if way.length() > 0.001:
		basis = Basis.looking_at(way, Vector3.UP, true)


func _play(clip: StringName) -> void:
	if _anim.current_animation != clip:
		_anim.play(clip, 0.15)
