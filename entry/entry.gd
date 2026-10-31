class_name Entry
extends Node3D
## Entry: "Something Was Left Here" (story: claude/BUILD_STATE.md, story chat).
## A node in main.tscn before World: plays when there is no session plan, then
## starts the World. Beats are written in this file.
## Every spoken line is a literal inside say("..."), so Wei's speech baker finds it
## (content/voice/speech.tts lists "entry" in say_sources).

## Seconds between lines.
const PAUSE := 3.0
## Play when the app starts without a session plan. Tests switch it off and call [method run].
@export var autostart := true

## The cauldron (story chat's asset, CC0) and how wide it should be on the table, metres.
const CAULDRON := preload("res://entry/assets/cauldron-cream-sage.glb")
const CAULDRON_WIDTH := 0.22
## The guide: "Onion the Wisp" by Edvin Borkovskij, CC BY 4.0 (credit in entry/assets/CREDITS.md).
const ONION := preload("res://entry/assets/onion_the_wisp.glb")
## How tall Onion is, metres.
const ONION_HEIGHT := 0.11
## Quiet piano under the opening (CC0, see entry/assets/CREDITS.md).
const MUSIC := preload("res://entry/assets/calm-piano-1.mp3")
## Music volume, decibels: well under the voice.
const MUSIC_DB := -20.0

var _table: Surface
var _box := Node3D.new()            # the cauldron on the table (named _box from v0)
var _rim := 0.15                    # height of the cauldron's rim above the table, metres (measured)
var _music := AudioStreamPlayer.new()
var _orb := MeshInstance3D.new()    # the guide: holds Onion and its glow (named _orb from v0)
var _onion: Node3D                  # the wisp model, turned to face the child
var _face := Vector3.FORWARD        # which way Onion's eyes point, in its own space
var _found: Array[Node3D] = []      # the objects that tumble out
var _cabinet := Node3D.new()        # stand-in for the cabinet beside the chair
var _seal := MeshInstance3D.new()   # the sealed patch on the wall behind
var _beat_label := Label3D.new()    # DEBUG: which beat is playing, in view

## While > -1, the child is looking for the object with this index.
var _wanted := -1
## DEBUG: show the beat in the headset and in Output.
const DEBUG := true

## Sent when the child touches (or points at and pinches) the lid.
signal _lid_touched
## Sent when the child chooses to begin (the button over the box).
signal _begin_chosen
## Sent when the child picks one of the objects: its index.
signal _piece_picked(index: int)


func _ready() -> void:
	if autostart and App.session.plan == null:
		print("ENTRY 1: ready, pausing World")
		# Wei's World starts by itself unless told to wait (it is readied after this node).
		(get_node(^"../World") as World).autostart = false
		run.call_deferred()   # run the opening once everything is set up


## Plays the opening, then starts the World.
func run() -> void:
	Events.touched.connect(func(_hand: StringName, target: Target) -> void: _on_target(target))
	Events.selected.connect(func(_hand: StringName, target: Target, _o: Vector3, _d: Vector3) -> void: _on_target(target))
	Events.help_requested.connect(_on_help)
	# Wait until the headset has found the real table.
	if not App.reality.is_settled:
		await App.reality.settled
	_table = App.reality.work_surface()
	print("ENTRY 2: table found: ", _table != null)
	_build_box()
	_build_orb()
	_start_music()
	print("ENTRY 3: cauldron at ", _box.global_position, ", head at ", App.head().global_position)

	# Beat 1: a small invitation. The orb (stand-in for Onion) peeks over the rim, ducks, peeks again.
	_beat("1: the orb peeks out")
	await get_tree().create_timer(2.0).timeout   # nothing rushes the child
	await _peek()
	await say("Oh. You can see me?")
	await _duck()
	await get_tree().create_timer(1.0).timeout
	await _peek()
	await say("Good. I've been making rather a lot of noise.")

	# Beat 2: the child helps; the orb emerges and things float out of the cauldron.
	_beat("2: touch the cauldron")
	await say("Could you give me a hand? Touch the cauldron.")
	await _lid_touched
	await _open_lid()

	# Beat 3: the room shows another identity, still faded.
	_beat("3: the room reveals")
	_reveal_room()
	await say("There it is.")
	await say("I was beginning to think I'd found the wrong room.")

	# Beat 4: the orb explains, and one object rattles.
	_beat("4: workshop")
	await say("This is a workshop. Things come here when someone needs help with them.")
	await say("Usually with a note.")
	await say("Of course.")
	await _rattle(_found[1])
	await say("Well, that's somewhere to start.")

	# Beat 5: the first discovery. Unscored: it teaches pointing, pinching and help.
	_beat("5: find it again")
	await _show_off(_found[1])
	await say("Let's find that one again. You can take your time.")
	await say("Point at it and pinch. If you need help, raise your hand.")
	_wanted = 1
	while true:
		var picked: int = await _piece_picked
		if picked == 1:
			break
		await say("Not that one. Have another look.")
	_wanted = -1
	_orb_to(_box.global_position + Vector3.UP * (_rim + 0.15))

	# Beat 6: a fragment inside; colour comes back to the cabinet; a mark on the seal.
	_beat("6: the fragment")
	var fragment := await _unfold(_found[1])
	await say("Someone put that inside?")
	await _fly(fragment, _cabinet.global_position + Vector3.UP * 0.12)
	_tint(_cabinet, Color(0.85, 0.55, 0.25))
	await say("It belongs here.")
	_mark(_seal)
	await say("And apparently... there.")

	# Beat 7: the invitation. Then Wei's adventure.
	_beat("7: invitation")
	await say("We could look through the rest of the box. Or leave it here until you're ready.")
	# Nothing starts until the child chooses: a button over the box. Until then the
	# room stays as it is, to look around in.
	var begin_button := _button("Look through the box", _box.global_position + Vector3.UP * 0.4)
	_beat("7: waiting for 'Look through the box'")
	await _begin_chosen
	begin_button.queue_free()
	_beat("done: Wei's World")
	App.world.run()


