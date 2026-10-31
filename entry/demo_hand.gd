class_name DemoHand
extends Node3D
## A softly translucent teaching hand from primitives (a palm, curled fingers, a thumb and an
## index finger; no textures). It shows ONE gesture at a time and loops it until [method stop]:
## a tap on the cauldron, a pinch that lifts the gear, a lowering and opening over the socket.
## It never moves the real gear and never points at an answer: [method pinch_lift] stays within a few
## cm of the thing it pinches (it only shows HOW to pick up, for any thing, a shelf thing too), and only
## [method lower_release] goes to a place, which is the story's own instruction (the socket), never a
## shelf slot. It never flashes, and its calls return at once: everything it
## does runs from its own [method _process], so [method stop] (or freeing it) cancels it, and
## nothing waits on a timer or a tween that could outlive a part.
## The hand is the MRTK-derived right hand (entry/assets/hand/right_hand_demo.glb, MIT, see its
## LICENSE.md): [constant USE_GLB_HAND]. If that file is missing or does not load, the primitive
## stand-in below is used instead, with the same behaviour. Its clips: "pinch" (0 = open, 1 s =
## closed, the tips meeting at the origin) and "tap"; both are scrubbed by code, never played.

## Use the GLB hand (false, or a file that will not load: the primitives).
const USE_GLB_HAND := true
const HAND_FILE := "res://entry/assets/hand/right_hand_demo.glb"
## How big the GLB hand is (it is about 23 cm from wrist to fingertip at 1.0). Megan judges it in the headset.
const HAND_SCALE := 0.6
## The GLB's fingers point +Z, ours -Z: one fixed turn about Y, plus a trim by eye (radians).
const HAND_FIX_YAW := PI
const HAND_FIX_TRIM := -0.72
## A roll about the fingers' axis (the pinch point stays put), so that the gap between the thumb and the
## index finger shows to a child looking down at the table instead of hiding under the index finger.
const HAND_ROLL := -0.6
## The bones: the index fingertip (the asset calls it "Point"), and the fingers a tap folds away.
const INDEX_TIP_BONE := "PointR_JNT3"
const INDEX_BONES := "Point"
const FOLDED_FINGERS: Array[String] = ["Middle", "Middel", "Ring", "Pinky"]

const COLOUR := Color(0.96, 0.9, 0.8)
## How solid it looks at most, and how long it takes to appear or go, seconds.
const ALPHA := 0.4
const FADE_SECONDS := 0.4
const RADIUS := 0.0085
## It comes in like a right hand: turned this many radians to the left of straight away from the
## child, so thumb and finger are seen from the side, not end-on.
const YAW := 1.3

enum Mode { NONE, TAP, PINCH_LIFT, LOWER_RELEASE, SWEEP }
## The tap's own times: the hand is down on the rim from TAP_DOWN to TAP_UP, back up at TAP_BACK, and
## the loop is TAP_LOOP long. The GLB's "tap" clip (0 -> press at 0.5 -> back at 1) is scrubbed to match.
const TAP_DOWN := 0.8
const TAP_UP := 1.25
const TAP_BACK := 2.0
const TAP_LOOP := 3.0
## The sweep's own times: it waits at the start until SWEEP_START, is across at SWEEP_END, and the loop is SWEEP_LOOP.
const SWEEP_START := 0.5
const SWEEP_END := 1.7
const SWEEP_LOOP := 3.2
## The clip's press is small: the index finger bends this many times as far as the clip bends it.
const TAP_PRESS_GAIN := 1.8
## The contact moment: a soft ring spreads from the rim where the fingertip lands (seconds, and how
## wide it ends up, metres).
const RING_SECONDS := 0.7
const RING_FROM := 0.02
const RING_TO := 0.075
const RING_COLOUR := Color(1.0, 0.92, 0.6)
const RING_ALPHA := 0.6

