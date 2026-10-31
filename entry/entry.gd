class_name Entry
extends Node3D
## Entry: the arrival in the child's magical AR home (direction of Oct 30).
## A calm introduction in the child's real room: Onion, the cream-and-sage cauldron
## and quiet piano. Activating the cauldron lets things out through its opening, and
## a gentle ripple spreads through the nearby room and shows its hidden workshop.
## Then Wei's shelf activity (his World) starts inside that workshop, with Onion
## staying beside the child as the one guide.
##
## Not decided yet, so only placeholders here: what comes out of the cauldron, how
## the child activates it (now: touch it), the workshop's real assets.
## Only the sample lines are spoken. Every say("...") literal is baked by Wei's
## speech baker, so new lines go in only once the interaction is chosen.
## A node in main.tscn before World: plays when there is no session plan.

## Seconds after a line, at least.
const PAUSE := 1.2
## Play when the app starts without a session plan. Tests switch it off and call [method run].
@export var autostart := true

## The cauldron (CC0) and how wide it should be on the table, metres.
const CAULDRON := preload("res://entry/assets/cauldron-cream-sage.glb")
const CAULDRON_WIDTH := 0.22
## The guide: "Onion the Wisp" by Edvin Borkovskij, CC BY 4.0 (credit in entry/assets/CREDITS.md).
const ONION := preload("res://entry/assets/onion_the_wisp.glb")
## How tall Onion is, metres.
const ONION_HEIGHT := 0.11
## Quiet piano under the opening (CC0, see entry/assets/CREDITS.md).
const MUSIC := preload("res://entry/assets/calm-piano-1.mp3")
## Music volume, decibels: well under the voice.
const MUSIC_DB := -12.0

## DEMO: the child stays seated. Everything to reach or look at closely sits inside
## this circle around the head (seen from above). TO TEST: comfortable reach and view.
const PLAY_RADIUS := 0.75
## The cauldron stands near the middle, a little left, this far from the eyes. TO TEST: reach.
const CAULDRON_DISTANCE := 0.5
const CAULDRON_ANGLE := 12.0
## Wei's shelf stands to the right, this many degrees off straight ahead: in view, clear
## of the cauldron. (It goes where his code's table point is, so that point is moved.)
const SHELF_ANGLE := 45.0
## Gap the cauldron keeps from the bench, metres; if it can't, it goes beside the bench.
const CAULDRON_GAP := 0.02
## Size of the things that come out (placeholders), metres. Must fit through the opening.
const PIECE := 0.04
## Seconds the ripple takes to spread across the play circle. Slow and soft: no flash.
const RIPPLE_SECONDS := 5.0

## DEBUG: show the beat in the headset and in Output.
const DEBUG := true
## TESTING: how fast the opening plays (0.5 = half speed, 1.0 = normal). Speech
## itself stays normal; everything around it (moves, pauses, the ripple) slows.
const TEST_SPEED := 0.5
## Draw each hand's pointing ray (Wei's pointer casts it but only draws it on the
## desktop). Only while pointing is on (his [method Pointer.ray_on]).
const SHOW_RAYS := true
## TESTING: before the opening, show where the table was found and ask to confirm it
## (or point at the real table and pinch).
const CONFIRM_TABLE := true
## TESTING: a rough line outline of each tracked hand (headset only).
const SHOW_HANDS := true
## TESTING: in setup, beside Start, buttons that play one part on its own (set up
## as that part needs it), then come back. Start plays everything, into Wei's World.
const JUMP_PANEL := true
## The parts, in order: button id suffix -> label.
const PARTS := {hello = "Hello", touch = "Touch", emerge = "Emerge", ripple = "Ripple", shelf = "Shelf"}

var _table: Surface
var _box := Node3D.new()            # the cauldron on the table
var _rim := 0.15                    # height of the rim above the table, metres (measured)
var _mouth := Vector3.ZERO          # centre of the opening (the brew's surface), world
var _mouth_radius := 0.05           # radius of the opening, metres (measured)
var _left := Vector3.LEFT           # the child's left, flat (set when the cauldron is placed)
var _music := AudioStreamPlayer.new()
var _orb := Node3D.new()            # holds Onion and its glow; moves around
var _onion: Node3D                  # the wisp model, turned to face the child
var _face := Vector3.FORWARD        # which way Onion's eyes point, in its own space
var _glow: OmniLight3D              # Onion's light; pulses while it talks
var _talk_until := 0.0              # seconds (game time) until Onion stops "talking"
var _cue := false                   # the cauldron glows slowly: "something here"
var _clock := 0.0
var _onion_rest_y := 0.0            # Onion's height in its holder when still
var _pieces: Array[Node3D] = []     # what came out of the cauldron (placeholders)
var _details: Array[Node3D] = []    # the workshop, shown as the ripple reaches each
var _motes: Array[Node3D] = []      # drifting specks of light, after the reveal
var _surface_points: Array[Dictionary] = []   # real surfaces the depth rays found: {position, normal}
var _beat_label := Label3D.new()    # DEBUG: which beat is playing, in view
var _shelf: ShelfCopy               # Wei's shelf, built by his own code, shown by the ripple
var _bench := Transform3D.IDENTITY  # Wei's bench frame: at the eyes, facing the work surface
var _bench_below := 0.35            # its top, metres below that frame
var _bench_half := 0.27             # its half width, metres
var _ahead := Vector3.FORWARD       # straight ahead from the seat, flat (at the start)
var _on_table: Variant = null       # where the cauldron goes on the confirmed table, or null (no real table)
var _guide: Guide                   # Wei's "this way" guide, once Onion is its body
var _guiding := false               # the guide was showing the way last frame

## Sent when the child touches (or points at and pinches) the cauldron.
signal _cauldron_touched
## TESTING: a confirm button: its id.
signal _confirm_pressed(id: StringName)
## TESTING: a Start or jump button: which part (&"all" for Start).
signal _part_pressed(part: StringName)
## DEBUG: Onion's soft halo.
var _halo: StandardMaterial3D


## Wei's tidy trial, only to build his shelf: the same object the child then plays
## with. It doesn't play (no _ready: no input, not in the trials group).
class ShelfCopy extends "res://trials/tidy/tidy_trial.gd":
	func _ready() -> void:
		pass

	## Where the bench is: its frame (at the eyes, facing the work surface) and how far its top is below.
	func frame() -> Transform3D:
		return _frame

	func top_below() -> float:
		return _below

	## The bench's half width, metres (as Wei builds it).
	func half_wide() -> float:
		return (THINGS_WIDE + 0.06) * 0.5

	func shelf() -> Node3D:
		return _shelf


func _ready() -> void:
	if autostart and App.session.plan == null:
		print("ENTRY 1: ready, pausing World")
		# Wei's World starts by itself unless told to wait (it is readied after this node).
		(get_node(^"../World") as World).autostart = false
		run.call_deferred()


