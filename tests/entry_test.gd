extends TestCase
## Megan's opening (Entry in main.tscn, direction of Oct 30): it plays before the
## World unless a session plan is given. Setup for the adult (table check, then
## Start or a part to jump to), then Onion's hello, the cauldron touch, the things
## coming out, the ripple, and Wei's shelf with Onion as the guide.

const TIDY := preload("res://trials/tidy/tidy.tres")
const Tidy := preload("res://trials/tidy/tidy_trial.gd")
const Motion := preload("res://trials/motion/motion_trial.gd")
const ADVENTURE := preload("res://content/adventure.tres")

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
	expect((entry.get("_music") as AudioStreamPlayer).playing, "the piano is already playing (it starts with the scene)")


func test_start_plays_everything_into_the_world() -> void:
	await _boot_entry()
	var said := record(Events.said)
	await _to_setup_panel()
	expect(await _press(&"entry_part_all"), "Start is pressed")
	expect(await _until_said(said, "Oh! Hello there."), "Onion says hello")
	expect(await _until_said(said, "I'm Onion, by the way."), "and its name")
	await _touch_cauldron()
	expect(await until(func() -> bool: return (entry.get("_gear") as Node3D).visible, 30.0), "the gear comes out of the cauldron")
	expect(await _until_said(said, "Welcome to the workshop.", 60.0), "the ripple, then welcome")
	expect_eq(App.main.current_scene, &"first_visit", "welcomed with the shelf already playable")
	expect(await _until_said(said, "Pick whichever one you'd like to start with.", 60.0), "the things drop in, then Onion notices them")
	expect(await _until_said(said, "The shapes on the shelf show where things go.", 60.0), "Onion leads the first shelf level")
	expect_eq(App.main.current_scene, &"first_visit", "in its own scene")
	expect(not _said_line(said, ADVENTURE.greeting), "without Wei's welcome stacked on top")


func test_jumping_to_each_part_plays_only_that_part() -> void:
	await _boot_entry()
	var said := record(Events.said)
	await _to_setup_panel()
	var orb: Node3D = entry.get("_orb")

	# Ripple first: the things are already on the table, Onion aside, workshop hidden.
	await jump_to_intro_part(&"reveal")
	await frames(2)
	# (where the table is narrow the socket rides its drawn track at the start of the reveal; wait it out)
	expect(await until(func() -> bool: return _docked(), 20.0), "ripple: the gear is already in its socket")
	expect(orb.global_position.distance_to(entry.call("_lifted_spot")) < 0.15, "ripple: Onion is already up beside the socket (the lifted spot)")
	expect(await until(func() -> bool: return _shown(entry.get("_details")) > 0, 60.0), "ripple: plays")
	expect(not _said_line(said, "Oh! Hello there."), "ripple: no hello")
	expect(await until(func() -> bool: return _target(&"entry_part_all") != null, 30.0), "ripple: the panel comes back")
	var details := _shown(entry.get("_details"))
	expect(details > 0, "ripple: the workshop was revealed")

	# Hello: the workshop goes, the things go, Onion back inside.
	await jump_to_intro_part(&"hello")
	await frames(2)
	expect_eq(_shown(entry.get("_details")), 0, "hello: the workshop is hidden again")
	expect(not (entry.get("_gear") as Node3D).visible, "hello: the gear is still hidden")
	expect(await _until_said(said, "I'm Onion, by the way."), "hello: plays")
	expect(await until(func() -> bool: return _target(&"entry_part_all") != null, 30.0), "hello: the panel comes back")

	# Touch: waits for the touch, then back to the panel (nothing comes out).
	await jump_to_intro_part(&"touch")
	await _touch_cauldron()
	expect(await until(func() -> bool: return _target(&"entry_part_all") != null, 30.0), "touch: the panel comes back after the touch")
	expect(not (entry.get("_gear") as Node3D).visible, "touch: nothing comes out")

	# Emerge: Onion moves aside, the gear comes out and (for now) sets itself in, then back to the panel.
	await jump_to_intro_part(&"emerge")
	expect(await until(func() -> bool: return _target(&"entry_part_all") != null, 30.0), "emerge: the panel comes back")
	expect((entry.get("_gear") as Node3D).visible and not _docked(), "emerge: the gear is out on the table, waiting to be picked up")

	# Pick up, then set in: the stand-in child does each, and the gear ends turning in its socket.
	await jump_to_intro_part(&"pickup")   # Wei moved the jumps into the facilitator Tools (Nov 9)
	expect(await until(func() -> bool: return entry.get("_part_running") == false, 30.0), "pickup: the beat ends once the gear is held")
	expect(await until(func() -> bool: return _target(&"entry_part_all") != null, 30.0), "pickup: the panel comes back")
	await jump_to_intro_part(&"place")
	expect(await until(func() -> bool: return (entry.get("_sounds") as Sounds).played.has(&"seat"), 30.0), "place: the gear is seated (one click)")
	expect(await until(func() -> bool: return _target(&"entry_part_all") != null, 30.0), "place: the panel comes back")
	expect(_docked(), "place: the gear is in its socket, turning")

	# Still one of each.
	expect_eq(entry.find_children("*", "Target", true, false).filter(func(t: Target) -> bool: return t.id == &"entry_cauldron").size(), 1, "one cauldron")

	# Shelf: straight into Wei's World.
	await jump_to_intro_part(&"shelf")
	expect(await _until_said(said, "The shapes on the shelf show where things go.", 60.0), "shelf: Onion leads the first level")
	expect_eq(App.main.current_scene, &"first_visit", "shelf: in its own scene")


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
	expect(await until(func() -> bool: return _shown(entry.get("_details")) > 0, 60.0), "the ripple plays straight from step 1")
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
	expect(workshop.find_children("*", "Target", true, false).filter(func(n: Target) -> bool: return n.collision_layer & Pointer.TARGET_LAYER != 0).is_empty(), "the cauldron cannot be touched any more; Onion only uses the reaction layer")
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
	expect(absf(away - Entry.SHELF_PUSH) < 0.01, "the whole play set is that far along the table from the eyes, got %s" % away)
	var cauldron: Node3D = entry.get("_box")
	var shelf_frame: Transform3D = bench
	var local := shelf_frame.affine_inverse() * cauldron.global_position
	# Where the panel stays put the cauldron may stand in the bench's way (EntryLayout.ripple_overlaps); it then sinks
	# as the ripple starts, before the bench grows in.
	var layout: EntryLayout = entry.get("_layout")
	expect(absf(local.x) > (0.48 + 0.06) * 0.5 or -local.z > 0.41 + 0.11 or local.z > 0.0 or not layout.ripple_overlaps().is_empty(),
			"the cauldron does not stand inside the shelf's footprint, or it sinks as the ripple starts")


