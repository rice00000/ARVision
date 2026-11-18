extends TestCase
## Megan's opening (Entry in main.tscn, direction of Oct 30): it plays before the
## World unless a session plan is given. Setup for the adult (table check, then
## Start or a part to jump to), then Onion's hello, the cauldron touch, the things
## coming out, the ripple, and Wei's shelf with Onion as the guide.

const TIDY := preload("res://trials/tidy/tidy.tres")
const Tidy := preload("res://trials/tidy/tidy_trial.gd")
const Motion := preload("res://trials/motion/motion_trial.gd")

var entry: Entry


## Boots main.tscn and starts the opening, like a launch without a plan does.
func _boot_entry() -> void:
	Engine.time_scale = 1.0   # an earlier test may have left the opening's half speed on
	await boot(null, &"intro")
	app.autostart = true   # when the opening ends and switches scene, the next scene starts itself
	entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false   # these tests look at the room before pressing anything
	entry.touch_cauldron_in_sim = true   # the tests tap the cauldron with a fingertip
	entry.skip_setup = false   # the tests go through the four steps
	entry.simulate_child = true   # a pretend child picks the gear up and sets it in
	entry.run()


## The hub (Scene 7): waits until the game [param kind] waits in the ring, then pinches it.
func _choose_game(kind: StringName, timeout := 60.0) -> bool:
	var found := {}
	var ready := func() -> bool:
		var hub := app.find_child("WorkshopController", true, false) as WorkshopController
		if hub == null or hub.state != &"hub" or hub.ring == null or hub.ring.turning:
			return false
		for impression in hub.ring.impressions:
			if is_instance_valid(impression) and impression.kind == kind:
				found.target = impression.target
				return true
		return false
	if not await until(ready, timeout):
		return false
	var hub := app.find_child("WorkshopController", true, false) as WorkshopController
	await until(func() -> bool: return not app.get_tree().paused, 10.0)
	if not hub.ring.opened:   # the cauldron is the menu: one tap opens it
		Events.selected.emit(&"right", hub.cauldron_target, Vector3.ZERO, Vector3.FORWARD)
		if not await until(func() -> bool: return hub.ring.opened and not hub.ring.turning, 10.0):
			return false
	Events.selected.emit(&"right", found.target, Vector3.ZERO, Vector3.FORWARD)
	# A game with a level finished opens its own row (design chat, Nov 18): pinch the recommended one.
	await until(func() -> bool: return hub.state != &"hub" or (hub.row != null and hub.row.opened), 3.0)
	if hub.row != null and hub.row_kind == &"levels":
		Events.selected.emit(&"right", hub.row.leader().target, Vector3.ZERO, Vector3.FORWARD)
	return true


func _said_line(said: Array, text: String) -> bool:
	return said.any(func(args: Array) -> bool: return args[0] == text)


func _until_said(said: Array, text: String, timeout := 30.0) -> bool:
	return await until(func() -> bool: return _said_line(said, text), timeout)


func _target(id: StringName) -> Target:
	return entry.find_child(String(id), true, false) as Target


## Waits for a button and presses it (points and pinches), then waits out the gap in which
## the same button ignores a second press.
func _press(id: StringName) -> bool:
	if not await until(func() -> bool: return _target(id) != null, 20.0):
		return false
	await select(_target(id).global_position)
	await frames(2)
	await wait(0.7)
	return true


## Goes through the four setup steps to "All set" (the Start button).
func _to_setup_panel() -> void:
	await until(func() -> bool: return _target(&"entry_step_next") != null, 20.0)
	input.click(&"right", &"trigger_click")   # step 1 wants a pinch
	await frames(3)
	await wait(0.7)
	await _press(&"entry_step_next")     # 1 hands
	await _press(&"entry_confirm_yes")   # 2 the table
	await _press(&"entry_step_alt")      # 3 the usual spot
	await _press(&"entry_step_next")     # 4 heard the chime
	await until(func() -> bool: return _target(&"entry_part_all") != null, 20.0)


## Touches the cauldron once it glows (the cue).
func _touch_cauldron() -> void:
	await until(func() -> bool: return (entry.get("_orb") as Onion).cue, 30.0)
	var at := _target(&"entry_cauldron").global_position
	var eye := App.head().global_position
	var along := (at - (eye + Vector3.DOWN * 0.2)).normalized()
	input.point(&"right", at - along * App.rig.pointer(&"right").tip_reach, at)
	await frames(2)
	input.point(&"right", eye + Vector3(0.2, -0.25, -0.15), eye + Vector3(0.2, -0.4, -0.6))   # hand back
	await frames(2)


## The gear stands in the socket and is turning.
func _docked() -> bool:
	var gear: Node3D = entry.get("_gear")
	var seat: Vector3 = entry.call("_seat_at")   # down in the socket (SOCKET_SINK, Nov 10)
	return gear.visible and gear.global_position.distance_to(seat) < 0.01 and (entry.get("_gear_spin") as GearSpin).running


func _shown(entry_details: Array) -> int:
	return entry_details.filter(func(d: Node3D) -> bool: return is_instance_valid(d) and d.visible).size()


func test_a_launch_plays_the_opening_before_the_world_and_a_plan_skips_it() -> void:
	var said := record(Events.said)
	app = load("res://main.tscn").instantiate()
	add_child(app)
	input = App.sim_input
	await frames(2)
	expect(App.world == null, "the World is not loaded during the opening")
	expect_eq(App.main.current_scene, &"intro", "the opening is its own scene")
	await shutdown()
	app = load("res://main.tscn").instantiate()
	app.plan = plan_of(TIDY, 1)
	add_child(app)
	input = App.sim_input
	await wait(3.0)
	expect(not _said_line(said, "Oh! Hello there."), "no opening before a planned session")
	expect(app.find_child("Entry", true, false) == null, "and the opening is not loaded")