## Plays the arrival, then starts the World.
func run() -> void:
	Events.touched.connect(func(_hand: StringName, target: Target) -> void: _on_target(target))
	Events.selected.connect(func(_hand: StringName, target: Target, _o: Vector3, _d: Vector3) -> void: _on_target(target))
	# Onion moves while any line plays, Wei's too: one voice, one guide.
	Events.said.connect(func(text: String) -> void: _talk_until = _clock + maxf(1.5, text.length() * 0.065))
	# Setup is quiet: Wei's "Got it. That's your table." is not for the child.
	if &"announce_table" in App.reality:
		App.reality.announce_table = false
	if not App.reality.is_settled:
		await App.reality.settled
	if DEBUG:
		_debug_buttons()
	if CONFIRM_TABLE:
		await _confirm_table()
	_ahead = Vector3(-App.head().global_basis.z.x, 0.0, -App.head().global_basis.z.z).normalized()
	_on_table = _cauldron_on_table()
	_shelf_to_the_side()
	_table = App.reality.work_surface()
	# One cauldron, one Onion, one shelf, one workshop for every part.
	_build_shelf()
	_build_cauldron(await _cauldron_spot())
	_build_onion()
	_build_workshop()

	# Nothing plays until the adult presses Start (or a part to jump to).
	while true:
		var part := await _choose_part()
		if not _music.playing:
			_start_music()
		Engine.time_scale = TEST_SPEED
		_set_up_for(&"hello" if part == &"all" else part)
		if part == &"all":
			await _hello()
			await _touch()
			await _out()
			await _reveal()
		elif part != &"shelf":
			match part:
				&"hello": await _hello()
				&"touch": await _touch()
				&"emerge": await _out()
				&"ripple": await _reveal()
			Engine.time_scale = 1.0
			print("ENTRY jump: ", part, " done")
			continue
		await _to_shelf()
		return


## 1. Arrival: Onion peeks over the rim and says hello.
func _hello() -> void:
	_beat("1: hello")
	await _wait(2.0)   # nothing rushes the child
	await _peek()
	await say("Hello.")
	await _duck()
	await _wait(0.8)
	await _peek()
	await say("I'm Onion, by the way.")


## 2. PLACEHOLDER activation: touch the cauldron. The interaction is not chosen yet,
## so there is no spoken instruction: the cauldron glows slowly until touched.
func _touch() -> void:
	_beat("2: PLACEHOLDER touch the cauldron")
	_cue = true
	await _cauldron_touched
	_cue = false


## 3. Onion moves aside; things come up through the opening, clear the rim, then out.
func _out() -> void:
	_beat("3: out of the cauldron")
	await _onion_aside()
	await _emerge()


## 4. The reveal: a gentle ripple spreads through the nearby room.
func _reveal() -> void:
	_beat("4: the ripple")
	await _ripple()
	await say("Welcome.")
	await _wait(3.0)   # time to look around


## 5. Into the shelf activity, inside the revealed workshop. Onion stays.
func _to_shelf() -> void:
	_beat("5: to the shelf")
	await _tidy_away()   # clears the table for the shelf
	_orb_to(_beside_shelf())
	_become_guide()
	_keep_pinned()   # TESTING: Wei's World uses the chosen table
	Engine.time_scale = 1.0   # Wei's World at normal speed
	_beat("done: Wei's World")
	App.world.run()


# --- TESTING: Start, and jumping to one part ----------------------------------

## Shows Start (green) and, with JUMP_PANEL, one button per part; waits for one.
## Returns the part, or &"all" for Start.
func _choose_part() -> StringName:
	_beat("setup: press Start" + (" or jump to a part" if JUMP_PANEL else ""))
	var eye := App.head().global_transform
	var ahead := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	var side := ahead.rotated(Vector3.UP, -PI * 0.5)   # to the right
	var middle := eye.origin + ahead * 0.5 + Vector3.UP * 0.08
	var buttons: Array[Node3D] = [_button("Start", middle, &"entry_part_all", Color(0.25, 0.65, 0.35))]
	if JUMP_PANEL:
		var words := Label3D.new()
		words.text = "or jump to:"
		words.font_size = 24
		words.pixel_size = 0.0006
		words.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(words)
		words.global_position = middle + Vector3.DOWN * 0.065
		buttons.append(words)
		# Two rows (3 + 2) under Start, 13 cm apart, so each is easy to hit on its own.
		var names: Array = PARTS.keys()
		for i in names.size():
			var row := i / 3
			var count := 3 if row == 0 else names.size() - 3
			var across := ((i % 3) - (count - 1) * 0.5) * 0.13
			var at := middle + side * across + Vector3.DOWN * (0.13 + row * 0.1)
			buttons.append(_button(PARTS[names[i]], at, StringName("entry_part_" + names[i]), Color(0.3, 0.4, 0.6), 0.11, 0.045))
	var part: StringName = await _part_pressed
	for button in buttons:
		button.queue_free()
	print("ENTRY setup: ", "Start" if part == &"all" else "jump to " + part)
	return part


## Puts everything as [param part] finds it, at once: Onion's place, the things on
## the table, the workshop hidden or shown. Same cauldron, Onion and shelf each time.
func _set_up_for(part: StringName) -> void:
	_cue = false
	for piece in _pieces:
		piece.queue_free()
	_pieces.clear()
	_surface_points.clear()
	for detail in _details:
		if is_instance_valid(detail):
			_show_detail(detail, false)
	match part:
		&"hello":
			_orb.global_position = _inside()
		&"touch", &"emerge":
			_orb.global_position = _peek_spot()
		&"ripple", &"shelf":
			_orb.global_position = _aside_spot()
			for i in 3:
				var piece := _new_piece(i)
				piece.global_position = _land_spot(i)
				piece.rotation.y += PI * 0.5
	if part == &"shelf":
		for detail in _details:
			if is_instance_valid(detail):
				_show_detail(detail, true)
	print("ENTRY jump: set up for ", part)


## Shows (at full size) or hides one part of the workshop, at once.
func _show_detail(detail: Node3D, shown: bool) -> void:
	detail.set_meta(&"shown", shown)
	detail.visible = shown
	detail.scale = detail.get_meta(&"size", Vector3.ONE) if shown else Vector3.ONE * 0.001


## Onion becomes the body of Wei's "this way" guide: one guide all the way through.
## While the guide shows the way, Onion is there (with its arrow); after, Onion goes
## back beside the shelf.
func _become_guide() -> void:
	for child in App.world.get_children():
		if child is Guide:
			_guide = child
			_guide.body = _orb
	print("ENTRY Onion is the guide: ", _guide != null)


## Speaks [param text] (baked audio + subtitle) and waits about as long as it lasts.
func say(text: String) -> void:
	Events.say(text)
	await _wait(maxf(PAUSE, text.length() * 0.07 + 0.6))


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _on_target(target: Target) -> void:
	if target != null and target.id == &"entry_debug_restart":
		print("ENTRY DEBUG: restart")
		Engine.time_scale = 1.0
		get_tree().reload_current_scene.call_deferred()
		return
	if target != null and target.id == &"entry_debug_exit":
		print("ENTRY DEBUG: exit")
		get_tree().quit()
		return
	if target != null and String(target.id).begins_with("entry_part_"):
		Events.feedback.emit(&"hint", target.global_position)
		_part_pressed.emit(StringName(String(target.id).trim_prefix("entry_part_")))
		return
	if target != null and String(target.id).begins_with("entry_confirm"):
		Events.feedback.emit(&"hint", target.global_position)
		_confirm_pressed.emit(target.id)
		return
	if target == null or target.id != &"entry_cauldron" or not _cue:
		return
	if DEBUG:
		print("ENTRY touched: ", target.id)
	# Touch feedback (tracked hands can't vibrate): Wei's Feedback module plays a
	# sound and shows a mark where the touch landed.
	Events.feedback.emit(&"hint", target.global_position)
	_cauldron_touched.emit()


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


