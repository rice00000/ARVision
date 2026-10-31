extends TestCase
## The interaction part of the opening: the child pinches the gear, carries it and sets it into
## the socket (Carry), and a translucent teaching hand shows the gestures (DemoHand).
## Most tests drive a Carry on a stand-in gear on the simulated room; the last one checks the
## real Entry configures it.

var carry: Carry
var gear: Node3D
var spin: GearSpin
var eye: Vector3
var table_y: float
var socket: Vector3
var cauldron: Vector3
const YAW := 0.6


## The simulated room, a stand-in gear on the table, and a Carry watching it.
func _scene() -> void:
	await boot(null, &"intro")
	eye = App.head().global_position
	table_y = eye.y - 0.35
	socket = Vector3(eye.x, table_y + 0.012, eye.z - 0.40)
	cauldron = Vector3(eye.x - 0.35, table_y, eye.z - 0.35)
	gear = Node3D.new()
	app.add_child(gear)
	var body := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.0875
	disc.bottom_radius = 0.0875
	disc.height = 0.08
	body.mesh = disc
	body.position.y = 0.04   # the gear's origin is the middle of its base
	gear.add_child(body)
	spin = GearSpin.new()
	gear.add_child(spin)
	spin.running = true
	gear.scale = Vector3.ONE * 0.6
	gear.global_position = Vector3(eye.x + 0.25, table_y, eye.z - 0.30)
	carry = Carry.new()
	app.add_child(carry)
	carry.configure(table_y, eye, 0.62, YAW, cauldron, 0.17)
	carry.begin(gear, socket)
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, eye + Vector3(0.2, -0.1, 0.0)))   # out of the way
	await frames(3)


## Puts the right hand's pinch point at [param p].
func _pinch_at(p: Vector3) -> void:
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, p + Vector3(0.0, 0.0, 0.05)))
	await frames(2)


func _press(down: bool) -> void:
	input.press(&"right", &"trigger_click", down)
	await frames(2)


## Pinches the gear (hand on its middle) and lifts it so its base is at [param base].
func _carry_to(base: Vector3) -> void:
	await _pinch_at(Carry.middle_of(gear))
	await _press(true)
	await _pinch_at(base + Vector3.UP * 0.024)
	await wait(0.4)   # it follows with a little smoothing


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func test_the_middle_of_the_gear_is_halfway_up_its_scaled_body() -> void:
	await _scene()
	expect(Carry.middle_of(gear).distance_to(gear.global_position + Vector3.UP * 0.024) < 0.002, "the pinch target is the gear's middle: %s" % [Carry.middle_of(gear)])


func test_a_pinch_near_the_gear_picks_it_up_and_it_follows_the_hand() -> void:
	await _scene()
	var picked := record(carry.picked_up)
	var hand := Carry.middle_of(gear) + Vector3(0.05, 0.02, 0.0)   # 5 cm off: close enough
	await _pinch_at(hand)
	await _press(true)
	expect_eq(picked.size(), 1, "picked up")
	expect(carry.held, "held")
	expect(carry.has_been_picked_up(), "remembers it was picked up")
	expect(not spin.running, "the gear is stopped while handled")
	var before := gear.global_position
	await _pinch_at(hand + Vector3(0.0, 0.08, -0.06))
	await wait(0.4)
	expect(gear.global_position.distance_to(before + Vector3(0.0, 0.08, -0.06)) < 0.02, "it went with the hand (%s -> %s)" % [before, gear.global_position])


func test_a_pinch_far_from_the_gear_takes_nothing() -> void:
	await _scene()
	var picked := record(carry.picked_up)
	await _pinch_at(Carry.middle_of(gear) + Vector3(0.2, 0.0, 0.0))
	await _press(true)
	expect(picked.is_empty() and not carry.held, "a pinch 20 cm away takes nothing")
	await _press(false)
	await _pinch_at(Carry.middle_of(gear) + Vector3(0.0, 0.0, 0.07))   # closing the pinch as the hand arrives
	await _press(true)
	expect(carry.held, "7 cm from the middle is close enough")


func test_a_pinch_that_closes_just_before_the_hand_arrives_still_takes_it() -> void:
	await _scene()
	await _pinch_at(Carry.middle_of(gear) + Vector3(0.3, 0.0, 0.0))
	await _press(true)
	expect(not carry.held, "not yet")
	await _pinch_at(Carry.middle_of(gear) + Vector3(0.02, 0.0, 0.0))
	await frames(3)
	expect(carry.held, "the hand arrived within a moment of the pinch")


