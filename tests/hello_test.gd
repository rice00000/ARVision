extends TestCase
## Scene 1, Hello (Megan's scene review, Nov 17): the opening calls Effects' HelloFx (bubbles on
## Onion's pop, the cog ticking with the rattle; their own tests: tests/fx/hello_fx_test.gd);
## subtitles bigger, on a dark plate, kept in the room above the action and re-centred only when
## the head turns far (modules/voice/voice.gd).


func _voice() -> Node:
	return App.module(&"Voice")


func _label() -> Label3D:
	return _voice().get("_label")


## Turns the head [param degrees] to the right of straight ahead, at [param pitch] degrees.
func _look(degrees: float, pitch := -10.0) -> void:
	var eye := App.head().global_position
	var dir := Vector3(sin(deg_to_rad(degrees)), 0.0, -cos(deg_to_rad(degrees))) * cos(deg_to_rad(pitch)) + Vector3.UP * sin(deg_to_rad(pitch))
	input.look_at(eye + dir)
	await frames(3)


func test_in_the_opening_the_rattle_ticks_the_cog_and_the_pop_lets_bubbles_out() -> void:
	Engine.time_scale = 1.0
	await boot(null, &"intro")
	app.autostart = true
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	entry.run()
	await until(func() -> bool: return entry.tools_ready and entry.get("_cog") != null, 20.0)
	var cog: Node3D = entry.get("_cog")
	var before := cog.rotation.y
	entry.jump_to(&"hello")
	expect(await until(func() -> bool: return absf(cog.rotation.y - before) > deg_to_rad(3.0), 10.0), "the cog ticks with the rattle")
	expect(await until(func() -> bool: return entry.find_child("pop_burst", true, false) != null, 10.0), "bubbles when Onion pops up")
	var burst := entry.find_child("pop_burst", true, false)
	expect(burst.is_in_group(&"entry_transient"), "a jump clears them")


func test_the_subtitle_stays_in_the_room_until_the_head_turns_far() -> void:
	await boot()
	await _look(0.0)
	Events.say("Look around the room.")
	await frames(2)
	var at := _label().global_position
	expect(_label().visible, "the subtitle shows")
	await _look(20.0)
	expect(_label().global_position.distance_to(at) < 0.001, "a small turn: it stays where it is (not head-locked)")
	await _look(20.0, -40.0)
	expect(_label().global_position.distance_to(at) < 0.001, "looking down at the table: it stays above")
	await _look(55.0)
	await wait(0.6)
	expect(_label().global_position.distance_to(at) > 0.2, "a far turn: it moves to the new view")
	expect(_voice().turned_away() < 5.0, "and stands ahead again")


func test_a_line_right_after_another_keeps_its_place() -> void:
	await boot()
	await _look(0.0)
	Events.say("Look around the room.")
	await frames(2)
	var at := _label().global_position
	await _look(25.0)
	Events.say("Nearly ready.")
	await frames(2)
	expect(_label().global_position.distance_to(at) < 0.001, "the next line shows in the same place")


func test_the_subtitle_is_bigger_on_a_dark_plate() -> void:
	await boot()
	Events.say("Could you help me with something?")
	await frames(2)
	expect(_label().font_size >= 72, "bigger text: 1.5 times the old 48")
	var plate := _label().get_node(^"Plate") as MeshInstance3D
	expect(plate != null and plate.visible, "a plate behind the text")
	var colour: Color = (plate.material_override as StandardMaterial3D).albedo_color
	expect(colour.get_luminance() < 0.1 and colour.a > 0.8, "dark and nearly opaque: high contrast")
	var size: Vector2 = _voice().plate_size()
	expect(size.x > 0.15 and size.y > 0.03, "the plate fits the text (%s m)" % size)
	expect(size.x <= _label().width * _label().pixel_size + 0.05, "and no wider than a line")


func test_the_pop_bubbles_are_not_hidden_inside_onion() -> void:
	Engine.time_scale = 1.0
	await boot(null, &"intro")
	app.autostart = true
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	entry.run()
	await until(func() -> bool: return entry.tools_ready, 20.0)
	entry.jump_to(&"hello")
	expect(await until(func() -> bool: return entry.find_child("pop_burst", true, false) != null, 10.0), "the pop")
	await wait(0.35)
	var burst := entry.find_child("pop_burst", true, false) as Node3D
	var onion := (entry.get("_orb") as Node3D).global_position
	var clear := 0
	for bubble: Node3D in burst.get_children():
		var flat := Vector2(bubble.global_position.x - onion.x, bubble.global_position.z - onion.z).length()
		if flat > 0.05 or bubble.global_position.y > onion.y + 0.05:
			clear += 1
	expect(clear >= PopBurst.COUNT - 1, "the bubbles are out beside or above Onion (%d of %d clear)" % [clear, PopBurst.COUNT])


func test_hello_has_no_nearly_ready_and_one_second_of_quiet() -> void:
	Engine.time_scale = 1.0
	await boot(null, &"intro")
	app.autostart = true
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	entry.run()
	await until(func() -> bool: return entry.tools_ready, 20.0)
	var said := record(Events.said)
	var sounds: Sounds = entry.get("_sounds")
	entry.jump_to(&"all")
	await until(func() -> bool: return bool(entry.get("_part_running")), 10.0)
	var start := Engine.get_process_frames()
	await until(func() -> bool: return sounds.played.has(&"pre_rattle"), 10.0)
	var quiet := (Engine.get_process_frames() - start) / 60.0
	expect(quiet > 0.8 and quiet < 1.4, "about 1 s of quiet before the rattle (%.2f s)" % quiet)
	expect(await until(func() -> bool: return said.any(func(a: Array) -> bool: return a[0] == "I'm Onion, by the way."), 30.0), "Onion introduces itself")
	expect(not said.any(func(a: Array) -> bool: return a[0] == "Nearly ready."), "\"Nearly ready.\" is cut")


## Visual pass (Megan, Nov 18): the floating ☰ Menu and the stones chip leave the child's view from the opening on.
func test_the_floating_menu_and_stones_are_hidden_in_the_opening() -> void:
	Engine.time_scale = 1.0
	await boot(null, &"intro")
	app.autostart = true
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	entry.run()
	await until(func() -> bool: return entry.tools_ready, 20.0)
	entry.jump_to(&"hello")
	await wait(2.0)
	var home := App.module(&"Home")
	expect(home != null and home.get("hide_entry") == true, "the opening hides the floating Menu")
	var button: Node3D = home.get("_entry")
	expect(button != null and not button.visible, "no ☰ Menu or stones in view during Hello")
