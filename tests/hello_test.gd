extends TestCase
## Scene 1, Hello (Megan's scene review, Nov 17): bubbles on Onion's pop and a cog nudge during
## the rattle (entry/fx/hello_fx.gd); subtitles bigger, on a dark plate, kept in the room above
## the action and re-centred only when the head turns far (modules/voice/voice.gd).


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


func test_bubbles_rise_fade_and_go() -> void:
	await boot()
	var mouth := App.head().global_position + Vector3(0.0, -0.4, -0.5)
	var fx := HelloFx.bubbles(App.stage, mouth, 0.04)
	await wait(0.5)
	expect(is_instance_valid(fx) and fx.showing() >= 3, "a few bubbles show")
	var risen := fx.get_children().filter(func(n: Node) -> bool: return (n as Node3D).visible and (n as Node3D).global_position.y > mouth.y + 0.02)
	expect(risen.size() >= 1, "they rise out of the opening")
	for b: Dictionary in fx.get("_bubbles"):
		expect(float((b.material as ShaderMaterial).get_shader_parameter(&"alpha")) <= HelloFx.PEAK + 0.001, "soft: never past the peak alpha")
	expect(fx.is_in_group(&"entry_transient"), "a jump clears them")
	var ref: WeakRef = weakref(fx)
	fx = null
	expect(await until(func() -> bool: return ref.get_ref() == null, 3.0), "gone after about two seconds")


func test_the_cog_nudge_is_one_small_turn() -> void:
	await boot()
	var cog := Node3D.new()
	App.stage.add_child(cog)
	var tween := HelloFx.nudge(cog, 14.0)
	await tween.finished
	var turned := rad_to_deg(cog.rotation.y)
	expect(turned > 5.0 and turned < 14.5, "a small turn that settles a little back (%.1f deg)" % turned)


func test_in_the_opening_the_rattle_nudges_the_cog_and_the_pop_lets_bubbles_out() -> void:
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
	expect(await until(func() -> bool: return absf(cog.rotation.y - before) > deg_to_rad(3.0), 10.0), "the cog turns a notch with the rattle")
	expect(await until(func() -> bool: return entry.find_child("hello_bubbles", true, false) != null, 10.0), "bubbles when Onion pops up")


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