var _mode := Mode.NONE
var _gesture := Mode.NONE      # the gesture last started: it keeps its look while it fades out after stop()
var _sweep_way := Vector3.FORWARD   # the way an open hand sweeps (level, unit): its fingers lead
var _t := 0.0
var _fade := 0.0
var _keys: Array = []           # [seconds, up, back, open]: where the pinch point is, and how open
var _length := 0.0
var _anchor := Callable()       # () -> Vector3: the spot the keys are measured from
var _pitch := 0.0               # radians, negative: pointing down
var _fade_loop := false         # fade out and in between rounds (when the end does not match the start)
var _key: Variant = null        # what the gesture is about (the gear, a spot): asking again for it changes nothing
## Which body to build (the constants by default; tests change them to check the fallback).
var use_glb := USE_GLB_HAND
var hand_file := HAND_FILE
var _material: StandardMaterial3D
var _figure: Node3D
var _index: Array[MeshInstance3D] = []
var _thumb: Array[MeshInstance3D] = []
var _player: AnimationPlayer    # the GLB hand's clips (null: the primitive hand)
var _skeleton: Skeleton3D
var _folded: Dictionary = {}    # bone -> its rotation in the closed pinch: the three fingers a pointing hand folds
var _tap_tip := Vector3.ZERO    # where the index fingertip is (figure space) when the tap is pressed
var _index_rest: Dictionary = {}     # index bone -> its rotation at rest (the tap clip's start)
var _index_pressed: Dictionary = {}  # index bone -> its rotation at the clip's press
var _ring: MeshInstance3D       # the contact ring (a tap only)
var _ring_material: StandardMaterial3D
var _shown_clip := ""
var _shown_at := -1.0


func _ready() -> void:
	visible = false   # nothing is built until a gesture is asked for, and it is freed again after the fade
	set_process(false)


## Taps at [param at] (the cauldron's rim), looping until [method stop].
func tap(at: Vector3) -> void:
	_start(Mode.TAP, [
		[0.0, 0.13, 0.05, 0.25],
		[TAP_DOWN, 0.006, 0.0, 0.25],
		[TAP_UP, 0.006, 0.0, 0.25],
		[TAP_BACK, 0.13, 0.05, 0.25],
		[TAP_LOOP, 0.13, 0.05, 0.25],
	], func() -> Vector3: return at, -0.55, false, at)


## Pinches [param gear] and lifts it a little, looping until [method stop]. It only shows the
## gesture: the real gear stays where it is. With [param straight_down] the hand comes down onto the thing
## from straight above instead of from the child's side, so it never travels toward anything (the shelf
## reminder uses it: the hand never leans toward a cubby).
func pinch_lift(gear: Node3D, straight_down := false) -> void:
	var side := 0.0 if straight_down else 0.07
	_start(Mode.PINCH_LIFT, [
		[0.0, 0.09, side, 1.0],
		[1.1, 0.0, 0.0, 1.0],
		[1.7, 0.0, 0.0, 0.0],
		[2.0, 0.0, 0.0, 0.0],
		[2.9, 0.05, 0.0, 0.0],
		[3.3, 0.05, 0.0, 0.0],
		[4.2, 0.0, 0.0, 0.0],
		[4.5, 0.0, 0.0, 0.0],
		[5.0, 0.0, 0.0, 1.0],
		[6.0, 0.09, side, 1.0],
		[6.6, 0.09, side, 1.0],
	], func() -> Vector3: return Carry.middle_of(gear) if is_instance_valid(gear) else Vector3.INF, -0.2, false, gear)


## Lowers over [param socket_at] and opens its fingers, looping until [method stop].
func lower_release(socket_at: Vector3) -> void:
	# The pinch point is where the gear's middle would be once seated (a little above the socket).
	_start(Mode.LOWER_RELEASE, [
		[0.0, 0.13, 0.0, 0.0],
		[1.3, 0.0, 0.0, 0.0],
		[1.9, 0.0, 0.0, 0.0],
		[2.4, 0.0, 0.0, 1.0],
		[3.3, 0.1, 0.05, 1.0],
		[3.8, 0.1, 0.05, 1.0],
	], func() -> Vector3: return socket_at + Vector3.UP * 0.026, -0.3, true, socket_at)


## Sweeps an open hand from [param from] to [param to] (world), fingers leading, looping until [method stop]:
## it waits at the start, slides across, waits at the end, fades, and comes again. It only shows the gesture
## (it is not tracked or judged, and moves nothing). The way is read level: a sweep never rises or falls.
func sweep(from: Vector3, to: Vector3) -> void:
	var way := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if way.length() < 0.01:
		return
	_sweep_way = way.normalized()
	_start(Mode.SWEEP, [
		[0.0, 0.0, 0.0, 1.0],
		[SWEEP_START, 0.0, 0.0, 1.0],
		[SWEEP_END, 0.0, 0.0, 1.0],
		[SWEEP_LOOP, 0.0, 0.0, 1.0],
	], func() -> Vector3: return from.lerp(to, smoothstep(SWEEP_START, SWEEP_END, _t)), -0.1, true, [from, to])


