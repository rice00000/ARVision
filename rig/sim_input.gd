class_name SimInput
extends RefCounted
## Synthetic head and controllers for running without a headset. The desktop
## driver and the simulation tests move the real Rig through these, so every
## input reaches trials along the same path a Quest's does.

const ACTIONS: Array[StringName] = [&"trigger_click", &"grip_click", &"ax_button", &"by_button", &"menu_button"]

var rig: Rig
var _trackers: Dictionary[StringName, XRControllerTracker] = {}


func _init(target: Rig) -> void:
	rig = target
	for side: StringName in [&"left", &"right"]:
		var tracker := XRControllerTracker.new()
		tracker.name = StringName("/sim/%s" % side)
		tracker.type = XRServer.TRACKER_CONTROLLER
		tracker.hand = XRPositionalTracker.TRACKER_HAND_LEFT if side == &"left" else XRPositionalTracker.TRACKER_HAND_RIGHT
		for action in ACTIONS:
			tracker.set_input(action, false)
		XRServer.add_tracker(tracker)
		_trackers[side] = tracker
		rig.hand(side).tracker = tracker.name
		var x := -0.2 if side == &"left" else 0.2
		set_hand(side, rig.global_transform * Transform3D(Basis.IDENTITY, Vector3(x, 0.85, -0.3)))


## Moves a hand to [param world] at once (the controller follows the same frame).
func set_hand(side: StringName, world: Transform3D) -> void:
	var local := rig.global_transform.affine_inverse() * world
	for pose: StringName in [&"default", &"aim"]:
		_trackers[side].set_pose(pose, local, Vector3.ZERO, Vector3.ZERO, XRPose.XR_TRACKING_CONFIDENCE_HIGH)
	rig.hand(side).transform = local


## Puts a hand at [param from], pointing at [param at].
func point(side: StringName, from: Vector3, at: Vector3) -> void:
	set_hand(side, Transform3D(Basis.looking_at(at - from), from))


func press(side: StringName, action: StringName, pressed: bool) -> void:
	_trackers[side].set_input(action, pressed)


## Press and release.
func click(side: StringName, action: StringName) -> void:
	press(side, action, true)
	press(side, action, false)


## Turns the head to look at [param at] from where it is.
func look_at(at: Vector3) -> void:
	var eye := rig.head.global_position
	rig.head.global_basis = Basis.looking_at(at - eye)


## The controller loses (or regains) tracking.
func track(side: StringName, on: bool) -> void:
	if on:
		set_hand(side, rig.hand(side).global_transform)
	else:
		_trackers[side].invalidate_pose(&"default")
		_trackers[side].invalidate_pose(&"aim")


## Removes the trackers. Called when the rig goes away.
func release() -> void:
	for tracker in _trackers.values():
		XRServer.remove_tracker(tracker)
	_trackers.clear()
