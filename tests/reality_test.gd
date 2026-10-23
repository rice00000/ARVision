extends TestCase
## The Reality API's pieces: Surface, CameraFrame, View, Log.plain and
## work_surface() with and without a table in reach.


func _turned_surface() -> Surface:
	var frame := Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(1.0, 0.7, -1.0))
	return Surface.new(&"table", frame, Vector2(1.2, 0.6))


# -- Surface ------------------------------------------------------------------

func test_surface_points_span_its_top() -> void:
	var surface := _turned_surface()
	expect(surface.point(0.0, 0.0).is_equal_approx(Vector3(1.0, 0.7, -1.0)), "centre")
	# Turned 90 degrees: width (local X) runs along world -Z, depth (local Z) along world +X.
	expect(surface.point(1.0, 0.0).is_equal_approx(Vector3(1.0, 0.7, -1.6)), "right edge, half the width away")
	expect(surface.point(0.0, 1.0).is_equal_approx(Vector3(1.3, 0.7, -1.0)), "near edge, half the depth away")
	expect(surface.point(-1.0, -1.0).is_equal_approx(Vector3(0.7, 0.7, -0.4)), "a corner")


func test_scatter_keeps_spacing_and_margin() -> void:
	var surface := _turned_surface()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var points := surface.scatter(8, 0.15, 0.07, rng)
	expect_eq(points.size(), 8, "all fit")
	var frame := surface.transform
	for i in points.size():
		var local := frame.affine_inverse() * points[i]
		expect(is_zero_approx(local.y), "on the top")
		expect(absf(local.x) <= 0.6 - 0.07 + 1e-5 and absf(local.z) <= 0.3 - 0.07 + 1e-5, "inside the margin")
		for j in range(i + 1, points.size()):
			expect(points[i].distance_to(points[j]) >= 0.15 - 1e-5, "spaced")
	rng.seed = 7
	expect_eq(surface.scatter(8, 0.15, 0.07, rng), points, "same seed, same layout")


func test_scatter_returns_fewer_when_they_do_not_fit() -> void:
	var small := Surface.new(&"table", Transform3D.IDENTITY, Vector2(0.3, 0.3))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var points := small.scatter(20, 0.12, 0.05, rng)
	expect(points.size() >= 1 and points.size() < 20, "a few, not twenty: %d" % points.size())
	expect_eq(small.scatter(3, 0.1, 0.2, rng).size(), 1, "a margin larger than the half size leaves the centre only")


func test_an_anchored_surface_follows_its_anchor() -> void:
	var anchor := Node3D.new()
	add_child(anchor)
	anchor.global_position = Vector3(0, 0.7, -1)
	var surface := Surface.new(&"table", anchor.global_transform, Vector2(1, 1), anchor)
	anchor.global_position += Vector3(0.5, 0.0, 0.0) # the headset recentred
	expect(surface.transform.origin.is_equal_approx(Vector3(0.5, 0.7, -1)), "moves with the anchor")
	anchor.free()


# -- CameraFrame --------------------------------------------------------------

func test_camera_rays_go_through_the_image() -> void:
	var image := Image.create(640, 480, false, Image.FORMAT_RGB8)
	var frame := CameraFrame.new(image, Transform3D.IDENTITY, 60.0)
	expect(frame.ray(0.5, 0.5).is_equal_approx(Vector3.FORWARD), "centre: straight ahead")
	expect(is_equal_approx(rad_to_deg(frame.ray(0.5, 0.0).angle_to(Vector3.FORWARD)), 30.0), "top edge: half the fov")
	expect(frame.ray(0.5, 0.0).y > 0.0, "top is up")
	expect(frame.ray(0.0, 0.5).x < 0.0, "left is left")
	var horizontal := rad_to_deg(atan(tan(deg_to_rad(30.0)) * 640.0 / 480.0))
	expect(is_equal_approx(rad_to_deg(frame.ray(1.0, 0.5).angle_to(Vector3.FORWARD)), horizontal), "wider by the aspect")
	var turned := CameraFrame.new(image, Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(1, 2, 3)), 60.0)
	expect(turned.ray(0.5, 0.5).is_equal_approx(Vector3.LEFT), "the pose turns the rays")
	expect(is_equal_approx(turned.ray(0.2, 0.7).length(), 1.0), "unit length")


