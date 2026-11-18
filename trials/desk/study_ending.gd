extends Node3D
## A short, pausable walk -> sit -> open notebook -> write sequence, local to this trial.

const Props := preload("res://trials/study_props.gd")
const STUDENT := preload("res://trials/desk/assets/student.glb")
const CHAIR := preload("res://trials/desk/assets/chair.glb")
const FLOOR := -0.68
const SEAT := Vector3(0.065, FLOOR, -0.60)
const TIP := Vector3(0, 0, 0.0725) # The graphite end of the centred model is +Z.
const GRIP := TIP - Vector3(0, 0, 0.040)
const GRAB_AT := 3.13
const WRITE_AT := 3.55

signal completed

var phase := "waiting"
var _actor: Node3D
var _skeleton: Skeleton3D
var _clock := 0.0
var _sit := 0.0
var _write := 0.0
var _cover: Node3D
var _notebook: Target
var _pencil: Target
var _pencil_rest: Transform3D
var _paper_point := Vector3.ZERO


func _ready() -> void:
	var chair: Node3D = CHAIR.instantiate()
	add_child(chair)
	chair.scale = Vector3.ONE * 0.40
	chair.position = SEAT
	chair.rotation.y = PI
	_actor = STUDENT.instantiate()
	add_child(_actor)
	_actor.name = "Student"
	_actor.scale = Vector3.ONE * 0.63
	_actor.position = SEAT + Vector3(0.55, 0, -0.32)
	_actor.hide()
	_skeleton = _actor.find_child("Skeleton3D", true, false) as Skeleton3D


func start(keys: Dictionary[Target, String]) -> void:
	phase = "settling"
	_clock = -0.35
	_notebook = keys.find_key("notebook")
	_pencil = keys.find_key("pencil")
	# The source notebook has separate bottom cover, top cover and pages.
	var top := _notebook.get_node(^"Model").find_child("Box002", true, false) as Node3D
	_cover = Node3D.new()
	_notebook.add_child(_cover)
	_cover.position = Vector3(-Props.size_of("notebook").x * 0.5, 0, 0)
	top.reparent(_cover)


func _process(delta: float) -> void:
	if phase == "waiting" or phase == "done":
		return
	_clock += delta
	if _clock < 0.0:
		return
	if phase == "settling":
		# The last item may still have been moving to its outline when start ran.
		_pencil_rest = _pencil.transform
		var model := _notebook.get_node(^"Model") as Node3D
		_paper_point = _notebook.transform * (model.position + Vector3(0.003, 0.010, 0.012))
	var next_phase := "arriving" if _clock < 1.8 else "sitting" if _clock < 2.7 else "opening" if _clock < WRITE_AT else "studying"
	if next_phase != phase:
		phase = next_phase
		Events.report(&"desk_ending", {phase = phase})
	_actor.show()
	var walk := smoothstep(0.0, 1.8, _clock)
	_sit = smoothstep(1.8, 2.7, _clock)
	_write = smoothstep(2.7, WRITE_AT, _clock)
	_actor.position = (SEAT + Vector3(0.55, 0, -0.32)).lerp(SEAT, walk) + Vector3.DOWN * 0.12 * _sit
	_cover.rotation.z = 2.7 * _write
	_skeleton.reset_bone_poses()
	# Targets are in the desk frame; the skeleton's source uses centimetre-sized bone rests.
	var walking := phase == "arriving"
	var stride := sin(_clock * 9.0) * 0.32 if walking else 0.0
	_aim("UpperLeg.L", "LowerLeg.L", Vector3(0, -1.0 + _sit, _sit + stride))
	_aim("UpperLeg.R", "LowerLeg.R", Vector3(0, -1.0 + _sit, _sit - stride))
	_aim("LowerLeg.L", "Foot.L", Vector3(0, -1, 0.10))
	_aim("LowerLeg.R", "Foot.R", Vector3(0, -1, 0.10))
	_aim("Abdomen", "Torso", Vector3(0, 1, 0.35 * _sit))
	_aim("UpperArm.L", "LowerArm.L", Vector3(0.12, -1, stride * 0.6))
	_aim("UpperArm.R", "LowerArm.R", Vector3(-0.12, -1, -stride * 0.6))
	if _sit > 0:
		_arm("R", Vector3(0.005, 0.045, -0.425), Vector3(-1, -0.3, -0.4))
		_hand("R", 0.0)
		_write_with_pencil()
		_aim("Neck", "Head", Vector3(0, 1, _sit * 0.45))
	if _clock >= 5.95:
		completed.emit()


