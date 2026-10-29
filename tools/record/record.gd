extends Node3D
## The recorder: its own Quest app (export preset "Meta Quest 3 Recorder"), no
## game. It keeps what the headset senses, so it can be replayed on the PC
## against any later version of the app. Each launch records up to [constant LIMIT]
## seconds into user://recordings/<start time>/ (pulled by tools/recordings.py):
##
## - meta.json: format, camera and depth settings.
## - poses.jsonl: every frame, Time.get_ticks_usec() as t, XRServer's reference
##   frame, the head, each hand's aim and grip poses, pinch and grasp, its 26
##   OpenXR hand joints, and the left-hand menu pinch. Poses are in the Rig's
##   space as [x, y, z, qx, qy, qz, qw], null while not tracked; the joints as
##   XRHandTracker gives them, before the reference frame.
## - frames/: camera frames ([method CameraFrame.save]) every [constant FRAME_EVERY] s.
## - depth/: depth looks ([method DepthGrid.save]) every [constant DEPTH_EVERY] s.

const FORMAT := 1
const LIMIT := 300.0
const FRAME_EVERY := 0.1
const DEPTH_EVERY := 0.25
const SIDES: Array[StringName] = [&"left", &"right"]

var _folder := "user://recordings/" + Time.get_datetime_string_from_system().replace(":", "-")
var _poses: FileAccess
var _camera := QuestCamera.new()
var _depth := DepthSensor.new()
var _label := Label3D.new()
var _preview := Sprite3D.new()
var _started := 0
var _since_frame := 0.0
var _frames := 0
var _looks := 0
var _tracked := {&"left": 0, &"right": 0}
var _lines := 0


func _ready() -> void:
	get_viewport().transparent_bg = true
	App.xr.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
	for sub in ["frames", "depth"]:
		DirAccess.make_dir_recursive_absolute(_folder.path_join(sub))
	FileAccess.open(_folder.path_join("meta.json"), FileAccess.WRITE).store_string(JSON.stringify({
		format = FORMAT, started = Time.get_datetime_string_from_system(),
		camera = {in_head = pose(QuestCamera.IN_HEAD), fov_y = QuestCamera.FOV_Y, size = [QuestCamera.SIZE.x, QuestCamera.SIZE.y]},
		depth = {size = DepthSensor.N, every = DEPTH_EVERY}, frame_every = FRAME_EVERY}))
	_poses = FileAccess.open(_folder.path_join("poses.jsonl"), FileAccess.WRITE)
	add_child(_camera)
	_depth.record = false
	_depth.interval = DEPTH_EVERY
	_depth.refreshed.connect(_save_depth)
	App.rig.add_child(_depth)
	_depth.start()
	_label.font_size = 28
	_label.pixel_size = 0.0006
	_label.no_depth_test = true
	_label.position = Vector3(0.0, -0.12, -0.6)
	App.rig.head.add_child(_label)
	# What the camera sends, so whoever records sees it is the room and not a test pattern.
	_preview.texture = _camera.get_texture()
	_preview.pixel_size = 0.00025
	_preview.no_depth_test = true
	_preview.position = Vector3(0.0, -0.25, -0.6)
	App.rig.head.add_child(_preview)
	_started = Time.get_ticks_usec()


func _process(delta: float) -> void:
	if _poses == null:
		return
	var seconds := (Time.get_ticks_usec() - _started) / 1e6
	if seconds > LIMIT:
		_stop()
		return
	_record_poses()
	_since_frame += delta
	var frame := _camera.frame() if _since_frame >= FRAME_EVERY else null
	if frame:
		_since_frame = 0.0
		WorkerThreadPool.add_task(frame.save.bind(_folder.path_join("frames/%05d" % _frames)))
		_frames += 1
	_label.text = "● REC %d:%02d / %d:00\ncamera %d   depth %d\nhands  L %s   R %s" % [
		int(seconds) / 60, int(seconds) % 60, int(LIMIT) / 60, _frames, _looks,
		"✓" if App.rig.left.get_has_tracking_data() else "–", "✓" if App.rig.right.get_has_tracking_data() else "–"]


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and _poses:
		_poses.flush() # the app may be closed from here without another word
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_stop()


func _record_poses() -> void:
	var line := {t = Time.get_ticks_usec(), ref = pose(XRServer.get_reference_frame()), head = pose(App.rig.head.transform),
		menu = App.rig.menu.is_button_pressed(&"menu_pressed")}
	for side in SIDES:
		var controller := App.rig.hand(side)
		var tracked := controller.get_has_tracking_data()
		var grip := XRServer.get_tracker(controller.tracker).get_pose(&"grip") as XRPose
		var joints := XRServer.get_tracker(StringName("/user/hand_tracker/" + side)) as XRHandTracker
		line[side] = {aim = pose(controller.transform) if tracked else null,
			grip = pose(grip.get_adjusted_transform()) if grip and grip.has_tracking_data else null,
			pinch = controller.is_button_pressed(&"trigger_click"), grasp = controller.is_button_pressed(&"grip_click"),
			trigger = snappedf(controller.get_float(&"trigger"), 0.001),
			joints = _joints(joints) if joints and joints.has_tracking_data else null}
		if tracked:
			_tracked[side] += 1
	_poses.store_line(JSON.stringify(line))
	_lines += 1
	if _lines % 90 == 0:
		_poses.flush()


func _joints(tracker: XRHandTracker) -> Array:
	var all := []
	for joint in XRHandTracker.HAND_JOINT_MAX:
		all.append(pose(tracker.get_hand_joint_transform(joint)))
	return all


func _save_depth() -> void:
	if _poses == null:
		return
	_depth.grid.save(_folder.path_join("depth/%05d" % _looks), App.head().global_transform)
	_looks += 1


func _stop() -> void:
	if _poses == null:
		return
	_poses.close()
	_poses = null
	FileAccess.open(_folder.path_join("done.json"), FileAccess.WRITE).store_string(JSON.stringify({
		frames = _frames, depth = _looks, poses = _lines, tracked = _tracked}))
	_label.text = "Saved: %d frames, %d depth looks\nYou can take the headset off." % [_frames, _looks]


## [param transform] as [x, y, z, qx, qy, qz, qw], rounded to 0.1 mm and 1e-4.
static func pose(transform: Transform3D) -> Array:
	var q := transform.basis.get_rotation_quaternion()
	return [transform.origin.x, transform.origin.y, transform.origin.z, q.x, q.y, q.z, q.w].map(
		func(value: float) -> float: return snappedf(value, 0.0001))
