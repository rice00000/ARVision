class_name Guide
extends Node3D
## "This way": a glowing orb with an arrow, floating in sight on the side of a
## place the child is not facing yet, the arrow pointing at it. It follows the
## head, so turning toward the place leads the child there.

## Metres ahead of the eyes.
const DISTANCE := 0.7
## Degrees off the gaze it floats, toward the place.
const OFF_GAZE := 25.0

## Optional body shown instead of the orb (the entry's guide, Onion); the arrow stays.
## It follows the guide while the guide shows the way.
var body: Node3D:
	set(value):
		body = value
		_orb.visible = value == null

var _to := Vector3.ZERO
var _orb := MeshInstance3D.new()
var _arrow := MeshInstance3D.new()
var _clock := 0.0


func _ready() -> void:
	visible = false
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = Color(1.0, 0.85, 0.3)
	glow.no_depth_test = true
	glow.render_priority = 5
	_orb.mesh = SphereMesh.new()
	(_orb.mesh as SphereMesh).radius = 0.03
	(_orb.mesh as SphereMesh).height = 0.06
	_orb.material_override = glow
	add_child(_orb)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.025
	cone.height = 0.06
	_arrow.mesh = cone
	_arrow.material_override = glow
	add_child(_arrow)


## Shows the way to [param where] until [method stop].
func point_to(where: Vector3) -> void:
	_to = where
	visible = true
	_place()


func stop() -> void:
	visible = false


func _process(delta: float) -> void:
	if visible:
		_clock += delta
		_place()


func _place() -> void:
	var eye := App.head().global_transform
	var gaze := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	var to := Vector3(_to.x - eye.origin.x, 0.0, _to.z - eye.origin.z).normalized()
	var turn := gaze.signed_angle_to(to, Vector3.UP)
	var side := gaze.rotated(Vector3.UP, clampf(turn, -deg_to_rad(OFF_GAZE), deg_to_rad(OFF_GAZE)))
	global_position = eye.origin + side * DISTANCE + Vector3.UP * (0.02 * sin(_clock * 4.0) - 0.05)
	# The arrow leans out of the orb toward the place, tip first.
	var toward := (_to - global_position).normalized()
	_arrow.global_transform = Transform3D(_tilt(toward), global_position + toward * (0.09 if body else 0.06))
	if body:
		body.global_position = global_position


## A basis whose +Y (the cone's tip) points along [param direction].
static func _tilt(direction: Vector3) -> Basis:
	var x := direction.cross(Vector3.FORWARD if absf(direction.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT).normalized()
	return Basis(x, direction, x.cross(direction))
