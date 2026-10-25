extends TestCase
## The rig's input path: Pointer rays hit only Targets, the fingertip touches,
## buttons and tracking become Events, and the desktop mouse drives it all.

const FIND := preload("res://trials/find/find.tres")


func _body(layer: int, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = Vector3(0.3, 0.3, 0.02)
	body.add_child(shape)
	app.add_child(body)
	body.global_position = at
	return body


func _area(layer: int, at: Vector3) -> Area3D:
	var area := Area3D.new()
	area.collision_layer = layer
	area.collision_mask = 0
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	area.add_child(shape)
	app.add_child(area)
	area.global_position = at
	return area


func test_the_ray_hits_targets_only() -> void:
	await boot(plan_of(FIND, 1))
	var selected := record(Events.selected)
	var hand := Vector3(0.0, 1.0, 0.0)
	var target := Target.sphere(&"probe", 0.05)
	app.add_child(target)
	target.global_position = Vector3(0.0, 1.0, -1.5)
	_body(2, Vector3(0, 1, -0.7)) # something real in the way
	_body(1, Vector3(0, 1, -0.9)) # even a body on the targets layer
	_area(2, Vector3(0, 1, -1.1)) # an area on the reality layer
	input.point(&"right", hand, target.global_position)
	await frames(2)
	var pointer := App.rig.pointer(&"right")
	expect_eq(pointer.cast(), target, "rays pass real things and bodies")
	expect_eq(pointer.aimed, target, "aimed follows")
	input.click(&"right", &"trigger_click")
	expect_eq(selected.size(), 1, "one selection")
	expect_eq(selected[0][1], target, "of the Target")
	expect(selected[0][2].is_equal_approx(hand), "from the controller")
	expect(selected[0][3].is_equal_approx(Vector3.FORWARD), "along its aim")
	var plain := _area(1, Vector3(0, 1, -1.2)) # a non-Target area on the targets layer
	await frames(2)
	expect_eq(pointer.cast(), null, "a non-Target area blocks the ray and selects nothing")
	plain.free()
	input.point(&"right", hand, hand + Vector3(0, 1, -0.1)) # up, away from every target
	await frames(2)
	input.click(&"right", &"trigger_click")
	expect_eq(selected.back()[1], null, "the ray always comes, even at nothing")
	target.global_position = hand + Vector3.FORWARD * (pointer.length + 0.2)
	input.point(&"right", hand, target.global_position)
	await frames(2)
	expect_eq(pointer.cast(), null, "beyond the ray's length")


func test_the_fingertip_touches_targets() -> void:
	await boot(plan_of(FIND, 1))
	var touched := record(Events.touched)
	var target := Target.sphere(&"probe", 0.05)
	app.add_child(target)
	target.global_position = Vector3(0.3, 0.9, -0.5)
	var pointer := App.rig.pointer(&"left")
	input.point(&"left", target.global_position + Vector3(0, 0, 0.3), target.global_position)
	await frames(3)
	expect(touched.is_empty(), "not yet")
	input.point(&"left", target.global_position + Vector3(0, 0, pointer.tip_reach), target.global_position)
	await frames(3)
	expect_eq(touched.size(), 1, "the tip entered")
	expect_eq(touched[0], [&"left", target], "which hand, which target")
	expect(pointer.tip().is_equal_approx(target.global_position), "tip() is the fingertip")


func test_a_resting_fingertip_touches_nothing() -> void:
	await boot(plan_of(FIND, 1))
	var touched := record(Events.touched)
	var pointer := App.rig.pointer(&"left")
	var spot := Vector3(0.3, 0.9, -0.5)
	input.point(&"left", spot + Vector3(0, 0, pointer.tip_reach), spot)
	await wait(pointer.rest_seconds + 0.1)
	expect(pointer.resting(), "the hand has been still")
	var target := Target.sphere(&"probe", 0.05)
	app.add_child(target)
	target.global_position = spot
	await frames(3)
	expect(touched.is_empty(), "a target that appears under a resting fingertip is not touched")
	input.point(&"left", spot + Vector3(0, 0, 0.3), spot)
	await frames(3)
	input.point(&"left", spot + Vector3(0, 0, pointer.tip_reach), spot)
	await frames(3)
	expect_eq(touched.size(), 1, "reaching in touches it")


func test_pinches_raised_hands_the_menu_pinch_and_tracking_become_events() -> void:
	await boot(plan_of(FIND, 1))
	var buttons := record(Events.button)
	var help := record(Events.help_requested)
	var tracking := record(Events.hand_tracking)
	input.click(&"left", &"grip_click")
	expect_eq(buttons.slice(0, 2), [[&"left", &"grip_click", true], [&"left", &"grip_click", false]], "press and release")
	input.menu()
	expect_eq(buttons.back(), [&"left", &"menu_pressed", true], "the left-hand menu pinch")
	var pointer := App.rig.pointer(&"right")
	var eye := App.head().global_position
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, eye + Vector3(0.2, pointer.raise_height * 0.5, -0.3)))
	await wait(pointer.raise_seconds + 0.2)
	expect(help.is_empty(), "a hand at eye height does not ask")
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, eye + Vector3(0.2, 0.2, -0.3)))
	await wait(pointer.raise_seconds - 0.1)
	expect(help.is_empty(), "not before it has been up a moment")
	await wait(1.0)
	expect_eq(help.size(), 1, "a raised hand asks for help, once")
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, eye + Vector3(0.2, -0.3, -0.3)))
	await frames(2)
	await raise_hand(&"left")
	expect_eq(help.size(), 2, "either hand")
	await raise_hand(&"right")
	expect_eq(help.size(), 3, "down and up again asks again")
	input.track(&"right", false)
	await frames(2)
	input.track(&"right", true)
	await frames(2)
	expect_eq(tracking.filter(func(args: Array) -> bool: return args[0] == &"right"), [[&"right", false], [&"right", true]], "lost, found")