## Takes the hand away (soon, softly).
func stop() -> void:
	_mode = Mode.NONE
	_key = null


func _start(mode: Mode, keys: Array, anchor: Callable, pitch: float, fade_loop: bool, key: Variant) -> void:
	_ensure_built()
	if _mode == mode and is_same(_key, key):
		return   # already showing exactly this: asking again must not make it blink
	if _mode != Mode.NONE:
		_fade = 0.0   # one gesture at a time: the old one is gone before the new one shows
	_key = key
	_mode = mode
	_gesture = mode
	_keys = keys
	_length = keys[keys.size() - 1][0]
	_anchor = anchor
	_pitch = pitch
	_fade_loop = fade_loop
	_t = 0.0
	visible = true
	set_process(true)
	_pose(0.0)


func _process(delta: float) -> void:
	_fade = move_toward(_fade, 1.0 if _mode != Mode.NONE else 0.0, delta / FADE_SECONDS)
	if _mode == Mode.NONE:
		if _fade <= 0.0:
			_free_figure()   # gone: no hand node left, nothing running
			visible = false
			set_process(false)
		else:
			_pose(_t)
		return
	_t += delta
	if _t >= _length:
		_t = fposmod(_t, _length)
	_pose(_t)


## Puts the hand where the keys say at [param seconds], and sets its look.
func _pose(seconds: float) -> void:
	var up := 0.0
	var back := 0.0
	var open := 1.0
	for i in _keys.size() - 1:
		var a: Array = _keys[i]
		var b: Array = _keys[i + 1]
		if seconds >= a[0] and seconds <= b[0]:
			var k := smoothstep(0.0, 1.0, inverse_lerp(a[0], b[0], seconds))
			up = lerpf(a[1], b[1], k)
			back = lerpf(a[2], b[2], k)
			open = lerpf(a[3], b[3], k)
			break
	var anchor: Vector3 = _anchor.call()
	if not anchor.is_finite():
		stop()   # what it was showing is gone
		return
	var forward := Vector3.FORWARD   # away from the child
	if App.rig != null and App.head() != null:
		var flat := anchor - App.head().global_position
		flat.y = 0.0
		if flat.length() > 0.01:
			forward = flat.normalized()
	forward = forward.rotated(Vector3.UP, YAW)
	if _gesture == Mode.SWEEP:
		forward = _sweep_way   # an open hand sweeping: its fingers lead the way
	global_position = anchor + Vector3.UP * up - forward * back
	global_basis = Basis.looking_at(forward * cos(_pitch) + Vector3.UP * sin(_pitch), Vector3.UP)
	_show_fingers(open, seconds)
	_show_ring(anchor, seconds)
	var rounds := 1.0
	if _fade_loop:
		rounds = smoothstep(0.0, 0.5, seconds) * (1.0 - smoothstep(_length - 0.5, _length, seconds))
	_material.albedo_color.a = ALPHA * smoothstep(0.0, 1.0, _fade) * rounds


# --- The hand itself ------------------------------------------------------------------
# Its own frame: the pinch point (between the thumb's tip and the index finger's tip) is the
# origin, the fingers point along -z, the palm is behind them (+z), the index finger above
# (+y) and the thumb below (-y).

func _ensure_built() -> void:
	if _figure != null:
		return
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
		_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_material.albedo_color = Color(COLOUR, 0.0)
		_material.emission_enabled = true
		_material.emission = COLOUR
		_material.emission_energy_multiplier = 0.35
		_material.roughness = 0.9
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_figure = Node3D.new()
	add_child(_figure)
	if not (use_glb and _build_glb_hand()):
		_build_primitive_hand()


## Takes the hand away for good (after it has faded): nothing of it is left in the tree.
func _free_figure() -> void:
	if _figure != null:
		_figure.queue_free()
	_figure = null
	_ring = null
	_ring_material = null
	_player = null
	_skeleton = null
	_folded.clear()
	_index_rest.clear()
	_index_pressed.clear()
	_index.clear()
	_thumb.clear()
	_shown_clip = ""
	_shown_at = -1.0


