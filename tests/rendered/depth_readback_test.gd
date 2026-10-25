extends TestCase
## DepthSensor's shader and readback on a fake Meta depth image: every grid point
## must come back where the depth and the inverse projection-view put it. Needs a
## renderer: godot --xr-mode off --path . res://tests/run.tscn -- --profile=test --only=depth_readback

const DEPTH_SIZE := 4


func test_points_come_back_where_the_depth_puts_them() -> void:
	var depth := Image.create_empty(DEPTH_SIZE, DEPTH_SIZE, false, Image.FORMAT_RF)
	for y in DEPTH_SIZE:
		for x in DEPTH_SIZE:
			depth.set_pixel(x, y, Color(0.9 + 0.02 * x + 0.005 * y, 0, 0))
	var layers := Texture2DArray.new()
	layers.create_from_images([depth, depth])
	var eye := Transform3D(Basis(Vector3.UP, 0.3), Vector3(0.2, 1.1, -0.3))
	var inverse := (Projection.create_perspective(90.0, 1.0, 0.1, 10.0) * Projection(eye.affine_inverse())).inverse()
	var globals := {&"META_ENVIRONMENT_DEPTH_AVAILABLE": [RenderingServer.GLOBAL_VAR_TYPE_BOOL, true],
		&"META_ENVIRONMENT_DEPTH_TEXTURE": [RenderingServer.GLOBAL_VAR_TYPE_SAMPLER2DARRAY, layers],
		&"META_ENVIRONMENT_DEPTH_INV_PROJECTION_VIEW_LEFT": [RenderingServer.GLOBAL_VAR_TYPE_MAT4, inverse]}
	for name: StringName in globals:
		RenderingServer.global_shader_parameter_add(name, globals[name][0], globals[name][1])
	var rig := Node3D.new()
	add_child(rig)
	var sensor := DepthSensor.new()
	rig.add_child(sensor)
	var grid: DepthGrid = await sensor.read_once()
	var worst := 0.0
	for y in DepthSensor.N:
		for x in DepthSensor.N:
			var uv := (Vector2(x, y) + Vector2.ONE * 0.5) / DepthSensor.N
			var d := depth.get_pixel(int(uv.x * DEPTH_SIZE), int(uv.y * DEPTH_SIZE)).r
			var point := inverse * Vector4(uv.x * 2.0 - 1.0, uv.y * 2.0 - 1.0, d * 2.0 - 1.0, 1.0)
			worst = maxf(worst, grid.points[y * DepthSensor.N + x].distance_to(Vector3(point.x, point.y, point.z) / point.w))
	expect_eq(grid.count(), DepthSensor.N * DepthSensor.N, "every pixel saw something")
	expect(worst < 0.01, "within a centimetre (half floats): %.4f m" % worst)
	rig.free()
	for name: StringName in globals:
		RenderingServer.global_shader_parameter_remove(name)