func test_a_jump_button_cuts_in_on_a_part_that_is_still_playing() -> void:
	await _boot_entry()
	var said := record(Events.said)
	await _to_setup_panel()
	await jump_to_intro_part(&"touch")   # waits for a tap that never comes
	await wait(1.0)
	expect((entry.get("_orb") as Onion).cue, "the touch part is waiting for the tap")
	await jump_to_intro_part(&"reveal")   # cuts in
	expect(await until(func() -> bool: return _shown(entry.get("_details")) > 0, 30.0), "the ripple plays at once")
	expect(not (entry.get("_orb") as Onion).cue, "and the touch part is gone")
	expect(not _said_line(said, "Oh! Hello there."), "without the earlier parts")
	# Back at the panel, wait for a part again and cut straight into the shelf scene.
	expect(await until(func() -> bool: return _target(&"entry_part_all") != null, 30.0), "the panel comes back")
	await jump_to_intro_part(&"touch")
	await wait(0.5)
	await jump_to_intro_part(&"shelf")
	expect(await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 30.0), "a jump to the shelf works mid-part too")


func test_dots_button_goes_to_the_global_motion_task() -> void:
	await _boot_entry()
	await _to_setup_panel()
	await jump_to_intro_part(&"dots")
	expect(await until(func() -> bool: return App.main.current_scene == &"global_motion" and not App.main.switching, 30.0), "the Dots button opens the global motion scene")