func test_setup_is_quiet_and_waits_for_start() -> void:
	await _boot_entry()
	var said := record(Events.said)
	await _to_setup_panel()
	var panel := entry.get("_panel") as SetupPanel
	await open_intro_tools()
	expect(not panel.visible and not _target(&"entry_part_all").is_visible_in_tree(), "Tools hides the setup panel and its button")
	input.menu()
	await frames(2)
	expect(panel.visible, "setup returns when Tools closes")
	await wait(6.0)
	expect(said.is_empty(), "nothing is said before Start (no 'Got it' line either): %s" % [said])
	expect(App.module(&"Music").playing(), "the piano is already playing (it plays from the start)")


func test_start_plays_everything_into_the_world() -> void:
	await _boot_entry()
	var said := record(Events.said)
	await _to_setup_panel()
	expect(await _press(&"entry_part_all"), "Start is pressed")
	expect(await _until_said(said, "Oh! Hello there."), "Onion says hello")
	expect(await _until_said(said, "I'm Onion, by the way."), "and its name")
	await _touch_cauldron()
	expect(await until(func() -> bool: return (entry.get("_gear") as Node3D).visible, 30.0), "the gear comes out of the cauldron")
	expect(await _until_said(said, Entry.REVEAL_LINE, 60.0), "the reveal: the cauldron's puff, then Onion's line")
	expect(await _until_said(said, "Welcome to the workshop.", 60.0), "the hub: the shelf rises into the ring, then welcome")
	expect_eq(App.main.current_scene, &"first_visit", "the hub is in the first visit's scene")
	expect(App.session.trial == null, "nothing plays until the child chooses the shelf")
	expect(await _choose_game(&"shelf"), "the child pinches the shelf in the ring")
	expect(await _until_said(said, "The shapes on the shelf show where things go.", 60.0), "Onion leads the first shelf level")
	expect(await _until_said(said, "Pick whichever one you'd like to start with.", 60.0), "and invites")
	expect_eq(App.main.current_scene, &"first_visit", "in its own scene")


## Megan, Nov 18: a jump sets everything as its part finds it, plays that part and then the rest of the story.
func test_jumping_to_each_part_sets_it_up_and_plays_on() -> void:
	await _boot_entry()
	var said := record(Events.said)
	await _to_setup_panel()
	var orb: Node3D = entry.get("_orb")
	var gear := entry.get("_gear") as Node3D

	# Hello: Onion inside, the gear hidden, no workshop.
	await jump_to_intro_part(&"hello")
	await frames(2)
	expect_eq(_shown(entry.get("_details")), 0, "hello: the workshop is hidden")
	expect(not gear.visible, "hello: the gear is hidden")
	expect(await _until_said(said, "I'm Onion, by the way."), "hello: plays")

	# Touch: waits for the tap; after it the story goes on: the gear comes out.
	await jump_to_intro_part(&"touch")
	await _touch_cauldron()
	expect(await until(func() -> bool: return gear.visible, 30.0), "touch: after the tap, the gear comes out")

	# Emerge: the gear out on the table, waiting to be picked up.
	await jump_to_intro_part(&"emerge")
	expect(await until(func() -> bool: return gear.visible and not _docked(), 30.0), "emerge: the gear is out on the table")

	# Pick up: the stand-in child takes it, and the story plays on: it is set in.
	await jump_to_intro_part(&"pickup")
	expect(await until(func() -> bool: return (entry.get("_sounds") as Sounds).played.has(&"seat"), 60.0), "pickup, then place: the gear is seated")

	# Set in: the gear ends turning in its socket.
	await jump_to_intro_part(&"place")
	expect(await until(func() -> bool: return _docked(), 30.0), "place: the gear is in its socket")

	# Still one of each.
	expect_eq(entry.find_children("*", "Target", true, false).filter(func(t: Target) -> bool: return t.id == &"entry_cauldron").size(), 1, "one cauldron")

	# Reveal: the gear already in, Onion up beside it; the puff and line, then on into the hub.
	said.clear()
	await jump_to_intro_part(&"reveal")
	await frames(2)
	expect(await until(func() -> bool: return _docked(), 20.0), "reveal: the gear is already in its socket")
	expect(orb.global_position.distance_to(entry.call("_lifted_spot")) < 0.15, "reveal: Onion is already up beside the socket")
	expect(await _until_said(said, Entry.REVEAL_LINE, 60.0), "reveal: plays (the puff, then Onion's line)")
	expect(not _said_line(said, "Oh! Hello there."), "reveal: no hello")
	expect_eq(_shown(entry.get("_details")), 0, "reveal: no shelf at the reveal (Scene 6; the hub offers it)")
	expect(await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 60.0), "then the hub")


## Puts the right fingertip at [param point] (button space), the hand behind it pointing into the plate.
func _poke_at(button: EntryButton, local: Vector3) -> void:
	var tip := button.to_global(local)
	var back := button.global_basis.z.normalized()
	input.point(&"right", tip + back * App.rig.pointer(&"right").tip_reach, tip)
	await frames(3)


func test_a_fingertip_crossing_the_plate_does_not_press_it() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var pressed := record(entry._part_pressed)
	var start: EntryButton = _target(&"entry_part_all").get_parent()
	await wait(1.0)   # give the setup its normal settling time
	# Near the far end of the plate, which the old round hit area missed.
	await _poke_at(start, Vector3(start.plate.x * 0.5 - 0.01, 0.0, 0.15))
	await _poke_at(start, Vector3(start.plate.x * 0.5 - 0.01, 0.0, -0.01))
	expect_eq(pressed.size(), 0, "crossing the UI never confirms it")
	Events.touched.emit(&"right", start.target)
	await frames(2)
	expect(pressed.is_empty(), "the old touch event has no UI listener")
	await select(start.global_position)
	expect_eq(pressed.size(), 1, "an aimed pinch confirms once")


