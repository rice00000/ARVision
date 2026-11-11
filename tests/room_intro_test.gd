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
	await wait(0.5) # Onion finishes appearing.
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
