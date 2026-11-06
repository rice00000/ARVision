extends TestCase


func test_touch_springs_once_returns_to_scale_and_rearms_after_leaving() -> void:
	await boot()
	var model := Node3D.new()
	app.add_child(model)
	model.scale = Vector3.ONE * 0.4
	var touch := OnionTouch.new()
	touch.setup(model)
	app.add_child(touch)
	touch.position = App.head().global_position + Vector3(0, -0.15, -0.4)
	var at := touch.global_position
	input.point(&"right", at + Vector3.BACK * 0.05, at)
	await frames(3)
	Events.touched.emit(&"right", touch)
	await wait(0.12)
	expect(model.scale.y < 0.4, "squashes")
	await wait(1.0)
	Events.touched.emit(&"right", touch)
	expect_eq(touch.reactions, 1, "stationary hand cannot retrigger")
	expect(model.scale.is_equal_approx(Vector3.ONE * 0.4), "exact rest scale restored")
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, at + Vector3.RIGHT * 0.3))
	await frames(3)
	Events.touched.emit(&"right", touch)
	expect_eq(touch.reactions, 2, "can touch again after leaving")
	App.hold_pause(&"test", true)
	expect(model.scale.is_equal_approx(Vector3.ONE * 0.4), "pause clears reaction")
	Events.touched.emit(&"left", touch)
	expect_eq(touch.reactions, 2, "paused touches ignored")
	App.hold_pause(&"test", false)
