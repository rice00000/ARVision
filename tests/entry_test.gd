extends TestCase
## Megan's opening (Entry in main.tscn, direction of Oct 30): it plays before the
## World unless a session plan is given. Setup for the adult (table check, then
## Start or a part to jump to), then Onion's hello, the cauldron touch, the things
## coming out, the ripple, and Wei's shelf with Onion as the guide.

const TIDY := preload("res://trials/tidy/tidy.tres")
const ADVENTURE := preload("res://content/adventure.tres")

var entry: Entry


## Boots main.tscn and starts the opening, like a launch without a plan does.
func _boot_entry() -> void:
	Engine.time_scale = 1.0   # an earlier test may have left the opening's half speed on
	load("res://trials/tidy/tidy_trial.gd").push = 0.0   # the opening sets it; each test starts from the original
	await boot(null, &"intro")
	app.autostart = true   # when the opening ends and switches scene, the next scene starts itself
	entry = app.get_node(^"Intro/Entry")
	entry.poke_in_sim = true   # the tests move a fingertip; on desktop only clicks count
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
	await until(func() -> bool: return entry.get("_cue"), 30.0)
	var at := _target(&"entry_cauldron").global_position
	var eye := App.head().global_position
	var along := (at - (eye + Vector3.DOWN * 0.2)).normalized()
	input.point(&"right", at - along * App.rig.pointer(&"right").tip_reach, at)
	await frames(2)
	input.point(&"right", eye + Vector3(0.2, -0.25, -0.15), eye + Vector3(0.2, -0.4, -0.6))   # hand back
	await frames(2)


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
	expect(not _said_line(said, "Hello."), "no opening before a planned session")
	expect(app.find_child("Entry", true, false) == null, "and the opening is not loaded")


func test_setup_is_quiet_and_waits_for_start() -> void:
	await _boot_entry()
	var said := record(Events.said)
	await _to_setup_panel()
	for part: String in Entry.PARTS:
		expect(_target(StringName("entry_part_" + part)) != null, "a button to jump to " + part)
	var a := _target(&"entry_debug_restart").global_position
	var b := _target(&"entry_debug_exit").global_position
	expect(a.distance_to(b) > 0.14, "Restart and Exit are well apart")
	await wait(6.0)
	expect(said.is_empty(), "nothing is said before Start (no 'Got it' line either): %s" % [said])
	expect(not (entry.get("_music") as AudioStreamPlayer).playing, "and no music yet")


func test_start_plays_everything_into_the_world() -> void:
	await _boot_entry()
	var said := record(Events.said)
	await _to_setup_panel()
	expect(await _press(&"entry_part_all"), "Start is pressed")
	expect(await _until_said(said, "Hello."), "Onion says hello")
	expect(await _until_said(said, "I'm Onion, by the way."), "and its name")
	await _touch_cauldron()
	expect(await until(func() -> bool: return (entry.get("_pieces") as Array).size() == 3, 30.0), "three things come out")
	expect(await _until_said(said, "Welcome.", 60.0), "the ripple, then welcome")
	expect(_shown(entry.get("_details")) > 0, "the workshop is shown")
	expect(await _until_said(said, ADVENTURE.greeting, 60.0), "Wei's World starts")
	expect_eq(App.main.current_scene, &"find_object", "in its own scene")


func test_jumping_to_each_part_plays_only_that_part() -> void:
	await _boot_entry()
	var said := record(Events.said)
	await _to_setup_panel()
	var orb: Node3D = entry.get("_orb")

	# Ripple first: the things are already on the table, Onion aside, workshop hidden.
	await _press(&"entry_part_ripple")
	await frames(2)
	expect_eq((entry.get("_pieces") as Array).size(), 3, "ripple: the things are already out")
	expect(orb.global_position.distance_to(entry.call("_aside_spot")) < 0.01, "ripple: Onion is already aside")
	expect(await _until_said(said, "Welcome.", 60.0), "ripple: plays and says welcome")
	expect(not _said_line(said, "Hello."), "ripple: no hello")
	expect(await until(func() -> bool: return _target(&"entry_part_all") != null, 30.0), "ripple: the panel comes back")
	var details := _shown(entry.get("_details"))
	expect(details > 0, "ripple: the workshop was revealed")

	# Hello: the workshop goes, the things go, Onion back inside.
	await _press(&"entry_part_hello")
	await frames(2)
	expect_eq(_shown(entry.get("_details")), 0, "hello: the workshop is hidden again")
	expect((entry.get("_pieces") as Array).is_empty(), "hello: the table is clear")
	expect(await _until_said(said, "I'm Onion, by the way."), "hello: plays")
	expect(await until(func() -> bool: return _target(&"entry_part_all") != null, 30.0), "hello: the panel comes back")

	# Touch: waits for the touch, then back to the panel (nothing comes out).
	await _press(&"entry_part_touch")
	await _touch_cauldron()
	expect(await until(func() -> bool: return _target(&"entry_part_all") != null, 30.0), "touch: the panel comes back after the touch")
	expect((entry.get("_pieces") as Array).is_empty(), "touch: nothing comes out")

	# Emerge: Onion moves aside and three things come out, then back to the panel.
	await _press(&"entry_part_emerge")
	expect(await until(func() -> bool: return _target(&"entry_part_all") != null, 30.0), "emerge: the panel comes back")
	expect_eq((entry.get("_pieces") as Array).size(), 3, "emerge: three things are out")

	# Still one of each.
	expect_eq(entry.find_children("*", "Target", true, false).filter(func(t: Target) -> bool: return t.id == &"entry_cauldron").size(), 1, "one cauldron")

	# Shelf: straight into Wei's World.
	await _press(&"entry_part_shelf")
	expect(await _until_said(said, ADVENTURE.greeting, 60.0), "shelf: Wei's World starts")
	expect_eq(App.main.current_scene, &"find_object", "shelf: in its own scene")


