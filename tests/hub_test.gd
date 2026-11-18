extends TestCase
## The workshop hub, Scenes 7–11 (Megan's visual pass, Nov 18; `claude/VISUAL_PASS_LOG.md`): the cauldron is the
## menu (a tap opens the fog menu), the first visit's welcome, tap cue and shelf, the dots and Wei's room's door
## joining after the first game, the exit token, lifting the gear out to finish, the dots' dimmed room and
## Onion's calm lines, and the closing.

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


## The child taps the cauldron (if the menu is closed) and waits for the fog to rise.
func _open(hub: WorkshopController) -> bool:
	if not await until(func() -> bool: return hub.state == &"hub" and not hub.ring.turning and not app.get_tree().paused, 30.0):
		return false
	if not hub.ring.opened:
		Events.selected.emit(&"right", hub.cauldron_target, Vector3.ZERO, Vector3.FORWARD)
	return await until(func() -> bool: return hub.ring.opened and not hub.ring.turning, 10.0)


func _choose(hub: WorkshopController, kind: StringName) -> bool:
	if not await until(func() -> bool: return _in_hub(hub) and hub.ring.impressions.any(func(i: Impression) -> bool: return is_instance_valid(i) and i.kind == kind), 30.0):
		return false
	if not await _open(hub):
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


func test_the_first_visit_waits_for_a_tap_on_the_cauldron_then_offers_the_shelf_alone() -> void:
	var said := record(Events.said)
	var hub := await _to_hub()
	expect(hub != null, "the hub runs in the first visit")
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.WELCOME), 20.0), "Onion: \"Welcome to the workshop.\"")
	expect_eq(hub.ring.impressions.size(), 2, "the shelf, and the dots beside it")
	expect_eq(hub.ring.impressions[0].kind, &"shelf", "the shelf")
	expect(not hub.ring.impressions[0].sealed, "the shelf is open")
	expect(hub.ring.impressions[1].kind == &"dots" and hub.ring.impressions[1].sealed, "the dots wait in a closed bubble (there's more)")
	expect(hub.ring.impressions[0].bud != null, "a bud under the shelf shows its next level")
	expect(await until(func() -> bool: return hub.state == &"hub", 10.0), "the hub waits")
	expect(not hub.ring.visible and not hub.ring.opened, "the menu is closed: it waits for the child's tap")
	expect(await until(func() -> bool: return hub.cauldron_lit(), 3.0), "the cauldron glows softly (\"you can tap me\")")
	expect(App.session.trial == null, "nothing plays until the child chooses")
	var cauldron := (App.main.get_node(^"Workshop") as Workshop).cauldron()
	expect(cauldron.visible, "the cauldron stays")
	var demo := hub.find_children("*", "DemoHand", true, false)
	expect(not demo.is_empty() and await until(func() -> bool: return (demo[0] as DemoHand).visible, WorkshopController.CUE_AFTER + 4.0),
			"after ~5 s with no tap the hand shows a tap at the cauldron")
	var lines := said.size()
	Events.touched.emit(&"right", hub.cauldron_target)   # one tap (a touch counts on the cauldron)
	expect(await until(func() -> bool: return hub.ring.opened and hub.ring.visible and not hub.ring.turning, 5.0), "one tap opens the menu: the fog rises")
	expect_eq(said.size(), lines, "no new line")
	expect(await until(func() -> bool: return not hub.cauldron_lit(), 3.0), "the cauldron's glow goes while the menu is open")
	var eye := App.head().global_position
	var shelf := hub.ring.impressions[0]
	expect(shelf.global_position.distance_to(eye) < 0.5, "the shelf piece is within touch reach (%.2f m)" % shelf.global_position.distance_to(eye))
	expect(await until(func() -> bool: return (demo[0] as DemoHand).visible, WorkshopController.CUE_AFTER + 4.0),
			"after ~5 s with no choice the hand shows aim-and-pinch")
	expect(not hub.exit_token.visible, "no exit token in the hub")


func test_after_the_first_shelf_the_dots_rise_in_with_their_line_and_the_door_waits_below() -> void:
	var said := record(Events.said)
	var hub := await _to_hub()
	expect(await _choose(hub, &"shelf"), "the child pinches the shelf")
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.running, 20.0), "the shelf plays")
	expect(hub.exit_token.visible and hub.exit_token.open, "the exit token stands by the cauldron during the game")
	expect(not hub.ring.visible, "the menu drew into the cauldron for the game")
	expect(not hub.carry.enabled, "the gear can't be lifted during a game")
	Engine.time_scale = 4.0
	await _finish_rounds()
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.MORE), 40.0), "Onion: \"There are more waiting.\"")
	expect(await until(func() -> bool: return _in_hub(hub), 20.0), "back at the hub")
	Engine.time_scale = 1.0
	var kinds := hub.ring.impressions.map(func(i: Impression) -> StringName: return i.kind)
	expect(hub.ring.opened and hub.ring.visible, "the menu rose again by itself")
	expect(kinds.has(&"dots"), "the dots are in the menu (%s)" % [kinds])
	expect(hub.ring.impressions.all(func(i: Impression) -> bool: return not i.sealed), "the dots' bubble opened")
	expect(not kinds.has(&"turn_to_fit"), "Turn to fit only when it can run")
	expect(hub.ring.door != null and hub.ring.door.visible, "Wei's room's door waits below the tasks now")
	expect(hub.ring.door.global_position.y < hub.ring.impressions[0].global_position.y - 0.05, "below the tasks")
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


