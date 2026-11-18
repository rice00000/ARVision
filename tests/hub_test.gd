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
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.PARTICULAR), 20.0), "\"It's a bit particular, this place…\" (story chat, Nov 18)")
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.READY), 20.0), "the cauldron clicks ready: \"Well, this one's ready for us!\"")
	expect_eq(hub.ring.impressions.size(), 4, "the shelf, then the dots, the butterflies and the cup, locked")
	expect_eq(hub.ring.impressions[0].kind, &"shelf", "the shelf")
	expect(not hub.ring.impressions[0].sealed, "the shelf is open")
	expect(hub.ring.impressions[1].kind == &"dots" and hub.ring.impressions[1].sealed, "the dots wait in a closed bubble (there's more)")
	expect(hub.ring.impressions.all(func(i: Impression) -> bool: return i.bud == null), "no buds in the menu (Megan, Nov 18)")
	expect(await until(func() -> bool: return hub.state == &"hub", 10.0), "the hub waits")
	# Megan, Nov 18: on "Well, this one's ready for us!" the menu opens by itself, Find Objects waiting in front.
	expect(await until(func() -> bool: return hub.ring.opened and hub.ring.visible and not hub.ring.turning, 10.0), "the menu opened by itself with the line")
	expect(App.session.trial == null, "nothing plays until the child chooses")
	var cauldron := (App.main.get_node(^"Workshop") as Workshop).cauldron()
	expect(cauldron.visible, "the cauldron stays")
	expect(hub.menu_sign.is_visible_in_tree() and hub.menu_sign.get_parent() == cauldron, "the ☰ is engraved on the cauldron itself")
	var demo := hub.find_children("*", "DemoHand", true, false)
	expect(await until(func() -> bool: return not hub.cauldron_lit(), 3.0), "the cauldron's glow goes while the menu is open")
	var eye := App.head().global_position
	var shelf := hub.ring.impressions[0]
	expect(shelf.global_position.distance_to(eye) < 0.62, "the shelf bubble is within easy ray-and-pinch reach (%.2f m; bubbles are pinched, not touched)" % shelf.global_position.distance_to(eye))
	expect(hub.ring.leader() == shelf, "the waiting glow is on the open game, not a locked one")
	expect(await until(func() -> bool: return (demo[0] as DemoHand).visible, WorkshopController.CUE_AFTER + 4.0),
			"after ~5 s with no choice the hand shows aim-and-pinch")
	expect(hub.stop_bubble == null, "no ✕ bubble in the hub")


func test_after_the_first_shelf_the_dots_rise_in_with_their_line_and_the_door_waits_below() -> void:
	var said := record(Events.said)
	var hub := await _to_hub()
	expect(await _choose(hub, &"shelf"), "the child pinches the shelf")
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.running, 20.0), "the shelf plays")
	expect(hub.menu_sign.is_visible_in_tree(), "the ☰ engraved on the cauldron stays during the game")
	expect(hub.stop_bubble == null, "no ✕ until the child taps the cauldron")
	expect(not hub.ring.visible, "the menu drew into the cauldron for the game")
	expect(not hub.carry.enabled, "the gear can't be lifted during a game")
	Engine.time_scale = 4.0
	await _finish_rounds()
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.DOTS_WOKE), 40.0), "Onion: \"Oh! Looks like we've woken another one!\"")
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.DOTS_AWAKE), 10.0), "\"The Dots are awake. Shall we see what they're up to?\"")
	expect(await until(func() -> bool: return _in_hub(hub), 20.0), "back at the hub")
	Engine.time_scale = 1.0
	var kinds := hub.ring.impressions.map(func(i: Impression) -> StringName: return i.kind)
	expect(hub.ring.opened and hub.ring.visible, "the menu rose again by itself")
	expect(kinds.has(&"dots"), "the dots are in the menu (%s)" % [kinds])
	expect(not hub.ring.impressions[1].sealed, "the dots' bubble opened")
	var cup := hub.ring.impressions.filter(func(i: Impression) -> bool: return i.kind == &"turn_to_fit")
	expect(cup.size() == 1 and cup[0].sealed, "Turn to fit waits locked, the last game")
	expect(hub.ring.door != null and hub.ring.door.visible, "the Virtual Workshop house waits below the tasks now")
	expect(hub.ring.door.global_position.y < hub.ring.impressions[0].global_position.y - 0.05, "below the tasks")
	var row := hub.ring.places.map(func(p: Impression) -> StringName: return p.kind)
	expect_eq(row, [&"help", &"eye", &"house", &"finish"], "the places row: ? · eye · house · ✕")
	var eye := App.head().global_position
	var right := Vector3(eye.x - hub.ring.global_position.x, 0, eye.z - hub.ring.global_position.z).normalized().cross(Vector3.UP) * -1.0
	expect(hub.ring.place_of(&"help").global_position.dot(right) < hub.ring.place_of(&"finish").global_position.dot(right), "? on the left, ✕ on the right")
	expect(not _said_line(said, "Thank you for helping."), "cut")
	# The earning moment (DESIGN_STONES_AND_LEVELS §2, §4): the first shelf's 3 stones fly into the house's badge,
	# then, the first time ever, Onion says what they're for.
	expect(hub.badge != null, "the stones badge sits on the house")
	var stones: int = App.module(&"Inventory").count(&"magic_stone")
	expect(stones >= 3, "the first shelf earned 3 stones (%d)" % stones)
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.STONES_YOURS), 20.0), "Onion: \"These stones are yours.\"")
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.STONES_SPEND), 10.0), "\"You can spend them in the Virtual Workshop.\"")
	expect_eq(hub.badge.count, stones, "the badge's count ends at the inventory's count")
	expect(App.main.get_node(^"Magic").find_child("LevelCelebration", true, false) == null if App.main.has_node(^"Magic") else true, "no trophy in the workshop")
	expect_eq(hub.ring.impressions[0].rows, 2, "the shelf grew a row (Shadow Match done)")


