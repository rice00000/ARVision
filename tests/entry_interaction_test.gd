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


func test_reset_forgets_so_a_jump_can_replay_the_part() -> void:
	await _scene()
	await _carry_to(socket)
	await _press(false)
	expect(await until(func() -> bool: return carry.has_docked(), 2.0), "docked")
	gear.global_position = Vector3(eye.x + 0.25, table_y, eye.z - 0.30)
	carry.reset()
	expect(not carry.has_docked() and not carry.has_been_picked_up() and not carry.enabled, "forgets")
	carry.begin(gear, socket)
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


# --- Robustness (no headset: the hands are simulated) -----------------------------------

func _left_at(p: Vector3) -> void:
	input.set_hand(&"left", Transform3D(Basis.IDENTITY, p + Vector3(0.0, 0.0, 0.05)))
	await frames(2)


func test_two_hands_pinching_the_first_one_holds_and_the_second_does_not_steal_it() -> void:
	await _scene()
	var picked := record(carry.picked_up)
	var released := record(carry.released)
	await _pinch_at(Carry.middle_of(gear))
	await _press(true)                                   # the right hand takes it
	await _left_at(Carry.middle_of(gear))
	input.press(&"left", &"trigger_click", true)         # the left pinches it too
	await frames(2)
	expect_eq(picked.size(), 1, "picked up once")
	await _pinch_at(Vector3(eye.x + 0.2, table_y + 0.1, eye.z - 0.25))
	await wait(0.4)
	expect(carry.held, "still in the right hand")
	await _press(false)                                  # the right lets go
	await wait(1.2)
	expect_eq(released, [[false]], "let go once")
	expect(not carry.held, "the left hand's closed pinch does not steal it")
	input.press(&"left", &"trigger_click", false)
	await _left_at(Carry.middle_of(gear))
	input.press(&"left", &"trigger_click", true)         # a new pinch does take it
	await frames(2)
	expect(carry.held, "a fresh pinch by the left hand takes it")
	input.press(&"left", &"trigger_click", false)


func test_the_other_hand_losing_tracking_does_not_drop_the_gear() -> void:
	await _scene()
	await _carry_to(Vector3(eye.x + 0.1, table_y + 0.1, eye.z - 0.3))
	input.track(&"left", false)
	await wait(0.6)
	expect(carry.held, "still held by the hand that has it")
	input.track(&"left", true)


func test_the_gear_settles_clear_of_the_cauldron_wherever_it_stands_now() -> void:
	await _scene()
	var pot := Node3D.new()
	app.add_child(pot)
	pot.global_position = Vector3(eye.x + 0.30, table_y, eye.z - 0.30)   # it moved since configure()
	carry.follow(pot, null)
	await _carry_to(pot.global_position + Vector3(0.01, 0.2, 0.0))   # let go right over its mouth
	await _press(false)
	await wait(1.4)
	expect(_flat(gear.global_position, pot.global_position) >= 0.17 - 0.005, "beside the cauldron in its new place (%s m)" % _flat(gear.global_position, pot.global_position))
	expect(absf(gear.global_position.y - table_y) < 0.003, "on the table")


func test_the_docked_gear_faces_the_panel_as_it_stands_now() -> void:
	await _scene()
	var panel := Node3D.new()
	app.add_child(panel)
	panel.rotation.y = 1.1   # turned since configure() said 0.6
	carry.follow(null, panel)
	await _carry_to(socket + Vector3(0.0, 0.03, 0.0))
	await _press(false)
	expect(await until(func() -> bool: return carry.has_docked(), 2.0), "docked")
	expect(absf(angle_difference(gear.global_basis.get_euler().y, 1.1)) < 0.01, "turned like the panel is now")


func test_a_gear_carried_far_away_and_let_go_floats_back_within_reach() -> void:
	await _scene()
	var released := record(carry.released)
	await _carry_to(Vector3(eye.x + 2.5, table_y + 1.0, eye.z - 2.5))   # thrown far
	expect(carry.held and gear.global_position.is_finite(), "it went with the hand")
	await _press(false)
	await wait(2.0)
	var out := _flat(gear.global_position, eye)
	expect(out <= 0.62 + 0.005, "back within reach: %s m" % out)
	expect(absf(gear.global_position.y - table_y) < 0.003 and gear.global_position.is_finite(), "on the table")
	expect_eq(released, [[false]], "no docking, no failure")
	await _press(false)
	await _pinch_at(Carry.middle_of(gear))
	await _press(true)
	expect(carry.held, "and it can be picked up again")