## Speaks [param text] (baked audio + subtitle) and waits a moment.
func say(text: String) -> void:
	Events.say(text)
	await get_tree().create_timer(PAUSE).timeout


func _on_target(target: Target) -> void:
	if target == null:
		return
	if DEBUG:
		print("ENTRY touched/picked: ", target.id)
	if target.id == &"entry_cauldron":
		_lid_touched.emit()
	elif target.id == &"entry_begin":
		_begin_chosen.emit()
	elif String(target.id).begins_with("entry_piece_") and _wanted >= 0:
		_piece_picked.emit(int(String(target.id).trim_prefix("entry_piece_")))


## Help (hand raised): the orb floats over the wanted object. Logged by Wei's
## modules as help, like in his trials.
func _on_help() -> void:
	if _wanted >= 0:
		_orb_to(_found[_wanted].global_position + Vector3.UP * 0.12)
		Events.say("This one.")


## DEBUG: the beat name in Output and floating low in view.
func _beat(text: String) -> void:
	if not DEBUG:
		return
	print("ENTRY beat ", text)
	if _beat_label.get_parent() == null:
		_beat_label.font_size = 24
		_beat_label.pixel_size = 0.0006
		_beat_label.modulate = Color(1, 1, 1, 0.6)
		_beat_label.no_depth_test = true
		_beat_label.position = Vector3(0, -0.22, -0.6)
		App.rig.head.add_child(_beat_label)
	_beat_label.text = "beat " + text


func _build_box() -> void:
	add_child(_box)
	_box.global_position = _table.point(0, 0)   # centre of the table, on its top
	var cauldron: Node3D = CAULDRON.instantiate()
	_box.add_child(cauldron)
	# Scale it to CAULDRON_WIDTH and stand it on the table, whatever the model's own units.
	var bounds := _bounds(cauldron)
	var fit := CAULDRON_WIDTH / maxf(bounds.size.x, bounds.size.z)
	cauldron.scale *= fit
	bounds = _bounds(cauldron)
	cauldron.global_position.y += _box.global_position.y - bounds.position.y
	_rim = bounds.size.y
	print("ENTRY cauldron: ", bounds.size, " m")
	# What the child can touch: a sphere around the cauldron (Wei's Target).
	var target := Target.sphere(&"entry_cauldron", CAULDRON_WIDTH * 0.6)
	target.position = Vector3.UP * _rim * 0.5
	_box.add_child(target)


## The box around every mesh under [param root], in world space.
func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var part := mesh.global_transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


func _build_orb() -> void:
	_box.add_child(_orb)
	_orb.position = Vector3.UP * (_rim - 0.08)   # hidden inside the cauldron
	_onion = ONION.instantiate()
	_orb.add_child(_onion)
	# Scale Onion to ONION_HEIGHT and centre it on the orb point.
	var bounds := _bounds(_onion)
	_onion.scale *= ONION_HEIGHT / bounds.size.y
	bounds = _bounds(_onion)
	_onion.global_position -= bounds.get_center() - _orb.global_position
	# Which way the eyes look: from the body's centre to the eyes' centre.
	for mesh: MeshInstance3D in _onion.find_children("*Eyes*", "MeshInstance3D", true, false):
		var eyes := (mesh.global_transform * mesh.get_aabb()).get_center()
		var towards := eyes - bounds.get_center()
		_face = _orb.global_transform.basis.inverse() * Vector3(towards.x, 0, towards.z).normalized()
	# A soft light around Onion, so it glows on the cauldron and table.
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.2)
	light.omni_range = 0.6
	light.light_energy = 0.6
	_orb.add_child(light)


