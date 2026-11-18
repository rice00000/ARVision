extends TestCase


func _intro() -> RoomIntro:
	return app.get_node(^"RoomIntro") as RoomIntro


func _onion() -> Onion:
	var found := _intro().find_children("*", "Onion", false, false)
	return found.front() if not found.is_empty() else null


func _press(id: String) -> void:
	await wait(0.35)
	var target: Target = app.find_child(id, true, false)
	expect(target != null, "button exists: " + id)
	if target: await select(target.global_position)
	await frames(3)


func _into_room() -> void:
	await _press("menu_open")
	await _press("menu_room")


## A child who presses whatever Onion asks for, until something is bought.
func _buy_what_onion_asks() -> void:
	for i in 20:
		if not App.module(&"Decor").items().is_empty():
			return
		var button: Target = _intro().call(&"_next")
		if button == null:
			await frames(2)
			continue
		await _press(String(button.id))


func test_the_first_room_visit_teaches_buying_and_placing_and_is_then_seen() -> void:
	await boot()
	_intro().automatic = true
	var said := record(Events.said)
	var reports := record(Events.reported)
	await _into_room()
	expect(_intro().running, "the first room visit starts the intro")
	expect(await until(func() -> bool: return _onion() != null), "Onion appears beside the room's bar")
	expect(await until(func() -> bool: return App.module(&"Inventory").count(&"magic_stone") == 1, 15.0), "a child with no stones gets one")
	expect(reports.any(func(args: Array) -> bool: return args[0] == &"room_intro_gift"), "the gift is logged")
	expect(await until(func() -> bool: return said.any(func(args: Array) -> bool: return args[0] == "Pinch Shop to see what you can buy."), 15.0), "Onion asks for the shop")
	await _buy_what_onion_asks()
	var pieces: Array = App.module(&"Decor").items()
	expect_eq(pieces.size(), 1, "the bought furniture is in the room")
	if pieces.is_empty():
		return
	expect_eq(App.module(&"Inventory").count(&"magic_stone"), 0, "it was paid for")
	var piece: Target = pieces[0]
	expect(await until(func() -> bool: return said.any(func(args: Array) -> bool: return args[0] == "Now pinch it, move your hand, and let go where you see the tick."), 15.0), "Onion asks to place it")
	Events.selected.emit(&"right", piece, App.head().global_position, Vector3.FORWARD)   # the child takes it
	await frames(2)
	Events.button.emit(&"right", &"trigger_click", false)   # and lets go on a free spot
	expect(await until(func() -> bool: return _intro().seen, 20.0), "placing it finishes the intro")
	expect(said.any(func(args: Array) -> bool: return args[0] == "That looks lovely there."), "Onion likes the spot")
	expect(await until(func() -> bool: return _onion() == null, 5.0), "and Onion goes")
	await _press("menu_back")
	await _press("menu_room")
	expect(not _intro().running, "a seen intro does not come back on its own")
	Save.write()
	Save.reload()
	expect(_intro().seen, "seen is saved with the child's progress")


func test_leaving_the_room_stops_it_and_the_next_visit_starts_again() -> void:
	await boot()
	_intro().automatic = true
	await _into_room()
	expect(await until(func() -> bool: return _onion() != null), "Onion is there")
	await _press("menu_back")
	expect(not _intro().running and not _intro().seen, "leaving stops it, not seen")
	expect(await until(func() -> bool: return _onion() == null), "Onion goes with it")
	await _press("menu_room")
	expect(_intro().running, "the next room visit starts it again")