func test_a_brisk_hand_move_is_a_sweep_a_jump_or_a_creep_is_not() -> void:
	await boot(plan_of(FIND, 1))
	var swept := record(Events.swept)
	var pointer := App.rig.pointer(&"right")
	var start := App.head().global_position + Vector3(0.2, -0.4, -0.4)
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, start))
	await frames(2)
	expect(swept.is_empty(), "a jump (tracking finding the hand) is no sweep")
	await _glide(&"right", start, start + Vector3.RIGHT * 0.3, 0.3)
	await wait(pointer.sweep_stop_seconds + 0.1)
	expect_eq(swept.size(), 1, "one sweep once the hand holds still")
	expect_eq(swept[0][0], &"right", "by the right hand")
	expect(swept[0][1].is_equal_approx(start), "from where it left rest: %s" % swept[0][1])
	expect(swept[0][2].is_equal_approx(start + Vector3.RIGHT * 0.3), "to where it stopped: %s" % swept[0][2])
	expect(absf(swept[0][3] - 0.3) < 0.05, "taking about 0.3 s: %s" % swept[0][3])
	await _glide(&"right", start + Vector3.RIGHT * 0.3, start, 2.0) # 0.15 m/s: a creep
	await wait(pointer.sweep_stop_seconds + 0.1)
	expect_eq(swept.size(), 1, "a slow move is no sweep")
	# Out and straight back without a stop: the way out is the sweep, the way back is not.
	await _glide(&"right", start, start + Vector3.RIGHT * 0.3, 0.3)
	await _glide(&"right", start + Vector3.RIGHT * 0.3, start, 0.3)
	await wait(pointer.sweep_stop_seconds + 0.1)
	expect_eq(swept.size(), 2, "the wave out was reported as soon as the hand turned back")
	expect(swept[1][2].is_equal_approx(start + Vector3.RIGHT * 0.3), "to its farthest point: %s" % swept[1][2])
	# A hand that keeps going after a stop starts another sweep.
	await _glide(&"right", start, start + Vector3.FORWARD * 0.2, 0.2)
	await wait(pointer.sweep_stop_seconds + 0.1)
	await _glide(&"right", start + Vector3.FORWARD * 0.2, start + Vector3.FORWARD * 0.4, 0.2)
	await wait(pointer.sweep_stop_seconds + 0.1)
	expect_eq(swept.size(), 4, "two sweeps with a stop between")
	input.track(&"right", false)
	await frames(2)
	input.track(&"right", true)
	await _glide(&"right", start + Vector3.FORWARD * 0.4, start + Vector3.FORWARD * 0.4 + Vector3.RIGHT * 0.15, 0.15)
	input.track(&"right", false)
	await frames(2)
	input.track(&"right", true)
	await wait(pointer.sweep_stop_seconds + 0.1)
	expect_eq(swept.size(), 4, "a sweep cut by a tracking loss is dropped")


