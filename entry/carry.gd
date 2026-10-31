class_name Carry
extends Node
## The child pinches the gear, carries it, and sets it into the socket.
##
## Pick-up: a pinch whose pinch point ([method Pointer.grip]) is within [constant GRAB_RADIUS]
## of the gear's middle takes it. It then follows the hand (the contact offset and the hand's
## rotation are kept). On desktop the same path works: left-click-hold near it.
##
## Release: inside a generous volume around the socket it aligns itself (a short tween to the
## socket pose, upright, turned to the panel), the hint sounds once, and it is docked. Anywhere
## else it floats gently down to the nearest table spot under it, within reach. There is no
## failure, no score and no extra gesture. Tracking lost, a pause or the scene leaving: it is let
## go and settled within reach, quietly.
##
## While handled the gear is stopped; the story chat starts the turning after [signal docked].
## The seating click belongs to the story chat. The same chat can skip an obsolete prompt with
## [method has_been_picked_up], [method has_docked] and [member held].

## The child picked the gear up.
signal picked_up
## The child let go (docked: it went into the socket).
signal released(docked: bool)
## The gear is in the socket (after the auto-align and the click).
signal docked
## The gear has been in view for [member remind_after] seconds and the child has not touched it.
## Once per [method begin]. The listener may show the teaching hand (it must never carry the gear).
signal reminder_due

## The child may pick it up now (the story turns this on after asking).
var enabled := false
## A hand is holding it.
var held := false
## Seconds the gear may wait, in view and untouched, before [signal reminder_due]; 0 = never.
var remind_after := 0.0

## How near the pinch point must be to the gear's middle, metres ("about 9 cm").
const GRAB_RADIUS := 0.09
## The acceptance volume around the socket: sideways, and how far below the socket a gear may
## be and still count. Any height above counts (a gear held over the socket is meant for it).
const ACCEPT_SIDE := 0.12
const ACCEPT_BELOW := 0.06
## Seconds of the auto-align when the gear is within a few cm of the socket (farther: a little more).
const ALIGN_SECONDS := 0.25
## Seconds of the gentle float down to the table.
const SETTLE_SECONDS := 0.7
## A tracking gap shorter than this is ignored (hand tracking blinks).
const TRACK_GRACE := 0.25
## A pinch that closes a moment before the hand arrives still takes the gear for this long.
const PRESS_GRACE := 0.25
## Gear and panel: a settled gear stays this far (centre to socket) from the panel, metres.
const PANEL_CLEAR := 0.23
## Radius of the socket's outline, metres.
const HINT_RADIUS := 0.0725

# --- Set by Entry (see Entry._configure_interaction), with sensible fallbacks ---
## The tabletop's height (world y). NAN: worked out from the socket.
var table_y := NAN
## Where the child can reach from (flat), and how far; 0 = no limit.
var reach_from := Vector3.ZERO
var reach_radius := 0.0
## How the panel is turned (yaw, radians): the docked gear faces the child.
var socket_yaw := 0.0
## A spot to keep clear of (the cauldron) and its radius; Vector3.INF = none.
var avoid_at := Vector3.INF
var avoid_radius := 0.0

enum State { IDLE, HELD, ALIGNING, SETTLING, DOCKED }
var _state := State.IDLE

var _gear: Node3D
var _spin: GearSpin
var _socket_at := Vector3.ZERO
var _side: StringName = &"right"
var _offset := Transform3D.IDENTITY   # the gear in the pinch's own frame, at pick-up
var _scale := Vector3.ONE
var _pinching: Dictionary = {}        # side -> the pinch is closed
var _press_age: Dictionary = {}       # side -> seconds since it closed, while still looking
var _lost_for := 0.0
var _picked := false
var _docked := false
var _tween: Tween
var _hint: MeshInstance3D
var _hint_material: StandardMaterial3D
var _hint_level := 0.0
var _clock := 0.0
var _idle := 0.0
var _reminded := false