func test_a_pinch_off_the_button_does_not_press_a_previous_target() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var pressed := record(entry._part_pressed)
	var start: EntryButton = _target(&"entry_part_all").get_parent()
	var eye := App.head().global_position
	# Aim at the top edge of Start, from a hand just below the eyes.
	var from := eye + Vector3.DOWN * 0.05
	var edge := start.global_position + start.global_basis.y * (start.plate.y * 0.5 + start.margin - 0.005)
	var direction := (edge - from).normalized()
	input.point(&"right", from, from + direction)
	await wait(0.5)
	# The aim slips 4.5 degrees up, off the button, as the fingers close; then the click lands.
	var slipped := direction.rotated(direction.cross(Vector3.UP).normalized(), deg_to_rad(4.5))
	input.point(&"right", from, from + slipped)
	await wait(0.08)
	input.click(&"right", &"trigger_click")
	await frames(3)
	expect(pressed.is_empty(), "only the current ray hit can confirm a button")


func test_a_pinch_after_a_real_move_to_another_button_goes_to_that_button() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var pressed := record(entry._part_pressed)
	await open_intro_tools()
	var facilitator := App.module(&"Facilitator")
	var ripple := facilitator.find_child("fac_jump_reveal", true, false) as Target
	var shelf := facilitator.find_child("fac_jump_shelf", true, false) as Target
	var eye := App.head().global_position
	input.point(&"right", eye + Vector3.DOWN * 0.05, ripple.global_position)
	await wait(0.5)
	input.point(&"right", eye + Vector3.DOWN * 0.05, shelf.global_position)   # one step down the column: a move, not a slip
	await wait(0.02)
	input.click(&"right", &"trigger_click")
	await frames(3)
	expect_eq(pressed.size(), 1, "one press")
	expect_eq(pressed[0][0] if not pressed.is_empty() else null, &"shelf", "and on the button the hand moved to")


func test_buttons_light_up_under_a_ray() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var start: EntryButton = _target(&"entry_part_all").get_parent()
	var eye := App.head().global_position
	var at := start.global_position
	input.point(&"right", eye + (at - eye).normalized() * 0.25 + Vector3.DOWN * 0.05, at)
	await wait(0.6)
	expect(start.get("_hot"), "the button the ray is on is lit")
	input.point(&"right", eye + Vector3.UP * 0.1, eye + Vector3.UP * 0.1 + Vector3.BACK * 2.0)
	await wait(0.6)
	expect(not start.get("_hot"), "and not once the ray leaves")


func test_on_desktop_only_a_click_presses_not_moving_over_a_button() -> void:
	await _boot_entry()
	entry.touch_cauldron_in_sim = false
	await _to_setup_panel()
	var pressed := record(entry._part_pressed)
	var start: EntryButton = _target(&"entry_part_all").get_parent()
	await wait(1.0)
	await _poke_at(start, Vector3(0.0, 0.0, 0.15))
	await _poke_at(start, Vector3(0.0, 0.0, -0.01))
	await wait(0.3)
	expect_eq(pressed.size(), 0, "a fingertip going through the button does not press it on desktop")
	await select(start.global_position)
	await frames(2)
	expect_eq(pressed.size(), 1, "but a click does")


func _key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	Input.parse_input_event(event)
	Input.flush_buffered_events()   # a real window does this every frame; the headless loop doesn't


func test_on_desktop_the_head_moves_with_the_keys() -> void:
	await _boot_entry()
	var head := App.rig.head
	var start := head.global_position
	var ahead := Vector3.FORWARD.rotated(Vector3.UP, head.global_rotation.y)
	_key(KEY_W, true)
	await frames(60)
	_key(KEY_W, false)
	var moved := head.global_position - start
	expect(moved.length() > 0.3 and moved.length() < 0.7, "W moves the head about half a metre in a second, got %s" % moved.length())
	expect(moved.normalized().dot(ahead) > 0.95, "and forward")
	var there := head.global_position
	await frames(10)
	expect(head.global_position.distance_to(there) < 0.001, "it stops when the key is let go")
	_key(KEY_E, true)
	await frames(30)
	_key(KEY_E, false)
	expect(head.global_position.y > there.y + 0.1, "E raises it")
	_key(KEY_R, true)
	await frames(3)
	_key(KEY_R, false)
	expect(head.global_position.distance_to(start) < 0.01, "R puts it back")


func test_on_desktop_the_arrow_keys_look_around() -> void:
	await _boot_entry()
	var head := App.rig.head
	_key(KEY_LEFT, true)
	await frames(30)
	_key(KEY_LEFT, false)
	expect(head.rotation.y > 0.3, "the left arrow turns the head left, got %s" % head.rotation.y)
	var turned := head.rotation.y
	await frames(10)
	expect(is_equal_approx(head.rotation.y, turned), "and it stops when the key is let go")
	_key(KEY_UP, true)
	await frames(30)
	_key(KEY_UP, false)
	expect(head.rotation.x > 0.3, "the up arrow tilts it up, got %s" % head.rotation.x)
	var before := head.global_position
	_key(KEY_W, true)
	await frames(30)
	_key(KEY_W, false)
	var ahead := Vector3.FORWARD.rotated(Vector3.UP, head.rotation.y)
	var went := head.global_position - before
	expect(went.length() > 0.1 and went.normalized().dot(ahead) > 0.95, "W then goes the way the head now faces")
	_key(KEY_R, true)
	await frames(3)
	_key(KEY_R, false)
	expect(absf(head.rotation.y) < 0.001 and absf(head.rotation.x) < 0.001, "R turns it back")