func test_it_cannot_be_picked_up_until_enabled_or_after_stop() -> void:
	await _scene()
	carry.enabled = false
	await _pinch_at(Carry.middle_of(gear))
	await _press(true)
	expect(not carry.held, "not enabled: nothing happens")
	await _press(false)
	carry.enabled = true
	await _press(true)
	expect(carry.held, "enabled: it can be taken")
	carry.stop()
	await frames(2)
	expect(not carry.held and not carry.enabled, "stop lets go and stops watching")


func test_released_over_the_socket_it_aligns_and_docks_with_one_click() -> void:
	await _scene()
	var order: Array[String] = []
	carry.picked_up.connect(func() -> void: order.append("picked_up"))
	carry.released.connect(func(docked: bool) -> void: order.append("released:%s" % docked))
	carry.docked.connect(func() -> void: order.append("docked"))
	var hints := record(Events.feedback)
	await _carry_to(socket + Vector3(0.07, 0.03, -0.04))   # a bit off to the side and above
	expect(hints.is_empty(), "no click while it is carried")
	await _press(false)
	expect(await until(func() -> bool: return carry.has_docked(), 2.0), "it docked")
	expect(gear.global_position.distance_to(socket) < 0.002, "in the socket (%s)" % [gear.global_position])
	expect(absf(angle_difference(gear.global_basis.get_euler().y, YAW)) < 0.01 and absf(gear.global_basis.get_euler().x) < 0.01, "upright, turned to the panel")
	expect(gear.global_basis.get_scale().is_equal_approx(Vector3.ONE * 0.6), "at its playing size")
	expect_eq(order, ["picked_up", "released:true", "docked"], "signals")
	expect_eq(hints.size(), 1, "one click")
	expect_eq(hints[0][0], &"hint", "it is the hint sound")
	expect(not spin.running, "stopped: the story starts the turning after docked")


func test_the_acceptance_volume_is_generous() -> void:
	await _scene()
	await _carry_to(socket + Vector3(0.11, 0.06, 0.0))   # 11 cm to the side, 6 cm up
	await _press(false)
	expect(await until(func() -> bool: return carry.has_docked(), 2.0), "11 cm sideways and 6 cm up still docks")


func test_a_gear_held_high_over_the_socket_floats_in_rather_than_being_missed() -> void:
	await _scene()
	await _carry_to(socket + Vector3(0.02, 0.18, 0.0))
	await _press(false)
	expect(await until(func() -> bool: return carry.has_docked(), 3.0), "released 18 cm above: it settles into the socket")


func test_released_elsewhere_it_floats_down_to_the_table_and_can_be_taken_again() -> void:
	await _scene()
	var released := record(carry.released)
	var docked := record(carry.docked)
	var start := Vector3(eye.x + 0.2, table_y + 0.15, eye.z - 0.25)
	await _carry_to(start)
	await _press(false)
	await wait(1.2)
	expect(absf(gear.global_position.y - table_y) < 0.003, "on the table (y %s, table %s)" % [gear.global_position.y, table_y])
	expect(_flat(gear.global_position, start) < 0.03, "straight below where it was let go")
	expect(absf(gear.global_basis.get_euler().x) < 0.01 and absf(gear.global_basis.get_euler().z) < 0.01, "upright")
	expect_eq(released, [[false]], "released(false)")
	expect(docked.is_empty() and not carry.has_docked(), "never docked, and no failure of any kind")
	await _press(false)
	await _pinch_at(Carry.middle_of(gear))
	await _press(true)
	expect(carry.held, "and it can be picked up again")


func test_a_gear_let_go_a_little_outside_the_volume_settles_on_the_table_beside_the_panel() -> void:
	await _scene()
	await _carry_to(socket + Vector3(0.14, 0.02, 0.0))   # outside the 12 cm volume
	await _press(false)
	await wait(1.2)
	expect(not carry.has_docked(), "not docked")
	expect(_flat(gear.global_position, socket) >= Carry.PANEL_CLEAR - 0.005, "it rests clear of the panel (%s m from the socket)" % _flat(gear.global_position, socket))
	expect(absf(gear.global_position.y - table_y) < 0.003, "on the table")


func test_a_gear_let_go_out_of_reach_settles_within_reach() -> void:
	await _scene()
	await _carry_to(Vector3(eye.x + 0.8, table_y + 0.1, eye.z - 0.3))
	await _press(false)
	await wait(1.2)
	var out := _flat(gear.global_position, eye)
	expect(out <= 0.62 + 0.005 and out > 0.5, "within reach: %s m from the eyes" % out)
	expect(absf(gear.global_position.y - table_y) < 0.003, "on the table")