## Puts the right fingertip at [param point] (button space), the hand behind it pointing into the plate.
func _poke_at(button: EntryButton, local: Vector3) -> void:
	var tip := button.to_global(local)
	var back := button.global_basis.z.normalized()
	input.point(&"right", tip + back * App.rig.pointer(&"right").tip_reach, tip)
	await frames(3)


func test_poking_anywhere_on_the_plate_presses_it() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var pressed := record(entry._part_pressed)
	var start: EntryButton = _target(&"entry_part_all").get_parent()
	await wait(1.0)   # a finger already there as a button appears doesn't count
	# Near the far end of the plate, which the old round hit area missed.
	await _poke_at(start, Vector3(start.plate.x * 0.5 - 0.01, 0.0, 0.15))
	await _poke_at(start, Vector3(start.plate.x * 0.5 - 0.01, 0.0, -0.01))
	expect_eq(pressed.size(), 1, "one press from one poke (pokes and pinches don't double)")
	expect_eq(pressed[0][0] if not pressed.is_empty() else null, &"all", "and it was Start")


func test_a_pinch_counts_what_was_aimed_at_before_the_fingers_closed() -> void:
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
	expect_eq(pressed.size(), 1, "the pinch still presses the button that was aimed at")


func test_a_pinch_after_a_real_move_to_another_button_goes_to_that_button() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var pressed := record(entry._part_pressed)
	var ripple := _target(&"entry_part_ripple")
	var shelf := _target(&"entry_part_shelf")
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


func test_exit_needs_two_presses_so_a_stray_pinch_cannot_close_the_app() -> void:
	await _boot_entry()
	await _to_setup_panel()
	var exit_button: EntryButton = _target(&"entry_debug_exit").get_parent()
	expect_eq(exit_button.text(), "Exit app", "it starts as Exit app")
	await select(_target(&"entry_debug_exit").global_position)
	await frames(3)
	expect(is_instance_valid(app), "one press does not quit")
	expect_eq(exit_button.text(), "Press again to exit", "it asks for a second press")
	await wait(3.5)
	expect_eq(exit_button.text(), "Exit app", "and goes back if none comes")


func test_on_desktop_only_a_click_presses_not_moving_over_a_button() -> void:
	await _boot_entry()
	entry.poke_in_sim = false
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
	await until(func() -> bool: return _target(&"entry_part_ripple") != null, 20.0)
	await _press(&"entry_part_ripple")
	expect(await _until_said(said, "Welcome.", 60.0), "the ripple plays straight from step 1")
	expect(not _said_line(said, "Hello."), "and nothing before it")


func test_the_workshop_survives_the_handoff_and_leaves_with_the_next_scene() -> void:
	await _boot_entry()
	await _to_setup_panel()
	await _press(&"entry_part_shelf")
	expect(await until(func() -> bool: return App.main.current_scene == &"find_object" and not App.main.switching, 30.0), "the shelf scene loads")
	await wait(1.5)
	var workshop := App.main.get_node_or_null(^"Workshop") as Workshop
	expect(workshop != null, "the workshop is still there")
	if workshop == null:
		return
	expect(workshop.find_children("*", "OmniLight3D", true, false).size() == 1, "with Onion (and its light)")
	expect(workshop.get_children().filter(func(n: Node) -> bool: return n is Node3D and n.find_children("*", "Target", true, false).is_empty() == false).is_empty(), "the cauldron cannot be touched any more")
	var guides := App.world.get_children().filter(func(n: Node) -> bool: return n is Guide)
	expect_eq(guides.size(), 1, "the World has its guide")
	expect(guides[0].body != null, "and Onion is its body")
	await App.main.change_scene(&"global_motion")
	await wait(0.5)
	expect(not is_instance_valid(workshop), "the workshop goes when the child leaves that scene")


func test_the_shelf_stands_back_along_the_table_not_in_front_of_the_player() -> void:
	await _boot_entry()
	await until(func() -> bool: return _target(&"entry_step_next") != null, 20.0)
	await _to_setup_panel()
	var tidy_trial = load("res://trials/tidy/tidy_trial.gd")
	expect_eq(tidy_trial.push, Entry.SHELF_PUSH, "the opening sets how far back the shelf stands")
	var eye := App.head().global_position
	var bench: Transform3D = entry.get("_bench")
	var away := Vector2(bench.origin.x - eye.x, bench.origin.z - eye.z).length()
	expect(absf(away - Entry.SHELF_PUSH) < 0.01, "the whole play set is that far along the table from the eyes, got %s" % away)
	var cauldron: Node3D = entry.get("_box")
	var shelf_frame: Transform3D = bench
	var local := shelf_frame.affine_inverse() * cauldron.global_position
	expect(absf(local.x) > (0.48 + 0.06) * 0.5 or -local.z > 0.41 + 0.11 or local.z > 0.0, "the cauldron does not stand inside the shelf's footprint")
