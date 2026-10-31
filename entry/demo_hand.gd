class_name DemoHand
extends Node3D
## A softly translucent teaching hand from primitives (a palm, curled fingers, a thumb and an
## index finger; no textures). It shows ONE gesture at a time and loops it until [method stop]:
## a tap on the cauldron, a pinch that lifts the gear, a lowering and opening over the socket.
## It never moves the real gear, never flashes, and its calls return at once: everything it
## does runs from its own [method _process], so [method stop] (or freeing it) cancels it, and
## nothing waits on a timer or a tween that could outlive a part.
## Later the MRTK Hand Coach rigs may replace the stand-in (see hand-coach/README.md).

const COLOUR := Color(0.96, 0.9, 0.8)
## How solid it looks at most, and how long it takes to appear or go, seconds.
const ALPHA := 0.4
const FADE_SECONDS := 0.4
const RADIUS := 0.0085

enum Mode { NONE, TAP, PINCH_LIFT, LOWER_RELEASE }

var _mode := Mode.NONE
var _t := 0.0
var _fade := 0.0
var _keys: Array = []           # [seconds, up, back, open]: where the pinch point is, and how open
var _length := 0.0
var _anchor := Callable()       # () -> Vector3: the spot the keys are measured from
var _pitch := 0.0               # radians, negative: pointing down
var _fade_loop := false         # fade out and in between rounds (when the end does not match the start)
var _material: StandardMaterial3D
var _figure: Node3D
var _index: Array[MeshInstance3D] = []
var _thumb: Array[MeshInstance3D] = []


func _ready() -> void:
	_ensure_built()
	visible = false
	set_process(false)


## Taps at [param at] (the cauldron's rim), looping until [method stop].
func tap(at: Vector3) -> void:
	_start(Mode.TAP, [
		[0.0, 0.13, 0.05, 0.25],
		[0.9, 0.012, 0.0, 0.25],
		[1.2, 0.012, 0.0, 0.25],
		[2.0, 0.13, 0.05, 0.25],
		[3.0, 0.13, 0.05, 0.25],
	], func() -> Vector3: return at, -0.55, false)


## Pinches [param gear] and lifts it a little, looping until [method stop]. It only shows the
## gesture: the real gear stays where it is.
func pinch_lift(gear: Node3D) -> void:
	_start(Mode.PINCH_LIFT, [
		[0.0, 0.09, 0.07, 1.0],
		[1.1, 0.0, 0.0, 1.0],
		[1.7, 0.0, 0.0, 0.0],
		[2.0, 0.0, 0.0, 0.0],
		[2.9, 0.05, 0.0, 0.0],
		[3.3, 0.05, 0.0, 0.0],
		[4.2, 0.0, 0.0, 0.0],
		[4.5, 0.0, 0.0, 0.0],
		[5.0, 0.0, 0.0, 1.0],
		[6.0, 0.09, 0.07, 1.0],
		[6.6, 0.09, 0.07, 1.0],
	], func() -> Vector3: return Carry.middle_of(gear) if is_instance_valid(gear) else Vector3.ZERO, -0.2, false)


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
	], func() -> Vector3: return socket_at + Vector3.UP * 0.026, -0.3, true)


## Takes the hand away (soon, softly).
func stop() -> void:
	_mode = Mode.NONE


func _start(mode: Mode, keys: Array, anchor: Callable, pitch: float, fade_loop: bool) -> void:
	_ensure_built()
	if _mode != Mode.NONE:
		_fade = 0.0   # one gesture at a time: the old one is gone before the new one shows
	_mode = mode
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
	var forward := Vector3.FORWARD   # away from the child
	if App.head() != null:
		var flat := anchor - App.head().global_position
		flat.y = 0.0
		if flat.length() > 0.01:
			forward = flat.normalized()
	global_position = anchor + Vector3.UP * up - forward * back
	global_basis = Basis.looking_at(forward * cos(_pitch) + Vector3.UP * sin(_pitch), Vector3.UP)
	_pose_fingers(open)
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
	_figure = Node3D.new()
	add_child(_figure)
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(COLOUR, 0.0)
	_material.emission_enabled = true
	_material.emission = COLOUR
	_material.emission_energy_multiplier = 0.35
	_material.roughness = 0.9
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
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