## Moves a hand from [param from] to [param to] over [param seconds], a step per physics tick.
func _glide(side: StringName, from: Vector3, to: Vector3, seconds: float) -> void:
	var steps := maxi(1, roundi(seconds * Engine.physics_ticks_per_second))
	for i in steps:
		input.set_hand(side, Transform3D(Basis.IDENTITY, from.lerp(to, float(i + 1) / steps)))
		await get_tree().physics_frame


func test_the_desktop_mouse_drives_the_right_hand() -> void:
	get_window().size = Vector2i(1280, 800) # headless windows start at 64 x 64
	Input.use_accumulated_input = false
	await boot(plan_of(FIND, 1))
	var selected := record(Events.selected)
	var help := record(Events.help_requested)
	var toggled := record(Events.facilitator_toggled)
	App.session.run()
	await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running())
	await frames(2) # new toys join ray queries after a physics step
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_RIGHT
	drag.relative = Vector2(100, 50)
	Input.parse_input_event(_button_event(MOUSE_BUTTON_RIGHT, true, Vector2(640, 400)))
	Input.parse_input_event(drag)
	Input.parse_input_event(_button_event(MOUSE_BUTTON_RIGHT, false, Vector2(640, 400)))
	expect(App.head().rotation.is_equal_approx(Vector3(-0.2, -0.4, 0.0)), "right drag turns the head: %s" % App.head().rotation)
	var target: Target = App.session.trial.get("_target")
	input.look_at(target.global_position)
	var cursor := App.head().unproject_position(target.global_position)
	expect(cursor.distance_to(Vector2(640, 400)) < 1.0, "looking at the toy puts it mid-screen: %s" % cursor)
	_mouse(MOUSE_BUTTON_LEFT, true, cursor)
	await frames(1)
	expect_eq(selected.size(), 1, "a left press pinches")
	expect_eq(selected[0][1], target, "at what is under the cursor")
	_mouse(MOUSE_BUTTON_LEFT, false, cursor)
	var hand := App.rig.hand(&"right").global_position
	var expected := App.head().project_ray_origin(cursor) + App.head().project_ray_normal(cursor) * 0.45
	expect(hand.is_equal_approx(expected), "the hand sits 0.45 m along the cursor's ray")
	_mouse(MOUSE_BUTTON_WHEEL_UP, true, cursor)
	expect(App.rig.hand(&"right").global_position.distance_to(App.head().global_position)
		> hand.distance_to(App.head().global_position), "the wheel moves the hand farther")
	_key(KEY_H)
	await wait(App.rig.pointer(&"left").raise_seconds + 0.1)
	expect_eq(help.size(), 1, "H raises the left hand to ask for help")
	_key(KEY_M)
	expect_eq(toggled, [[true]], "M opens the facilitator panel")
	_key(KEY_M)
	Input.use_accumulated_input = true


func _button_event(button: MouseButton, pressed: bool, at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = at
	event.global_position = at
	return event


func _mouse(button: MouseButton, pressed: bool, at: Vector2) -> void:
	Input.parse_input_event(_button_event(button, pressed, at))


func _key(key: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
