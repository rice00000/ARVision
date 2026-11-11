class_name OnionTouch
extends Node3D
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
var _last_tip: Dictionary[StringName, Vector3] = {}
var _tween: Tween
var _sound := AudioStreamPlayer3D.new()


func setup(model: Node3D) -> void:
	_model = model
	_rest = model.scale


func _ready() -> void:
	name = "OnionTouch"
	_sound.stream = SOUND
	_sound.volume_db = SOUND_DB
	_sound.max_db = SOUND_DB # the 3D player caps at +3 dB by default
	_sound.max_polyphony = 4 # quick taps overlap instead of cutting each other off
	_sound.max_distance = 3.0
	add_child(_sound)


func _react(hand: StringName) -> void:
	_inside[hand] = true
	reactions += 1
	if _tween: _tween.kill()
	_tween = create_tween()
	_tween.tween_property(_model, ^"scale", _rest * Vector3(1.20, 0.72, 1.20), 0.09).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_model, ^"scale", _rest, 0.65).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_sound.play()
	Events.report(&"onion_touched", {hand = hand})


## My room pauses physics, so sample tracked fingertips even there. The opening's Onion
## inherits the activity's pause, and the room's Onion inherits the running room intro.
func _physics_process(_delta: float) -> void:
	var centre := global_position
	var enabled := centre.y > minimum_y and is_visible_in_tree()
	var reach := RADIUS * global_basis.get_scale().x + Pointer.TIP_RADIUS
	for hand: StringName in [&"left", &"right"]:
		var pointer := App.rig.pointer(hand)
		if not pointer.tracked():
			_last_tip.erase(hand)
			_inside.erase(hand)
			continue
		var tip := pointer.tip()
		var previous: Vector3 = _last_tip.get(hand, tip)
		_last_tip[hand] = tip
		var distance := tip.distance_to(centre)
		if distance > REARM_DISTANCE:
			_inside.erase(hand)
		elif enabled and not _inside.has(hand) and not pointer.resting() and distance <= reach and previous.distance_to(centre) > reach:
			_react(hand)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED and _model:
		_last_tip.clear()
		if _tween: _tween.kill()
		_model.scale = _rest