# --- The hand rays ------------------------------------------------------------

var _rays: Dictionary = {}   # side -> [beam, end dot, material]

## A thin beam from each tracked hand, as far as what it meets: faint white, blue and
## brighter on something to press (a Target); a small dot where it lands.
func _draw_rays() -> void:
	if App.rig == null:
		return
	for side: StringName in [&"left", &"right"]:
		var pointer := App.rig.pointer(side)
		if not _rays.has(side):
			_rays[side] = _new_ray()
		var beam: MeshInstance3D = _rays[side][0]
		var dot: MeshInstance3D = _rays[side][1]
		var light: StandardMaterial3D = _rays[side][2]
		var on := pointer != null and pointer.tracked() and pointer.ray_on()
		beam.visible = on
		dot.visible = on
		if not on:
			continue
		var from := pointer.global_position
		var direction := -pointer.global_basis.z
		var target := pointer.aimed
		var length := 0.8
		if target:
			length = maxf(0.05, (target.global_position - from).dot(direction))
		else:
			var found: Dictionary = App.reality.hit(from, direction) if App.reality else {}
			if not found.is_empty():
				length = minf(2.0, from.distance_to(found.position))
		light.albedo_color = Color(0.45, 0.75, 1.0, 0.75) if target else Color(1.0, 1.0, 1.0, 0.3)
		var x := direction.cross(Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT).normalized()
		beam.global_transform = Transform3D(Basis(x, direction * length, x.cross(direction)), from + direction * length * 0.5)
		dot.global_position = from + direction * length


func _new_ray() -> Array:
	var light := _material(Color(1, 1, 1, 0.3), true)
	var beam := MeshInstance3D.new()
	var line := CylinderMesh.new()
	line.top_radius = 0.0015
	line.bottom_radius = 0.0025
	line.height = 1.0
	line.radial_segments = 6
	line.material = light
	beam.mesh = line
	add_child(beam)
	var dot := MeshInstance3D.new()
	var end := SphereMesh.new()
	end.radius = 0.008
	end.height = 0.016
	end.material = light
	dot.mesh = end
	add_child(dot)
	return [beam, dot, light]


# --- TESTING: the hands' outlines --------------------------------------------

## Wrist to each fingertip, through the knuckles (Godot's OpenXR hand joints).
const FINGERS := [[1, 2, 3, 4, 5], [1, 6, 7, 8, 9, 10], [1, 11, 12, 13, 14, 15], [1, 16, 17, 18, 19, 20], [1, 21, 22, 23, 24, 25]]
var _hand_lines: Dictionary = {}   # side -> [MeshInstance3D of lines, ImmediateMesh, joint dots]

## A rough outline of each tracked hand: a line along each finger and a small dot on
## each joint (lines alone are 1 pixel wide). Headset only: the desktop has no joints.
func _draw_hands() -> void:
	if App.rig == null or App.xr == null:
		return
	for side: StringName in [&"left", &"right"]:
		if not _hand_lines.has(side):
			_hand_lines[side] = _new_hand()
		var outline: MeshInstance3D = _hand_lines[side][0]
		var lines: ImmediateMesh = _hand_lines[side][1]
		var dots: MultiMeshInstance3D = _hand_lines[side][2]
		var hand := App.rig.tracked_hand(side)
		var on := hand.has_joints()
		outline.visible = on
		dots.visible = on
		if not on:
			continue
		var joints := hand.joints()
		var to_world := App.rig.global_transform
		lines.clear_surfaces()
		lines.surface_begin(Mesh.PRIMITIVE_LINES)
		for finger: Array in FINGERS:
			for k in finger.size() - 1:
				lines.surface_add_vertex(to_world * joints.get_hand_joint_transform(finger[k]).origin)
				lines.surface_add_vertex(to_world * joints.get_hand_joint_transform(finger[k + 1]).origin)
		lines.surface_end()
		for joint in 25:
			dots.multimesh.set_instance_transform(joint, Transform3D(Basis.IDENTITY, to_world * joints.get_hand_joint_transform(joint + 1).origin))


func _new_hand() -> Array:
	var lines := ImmediateMesh.new()
	var outline := MeshInstance3D.new()
	outline.mesh = lines
	outline.material_override = _material(Color(0.8, 0.95, 1.0, 0.7), true)
	outline.top_level = true
	add_child(outline)
	var ball := SphereMesh.new()
	ball.radius = 0.004
	ball.height = 0.008
	ball.radial_segments = 6
	ball.rings = 3
	ball.material = _material(Color(0.8, 0.95, 1.0, 0.7), true)
	var many := MultiMesh.new()
	many.transform_format = MultiMesh.TRANSFORM_3D
	many.mesh = ball
	many.instance_count = 25
	var dots := MultiMeshInstance3D.new()
	dots.multimesh = many
	dots.top_level = true
	add_child(dots)
	return [outline, lines, dots]


# --- DEBUG: restart and exit -------------------------------------------------

## Two small buttons up on the right, out of the way, for the whole run (Wei's World
## too): "Restart" plays the opening again from the start, "Exit app" closes the app.
## 15 cm apart, so each is easy to hit on its own.
func _debug_buttons() -> void:
	var eye := App.head().global_transform
	var ahead := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	var right := ahead.rotated(Vector3.UP, -deg_to_rad(38.0))
	var at := eye.origin + right * 0.5 + Vector3.UP * 0.1
	var down := Vector3.DOWN * 0.075
	var restart := _button("Restart", at - down, &"entry_debug_restart", Color(0.35, 0.35, 0.4))
	var leave := _button("Exit app", at + down, &"entry_debug_exit", Color(0.55, 0.25, 0.25))
	print("ENTRY DEBUG: Restart / Exit buttons ", _away(restart.global_position), " m away, up on the right, ",
			snappedf(restart.global_position.distance_to(leave.global_position), 0.01), " m apart")
	for button in [restart, leave]:
		button.set_meta(&"debug", true)


# --- The shelf to the side ----------------------------------------------------

## Wei's bench faces his table point from the eyes. So to put the shelf SHELF_ANGLE
## to the right, the found table's point moves there, along the same table. Only for
## a real table: the pretend one is always straight ahead (then the cauldron goes
## beside the bench instead). Wei's World follows: the alchemy table is that way.
func _shelf_to_the_side() -> void:
	var table := App.reality.work_surface()
	if not App.reality.surfaces(&"table").has(table):
		print("ENTRY shelf: no real table, so it stays straight ahead")
		return
	var eye := App.head().global_position
	var reach := Vector2(table.transform.origin.x - eye.x, table.transform.origin.z - eye.z).length()
	# Turn the shelf further right until the bench clears the cauldron (at most 75 degrees).
	var angle := SHELF_ANGLE
	while _on_table != null and angle < 75.0 and _clearance(_on_table, eye, angle) < CAULDRON_GAP:
		angle += 5.0
	var point := eye + _ahead.rotated(Vector3.UP, -deg_to_rad(angle)) * reach
	point.y = table.transform.origin.y
	App.reality._surfaces.erase(table)   # TESTING: reaches into Reality's list (ask Wei for a hook)
	var moved := Surface.new(&"table", Transform3D(table.transform.basis, point), table.size)
	App.reality.add_surface(moved)
	if _pinned != null:
		_pinned = moved
	print("ENTRY shelf: ", angle, " degrees right, ", snappedf(reach, 0.01), " m away",
			"" if _on_table == null else ", %.2f m clear of the cauldron" % _clearance(_on_table, eye, angle))


