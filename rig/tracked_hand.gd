class_name TrackedHand
extends Node
## Joint data for fingertip contact and pinch. No rendered hand: in passthrough
## the real hand is seen, and [method reveal_real_hand] keeps it in front of
## virtual things it is in front of.

const Reveal := preload("res://rig/hand_reveal.gdshader")
## The reveal's second pass comes after every menu and subtitle (those are drawn
## over everything at lower priorities), and before the scene fade (127).
const OVER_MENUS := 126
const INDEX := XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP
const THUMB := XRHandTracker.HAND_JOINT_THUMB_TIP
const PALM := XRHandTracker.HAND_JOINT_PALM

@export var side: StringName = &"right"


func joints() -> XRHandTracker:
	return XRServer.get_tracker(_tracker()) as XRHandTracker


## Passthrough only: the headset's mesh of this hand, posed by its joints and
## drawn with [method reveal_material], so the real hand is not covered by
## virtual things behind it, nor by menus.
func reveal_real_hand() -> void:
	var follow := XRNode3D.new()
	follow.name = "%sRealHand" % side.capitalize()
	follow.tracker = _tracker()
	var mesh := OpenXRFbHandTrackingMesh.new()
	mesh.hand = 0 if side == &"left" else 1
	mesh.material = reveal_material()
	var modifier := XRHandModifier3D.new()
	modifier.hand_tracker = _tracker()
	mesh.add_child(modifier)
	follow.add_child(mesh)
	get_parent().add_child(follow)


## [constant Reveal] twice. First it clears the world behind the hand and
## writes the hand's depth, so later virtual things behind it stay hidden.
## Then, after the menus, it clears them too; its depth test still keeps any
## virtual thing in front of the hand. Menus never depth test, so they never
## flicker or get cut by depth.
static func reveal_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = Reveal
	material.next_pass = ShaderMaterial.new()
	material.next_pass.shader = Reveal
	material.next_pass.render_priority = OVER_MENUS
	return material


func _tracker() -> StringName:
	return StringName("/user/hand_tracker/%s" % side)


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


func _valid(hand: XRHandTracker, joint: int) -> bool:
	var flags := hand.get_hand_joint_flags(joint)
	return (flags & XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID) != 0 \
		and (flags & XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_VALID) != 0
