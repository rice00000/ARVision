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
var _cauldron: Node3D
var _attention: Variant = null   # a Node3D or a position to look at instead of the child
var _cheer_until := 0.0
var _gear: Node3D
var _mechanism: Node3D
var _mouth := Vector3.ZERO
var _sounds: Sounds
var _tilt := 0.0
## The opening's zone map (EntryLayout), for the motion route's layout (EntryMotionLayout); may be null.
var layout: EntryLayout


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
	_cauldron = parts.cauldron as Node3D
	_cauldron.reparent(self)
	for key in ["mechanism", "gear"]:   # the installed mechanism stays, turning
		var part: Node3D = parts.get(key)
		if part != null and is_instance_valid(part):
			part.reparent(self)
	_gear = parts.get("gear")
	_mechanism = parts.get("mechanism")
	_mouth = parts.get("mouth", _cauldron.global_position)
	layout = parts.get("layout")
	var sounds: Sounds = parts.get("sounds")
	if sounds != null and is_instance_valid(sounds):
		sounds.reparent(self)   # the closing's clunk and rattle
		_sounds = sounds
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


## Onion floats to [param where] over [param seconds].
func float_to(where: Vector3, seconds := 1.0) -> void:
	create_tween().tween_property(_onion, "global_position", where, seconds).set_trans(Tween.TRANS_SINE)


## Where Onion is now.
func onion_position() -> Vector3:
	return _onion.global_position


# --- The closing (story chat: approved motion ending and closing) ------------------------

## The gears slow to a stop over [param seconds].
func slow_gears(seconds := 1.5) -> void:
	var spins: Array = []
	for part in [_gear, _mechanism]:
		if part != null and is_instance_valid(part):
			spins.append_array(part.find_children("*", "GearSpin", true, false))
	var tween := create_tween().set_parallel(true)
	for spin: GearSpin in spins:
		tween.tween_property(spin, "rate", 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	for spin: GearSpin in spins:
		spin.running = false


## The cauldron (sunk away at the reveal) comes back up where it stood.
func cauldron_back(seconds := 0.7) -> void:
	_cauldron.visible = true
	var tween := create_tween()
	tween.tween_property(_cauldron, "scale", Vector3.ONE, seconds).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished


## The gear lifts out of its socket, floats over and drops into the cauldron, with a soft clunk.
func gear_home() -> void:
	if _gear == null or not is_instance_valid(_gear):
		return
	var start := _gear.global_position
	var over := _mouth + Vector3.UP * 0.12
	var tween := create_tween()
	tween.tween_property(_gear, "global_position", start + Vector3.UP * 0.06, 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_gear, "global_position", over, 1.0).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_gear, "global_position", _mouth + Vector3.DOWN * 0.04, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		_gear.visible = false
		if _sounds != null:
			_sounds.play(&"knock", _mouth))   # the soft clunk as it lands
	await tween.finished


## A small rattle from the cauldron.
func rattle() -> void:
	if _sounds != null:
		_sounds.play(&"rattle_soft", _cauldron.global_position)
	var tween := create_tween()
	for i in 6:
		tween.tween_property(_cauldron, "rotation:z", 0.03 if i % 2 == 0 else -0.03, 0.06)
	tween.tween_property(_cauldron, "rotation:z", 0.0, 0.08)
	await tween.finished


## A sheepish sideways tilt of Onion's body ([param on]), or straight again.
func tilt(on: bool) -> void:
	create_tween().tween_property(self, "_tilt", 0.28 if on else 0.0, 0.35).set_trans(Tween.TRANS_SINE)


## A gentle goodbye bob, then Onion ducks into the cauldron and is gone.
func goodbye() -> void:
	cheer()
	await get_tree().create_timer(1.2, false).timeout
	attend(null)
	var tween := create_tween()
	tween.tween_property(_onion, "global_position", _mouth + Vector3.UP * 0.06, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_onion, "global_position", _mouth + Vector3.DOWN * 0.12, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _onion.visible = false)
	await tween.finished


## Where the cauldron's mouth is.
func mouth() -> Vector3:
	return _mouth


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
	elif scene == &"first_visit":
		_cauldron.visible = false   # the object test is what to look at now: the cauldron would distract
	else:
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
	_model.rotation.z = lerpf(_model.rotation.z, _tilt, minf(1.0, delta * 8.0))   # the sheepish tilt
