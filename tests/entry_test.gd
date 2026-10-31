extends TestCase
## Megan's opening (Entry in main.tscn, direction of Oct 30): it plays before the
## World unless a session plan is given. Setup for the adult (table check, then
## Start or a part to jump to), then Onion's hello, the cauldron touch, the things
## coming out, the ripple, and Wei's shelf with Onion as the guide.

const TIDY := preload("res://trials/tidy/tidy.tres")

var entry: Entry


## Boots main.tscn and starts the opening, like a launch without a plan does.
func _boot_entry() -> void:
	await boot()
	entry = app.get_node(^"Entry")
	entry.run()


func _said_line(said: Array, text: String) -> bool:
	return said.any(func(args: Array) -> bool: return args[0] == text)


func _until_said(said: Array, text: String, timeout := 30.0) -> bool:
	return await until(func() -> bool: return _said_line(said, text), timeout)


func _target(id: StringName) -> Target:
	return entry.find_child(String(id), true, false) as Target


## Waits for a button and presses it (points and pinches).
func _press(id: StringName) -> bool:
	if not await until(func() -> bool: return _target(id) != null, 20.0):
		return false
	await select(_target(id).global_position)
	await frames(2)
	return true


## Confirms the table and waits for the Start panel.
func _to_setup_panel() -> void:
	await _press(&"entry_confirm_yes")
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


func test_a_launch_holds_the_world_and_a_plan_skips_the_opening() -> void:
	var said := record(Events.said)
	app = load("res://main.tscn").instantiate()
	add_child(app)
	input = App.sim_input
	await frames(2)
	expect(not App.world.autostart, "the opening holds the World back")
	await shutdown()
	app = load("res://main.tscn").instantiate()
	(app.get_node(^"Session") as Session).plan = plan_of(TIDY, 1)
	add_child(app)
	input = App.sim_input
	await wait(3.0)
	expect(not _said_line(said, "Hello."), "no opening before a planned session")
	expect((app.get_node(^"Entry") as Entry).get("_onion") == null, "and nothing of it is built")


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
	expect(_target(&"entry_part_hello") == null, "the panel goes")
	expect(await _until_said(said, "Hello."), "Onion says hello")
	expect(await _until_said(said, "I'm Onion, by the way."), "and its name")
	await _touch_cauldron()
	expect(await until(func() -> bool: return (entry.get("_pieces") as Array).size() == 3, 30.0), "three things come out")
	expect(await _until_said(said, "Welcome.", 60.0), "the ripple, then welcome")
	expect(_shown(entry.get("_details")) > 0, "the workshop is shown")
	var greeting := App.world.adventure.greeting
	expect(await _until_said(said, greeting, 60.0), "Wei's World starts")
	expect(entry.get("_guide") != null, "with Onion as its guide")


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
	expect(await _until_said(said, App.world.adventure.greeting, 60.0), "shelf: Wei's World starts")
	expect(entry.get("_guide") != null, "shelf: with Onion as its guide")


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
	var at := start.global_position
	input.point(&"right", eye + (at - eye).normalized() * 0.25 + Vector3.DOWN * 0.05, at)
	await wait(0.5)
	# The aim slips off the button as the fingers close, then the click lands.
	var off := at + Vector3.UP * 0.6
	input.point(&"right", eye + (off - eye).normalized() * 0.25 + Vector3.DOWN * 0.05, off)
	await wait(0.08)
	input.click(&"right", &"trigger_click")
	await frames(3)
	expect_eq(pressed.size(), 1, "the pinch still presses the button that was aimed at")


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