func _ready() -> void:
	Events.button.connect(_on_button)
	Events.facilitator_toggled.connect(func(open: bool) -> void:
		if open:
			_let_go())
	Events.scene_changing.connect(stop)


## Configures the surroundings. [param floor_y] is the tabletop, [param eyes] and [param reach] say
## how far the child can reach, [param yaw] turns the docked gear to the panel, and the gear
## never settles on [param keep_clear_at] (the cauldron) within [param keep_clear_radius].
func configure(floor_y: float, eyes: Vector3, reach: float, yaw: float, keep_clear_at := Vector3.INF, keep_clear_radius := 0.0) -> void:
	table_y = floor_y
	reach_from = Vector3(eyes.x, 0.0, eyes.z)
	reach_radius = reach
	socket_yaw = yaw
	avoid_at = keep_clear_at
	avoid_radius = keep_clear_radius


## Starts watching for [param gear] to be picked up and set into the socket at [param socket_at].
func begin(gear: Node3D, socket_at: Vector3) -> void:
	_kill_tween()
	_gear = gear
	_socket_at = socket_at
	_spin = null
	for child in gear.get_children():
		if child is GearSpin:
			_spin = child
	if is_nan(table_y):
		table_y = socket_at.y - 0.012
	held = false
	_state = State.IDLE
	_picked = false
	_docked = false
	_pinching.clear()
	_press_age.clear()
	_lost_for = 0.0
	_idle = 0.0
	_reminded = false
	_make_hint()
	enabled = true


## The child may not handle the gear any more. If it is in a hand, it is let go and settled.
func stop() -> void:
	enabled = false
	if held:
		_let_go()


## True once the child has picked the gear up (since [method begin]).
func has_been_picked_up() -> bool:
	return _picked


## True once the gear sits in the socket (since [method begin]).
func has_docked() -> bool:
	return _docked


## STUB, kept for the story chat's tests: pretends the child picked it up and set it in. The gear
## really aligns into the socket, like after a real release.
func simulate(after := 1.0) -> void:
	await get_tree().create_timer(after).timeout
	if _gear == null:
		picked_up.emit()
		await get_tree().create_timer(after).timeout
		released.emit(true)
		docked.emit()
		return
	_picked = true
	if _spin != null:
		_spin.running = false
	picked_up.emit()
	await get_tree().create_timer(after).timeout
	_dock()


## The middle of [param gear], world: what a pinch must be near to take it.
static func middle_of(gear: Node3D) -> Vector3:
	var inverse := gear.global_transform.affine_inverse()
	var low := Vector3.INF
	var high := -Vector3.INF
	var meshes := gear.find_children("*", "MeshInstance3D", true, false)
	for node in meshes:
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		var box := mesh.get_aabb()
		var to_gear := inverse * mesh.global_transform
		for i in 8:
			var corner := to_gear * (box.position + box.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1))
			low = low.min(corner)
			high = high.max(corner)
	if low == Vector3.INF:
		return gear.global_position
	return gear.global_transform * ((low + high) * 0.5)


# --- Input ---------------------------------------------------------------------

func _on_button(side: StringName, action: StringName, pressed: bool) -> void:
	if action != &"trigger_click":
		return
	_pinching[side] = pressed
	if pressed:
		_press_age[side] = 0.0
		_try_pick_up(side)
	else:
		_press_age.erase(side)
		if held and side == _side:
			_release()


func _process(delta: float) -> void:
	_clock += delta
	_update_hint(delta)
	_watch_for_idle(delta)
	for side: StringName in _press_age.keys():
		_press_age[side] += delta
		if _press_age[side] > PRESS_GRACE:
			_press_age.erase(side)
		else:
			_try_pick_up(side)
	if not held or App.rig == null:
		return
	var pointer := App.rig.pointer(_side)
	if not pointer.tracked():
		_lost_for += delta
		if _lost_for > TRACK_GRACE:
			_let_go()
		return
	_lost_for = 0.0
	_follow(pointer.grip(), delta)