func test_a_gear_let_go_over_the_cauldron_does_not_land_in_it() -> void:
	await _scene()
	await _carry_to(cauldron + Vector3(0.02, 0.2, 0.0))
	await _press(false)
	await wait(1.2)
	expect(_flat(gear.global_position, cauldron) >= 0.17 - 0.005, "beside the cauldron (%s m from its middle)" % _flat(gear.global_position, cauldron))


func test_it_cannot_be_carried_through_the_table() -> void:
	await _scene()
	await _carry_to(Vector3(eye.x + 0.1, table_y - 0.2, eye.z - 0.3))
	expect(gear.global_position.y >= table_y - 0.001, "the table holds it up")


func test_losing_tracking_while_holding_sets_it_down_quietly_within_reach() -> void:
	await _scene()
	var hints := record(Events.feedback)
	var released := record(carry.released)
	await _carry_to(socket + Vector3(0.0, 0.1, 0.0))   # right over the socket
	input.track(&"right", false)
	await wait(0.4)
	expect(not carry.held, "let go")
	await wait(1.0)
	expect(absf(gear.global_position.y - table_y) < 0.003, "on the table")
	expect(_flat(gear.global_position, socket) >= Carry.PANEL_CLEAR - 0.005, "not left half in the panel")
	expect(hints.is_empty() and not carry.has_docked(), "quietly: no click, not docked")
	expect_eq(released, [[false]], "released(false)")
	input.track(&"right", true)


func test_a_short_tracking_blink_does_not_drop_it() -> void:
	await _scene()
	await _carry_to(Vector3(eye.x + 0.1, table_y + 0.1, eye.z - 0.3))
	input.track(&"right", false)
	await wait(0.1)
	input.track(&"right", true)
	await wait(0.3)
	expect(carry.held, "still in the hand after a blink")


func test_a_pause_lets_go_and_settles() -> void:
	await _scene()
	await _carry_to(Vector3(eye.x + 0.1, table_y + 0.1, eye.z - 0.3))
	Events.facilitator_toggled.emit(true)
	await wait(1.2)
	expect(not carry.held, "let go")
	expect(absf(gear.global_position.y - table_y) < 0.003, "on the table")


func test_the_socket_outline_shows_only_while_the_gear_is_held() -> void:
	await _scene()
	var hint := carry.find_child("SocketHint", true, false) as MeshInstance3D
	expect(hint != null and not hint.visible, "hidden at first")
	expect(hint.global_position.distance_to(socket) < 0.01, "around the socket")
	await _pinch_at(Carry.middle_of(gear))
	await _press(true)
	await wait(0.8)
	expect(hint.visible, "shown while held")
	var low := 1.0
	var high := 0.0
	for i in 8:   # one slow swell (4 s): watch it for a while, it never jumps
		var a := ((hint.mesh as TorusMesh).material as StandardMaterial3D).albedo_color.a
		low = minf(low, a)
		high = maxf(high, a)
		await wait(0.5)
	expect(high - low > 0.1 and high <= 0.65 and low >= 0.29, "a slow brightness change (%s to %s)" % [low, high])
	await _press(false)
	await wait(1.0)
	expect(not hint.visible, "gone after the release")


func test_begin_starts_over_so_a_jump_can_replay_the_part() -> void:
	await _scene()
	await _carry_to(socket)
	await _press(false)
	expect(await until(func() -> bool: return carry.has_docked(), 2.0), "docked")
	gear.global_position = Vector3(eye.x + 0.25, table_y, eye.z - 0.30)
	carry.begin(gear, socket)
	expect(not carry.has_docked() and not carry.has_been_picked_up(), "forgets")
	await _pinch_at(Carry.middle_of(gear))
	await _press(true)
	expect(carry.held, "and can be picked up again")


func test_simulate_still_does_what_the_stub_did() -> void:
	await _scene()
	var order: Array[String] = []
	carry.picked_up.connect(func() -> void: order.append("picked_up"))
	carry.released.connect(func(docked: bool) -> void: order.append("released:%s" % docked))
	carry.docked.connect(func() -> void: order.append("docked"))
	carry.simulate(0.2)
	await wait(1.2)
	expect_eq(order, ["picked_up", "released:true", "docked"], "the story chat's stand-in")
	expect(gear.global_position.distance_to(socket) < 0.002, "and the gear is in")


func test_the_reminder_comes_once_for_a_gear_nobody_touches() -> void:
	await _scene()
	var due := record(carry.reminder_due)
	carry.remind_after = 1.0
	carry.begin(gear, socket)
	await wait(0.6)
	expect(due.is_empty(), "not yet")
	await wait(0.8)
	expect_eq(due.size(), 1, "after the delay")
	await wait(1.5)
	expect_eq(due.size(), 1, "and only once")


