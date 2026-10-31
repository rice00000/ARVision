class_name Pointer
extends Node3D
## One tracked hand's pointing ray and fingertip, turned into [Events]: every
## button, [signal Events.selected] on a pinch (the OpenXR action
## trigger_click), [signal Events.touched] when the moving fingertip enters a
## [Target], [signal Events.sweeping] and [signal Events.swept] as it sweeps,
## [signal Events.help_requested] when the hand is raised, and tracking
## changes. A resting hand touches nothing: a toy that appears under
## it, or hops into it, was not reached for. In blocks without the ray
## ([member Block.ray]) a pinch or a closed hand on a Target takes it, like a touch.
##
## The ray only hits Targets (physics layer "targets"): real surfaces never block
## it, so pointing works the same over passthrough and in the simulated room.

const TARGET_LAYER := 1
const MENU_LAYER := 4
## How close the fingertip must be to a Target to grab it, metres.
const GRAB_RADIUS := 0.07
## A hand rising or falling more steeply than this (the sine of 50 degrees) is not sweeping.
const VERTICAL := 0.77

@export var length := 4.0
## How far in front of the hand's aim point the fingertip sits.
@export var tip_reach := 0.05
## The fingertip rests once it has stayed within [member rest_radius] metres
## for [member rest_seconds].
@export var rest_radius := 0.015
@export var rest_seconds := 0.3
## A hand held [member raise_height] metres above the eyes for
## [member raise_seconds] asks for help, like a raised hand in class. It asks
## again only after coming down. Raised in front, it stays in the cameras' view.
@export var raise_height := 0.1
@export var raise_seconds := 0.4
## A sweep: the hand going faster than [member sweep_speed] at least
## [member sweep_distance] sideways, toward or away. It sets off where the hand
## was last slower, or moving mostly up or down (a hand raised for help sweeps
## nothing; one lifted on its way sweeps from where it levels out), or where it
## turned back [member sweep_return] metres from its farthest point. Every tick it goes on, [signal Events.sweeping] says how far
## it has got, so a trial can answer the moment the hand goes the right way.
## Once the hand has been slower again for [member sweep_stop_seconds] (a turn
## is quicker), [signal Events.swept] says it is done. No pinch is involved: hand
## tracking drops a pinch as the hand moves. A step too long for a hand in one
## tick is tracking finding the hand again, never a sweep, and a pause drops one
## in progress.
## Lowered from 0.3 to 0.2 with Megan's OK (Oct 31): a seated child's slow, careful sweep peaks near 0.35 m/s
## and any tracking jitter took it under 0.3 (by simulation, see entry/DEV_NOTES.md); a resting or slowly
## drifting hand still makes no sweep at 0.2, and Wei's 0.15 m/s "creep" test still holds.
@export var sweep_speed := 0.2
@export var sweep_distance := 0.12
@export var sweep_return := 0.06
@export var sweep_stop_seconds := 0.4
@export var sweep_jump := 0.08
## Seconds the speed is smoothed over.
@export var sweep_smoothing := 0.05

## &"left" or &"right".
var side: StringName
## The Target the ray points at now, or null.
var aimed: Target

@onready var _controller := get_parent() as XRController3D
var _finger: Area3D
var _marker: MeshInstance3D
var _last_tip := Vector3.INF
var _tip_moved := false
## Where the fingertip last moved to, and for how long it has stayed near it.
var _rest_at := Vector3.INF
var _rest_for := 0.0
var _raised_for := 0.0
var _asked := false
var _last_position := Vector3.INF
var _velocity := Vector3.ZERO
## Seconds of this hand's clock (pauses do not count).
var _clock := 0.0
## The sweep in progress: where it set off and when, its farthest point and when.
var _from := Vector3.ZERO
var _from_at := 0.0
var _far := Vector3.ZERO
var _far_at := 0.0
## The hand has swept and not stopped since; how long it has been slow.
var _swept := false
var _slow_for := 0.0


func _ready() -> void:
	side = &"left" if _controller.name == &"LeftHand" else &"right"
	_controller.button_pressed.connect(_on_button.bind(true))
	_controller.button_released.connect(_on_button.bind(false))
	_controller.tracking_changed.connect(func(tracked: bool) -> void: Events.hand_tracking.emit(side, tracked))
	_build()


func _process(_delta: float) -> void:
	_finger.collision_mask = _input_layer()
	aimed = cast() if ray_on() else null
	_marker.visible = App.xr == null and tracked()


## The ray points: while the facilitator panel is open, and in blocks that use it.
func ray_on() -> bool:
	var panel := App.module(&"Facilitator")
	if panel and panel.is_open:
		return true
	return App.session == null or App.session.block == null or App.session.block.ray


