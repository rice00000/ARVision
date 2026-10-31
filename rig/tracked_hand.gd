class_name TrackedHand
extends XRNode3D
## Official rigged hand mesh, animated by Godot's built-in hand modifier.
## In passthrough its depth reveals the real hand in front of virtual objects.

const Occlusion := preload("res://rig/hand_occlusion.gdshader")
const INDEX := XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP
const THUMB := XRHandTracker.HAND_JOINT_THUMB_TIP
const PALM := XRHandTracker.HAND_JOINT_PALM

@export var side: StringName = &"right"
var _mesh: MeshInstance3D
var _skin: Material
var _occlusion := ShaderMaterial.new()


func _ready() -> void:
	var model: PackedScene = load("res://rig/hands/%sHandHumanoid.gltf" % ("Left" if side == &"left" else "Right"))
	var hand := model.instantiate()
	add_child(hand)
	var skeleton := hand.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var modifier := XRHandModifier3D.new()
	modifier.hand_tracker = tracker
	skeleton.add_child(modifier)
	_mesh = skeleton.get_child(0) as MeshInstance3D
	_skin = _mesh.get_active_material(0)
	_occlusion.shader = Occlusion


func joints() -> XRHandTracker:
	return XRServer.get_tracker(tracker) as XRHandTracker


func has_joints() -> bool:
	var hand := joints()
	return hand != null and hand.has_tracking_data and _valid(hand, INDEX) and _valid(hand, THUMB) and _valid(hand, PALM)


func fingertip() -> Vector3:
	return App.rig.global_transform * joints().get_hand_joint_transform(INDEX).origin


func pinch() -> Transform3D:
	var hand := joints()
	var pose := hand.get_hand_joint_transform(PALM)
	pose.origin = (hand.get_hand_joint_transform(INDEX).origin + hand.get_hand_joint_transform(THUMB).origin) * 0.5
	return App.rig.global_transform * pose


func _process(_delta: float) -> void:
	visible = has_joints()
	_mesh.material_override = _occlusion if App.reality is PassthroughReality else _skin


func _valid(hand: XRHandTracker, joint: int) -> bool:
	var flags := hand.get_hand_joint_flags(joint)
	return (flags & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID) != 0 \
		and (flags & XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_VALID) != 0