func test_no_reminder_for_a_child_who_has_picked_it_up_or_when_it_is_not_in_view() -> void:
	await _scene()
	var due := record(carry.reminder_due)
	carry.remind_after = 1.0
	carry.begin(gear, socket)
	await _pinch_at(Carry.middle_of(gear))
	await _press(true)
	await wait(1.5)
	expect(due.is_empty(), "it was picked up in time")
	await _press(false)
	await wait(1.0)
	gear.visible = false
	carry.begin(gear, socket)
	await wait(1.5)
	expect(due.is_empty(), "a hidden gear is not waiting")


# --- The teaching hand ----------------------------------------------------------------

func _demo() -> DemoHand:
	var demo := DemoHand.new()
	app.add_child(demo)
	return demo


func test_the_demo_hand_pinches_the_gear_without_moving_it() -> void:
	await _scene()
	var demo := _demo()
	var before := gear.global_transform
	demo.pinch_lift(gear)
	await wait(1.9)   # it has reached the gear and closed on it
	var middle := Carry.middle_of(gear)
	expect(demo.visible, "shown")
	expect(demo.global_position.distance_to(middle) < 0.03, "the pinch is on the gear's middle (%s)" % demo.global_position.distance_to(middle))
	await wait(1.4)   # lifted
	expect(demo.global_position.y > middle.y + 0.03, "it lifts a few cm")
	expect(gear.global_transform.is_equal_approx(before), "the real gear never moves")
	var low := 10.0
	for i in 40:
		low = minf(low, demo.global_position.y - middle.y)
		await wait(0.15)
	expect(low < 0.01, "and lowers again: it loops")


func test_the_demo_hand_shows_one_gesture_and_stop_takes_it_away() -> void:
	await _scene()
	var demo := _demo()
	demo.tap(cauldron + Vector3(0.0, 0.15, 0.0))
	await wait(0.9)
	expect(demo.visible, "the tap shows")
	var at := demo.global_position
	demo.lower_release(socket)   # another gesture replaces it, not joins it
	await wait(0.2)
	expect(demo.get_child_count() == 1, "still one hand (%s children)" % demo.get_child_count())
	await wait(1.4)
	expect(demo.global_position.distance_to(socket + Vector3.UP * 0.026) < 0.05, "now over the socket")
	expect(demo.global_position.distance_to(at) > 0.2, "and not at the cauldron")
	demo.stop()
	await wait(0.8)
	expect(not demo.visible, "stop takes the hand away")
	expect(not demo.is_processing(), "and it does no work")