## The contact moment of a tap: a thin ring spreads and fades on the rim, once a loop, from the instant the
## fingertip lands. (Nothing for the other gestures.)
func _show_ring(at: Vector3, seconds: float) -> void:
	if _gesture != Mode.TAP or _figure == null:
		if _ring != null:
			_ring.visible = false
		return
	if _ring == null:
		_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.9
		torus.outer_radius = 1.0   # scaled to the width wanted: a thin ring
		torus.rings = 48
		torus.ring_segments = 6
		_ring_material = StandardMaterial3D.new()
		_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_ring_material.albedo_color = Color(RING_COLOUR, 0.0)
		torus.material = _ring_material
		_ring.mesh = torus
		_ring.top_level = true   # stays on the rim, whatever the hand does
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_figure.add_child(_ring)
	var u := (seconds - TAP_DOWN) / RING_SECONDS
	_ring.visible = u >= 0.0 and u <= 1.0
	if _ring.visible:
		var spread := 1.0 - pow(1.0 - u, 2.0)   # quick at first, then slow
		_ring.global_position = at
		_ring.scale = Vector3(1.0, 0.4, 1.0) * lerpf(RING_FROM, RING_TO, spread)
		_ring_material.albedo_color.a = RING_ALPHA * (1.0 - u) * smoothstep(0.0, 1.0, _fade)


## The MRTK right hand from the GLB, turned to our frame and scaled. False (and nothing left behind)
## if the file is missing or is not what we expect: the caller then builds the primitive hand.
func _build_glb_hand() -> bool:
	if not ResourceLoader.exists(hand_file):
		return false
	var scene := load(hand_file) as PackedScene
	if scene == null:
		return false
	var model := scene.instantiate() as Node3D
	if model == null:
		return false
	var player := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if player == null or meshes.is_empty() or not player.has_animation(&"pinch") or not player.has_animation(&"tap"):
		model.free()
		return false
	var wrapper := Node3D.new()   # the one fixed correction lives here, not in the asset
	wrapper.rotation = Vector3(0.0, HAND_FIX_YAW + HAND_FIX_TRIM, HAND_ROLL)
	wrapper.scale = Vector3.ONE * HAND_SCALE
	_figure.add_child(wrapper)
	wrapper.add_child(model)
	for node in meshes:
		var mesh := node as MeshInstance3D
		mesh.material_override = _material   # ours, so that the fade works on whatever the file brought
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if player.has_animation(&"idle"):
		player.get_animation(&"idle").loop_mode = Animation.LOOP_LINEAR   # the import gives no loop flag
	_skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	_player = player
	_folded.clear()
	_index_rest.clear()
	_index_pressed.clear()
	_tap_tip = Vector3.ZERO
	if _skeleton != null:
		player.play(&"pinch")
		player.seek(1.0, true)   # closed: the fingers a pointing hand folds away are curled here
		player.pause()
		for bone in _skeleton.get_bone_count():
			for finger in FOLDED_FINGERS:
				if _skeleton.get_bone_name(bone).begins_with(finger):
					_folded[bone] = _skeleton.get_bone_pose_rotation(bone)
		player.play(&"tap")
		player.seek(0.0, true)
		player.pause()
		for bone in _skeleton.get_bone_count():
			if _skeleton.get_bone_name(bone).begins_with(INDEX_BONES):
				_index_rest[bone] = _skeleton.get_bone_pose_rotation(bone)
		player.seek(0.5, true)   # pressed
		for bone: int in _index_rest:
			_index_pressed[bone] = _skeleton.get_bone_pose_rotation(bone)
		_apply_tap_pose(1.0)   # the harder press this hand really makes: where the fingertip lands
		var tip := _skeleton.find_bone(INDEX_TIP_BONE)
		if tip >= 0:
			_tap_tip = _figure.to_local(_skeleton.to_global(_skeleton.get_bone_global_pose(tip).origin))
	player.play(&"pinch")
	player.seek(0.0, true)
	player.pause()   # from now on only scrubbed, never played
	_shown_clip = ""
	return true