func test_lifting_the_gear_out_ends_the_visit_and_setting_it_back_does_nothing() -> void:
	var said := record(Events.said)
	var hub := await _to_hub()
	expect(await _open(hub), "the menu is open")
	expect(hub.carry.enabled, "the gear can be lifted out in the hub")
	hub.carry.picked_up.emit()   # the child lifts it
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.ALL_DONE), 10.0), "Onion: \"All done for today?\"")
	hub.carry.released.emit(true)   # set back in
	await frames(10)
	expect(hub.state == &"hub" and hub.ring.visible, "set back in: nothing happens")
	Engine.time_scale = 4.0
	hub.carry.released.emit(false)   # let go elsewhere
	expect(await until(func() -> bool: return not hub.ring.visible, 15.0), "the menu sinks into the cauldron first")
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


## Scene 11: the door in the fog menu (after the first game) → a slow fade to Wei's room and back to the hub.
func test_the_door_fades_to_weis_room_and_back_to_the_hub() -> void:
	var said := record(Events.said)
	var hub := await _to_hub()
	expect(await _choose(hub, &"shelf"), "the child pinches the shelf")
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.running, 20.0), "the shelf plays")
	Engine.time_scale = 4.0
	await _finish_rounds()
	expect(await until(func() -> bool: return _in_hub(hub) and hub.ring.door != null, 40.0), "back at the hub")
	Engine.time_scale = 1.0
	expect(await _open(hub), "the menu is open")
	var home := App.module(&"Home")
	Events.selected.emit(&"right", hub.ring.door.target, Vector3.ZERO, Vector3.FORWARD)
	expect(await until(func() -> bool: return home.is_open, 10.0), "Wei's room opens")
	var veil := App.head().find_child("HomeVeil", true, false) as MeshInstance3D
	expect(veil != null, "through a fade on the head (no camera movement)")
	expect(hub.state == &"home", "the hub waits while the child is in the room")
	expect(await until(func() -> bool: return not hub.ring.visible, 5.0), "the menu isn't over Wei's room")
	expect(not _said_line(said, "Point and pinch to keep playing, choose a game, or visit your room."), "no menu line: straight into the room")
	home.close()
	expect(await until(func() -> bool: return _in_hub(hub) and hub.ring.opened, 15.0), "back at the hub, the menu up again")
	expect(veil == null or not veil.visible, "the fade has cleared")
	expect(not _said_line(said, WorkshopController.SURPRISES), "the Home line waits for the next game's end")


## The socket sits at the table's front right (Megan, Nov 18; was right of middle, Nov 17 late). It fades under Wei's
## bench during the shelf (the board can reach it there too).
func test_the_socket_sits_front_right_and_hides_under_the_bench_during_the_shelf() -> void:
	var hub := await _to_hub()
	var workshop := App.main.get_node(^"Workshop") as Workshop
	var socket := workshop.get("_mechanism") as Node3D
	var eye := App.head().global_position
	var to := Vector3(socket.global_position.x - eye.x, 0.0, socket.global_position.z - eye.z)
	var ahead := -App.head().global_basis.z
	ahead = Vector3(ahead.x, 0.0, ahead.z).normalized()
	var angle := rad_to_deg(ahead.signed_angle_to(to.normalized(), Vector3.DOWN))
	expect(angle > 20.0, "the socket is to the child's right, out of the middle (%d degrees)" % roundi(angle))
	expect(to.length() < 0.5, "and near the table's near edge (%.2f m)" % to.length())
	expect(await _choose(hub, &"shelf"), "the child pinches the shelf")
	expect(await until(func() -> bool: return hub.state == &"game" and not socket.visible, 10.0), "the socket fades under the bench during the shelf")
	Engine.time_scale = 4.0
	await _finish_rounds()
	expect(await until(func() -> bool: return _in_hub(hub), 40.0), "back at the hub")
	Engine.time_scale = 1.0
	expect(socket.visible, "the socket is back")


## Issue 2 (Megan, Nov 18): the house introduces itself the first time a hand comes to it; issue 5: a label
## never plays on top of a line, nor in the hub's first moments.
func test_the_house_says_its_teaser_on_the_first_hover_and_labels_wait_for_quiet() -> void:
	var said := record(Events.said)
	var hub := await _to_hub()
	expect(await _choose(hub, &"shelf"), "the shelf is chosen")
	Engine.time_scale = 3.0
	while App.session.running:
		if App.session.trial != null and App.session.trial.is_running():
			App.session.trial.finish(true)
		await frames(1)
	Engine.time_scale = 1.0
	expect(await until(func() -> bool: return _in_hub(hub) and hub.ring.door != null and hub.ring.opened, 40.0), "back at the hub with the house")
	expect(not _said_line(said, WorkshopController.SURPRISES), "the house came silently")
	await wait(WorkshopController.LABEL_SETTLE + WorkshopController.LABEL_QUIET + 0.5)
	var tries := 0
	while not _said_line(said, WorkshopController.SURPRISES) and tries < 12:   # a hand comes to the house (again)
		hub.ring.hovered.emit(hub.ring.door)
		await wait(0.5)
		tries += 1
	expect(_said_line(said, WorkshopController.SURPRISES), "a hand at the house: its teaser")
	var shelf_name := Impression.title_for(&"shelf")
	var named := said.filter(func(args: Array) -> bool: return args[0] == shelf_name).size()
	hub.ring.hovered.emit(hub.ring.impressions[0])   # while the teaser is still being said
	await frames(2)
	expect_eq(said.filter(func(args: Array) -> bool: return args[0] == shelf_name).size(), named, "no label while Onion is still speaking")