func test_a_cauldron_tap_in_a_game_pauses_it_and_its_x_ends_it_with_a_pinch_never_a_touch() -> void:
	var said := record(Events.said)
	var hub := await _to_hub()
	expect(await _choose(hub, &"shelf"), "the child pinches the shelf")
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.running and App.session.trial != null, 20.0), "the shelf plays")
	Events.touched.emit(&"right", hub.cauldron_target)   # a hand passing over the cauldron
	await wait(0.5)
	expect(hub.stop_bubble == null and not app.get_tree().paused, "a touch or hover over the cauldron never pauses a game")
	Events.selected.emit(&"right", hub.cauldron_target, Vector3.ZERO, Vector3.FORWARD)   # a pinch on the cauldron
	expect(await until(func() -> bool: return hub.stop_bubble != null, 5.0), "one ✕ bubble rises")
	expect(app.get_tree().paused, "the game pauses")
	await wait(0.7)
	Events.touched.emit(&"right", hub.stop_bubble.target)   # a hand passing through it
	await frames(3)
	expect(hub.stop_bubble != null and App.session.running, "a touch (a sweep through it) never counts")
	Events.selected.emit(&"right", hub.stop_bubble.target, Vector3.ZERO, Vector3.FORWARD)
	expect(await until(func() -> bool: return not App.session.running, 10.0), "a pinch ends the game")
	expect(not app.get_tree().paused, "the pause is over")
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.LEFT_EARLY), 15.0), "Onion: \"We can come back to these.\"")
	expect(await until(func() -> bool: return _in_hub(hub), 20.0), "back at the hub")
	expect(not _said_line(said, "There. Everything's found its place."), "no claim of success")


func test_the_paused_game_carries_on_after_six_seconds_or_a_second_tap() -> void:
	var hub := await _to_hub()
	expect(await _choose(hub, &"shelf"), "the shelf is chosen")
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.running and App.session.trial != null, 20.0), "the shelf plays")
	Events.selected.emit(&"right", hub.cauldron_target, Vector3.ZERO, Vector3.FORWARD)
	expect(await until(func() -> bool: return hub.stop_bubble != null, 5.0), "paused")
	await wait(WorkshopController.STOP_WAIT + 1.0)
	expect(hub.stop_bubble == null and not app.get_tree().paused, "after ~6 s the bubble sinks and the game goes on")
	expect(App.session.running and hub.state == &"game", "the same game, still running")
	Events.selected.emit(&"right", hub.cauldron_target, Vector3.ZERO, Vector3.FORWARD)
	expect(await until(func() -> bool: return hub.stop_bubble != null, 5.0), "paused again")
	await wait(0.3)
	Events.selected.emit(&"right", hub.cauldron_target, Vector3.ZERO, Vector3.FORWARD)
	expect(await until(func() -> bool: return hub.stop_bubble == null and not app.get_tree().paused, 3.0), "a second tap: it carries on")
	expect(App.session.running, "still running")


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


