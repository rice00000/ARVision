extends TestCase

const FIND := preload("res://trials/find/find.tres")


func test_ui_requires_an_aimed_pinch_even_when_a_hand_passes_through_it() -> void:
	var plan := plan_of(FIND, 1)
	plan.blocks[0].ray = false
	await boot(plan)
	App.session.play(plan)
	await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running())
	var home: UITarget = App.rig.find_child("home_open", true, false)
	var at := home.global_position
	var pointer := App.rig.pointer(&"right")
	var touched := record(Events.touched)
	input.point(&"right", at + Vector3.BACK * 0.2, at)
	await frames(3)
	input.point(&"right", at + Vector3.BACK * pointer.tip_reach, at)
	await frames(3)
	expect(touched.is_empty() and not App.menu_active(), "passing through the house cannot open it")
	Events.touched.emit(&"right", home)
	await frames(2)
	expect(not App.menu_active(), "home has no touch listener")
	await select(at)
	await frames(3)
	expect(App.module(&"Home").is_open, "an aimed pinch opens home in grab-only training")
	App.module(&"Home").close()


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