func test_a_tracking_glitch_with_a_nonsense_pose_changes_nothing() -> void:
	await _scene()
	await _carry_to(Vector3(eye.x + 0.1, table_y + 0.1, eye.z - 0.3))
	var at := gear.global_position
	carry._follow(Transform3D(Basis.IDENTITY, Vector3(NAN, 0.0, 0.0)), 0.016)
	carry._follow(Transform3D(Basis.IDENTITY, Vector3(INF, 0.0, 0.0)), 0.016)
	expect(gear.global_position == at and gear.global_position.is_finite(), "the gear stays put")


func test_the_gear_going_away_while_held_does_not_break_carry() -> void:
	await _scene()
	await _carry_to(Vector3(eye.x + 0.1, table_y + 0.1, eye.z - 0.3))
	gear.free()   # a scene change took it
	await frames(3)
	expect(not carry.held, "nothing left to hold")
	await _press(false)
	expect(true, "and no error")


func test_a_jump_button_while_carrying_leaves_nothing_running() -> void:
	await _scene()
	var signals := record(carry.released)
	var hints := record(Events.feedback)
	var hint := carry.find_child("SocketHint", true, false) as MeshInstance3D
	await _carry_to(Vector3(eye.x + 0.15, table_y + 0.12, eye.z - 0.3))
	await wait(0.7)
	expect(hint.visible, "the outline is up while held")
	carry.reset()   # what the story's _set_up_for does
	expect(not carry.held and not carry.enabled, "let go of, and off")
	expect(not carry.has_been_picked_up(), "forgotten")
	expect(signals.is_empty() and hints.is_empty(), "no signal, no click")
	var at := gear.global_position
	await wait(1.5)
	expect(gear.global_position == at, "nothing keeps moving the gear (the story places it itself)")
	expect(not hint.visible, "the outline is gone")
	carry.begin(gear, socket)
	await _press(false)
	await _pinch_at(Carry.middle_of(gear))
	await _press(true)
	expect(carry.held, "the part can be played again")


func test_a_jump_button_while_the_gear_slides_in_cancels_the_docking() -> void:
	await _scene()
	var docked := record(carry.docked)
	var hints := record(Events.feedback)
	await _carry_to(socket + Vector3(0.05, 0.03, 0.0))
	await _press(false)
	await wait(0.1)   # the align takes 0.25 s
	carry.reset()
	var at := gear.global_position
	await wait(0.8)
	expect(docked.is_empty() and hints.is_empty() and not carry.has_docked(), "never docked, no click")
	expect(gear.global_position == at, "and it stopped where it was")


func test_a_jump_button_while_the_gear_floats_down_stops_it() -> void:
	await _scene()
	await _carry_to(Vector3(eye.x + 0.2, table_y + 0.2, eye.z - 0.25))
	await _press(false)
	await wait(0.2)
	carry.reset()
	var at := gear.global_position
	await wait(1.0)
	expect(gear.global_position == at, "the settle was cancelled")


func test_begin_again_while_the_child_has_it_or_has_set_it_in_forgets_nothing() -> void:
	await _scene()
	await _carry_to(Vector3(eye.x + 0.1, table_y + 0.1, eye.z - 0.3))
	carry.begin(gear, socket)   # the story asks again
	expect(carry.held and carry.has_been_picked_up(), "still held")
	await _carry_to(socket + Vector3(0.0, 0.03, 0.0))
	await _press(false)
	expect(await until(func() -> bool: return carry.has_docked(), 2.0), "docked")
	carry.begin(gear, socket)
	expect(carry.has_docked() and carry.enabled, "still docked after being asked again")
	await _pinch_at(Carry.middle_of(gear))
	await _press(true)
	expect(not carry.held, "a docked gear is not pulled out again")


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


func test_asking_for_the_gesture_already_showing_does_not_make_the_hand_blink() -> void:
	await _scene()
	var demo := _demo()
	demo.pinch_lift(gear)
	await wait(1.0)
	expect(demo._fade > 0.99, "fully shown")
	demo.pinch_lift(gear)   # the story's hand and the reminder both ask
	expect(demo._fade > 0.99, "asking again changes nothing")
	demo.pinch_lift(gear)
	await wait(0.1)
	expect(demo._fade > 0.99, "and it is not restarted")


