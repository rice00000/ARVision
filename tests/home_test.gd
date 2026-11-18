extends TestCase

const FIND := preload("res://trials/find/find.tres")


func _home() -> Node:
	return App.module(&"Home")


func _inventory() -> Node:
	return App.module(&"Inventory")


func _press(id: String) -> void:
	await wait(0.35)
	var target: Target = app.find_child(id, true, false)
	expect(target != null, "button exists: " + id)
	if target: await select(target.global_position)
	await frames(3)


func test_catalogue_has_sixteen_furniture_and_four_room_scenes() -> void:
	await boot()
	expect(ResourceLoader.has_cached("res://content/items/visuals/bed.tscn"), "item scenes stay loaded from startup")
	expect_eq(ItemDef.all(ItemDef.Kind.FURNITURE).size(), 16, "furniture includes the six Find the object toys")
	expect_eq(ItemDef.all(ItemDef.Kind.ROOM).size(), 4, "starter room and three purchasable rooms")
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
	inventory.load_state({items = {&"magic_stone": 1}})
	expect_eq(inventory.count(&"room_sun"), 1, "older inventories still own the starter room")
	expect(not inventory.buy(&"room_sun"), "the starter room cannot be purchased")
	inventory.take(&"magic_stone")
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
	await _press("menu_open")
	expect(_home().is_open and get_tree().paused, "the menu opens even without a trial ray")
	expect(App.stage.visible and App.reality.home_room == null, "the menu starts over the current activity")
	await wait(0.5)
	expect(trial.seconds() - before < 0.4, "training clock paused")
	await _press("menu_room")
	expect(not App.stage.visible and App.reality.home_room != null, "leisure room replaces training view")
	await _press("menu_back")
	expect(get_tree().paused and App.stage.visible and App.reality.home_room == null, "back restores the AR view while still paused")
	await _press("menu_resume")
	expect(not get_tree().paused and App.stage.visible and App.reality.home_room == null, "AR view restored")
	expect(App.session.trial == trial and trial.is_running(), "same unscored round continues")


func test_the_level_picker_waits_behind_player_and_staff_menus() -> void:
	await boot()
	input.set_head(Transform3D(Basis(Vector3.UP, deg_to_rad(19.0)), App.head().global_position))
	await frames(2)
	await _press("menu_open")
	await _press("menu_resume") # reanchor the side button while looking left of the table
	var entry := App.rig.get_node(^"menu_open") as UITarget
	var side_pose := entry.global_transform
	var started := record(Events.trial_started)
	App.world.run()
	expect(await until(func() -> bool: return App.world.menu != null and App.world.menu.get("_open"), 15.0), "level picker ready")
	var menu := App.world.menu
	expect_eq((menu.get_child(2) as Label3D).text, "Levels", "the panel heading")
	var back := menu.get_child(0) as MeshInstance3D
	var card := menu.get_node(^"task_tidy_shelf_similar_shadows") as Target
	var at := card.global_position
	var half_panel := (back.mesh as QuadMesh).size * 0.5
	var in_menu := menu.global_transform.affine_inverse() * entry.global_transform
	var half_button := ((entry.get_child(0) as CollisionShape3D).shape as BoxShape3D).size * 0.5 * in_menu.basis.get_scale()
	var local := in_menu.origin
	expect(local.x - half_button.x > half_panel.x * 0.5 and local.x + half_button.x < half_panel.x,
		"the Menu button fits the right of the header while looking left")
	expect(local.y - half_button.y > card.position.y + TaskMenu.CARD.y * 0.5 and local.y + half_button.y < half_panel.y,
		"the Menu button fits above the level cards")
	await _press("menu_open")
	expect(_home().is_open and not menu.is_visible_in_tree(), "the player menu hides the level picker")
	await _press("menu_room")
	await _press("menu_back")
	expect(_home().page == &"menu" and not menu.is_visible_in_tree(), "returning from the room keeps the level picker hidden")
	await _press("menu_staff_tools")
	expect(App.module(&"Facilitator").is_open and not menu.is_visible_in_tree(), "staff tools also hide the level picker")
	await press_facilitator("fac_close")
	expect(_home().is_open and not menu.is_visible_in_tree(), "returning from staff tools keeps the level picker hidden")
	await _press("menu_resume")
	expect(App.world.menu == menu and menu.is_visible_in_tree() and not get_tree().paused, "the same level picker comes back")
	expect_eq(card.global_position, at, "the level card stays in place")
	expect(started.is_empty(), "the menus did not choose a level")
	await select(at)
	expect(await until(func() -> bool: return started.size() == 1), "the restored level card starts its round")
	await wait(0.25)
	expect(entry.global_transform.is_equal_approx(side_pose), "the button returns to its side position after the panel folds")


func test_shop_needs_separate_confirmation_and_a_second_press_cannot_buy_twice() -> void:
	await boot()
	await _press("menu_open")
	await _press("menu_room")
	var said := record(Events.said)
	await _press("home_shop")
	expect(App.reality.home_room != null, "the shop opens in the room")
	expect(_home().find_child("home_buy", true, false) == null, "nothing to press without enough stones")
	expect(_home().find_child("menu_resume", true, false) == null, "only the menu and the room resume the game")
	expect_eq(said[-1][0], "Chair. 1 magic stones. You need 1 more.", "the price and what is missing are spoken")
	for line in ["Dog. 8 magic stones. You need 11 more.", "Cat. 8 magic stones. You can buy it.", "Panda. It is yours!"]:
		expect(not BakedSpeech.paths_for(line).is_empty(), "baked: " + line)
	_inventory().add(&"magic_stone", 5)
	await frames(2)
	var id := &"toy_ball"
	var furniture := ItemDef.all(ItemDef.Kind.FURNITURE)
	for i in furniture.find(ItemDef.find(id)):
		await _press("home_next")
	expect_eq(_home()._item().id, id, "the Find the object ball is in the shop")
	await _press("home_buy")
	expect_eq(_inventory().count(id), 0, "preview costs nothing")
	var stones: int = _inventory().count(&"magic_stone")
	await _press("home_confirm")
	var decor := App.module(&"Decor")
	expect_eq(_inventory().count(&"magic_stone"), stones - ItemDef.find(id).price, "one purchase")
	expect_eq([_home().page, decor.items().size(), _inventory().count(id)], [&"room", 1, 0], "the new furniture stands in the room, not in the box")
	expect_eq((decor.items()[0] as Target).id, id, "the purchased toy is placed")
	expect(_home().find_child("home_confirm", true, false) == null, "confirmation target removed")
	_home().close()