func test_the_first_visit_ends_with_onions_closing_and_nothing_of_weis() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var said := record(Events.said)
	await jump_to_intro_part(&"shelf")
	expect(await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 30.0), "the first visit loads")
	expect(Tidy.onion_voice, "Wei's own spoken lines are switched off while Onion leads")
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
	expect(_said_line(said, "There. Everything's found its place."), "Onion closes the level")
	expect(_said_line(said, "Thank you for helping."), "and thanks the child")
	expect(not _said_line(said, "Well done, alchemist!"), "no second 'well done' from the World")
	expect(not Tidy.onion_voice, "Wei's lines are back for his own route afterwards")
	var more: UITarget
	if not await until(func() -> bool: return app.find_child("visit_more_shelf", true, false) != null, 20.0):
		expect(false, "the child can choose to play more shapes")
		return
	more = app.find_child("visit_more_shelf", true, false) as UITarget
	var next_level := task.levels[1]
	await select(more.global_position)
	for block: Block in next_level.plan.blocks:
		for round_index in block.rounds:
			if not await until(func() -> bool:
				var trial := App.session.trial
				return App.session.block == block and trial != null and trial.is_running() and trial.condition.round_index == round_index):
				expect(false, "the next shelf level starts round %d" % round_index)
				return
			App.session.trial.finish(true)
	expect(await until(func() -> bool: return App.main.progress.is_done(task, next_level)), "More shapes saves the completed level")
	expect_eq(App.module(&"Inventory").count(&"magic_stone"), 3 + next_level.first_reward, "More shapes grants the first reward")


func test_onion_invites_with_the_shelf_already_playable_and_a_pick_up_ends_the_talk() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var said := record(Events.said)
	await jump_to_intro_part(&"shelf")
	expect(await _until_said(said, "Oh! I'd nearly forgotten about these.", 60.0), "Onion notices the shapes in the shelf part")
	expect_eq(App.main.current_scene, &"first_visit", "the invitation plays in the shelf scene")
	var trial := App.session.trial
	expect(trial != null and trial.is_running(), "the shelf round is already running: shapes can be picked up while Onion talks")
	Events.report(&"taken", {})   # the child picks a shape up
	await wait(12.0)
	expect(not _said_line(said, "You could join me, if you like."), "a pick-up ends the invitation")
	expect(not _said_line(said, "The shapes on the shelf show where things go."), "and the rule (the child is already playing)")


func test_a_shelf_finished_while_onion_still_talks_goes_straight_to_the_closing() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var said := record(Events.said)
	await jump_to_intro_part(&"shelf")
	expect(await _until_said(said, "Welcome to the workshop.", 60.0), "Onion welcomes the child in the shelf scene")
	for round_index in 2:   # the child sorts both rounds before Onion has finished inviting
		expect(await until(func() -> bool:
			var trial := App.session.trial
			return trial != null and trial.is_running() and trial.condition.round_index == round_index), "round %d runs" % round_index)
		App.session.trial.finish(true)
	expect(await _until_said(said, "Thank you for helping.", 15.0), "the closing comes at once")
	expect(not _said_line(said, "You could join me, if you like."), "the rest of the invitation is not said")


func test_dev_mode_offers_skip_setup_and_the_mode_toggle_switches_to_play() -> void:
	expect(PlayMode.is_dev(), "the tests run in dev")
	var reports := record(Events.reported)
	await _boot_entry()
	expect(reports.any(func(args: Array) -> bool: return args[0] == &"session_mode" and args[1].mode == "dev"),
		"the session logs its mode")
	expect(await until(func() -> bool: return _target(&"entry_step_next") != null, 20.0), "setup runs (step 1)")
	expect(_target(&"entry_mode") != null, "the setup panel has the Mode toggle")
	expect(_target(&"entry_skip_setup") != null, "dev: and a Skip setup button")
	await _press(&"entry_skip_setup")
	expect(await until(func() -> bool: return _target(&"entry_part_all") != null, 20.0), "Skip setup goes straight to Start")
	await _press(&"entry_mode")
	expect(not PlayMode.is_dev(), "the toggle switches to play")
	expect(reports.any(func(args: Array) -> bool: return args[0] == &"session_mode" and args[1].mode == "play"),
		"the switch is logged")
	expect(await until(func() -> bool: return _target(&"entry_skip_setup") == null, 5.0), "play: no Skip setup")
	var marker := App.head().get_node_or_null(NodePath(SceneMarker.NAME)) as Label3D
	expect(marker == null or not marker.visible, "play: no scene marker")
	await _press(&"entry_mode")
	expect(PlayMode.is_dev(), "and back to dev")
	marker = App.head().get_node_or_null(NodePath(SceneMarker.NAME)) as Label3D
	expect(marker != null and marker.visible, "dev: the scene marker is back")


func test_under_the_test_runner_the_mode_is_dev_and_setup_is_skipped_by_default() -> void:
	PlayMode.reset_for_tests()
	expect(PlayMode.testing_now(), "the runner's --profile=test is seen")
	expect(PlayMode.is_dev(), "tests are always dev")
	expect_eq(PlayMode.source(), "tests", "whatever was saved on the device")
	await boot(null, &"intro")
	expect((app.get_node(^"Intro/Entry") as Entry).skip_setup, "tests skip setup unless they turn it on (the test hook)")


