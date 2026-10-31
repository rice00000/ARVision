extends TestCase
## Feed joint data through XRServer, as the OpenXR runtime does.

var _trackers: Array[XRHandTracker] = []


func _tracked(side: StringName) -> XRHandTracker:
	var tracker := XRHandTracker.new()
	tracker.name = StringName("/user/hand_tracker/%s" % side)
	tracker.hand = XRPositionalTracker.TRACKER_HAND_LEFT if side == &"left" else XRPositionalTracker.TRACKER_HAND_RIGHT
	tracker.has_tracking_data = true
	tracker.set_pose(&"default", Transform3D.IDENTITY, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	for joint in XRHandTracker.HAND_JOINT_MAX:
		tracker.set_hand_joint_flags(joint, XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_VALID)
		tracker.set_hand_joint_transform(joint, Transform3D(Basis.IDENTITY, Vector3(0.1, 0.8, -0.3)))
	XRServer.add_tracker(tracker)
	_trackers.append(tracker)
	return tracker


func test_touch_and_grip_use_real_joints_in_the_rigs_world_frame() -> void:
	await boot()
	App.rig.global_transform = Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.3, 0.1, -0.2))
	for side: StringName in [&"left", &"right"]:
		var tracker := _tracked(side)
		var palm := Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0.1, 0.8, -0.3))
		var index := Vector3(0.12, 0.85, -0.4)
		var thumb := Vector3(0.1, 0.82, -0.38)
		tracker.set_hand_joint_transform(TrackedHand.PALM, palm)
		tracker.set_hand_joint_transform(TrackedHand.INDEX, Transform3D(Basis.IDENTITY, index))
		tracker.set_hand_joint_transform(TrackedHand.THUMB, Transform3D(Basis.IDENTITY, thumb))
		var pointer := App.rig.pointer(side)
		expect(pointer.tip().is_equal_approx(App.rig.global_transform * index), "%s touches with the actual index tip" % side)
		palm.origin = (index + thumb) * 0.5
		expect(pointer.grip().is_equal_approx(App.rig.global_transform * palm), "%s pinches between the fingertips with palm rotation" % side)


func test_joint_data_is_unavailable_when_tracking_is_lost() -> void:
	await boot()
	for side: StringName in [&"left", &"right"]:
		var tracker := _tracked(side)
		await frames(2)
		var hand := App.rig.tracked_hand(side)
		expect(hand.has_joints(), "%s joints are available while tracked" % side)
		tracker.has_tracking_data = false
		tracker.invalidate_pose(&"default")
		await frames(2)
		expect(not hand.has_joints(), "%s does not use stale joints after tracking loss" % side)


func shutdown() -> void:
	for tracker in _trackers:
		XRServer.remove_tracker(tracker)
	_trackers.clear()
	await super.shutdown()


func test_the_real_hand_is_revealed_by_the_headsets_hand_mesh() -> void:
	await boot()
	for side: StringName in [&"left", &"right"]:
		App.rig.tracked_hand(side).reveal_real_hand()
		var follow := App.rig.get_node(NodePath("%sRealHand" % side.capitalize())) as XRNode3D
		var tracker := StringName("/user/hand_tracker/%s" % side)
		expect_eq(follow.tracker, tracker, "%s follows its hand" % side)
		var mesh := follow.get_child(0) as OpenXRFbHandTrackingMesh
		expect_eq(mesh.hand, 0 if side == &"left" else 1, "%s mesh is that hand's" % side)
		expect_eq((mesh.material as ShaderMaterial).shader, TrackedHand.Reveal, "%s reveals the passthrough" % side)
		expect_eq((mesh.get_child(0) as XRHandModifier3D).hand_tracker, tracker, "%s posed by its joints" % side)