## Megan, Nov 18: after the goodbye a tap on the cauldron starts again: Onion and the socket come back, the gear
## pops out, the child sets it in; no hello, no lines; then the menu opens.
func test_after_the_goodbye_a_cauldron_tap_restarts_with_the_gear_to_set_back() -> void:
	var said := record(Events.said)
	var reported := record(Events.reported)
	var hub := await _to_hub()
	expect(await _open(hub), "the menu is open")
	Engine.time_scale = 4.0
	hub.carry.released.emit(false)   # the gear lifted out and let go: the visit ends
	expect(await until(func() -> bool: return hub.state == &"closed", 90.0), "the closing plays")
	Engine.time_scale = 1.0
	var workshop := App.main.get_node(^"Workshop") as Workshop
	var lines := said.size()
	Events.selected.emit(&"right", hub.cauldron_target, Vector3.ZERO, Vector3.FORWARD)   # a tap on the cauldron
	expect(await until(func() -> bool: return hub.state == &"restarting", 5.0), "it starts again")
	expect(reported.any(func(r: Array) -> bool: return r[0] == WorkshopController.RESTARTED), "logged")
	expect(await until(func() -> bool: return hub.carry.enabled and workshop.gear_node().visible, 10.0), "the gear popped out, ready to pick up")
	expect((workshop.get("_mechanism") as Node3D).visible, "the socket is back")
	expect(workshop.onion.visible, "Onion is back")
	expect(not App.results_after_closing, "Staff tools won't jump to Results")
	hub.carry.simulate(0.2)   # the child sets it back in
	expect(await until(func() -> bool: return hub.state == &"hub" and hub.ring.opened, 20.0), "the gear in: the menu opens")
	expect_eq(said.size(), lines, "no hello and no lines")
	expect(not _said_line(said.slice(lines), WorkshopController.ALL_DONE), "picking the gear up was not \"All done for today?\"")


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
	expect(await until(func() -> bool: return _said_line(said, "So many little dots. It all looks a bit jumbled, doesn't it?"), 60.0), "Onion's intro to the dots")
	var arrived := App.main.find_children("*", "MotionCloud", true, false)
	expect(not arrived.is_empty(), "the dots come in as Onion speaks (Megan, Nov 18)")
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


## The house says its name and the child's stones ("Three stones"; design chat, Nov 18: the teaser line is cut);
## issue 5: a label never plays on top of a line, nor in the hub's first moments.
func test_the_house_says_its_name_and_the_stones_and_labels_wait_for_quiet() -> void:
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
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.STONES_SPEND), 30.0), "the stones are introduced first")
	await wait(WorkshopController.LABEL_SETTLE + WorkshopController.LABEL_QUIET + 0.5)
	var count := StonesBadge.spoken(App.module(&"Inventory").count(&"magic_stone"))
	var tries := 0
	while not _said_line(said, count) and tries < 12:   # a hand comes to the house (again)
		hub.ring.hovered.emit(hub.ring.door)
		await wait(1.0)
		tries += 1
	expect(_said_line(said, "Virtual Workshop"), "a hand at the house: its name")
	expect(_said_line(said, count), "then the count: \"%s\"" % count)
	hub.ring.hovered.emit(hub.ring.door)
	await frames(2)
	var shelf_name := Impression.title_for(&"shelf")
	var named := said.filter(func(args: Array) -> bool: return args[0] == shelf_name).size()
	hub.ring.hovered.emit(hub.ring.impressions[0])   # while the teaser is still being said
	await frames(2)
	expect_eq(said.filter(func(args: Array) -> bool: return args[0] == shelf_name).size(), named, "no label while Onion is still speaking")


