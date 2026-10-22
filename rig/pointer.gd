class_name Pointer
extends Node3D
## One controller's pointing ray and fingertip, turned into [Events]: every
## button, [signal Events.selected] when the trigger is pulled,
## [signal Events.touched] when the fingertip enters a [Target], and tracking
## changes.
##
## The ray only hits Targets (physics layer "targets"): real surfaces never block
## it, so pointing works the same over passthrough and in the simulated room.

const TARGET_LAYER := 1

@export var length := 4.0
## How far in front of the controller the fingertip sits.
@export var tip_reach := 0.05

## &"left" or &"right".
var side: StringName
## The Target the ray points at now, or null.
var aimed: Target

@onready var _controller := get_parent() as XRController3D
var _beam: MeshInstance3D
var _distance := 0.0


func _ready() -> void:
	side = &"left" if _controller.name == &"LeftHand" else &"right"
	_controller.button_pressed.connect(_on_button.bind(true))
	_controller.button_released.connect(_on_button.bind(false))
	_controller.tracking_changed.connect(func(tracked: bool) -> void: Events.hand_tracking.emit(side, tracked))
	_build()


func _process(_delta: float) -> void:
	aimed = cast()
	_beam.scale.z = _distance
	_beam.position.z = -_distance * 0.5


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
	if action == "trigger_click":
		Events.selected.emit(side, cast(), global_position, -global_basis.z)
	elif action == "by_button":
		Events.help_requested.emit()


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
		if area is Target:
			Events.touched.emit(side, area))
	add_child(finger)