func test_the_pinch_lift_hand_stays_with_its_thing_and_never_points_at_a_place() -> void:
	await _scene()
	var demo := _demo()
	var thing := Node3D.new()   # a shelf thing, far from the socket
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.03
	sphere.height = 0.06
	ball.mesh = sphere
	thing.add_child(ball)
	app.add_child(thing)
	thing.global_position = Vector3(eye.x - 0.5, table_y + 0.03, eye.z - 0.15)
	demo.pinch_lift(thing)
	var middle := Carry.middle_of(thing)
	var farthest := 0.0
	var nearest_socket := INF
	for i in 70:   # a full round (6.6 s) and a little more
		await wait(0.1)
		farthest = maxf(farthest, demo.global_position.distance_to(middle))
		nearest_socket = minf(nearest_socket, demo.global_position.distance_to(socket))
	expect(farthest < 0.13, "never more than 13 cm from the thing it pinches (%s)" % farthest)
	expect(nearest_socket > 0.3, "and never anywhere near the socket (%s)" % nearest_socket)
	thing.free()
	await wait(0.3)
	expect(not demo.visible or not demo.is_processing() or demo.global_position.is_finite(), "a thing that goes away does not leave the hand stuck")


func _frozen(demo: DemoHand, seconds: float) -> void:
	demo.set_process(false)   # held at an exact moment of the loop
	demo._fade = 1.0
	demo._t = seconds
	demo._pose(seconds)
	await frames(2)


func _joint(demo: DemoHand, joint: String) -> Vector3:
	return demo.to_local(demo._skeleton.to_global(demo._skeleton.get_bone_global_pose(demo._skeleton.find_bone(joint)).origin))


func test_the_demo_hand_is_the_glb_hand_translucent_and_without_shadows() -> void:
	await _scene()
	var demo := _demo()
	demo.pinch_lift(gear)
	expect(demo._player != null and demo._skeleton != null, "the GLB hand is used")
	var meshes := demo.find_children("*", "MeshInstance3D", true, false)
	expect(not meshes.is_empty(), "it has a mesh")
	for node in meshes:
		var mesh := node as MeshInstance3D
		expect(mesh.material_override == demo._material, "our translucent material overrides the file's")
		expect_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "no shadows")
	expect(demo._material.albedo_color.is_equal_approx(Color(0.96, 0.9, 0.8, demo._material.albedo_color.a)), "the stand-in's colour")
	expect(is_equal_approx(demo._material.emission_energy_multiplier, 0.35), "and its glow")
	expect(demo._material.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED, "so that alpha fades work")
	expect(is_equal_approx(demo._figure.get_child(0).scale.x, DemoHand.HAND_SCALE), "scaled by the one constant")
	await _frozen(demo, 1.1)
	expect(demo._material.albedo_color.a <= DemoHand.ALPHA + 0.001 and demo._material.albedo_color.a > 0.3, "softly translucent")


func test_the_glb_hand_has_its_fingers_forward_and_its_tips_meet_at_the_pinch_point() -> void:
	await _scene()
	var demo := _demo()
	demo.pinch_lift(gear)
	await _frozen(demo, 1.1)   # open
	var index_tip := _joint(demo, "PointR_JNT3")
	var thumb_tip := _joint(demo, "ThumbR_JNT3")
	var middle_tip := _joint(demo, "MiddleR_JNT3")
	var wrist := _joint(demo, "WristR_JNT")
	expect(middle_tip.z < wrist.z - 0.05, "the fingers point -Z, the wrist is behind (%s vs %s)" % [middle_tip.z, wrist.z])
	expect(index_tip.y > thumb_tip.y + 0.01, "the index finger is above the thumb")
	await _frozen(demo, 1.7)   # closed
	expect(_joint(demo, "PointR_JNT3").length() < 0.006 and _joint(demo, "ThumbR_JNT3").length() < 0.006, "closed, both tips are at the pinch point")


func test_open_maps_to_the_pinch_clip_and_the_tap_follows_its_own_keys() -> void:
	await _scene()
	var demo := _demo()
	demo.pinch_lift(gear)
	await _frozen(demo, 1.1)   # open 1.0
	expect_eq(demo._shown_clip, "pinch", "the pinch clip")
	expect(absf(demo._shown_at - 0.0) < 0.001, "open 1.0 is the clip's start (%s)" % demo._shown_at)
	await _frozen(demo, 2.0)   # open 0.0
	expect(absf(demo._shown_at - 1.0) < 0.001, "open 0.0 is the clip's end (%s)" % demo._shown_at)
	demo.stop()
	await wait(0.6)
	demo.tap(cauldron)
	await _frozen(demo, DemoHand.TAP_DOWN * 0.5)
	expect_eq(demo._shown_clip, "tap", "the tap clip")
	expect(absf(demo._shown_at - 0.25) < 0.001, "halfway down is a quarter in (%s)" % demo._shown_at)
	await _frozen(demo, (DemoHand.TAP_DOWN + DemoHand.TAP_UP) * 0.5)
	expect(absf(demo._shown_at - 0.5) < 0.001, "on the rim it is pressed (%s)" % demo._shown_at)
	await _frozen(demo, DemoHand.TAP_LOOP - 0.1)
	expect(absf(demo._shown_at - 1.0) < 0.001, "and back at rest")