func _write_with_pencil() -> void:
	var reach := smoothstep(2.7, GRAB_AT, _clock)
	var carry := smoothstep(GRAB_AT, WRITE_AT, _clock)
	var pinch := smoothstep(2.94, GRAB_AT, _clock)
	_hand("L", pinch)
	var grip_offset := _pencil_grip() - _bone_point("Hand.L")
	var stroke := maxf(0.0, _clock - WRITE_AT)
	var tip := _paper_point + Vector3(sin(stroke * 8.0) * 0.009, 0, sin(stroke * 5.0) * 0.006)
	var writing_basis := Basis.looking_at(Vector3(0.34, -0.79, 0.51), Vector3.UP, true)
	var attitude := _pencil_rest.basis.slerp(writing_basis, carry)
	var grip := (_pencil_rest * GRIP).lerp(tip + writing_basis * (GRIP - TIP), carry)
	grip.y += 0.037 * sin(PI * carry)
	var wrist := Vector3(0.153, 0.047, -0.424).lerp(grip - grip_offset, reach)
	_arm("L", wrist, Vector3(1, -0.3, -0.4))
	# Reapply the grip after the forearm turns, then attach to the posed fingers.
	_hand("L", pinch)
	if _clock >= GRAB_AT:
		# The wrist is solved against the same grip; use the actual joint positions.
		_pencil.transform = Transform3D(attitude, _pencil_grip() - attitude * GRIP)


func _pencil_grip() -> Vector3:
	return _bone_point("Thumb3.L").lerp(_bone_point("Index3.L"), 0.5)


func _aim(bone_name: String, child_name: String, direction: Vector3) -> void:
	var bone := _skeleton.find_bone(bone_name)
	var child := _skeleton.find_bone(child_name)
	var pose := _skeleton.get_bone_global_pose(bone)
	var from := (_skeleton.get_bone_global_pose(child).origin - pose.origin).normalized()
	# Direction is in desk space, not the rotated/scaled source armature.
	var local_direction: Vector3 = _skeleton.global_basis.inverse() * (get_parent() as Node3D).global_basis * direction
	pose.basis = Basis(Quaternion(from, local_direction.normalized())) * pose.basis
	_skeleton.set_bone_global_pose(bone, pose)


func _reach(bone_name: String, child_name: String, point: Vector3, weight: float) -> void:
	var bone := _skeleton.find_bone(bone_name)
	var child := _skeleton.find_bone(child_name)
	var pose := _skeleton.get_bone_global_pose(bone)
	var from := (_skeleton.get_bone_global_pose(child).origin - pose.origin).normalized()
	var to := (_skeleton.to_local(get_parent().to_global(point)) - pose.origin).normalized()
	pose.basis = Basis(Quaternion.IDENTITY.slerp(Quaternion(from, to), weight)) * pose.basis
	_skeleton.set_bone_global_pose(bone, pose)


## Two-bone reach keeps both wrists at the desk without crossing or stretching arms.
func _arm(side: String, target: Vector3, pole: Vector3) -> void:
	var upper := "UpperArm." + side
	var lower := "LowerArm." + side
	var hand := "Hand." + side
	var shoulder := _bone_point(upper)
	var length_a := shoulder.distance_to(_bone_point(lower))
	var length_b := _bone_point(lower).distance_to(_bone_point(hand))
	var direction := (target - shoulder).normalized()
	var distance := clampf(shoulder.distance_to(target), absf(length_a - length_b) + 0.001, length_a + length_b - 0.001)
	var along := (length_a * length_a - length_b * length_b + distance * distance) / (2 * distance)
	var perpendicular := (pole - direction * pole.dot(direction)).normalized()
	var elbow := shoulder + direction * along + perpendicular * sqrt(maxf(length_a * length_a - along * along, 0.0))
	_reach(upper, lower, elbow, _sit)
	_reach(lower, hand, target, _sit)


func _bone_point(bone_name: String) -> Vector3:
	var pose := _skeleton.get_bone_global_pose(_skeleton.find_bone(bone_name))
	return (get_parent() as Node3D).to_local(_skeleton.to_global(pose.origin))


func _hand(side: String, grip: float) -> void:
	var bone := _skeleton.find_bone("Hand." + side)
	_skeleton.set_bone_pose_scale(bone, Vector3.ONE * 0.65)
	var pose := _skeleton.get_bone_global_pose(bone)
	# Bone Y runs wrist-to-fingers. Keep palms down rather than inheriting the arm's twist.
	var palm := Basis(Vector3.RIGHT, 0.2) * Basis(Vector3.LEFT, Vector3.BACK, Vector3.UP)
	var orientation: Basis = _skeleton.global_basis.orthonormalized().inverse() * (get_parent() as Node3D).global_basis.orthonormalized() * palm
	pose.basis = orientation.scaled(pose.basis.get_scale())
	_skeleton.set_bone_global_pose(bone, pose)
	for finger in ["Index", "Middle", "Ring", "Pinky"]:
		for joint in [2, 3, 4]:
			var curl := -0.65 if finger == "Index" else -1.0
			var bend := lerpf(-0.22, curl, grip)
			_skeleton.set_bone_pose_rotation(_skeleton.find_bone("%s%d.%s" % [finger, joint, side]), Quaternion(Vector3.RIGHT, bend))


func stop() -> void:
	phase = "done"
