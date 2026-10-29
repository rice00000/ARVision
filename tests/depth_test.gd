extends TestCase
## Finding the room without the scan: DepthGrid on a synthetic depth image (a
## wall 2.5 m ahead, a table top below), CameraFrame.uv, Reality.hit and the
## wall break on the simulated room.

const EYE := Vector3(0.0, 1.2, 0.0)
const N := 48
const WALL_Z := -2.5
const TABLE_Y := 0.7


## What a 90 degree depth camera at EYE looking along -Z sees: a wall at
## WALL_Z, and a 1 x 0.7 m table top at TABLE_Y in front of the eyes.
func _room_grid(with_table := true) -> DepthGrid:
	var points := PackedVector3Array()
	var valid := PackedByteArray()
	for y in N:
		for x in N:
			var ray := Vector3((x + 0.5) / N * 2.0 - 1.0, 1.0 - (y + 0.5) / N * 2.0, -1.0).normalized()
			var at := EYE + ray * ((WALL_Z - EYE.z) / ray.z)
			if with_table and ray.y < 0.0:
				var on_table := EYE + ray * ((TABLE_Y - EYE.y) / ray.y)
				if absf(on_table.x) < 0.5 and on_table.z < -0.3 and on_table.z > -1.0:
					at = on_table
			points.append(at)
			valid.append(1)
	return DepthGrid.new(N, points, valid)


func test_a_ray_finds_the_wall_ahead_and_its_normal() -> void:
	var grid := _room_grid()
	var ahead := grid.hit(EYE, Vector3.FORWARD)
	expect(ahead.position.is_equal_approx(Vector3(0.0, 1.2, WALL_Z)), "on the wall, on the ray: %s" % ahead.position)
	expect(ahead.normal.dot(Vector3.BACK) > 0.99, "facing the eyes: %s" % ahead.normal)
	var slanted := Vector3(0.3, 0.1, -1.0).normalized()
	var off := grid.hit(EYE, slanted)
	expect(absf(off.position.z - WALL_Z) < 0.01 and (off.position - EYE).normalized().dot(slanted) > 0.9999,
		"a slanted ray meets the wall where it points: %s" % off.position)


func test_a_ray_stops_at_the_nearer_table() -> void:
	var down := (Vector3(0.0, TABLE_Y, -0.6) - EYE).normalized()
	var found := _room_grid().hit(EYE, down)
	expect(absf(found.position.y - TABLE_Y) < 0.01, "on the table top: %s" % found.position)
	expect(found.normal.dot(Vector3.UP) > 0.99, "pointing up: %s" % found.normal)


func test_nothing_seen_means_no_hit() -> void:
	var grid := _room_grid()
	grid.valid.fill(0)
	expect(grid.hit(EYE, Vector3.FORWARD).is_empty(), "no points")
	expect(_room_grid().hit(EYE, Vector3.BACK).is_empty(), "nothing behind the eyes")


func test_the_table_top_is_found_from_the_depth() -> void:
	var table := _room_grid().table(EYE, Vector3.FORWARD)
	expect(table.has("centre"), "found, %d points on it" % table.support)
	expect(absf(table.centre.y - TABLE_Y) < 0.02, "at its height: %s" % table.centre)
	# A 90 degree camera 0.5 m above the top sees it from 0.5 m ahead: 1 x 0.5 m of it.
	expect(absf(table.centre.x) < 0.05 and absf(table.centre.z + 0.75) < 0.1, "in the middle of what is seen: %s" % table.centre)
	expect(table.size.x > 0.85 and table.size.y > 0.4, "most of the 1 x 0.5 m in view: %s" % table.size)
	expect(not _room_grid(false).table(EYE, Vector3.FORWARD).has("centre"), "a bare wall is no table")


func test_stray_points_do_not_stretch_the_table() -> void:
	var grid := _room_grid()
	var stray := 0
	for i in grid.points.size():
		if grid.points[i].y == TABLE_Y and stray < 6: # an arm at table height, right under the eyes
			grid.points[i] = Vector3(0.0, TABLE_Y, -0.05)
			stray += 1
	var table := grid.table(EYE, Vector3.FORWARD)
	expect(table.centre.z < -0.55, "the centre stays on the top: %s" % table.centre)


func test_a_lap_or_a_slope_at_table_height_is_no_table() -> void:
	# A level patch right under the eyes (the child's own lap or chest).
	var lap := _room_grid(false)
	for i in lap.points.size():
		var point := lap.points[i]
		if point.y < EYE.y - 0.3 and point.y > EYE.y - 0.6:
			var ray := (point - EYE).normalized()
			lap.points[i] = EYE + ray * ((EYE.y - 0.45 - EYE.y) / ray.y)
	var near := lap.table(EYE, Vector3.FORWARD)
	expect(not near.has("centre"), "nothing within %.1f m of the eyes counts: %s" % [DepthGrid.TABLE_AROUND.x, near])
	# A slope at the right height and distance: level points only.
	var slope := _room_grid(false)
	for i in slope.points.size():
		var ray := (slope.points[i] - EYE).normalized()
		if ray.y < -0.2:
			var plane_y := TABLE_Y
			var t := 0.0
			for step in 20: # the plane y = TABLE_Y + 0.5 * (z + 0.6), by iteration
				t = (plane_y - EYE.y) / ray.y
				plane_y = TABLE_Y + 0.5 * (EYE.z + ray.z * t + 0.6)
			slope.points[i] = EYE + ray * t
	expect(not slope.table(EYE, Vector3.FORWARD).has("centre"), "a 27 degree slope is no table")


