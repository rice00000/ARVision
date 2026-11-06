class_name OnionTouch
extends Target
## A reusable squash-and-spring touch reaction, using Godot's MIT-licensed Tween.
## Model scale only: story motion, facing and dialogue retain their own owners.

const RADIUS := 0.065
const REARM_DISTANCE := 0.11
var reactions := 0
var minimum_y := -INF
var _model: Node3D
var _rest := Vector3.ONE
var _inside: Dictionary[StringName, bool] = {}
var _cooldown := 0.0
var _tween: Tween
var _sound := AudioStreamPlayer3D.new()


func setup(model: Node3D) -> void:
	_model = model
	_rest = model.scale


func _ready() -> void:
	id = &"onion_touch"
	name = "OnionTouch"
	collision_layer = Pointer.REACTION_LAYER
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	(shape.shape as SphereShape3D).radius = RADIUS
	add_child(shape)
	_sound.stream = _duang()
	_sound.volume_db = -16.0
	_sound.max_distance = 3.0
	add_child(_sound)
	Events.touched.connect(_touch)


func _touch(hand: StringName, target: Target) -> void:
	if target != self or get_tree().paused or not is_visible_in_tree() or _cooldown > 0 or _inside.get(hand, false): return
	_inside[hand] = true
	_cooldown = 0.8
	reactions += 1
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(_model, ^"scale", _rest * Vector3(1.20, 0.72, 1.20), 0.09).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_model, ^"scale", _rest, 0.65).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_sound.play()
	Events.report(&"onion_touched", {hand = hand})


func _process(delta: float) -> void:
	collision_layer = Pointer.REACTION_LAYER if global_position.y > minimum_y and is_visible_in_tree() else 0
	_cooldown = maxf(0, _cooldown - delta)
	for hand: StringName in _inside:
		var pointer := App.rig.pointer(hand)
		if not pointer.tracked() or pointer.tip().distance_to(global_position) > REARM_DISTANCE:
			_inside[hand] = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _model:
		if _tween: _tween.kill()
		_model.scale = _rest


static func _duang() -> AudioStreamWAV:
	var rate := 22050
	var samples := PackedByteArray()
	samples.resize(int(rate * 0.45) * 2)
	for i in samples.size() / 2:
		var t := float(i) / rate
		var envelope := (1.0 - exp(-t * 90.0)) * exp(-t * 10.0)
		var tone := sin(TAU * (230.0 * t + 14.0 * (1.0 - exp(-t * 12.0))))
		samples.encode_s16(i * 2, int(tone * envelope * 18000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = samples
	return stream