func test_the_setup_checks_are_honest_and_next_waits_for_them() -> void:
	await _boot_entry()
	await until(func() -> bool: return _target(&"entry_step_next") != null, 20.0)
	var panel: SetupPanel = entry.get("_panel")
	expect_eq(panel.step, 1, "setup starts at step 1")
	await frames(3)
	expect_eq(panel.check_state(0), &"good", "the left hand is seen")
	expect_eq(panel.check_state(1), &"good", "the right hand is seen")
	expect_eq(panel.check_state(2), &"wait", "no pinch yet")
	input.track(&"left", false)
	await frames(3)
	expect_eq(panel.check_state(0), &"wait", "a lost hand un-ticks")
	input.track(&"left", true)
	await frames(3)
	expect_eq(panel.check_state(0), &"good", "and ticks again when it is back")
	entry._on_target(_target(&"entry_step_next"))   # Next, without a pinch
	await wait(0.5)
	expect_eq(panel.step, 1, "Next waits until the pinch has worked")
	input.click(&"right", &"trigger_click")
	await frames(3)
	expect_eq(panel.check_state(2), &"good", "the pinch ticks")
	await wait(0.7)
	entry._on_target(_target(&"entry_step_next"))
	expect(await until(func() -> bool: return panel.step == 2, 5.0), "and now Next moves on to the table")


func test_the_table_step_reports_the_table() -> void:
	await _boot_entry()
	await until(func() -> bool: return _target(&"entry_step_next") != null, 20.0)
	var panel: SetupPanel = entry.get("_panel")
	input.click(&"right", &"trigger_click")
	await wait(0.7)
	await _press(&"entry_step_next")
	expect(await until(func() -> bool: return _target(&"entry_confirm_yes") != null, 10.0), "the table question shows")
	expect_eq(panel.check_state(0), &"good", "found by the headset")
	expect_eq(panel.check_state(1), &"good", "a comfortable height")
	expect_eq(panel.check_state(2), &"good", "big enough")


func test_the_reach_step_brings_the_cauldron_in_to_the_childs_reach() -> void:
	await _boot_entry()
	await until(func() -> bool: return _target(&"entry_step_next") != null, 20.0)
	input.click(&"right", &"trigger_click")
	await wait(0.7)
	await _press(&"entry_step_next")
	await _press(&"entry_confirm_yes")
	expect(await until(func() -> bool: return _target(&"entry_step_alt") != null, 10.0), "step 3 shows")
	# A hand slid out along the table, 62 cm from the eyes.
	var eye := App.head().global_position
	var table_y := App.reality.work_surface().transform.origin.y
	var tip := Vector3(eye.x, table_y + 0.02, eye.z - 0.62)
	input.point(&"right", tip + Vector3(0, 0, 0.05), tip)
	await wait(0.4)
	await _press(&"entry_step_next")   # Done
	await wait(0.2)
	expect(absf(float(entry.get("_cauldron_distance")) - 0.465) < 0.02, "the cauldron goes three quarters of the reach out, got %s" % entry.get("_cauldron_distance"))
	expect(absf(float(entry.get("shelf_push")) - (0.62 * 0.9 - Entry.SHELF_BACK)) < 0.02, "the shelf stands back so its farthest cubby is at nine tenths of the reach, got %s" % entry.get("shelf_push"))


func test_without_a_measured_reach_the_cauldron_keeps_its_usual_spot() -> void:
	await _boot_entry()
	await _to_setup_panel()
	expect_eq(entry.get("_cauldron_distance"), Entry.CAULDRON_DISTANCE, "the usual 50 cm")
	expect_eq(entry.get("shelf_push"), Entry.SHELF_PUSH, "and the shelf its usual 22 cm back")


func test_a_jump_button_during_setup_skips_the_rest() -> void:
	await _boot_entry()
	var said := record(Events.said)
	await jump_to_intro_part(&"reveal")
	expect(await _until_said(said, Entry.REVEAL_LINE, 60.0), "the ripple plays straight from step 1")
	expect(not _said_line(said, "Oh! Hello there."), "and nothing before it")


func test_the_workshop_survives_the_handoff_and_leaves_with_the_next_scene() -> void:
	await _boot_entry()
	await _to_setup_panel()
	await jump_to_intro_part(&"shelf")
	expect(await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 30.0), "the shelf scene loads")
	await wait(1.5)
	var workshop := App.main.get_node_or_null(^"Workshop") as Workshop
	expect(workshop != null, "the workshop is still there")
	if workshop == null:
		return
	expect(workshop.find_children("*", "OmniLight3D", true, false).size() == 1, "with Onion (and its light)")
	expect(workshop.find_children("*", "Target", true, false).filter(func(n: Target) -> bool: return n.collision_layer & Pointer.TARGET_LAYER != 0).is_empty(), "the workshop has no gameplay touch targets")
	expect(App.world == null, "no World welcome or menu in the first visit")
	await App.main.change_scene(&"global_motion")
	await wait(0.5)
	expect(not is_instance_valid(workshop), "the workshop goes when the child leaves that scene")


func test_the_shelf_stands_back_along_the_table_not_in_front_of_the_player() -> void:
	await _boot_entry()
	await until(func() -> bool: return _target(&"entry_step_next") != null, 20.0)
	await _to_setup_panel()
	var eye := App.head().global_position
	var bench: Transform3D = entry.get("_bench")
	expect_eq(Tidy.shelf_frame, bench, "the opening hands the first visit its planned shelf position")
	var away := Vector2(bench.origin.x - eye.x, bench.origin.z - eye.z).length()
	# At least that far back (it may stand further where the plan turns it to fit the table: Scene 6's layout).
	expect(away > Entry.SHELF_PUSH - 0.01, "the whole play set stands back along the table from the eyes, got %s" % away)
	var cauldron: Node3D = entry.get("_box")
	var shelf_frame: Transform3D = bench
	var local := shelf_frame.affine_inverse() * cauldron.global_position
	# The cauldron stays for the whole visit (Scene 6): the plan keeps it out of the shelf's footprint.
	expect(absf(local.x) > (0.48 + 0.06) * 0.5 or -local.z > 0.41 + 0.11 or local.z > 0.0,
			"the cauldron does not stand inside the shelf's footprint")