## Counts the seconds the gear waits in view, untouched, and says so once.
func _watch_for_idle(delta: float) -> void:
	if remind_after <= 0.0 or _reminded or not enabled or _picked or _gear == null or not is_instance_valid(_gear) or not _gear.visible:
		return
	_idle += delta
	if _idle >= remind_after:
		_reminded = true
		reminder_due.emit()


# --- Picking up and carrying -------------------------------------------------------

func _try_pick_up(side: StringName) -> void:
	if not enabled or held or _gear == null or not is_instance_valid(_gear) or not _gear.visible or App.rig == null:
		return
	if _state == State.ALIGNING or _state == State.DOCKED:
		return
	var pointer := App.rig.pointer(side)
	if not pointer.tracked():
		return
	var pinch := pointer.grip()
	if pinch.origin.distance_to(middle_of(_gear)) > GRAB_RADIUS:
		return
	_kill_tween()   # a gear still floating down can be taken again
	_side = side
	held = true
	_state = State.HELD
	_lost_for = 0.0
	_press_age.erase(side)
	var hand := Transform3D(pinch.basis.orthonormalized(), pinch.origin)
	var now := _gear.global_transform
	_scale = now.basis.get_scale()
	_offset = hand.affine_inverse() * Transform3D(now.basis.orthonormalized(), now.origin)
	if _spin != null:
		_spin.running = false
	_picked = true
	picked_up.emit()


func _follow(pinch: Transform3D, delta: float) -> void:
	var hand := Transform3D(pinch.basis.orthonormalized(), pinch.origin)
	var want := hand * _offset
	var keep := 1.0 - exp(-delta * 30.0)   # a little smoothing: tracking is jittery
	var at := _gear.global_position.lerp(want.origin, keep)
	var turn := _gear.global_basis.orthonormalized().get_rotation_quaternion().slerp(want.basis.get_rotation_quaternion(), keep)
	at.y = maxf(at.y, table_y)   # never through the table
	_gear.global_transform = Transform3D(Basis(turn) * Basis.from_scale(_scale), at)


# --- Letting go ---------------------------------------------------------------------

## The pinch opened: into the socket if it is over it, otherwise onto the table.
func _release() -> void:
	held = false
	if _inside_socket_volume():
		_dock()
	else:
		released.emit(false)
		_settle()


## Tracking lost, a pause, or the scene leaving: settled quietly, never docked.
func _let_go() -> void:
	if not held:
		return
	held = false
	released.emit(false)
	_settle()


func _inside_socket_volume() -> bool:
	var p := _gear.global_position
	var sideways := Vector2(p.x - _socket_at.x, p.z - _socket_at.z).length()
	return sideways <= ACCEPT_SIDE and p.y - _socket_at.y >= -ACCEPT_BELOW


