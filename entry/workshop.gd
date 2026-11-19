class_name Workshop
extends Node3D
## What the opening leaves standing when it hands over to the next scene: Onion, the
## cauldron and the installed mechanism. It lives under Main, which keeps what is added to it across scene switches
## (the scene itself and everything on the stage are freed). It survives exactly one switch,
## the handoff; when the child leaves that scene too, the workshop goes with it.
##
## In Find the object, Onion becomes the body of the World's "this way" guide and waits
## beside the shelf in between.
## The opening's piano fades out over this long once the workshop takes over.
const MUSIC_FADE := 3.0

## Onion, the guide.
var onion: Onion
var _rest := Vector3.ZERO     # where Onion waits beside the shelf
var _guide: Guide
var _guiding := false
var _switches := 0
var _cauldron: Node3D
var _gear: Node3D
var _mechanism: Node3D
var _mouth := Vector3.ZERO
var _sounds: Sounds
## The opening's zone map (EntryLayout), for the motion route's layout (EntryMotionLayout); may be null.
var layout: EntryLayout


## Takes over from the opening. [param parts]: onion, cauldron, rest (where Onion waits),
## mechanism, gear, mouth, sounds, layout. Call after adding this to Main.
func take(parts: Dictionary) -> void:
	add_to_group(&"activity_scenery")
	name = "Workshop"
	onion = parts.onion
	onion.touch.minimum_y = -INF
	_rest = parts.rest
	onion.reparent(self)
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
	_glide(_rest, 1.2)
	Events.scene_changing.connect(_on_scene_changing)
	Events.reported.connect(_on_reported)


## Onion looks at [param what] (a Node3D or a position) instead of the child; null: back to the child.
func attend(what: Variant) -> void:
	onion.attend(what)


## Onion floats to [param where] over [param seconds].
func float_to(where: Vector3, seconds := 1.0) -> void:
	_glide(where, seconds)


## One glide at a time (Megan, Nov 18: Onion "glitched" at "Welcome to the workshop.": the take-over glide and
## the hub's glide ran together, and Onion snapped 55 cm when one ended). A new glide replaces the last.
var _gliding: Tween
func _glide(where: Vector3, seconds: float) -> void:
	if _gliding != null and _gliding.is_valid():
		_gliding.kill()
	_gliding = create_tween()
	_gliding.tween_property(onion, "global_position", where, seconds).set_trans(Tween.TRANS_SINE)


## Where Onion is now.
func onion_position() -> Vector3:
	return onion.global_position


# --- The closing (story chat: approved motion ending and closing) ------------------------

## The gears slow to a stop over [param seconds].
func slow_gears(seconds := 1.5) -> void:
	var spins: Array = []
	for part in [_gear, _mechanism]:
		if part != null and is_instance_valid(part):
			spins.append_array(part.find_children("*", "GearSpin", true, false))
	if _slowing != null and _slowing.is_valid():
		_slowing.kill()
	var tween := create_tween().set_parallel(true)
	_slowing = tween
	for spin: GearSpin in spins:
		tween.tween_property(spin, "rate", 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tween.finished
	if _slowing != tween:
		return   # woken again meanwhile (the gear was set back)
	for spin: GearSpin in spins:
		spin.running = false


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
			_sounds.play(&"knock", _mouth)   # the soft clunk as it lands
		PlaceSignal.play(self, _mouth, Vector3.UP, 0.08, false))   # Scene 10: "found its place" as it goes home
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
	create_tween().tween_property(onion, "tilt", 0.28 if on else 0.0, 0.35).set_trans(Tween.TRANS_SINE)