## Metres between the cauldron at [param spot] and Wei's bench if it faced
## [param angle] degrees right (negative: they overlap). The bench's size is his.
func _clearance(spot: Vector3, eye: Vector3, angle: float) -> float:
	var bench := Transform3D(Basis.looking_at(_ahead.rotated(Vector3.UP, -deg_to_rad(angle))), eye)
	var local := bench.affine_inverse() * spot
	var half := (ShelfCopy.THINGS_WIDE + 0.06) * 0.5
	var across := absf(local.x) - half - CAULDRON_WIDTH * 0.5
	var beyond := -local.z - 0.41 - CAULDRON_WIDTH * 0.5   # past the shelf's back
	return maxf(across, beyond)


## The cauldron's spot on the confirmed real table: the point of the table nearest
## the middle of the seated reach (CAULDRON_ANGLE left, CAULDRON_DISTANCE), 12 cm in
## from its edges. Null without a real table.
func _cauldron_on_table() -> Variant:
	var table := App.reality.work_surface()
	if not App.reality.surfaces(&"table").has(table):
		return null
	var eye := App.head().global_position
	var wanted := eye + _ahead.rotated(Vector3.UP, deg_to_rad(CAULDRON_ANGLE)) * CAULDRON_DISTANCE
	var spot := _nearest_on(table, wanted, 0.12)
	print("ENTRY spot: on the confirmed table, ", _away(spot), " m away (", snappedf(spot.distance_to(Vector3(wanted.x, spot.y, wanted.z)), 0.01), " m from the ideal spot)")
	return spot


## The point of [param table] nearest [param near] (seen from above), [param margin] in from its edges.
func _nearest_on(table: Surface, near: Vector3, margin: float) -> Vector3:
	var local := table.transform.affine_inverse() * near
	var half := (table.size * 0.5 - Vector2.ONE * margin).max(Vector2.ZERO)
	local.x = clampf(local.x, -half.x, half.x)
	local.z = clampf(local.z, -half.y, half.y)
	local.y = 0.0
	return table.transform * local


# --- TESTING: confirm the table ---------------------------------------------

## Shows where Wei's code thinks the table is (a soft outline) and two buttons:
## "Yes, that's the table" or "No: point at it". Pointing: a dot shows where the hand
## ray meets something, green on a flat tabletop; pinch on green and that is the table
## (no second confirm). Pinching off a tabletop says why and keeps waiting.
var _aiming := false
var _aim_dot: MeshInstance3D
var _aim_material: StandardMaterial3D
var _aim_hit: Dictionary = {}       # the last flat tabletop the ray found: {position, normal}
var _pinned: Surface                # TESTING: the table chosen here; kept over others later
func _confirm_table() -> void:
	_beat("TEST: is this the table?")
	var eye := App.head().global_transform
	var ahead := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	var panel_at := eye.origin + ahead * 0.45 + Vector3.UP * 0.05
	var side := ahead.rotated(Vector3.UP, PI * 0.5)
	var table := App.reality.work_surface()
	var real := App.reality.surfaces(&"table").has(table)
	var outline := _outline(table, real)
	print("ENTRY table: ", "found" if real else "NONE found: a virtual patch", " at ", snappedf(eye.origin.y - table.transform.origin.y, 0.01),
			" m below the eyes, ", _away(table.transform.origin), " m away, size ", table.size)
	var yes := _button("Yes, that's the table", panel_at + side * 0.13, &"entry_confirm_yes")
	var point := _button("No: point at it", panel_at - side * 0.13, &"entry_confirm_point")
	var pressed: StringName = await _confirm_pressed
	yes.queue_free()
	point.queue_free()
	if pressed == &"entry_confirm_yes":
		outline.queue_free()
		if real:
			_pinned = table
		print("ENTRY table: confirmed")
		return
	outline.queue_free()
	_beat("TEST: aim at the tabletop (green dot) and pinch")
	_start_aiming()
	while true:
		var aimed: Array = await Events.selected
		_aim_at(aimed[2], aimed[3])   # the pinch's own ray
		if not _aim_hit.is_empty():
			break
		_beat("TEST: not a flat tabletop there; aim at the table (green dot)")
		print("ENTRY table: pinched off the tabletop")
	_aiming = false
	_aim_dot.queue_free()
	var at: Vector3 = _aim_hit.position
	var facing := Vector3(at.x - eye.origin.x, 0.0, at.z - eye.origin.z).normalized()
	_pinned = Surface.new(&"table", Transform3D(Basis.looking_at(facing), at), Vector2(0.8, 0.5))
	_keep_pinned()
	print("ENTRY table: pointed, ", _away(at), " m away, ", snappedf(eye.origin.y - at.y, 0.01), " m below the eyes")
	var shown := _outline(_pinned, true)
	await _wait(1.2)
	shown.queue_free()


## TESTING ONLY: the chosen table replaces any other tables (Wei's depth finder can
## add one later; then his code would pick whichever is nearest). Reaches into
## Reality's list: a proper "use this table" hook would be Wei's call.
func _keep_pinned() -> void:
	if _pinned == null:
		return
	for other in App.reality.surfaces(&"table"):
		if other != _pinned:
			App.reality._surfaces.erase(other)
	if not App.reality.surfaces(&"table").has(_pinned):
		App.reality.add_surface(_pinned)


func _start_aiming() -> void:
	_aim_material = _material(Color(0.6, 0.6, 0.6, 0.8), true)
	_aim_material.no_depth_test = true
	_aim_dot = MeshInstance3D.new()
	var dot := SphereMesh.new()
	dot.radius = 0.015
	dot.height = 0.03
	dot.material = _aim_material
	_aim_dot.mesh = dot
	_aim_dot.visible = false
	add_child(_aim_dot)
	_aiming = true


## While aiming: where the hand ray (right hand, else left) meets something real;
## green when it is a flat, level top at table height.
func _aim() -> void:
	var ray: Node3D = null
	for side: StringName in [&"right", &"left"]:
		var pointer := App.rig.pointer(side)
		if pointer and pointer.tracked():
			ray = pointer
			break
	if ray == null:
		_aim_hit = {}
		_aim_dot.visible = false
		return
	_aim_at(ray.global_position, -ray.global_basis.z)