func test_a_jump_button_cuts_in_on_a_part_that_is_still_playing() -> void:
	await _boot_entry()
	var said := record(Events.said)
	await _to_setup_panel()
	await jump_to_intro_part(&"touch")   # waits for a tap that never comes
	await wait(1.0)
	expect((entry.get("_orb") as Onion).cue, "the touch part is waiting for the tap")
	await jump_to_intro_part(&"reveal")   # cuts in
	expect(await _until_said(said, Entry.REVEAL_LINE, 30.0), "the ripple plays at once")
	expect(not (entry.get("_orb") as Onion).cue, "and the touch part is gone")
	expect(not _said_line(said, "Oh! Hello there."), "without the earlier parts")
	# Cut in again, and straight into the shelf.
	await jump_to_intro_part(&"touch")
	await wait(0.5)
	await jump_to_intro_part(&"shelf")
	expect(await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 30.0), "a jump to the shelf works mid-part too")


func test_dots_button_goes_to_the_dots_in_the_workshop() -> void:
	await _boot_entry()
	await _to_setup_panel()
	await jump_to_intro_part(&"dots")
	expect(await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 30.0), "the Dots button opens the workshop, not Wei's dots scene")
	var hub := app.find_child("WorkshopController", true, false) as WorkshopController
	expect(await until(func() -> bool: return hub.current != null and hub.current.id() == &"dots", 30.0), "and the dots start")
	var workshop := App.main.get_node_or_null(^"Workshop") as Workshop
	expect(workshop != null and is_instance_valid(workshop.onion), "Onion and the cauldron came along")


## Megan, Nov 18: a jump to one part plays it and then the rest of the opening, into the hub.
func test_a_part_jump_plays_on_into_the_hub() -> void:
	await _boot_entry()
	await _to_setup_panel()
	await jump_to_intro_part(&"reveal")
	expect(await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 60.0), "after the reveal, the hub")


## Megan, Nov 18: a jump back from the reveal does not leave its lanterns lit.
func test_a_jump_back_from_the_reveal_puts_the_lanterns_out() -> void:
	await _boot_entry()
	await _to_setup_panel()
	await jump_to_intro_part(&"reveal")
	expect(await until(func() -> bool: return not Lantern.from_reveal.is_empty(), 10.0), "the reveal lights the lanterns")
	await jump_to_intro_part(&"hello")
	await frames(2)
	expect(Lantern.from_reveal.is_empty(), "the hello has none")
	expect(App.main.get_node_or_null(^"Rafters") == null or App.main.get_node(^"Rafters").is_queued_for_deletion(), "nor the beams")


## Megan, Nov 18: a game jump builds the whole menu; the game's bubble is open.
func test_a_game_jump_keeps_every_bubble() -> void:
	await _boot_entry()
	await _to_setup_panel()
	await jump_to_intro_part(&"shelf")
	expect(await until(func() -> bool:
		var found := app.find_child("WorkshopController", true, false) as WorkshopController
		return found != null and found.state == &"game", 30.0), "the shelf starts")
	var hub := app.find_child("WorkshopController", true, false) as WorkshopController
	var kinds := hub.ring.impressions.map(func(i: Impression) -> StringName: return i.kind)
	expect_eq(kinds, [&"shelf", &"dots", &"butterflies", &"turn_to_fit"], "every game's bubble")


## Megan, Nov 18: Restart in the hub rebuilds the room: a fresh hub with the cauldron, Onion and the gear.
func test_restart_in_the_hub_keeps_the_workshop() -> void:
	await _boot_entry()
	await _to_setup_panel()
	Entry.go_to(&"hub")
	expect(await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 60.0), "the hub")
	await until(func() -> bool: return App.main.get_node_or_null(^"Workshop") != null, 10.0)
	await open_intro_tools()
	await press_facilitator("fac_restart")
	await frames(2)
	await press_facilitator("fac_confirm_tool")
	expect(await until(func() -> bool:
		var hub := app.find_child("WorkshopController", true, false) as WorkshopController
		return App.main.current_scene == &"first_visit" and hub != null and hub.state == &"hub" \
				and App.main.get_node_or_null(^"Workshop") != null, 60.0), "a fresh hub, through the opening's room")
	var workshop := App.main.get_node(^"Workshop") as Workshop
	expect(is_instance_valid(workshop.onion) and workshop.onion.is_visible_in_tree(), "Onion is there")
	expect(is_instance_valid(workshop.get(&"_cauldron")), "and the cauldron")


## Megan, Nov 18: Scenes holds the workshop's places; each goes through the opening's room.
func test_scenes_go_to_the_workshops_places() -> void:
	await _boot_entry()
	await _to_setup_panel()
	input.menu()
	await frames(2)
	await press_facilitator("fac_scenes")
	await frames(2)
	for place: StringName in Entry.PLACES:
		expect(App.module(&"Facilitator").find_child("fac_scene_" + String(place), true, false) != null, "a button for " + place)
	expect(App.module(&"Facilitator").find_child("fac_scene_global_motion", true, false) == null, "not Wei's scenes")
	await press_facilitator("fac_scene_butterflies")
	expect(await until(func() -> bool:
		var hub := app.find_child("WorkshopController", true, false) as WorkshopController
		return hub != null and hub.current != null and hub.current.id() == &"butterflies", 60.0), "Butterflies starts in the workshop")


