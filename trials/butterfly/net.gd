class_name ButterflyNet
extends Node3D
## A butterfly net: a handle, a hoop and a bag. It lies on the table until a
## hand takes it ([method hold]); then the handle runs on from the hand, away
## from the shoulder, so the hoop sweeps a circle round the child. The hoop
## turns its opening to where it is going and the bag trails behind, so a
## swing meets what flies into it. This node's own frame is the hoop: origin
## at its centre, -Z out through the opening.

const HANDLE := 0.36
const HOOP_RADIUS := 0.12
const BAG_DEPTH := 0.24
## Seconds the hoop's speed is smoothed over.
const SMOOTHING := 0.06
## Below this speed (m/s) the opening stops turning with the swing.
const TURN_SPEED := 0.2
## A hoop step longer than this in one tick is tracking finding the hand again, not a swing.
const JUMP := 0.15

## The hand holding it, or &"" while it lies on the table.
var hand: StringName = &""
## The hoop's smoothed velocity, m/s.
var velocity := Vector3.ZERO
## Where the child can take it from (a Target at the handle's end).
var grip: Target

var _handle := MeshInstance3D.new()
var _last := Vector3.INF
var _opening := Vector3.FORWARD


func _ready() -> void:
	_build()


## Lies on the table at [param at], handle towards [param towards] (where the child sits).
func lay(at: Vector3, towards: Vector3) -> void:
	hand = &""
	var along := Vector3(towards.x - at.x, 0.0, towards.z - at.z).normalized()
	var hoop := at - along * HANDLE * 0.5
	global_transform = Transform3D(Basis.looking_at(Vector3.UP, along), hoop + Vector3.UP * 0.012)
	_place_handle(at + along * HANDLE * 0.5)
	grip.global_position = at + along * HANDLE * 0.5
	velocity = Vector3.ZERO
	_last = Vector3.INF


func hold(side: StringName) -> void:
	hand = side
	grip.collision_layer = 0


func held() -> bool:
	return hand != &""


## Follows the hand, the hoop [constant HANDLE] beyond it, away from the shoulder.
func follow(at: Vector3, shoulder: Vector3, delta: float) -> void:
	var out := (at - shoulder).normalized()
	var hoop := at + out * HANDLE
	if not _last.is_finite() or hoop.distance_to(_last) > JUMP:
		velocity = Vector3.ZERO
	elif delta > 0.0:
		velocity = velocity.lerp((hoop - _last) / delta, minf(1.0, delta / SMOOTHING))
	_last = hoop
	if velocity.length() > TURN_SPEED:
		_opening = _opening.slerp(velocity.normalized(), minf(1.0, delta * 12.0))
	var up := out if absf(out.dot(_opening)) < 0.95 else Vector3.UP
	global_transform = Transform3D(Basis.looking_at(_opening, up), hoop)
	_place_handle(at)


func _place_handle(end: Vector3) -> void:
	var from := global_position
	var along := end - from
	var y := along.normalized()
	var x := y.cross(Vector3.UP if absf(y.y) < 0.99 else Vector3.RIGHT).normalized()
	_handle.global_transform = Transform3D(Basis(x, y * along.length(), x.cross(y)), from + along * 0.5)


func _build() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.62, 0.42, 0.24)
	var stick := CylinderMesh.new()
	stick.top_radius = 0.009
	stick.bottom_radius = 0.009
	stick.height = 1.0
	stick.radial_segments = 8
	stick.rings = 1
	_handle.mesh = stick
	_handle.material_override = wood
	_handle.top_level = true
	add_child(_handle)
	var hoop := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = HOOP_RADIUS - 0.006
	ring.outer_radius = HOOP_RADIUS + 0.006
	ring.rings = 24
	ring.ring_segments = 6
	hoop.mesh = ring
	hoop.rotation.x = PI / 2.0
	hoop.material_override = wood
	add_child(hoop)
	var mesh := StandardMaterial3D.new()
	mesh.albedo_color = Color(1.0, 1.0, 1.0, 0.35)
	mesh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cone := CylinderMesh.new()
	cone.top_radius = HOOP_RADIUS
	cone.bottom_radius = 0.02
	cone.height = BAG_DEPTH
	cone.cap_top = false
	cone.radial_segments = 16
	cone.rings = 3
	var bag := MeshInstance3D.new()
	bag.name = "Bag"
	bag.mesh = cone
	bag.material_override = mesh
	bag.rotation.x = -PI / 2.0
	bag.position = Vector3(0.0, 0.0, BAG_DEPTH * 0.5)
	add_child(bag)
	grip = Target.sphere(&"net", 0.07)
	grip.top_level = true
	add_child(grip)