func _aim_at(origin: Vector3, direction: Vector3) -> void:
	_aim_hit = {}
	var found: Dictionary = App.reality.hit(origin, direction)
	if found.is_empty():
		_aim_dot.visible = false
		return
	var at: Vector3 = found.position
	_aim_dot.visible = true
	_aim_dot.global_position = at
	var eye := App.head().global_position
	var level := (found.normal as Vector3).y > 0.8 or _flat_at(eye, at + Vector3.UP * 0.1) != null
	var height_ok := eye.y - at.y > 0.2 and eye.y - at.y < 0.9
	if level and height_ok:
		_aim_hit = found
	_aim_material.albedo_color = Color(0.3, 0.95, 0.5, 0.9) if not _aim_hit.is_empty() else Color(0.6, 0.6, 0.6, 0.8)


## A soft rectangle over [param table]: green when it is a found table, orange for the virtual patch.
func _outline(table: Surface, real: bool) -> Node3D:
	var sheet := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = table.size
	plane.material = _material(Color(0.3, 0.9, 0.5, 0.25) if real else Color(1.0, 0.6, 0.2, 0.25), true)
	sheet.mesh = plane
	add_child(sheet)
	sheet.global_transform = table.transform.translated_local(Vector3.UP * 0.004)
	var words := Label3D.new()
	words.text = "table found" if real else "no table: pretend one"
	words.font_size = 32
	words.pixel_size = 0.0007
	words.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	words.position = Vector3.UP * 0.06
	sheet.add_child(words)
	return sheet


## A floating button with [param text]: touch it, or point at it and pinch.
func _button(text: String, at: Vector3, id: StringName, colour := Color(0.25, 0.45, 0.85),
		wide := 0.22, reach := 0.05) -> Node3D:
	var button := Node3D.new()
	add_child(button)
	button.global_position = at
	var face := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(wide, 0.06 if wide > 0.15 else 0.05, 0.01)
	plate.material = _material(colour)
	face.mesh = plate
	button.add_child(face)
	var words := Label3D.new()
	words.text = text
	words.font_size = 28 if wide > 0.15 else 24
	words.pixel_size = 0.0006
	words.position = Vector3(0, 0, 0.007)
	button.add_child(words)
	button.add_child(Target.sphere(id, reach))
	button.look_at(App.head().global_position, Vector3.UP)
	button.rotate_object_local(Vector3.UP, PI)   # its face to the child
	return button


# --- The cauldron ------------------------------------------------------------

func _build_cauldron(spot: Vector3) -> void:
	add_child(_box)
	_box.global_position = spot
	# Handles to the sides: the cauldron's front faces the child.
	var to_child := App.head().global_position - spot
	_box.rotation.y = atan2(to_child.x, to_child.z)
	var cauldron: Node3D = CAULDRON.instantiate()
	_box.add_child(cauldron)
	_stand_upright(cauldron)
	# Scale it to CAULDRON_WIDTH and stand it on the table, whatever the model's own units.
	var bounds := _bounds(cauldron)
	cauldron.scale *= CAULDRON_WIDTH / maxf(bounds.size.x, bounds.size.z)
	bounds = _bounds(cauldron)
	cauldron.global_position += Vector3(spot.x - bounds.get_center().x, spot.y - bounds.position.y, spot.z - bounds.get_center().z)
	_rim = _bounds(cauldron).size.y
	var brew := _brew(cauldron)
	_mouth = spot + Vector3.UP * _rim if brew.size == Vector3.ZERO else brew.get_center()
	_mouth_radius = CAULDRON_WIDTH * 0.25 if brew.size == Vector3.ZERO else minf(brew.size.x, brew.size.z) * 0.5
	print("ENTRY cauldron: rim ", snappedf(_rim, 0.001), " m, opening radius ", snappedf(_mouth_radius, 0.001),
			" m, ", snappedf(spot.y + _rim - _mouth.y, 0.001), " m below the rim")
	var target := Target.sphere(&"entry_cauldron", CAULDRON_WIDTH * 0.6)
	target.position = Vector3.UP * _rim * 0.5
	_box.add_child(target)


## The model lies on its side (its brew faces +Z): turn it so the brew faces up.
func _stand_upright(cauldron: Node3D) -> void:
	var brew := _brew(cauldron)
	var all := _bounds(cauldron)
	if brew.size == Vector3.ZERO or brew.size.y <= minf(brew.size.x, brew.size.z):
		return   # already upright
	var flat_z := brew.size.z < brew.size.x
	var side := (brew.get_center() - all.get_center()).z if flat_z else (brew.get_center() - all.get_center()).x
	if flat_z:
		cauldron.rotate_x(-PI * 0.5 if side > 0.0 else PI * 0.5)
	else:
		cauldron.rotate_z(PI * 0.5 if side > 0.0 else -PI * 0.5)


## The brew's surface ("SageBrew" material) in world space, or an empty box.
func _brew(cauldron: Node3D) -> AABB:
	for mesh: MeshInstance3D in cauldron.find_children("*", "MeshInstance3D", true, false):
		for s in mesh.mesh.get_surface_count():
			var material := mesh.mesh.surface_get_material(s)
			if material == null or not material.resource_name.contains("Brew"):
				continue
			var points: PackedVector3Array = mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			var box := AABB(mesh.global_transform * points[0], Vector3.ZERO)
			for point in points:
				box = box.expand(mesh.global_transform * point)
			return box
	return AABB()


## Wei's shelf, as his trial builds it, where his trial will put it. Hidden until
## the ripple reaches it. When his trial builds its own, this copy goes.
func _build_shelf() -> void:
	_shelf = ShelfCopy.new()
	add_child(_shelf)
	_shelf._build_shelf()
	_bench = _shelf.frame()
	_bench_below = _shelf.top_below()
	_bench_half = _shelf.half_wide()
	var frame := _bench
	# A pivot under the bench's middle, so the shelf can grow in from there.
	var pivot := Node3D.new()
	add_child(pivot)
	pivot.global_transform = frame.translated_local(Vector3(0.0, -_shelf.top_below(), -0.26))
	_shelf.shelf().reparent(pivot)
	_detail(pivot, pivot.global_position)
	get_tree().node_added.connect(_on_node_added)
	print("ENTRY shelf: bench top ", snappedf(_shelf.top_below(), 0.01), " m below the eyes")


## Wei's trial built its own shelf: the copy goes (they stand in the same place).
func _on_node_added(node: Node) -> void:
	if node.name == &"Shelf" and _shelf != null and node != _shelf.shelf():
		get_tree().node_added.disconnect(_on_node_added)
		_shelf.shelf().get_parent().queue_free()
		_shelf.queue_free()
		_shelf = null
		print("ENTRY shelf: Wei's trial has its own now")


