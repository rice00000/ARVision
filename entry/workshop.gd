class_name Workshop
extends Node3D
## What the opening leaves standing when it hands over to the next scene: Onion, the
## cauldron and the installed mechanism. It lives under Main, which keeps what is added to it across scene switches
## (the scene itself and everything on the stage are freed). It survives exactly one switch,
## the handoff; when the child leaves that scene too, the workshop goes with it.
##
## In Find the object, Onion becomes the body of the World's "this way" guide and waits
## beside the shelf in between. The piano fades out instead of cutting off.

## Seconds the piano takes to fade out after the handoff.
const MUSIC_FADE := 3.0

var _onion: Node3D            # Onion's holder: moves around
var _model: Node3D            # the wisp model, turned to face the child; it bobs
var _face := Vector3.FORWARD  # which way its eyes look, in the holder's space
var _model_rest_y := 0.0
var _glow: OmniLight3D
var _halo: StandardMaterial3D
var _rest := Vector3.ZERO     # where Onion waits beside the shelf
var _guide: Guide
var _guiding := false
var _clock := 0.0
var _talk_until := 0.0
var _switches := 0
var _attention: Variant = null   # a Node3D or a position to look at instead of the child
var _cheer_until := 0.0


## Takes over from the opening. [param parts]: onion (holder), model, face, rest_y, glow, halo,
## cauldron, rest (where Onion waits), music (or null). Call after adding this to Main.
func take(parts: Dictionary) -> void:
	name = "Workshop"
	_onion = parts.onion
	_model = parts.model
	_face = parts.face
	_model_rest_y = parts.rest_y
	_glow = parts.glow
	_halo = parts.halo
	_rest = parts.rest
	_onion.reparent(self)
	(parts.cauldron as Node3D).reparent(self)
	for key in ["mechanism", "gear"]:   # the installed mechanism stays, turning
		var part: Node3D = parts.get(key)
		if part != null and is_instance_valid(part):
			part.reparent(self)
	var music: AudioStreamPlayer = parts.get("music")
	if music != null and is_instance_valid(music):
		music.reparent(self)
		var fade := create_tween()
		fade.tween_property(music, "volume_db", -60.0, MUSIC_FADE)
		fade.tween_callback(music.queue_free)
	create_tween().tween_property(_onion, "global_position", _rest, 1.2).set_trans(Tween.TRANS_SINE)
	Events.said.connect(func(text: String) -> void: _talk_until = _clock + maxf(1.5, text.length() * 0.065))
	Events.scene_changing.connect(_on_scene_changing)
	Events.reported.connect(_on_reported)


## Onion looks at [param what] (a Node3D or a position) instead of the child; null: back to the child.
func attend(what: Variant) -> void:
	_attention = what


## A small satisfied bob.
func cheer() -> void:
	_cheer_until = _clock + 1.2


func _on_scene_changing() -> void:
	_switches += 1
	if _switches > 1:
		queue_free()   # the child left the scene after the handoff


func _on_reported(what: StringName, data: Dictionary) -> void:
	if what != &"scene_changed":
		return
	var scene: StringName = data.get("to", &"")
	if scene == &"find_object":
		_become_guide()
	elif scene != &"first_visit":
		queue_free()


## Onion replaces the orb of the World's "this way" guide (its arrow stays).
func _become_guide() -> void:
	if App.world == null:
		return
	for child in App.world.get_children():
		if child is Guide:
			_guide = child
			_guide.body = _onion
	print("WORKSHOP Onion is the guide: ", _guide != null)


func _process(delta: float) -> void:
	_clock += delta
	if App.rig == null or _onion == null:
		return
	if is_instance_valid(_guide):
		if _guiding and not _guide.visible:   # the child found the place: back beside the shelf
			create_tween().tween_property(_onion, "global_position", _rest, 1.2).set_trans(Tween.TRANS_SINE)
		_guiding = _guide.visible
	var talking := _clock < _talk_until
	var bob := sin(_clock * 7.0) * 0.006 if talking else sin(_clock * 1.5) * 0.002
	if _clock < _cheer_until:
		bob += sin((_cheer_until - _clock) / 1.2 * PI * 2.0) * 0.012
	_model.position.y = lerpf(_model.position.y, _model_rest_y + bob, minf(1.0, delta * 10.0))
	_halo.albedo_color.a = 0.3 if talking else 0.22
	_glow.light_energy = 0.6 + (0.35 * (0.5 + 0.5 * sin(_clock * 9.0)) if talking else 0.0)
	var look_at: Vector3 = App.head().global_position
	if _attention is Node3D and is_instance_valid(_attention):
		look_at = (_attention as Node3D).global_position
	elif _attention is Vector3:
		look_at = _attention
	var to_child := look_at - _onion.global_position
	to_child.y = 0.0
	if to_child.length() < 0.01:
		return
	_onion.global_rotation.y = -(atan2(_face.x, _face.z) - atan2(to_child.x, to_child.z))