func test_the_first_visit_ends_with_onions_closing_and_nothing_of_weis() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var said := record(Events.said)
	await jump_to_intro_part(&"shelf")
	expect(await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 30.0), "the first visit loads")
	expect(await until(func() -> bool: return Tidy.onion_voice, 10.0), "Wei's own spoken lines are switched off while Onion leads")
	var reports := record(Events.reported)
	for round_index in 2:
		expect(await until(func() -> bool:
			var trial := App.session.trial
			return trial != null and trial.is_running() and trial.condition.round_index == round_index), "the tutorial round starts")
		App.session.trial.finish(true)
	expect(await until(func() -> bool:
		return reports.any(func(args: Array) -> bool: return args[0] == &"first_visit_done"), 30.0), "the visit closes")
	var task := FirstVisit.SHELF_TASK as Task
	var level := task.level_by_id(FirstVisit.TUTORIAL_LEVEL)
	expect(App.main.progress.is_done(task, level), "the shelf menu remembers the tutorial completion")
	expect_eq(App.main.progress.reward(task, level), 2, "the shelf menu now offers the repeat reward")
	expect_eq(App.module(&"Inventory").count(&"magic_stone"), 3, "the tutorial grants the first reward")
	expect(await _until_said(said, "There. Everything's found its place.", 10.0), "Onion closes the level")
	expect(not _said_line(said, "Thank you for helping."), "\"Thank you for helping.\" is cut (Scene 8)")
	expect(not _said_line(said, "Well done, alchemist!"), "no second 'well done' from the World")
	expect(not _said_line(said, "You earned 3 magic stones!"), "Onion owns the tutorial closing")
	expect(not Tidy.onion_voice, "Wei's lines are back for his own route afterwards")
	var next_level := task.level_by_id(&"size")   # Find Objects' order (Megan, Nov 18): Shadow → Size → Clutter → Color → Similar
	if not await _choose_game(&"shelf"):   # back at the hub: the shelf again plays the next level
		expect(false, "the child can choose the shelf again in the hub")
		return
	for block: Block in next_level.plan.blocks:
		for round_index in block.rounds:
			if not await until(func() -> bool:
				var trial := App.session.trial
				return App.session.block == block and trial != null and trial.is_running() and trial.condition.round_index == round_index):
				expect(false, "the next shelf level starts round %d" % round_index)
				return
			App.session.trial.finish(true)
	expect(await until(func() -> bool: return App.main.progress.is_done(task, next_level)), "the shelf again saves the completed level")
	expect_eq(App.module(&"Inventory").count(&"magic_stone"), 3 + next_level.first_reward, "the shelf again grants the first reward")


func test_a_pick_up_ends_onions_shelf_lines() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var said := record(Events.said)
	await jump_to_intro_part(&"shelf")
	expect(await until(func() -> bool:
		var trial := App.session.trial
		return trial != null and trial.is_running(), 60.0), "the shelf round runs (the jump goes straight to the shelf)")
	var workshop := App.main.get_node_or_null(^"Workshop") as Workshop
	expect(workshop != null and workshop.cauldron() != null and workshop.cauldron().is_visible_in_tree(), "the Shelf jump keeps the cauldron (the hub's menu; Megan, Nov 18)")
	Events.report(&"taken", {})   # the child picks a shape up at once
	await wait(12.0)
	expect(not _said_line(said, "Pick whichever one you'd like to start with."), "a pick-up ends Onion's lines")
	expect(not _said_line(said, "Welcome to the workshop."), "a jump has no welcome (the hub's first visit has it)")


func test_a_shelf_finished_while_onion_still_talks_goes_straight_to_the_closing() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var said := record(Events.said)
	await jump_to_intro_part(&"shelf")
	for round_index in 2:   # the child sorts both rounds before Onion has finished inviting
		expect(await until(func() -> bool:
			var trial := App.session.trial
			return trial != null and trial.is_running() and trial.condition.round_index == round_index), "round %d runs" % round_index)
		App.session.trial.finish(true)
	expect(await _until_said(said, "There. Everything's found its place.", 15.0), "the closing comes at once")
	expect(not _said_line(said, "Pick whichever one you'd like to start with."), "the rest of the invitation is not said")


func test_skip_stays_visible_across_modes_and_setup_steps() -> void:
	expect(PlayMode.is_dev(), "the tests run in dev")
	var reports := record(Events.reported)
	await _boot_entry()
	expect(reports.any(func(args: Array) -> bool: return args[0] == &"session_mode" and args[1].mode == "dev"),
		"the session logs its mode")
	expect(await until(func() -> bool: return _target(&"entry_step_next") != null, 20.0), "setup runs (step 1)")
	expect(_target(&"entry_mode") != null, "the setup panel has the Mode toggle")
	var skip := _target(&"entry_skip_setup")
	expect(skip.is_visible_in_tree(), "dev: Skip is visible")
	await _press(&"entry_mode")
	expect(not PlayMode.is_dev(), "the toggle switches to play")
	expect(reports.any(func(args: Array) -> bool: return args[0] == &"session_mode" and args[1].mode == "play"),
		"the switch is logged")
	expect_eq(_target(&"entry_skip_setup"), skip, "play: the same Skip button")
	expect(skip.is_visible_in_tree(), "play: Skip is visible")
	var marker := App.head().get_node_or_null(NodePath(SceneMarker.NAME)) as Label3D
	expect(marker == null or not marker.visible, "play: no scene marker")
	await _press(&"entry_mode")
	expect(PlayMode.is_dev(), "and back to dev")
	marker = App.head().get_node_or_null(NodePath(SceneMarker.NAME)) as Label3D
	expect(marker != null and marker.visible, "dev: the scene marker is back")
	await _to_setup_panel()
	expect_eq(_target(&"entry_skip_setup"), skip, "Skip stays in place through all the setup steps")
	var said := record(Events.said)
	var table := App.reality.work_surface()
	await select(skip.global_position)
	expect(await _until_said(said, "Oh! Hello there."), "Skip starts the opening in one pinch")
	expect_eq(App.reality.work_surface(), table, "the opening uses the table already found")
	expect(not skip.is_visible_in_tree() and skip.collision_layer == 0, "the hidden shortcut cannot receive a pinch")


