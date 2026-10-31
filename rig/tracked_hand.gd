class_name TrackedHand
extends Node
## Joint data for fingertip contact and pinch. No rendered hand.

const INDEX := XRHandTracker.HAND_JOINT_INDEX_FINGER_TIP
const THUMB := XRHandTracker.HAND_JOINT_THUMB_TIP
const PALM := XRHandTracker.HAND_JOINT_PALM

@export var side: StringName = &"right"


func joints() -> XRHandTracker:
	return XRServer.get_tracker(StringName("/user/hand_tracker/%s" % side)) as XRHandTracker


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