## Auto-align into the socket: one click, then docked.
func _dock() -> void:
	_kill_tween()
	_state = State.ALIGNING
	held = false
	var from := _gear.global_transform
	var from_q := from.basis.orthonormalized().get_rotation_quaternion()
	var to_q := Quaternion(Vector3.UP, socket_yaw)
	var size := from.basis.get_scale()
	var high := maxf(from.origin.y - _socket_at.y - 0.08, 0.0)
	var seconds := clampf(ALIGN_SECONDS + high * 2.0, ALIGN_SECONDS, 0.7)
	_tween = create_tween()
	_tween.tween_method(func(k: float) -> void:
		_gear.global_transform = Transform3D(Basis(from_q.slerp(to_q, k)) * Basis.from_scale(size),
			from.origin.lerp(_socket_at, k)), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished
	if _state != State.ALIGNING:
		return   # begin() or stop() cut in
	_gear.global_transform = Transform3D(Basis(to_q) * Basis.from_scale(size), _socket_at)
	_state = State.DOCKED
	_docked = true
	Events.feedback.emit(&"hint", _socket_at)
	released.emit(true)
	docked.emit()


## Floats gently down to the nearest table spot under it, within reach.
func _settle() -> void:
	_kill_tween()
	_state = State.SETTLING
	var from := _gear.global_transform
	var size := from.basis.get_scale()
	var from_q := from.basis.orthonormalized().get_rotation_quaternion()
	var to_q := Quaternion(Vector3.UP, _yaw_of(from.basis))
	var to := _settle_spot(from.origin)
	_tween = create_tween()
	_tween.tween_method(func(k: float) -> void:
		_gear.global_transform = Transform3D(Basis(from_q.slerp(to_q, k)) * Basis.from_scale(size),
			from.origin.lerp(to, k)), 0.0, 1.0, SETTLE_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _tween.finished
	if _state == State.SETTLING:
		_state = State.IDLE


## The table spot for a gear let go at [param p]: the one nearest straight below it that is within
## reach and clear of the cauldron and the panel.
func _settle_spot(p: Vector3) -> Vector3:
	var wanted := Vector3(p.x, table_y, p.z)
	if _spot_is_free(wanted):
		return wanted
	var best := wanted
	var best_gap := INF
	for ring in range(1, 17):
		for step in 24:
			var offset := Vector3.RIGHT.rotated(Vector3.UP, step * TAU / 24.0) * (ring * 0.025)
			var spot := wanted + offset
			var gap := offset.length()
			if gap < best_gap and _spot_is_free(spot):
				best = spot
				best_gap = gap
		if best_gap < INF:
			return best   # nothing farther out can be nearer
	# Nowhere free (a room too small for it): at least within reach.
	var out := Vector3(wanted.x - reach_from.x, 0.0, wanted.z - reach_from.z)
	if reach_radius > 0.0 and out.length() > reach_radius:
		var kept := reach_from + out.normalized() * reach_radius
		return Vector3(kept.x, table_y, kept.z)
	return wanted


func _spot_is_free(spot: Vector3) -> bool:
	if reach_radius > 0.0 and Vector2(spot.x - reach_from.x, spot.z - reach_from.z).length() > reach_radius:
		return false
	if avoid_at != Vector3.INF and Vector2(spot.x - avoid_at.x, spot.z - avoid_at.z).length() < avoid_radius:
		return false
	return Vector2(spot.x - _socket_at.x, spot.z - _socket_at.z).length() >= PANEL_CLEAR


## The direction a gear faces, about the vertical, whatever its tilt.
func _yaw_of(basis: Basis) -> float:
	var z := basis.orthonormalized().z
	if Vector2(z.x, z.z).length() > 0.3:
		return atan2(z.x, z.z)
	var x := basis.orthonormalized().x
	return atan2(-x.z, x.x)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


# --- The socket hint -------------------------------------------------------------------

## A thin outline around the socket, shown while the gear is in a hand: a slow, steady
## brightness change, nothing that flashes.
func _make_hint() -> void:
	if _hint == null:
		_hint = MeshInstance3D.new()
		_hint.name = "SocketHint"
		_hint.top_level = true
		var ring := TorusMesh.new()
		ring.inner_radius = HINT_RADIUS - 0.003
		ring.outer_radius = HINT_RADIUS + 0.003
		ring.rings = 48
		ring.ring_segments = 8
		_hint_material = StandardMaterial3D.new()
		_hint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_hint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_hint_material.albedo_color = Color(1.0, 0.95, 0.78, 0.0)
		ring.material = _hint_material
		_hint.mesh = ring
		_hint.visible = false
		_hint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_hint)
	_hint.global_position = _socket_at + Vector3.UP * 0.004
	_hint_level = 0.0


func _update_hint(delta: float) -> void:
	if _hint == null:
		return
	var want := 1.0 if held else 0.0
	_hint_level = move_toward(_hint_level, want, delta / 0.5)
	_hint.visible = _hint_level > 0.0
	if _hint.visible:
		var breathe := 0.5 + 0.5 * sin(_clock * TAU / 4.0)   # one slow swell every 4 seconds
		_hint_material.albedo_color.a = _hint_level * lerpf(0.3, 0.65, breathe)