## Onion keeps its face turned to the child.
func _process(_delta: float) -> void:
	if _onion == null or App.rig == null:
		return
	var to_child := App.head().global_position - _orb.global_position
	to_child.y = 0
	if to_child.length() < 0.01:
		return
	var turn := atan2(_face.x, _face.z) - atan2(to_child.x, to_child.z)
	_orb.global_rotation.y = -turn


## The orb rises out; three unfamiliar objects float up from the cauldron and settle on the table.
func _open_lid() -> void:
	var rise := create_tween()
	rise.tween_property(_orb, "position", Vector3.UP * (_rim + 0.15), 1.2).set_trans(Tween.TRANS_SINE)
	await rise.finished

	var shapes: Array[Mesh] = [SphereMesh.new(), CylinderMesh.new(), PrismMesh.new()]
	var spots := [Vector2(-0.35, 0.3), Vector2(0.0, 0.45), Vector2(0.35, 0.3)]   # around the box, toward the child
	for i in shapes.size():
		var piece := MeshInstance3D.new()
		var mesh := shapes[i]
		mesh.set("radius", 0.035)
		mesh.set("height", 0.07)
		mesh.set("top_radius", 0.03)
		mesh.set("bottom_radius", 0.03)
		mesh.set("size", Vector3(0.07, 0.07, 0.07))
		var grey := StandardMaterial3D.new()
		grey.albedo_color = Color(0.6, 0.6, 0.6)   # faded: the colour has drained away
		mesh.material = grey
		piece.mesh = mesh
		piece.add_child(Target.sphere(StringName("entry_piece_%d" % i), 0.06))
		add_child(piece)
		piece.global_position = _box.global_position + Vector3.UP * (_rim + 0.05)
		_found.append(piece)
		var land := _table.point(spots[i].x, spots[i].y) + Vector3.UP * 0.035
		var fall := create_tween()
		fall.tween_property(piece, "global_position", land, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(0.6).timeout


## Faint markings on the table, a cabinet beside the chair, a sealed patch on the
## wall behind: all faded grey.
func _reveal_room() -> void:
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.7, 0.7, 0.7, 0.5)
	grey.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var ring := MeshInstance3D.new()   # markings around the box
	var torus := TorusMesh.new()
	torus.inner_radius = 0.2
	torus.outer_radius = 0.22
	torus.material = grey
	ring.mesh = torus
	_box.add_child(ring)
	ring.position = Vector3.UP * 0.003
	ring.scale = Vector3(1, 0.05, 1)   # flat on the table

	# The cabinet: where Wei's treasure cabinet stands (45 degrees left, 0.8 m, a bit low).
	var eye := App.head().global_transform
	var ahead := Vector3(-eye.basis.z.x, 0, -eye.basis.z.z).normalized()
	var left := ahead.rotated(Vector3.UP, deg_to_rad(45))
	add_child(_cabinet)
	_cabinet.global_position = eye.origin + left * 0.8 + Vector3.DOWN * 0.45
	var shelf := MeshInstance3D.new()
	var shelf_shape := BoxMesh.new()
	shelf_shape.size = Vector3(0.3, 0.4, 0.15)
	shelf_shape.material = StandardMaterial3D.new()
	(shelf_shape.material as StandardMaterial3D).albedo_color = Color(0.55, 0.55, 0.55)
	shelf.mesh = shelf_shape
	_cabinet.add_child(shelf)
	_cabinet.look_at(eye.origin, Vector3.UP)

	# The sealed patch: on the wall behind, where Wei's spell wall is.
	var patch := QuadMesh.new()
	patch.size = Vector2(0.5, 0.5)
	patch.material = grey
	_seal.mesh = patch
	add_child(_seal)
	_seal.global_position = App.world.position_of(App.world.adventure.places[1])
	_seal.look_at(eye.origin, Vector3.UP)
	_seal.rotate_object_local(Vector3.UP, PI)   # face the child


## One object gives a quiet rattle.
func _rattle(piece: Node3D) -> void:
	var start := piece.rotation
	var shake := create_tween()
	for i in 4:
		shake.tween_property(piece, "rotation:z", start.z + 0.25, 0.06)
		shake.tween_property(piece, "rotation:z", start.z - 0.25, 0.06)
	shake.tween_property(piece, "rotation", start, 0.06)
	await shake.finished