func test_the_depth_table_is_believed_once_the_looks_agree() -> void:
	var low := {support = 80, centre = Vector3(0, 0.70, -0.7), size = Vector2(0.8, 0.5)}
	var high := {support = 120, centre = Vector3(0, 0.90, -0.7), size = Vector2(0.8, 0.5)}
	var best := {support = 140, centre = Vector3(0, 0.71, -0.7), size = Vector2(0.8, 0.5)}
	var none := {support = 12}
	var looks: Array[Dictionary] = [none, high, high, high]
	expect(TableFinder.agreeing(looks, 4, 0.03).is_empty(), "three of five are not enough")
	looks.assign([high, low, best, none, low])
	expect(TableFinder.agreeing(looks, 4, 0.03).is_empty(), "the tops disagree")
	looks.assign([high, low, best, low, none])
	expect_eq(TableFinder.agreeing(looks, 3, 0.03), best, "the fullest of the agreeing looks")


func test_the_table_is_measured_the_way_the_child_faces() -> void:
	var turned := Vector3(1.0, 0.0, -1.0).normalized()
	var table := _room_grid().table(EYE, turned)
	expect(absf(table.centre.x) < 0.5 and table.centre.z < -0.3 and table.centre.z > -1.0, "still on the top: %s" % table.centre)
	expect(table.size.x >= 0.4 and table.size.y >= 0.3, "a usable size: %s" % table.size)


func test_hands_on_the_table_have_a_surface_around_them_hands_in_the_air_do_not() -> void:
	var grid := _room_grid()
	var on_table := grid.around(Vector3(0.0, TABLE_Y, -0.7), PassthroughReality.HAND_TABLE_RADIUS)
	expect(on_table.x >= PassthroughReality.HAND_TABLE_POINTS, "the top around resting hands: %s" % on_table)
	var in_air := grid.around(Vector3(0.0, TABLE_Y + 0.2, -0.7), PassthroughReality.HAND_TABLE_RADIUS)
	expect(in_air.y >= PassthroughReality.HAND_TABLE_POINTS and in_air.x < PassthroughReality.HAND_TABLE_POINTS,
		"seen, but nothing at the height of raised hands: %s" % in_air)
	expect_eq(grid.around(Vector3(3.0, TABLE_Y, 2.0), 0.35), Vector2i.ZERO, "a place the depth does not see")


func test_camera_uv_inverts_its_rays() -> void:
	var image := Image.create(640, 480, false, Image.FORMAT_RGB8)
	var pose := Transform3D(Basis(Vector3.UP, 0.6) * Basis(Vector3.RIGHT, -0.2), Vector3(0.3, 1.1, -0.2))
	var frame := CameraFrame.new(image, pose, 64.0)
	for uv: Vector2 in [Vector2(0.5, 0.5), Vector2(0.1, 0.8), Vector2(0.9, 0.2)]:
		var back := frame.uv(pose.origin + frame.ray(uv.x, uv.y) * 2.3)
		expect(back.is_equal_approx(uv), "%s comes back as %s" % [uv, back])


func test_reality_hit_finds_the_simulated_back_wall() -> void:
	await boot(plan_of(load("res://trials/find/find.tres"), 1))
	var eye := App.head().global_position
	var found := App.reality.hit(eye, Vector3.FORWARD)
	expect(not found.is_empty() and is_equal_approx(found.position.z, -2.95), "the back wall's face: %s" % found)
	expect(found.normal.is_equal_approx(Vector3.BACK), "its normal faces the room")
	expect(App.reality.hit(eye, Vector3.UP).is_empty(), "no ceiling in the simulated room")


func test_the_wall_breaks_where_the_wall_is_and_cleans_up() -> void:
	await boot(plan_of(load("res://trials/find/find.tres"), 1))
	var events := record(Events.reported)
	var eye := App.head().global_position
	WallBreak.burst(eye, Vector3.FORWARD, Vector3.RIGHT)
	var reports := events.filter(func(args: Array) -> bool: return args[0] == &"wall_break")
	expect_eq(reports.size(), 1, "reported once")
	var report: Dictionary = reports[0][1]
	expect(report.found and is_equal_approx(report.at.z, -2.95), "on the wall: %s" % report)
	expect(report.hole.x < WallBreak.HOLE_SIZE.x, "a nearer wall gets a smaller hole: %s" % report.hole)
	var effect: WallBreak = App.stage.get_children().filter(func(node: Node) -> bool: return node is WallBreak)[0]
	var shards := effect.get_children().filter(func(node: Node) -> bool: return node is MeshInstance3D).size() - 1
	expect(shards > 40, "many pieces: %d" % shards)
	expect(await until(func() -> bool: return not App.stage.get_children().any(func(node: Node) -> bool: return node is WallBreak),
		WallBreak.STAY_SECONDS[WallBreak.Style.CRACK] + 2.0), "gone after the hole closes")