func _physics_process(delta: float) -> void:
	_finger.monitoring = tracked()
	var fingertip := tip()
	_tip_moved = _last_tip.is_finite() and not fingertip.is_equal_approx(_last_tip)
	_last_tip = fingertip
	_finger.global_position = fingertip
	if tip().distance_to(_rest_at) > rest_radius:
		_rest_at = tip()
		_rest_for = 0.0
	else:
		_rest_for += delta
	var up := _controller.get_has_tracking_data() and global_position.y > App.head().global_position.y + raise_height
	_raised_for = _raised_for + delta if up else 0.0
	_asked = _asked and up
	if _raised_for >= raise_seconds and not _asked:
		_asked = true
		Events.help_requested.emit()
	_track_sweep(delta)


func _track_sweep(delta: float) -> void:
	var here := global_position
	var step := here - _last_position
	_last_position = here
	if get_tree().paused or not _controller.get_has_tracking_data() or step.length() > sweep_jump:
		_velocity = Vector3.ZERO
		_set_off(here, _clock)
		return
	_clock += delta
	_velocity = _velocity.lerp(step / delta, minf(1.0, delta / sweep_smoothing))
	if _velocity.length() < sweep_speed:
		_set_off(here, _clock)
		_slow_for += delta
		if _swept and _slow_for >= sweep_stop_seconds:
			_swept = false
			Events.swept.emit(side)
		return
	_slow_for = 0.0
	if absf(_velocity.y) > _velocity.length() * VERTICAL:
		_set_off(here, _clock)
		return
	if here.distance_to(_from) > _far.distance_to(_from):
		_far = here
		_far_at = _clock
	elif here.distance_to(_far) > sweep_return:
		_set_off(_far, _far_at)
	var way := here - _from
	if Vector2(way.x, way.z).length() >= sweep_distance:
		_swept = true
		Events.sweeping.emit(side, _from, here, _clock - _from_at)


## A sweep sets off from [param at], at [param time] of this hand's clock.
func _set_off(at: Vector3, time: float) -> void:
	_from = at
	_from_at = time
	_far = at
	_far_at = time


## The fingertip has not moved for [member rest_seconds].
func resting() -> bool:
	return _rest_for >= rest_seconds


## The Target under the ray, or null.
func cast() -> Target:
	var query := PhysicsRayQueryParameters3D.create(global_position,
		global_position - global_basis.z * length, _input_layer())
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.collider as Target if hit else null


## The open panel owns input, even when a game target sits in front of it.
func _input_layer() -> int:
	var panel := App.module(&"Facilitator")
	return MENU_LAYER if panel and panel.is_open else TARGET_LAYER


## Where the fingertip is.
func tip() -> Vector3:
	var hand := App.rig.tracked_hand(side)
	if hand.has_joints():
		return hand.fingertip()
	return global_position - global_basis.z * tip_reach


## The pinch between thumb and index, oriented with the palm. Desktop uses its synthetic tip.
func grip() -> Transform3D:
	var hand := App.rig.tracked_hand(side)
	if hand.has_joints():
		return hand.pinch()
	return Transform3D(global_basis, tip())


func tracked() -> bool:
	return App.rig.tracked_hand(side).has_joints() if App.xr != null else _controller.get_has_tracking_data()


func _on_button(action: String, pressed: bool) -> void:
	Events.button.emit(side, StringName(action), pressed)
	if not pressed:
		return
	if action == "trigger_click" and ray_on():
		Events.selected.emit(side, cast(), global_position, -global_basis.z)
	elif action in ["trigger_click", "grip_click"]:
		_grab()


## Takes the Target nearest the fingertip, if one is within [constant GRAB_RADIUS].
func _grab() -> void:
	var ball := SphereShape3D.new()
	ball.radius = GRAB_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = ball
	query.transform = Transform3D(Basis.IDENTITY, tip())
	query.collision_mask = _input_layer()
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var near: Target
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 8):
		var target := hit.collider as Target
		if target and (near == null or target.global_position.distance_to(tip()) < near.global_position.distance_to(tip())):
			near = target
	if near:
		Events.touched.emit(side, near)


func _build() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.45)
	var finger := Area3D.new()
	finger.name = "Tip"
	finger.position = Vector3(0, 0, -tip_reach)
	finger.collision_layer = 0
	finger.collision_mask = TARGET_LAYER
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	(shape.shape as SphereShape3D).radius = 0.02
	finger.add_child(shape)
	var ball := MeshInstance3D.new()
	ball.mesh = SphereMesh.new()
	(ball.mesh as SphereMesh).radius = 0.012
	(ball.mesh as SphereMesh).height = 0.024
	(ball.mesh as SphereMesh).material = material
	finger.add_child(ball)
	_finger = finger
	_marker = ball
	finger.area_entered.connect(func(area: Area3D) -> void:
		if area is Target and _tip_moved and not resting():
			Events.touched.emit(side, area))
	add_child(finger)