func test_shop_pages_switch_in_place_and_the_box_stores_or_opens() -> void:
	await boot()
	_inventory().add(&"chair")
	await _press("menu_open")
	await _press("menu_room")
	await _press("home_shop")
	for tab in ["pets", "rooms", "shop"]:
		await _press("home_tab_" + tab)
		expect_eq(_home().page, StringName(tab), "one pinch changes the shop page: " + tab)
		expect_eq(_home().find_children("home_tab_*", "Target", true, false).size(), 3, "all three pages stay on show")
	await _press("home_back")
	var decor := App.module(&"Decor")
	expect(decor.editing, "furniture can be moved as soon as the room opens")
	await _press("home_box")
	expect_eq(_home().page, &"bag", "an empty hand opens the box")
	await _press("home_place")
	expect_eq([_home().page, decor.items().size()], [&"room", 1], "the chair comes out into the room")
	Events.selected.emit(&"left", decor.items()[0], Vector3.ZERO, Vector3.FORWARD)
	await _press("home_box")
	expect_eq([_home().page, decor.items().size(), _inventory().count(&"chair")], [&"room", 0, 1], "a held chair goes into the box")
	await _press("home_box")
	await _press("home_back")
	expect_eq(_home().page, &"room", "back from the box to the room")
	_home().close()


func test_a_bought_room_can_be_visited_from_its_shop_preview() -> void:
	await boot()
	_inventory().add(&"magic_stone", 10)
	await _press("menu_open")
	await _press("menu_room")
	await _press("home_shop")
	await _press("home_tab_rooms")
	expect_eq(_home()._item().id, &"room_sun", "the starter is the first room")
	expect(_home().find_child("home_use_room", true, false) != null, "the starter shows Visit")
	expect(_home().find_child("home_buy", true, false) == null, "the starter never shows Buy")
	await _press("home_prev")
	expect_eq(_home()._item().id, &"room_observatory", "browse to the observatory")
	await _press("home_buy")
	expect_eq(_inventory().count(&"room_observatory"), 0, "preview has no cost")
	await _press("home_confirm")
	expect_eq(_inventory().count(&"magic_stone"), 0, "confirmation charges the room price")
	await _press("home_use_room")
	expect_eq(_home().page, &"room", "visit returns to the room controls")
	expect_eq(App.reality.home_room.scene_file_path, "res://content/rooms/observatory.tscn", "visit shows the purchased scene")
	expect(App.reality.home_room.has_node(^"Roof") and App.reality.home_room.has_node(^"Sky"),
		"the full room keeps its roof and sky")
	_home().close()


func test_furniture_moves_by_pinch_and_last_stored_item_stays_gone() -> void:
	await boot()
	_inventory().add(&"chair")
	_home().open()
	_home()._show(&"room")
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
	_home()._show(&"room")
	expect_eq(decor.items().size(), 0, "last item never resurrects on reload")
	_home().close()


func test_room_layouts_and_profiles_do_not_mix() -> void:
	await boot()
	_inventory().add(&"chair", 2)
	_inventory().add(&"magic_stone", 4)
	_inventory().buy(&"room_gallery")
	_home().open()
	_home()._show(&"room")
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


func test_room_pinching_empty_floor_moves_the_view_and_keeps_the_layout() -> void:
	await boot()
	_inventory().add(&"chair")
	_home().open()
	_home()._show(&"room")
	Events.furniture_requested.emit(&"chair")
	await frames(3)
	var chair: Target = App.module(&"Decor").items()[0]
	var pose := chair.transform
	var frame := App.reality.room_frame
	var floor := frame * Vector3(1.35, 0.0, -1.4)
	await select(floor)
	var moved := App.reality.room_frame
	var eye := App.head().global_position
	expect(moved * Vector3(1.35, eye.y, -1.4) == eye, "head is above the destination")
	expect_eq(chair.transform, pose, "furniture stays fixed in room coordinates")
	expect(chair.global_position.is_equal_approx(moved * pose.origin), "furniture follows the room")
	var near_chair := moved * (pose.origin + Vector3.RIGHT * 0.39)
	await select(near_chair)
	expect_eq(App.reality.room_frame, moved, "no landing beside furniture without clearance")
	_home()._show(&"shop")
	await select(moved * Vector3(1.85, 0, -1.25))
	expect_eq(App.reality.room_frame, moved, "shopping disables teleporting")
	_home().close()


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


func test_player_games_offer_only_playable_training_and_switch_once() -> void:
	await boot()
	await _press("menu_open")
	await _press("menu_games")
	var panel := _home()
	expect_eq(panel.find_children("menu_game_*", "Target", true, false).size(), 1, "only the other training game can be picked")
	await _press("menu_game_global_motion")
	expect(await until(func() -> bool: return app.current_scene == &"global_motion" and not app.switching), "the other game opens")
	expect(not panel.is_open and not get_tree().paused, "the scene change closes the menu")
