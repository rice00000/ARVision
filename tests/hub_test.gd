extends TestCase
## The workshop hub, Scenes 7–11 (Megan's scene review, Nov 17; `SCENE_REVIEW_DECISIONS.md`): the games' ring on
## the cauldron, the first visit's welcome and shelf, the dots joining after the first game, the exit token,
## the gear's buttons (Home, Finish visit), the dots' dimmed room and Onion's calm lines, and the closing.

var entry: Entry


## Into the hub as the opening's own flow leaves it (the first visit, with the welcome).
func _to_hub() -> WorkshopController:
	Engine.time_scale = 1.0
	await boot(null, &"intro")
	app.autostart = true
	entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	entry.run()
	await until(func() -> bool: return entry.tools_ready and entry.zones_available(), 20.0)
	entry.call(&"_to_shelf", false)
	await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 30.0)
	await until(func() -> bool: return app.find_child("WorkshopController", true, false) != null, 10.0)
	return app.find_child("WorkshopController", true, false) as WorkshopController


func _said_line(said: Array, text: String) -> bool:
	return said.any(func(args: Array) -> bool: return args[0] == text)


func _in_hub(hub: WorkshopController) -> bool:
	return hub.state == &"hub" and not hub.ring.turning


func _choose(hub: WorkshopController, kind: StringName) -> bool:
	if not await until(func() -> bool: return _in_hub(hub) and hub.ring.impressions.any(func(i: Impression) -> bool: return is_instance_valid(i) and i.kind == kind), 30.0):
		return false
	for impression in hub.ring.impressions:
		if impression.kind == kind:
			Events.selected.emit(&"right", impression.target, Vector3.ZERO, Vector3.FORWARD)
	return true


func _finish_rounds() -> void:
	while App.session.running:
		if App.session.trial != null and App.session.trial.is_running():
			App.session.trial.finish(true)
		await frames(2)


func test_the_first_visit_offers_the_shelf_alone_welcomes_and_teaches_the_pinch() -> void:
	var said := record(Events.said)
	var hub := await _to_hub()
	expect(hub != null, "the hub runs in the first visit")
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.WELCOME), 20.0), "Onion: \"Welcome to the workshop.\"")
	expect_eq(hub.ring.impressions.size(), 1, "only the shelf in the ring (no sealed choices)")
	expect_eq(hub.ring.impressions[0].kind, &"shelf", "the shelf")
	expect(App.session.trial == null, "nothing plays until the child chooses")
	var cauldron := (App.main.get_node(^"Workshop") as Workshop).cauldron()
	expect(cauldron.visible, "the cauldron stays")
	var demo := hub.find_children("*", "DemoHand", true, false)
	expect(not demo.is_empty() and await until(func() -> bool: return (demo[0] as DemoHand).visible, WorkshopController.CUE_AFTER + 4.0),
			"after ~5 s with no choice the hand shows aim-and-pinch")
	expect(not hub.exit_token.visible, "no exit token in the hub")


func test_after_the_first_shelf_the_dots_rise_in_with_their_line_and_home_waits_on_the_gear() -> void:
	var said := record(Events.said)
	var hub := await _to_hub()
	expect(await _choose(hub, &"shelf"), "the child pinches the shelf")
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.running, 20.0), "the shelf plays")
	expect(hub.exit_token.visible and hub.exit_token.open, "the exit token stands by the cauldron during the game")
	expect(not hub.gear.enabled, "the gear's buttons are off during a game")
	Engine.time_scale = 4.0
	await _finish_rounds()
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.MORE), 40.0), "Onion: \"There are more waiting.\"")
	expect(await until(func() -> bool: return _in_hub(hub), 20.0), "back at the hub")
	Engine.time_scale = 1.0
	var kinds := hub.ring.impressions.map(func(i: Impression) -> StringName: return i.kind)
	expect(kinds.has(&"dots"), "the dots rose into the ring (%s)" % [kinds])
	expect(not kinds.has(&"turn_to_fit"), "Turn to fit only when it can run")
	expect(hub.gear.has_home(), "Home is on the gear now")
	expect(not _said_line(said, WorkshopController.SURPRISES), "its line waits for the next game (≤ 2 lines)")
	expect(not _said_line(said, "Thank you for helping."), "cut")


func test_the_exit_token_leaves_a_game_with_a_pinch_never_a_touch() -> void:
	var said := record(Events.said)
	var hub := await _to_hub()
	expect(await _choose(hub, &"shelf"), "the child pinches the shelf")
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.running and App.session.trial != null, 20.0), "the shelf plays")
	Events.touched.emit(&"right", hub.exit_token.target)   # a hand passing through it
	await frames(3)
	expect(App.session.running, "a touch (a sweep through it) never counts")
	Events.selected.emit(&"right", hub.exit_token.target, Vector3.ZERO, Vector3.FORWARD)
	expect(await until(func() -> bool: return not App.session.running, 10.0), "a pinch ends the game")
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.LEFT_EARLY), 15.0), "Onion: \"We can come back to these.\"")
	expect(await until(func() -> bool: return _in_hub(hub), 20.0), "back at the hub")
	expect(not _said_line(said, "There. Everything's found its place."), "no claim of success")