## A gentle goodbye bob, then Onion ducks into the cauldron and is gone.
func goodbye() -> void:
	cheer()
	await get_tree().create_timer(1.2, false).timeout
	attend(null)
	var tween := create_tween()
	tween.tween_property(onion, "global_position", _mouth + Vector3.UP * 0.06, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(onion, "global_position", _mouth + Vector3.DOWN * 0.12, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		Events.play(&"vanish", _mouth)
		onion.visible = false)
	await tween.finished


# --- Restart after the goodbye (Megan, Nov 18): the closing played backwards -------------------------------

## The socket rises out of the table again (after [method fade_socket]).
func socket_back(seconds := 0.6) -> void:
	if not is_instance_valid(_mechanism):
		return
	_mechanism.remove_meta(&"faded_for_good")
	var shown: Vector3 = _mechanism.get_meta(&"scale_shown", Vector3.ONE)
	_mechanism.visible = true
	var tween := create_tween()
	tween.tween_property(_mechanism, "scale", shown, seconds).set_trans(Tween.TRANS_SINE)
	await tween.finished


## Onion pops back up out of the cauldron to [param spot] (after [method goodbye]).
func onion_back(spot: Vector3) -> void:
	onion.global_position = _mouth + Vector3.DOWN * 0.08
	onion.visible = true
	Events.play(&"vanish", _mouth)
	var tween := create_tween()
	tween.tween_property(onion, "global_position", _mouth + Vector3.UP * 0.12, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(onion, "global_position", spot, 0.8).set_trans(Tween.TRANS_SINE)
	await tween.finished


## The gear pops out of the cauldron and lands on the table at [param on_table] (after [method gear_home]).
func gear_out(on_table: Vector3) -> void:
	if _gear == null or not is_instance_valid(_gear):
		return
	if _sounds != null:
		_sounds.play(&"device_rattle", _mouth)
	_gear.global_position = _mouth + Vector3.DOWN * 0.03
	_gear.visible = true
	var over := _mouth.lerp(on_table, 0.5) + Vector3.UP * 0.14
	var tween := create_tween()
	tween.tween_property(_gear, "global_position", over, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_gear, "global_position", on_table, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void:
		if _sounds != null:
			_sounds.play(&"gear_land", on_table))
	await tween.finished


var _slowing: Tween


## The gears turn again (after [method slow_gears]).
func start_gears() -> void:
	if _slowing != null and _slowing.is_valid():
		_slowing.kill()
	_slowing = null
	for part in [_gear, _mechanism]:
		if part != null and is_instance_valid(part):
			for spin: GearSpin in part.find_children("*", "GearSpin", true, false):
				spin.rate = 1.0
				spin.running = true


## The socket's world position (its seat), or the mouth without one.
func socket_at() -> Vector3:
	return _mechanism.global_position if is_instance_valid(_mechanism) else _mouth


## The cauldron (the hub's centre).
func cauldron() -> Node3D:
	return _cauldron


## The seated gear (the child's menu sits on it), or null.
func gear_node() -> Node3D:
	return _gear if is_instance_valid(_gear) else null


## The closing's end (Scene 10): the empty socket fades into the table as Onion ducks in.
func fade_socket(seconds := 1.2) -> void:
	if not is_instance_valid(_mechanism):
		return
	if not _mechanism.has_meta(&"scale_shown"):
		_mechanism.set_meta(&"scale_shown", _mechanism.scale)   # a restart brings it back at this size
	var shown: Vector3 = _mechanism.get_meta(&"scale_shown")
	var tween := create_tween()
	tween.tween_property(_mechanism, "scale", Vector3(shown.x, shown.y * 0.02, shown.z), seconds).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: _mechanism.visible = false)
	_mechanism.set_meta(&"faded_for_good", true)


## The socket and the gear in it fade under Wei's bench board while the shelf game stands over them
## (Megan, Nov 17 late: the socket sits at the near edge, right of middle, where the bench board goes), and
## come back after. [param hidden]: true to hide.
func hide_socket(hidden: bool, seconds := 0.4) -> void:
	for part: Node3D in [_mechanism, _gear]:
		if not is_instance_valid(part) or part.get_meta(&"faded_for_good", false):
			continue
		if not part.has_meta(&"scale_shown"):
			part.set_meta(&"scale_shown", part.scale)
		var shown: Vector3 = part.get_meta(&"scale_shown")
		if not hidden:
			part.visible = true
		var tween := create_tween()
		tween.tween_property(part, "scale", Vector3(shown.x, shown.y * 0.02, shown.z) if hidden else shown, seconds).set_trans(Tween.TRANS_SINE)
		if hidden:
			tween.tween_callback(func() -> void: part.visible = false)


## The cauldron glides along the table by [param offset] (its brew with it), out of a game board's way and back.
func slide_cauldron(offset: Vector3, seconds := 0.6) -> Tween:
	_mouth += offset
	var tween := create_tween()
	tween.tween_property(_cauldron, "global_position", _cauldron.global_position + offset, seconds).set_trans(Tween.TRANS_SINE)
	return tween


## Where the cauldron's mouth is.
func mouth() -> Vector3:
	return _mouth


## A small satisfied bob.
func cheer() -> void:
	onion.cheer()


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
		_cauldron.visible = true   # the hub: the cauldron stays for the whole visit (Nov 17)
	else:
		queue_free()


## Onion replaces the orb of the World's "this way" guide (its arrow stays).
func _become_guide() -> void:
	if App.world == null:
		return
	for child in App.world.get_children():
		if child is Guide:
			_guide = child
			_guide.body = onion
	print("WORKSHOP Onion is the guide: ", _guide != null)


func _process(_delta: float) -> void:
	if not is_instance_valid(_guide):
		return
	if _guiding and not _guide.visible:   # the child found the place: back beside the shelf
		_glide(_rest, 1.2)
	_guiding = _guide.visible
