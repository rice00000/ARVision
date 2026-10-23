extends TestCase
## The Detector module: the sim backend sees only what is in its view cone with
## a clear line, and the remote backend turns tools/cv_server.py replies into
## places in the room.

const POINT := preload("res://trials/point_real/point_real.tres")
const CUP := Vector3(-0.35, 0.77, -0.8) # centre of the living room's cup


func _detector() -> Node:
	return App.module(&"Detector")


func _labels() -> Array:
	await wait(0.6) # it looks twice a second
	return _detector().detections.map(func(found: Detection) -> String: return found.label)


func test_sees_what_is_in_view() -> void:
	await boot(plan_of(POINT, 1))
	var detected := record(Events.detected)
	input.look_at(Vector3(0, 0.75, -0.8))
	var seen: Array = await _labels()
	for label in ["cup", "bottle", "book", "apple"]:
		expect(label in seen, "%s on the table is seen" % label)
	expect(not detected.is_empty(), "sent as Events.detected")
	var cup: Detection = _detector().find("cup")
	expect(cup.position.is_equal_approx(CUP), "at the object's centre: %s" % cup.position)
	expect_eq(cup.confidence, 1.0, "sim detections are certain")
	expect_eq(_detector().find("unicorn"), null, "find() of something absent")
	input.look_at(App.head().global_position + Vector3(0, 0, 1)) # turned right round
	seen = await _labels()
	expect(not "cup" in seen and not "bottle" in seen, "nothing behind the eyes: %s" % [seen])


func test_the_view_cone_edge() -> void:
	await boot(plan_of(POINT, 1))
	var eye := App.head().global_position
	var to_cup := (CUP - eye).normalized()
	var across := to_cup.cross(Vector3.UP).normalized() # turning about it moves the gaze straight off the cup
	for degrees: float in [44.0, 46.0]:
		input.look_at(eye + to_cup.rotated(across, deg_to_rad(degrees)))
		var seen: Array = await _labels()
		expect(("cup" in seen) == (degrees < 45.0), "cup %.0f degrees off the gaze: %s" % [degrees, seen])


func test_something_real_in_the_way_hides_an_object() -> void:
	await boot(plan_of(POINT, 1))
	input.look_at(CUP)
	expect("cup" in await _labels(), "seen at first")
	var wall := StaticBody3D.new()
	wall.collision_layer = 2 # the "reality" layer
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(0.2, 0.2, 0.02)
	wall.add_child(shape)
	app.add_child(wall)
	wall.global_position = App.head().global_position.lerp(CUP, 0.5)
	await frames(2)
	expect(not "cup" in await _labels(), "hidden behind a real thing")
	wall.collision_layer = 1 # the "targets" layer: virtual things never hide real ones
	await frames(2)
	expect("cup" in await _labels(), "seen again")
	wall.queue_free()


func test_remote_replies_become_places_in_the_room() -> void:
	await boot(plan_of(POINT, 1))
	var detector := _detector()
	var reports := record(Events.reported)
	var pose := Transform3D(Basis.looking_at(CUP - App.head().global_position), App.head().global_position)
	detector.set("_frame", CameraFrame.new(Image.create(640, 480, false, Image.FORMAT_RGB8), pose, 60.0))
	var reply := {detections = [
		{label = "cup", confidence = 0.9, box = [0.45, 0.45, 0.55, 0.55]},
		{label = "bottle", confidence = 0.2, box = [0.1, 0.1, 0.2, 0.2]},
		{label = "chair", confidence = 0.8, box = [0.0, 0.0, 0.02, 0.02]},
	]}
	detector.call("_on_reply", HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(reply).to_utf8_buffer())
	var found: Array = detector.detections.map(func(d: Detection) -> String: return d.label)
	expect_eq(found, ["cup", "chair"], "below min_confidence is dropped")
	var cup: Detection = detector.find("cup")
	expect_eq(cup.confidence, 0.9, "confidence kept")
	var space := App.head().get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(pose.origin, pose.origin - pose.basis.z * 4.0, 2))
	expect(cup.position.is_equal_approx(hit.position), "where the box centre's ray meets the room: %s" % cup.position)
	expect(cup.position.distance_to(CUP) < 0.06, "which is on the cup")
	var corner := CameraFrame.new(Image.create(640, 480, false, Image.FORMAT_RGB8), pose, 60.0).ray(0.01, 0.01)
	var chair: Detection = detector.find("chair")
	expect(is_equal_approx((chair.position - pose.origin).normalized().dot(corner), 1.0), "along its own ray")
	detector.call("_on_reply", HTTPRequest.RESULT_SUCCESS, 500, PackedStringArray(), PackedByteArray())
	detector.call("_on_reply", HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	var errors := reports.filter(func(args: Array) -> bool: return args[0] == &"cv_error")
	expect_eq(errors.map(func(args: Array) -> Dictionary: return args[1]),
		[{result = HTTPRequest.RESULT_SUCCESS, code = 500}, {result = HTTPRequest.RESULT_CANT_CONNECT, code = 0}], "errors are logged")
	expect_eq(detector.detections.size(), 2, "and keep the last detections")


func test_headless_remote_backend_sends_nothing() -> void:
	await boot(plan_of(POINT, 1))
	var detector := _detector()
	detector.backend = 2 # REMOTE
	await wait(1.2)
	expect(not detector.get("_waiting"), "no camera frame headless, so no request")
	expect(App.reality.camera_frame() == null, "SimReality has no frame headless")