## Where the cauldron goes: near the middle (CAULDRON_ANGLE left, CAULDRON_DISTANCE),
## if that keeps it clear of Wei's bench; else just left of the bench. At the real
## table's height when depth finds a flat, level patch there (a lap doesn't count),
## else the found table's height, else the bench's. It stays there the whole time.
func _cauldron_spot() -> Vector3:
	var eye := _bench.origin
	_left = _ahead.rotated(Vector3.UP, PI * 0.5)
	if _on_table != null:
		var on: Vector3 = _on_table
		var flat: Variant = _flat_at(eye, Vector3(on.x, eye.y, on.z))   # the real top's height, if depth sees it
		if flat != null and absf((flat as Vector3).y - on.y) < 0.05:
			on.y = (flat as Vector3).y
		print("ENTRY spot: cauldron on the confirmed table, ", snappedf(eye.y - on.y, 0.01), " m below the eyes")
		return on
	var spot := eye + _ahead.rotated(Vector3.UP, deg_to_rad(CAULDRON_ANGLE)) * CAULDRON_DISTANCE
	var on_bench := _bench.affine_inverse() * spot   # in the bench's frame: x across, -z ahead
	var clear := absf(on_bench.x) - CAULDRON_WIDTH * 0.5 - _bench_half
	if clear < CAULDRON_GAP and -on_bench.z < 0.41 + CAULDRON_WIDTH * 0.5:
		var side := _bench_half + CAULDRON_GAP + 0.03 + CAULDRON_WIDTH * 0.5
		spot = _bench * Vector3(-side, 0.0, -0.28)
		print("ENTRY spot: the middle would touch the shelf; beside it instead")
	else:
		print("ENTRY spot: middle, ", snappedf(clear, 0.01), " m clear of the bench")
	spot.y = eye.y - _bench_below
	for attempt in 12:   # about 3 s
		var flat: Variant = _flat_at(eye, Vector3(spot.x, eye.y, spot.z))
		if flat != null:
			print("ENTRY spot: real table by depth, ", _away(flat), " m away, ", snappedf(eye.y - (flat as Vector3).y, 0.01), " m below the eyes")
			return flat
		await _wait(0.25)
	if App.reality.surfaces(&"table").has(_table):
		spot.y = _table.transform.origin.y
		print("ENTRY spot: at the table's height (depth saw no flat patch there), ", _away(spot), " m away")
	else:
		print("ENTRY spot: no table; at the bench's height, ", _away(spot), " m away")
	return spot


## Seen from above, how far [param point] is from the head, metres.
func _away(point: Vector3) -> float:
	var eye := App.head().global_position
	return snappedf(Vector2(point.x - eye.x, point.z - eye.z).length(), 0.01)


## The tabletop under [param above] if it is level and flat over 16 cm at table
## height below [param eye]; else null.
func _flat_at(eye: Vector3, above: Vector3) -> Variant:
	var heights: Array[float] = []
	for offset: Vector3 in [Vector3.ZERO, Vector3(0.08, 0, 0), Vector3(-0.08, 0, 0), Vector3(0, 0, 0.08), Vector3(0, 0, -0.08)]:
		var found: Dictionary = App.reality.hit(above + offset, Vector3.DOWN)
		if found.is_empty() or found.normal.y < 0.95:
			return null
		heights.append(found.position.y)
	var drop := eye.y - heights[0]
	if drop < 0.25 or drop > 0.8 or heights.max() - heights.min() > 0.015:
		return null
	return Vector3(above.x, heights[0], above.z)


## The box around every mesh under [param root], in world space.
func _bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var part := mesh.global_transform * mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


## Flat, from the cauldron toward the child.
func _toward_child() -> Vector3:
	var to := App.head().global_position - _box.global_position
	return Vector3(to.x, 0.0, to.z).normalized()


# --- Onion -------------------------------------------------------------------

func _build_onion() -> void:
	add_child(_orb)
	_orb.global_position = _inside()
	_onion = ONION.instantiate()
	_orb.add_child(_onion)
	# Scale Onion to ONION_HEIGHT and centre it on the holder.
	var bounds := _bounds(_onion)
	_onion.scale *= ONION_HEIGHT / bounds.size.y
	bounds = _bounds(_onion)
	_onion.global_position -= bounds.get_center() - _orb.global_position
	_onion_rest_y = _onion.position.y
	# Which way the eyes look: from the body's centre to the eyes' centre.
	for mesh: MeshInstance3D in _onion.find_children("*Eyes*", "MeshInstance3D", true, false):
		var eyes := (mesh.global_transform * mesh.get_aabb()).get_center()
		var towards := eyes - bounds.get_center()
		_face = _orb.global_transform.basis.inverse() * Vector3(towards.x, 0, towards.z).normalized()
	# A soft light around Onion, so it glows on the cauldron and table.
	_glow = OmniLight3D.new()
	_glow.light_color = Color(1.0, 0.85, 0.2)
	_glow.omni_range = 0.6
	_glow.light_energy = 0.6
	_orb.add_child(_glow)
	# A small, soft halo around Onion in its own body colour, always facing the child.
	var halo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * ONION_HEIGHT * 1.5
	# Normal (mixed) blending: over passthrough, an added glow can vanish.
	var tint := _body_colour()
	tint.a = 0.22
	_halo = _material(tint, true)
	_halo.albedo_texture = _soft_dot()
	_halo.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = _halo
	halo.mesh = quad
	_orb.add_child(halo)


## Onion's body colour: the average of its texture where the body's UVs fall
## (light blue). If the texture can't be read on this device, the value measured on the desktop.
func _body_colour() -> Color:
	var measured := Color(0.57, 0.84, 0.91)
	for mesh: MeshInstance3D in _onion.find_children("*", "MeshInstance3D", true, false):
		if mesh.name.contains("Eye"):
			continue
		var material := mesh.mesh.surface_get_material(0) as BaseMaterial3D
		if material == null or material.albedo_texture == null:
			continue
		var image := material.albedo_texture.get_image()
		if image == null:
			break
		if image.is_compressed() and image.decompress() != OK:
			break
		var uvs: PackedVector2Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
		var sum := Color(0, 0, 0, 0)
		var count := 0
		for i in range(0, uvs.size(), 7):
			var x := clampi(int(fposmod(uvs[i].x, 1.0) * image.get_width()), 0, image.get_width() - 1)
			var y := clampi(int(fposmod(uvs[i].y, 1.0) * image.get_height()), 0, image.get_height() - 1)
			sum += image.get_pixel(x, y)
			count += 1
		if count > 0:
			print("ENTRY Onion's colour: ", sum / count)
			return Color(sum.r / count, sum.g / count, sum.b / count)
	print("ENTRY Onion's colour: measured value (texture not readable here)")
	return measured


## Where Onion hides: under the brew, out of sight.
func _inside() -> Vector3:
	return _mouth + Vector3.DOWN * (ONION_HEIGHT * 0.5 + 0.02)


## Onion faces the child; bobs and glows while talking. The cauldron's cue and the
## workshop's motes move here too.
func _process(delta: float) -> void:
	_clock += delta
	if SHOW_RAYS:
		_draw_rays()
	if SHOW_HANDS:
		_draw_hands()
	if _aiming:
		_aim()
	for i in _motes.size():
		var mote := _motes[i]
		var home: Vector3 = mote.get_meta(&"home")
		mote.global_position = home + Vector3(sin(_clock * 0.3 + i), sin(_clock * 0.4 + i * 1.7) * 0.6, cos(_clock * 0.25 + i * 0.9)) * 0.03
	if _onion == null or App.rig == null:
		return
	if _guide:
		if _guiding and not _guide.visible:
			_orb_to(_beside_shelf())   # the child found the place
		_guiding = _guide.visible
	var talking := _clock < _talk_until
	var bob := sin(_clock * 7.0) * 0.006 if talking else sin(_clock * 1.5) * 0.002   # idle: a slow float
	_onion.position.y = lerpf(_onion.position.y, _onion_rest_y + bob, minf(1.0, delta * 10.0))
	_halo.albedo_color.a = 0.3 if talking else 0.22
	if talking:
		_glow.light_energy = 0.6 + 0.35 * (0.5 + 0.5 * sin(_clock * 9.0))
	elif _cue:
		_glow.light_energy = 0.5 + 0.5 * (0.5 + 0.5 * sin(_clock * 2.0))   # slow: about 3 s a breath
	else:
		_glow.light_energy = 0.6
	var to_child := App.head().global_position - _orb.global_position
	to_child.y = 0
	if to_child.length() < 0.01:
		return
	var turn := atan2(_face.x, _face.z) - atan2(to_child.x, to_child.z)
	_orb.global_rotation.y = -turn