## The orb lifts an object up for the child to see, then puts it back.
func _show_off(piece: Node3D) -> void:
	var home := piece.global_position
	var up := home + Vector3.UP * 0.2
	_orb_to(up + Vector3.UP * 0.08)
	var lift := create_tween()
	lift.tween_property(piece, "global_position", up, 0.6)
	lift.tween_property(piece, "rotation:y", piece.rotation.y + TAU, 2.0)
	lift.tween_property(piece, "global_position", home, 0.6)
	await lift.finished


## Moves the orb smoothly to [param where].
func _orb_to(where: Vector3) -> void:
	create_tween().tween_property(_orb, "global_position", where, 0.7).set_trans(Tween.TRANS_SINE)


## The object opens up and shows a small coloured fragment with a mark. Returns it.
func _unfold(piece: Node3D) -> Node3D:
	for target in piece.find_children("*", "Target", false, false):
		piece.remove_child(target)   # found: it can't be picked again (and physics shapes can't squash)
		target.queue_free()
	var grow := create_tween()
	grow.tween_property(piece, "scale", Vector3(1.4, 0.2, 1.4), 0.5)
	await grow.finished
	var fragment := MeshInstance3D.new()
	var gem := PrismMesh.new()
	gem.size = Vector3(0.04, 0.05, 0.02)
	var shine := StandardMaterial3D.new()
	shine.albedo_color = Color(0.95, 0.5, 0.2)
	shine.emission_enabled = true
	shine.emission = Color(0.95, 0.5, 0.2)
	gem.material = shine
	fragment.mesh = gem
	add_child(fragment)
	fragment.global_position = piece.global_position + Vector3.UP * 0.08
	return fragment


## Flies [param thing] to [param where].
func _fly(thing: Node3D, where: Vector3) -> void:
	var flight := create_tween()
	flight.tween_property(thing, "global_position", where, 1.2).set_trans(Tween.TRANS_SINE)
	await flight.finished


## Colour comes back to [param node] (every mesh under it).
func _tint(node: Node, colour: Color) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var paint := StandardMaterial3D.new()
		paint.albedo_color = colour
		(child as MeshInstance3D).material_override = paint


## The fragment's mark appears on the seal, glowing for a moment.
func _mark(on: MeshInstance3D) -> void:
	var symbol := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.08
	torus.outer_radius = 0.1
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.95, 0.5, 0.2)
	glow.emission_enabled = true
	glow.emission = Color(0.95, 0.5, 0.2)
	torus.material = glow
	symbol.mesh = torus
	on.add_child(symbol)
	symbol.rotation_degrees = Vector3(90, 0, 0)
	symbol.position = Vector3(0, 0, 0.01)


## A floating button with [param text] the child can touch or point at and pinch.
func _button(text: String, at: Vector3) -> Node3D:
	var button := Node3D.new()
	add_child(button)
	button.global_position = at
	var face := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(0.22, 0.06, 0.01)
	var blue := StandardMaterial3D.new()
	blue.albedo_color = Color(0.25, 0.45, 0.85)
	blue.emission_enabled = true
	blue.emission = Color(0.1, 0.2, 0.45)
	plate.material = blue
	face.mesh = plate
	button.add_child(face)
	var words := Label3D.new()
	words.text = text
	words.font_size = 28
	words.pixel_size = 0.0006
	words.position = Vector3(0, 0, 0.007)
	button.add_child(words)
	button.add_child(Target.sphere(&"entry_begin", 0.07))
	button.look_at(App.head().global_position, Vector3.UP)
	button.rotate_object_local(Vector3.UP, PI)   # face the child
	return button


## The orb rises just over the rim.
func _peek() -> void:
	var up := create_tween()
	up.tween_property(_orb, "position", Vector3.UP * (_rim + 0.02), 0.6).set_trans(Tween.TRANS_SINE)
	await up.finished


## The orb ducks back inside.
func _duck() -> void:
	var down := create_tween()
	down.tween_property(_orb, "position", Vector3.UP * (_rim - 0.08), 0.3)
	await down.finished


## Quiet piano, fading in, looping.
func _start_music() -> void:
	var stream: AudioStreamMP3 = MUSIC.duplicate()
	stream.loop = true
	_music.stream = stream
	_music.volume_db = -60.0
	add_child(_music)
	_music.play()
	create_tween().tween_property(_music, "volume_db", MUSIC_DB, 4.0)