## Megan, Nov 18: a bubble is chosen by a click or pinch only, never by a touch or a hand passing by.
func test_a_touch_on_a_bubble_never_chooses_it() -> void:
	var hub := await _to_hub()
	await until(func() -> bool: return hub.state == &"hub" and not hub.ring.turning and not app.get_tree().paused, 30.0)
	Events.selected.emit(&"right", hub.cauldron_target, Vector3.ZERO, Vector3.FORWARD)
	expect(await until(func() -> bool: return hub.ring.opened and not hub.ring.turning, 10.0), "the menu is open")
	var shelf := hub.ring.impressions[0]
	Events.touched.emit(&"right", shelf.target)
	await wait(1.0)
	expect_eq(hub.state, &"hub", "a touch didn't choose it")
	Events.selected.emit(&"right", shelf.target, Vector3.ZERO, Vector3.FORWARD)
	expect(await until(func() -> bool: return hub.state == &"game", 10.0), "a pinch does")


## The desktop's dev skip (Megan, Nov 18): opens the menu, wins a game's rounds, brings the child back from Wei's room.
func test_the_dev_skip_moves_through_the_hub() -> void:
	var hub := await _to_hub()
	var skip := DevSkip.new()
	app.add_child(skip)
	await until(func() -> bool: return hub.state == &"hub" and not hub.ring.turning and not app.get_tree().paused, 30.0)
	skip.skip()
	expect(await until(func() -> bool: return hub.ring.opened, 10.0), "skip opens the menu")
	expect(await _choose(hub, &"shelf"), "the shelf is chosen")
	await until(func() -> bool: return hub.state == &"game" and App.session.running, 30.0)
	skip.skip()
	expect(await until(func() -> bool: return hub.state == &"hub", 90.0), "skip wins the rounds: back at the hub")
	Engine.time_scale = 1.0



## The places row's ✕ (design chat, Nov 18): Onion asks first; a second ✕ finishes, a pause or a tap doesn't.
func test_the_finish_x_asks_first_and_a_second_x_closes() -> void:
	var said := record(Events.said)
	var hub := await _to_hub()
	expect(await _choose(hub, &"shelf"), "the shelf is chosen")
	await until(func() -> bool: return hub.state == &"game" and App.session.running, 20.0)
	await _finish_rounds()
	expect(await until(func() -> bool: return _in_hub(hub) and hub.ring.place_of(&"finish") != null and hub.ring.opened, 40.0), "the ✕ is in the places row")
	await wait(1.0)
	Events.selected.emit(&"right", hub.ring.place_of(&"finish").target, Vector3.ZERO, Vector3.FORWARD)
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.ALL_DONE), 10.0), "Onion: \"All done for today?\"")
	expect(await until(func() -> bool: return hub.stop_bubble != null, 10.0), "one ✕ over the brew")
	Events.selected.emit(&"right", hub.stop_bubble.target, Vector3.ZERO, Vector3.FORWARD)
	await frames(3)
	expect(hub.state != &"closing", "a press in its first half second is ignored")
	await wait(WorkshopController.STOP_WAIT + 1.0)
	expect(await until(func() -> bool: return _in_hub(hub) and hub.ring.opened, 10.0), "no choice: the menu rises again")
	Events.selected.emit(&"right", hub.ring.place_of(&"finish").target, Vector3.ZERO, Vector3.FORWARD)
	expect(await until(func() -> bool: return hub.stop_bubble != null, 10.0), "asked again")
	await wait(0.7)
	Engine.time_scale = 3.0
	Events.selected.emit(&"right", hub.stop_bubble.target, Vector3.ZERO, Vector3.FORWARD)
	expect(await until(func() -> bool: return hub.state == &"closed", 90.0), "the second ✕: the closing")
	Engine.time_scale = 1.0


