extends TestCase


func _move_tip(at: Vector3, side := &"right") -> void:
	var offset := Vector3.BACK * App.rig.pointer(side).tip_reach
	input.point(side, at + offset, at)
	await frames(2)


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
	await _move_tip(at + Vector3.RIGHT * 0.3)
	await _move_tip(at)
	await wait(0.12)
	expect(model.scale.y < 0.4, "squashes")
	await wait(1.0)
	expect_eq(touch.reactions, 1, "stationary hand cannot retrigger")
	expect(model.scale.is_equal_approx(Vector3.ONE * 0.4), "exact rest scale restored")
	await _move_tip(at + Vector3.RIGHT * 0.3)
	await _move_tip(at)
	expect_eq(touch.reactions, 2, "can touch again after leaving")
	App.hold_pause(&"test", true)
	expect(model.scale.is_equal_approx(Vector3.ONE * 0.4), "pause clears reaction")
	await _move_tip(at + Vector3.LEFT * 0.3, &"left")
	await _move_tip(at, &"left")
	expect_eq(touch.reactions, 2, "paused touches ignored")
	App.hold_pause(&"test", false)


func test_quick_taps_each_react_and_sound_without_a_cooldown() -> void:
	await boot()
	var model := Node3D.new()
	app.add_child(model)
	var touch := OnionTouch.new()
	touch.setup(model)
	app.add_child(touch)
	touch.position = App.head().global_position + Vector3(0, -0.15, -0.4)
	for i in 4:
		await _move_tip(touch.global_position + Vector3.RIGHT * 0.3)
		await _move_tip(touch.global_position)
	expect_eq(touch.reactions, 4, "four quick taps, four reactions")
	var sound := touch.get_child(touch.get_child_count() - 1) as AudioStreamPlayer3D
	expect_eq(sound.stream, OnionTouch.SOUND, "the designed touch sound, from Onion's own position")