## Puts the fingers where [param open] (and, for the tap, [param seconds] of the loop) say.
func _show_fingers(open: float, seconds: float) -> void:
	if _player == null:
		_pose_fingers(open)
		return
	var clip := &"pinch"
	var at := 0.0
	if _gesture == Mode.TAP:
		clip = &"tap"
		at = _tap_clip_at(seconds)
	else:
		at = (1.0 - clampf(open, 0.0, 1.0)) * _player.get_animation(clip).length   # open 1 -> 0, closed 0 -> the end
	if String(clip) != _shown_clip:
		_player.play(clip)
		_player.pause()
		_shown_clip = String(clip)
		_shown_at = -1.0
		# A tap points: the hand is placed so the index fingertip, not the pinch point, is on the rim.
		_figure.position = -_tap_tip if _gesture == Mode.TAP else Vector3.ZERO
	if not is_equal_approx(at, _shown_at):
		_player.seek(at, true)
		_shown_at = at
		if _gesture == Mode.TAP and _skeleton != null:
			_apply_tap_pose(1.0 - absf(at - 0.5) * 2.0)   # 0 at rest, 1 at the press


## The tap's fingers: the three other fingers folded, and the index finger [param press] (0 rest, 1 pressed)
## of the way to a press made TAP_PRESS_GAIN times harder than the clip makes it.
func _apply_tap_pose(press: float) -> void:
	for bone: int in _folded:
		_skeleton.set_bone_pose_rotation(bone, _folded[bone])
	for bone: int in _index_rest:
		var rest: Quaternion = _index_rest[bone]
		_skeleton.set_bone_pose_rotation(bone, rest.slerp(_index_pressed[bone], press * TAP_PRESS_GAIN))


## Where the "tap" clip is when the loop is at [param seconds]: down on the rim, pressed at 0.5, back.
func _tap_clip_at(seconds: float) -> float:
	if seconds < TAP_DOWN:
		return 0.5 * seconds / TAP_DOWN
	if seconds < TAP_UP:
		return 0.5
	if seconds < TAP_BACK:
		return 0.5 + 0.5 * (seconds - TAP_UP) / (TAP_BACK - TAP_UP)
	return 1.0


## The stand-in made of primitives (the fallback).
func _build_primitive_hand() -> void:
	var palm := MeshInstance3D.new()
	var palm_mesh := BoxMesh.new()
	palm_mesh.size = Vector3(0.022, 0.066, 0.07)
	palm_mesh.material = _material
	palm.mesh = palm_mesh
	palm.position = Vector3(0.0, 0.0, 0.088)
	_figure.add_child(palm)
	var curled := MeshInstance3D.new()   # the other fingers, folded in
	var curled_mesh := BoxMesh.new()
	curled_mesh.size = Vector3(0.02, 0.026, 0.03)
	curled_mesh.material = _material
	curled.mesh = curled_mesh
	curled.position = Vector3(0.0, 0.0, 0.052)
	_figure.add_child(curled)
	for bone in 2:
		_index.append(_new_bone())
		_thumb.append(_new_bone())
	_pose_fingers(1.0)


func _new_bone() -> MeshInstance3D:
	var bone := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = RADIUS
	capsule.material = _material
	capsule.radial_segments = 12
	capsule.rings = 4
	bone.mesh = capsule
	bone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_figure.add_child(bone)
	return bone


## [param open] 1: thumb and index well apart; 0: their tips meet at the pinch point.
func _pose_fingers(open: float) -> void:
	var gap := 0.003 + 0.032 * open
	var knuckle := Vector3(0.0, 0.03, 0.05)
	var tip := Vector3(0.0, gap, 0.0)
	var middle := knuckle.lerp(tip, 0.5) + Vector3(0.0, 0.009, 0.0)
	_bone(_index[0], knuckle, middle)
	_bone(_index[1], middle, tip)
	var base := Vector3(0.0, -0.026, 0.074)
	var thumb_tip := Vector3(0.0, -gap, 0.0)
	var thumb_middle := base.lerp(thumb_tip, 0.5) + Vector3(0.0, -0.009, 0.0)
	_bone(_thumb[0], base, thumb_middle)
	_bone(_thumb[1], thumb_middle, thumb_tip)


## Stretches the capsule [param bone] from [param a] to [param b].
func _bone(bone: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	(bone.mesh as CapsuleMesh).height = length + 2.0 * RADIUS
	var along := (b - a).normalized()
	bone.transform = Transform3D(Basis(Quaternion(Vector3.UP, along)), (a + b) * 0.5)