# -- View ---------------------------------------------------------------------

func test_views_say_whether_they_grade_and_log_everything() -> void:
	expect(not View.new().is_graded(), "neutral by default")
	for property in ["brightness", "contrast", "saturation"]:
		var view := View.new()
		view.set(property, 10.0 if property == "brightness" else 0.5)
		expect(view.is_graded(), "%s grades" % property)
	var other := View.new()
	other.black_and_white = true
	other.dim = 0.5
	other.edges = Color.YELLOW
	expect(not other.is_graded(), "black and white, dimming and edges are not grading")
	var logged := (load("res://content/views/spotlight.tres") as View).to_log()
	expect_eq(logged.keys().map(func(key: Variant) -> String: return str(key)), ["title", "brightness", "contrast", "saturation", "black_and_white", "edges", "dim", "focus_radius"], "every field")
	expect_eq([logged.title, logged.dim, logged.focus_radius], ["Spotlight", 0.8, 0.35], "spotlight preset")


# -- Log.plain ----------------------------------------------------------------

func test_plain_turns_engine_types_into_json() -> void:
	var value := {&"at": Vector3(1, 2, 3), "uv": Vector2(0.5, 0.25), "edges": Color(1, 0.5, 0, 1),
		"name": &"ball", 3: [Vector3.UP, {&"inner": &"x"}], "n": 2.5, "flag": true}
	var plain: Dictionary = Log.plain(value)
	expect_eq(plain.at, [1.0, 2.0, 3.0], "Vector3")
	expect_eq(plain.uv, [0.5, 0.25], "Vector2")
	expect_eq(plain.edges, [1.0, 0.5, 0.0, 1.0], "Color")
	expect(plain.name is String and plain.name == "ball", "StringName")
	expect_eq(plain["3"], [[0.0, 1.0, 0.0], {"inner": "x"}], "keys become strings, nested values too")
	var back: Variant = JSON.parse_string(JSON.stringify(plain))
	expect_eq(back, plain, "survives JSON unchanged")


# -- work_surface() -----------------------------------------------------------

func test_the_table_in_reach_is_the_work_surface() -> void:
	await boot(plan_of(load("res://trials/find/find.tres"), 1))
	var surface := App.reality.work_surface()
	expect_eq(surface.kind, &"table", "a table")
	expect(surface.size.is_equal_approx(Vector2(1.2, 0.7)), "the simulated room's table")
	expect(surface.transform.origin.is_equal_approx(Vector3(0, 0.72, -0.55)), "its top")
	expect_eq(App.reality.surfaces(&"floor").size(), 1, "the floor is known too")
	App.reality.add_surface(Surface.new(&"table", Transform3D(Basis.IDENTITY, Vector3(0, 0.7, -2.0)), Vector2.ONE))
	var tables := App.reality.surfaces(&"table")
	expect(tables.size() == 2 and tables[0].size.is_equal_approx(Vector2(1.2, 0.7)), "nearest first")


func test_without_a_table_in_reach_a_patch_goes_in_front() -> void:
	await boot(plan_of(load("res://trials/find/find.tres"), 1))
	App.rig.global_position = Vector3(0, 0, 1.5) # the table is now 2 m away
	input.look_at(App.head().global_position + Vector3(1, -0.5, -1)) # turned and looking down
	var eye := App.head().global_position
	var forward := Vector3(1, 0, -1).normalized()
	var surface := App.reality.work_surface()
	expect_eq(surface.kind, &"table", "still called a table")
	expect(surface.size.is_equal_approx(Vector2(0.8, 0.5)), "the virtual patch")
	expect(surface.transform.origin.is_equal_approx(eye + forward * Reality.REACH + Vector3.DOWN * Reality.BELOW_EYE),
		"in front at reach, below the eyes")
	expect(surface.transform.basis.y.is_equal_approx(Vector3.UP), "level even when the head is not")
	expect((-surface.transform.basis.z).is_equal_approx(forward), "facing the way the child faces")
	App.rig.global_position = Vector3(0, 0, 0.45) # the table edge just in reach again
	expect(App.reality.work_surface().size.is_equal_approx(Vector2(1.2, 0.7)), "back on the table")
