extends TestCase

const FIND := preload("res://trials/find/find.tres")


func test_ui_requires_an_aimed_pinch_even_when_a_hand_passes_through_it() -> void:
	var plan := plan_of(FIND, 1)
	plan.blocks[0].ray = false
	await boot(plan)
	App.session.play(plan)
	await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running())
	var home: UITarget = App.rig.find_child("menu_open", true, false)
	var at := home.global_position
	var pointer := App.rig.pointer(&"right")
	var touched := record(Events.touched)
	input.point(&"right", at + Vector3.BACK * 0.2, at)
	await frames(3)
	input.point(&"right", at + Vector3.BACK * pointer.tip_reach, at)
	await frames(3)
	expect(touched.is_empty() and not App.menu_active(), "passing through the menu entry cannot open it")
	Events.touched.emit(&"right", home)
	await frames(2)
	expect(not App.menu_active(), "home has no touch listener")
	var raw_pinch := {paused = false}
	var on_button := func(_hand: StringName, action: StringName, pressed: bool) -> void:
		if action == &"trigger_click" and pressed: raw_pinch.paused = get_tree().paused
	Events.button.connect(on_button)
	await select(at)
	Events.button.disconnect(on_button)
	await frames(3)
	expect(App.module(&"Home").is_open, "an aimed pinch opens home in grab-only training")
	expect(raw_pinch.paused, "the menu pauses before gameplay hears the pinch")
	App.module(&"Home").close()


func test_facilitator_takes_over_from_player_room_and_cancels_a_queued_open() -> void:
	await boot()
	var home := App.module(&"Home")
	var entry := App.rig.find_child("menu_open", true, false) as UITarget
	home.open()
	home._show(&"room")
	input.menu()
	await frames(2)
	expect(App.module(&"Facilitator").is_open and not home.is_open, "only the adult panel is open")
	expect(get_tree().paused and App.stage.visible and App.reality.home_room == null, "training is visible but still paused")
	expect(not entry.visible and entry.collision_layer == 0, "the player entry cannot intercept the adult panel")
	input.menu()
	await frames(2)
	expect(not get_tree().paused and entry.visible, "closing the adult panel restores play and the entry")
	Events.selected.emit(&"right", entry, Vector3.ZERO, Vector3.FORWARD)
	input.menu()
	await frames(2)
	expect(App.module(&"Facilitator").is_open and not home.is_open, "a queued player press cannot open over the adult panel")


func test_the_visible_menu_opens_staff_tools_and_returns_to_the_same_round() -> void:
	await boot(plan_of(FIND, 1))
	App.session.run()
	await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running())
	var trial := App.session.trial
	var home := App.module(&"Home")
	var facilitator := App.module(&"Facilitator")
	await select((App.rig.find_child("menu_open", true, false) as Target).global_position)
	await wait(0.35)
	await select((home.find_child("menu_staff_tools", true, false) as Target).global_position)
	expect(facilitator.is_open and not home.is_open and get_tree().paused, "only staff tools owns input")
	expect(facilitator.find_child("fac_restart", true, false) != null, "the button opens the Tools page directly")
	await press_facilitator("fac_close")
	expect(home.is_open and not facilitator.is_open and get_tree().paused, "Menu returns to the player menu while paused")
	await wait(0.35)
	await select((home.find_child("menu_resume", true, false) as Target).global_position)
	expect(App.session.trial == trial and not get_tree().paused, "Close resumes the same round")


func test_shared_ray_focus_feedback_and_tracking_loss_work_while_paused() -> void:
	await boot()
	input.menu()
	await frames(3)
	var button: UITarget = App.module(&"Facilitator").find_child("fac_saves", true, false)
	var pointer := App.rig.pointer(&"right")
	var at := button.global_position
	var world_ui := EntryButton.new()
	app.add_child(world_ui)
	world_ui.setup("World UI", &"world_ui", Color.WHITE, Vector2(0.2, 0.1), 0.0)
	world_ui.global_position = at + Vector3.BACK * 0.15
	input.point(&"right", at + Vector3.BACK * 0.3, at)
	await frames(4)
	expect(get_tree().paused and button.hovered, "paused UI receives ray hover")
	expect(pointer.aimed == button, "in-world UI cannot intercept a modal panel's ray")
	expect(pointer.get_node(^"UIRay").visible and pointer.get_node(^"UICursor").visible, "ray and hit marker visible")
	expect(button.get_node(^"Focus").visible, "button has a shared focus outline")
	var feedback := record(Events.feedback)
	input.click(&"right", &"trigger_click")
	await frames(3)
	expect_eq(App.module(&"Facilitator").get("_page_shown"), &"Saves", "the pinch selects the tab")
	expect_eq(feedback.size(), 1, "one confirmation sound")
	input.track(&"right", false)
	await frames(3)
	expect(not button.hovered and pointer.aimed == null, "tracking loss clears the focus immediately")
	expect(not pointer.get_node(^"UIRay").visible, "untracked hands have no ray")
	input.click(&"right", &"trigger_click")
	expect_eq(feedback.size(), 1, "tracking loss cannot confirm a stale target")
	input.menu()


func test_ui_touches_and_nearby_grips_cannot_replay_a_session() -> void:
	await boot()
	var replay := ReplayButton.new()
	app.add_child(replay)
	replay.global_position = App.head().global_position + Vector3(0, -0.1, -0.5)
	var pressed := record(replay.pressed)
	var at := replay.global_position
	Events.touched.emit(&"right", replay)
	input.point(&"right", at + Vector3.BACK * 0.05, at + Vector3.BACK)
	await frames(3)
	input.click(&"right", &"grip_click")
	await frames(3)
	expect(pressed.is_empty(), "neither a touch event nor a nearby grip activates UI")
	await select(at)
	expect_eq(pressed.size(), 1, "a ray pinch replays once")


func test_gameplay_keeps_direct_touch_without_a_visible_ui_ray() -> void:
	await boot(plan_of(FIND, 1))
	var target := Target.sphere(&"toy", 0.05)
	app.add_child(target)
	target.global_position = Vector3(0, 0.9, -0.5)
	var pointer := App.rig.pointer(&"right")
	input.point(&"right", Vector3(0, 0.9, 0), target.global_position)
	await frames(3)
	expect(not pointer.get_node(^"UIRay").visible, "normal gameplay has no UI beam")
	var touched := record(Events.touched)
	input.point(&"right", target.global_position + Vector3.BACK * pointer.tip_reach, target.global_position)
	await frames(3)
	expect_eq(touched.size(), 1, "reaching still touches a toy")