## Onion rises just over the rim.
func _peek() -> void:
	await _move(_orb, _peek_spot(), 0.6)


func _peek_spot() -> Vector3:
	return _mouth + Vector3.UP * 0.035


## Onion ducks back under the brew.
func _duck() -> void:
	await _move(_orb, _inside(), 0.3)


## Onion comes up through the opening, then moves aside: to the right of the cauldron
## (seen by the child), away from where the things will land.
func _onion_aside() -> void:
	await _move(_orb, _mouth + Vector3.UP * (ONION_HEIGHT * 0.5 + 0.05), 0.7)
	await _move(_orb, _aside_spot(), 0.8)


## Where Onion waits while the things come out: right of the cauldron, a little toward the child.
func _aside_spot() -> Vector3:
	return _mouth + Vector3.UP * (ONION_HEIGHT * 0.5 + 0.04) - _left * (CAULDRON_WIDTH * 0.5 + 0.08) + _toward_child() * 0.04


## Moves Onion smoothly to [param where].
func _orb_to(where: Vector3) -> void:
	_move(_orb, where, 1.2)


## Over the shelf's left end, between it and the cauldron: where Onion waits during Wei's World.
func _beside_shelf() -> Vector3:
	return _bench * Vector3(-_bench_half + 0.02, -_bench_below + 0.3, -0.3)


# --- What comes out (PLACEHOLDERS: not chosen yet) ---------------------------

