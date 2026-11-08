class_name OnionTouch
extends Target
## A reusable squash-and-spring touch reaction, using Godot's MIT-licensed Tween.
## Model scale only: story motion, facing and dialogue retain their own owners.
## No cooldown: every new touch (the finger left and came back) squashes again
## and sounds again, from Onion, so quick taps go "dang dang dang".

const RADIUS := 0.065
const REARM_DISTANCE := 0.11
## Designed for this touch; already about as soft as the pop (entry/assets/audio/README.md).
const SOUND := preload("res://entry/assets/audio/onion-touch.ogg")
## Touch sound loudness, dB. Mix here.
const SOUND_DB := 6.0
var reactions := 0
var minimum_y := -INF
var _model: Node3D
var _rest := Vector3.ONE
var _inside: Dictionary[StringName, bool] = {}
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
	_sound.stream = SOUND
	_sound.volume_db = SOUND_DB
	_sound.max_db = SOUND_DB # the 3D player caps at +3 dB by default
	_sound.max_polyphony = 4 # quick taps overlap instead of cutting each other off
	_sound.max_distance = 3.0
	add_child(_sound)
	Events.touched.connect(_touch)


func _touch(hand: StringName, target: Target) -> void:
	if target != self or get_tree().paused or not is_visible_in_tree() or _inside.get(hand, false): return
	_inside[hand] = true
	reactions += 1
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(_model, ^"scale", _rest * Vector3(1.20, 0.72, 1.20), 0.09).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_model, ^"scale", _rest, 0.65).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_sound.play()
	Events.report(&"onion_touched", {hand = hand})


func _process(delta: float) -> void:
	collision_layer = Pointer.REACTION_LAYER if global_position.y > minimum_y and is_visible_in_tree() else 0
	for hand: StringName in _inside:
		var pointer := App.rig.pointer(hand)
		if not pointer.tracked() or pointer.tip().distance_to(global_position) > REARM_DISTANCE:
			_inside[hand] = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _model:
		if _tween: _tween.kill()
		_model.scale = _rest
