extends TestCase

const FIND := preload("res://trials/find/find.tres")


func _home() -> Node:
	return App.module(&"Home")


func _inventory() -> Node:
	return App.module(&"Inventory")


func _press(id: String) -> void:
	await wait(0.35)
	var target: Target = _home().find_child(id, true, false) if id != "home_open" else App.rig.find_child(id, true, false)
	expect(target != null, "button exists: " + id)
	if target: await select(target.global_position)
	await frames(3)


func test_catalogue_has_ten_furniture_and_three_room_scenes() -> void:
	await boot()
	expect_eq(ItemDef.all(ItemDef.Kind.FURNITURE).size(), 10, "all furniture ported")
	expect_eq(ItemDef.all(ItemDef.Kind.ROOM).size(), 3, "three distinct rooms")
	for kind in [ItemDef.Kind.FURNITURE, ItemDef.Kind.ROOM]:
		for item in ItemDef.all(kind):
			var visual := item.scene.instantiate()
			app.add_child(visual)
			expect(HomeUI.bounds_of(visual).size.length() > 0, "visible model: " + String(item.id))
			expect(not BakedSpeech.paths_for("%s. %d magic stones." % [item.title, item.price]).is_empty(), "spoken price")
			visual.free()


func test_purchases_are_atomic_and_room_ownership_is_unique() -> void:
	await boot()
	var inventory := _inventory()
	expect(not inventory.buy(&"chair"), "no money: purchase denied")
	expect_eq(inventory.count(&"chair"), 0, "no item created")
	inventory.add(&"magic_stone", 8)
	expect(inventory.buy(&"room_gallery"), "buy room")
	var after: int = inventory.count(&"magic_stone")
	expect(not inventory.buy(&"room_gallery"), "owned room is not charged twice")
	expect_eq(inventory.count(&"magic_stone"), after, "balance unchanged")
	expect(inventory.buy(&"chair"), "buy furniture")
	Save.write()
	var state: Dictionary = inventory.all()
	inventory.add(&"magic_stone", 20)
	Save.reload()
	expect_eq(inventory.all(), state, "transaction survives reload")


func test_home_opens_during_grab_only_training_and_resumes_same_round() -> void:
	var plan := plan_of(FIND, 1)
	plan.blocks[0].ray = false
	await boot(plan)
	App.session.play(plan)
	await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running())
	var trial := App.session.trial
	var before := trial.seconds()
	await _press("home_open")
	expect(_home().is_open and get_tree().paused, "always reachable even without a trial ray")
	await wait(0.5)
	expect(trial.seconds() - before < 0.4, "training clock paused")
	expect(not App.stage.visible and App.reality.home_room != null, "leisure room replaces training view")
	await _press("home_close")
	expect(not get_tree().paused and App.stage.visible and App.reality.home_room == null, "AR view restored")
	expect(App.session.trial == trial and trial.is_running(), "same unscored round continues")


func test_shop_needs_separate_confirmation_and_a_second_press_cannot_buy_twice() -> void:
	await boot()
	_inventory().add(&"magic_stone", 5)
	await _press("home_open")
	await _press("home_shop")
	var id: StringName = _home()._item().id
	await _press("home_buy")
	expect_eq(_inventory().count(id), 0, "preview costs nothing")
	await _press("home_confirm")
	expect_eq(_inventory().count(id), 1, "one purchase")
	expect(_home().find_child("home_confirm", true, false) == null, "confirmation target removed")
	_home().close()


func test_furniture_moves_by_pinch_and_last_stored_item_stays_gone() -> void:
	await boot()
	_inventory().add(&"chair")
	_home().open()
	_home()._show(&"decorate")
	var decor := App.module(&"Decor")
	Events.furniture_requested.emit(&"chair")
	expect_eq(decor.items().size(), 1, "one chair placed")
	var chair: Target = decor.items()[0]
	var old := chair.position
	input.point(&"right", App.head().global_position + Vector3(0, -0.2, -0.2), chair.global_position + Vector3.UP * 0.3)
	await frames(2)
	input.press(&"right", &"trigger_click", true)
	await frames(2)
	expect(decor.held == chair, "pinch selects furniture")
	var pose := App.rig.hand(&"right").global_transform
	pose.origin.x += 0.15
	input.set_hand(&"right", pose)
	await frames(3)
	input.press(&"right", &"trigger_click", false)
	await frames(2)
	expect(chair.position.x > old.x + 0.3, "seated hand movement reaches across room")
	Events.selected.emit(&"right", chair, Vector3.ZERO, Vector3.FORWARD)
	Events.furniture_store_requested.emit()
	expect_eq(_inventory().count(&"chair"), 1, "returned to bag once")
	expect_eq(decor.items().size(), 0, "no placed furniture")
	Save.write()
	_home().close()
	Save.reload()
	_home().open()
	expect_eq(decor.items().size(), 0, "last item never resurrects on reload")
	_home().close()


func test_room_layouts_and_profiles_do_not_mix() -> void:
	await boot()
	_inventory().add(&"chair", 2)
	_inventory().add(&"magic_stone", 4)
	_inventory().buy(&"room_gallery")
	_home().open()
	_home()._show(&"decorate")
	var decor := App.module(&"Decor")
	Events.furniture_requested.emit(&"chair")
	App.module(&"Rooms").choose(&"room_gallery")
	expect_eq(decor.items().size(), 0, "new room starts empty")
	Events.furniture_requested.emit(&"chair")
	App.module(&"Rooms").choose(&"room_sun")
	expect_eq(decor.items().size(), 1, "old room restored")
	_home().close()
	Save.write()
	var original := Profile.id
	Profile.switch(Profile.new_save("Home test"))
	await frames(5)
	expect_eq(_inventory().count(&"chair"), 0, "fresh save has no inherited chairs")
	expect_eq(decor.layouts.size(), 0, "fresh save has no inherited layout")
	Profile.switch(original)
	await frames(5)
	expect_eq(decor.layouts.size(), 2, "both room layouts restored")


func test_successful_replays_earn_stones_but_skip_probe_and_failure_do_not() -> void:
	var plan := plan_of(FIND, 1)
	await boot(plan)
	for run in 2:
		App.session.run()
		await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running())
		await select((App.session.trial.get("_target") as Target).global_position)
		await until(func() -> bool: return not App.session.running)
		expect_eq(_inventory().count(&"magic_stone"), (run + 1) * 2, "each completed play earns stones")
		for button in App.stage.get_children():
			if button is ReplayButton: button.queue_free()
	for mode in ["skip", "probe", "fail"]:
		plan.blocks[0].probe = mode == "probe"
		App.session.run()
		await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running())
		if mode == "skip": App.session.skip_block()
		elif mode == "probe": await select((App.session.trial.get("_target") as Target).global_position)
		else: App.session.trial.finish(false)
		await until(func() -> bool: return not App.session.running)
		expect_eq(_inventory().count(&"magic_stone"), 4, mode + " earns nothing")


func test_story_voice_waits_while_home_speaks() -> void:
	await boot()
	var voice := App.module(&"Voice")
	Events.say("Look around the room.")
	var finished := record(voice.line_finished)
	_home().open()
	expect(not finished.any(func(e: Array) -> bool: return e[0] == "Look around the room."), "story line not ended by home")
	_home().close()
	expect_eq(voice.speaking(), "Look around the room.", "same story instruction replays")