func test_skip_starts_in_play_mode_even_when_the_table_search_has_no_result() -> void:
	await boot(null, &"intro")
	for table in App.reality.surfaces(&"table"):
		App.reality._surfaces.erase(table)
	App.reality.is_settled = false
	PlayMode.set_dev(false, "tests")
	entry = app.get_node(^"Intro/Entry")
	entry.skip_setup = false
	var said := record(Events.said)
	entry.run()
	var skip := _target(&"entry_skip_setup")
	expect(skip.is_visible_in_tree(), "Skip is available while Reality searches")
	input.click(&"right", &"trigger_click")
	await _press(&"entry_step_next")
	var panel: SetupPanel = entry.get("_panel")
	expect_eq(panel.step, 2, "manual setup waits on the table step")
	expect(not App.reality.is_settled and _target(&"entry_confirm_yes") == null, "the scan is still pending")
	await select(skip.global_position)
	expect(await _until_said(said, "Oh! Hello there."), "one pinch keeps going with the available data")
	var layout: EntryLayout = entry.get("_layout")
	expect(not layout.real_table and App.reality.surfaces(&"table").is_empty(), "the virtual surface is not a measured table")
	expect(App.reality.is_settled, "the opening can use the fallback without waiting for the scan")
	expect(is_equal_approx(layout.reach_used(), EntryLayout.REACH_USUAL), "the usual reach is used")


func test_under_the_test_runner_the_mode_is_dev_and_setup_is_skipped_by_default() -> void:
	PlayMode.reset_for_tests()
	expect(PlayMode.testing_now(), "the runner's --profile=test is seen")
	expect(PlayMode.is_dev(), "tests are always dev")
	expect_eq(PlayMode.source(), "tests", "whatever was saved on the device")
	await boot(null, &"intro")
	expect((app.get_node(^"Intro/Entry") as Entry).skip_setup, "tests skip setup unless they turn it on (the test hook)")


func test_a_shape_can_be_taken_while_onion_invites() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var said := record(Events.said)
	var reports := record(Events.reported)
	await jump_to_intro_part(&"shelf")
	expect(await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running(), 60.0), "the shelf round runs")
	await wait(1.0)
	var trial := App.session.trial
	var thing: Target = (trial.get("_things") as Array)[0]
	var at := thing.global_position
	var along := (at - (App.head().global_position + Vector3.DOWN * 0.2)).normalized()
	input.point(&"right", at - along * App.rig.pointer(&"right").tip_reach, at)
	await frames(3)
	input.press(&"right", &"trigger_click", true)
	await frames(3)
	expect(reports.any(func(a: Array) -> bool: return a[0] == &"taken"), "a hand takes a shape while Onion talks")
	input.press(&"right", &"trigger_click", false)


## On a laptop the mouse hand sits 45 cm out and the shapes are further: a click on one reaches it (Nov 10).
func test_on_desktop_a_click_on_a_shape_takes_it() -> void:
	get_window().size = Vector2i(1280, 800)   # headless windows start tiny
	Input.use_accumulated_input = false
	await _boot_entry()
	await _to_setup_panel()
	var said := record(Events.said)
	var reports := record(Events.reported)
	await jump_to_intro_part(&"shelf")
	expect(await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running(), 60.0), "the shelf round runs")
	await wait(1.0)
	var trial := App.session.trial
	var thing: Target = (trial.get("_things") as Array)[0]
	await frames(2)
	var cursor := App.head().unproject_position(thing.global_position)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = cursor
	event.global_position = cursor
	Input.parse_input_event(event)
	await frames(3)
	expect(App.head().global_position.distance_to(thing.global_position) > 0.5, "the shape is beyond the usual 45 cm (%.2f m)" % App.head().global_position.distance_to(thing.global_position))
	expect(reports.any(func(a: Array) -> bool: return a[0] == &"taken"), "a mouse click on the shape takes it")
	var up := event.duplicate() as InputEventMouseButton
	up.pressed = false
	Input.parse_input_event(up)
	await frames(2)


func test_play_mode_frees_the_hand_outline_after_the_hands_check() -> void:
	await _boot_entry()
	await _press(&"entry_mode")
	expect(not PlayMode.is_dev(), "the hands check is in Play mode")
	# XR normally creates these nodes on the first tracked frame.
	var outline := entry._new_hand()
	entry._hand_lines[&"right"] = outline
	await frames(2)
	expect(is_instance_valid(outline[0]) and is_instance_valid(outline[2]), "the outline stays during the hands check")
	Events.button.emit(&"right", &"trigger_click", true)
	await _press(&"entry_step_next")
	expect(_target(&"entry_confirm_yes") != null, "the table check follows the hands check")
	expect(entry._hand_lines.is_empty(), "the hand check releases its references")
	expect(not is_instance_valid(outline[0]) and not is_instance_valid(outline[2]), "the lines and dots are freed")


## The opening's shelf distance and Onion's voice are static: other suites must not inherit them.
func shutdown() -> void:
	PlayMode.set_dev(true, "tests")
	await super.shutdown()
	Tidy.onion_voice = false
	Motion.onion_voice = false
	Engine.time_scale = 1.0


func test_the_story_sounds_play_at_their_moments() -> void:
	await _boot_entry()
	var said := record(Events.said)
	await _to_setup_panel()
	var sounds := entry.get("_sounds") as Sounds
	await _press(&"entry_part_all")
	expect(await _until_said(said, "Could you help me with something?", 60.0), "the opening plays")
	expect(sounds.played.has(&"pre_rattle"), "the soft rattle plays before Onion appears")
	expect(sounds.played.has(&"pop"), "and Onion's pop")
	await _touch_cauldron()
	expect(await until(func() -> bool: return sounds.played.has(&"device_rattle"), 30.0), "the heavier rattle precedes the device")
	expect(not sounds.played.has(&"seat"), "no seating click before the gear is set in")
	expect(await until(func() -> bool: return sounds.played.has(&"seat"), 60.0), "one click when it is seated")
	expect(await until(func() -> bool: return sounds.played.has(&"reveal"), 60.0), "the reveal pad with the ripple")
	expect_eq(sounds.played.count(&"seat"), 1, "the click plays once")