func test_a_tap_points_with_the_index_fingertip_on_the_rim() -> void:
	await _scene()
	var demo := _demo()
	var rim := cauldron + Vector3.UP * 0.12
	demo.tap(rim)
	await _frozen(demo, (DemoHand.TAP_DOWN + DemoHand.TAP_UP) * 0.5)
	var tip := demo.to_global(_joint(demo, "PointR_JNT3"))
	expect(tip.distance_to(rim) < 0.02, "the index fingertip is on the rim, within 2 cm (%s)" % tip.distance_to(rim))
	var middle := _joint(demo, "MiddleR_JNT3")
	var index := _joint(demo, "PointR_JNT3")
	expect(middle.distance_to(index) < 0.07 and middle.z > index.z - 0.02, "the other fingers are folded, not reaching past it")
	demo.pinch_lift(gear)   # the next gesture starts from a plain hand again
	await _frozen(demo, 1.1)
	expect(demo._figure.position == Vector3.ZERO, "the hand is back at its own origin")


func test_without_the_glb_the_primitive_hand_does_the_same_job() -> void:
	await _scene()
	var plain := _demo()
	plain.use_glb = false
	plain.pinch_lift(gear)
	expect(plain._player == null and plain._index.size() == 2, "the primitives are built")
	await wait(1.9)
	expect(plain.visible and plain.global_position.distance_to(Carry.middle_of(gear)) < 0.03, "and work")
	var missing := _demo()
	missing.hand_file = "res://entry/assets/hand/not_there.glb"
	missing.tap(cauldron)
	expect(missing._player == null and missing._index.size() == 2, "a missing file falls back as well")
	await wait(0.9)
	expect(missing.visible, "and shows")
	var broken := _demo()
	broken.hand_file = "res://entry/assets/hand/LICENSE.md"   # exists, but is no hand
	broken.lower_release(socket)
	expect(broken._player == null and broken._index.size() == 2, "a file that does not load as a hand falls back")


func test_stop_is_safe_to_repeat_and_leaves_nothing_behind() -> void:
	await _scene()
	var demo := _demo()
	demo.stop()   # before anything was shown
	demo.pinch_lift(gear)
	await wait(0.6)
	demo.stop()
	demo.stop()
	await wait(0.7)
	expect(not demo.visible and demo.get_child_count() == 0 and not demo.is_processing(), "gone: no node, no work")
	demo.stop()
	demo.tap(cauldron)   # and it can show again
	await wait(0.6)
	expect(demo.visible and demo.get_child_count() == 1, "again, one hand")
	demo.stop()
	await wait(0.7)
	expect_eq(demo.get_child_count(), 0, "gone again")


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
	expect_eq(demo.get_child_count(), 0, "and no hand node is left")


func test_the_demo_hand_fades_softly_and_never_flashes() -> void:
	await _scene()
	var demo := _demo()
	demo.lower_release(socket)
	var material: StandardMaterial3D = demo._material
	var last := 0.0
	var biggest_step := 0.0
	var peak := 0.0
	for i in 400:   # more than a full round of 3.8 s at 60 frames a second
		await frames(1)
		material = demo._material
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


func test_the_real_opening_does_not_wait_for_a_gear_the_child_already_set_in() -> void:
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
	var real_socket: Vector3 = entry.get("_socket_at")
	expect(real._cauldron_node == entry.get("_box") and real._panel_node == entry.get("_mechanism"), "Carry follows the cauldron and the panel")
	entry._try_carry()
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, Carry.middle_of(real_gear) + Vector3(0.0, 0.0, 0.05)))
	await frames(2)
	input.press(&"right", &"trigger_click", true)
	await frames(2)
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, real_socket + Vector3(0.0, 0.03, 0.0) + Vector3(0.0, 0.0, 0.05)))
	await wait(0.5)
	input.press(&"right", &"trigger_click", false)   # set in early, while the story is still talking
	expect(await until(func() -> bool: return real.has_docked(), 3.0), "docked early")
	var done := {finished = false}
	var wait_for_it := func() -> void:
		await entry._child_sets_in()
		done.finished = true
	wait_for_it.call()
	expect(await until(func() -> bool: return done.finished, 1.5), "the story's wait for 'set it in' ends at once")