func test_finish_visit_on_the_gear_sinks_the_ring_and_plays_the_closing() -> void:
	var said := record(Events.said)
	var hub := await _to_hub()
	expect(await until(func() -> bool: return _in_hub(hub) and hub.gear.enabled, 30.0), "the hub waits")
	hub.gear.reveal()   # a hand comes near the gear
	await frames(2)
	var finish: HubButton = hub.gear.buttons[&"gear_finish"]
	expect(finish.visible and finish.open, "Finish visit shows on the gear")
	expect(not hub.gear.buttons[&"gear_home"].visible, "Home not yet (after the first game)")
	Engine.time_scale = 4.0
	Events.selected.emit(&"right", finish.target, Vector3.ZERO, Vector3.FORWARD)
	expect(await until(func() -> bool: return not hub.ring.visible, 15.0), "the ring sinks into the cauldron first")
	expect(await until(func() -> bool: return hub.state == &"closed", 90.0), "the closing plays")
	Engine.time_scale = 1.0
	expect(not _said_line(said, "Thank you for trying that with me."), "cut")
	expect(_said_line(said, "It's been lovely having you here."), "the goodbye opens with this")
	var workshop := App.main.get_node(^"Workshop") as Workshop
	expect(not (workshop.get("_mechanism") as Node3D).visible, "the empty socket faded into the table")
	expect(App.results_after_closing, "Staff tools will open on Results")
	App.results_after_closing = false


func test_the_dots_dim_the_room_put_subtitles_under_the_cloud_and_onion_answers_a_wrong_sweep() -> void:
	var said := record(Events.said)
	Engine.time_scale = 1.0
	await boot(null, &"intro")
	app.autostart = true
	entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	entry.run()
	await until(func() -> bool: return entry.tools_ready and entry.zones_available(), 20.0)
	FirstVisit.start_with = &"motion"
	entry.call(&"_to_shelf", true)
	await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 30.0)
	Engine.time_scale = 4.0
	expect(await until(func() -> bool:
		var found := App.main.get_node_or_null(^"FirstVisit/Visit/Motion") as MotionVisit
		return found != null and found.in_motion() and App.session.trial != null, 90.0), "the dots rounds run")
	var visit := App.main.get_node_or_null(^"FirstVisit/Visit/Motion") as MotionVisit
	expect(is_equal_approx(App.reality.view.dim, MotionVisit.DIM.dim), "the room is dimmed to 60 %% for the rounds (%.2f)" % App.reality.view.dim)
	var voice := App.module(&"Voice")
	expect(voice != null and is_equal_approx(voice.fixed_elevation, MotionVisit.SUBTITLE_BELOW), "subtitles sit under the dot cloud")
	Events.report(&"motion_wrong", {})
	expect(await until(func() -> bool: return _said_line(said, MotionVisit.WRONG_LINE), 10.0), "a wrong sweep gets Onion's calm line")
	expect(not _said_line(said, "Not that way. Watch the dots and try again."), "not Wei's")
	await _finish_rounds()
	expect(await until(func() -> bool: return not visit.in_motion() and App.reality.view.dim < 0.01, 30.0), "the haze clears once after the last round")
	expect(await until(func() -> bool: return voice == null or is_nan(voice.fixed_elevation), 5.0), "subtitles back to their usual place")
	Engine.time_scale = 1.0
	FirstVisit.start_with = &""


## Scene 11: Home on the gear (after the first game) → a slow fade to Wei's room and back to the hub.
func test_home_on_the_gear_fades_to_weis_room_and_back_to_the_hub() -> void:
	var said := record(Events.said)
	var hub := await _to_hub()
	expect(await _choose(hub, &"shelf"), "the child pinches the shelf")
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.running, 20.0), "the shelf plays")
	Engine.time_scale = 4.0
	await _finish_rounds()
	expect(await until(func() -> bool: return _in_hub(hub) and hub.gear.enabled, 40.0), "back at the hub")
	Engine.time_scale = 1.0
	hub.gear.reveal()
	await frames(2)
	var home_button: HubButton = hub.gear.buttons[&"gear_home"]
	expect(home_button.visible, "Home shows on the gear")
	var home := App.module(&"Home")
	Events.selected.emit(&"right", home_button.target, Vector3.ZERO, Vector3.FORWARD)
	expect(await until(func() -> bool: return home.is_open, 10.0), "Wei's room opens")
	var veil := App.head().find_child("HomeVeil", true, false) as MeshInstance3D
	expect(veil != null, "through a fade on the head (no camera movement)")
	expect(hub.state == &"home", "the hub waits while the child is in the room")
	home.close()
	expect(await until(func() -> bool: return _in_hub(hub), 15.0), "back at the hub, as it was")
	expect(veil == null or not veil.visible, "the fade has cleared")
	expect(not _said_line(said, WorkshopController.SURPRISES), "the Home line waits for the next game's end")