func test_the_cauldron_stays_during_the_first_shelf_level() -> void:
	await _boot_entry()
	await _to_setup_panel()
	await jump_to_intro_part(&"shelf")
	expect(await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 30.0), "the first visit loads")
	await wait(1.0)
	var workshop := App.main.get_node(^"Workshop") as Workshop
	var cauldron := workshop.get("_cauldron") as Node3D
	expect(cauldron != null and cauldron.visible, "the cauldron stays for the whole visit (Nov 17)")
	expect(workshop.find_children("*", "OmniLight3D", true, false).size() == 1, "Onion is still there")


func test_the_first_visit_does_not_claim_success_after_a_time_out() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var said := record(Events.said)
	await jump_to_intro_part(&"shelf")
	expect(await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 30.0), "the first visit loads")
	var visit := App.main.get_node(^"FirstVisit/Visit") as FirstVisit
	visit.set("_rounds_ended", 2)
	visit.set("_rounds_won", 1)   # one round timed out
	Engine.time_scale = 4.0
	await visit._closing()
	Engine.time_scale = 1.0
	expect(not _said_line(said, "There. Everything's found its place."), "no claim that everything is in place")
	expect(_said_line(said, "We can come back to these."), "the not-all-won line (Scene 8)")


func test_the_motion_route_starts_play_and_replays_the_tutorial_on_request() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var said := record(Events.said)
	await jump_to_intro_part(&"motion")   # Wei moved the jumps into the facilitator Tools (Nov 9)
	expect(await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 30.0), "the motion route loads")
	expect(await until(func() -> bool: return App.session.trial != null, 5.0), "the motion round starts straight away")
	expect(Motion.onion_voice, "with Wei's own lines switched off")
	await wait(1.0)
	expect(not _said_line(said, "Which way do the dots go? Sweep your hand that way, then hold still."), "his round line is not said")
	var task := preload("res://content/tasks/break_wall.tres")
	var plan := task.level_by_id(&"steady_flow").plan
	expect_eq(App.session.plan, plan, "Onion plays the same Steady Flow level as the menu")
	expect(not _said_line(said, plan.blocks[0].intro), "the tutorial waits for a press")
	var trial := App.session.trial
	var replay := trial.find_child("replay_tutorial", true, false) as UITarget
	expect(replay != null, "there is a replay tutorial button")
	if replay:
		var ended := record(Events.trial_ended)
		await select(replay.global_position)
		expect(_said_line(said, plan.blocks[0].intro), "pinching the replay button plays the lesson")
		expect(not trial.find_children("*", "MotionTutorial", true, false).is_empty(), "a demonstration runs on demand")
		var elapsed := trial.seconds()
		await wait(0.5)
		expect_eq(trial.seconds(), elapsed, "watching the example does not spend round time")
		expect(ended.is_empty(), "the example does not answer the round")
		expect(await until(func() -> bool: return trial.seconds() > elapsed, 10.0), "the same round resumes")


func test_the_closing_and_the_first_success_line_once() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var said := record(Events.said)
	await jump_to_intro_part(&"motion")   # Wei moved the jumps into the facilitator Tools (Nov 9)
	expect(await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 30.0), "the motion route loads")
	var visit := App.main.get_node(^"FirstVisit/Visit/Motion") as MotionVisit
	Engine.time_scale = 4.0
	expect(await until(func() -> bool: return visit.get("_in_motion"), 60.0), "the motion rounds start")
	Events.trial_ended.emit(&"motion", true, {})
	Events.trial_ended.emit(&"motion", true, {})
	await wait(3.0)
	expect(not _said_line(said, "There! You did that."), "Onion stays quiet during the measured rounds (story chat, Nov 18)")
	while App.session.running:
		if App.session.trial != null and App.session.trial.is_running():
			App.session.trial.finish(true)
		await frames(2)
	expect(await _until_said(said, "There! You did that.", 40.0), "the dots fly away: \"There! You did that.\"")
	expect(said.filter(func(a: Array) -> bool: return a[0] == "There! You did that.").size() == 1, "once")
	await visit.closing()
	Engine.time_scale = 1.0
	expect(not _said_line(said, "Thank you for trying that with me."), "cut (Scene 10)")
	for line: String in ["It's been lovely having you here.", "I'll have everything ready for your next visit.", "Well. I'll do my best."]:
		expect(_said_line(said, line), "the closing says: " + line)
	expect(not _said_line(said, "The room has a few surprises left in it."), "not after the first success any more (it's Home's offer)")
	var workshop := App.main.get_node(^"Workshop") as Workshop
	expect(not (workshop.get("_gear") as Node3D).visible, "the gear went home into the cauldron")
	expect((workshop.get("_cauldron") as Node3D).visible, "the cauldron is still there (it never left)")
	expect(not workshop.onion.visible, "Onion ducked inside")
	expect(visit.find_child("visit_end_session", true, false) == null, "no End-session button in the room (Scene 10)")
	expect(App.results_after_closing, "Staff tools will open on Results")
	App.results_after_closing = false
	expect(not Motion.onion_voice, "Wei's lines are back afterwards")


func test_the_room_is_planned_when_start_is_pressed_from_where_the_child_sits() -> void:
	Engine.time_scale = 1.0
	await boot(null, &"intro")
	entry = app.get_node(^"Intro/Entry")
	entry.touch_cauldron_in_sim = true
	entry.simulate_child = true
	entry.run()
	await until(func() -> bool: return _target(&"entry_part_all") != null, 20.0)
	expect(entry.get("_layout") == null, "nothing is planned before Start (the headset may still be going on)")
	App.rig.head.rotation.y = 0.3   # the child sits a little turned
	await frames(2)
	await _press(&"entry_part_all")
	expect(await until(func() -> bool: return entry.get("_layout") != null, 20.0), "Start plans the room")
	var planned: Transform3D = entry.get("_plan_head")
	expect(absf(planned.basis.get_euler().y - 0.3) < 0.05, "from the head as it is when Start is pressed")
	expect(Tidy.shelf_frame != Transform3D.IDENTITY, "and Wei's shelf will stand where the plan put the bench")