## The opening's shelf distance and Onion's voice are static: other suites must not inherit them.
func shutdown() -> void:
	await super.shutdown()
	PlayMode.set_dev(true, "tests")
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
	expect(sounds.played.has(&"pop_a"), "and Onion's pop (candidate A)")
	await _touch_cauldron()
	expect(await until(func() -> bool: return sounds.played.has(&"device_rattle"), 30.0), "the heavier rattle precedes the device")
	expect(not sounds.played.has(&"seat"), "no seating click before the gear is set in")
	expect(await until(func() -> bool: return sounds.played.has(&"seat"), 60.0), "one click when it is seated")
	expect(await until(func() -> bool: return sounds.played.has(&"reveal"), 60.0), "the reveal pad with the ripple")
	expect_eq(sounds.played.count(&"seat"), 1, "the click plays once")
	expect(sounds.toggle_pop() == "c", "the pop can be switched to candidate C")


func test_the_cauldron_is_hidden_during_the_first_shelf_level() -> void:
	await _boot_entry()
	await _to_setup_panel()
	await jump_to_intro_part(&"shelf")
	expect(await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 30.0), "the first visit loads")
	await wait(1.0)
	var workshop := App.main.get_node(^"Workshop") as Workshop
	var cauldron := workshop.get("_cauldron") as Node3D
	expect(cauldron != null and not cauldron.visible, "the cauldron is out of sight for the object test")
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
	expect(_said_line(said, "Thank you for helping."), "a neutral thank-you")


func test_the_motion_route_leads_wei_s_rounds_with_onion_s_lines_only() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var said := record(Events.said)
	await jump_to_intro_part(&"motion")   # Wei moved the jumps into the facilitator Tools (Nov 9)
	expect(await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 30.0), "the motion route loads")
	expect(await _until_said(said, "Watch what happens when they move together.", 30.0), "Onion introduces the demonstration")
	expect(await _until_said(said, "Your turn.", 30.0), "then the child's turn")
	expect(await until(func() -> bool: return App.session.trial != null, 30.0), "Wei's motion round runs")
	expect(Motion.onion_voice, "with Wei's own lines switched off")
	await wait(1.0)
	expect(not _said_line(said, "Which way do the dots go? Sweep your hand that way, then hold still."), "his round line is not said")
	var task := preload("res://content/tasks/break_wall.tres")
	var plan := task.level_by_id(&"steady_flow").plan
	expect_eq(App.session.plan, plan, "Onion plays the same Steady Flow level as the menu")
	expect(not _said_line(said, plan.blocks[0].intro), "Onion supplies the level introduction")


func test_the_motion_ending_thanks_the_child_whatever_the_outcome_and_the_first_success_is_marked_once() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var said := record(Events.said)
	await jump_to_intro_part(&"motion")   # Wei moved the jumps into the facilitator Tools (Nov 9)
	expect(await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 30.0), "the motion route loads")
	var visit := App.main.get_node(^"FirstVisit/Visit/Motion") as MotionVisit
	Engine.time_scale = 4.0
	expect(await until(func() -> bool: return visit.get("_in_motion"), 60.0), "the motion rounds start after the tutorial")
	Events.trial_ended.emit(&"motion", true, {})
	Events.trial_ended.emit(&"motion", true, {})
	expect(await _until_said(said, "There! You did that.", 40.0), "the first success gets its lines")
	await wait(3.0)
	expect(said.filter(func(a: Array) -> bool: return a[0] == "There! You did that.").size() == 1, "once")
	await visit._ending()
	Engine.time_scale = 1.0
	expect(_said_line(said, "Thank you for trying that with me."), "the approved ending")
	for line: String in ["It's been lovely having you here.", "I'll have everything ready for your next visit.", "Well. I'll do my best."]:
		expect(_said_line(said, line), "the closing says: " + line)
	var workshop := App.main.get_node(^"Workshop") as Workshop
	expect(not (workshop.get("_gear") as Node3D).visible, "the gear went home into the cauldron")
	expect((workshop.get("_cauldron") as Node3D).visible, "the cauldron is back for it")
	expect(not workshop.onion.visible, "Onion ducked inside")
	expect(visit.find_child("visit_end_session", true, false) != null, "the end-session control is shown")
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