## Three small things come up through the opening one after another: straight up
## until they clear the rim, then out in an arc to the table beside the cauldron.
func _emerge() -> void:
	var rim_y := _box.global_position.y + _rim
	var last: Tween
	for i in 3:
		var piece := _new_piece(i)
		# Through the opening: start under the brew, a little off centre, inside the opening.
		var across := _left.rotated(Vector3.UP, i * TAU / 3.0) * (_mouth_radius - PIECE * 0.6) * 0.5
		var start := _mouth + across + Vector3.DOWN * (PIECE + 0.01)
		var clear := Vector3(_mouth.x + across.x, rim_y + PIECE * 0.5 + 0.05, _mouth.z + across.z)
		var land := _land_spot(i)
		piece.global_position = start
		last = create_tween()
		last.tween_property(piece, "global_position", clear, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		last.tween_method(_arc.bind(piece, clear, land, 0.06), 0.0, 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		last.tween_property(piece, "rotation:y", piece.rotation.y + PI * 0.5, 0.4)
		if DEBUG:
			print("ENTRY piece ", i, ": from ", snappedf(start.y - rim_y, 0.001), " m (under the rim) up to ",
					snappedf(clear.y - rim_y, 0.001), " m over it, lands ", snappedf(land.distance_to(_box.global_position), 0.01), " m out")
		await _wait(0.6)
	await last.finished


## Placeholder thing number [param i] (0..2): a sphere, a cylinder or a prism.
func _new_piece(i: int) -> MeshInstance3D:
	var shapes: Array[Mesh] = [SphereMesh.new(), CylinderMesh.new(), PrismMesh.new()]
	var colours := [Color(0.35, 0.65, 0.85), Color(0.85, 0.55, 0.25), Color(0.5, 0.75, 0.4)]
	var piece := MeshInstance3D.new()
	var mesh := shapes[i]
	mesh.set("radius", PIECE * 0.5)
	mesh.set("height", PIECE)
	mesh.set("top_radius", PIECE * 0.4)
	mesh.set("bottom_radius", PIECE * 0.4)
	mesh.set("size", Vector3.ONE * PIECE)
	var material := StandardMaterial3D.new()
	material.albedo_color = colours[i]
	mesh.material = material
	piece.mesh = mesh
	add_child(piece)
	_pieces.append(piece)
	return piece


## Where thing [param i] lands: on the child's left of the cauldron, toward the child.
func _land_spot(i: int) -> Vector3:
	var spots: Array[Vector2] = [Vector2(0.16, 0.0), Vector2(0.13, 0.10), Vector2(0.04, 0.16)]   # [toward, left] metres
	return _box.global_position - _ahead * spots[i].x + _left * spots[i].y + Vector3.UP * PIECE * 0.5


## One step of a hop from [param from] to [param to], [param height] high in the middle.
func _arc(k: float, thing: Node3D, from: Vector3, to: Vector3, height: float) -> void:
	thing.global_position = from.lerp(to, k) + Vector3.UP * height * 4.0 * k * (1.0 - k)


## The things hop back into the cauldron (the table is clear for the shelf).
func _tidy_away() -> void:
	var rim_y := _box.global_position.y + _rim
	var last: Tween
	for piece in _pieces:
		var over := Vector3(_mouth.x, rim_y + PIECE * 0.5 + 0.05, _mouth.z)
		last = create_tween()
		last.tween_method(_arc.bind(piece, piece.global_position, over, 0.06), 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE)
		last.tween_property(piece, "global_position", _mouth + Vector3.DOWN * (PIECE + 0.01), 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		last.tween_callback(piece.queue_free)
		await _wait(0.3)
	await last.finished
	_pieces.clear()


# --- The reveal --------------------------------------------------------------

## A slow, soft ring of light spreads from the cauldron across the play circle. As it
## passes each spot, that part of the workshop appears, and where it meets a real
## surface (depth) a faint glint shows on it: the ripple travels over the real room.
## No flash, no camera movement.
func _ripple() -> void:
	_surface_points.clear()
	_sample_room()
	var reach := PLAY_RADIUS * 1.6 + _away(_box.global_position)
	for wave in 3:   # three rings, a second apart, each fainter
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.96
		torus.outer_radius = 1.0
		torus.rings = 96
		var light := StandardMaterial3D.new()
		light.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		light.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		light.albedo_color = Color(1.0, 0.85, 0.5, 0.35 - wave * 0.1)
		torus.material = light
		ring.mesh = torus
		add_child(ring)
		ring.global_position = _box.global_position + Vector3.UP * 0.004
		var spread := create_tween()
		spread.tween_method(_spread.bind(ring, light, reach, light.albedo_color.a, wave == 0), 0.0, 1.0, RIPPLE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		spread.tween_callback(ring.queue_free)
		await _wait(1.0)
	await _wait(RIPPLE_SECONDS - 1.0)


## One step of a ring: its radius grows, it fades; the first ring shows what it passes.
func _spread(k: float, ring: MeshInstance3D, light: StandardMaterial3D, reach: float, alpha: float, shows: bool) -> void:
	var radius := maxf(0.02, k * reach)
	ring.scale = Vector3(radius, 0.02, radius)
	light.albedo_color.a = alpha * (1.0 - k)
	if not shows:
		return
	for point in _surface_points:
		if not point.get(&"shown", false) and (point.position as Vector3).distance_to(_box.global_position) <= radius:
			point.shown = true
			_glint(point.position, point.normal)
	for detail in _details:
		if is_instance_valid(detail) and not detail.get_meta(&"shown", false) and detail.global_position.distance_to(_box.global_position) <= radius:
			detail.set_meta(&"shown", true)
			detail.visible = true
			create_tween().tween_property(detail, "scale", detail.get_meta(&"size", Vector3.ONE), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## PLACEHOLDER for a depth ripple (later: drawn on the depth image itself, every pixel).
## Casts a fan of depth rays from the eyes over what the headset sees and keeps the
## real surfaces they hit. Depth only covers what is in view, about 90 degrees ahead.
const GLINT_ROWS := 7
const GLINT_COLUMNS := 15
func _sample_room() -> void:
	var eye := App.head().global_transform
	var ahead := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	for row in GLINT_ROWS:
		var down := lerpf(-10.0, 65.0, row / float(GLINT_ROWS - 1))   # a little above level to steeply down
		for column in GLINT_COLUMNS:
			var across := lerpf(-50.0, 50.0, column / float(GLINT_COLUMNS - 1))
			var ray := ahead.rotated(Vector3.UP, deg_to_rad(across))
			ray = ray.rotated(ray.cross(Vector3.UP).normalized(), -deg_to_rad(down))
			var found: Dictionary = App.reality.hit(eye.origin, ray)
			if not found.is_empty() and (found.position as Vector3).distance_to(eye.origin) < 3.0:
				_surface_points.append({position = found.position, normal = found.normal})
	print("ENTRY ripple: ", _surface_points.size(), " real surface points of ", GLINT_ROWS * GLINT_COLUMNS, " rays")


## A faint, soft disc of light lying on a real surface, fading out.
func _glint(at: Vector3, normal: Vector3) -> void:
	var disc := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * 0.12
	var light := _material(Color(1.0, 0.85, 0.5, 0.0), true)
	light.albedo_texture = _soft_dot()
	quad.material = light
	disc.mesh = quad
	add_child(disc)
	var up := normal.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	disc.global_transform = Transform3D(Basis(side, up.cross(side), up), at + up * 0.005)   # the quad's face along the normal
	var fade := create_tween()
	fade.tween_property(light, "albedo_color:a", 0.3, 0.5)
	fade.tween_property(light, "albedo_color:a", 0.0, 1.5)
	fade.tween_callback(disc.queue_free)


## A round, soft-edged dot, made once.
var _dot: GradientTexture2D
func _soft_dot() -> GradientTexture2D:
	if _dot == null:
		_dot = GradientTexture2D.new()
		_dot.fill = GradientTexture2D.FILL_RADIAL
		_dot.fill_from = Vector2(0.5, 0.5)
		_dot.fill_to = Vector2(1.0, 0.5)
		var fall := Gradient.new()
		fall.set_color(0, Color(1, 1, 1, 1))
		fall.set_color(1, Color(1, 1, 1, 0))
		_dot.gradient = fall
	return _dot


## PLACEHOLDER workshop around the seated child: Wei's shelf (built at the start),
## drifting motes, and outside the play circle a soft doorway of light: a glimpse of
## a larger world. Real assets later.
func _build_workshop() -> void:
	var eye := App.head().global_position
	var ahead := -_left.rotated(Vector3.UP, PI * 0.5)
	var table_y := _box.global_position.y
	var around := func(degrees: float, distance: float, height: float) -> Vector3:
		return Vector3(eye.x, height, eye.z) + ahead.rotated(Vector3.UP, deg_to_rad(degrees)) * distance
	var flame := _material(Color(1.0, 0.75, 0.3), true)
	# Motes of light drifting through the play circle.
	for i in 16:
		var mote := _shape(SphereMesh.new(), Vector3.ONE * 0.008, flame)
		var angle := -80.0 + i * 160.0 / 15.0
		var spot: Vector3 = around.call(angle, 0.35 + fmod(i * 0.37, 1.0) * (PLAY_RADIUS - 0.35), table_y + 0.1 + fmod(i * 0.61, 1.0) * 0.5)
		mote.set_meta(&"home", spot)
		_detail(mote, spot)
		_motes.append(mote)
	# Beyond the circle: a soft doorway of light, ahead and to the right. Only to look at.
	var door := Node3D.new()
	var glow := _shape(QuadMesh.new(), Vector3(0.45, 0.8, 1.0), _material(Color(1.0, 0.85, 0.6, 0.35), true))
	door.add_child(glow)
	var beyond := OmniLight3D.new()
	beyond.light_color = Color(1.0, 0.85, 0.6)
	beyond.light_energy = 0.3
	beyond.omni_range = 1.2
	beyond.position = Vector3(0, 0, 0.3)
	door.add_child(beyond)
	_detail(door, around.call(-30.0, PLAY_RADIUS + 0.8, eye.y))
	door.look_at(Vector3(eye.x, door.global_position.y, eye.z), Vector3.UP)
	door.rotate_object_local(Vector3.UP, PI)   # its face to the child
	print("ENTRY workshop: ", _details.size(), " details, the doorway ", _away(door.global_position), " m away")


## Puts [param detail] at [param where], hidden until the ripple reaches it.
func _detail(detail: Node3D, where: Vector3) -> void:
	if detail.get_parent() == null:
		add_child(detail)
	detail.global_position = where
	detail.set_meta(&"size", detail.scale)
	detail.scale = Vector3.ONE * 0.001
	detail.visible = false
	_details.append(detail)


func _shape(mesh: PrimitiveMesh, size: Vector3, material: Material) -> MeshInstance3D:
	mesh.material = material
	var shape := MeshInstance3D.new()
	shape.mesh = mesh
	if mesh is QuadMesh:
		(mesh as QuadMesh).size = Vector2(size.x, size.y)
	else:
		shape.scale = size / _unit(mesh)
	return shape


## The size of a primitive mesh at its defaults, metres.
func _unit(mesh: PrimitiveMesh) -> Vector3:
	return mesh.get_aabb().size.max(Vector3.ONE * 0.0001)


func _material(colour: Color, glows := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	if colour.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glows:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


# --- Helpers -----------------------------------------------------------------

## Moves [param thing] smoothly to [param where] in [param seconds].
func _move(thing: Node3D, where: Vector3, seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(thing, "global_position", where, seconds).set_trans(Tween.TRANS_SINE)
	await tween.finished


## Quiet piano, fading in, looping.
func _start_music() -> void:
	var stream: AudioStreamMP3 = MUSIC.duplicate()
	stream.loop = true
	_music.stream = stream
	_music.volume_db = -60.0
	add_child(_music)
	_music.play()
	print("ENTRY music playing: ", _music.playing)
	create_tween().tween_property(_music, "volume_db", MUSIC_DB, 4.0)