func test_fingertip_touch_plays_onions_sound_during_the_room_intro() -> void:
	await boot()
	_intro().automatic = true
	await _into_room()
	var onion := _onion()
	var sound := onion.touch.get_child(onion.touch.get_child_count() - 1) as AudioStreamPlayer3D
	expect(get_tree().paused, "My room pauses the activity")
	expect(await until(func() -> bool: return not OnionFlight.flying(onion), 6.0), "Onion lands after its welcome flight")
	await wait(0.6) # and settles from the bounce.
	var at := onion.global_position
	var away := at + Vector3.RIGHT * 0.2
	var offset := Vector3.BACK * App.rig.pointer(&"right").tip_reach
	input.point(&"right", away + offset, away)
	await frames(3)
	input.point(&"right", at + offset, at)
	await frames(3)
	expect_eq(onion.touch.reactions, 1, "a fingertip touch reacts in the paused room")
	expect(sound.playing, "the shared touch sound is playing")


func test_the_teaching_hand_points_at_the_button_when_the_child_waits() -> void:
	await boot()
	_intro().automatic = true
	App.module(&"Inventory").add(&"magic_stone", 3)   # no gift needed
	await _into_room()
	var demo: DemoHand
	expect(await until(func() -> bool:
		var hands := _intro().find_children("*", "DemoHand", false, false)
		demo = hands.front() if not hands.is_empty() else null
		return demo != null and demo._mode == DemoHand.Mode.AIM_PINCH, RoomIntro.HAND_AFTER + 10.0), "the hand shows the pinch")
	expect_eq(App.module(&"Inventory").count(&"magic_stone"), 3, "no gift when the child can buy")
	if demo != null:
		expect(demo._key == app.find_child("home_shop", true, false), "at the Shop button")


func test_staff_tools_play_it_again_from_any_scene() -> void:
	await boot()
	_intro().automatic = true
	_intro().seen = true
	input.menu()
	await frames(2)
	await press_facilitator("fac_tools")
	await frames(2)
	await press_facilitator("fac_room_intro")
	expect(await until(func() -> bool: return App.module(&"Home").page == &"room"), "the room opens")
	expect(_intro().running, "and the intro plays although it was seen")
	expect(await until(func() -> bool: return _onion() != null), "with Onion")


func test_the_first_visit_onion_swoops_in_loops_lands_beside_the_bar_then_welcomes() -> void:
	await boot()
	_intro().automatic = true
	var said := record(Events.said)
	await _into_room()
	expect(await until(func() -> bool: return _onion() != null), "Onion comes")
	var onion := _onion()
	var eye := App.head().global_position
	expect(OnionFlight.flying(onion), "flying in")
	var nearest := 99.0
	var lowest := 99.0
	var highest := -99.0
	var start := onion.global_position
	while OnionFlight.flying(onion):
		nearest = minf(nearest, onion.global_position.distance_to(eye))
		lowest = minf(lowest, onion.global_position.y)
		highest = maxf(highest, onion.global_position.y)
		await frames(1)
	expect(start.distance_to(eye) > 1.5, "it comes from the far side of the room")
	expect(nearest > 0.4, "it never comes close to the child's face (%.2f m)" % nearest)
	expect(highest - lowest > 0.4, "a real loop, not a slide (%.2f m high)" % (highest - lowest))
	var bar: Target = app.find_child("home_shop", true, false)
	var spot: Vector3 = bar.get_parent().global_transform * RoomIntro.SPOT
	await wait(0.6)
	expect(onion.global_position.distance_to(spot) < 0.01, "it lands at its spot beside the bar")
	expect(is_equal_approx(onion.scale.x, 1.0) and is_equal_approx(onion.scale.y, 1.0), "settled after the bounce")
	expect(await until(func() -> bool: return said.any(func(args: Array) -> bool: return args[0] == RoomIntro.WELCOME), 5.0), "then: " + RoomIntro.WELCOME)
	expect(get_tree().paused, "the room (menu) stays live while it flies")


func test_staff_replay_and_a_later_visit_skip_nothing_but_the_seen_intro() -> void:
	await boot()
	_intro().automatic = true
	_intro().seen = true
	await _into_room()
	await wait(0.5)
	expect(_onion() == null, "after the first visit: no flight, no welcome")