func test_the_demo_hand_fades_softly_and_never_flashes() -> void:
	await _scene()
	var demo := _demo()
	demo.lower_release(socket)
	var material: StandardMaterial3D = null
	var last := 0.0
	var biggest_step := 0.0
	var peak := 0.0
	for i in 400:   # more than a full round of 3.8 s at 60 frames a second
		await frames(1)
		if material == null:
			material = (demo.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh.material as StandardMaterial3D
		var a := material.albedo_color.a
		biggest_step = maxf(biggest_step, absf(a - last))
		peak = maxf(peak, a)
		last = a
	expect(peak <= DemoHand.ALPHA + 0.001 and peak > 0.3, "softly translucent (peak %s)" % peak)
	expect(biggest_step < 0.04, "never jumps (biggest step in a frame %s)" % biggest_step)


func test_stopping_the_demo_hand_cancels_everything_it_was_doing() -> void:
	await _scene()
	var demo := _demo()
	demo.tap(cauldron)
	await wait(0.3)
	demo.stop()
	await wait(0.6)
	var at := demo.global_position
	await wait(1.0)
	expect(demo.global_position.is_equal_approx(at) and not demo.visible, "nothing moves after stop")


# --- In the real opening --------------------------------------------------------------

func _target(id: StringName) -> Target:
	return get_tree().root.find_child(String(id), true, false) as Target


func _press_button(id: StringName) -> void:
	await until(func() -> bool: return _target(id) != null, 20.0)
	await select(_target(id).global_position)
	await frames(2)
	await wait(0.7)


func test_the_real_opening_configures_carry_and_the_gear_docks_in_its_socket() -> void:
	Engine.time_scale = 1.0
	await boot(null, &"intro")
	app.autostart = true
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.skip_setup = false
	entry.poke_in_sim = true
	entry.run()
	await until(func() -> bool: return _target(&"entry_step_next") != null, 20.0)
	input.click(&"right", &"trigger_click")
	await frames(3)
	await wait(0.7)
	await _press_button(&"entry_step_next")     # 1 hands
	await _press_button(&"entry_confirm_yes")   # 2 the table
	await _press_button(&"entry_step_alt")      # 3 the usual spot
	await _press_button(&"entry_step_next")     # 4 heard the chime
	await until(func() -> bool: return _target(&"entry_part_all") != null, 20.0)
	var real: Carry = entry.get("_carry")
	var real_gear: Node3D = entry.get("_gear")
	var real_socket: Vector3 = entry.get("_socket_at")
	var rest: Vector3 = entry.get("_gear_rest")
	expect(real != null and entry.get("_demo") != null, "Entry builds both")
	expect(absf(real.table_y - rest.y) < 0.001, "Carry knows the table")
	expect(absf(real.socket_yaw - (entry.get("_mechanism") as Node3D).rotation.y) < 0.001, "and how the panel faces")
	expect(real.reach_radius > 0.4, "and how far the child reaches")
	# The story brings the gear out and turns Carry on; here we do it by hand.
	real_gear.visible = true
	real_gear.scale = Vector3.ONE * Entry.GEAR_PLAY_SCALE
	real_gear.global_position = rest
	var spinning: GearSpin = entry.get("_gear_spin")
	spinning.running = true
	real.begin(real_gear, real_socket)
	var docked := record(real.docked)
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, Carry.middle_of(real_gear) + Vector3(0.0, 0.0, 0.05)))
	await frames(2)
	input.press(&"right", &"trigger_click", true)
	await frames(2)
	expect(real.held and not spinning.running, "picked up in the real scene, and stopped")
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, real_socket + Vector3(0.04, 0.05, 0.02) + Vector3(0.0, 0.0, 0.05)))
	await wait(0.5)
	input.press(&"right", &"trigger_click", false)
	await until(func() -> bool: return not docked.is_empty(), 3.0)
	expect(real_gear.global_position.distance_to(real_socket) < 0.002, "docked in the real socket")
	expect(absf(angle_difference(real_gear.global_basis.get_euler().y, (entry.get("_mechanism") as Node3D).rotation.y)) < 0.01, "turned to the panel like the story's own dock")


func test_the_real_opening_can_be_tried_with_the_mouse_hand_and_reminds_a_waiting_child() -> void:
	Engine.time_scale = 1.0
	await boot(null, &"intro")
	app.autostart = true
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.skip_setup = false
	entry.poke_in_sim = true
	entry.run()
	await until(func() -> bool: return _target(&"entry_step_next") != null, 20.0)
	input.click(&"right", &"trigger_click")
	await frames(3)
	await wait(0.7)
	await _press_button(&"entry_step_next")
	await _press_button(&"entry_confirm_yes")
	await _press_button(&"entry_step_alt")
	await _press_button(&"entry_step_next")
	await until(func() -> bool: return _target(&"entry_part_all") != null, 20.0)
	var real: Carry = entry.get("_carry")
	var real_gear: Node3D = entry.get("_gear")
	var demo: DemoHand = entry.get("_demo")
	var socket_at: Vector3 = entry.get("_socket_at")
	expect(real.remind_after > 0.0, "the reminder is on")
	entry._try_carry()   # the G key
	expect(real_gear.visible and real.enabled, "the gear is out and Carry is on")
	var driver: DesktopDriver = entry._desktop_driver()
	expect(driver != null, "the mouse driver is there")
	var camera := App.rig.head
	real.remind_after = 0.8   # the real delay is longer; this is only to see it
	real._idle = 0.0
	real._reminded = false
	await wait(1.4)
	expect(demo.visible, "a gear nobody touches gets the teaching hand")
	var before := real_gear.global_transform
	driver._place_hand(camera.unproject_position(Carry.middle_of(real_gear)))   # the mouse over the gear
	await frames(2)
	input.press(&"right", &"trigger_click", true)   # left mouse button down
	await frames(2)
	expect(real.held, "click-hold on the gear takes it")
	await wait(0.8)
	expect(not demo.visible, "and the teaching hand goes away")
	driver._place_hand(camera.unproject_position(socket_at + Vector3.UP * 0.03))   # drag to the socket
	await wait(0.5)
	input.press(&"right", &"trigger_click", false)   # let go
	expect(await until(func() -> bool: return real.has_docked(), 3.0), "dragged over the socket and let go: docked (gear at %s, socket %s)" % [real_gear.global_position, socket_at])
	await wait(0.2)
	expect((entry.get("_gear_spin") as GearSpin).running, "and it turns")
	expect(not before.is_equal_approx(real_gear.global_transform), "it did move")
