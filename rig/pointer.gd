class_name Pointer
extends Node3D
## One tracked hand's pointing ray and fingertip, turned into [Events]: every
## button, [signal Events.selected] on a pinch (the OpenXR action
## trigger_click), [signal Events.touched] when the moving fingertip enters a
## [Target], [signal Events.help_requested] when the hand is raised, and
## tracking changes. A resting hand touches nothing: a toy that appears under
## it, or hops into it, was not reached for. In blocks without the ray
## ([member Block.ray]) a pinch or a closed hand on a Target takes it, like a touch.
##
## The ray only hits Targets (physics layer "targets"): real surfaces never block
## it, so pointing works the same over passthrough and in the simulated room.

const TARGET_LAYER := 1
## How close the fingertip must be to a Target to grab it, metres.
const GRAB_RADIUS := 0.07

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
## A sweep: one move of the hand, from leaving rest (faster than
## [member sweep_speed]) to resting again (slower than [member sweep_stop_speed]
## for [member sweep_stop_seconds]), or [member sweep_max_seconds] of moving.
## The move is cut into legs where the hand turns back ([member sweep_return]
## metres from a leg's farthest point) and the longest leg is the sweep: the
## wind-up before it and the way back after it are not, unless one of them is
## [member sweep_longer] times longer. No pinch is involved: hand tracking drops
## a pinch as the hand moves. A step too long for a hand in one tick is tracking
## finding the hand again, never a sweep, and a pause drops one in progress.
@export var sweep_speed := 0.3
@export var sweep_stop_speed := 0.12
@export var sweep_stop_seconds := 0.12
@export var sweep_max_seconds := 2.0
@export var sweep_return := 0.06
@export var sweep_longer := 1.25
@export var sweep_jump := 0.08
## Seconds the speed is smoothed over.
@export var sweep_smoothing := 0.05

## &"left" or &"right".
var side: StringName
## The Target the ray points at now, or null.
var aimed: Target

@onready var _controller := get_parent() as XRController3D
var _beam: MeshInstance3D
var _distance := 0.0
## Where the fingertip last moved to, and for how long it has stayed near it.
var _rest_at := Vector3.INF
var _rest_for := 0.0
var _raised_for := 0.0
var _asked := false
var _last_position := Vector3.INF
var _velocity := Vector3.ZERO
## Where the hand last moved slower than [member sweep_speed]: a move starts there.
var _slow_at := Vector3.ZERO
## Seconds of this hand's clock (pauses do not count).
var _clock := 0.0
## The move in progress: when it began, the leg being made (where it began and
## when, its farthest point and when), the longest leg so far, and how long the
## hand has been slow.
var _moving := false
var _move_began := 0.0
var _leg_from := Vector3.ZERO
var _leg_began := 0.0
var _leg_far := Vector3.ZERO
var _leg_far_at := 0.0
var _best: Dictionary = {}
var _slow_for := 0.0


func _ready() -> void:
	side = &"left" if _controller.name == &"LeftHand" else &"right"
	_controller.button_pressed.connect(_on_button.bind(true))
	_controller.button_released.connect(_on_button.bind(false))
	_controller.tracking_changed.connect(func(tracked: bool) -> void: Events.hand_tracking.emit(side, tracked))
	_build()


func _process(_delta: float) -> void:
	_beam.visible = ray_on()
	aimed = cast() if _beam.visible else null
	_beam.scale.z = _distance
	_beam.position.z = -_distance * 0.5


## The ray points: while the facilitator panel is open, and in blocks that use it.
func ray_on() -> bool:
	var panel := App.module(&"Facilitator")
	if panel and panel.is_open:
		return true
	return App.session == null or App.session.block == null or App.session.block.ray


func _physics_process(delta: float) -> void:
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
		_moving = false
		_velocity = Vector3.ZERO
		_slow_at = here
		return
	_clock += delta
	_velocity = _velocity.lerp(step / delta, minf(1.0, delta / sweep_smoothing))
	var speed := _velocity.length()
	if not _moving:
		if step.length() / delta < sweep_speed:
			_slow_at = here
		if speed >= sweep_speed:
			_moving = true
			_move_began = _clock
			_best = {}
			_slow_for = 0.0
			_start_leg(_slow_at, _clock)
		return
	if here.distance_to(_leg_from) > _leg_far.distance_to(_leg_from):
		_leg_far = here
		_leg_far_at = _clock
	elif here.distance_to(_leg_far) > sweep_return:
		_end_leg()
		_start_leg(_leg_far, _leg_far_at)
	_slow_for = _slow_for + delta if speed < sweep_stop_speed else 0.0
	if _slow_for >= sweep_stop_seconds or _clock - _move_began >= sweep_max_seconds:
		_end_leg()
		_moving = false
		Events.swept.emit(side, _best.from, _best.to, _best.seconds)


func _start_leg(from: Vector3, at: float) -> void:
	_leg_from = from
	_leg_began = at
	_leg_far = from
	_leg_far_at = at


## Keeps the leg just made if it is the longest of this move so far.
func _end_leg() -> void:
	var length := _leg_far.distance_to(_leg_from)
	if _best.is_empty() or length > _best.length * sweep_longer:
		_best = {from = _leg_from, to = _leg_far, seconds = _leg_far_at - _leg_began, length = length}


## The fingertip has not moved for [member rest_seconds].
func resting() -> bool:
	return _rest_for >= rest_seconds


## The Target under the ray, or null.
func cast() -> Target:
	var query := PhysicsRayQueryParameters3D.create(global_position,
		global_position - global_basis.z * length, TARGET_LAYER)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_distance = global_position.distance_to(hit.position) if hit else length
	return hit.collider as Target if hit else null


## Where the fingertip is.
func tip() -> Vector3:
	return global_position - global_basis.z * tip_reach


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
	query.collision_mask = TARGET_LAYER
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
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.003, 0.003, 1.0)
	mesh.material = material
	_beam = MeshInstance3D.new()
	_beam.mesh = mesh
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_beam)
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
	finger.area_entered.connect(func(area: Area3D) -> void:
		if area is Target and not resting():
			Events.touched.emit(side, area))
	add_child(finger)