## The ? (design chat, Nov 18): four steps in order, the rest dimmed; a real action stops it.
func test_the_help_tour_plays_four_steps_and_a_real_action_stops_it() -> void:
	var said := record(Events.said)
	var hub := await _to_hub()
	expect(await _choose(hub, &"shelf"), "the shelf is chosen")
	await until(func() -> bool: return hub.state == &"game" and App.session.running, 20.0)
	await _finish_rounds()
	expect(await until(func() -> bool: return _in_hub(hub) and hub.ring.place_of(&"help") != null and hub.ring.opened, 40.0), "the ? is in the places row")
	await wait(2.0)
	Events.selected.emit(&"right", hub.ring.place_of(&"help").target, Vector3.ZERO, Vector3.FORWARD)
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.TOUR_OPENING), 10.0), "\"Need a little reminder? I'll show you.\"")
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.TOUR_LINES[0]), 10.0), "step 1: the cauldron")
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.TOUR_LINES[1]), 10.0), "step 2: a bubble")
	expect(hub.ring.door._body.find_children("*", "GeometryInstance3D", true, false).any(func(m: GeometryInstance3D) -> bool: return m.transparency > 0.2), "the others dim a little")
	expect(await until(func() -> bool: return _said_line(said, WorkshopController.TOUR_LINES[3]), 20.0), "step 4: the gear")
	expect(await until(func() -> bool: return not hub._touring, 10.0), "then it ends")
	expect(hub.ring.door._body.find_children("*", "GeometryInstance3D", true, false).all(func(m: GeometryInstance3D) -> bool: return m.transparency < 0.01), "nothing dimmed after")
	Events.selected.emit(&"right", hub.ring.place_of(&"help").target, Vector3.ZERO, Vector3.FORWARD)
	expect(await until(func() -> bool: return hub._touring, 5.0), "again")
	hub.carry.picked_up.emit()   # a real action
	await frames(2)
	expect(not hub._touring, "a real action stops it at once")
	hub.carry.released.emit(true)


## Megan, Nov 18: Wei's butterflies show locked from the first visit and open after the dots; they play his level.
func test_the_butterflies_wait_locked_then_open_after_the_dots_and_play() -> void:
	var hub := await _to_hub()
	await until(func() -> bool: return hub.state == &"hub" and not hub.ring.turning, 30.0)
	var kinds := hub.ring.impressions.map(func(i: Impression) -> StringName: return i.kind)
	expect_eq(kinds, [&"shelf", &"dots", &"butterflies", &"turn_to_fit"], "the games in order, the cup last")
	var butterflies := hub.ring.impressions[2]
	expect(butterflies.sealed and butterflies.find_child("lock", true, false).visible, "the butterflies wait locked")
	for kind: StringName in [&"shelf", &"dots"]:
		expect(await _choose(hub, kind), "%s is chosen" % kind)
		await until(func() -> bool: return hub.state == &"game" and App.session.running, 60.0)
		await _finish_rounds()
		expect(await until(func() -> bool: return _in_hub(hub) and hub.ring.opened, 90.0), "back at the hub after %s" % kind)
		await wait(2.0)
		if kind == &"shelf":
			expect(butterflies.sealed, "still locked after the first game (the dots open first)")
	expect(not butterflies.sealed, "the butterflies opened after the dots")
	expect(await _choose(hub, &"butterflies"), "the butterflies are chosen")
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.running, 30.0), "Wei's butterflies play")
	await _finish_rounds()
	expect(await until(func() -> bool: return _in_hub(hub), 90.0), "and back to the hub")


func test_the_menu_opens_facing_the_child_and_follows_them_calmly_round_the_cauldron() -> void:
	var hub := await _to_hub()
	expect(await _open(hub), "the menu opens")
	var ring := hub.ring
	var facing := func() -> float:
		var eye := App.head().global_position
		var flat := Vector3(eye.x - ring.global_position.x, 0.0, eye.z - ring.global_position.z).normalized()
		return rad_to_deg(ring._toward.angle_to(flat))
	expect(facing.call() < 5.0, "it opens facing the child (%.0f°)" % facing.call())
	var toward: Vector3 = ring._toward
	App.rig.global_position += App.rig.global_basis.x * 0.1   # a small sway: the menu stays still
	await wait(1.2)
	expect(ring._toward.is_equal_approx(toward), "a small sway moves nothing")
	var mouth := ring.mouth
	var from := App.rig.global_position
	var round := Vector3(from.x - mouth.x, 0.0, from.z - mouth.z).rotated(Vector3.UP, deg_to_rad(70.0))
	App.rig.global_position = Vector3(mouth.x + round.x, from.y, mouth.z + round.z)   # the child walks round
	expect(await until(func() -> bool: return ring._follow != null and ring._follow.is_running(), 2.0), "the menu glides after them")
	await wait(ImpressionRing.FOLLOW_SECONDS + 0.3)
	expect(facing.call() < 5.0, "it faces them again (%.0f°)" % facing.call())
	var front := ring.impressions[0]
	var to_eye := (App.head().global_position - front.global_position).normalized()
	expect(front.global_basis.z.normalized().dot(to_eye) > 0.95, "the bubbles turn to the child's eyes, never edge-on")
