extends TestCase
## The hub's stones, games and levels, and the eye (design chat, Nov 18, `claude/DESIGN_STONES_AND_LEVELS.md`
## and the 9:54 update of `claude/DESIGN_EXIT_AND_HELP.md`).

const SHELF := preload("res://content/tasks/tidy_shelf.tres")

var entry: Entry


## Into the hub. [param prep] runs after boot, before the opening hands over (to set saved progress).
func _to_hub(prep := Callable(), first := &"") -> WorkshopController:
	Engine.time_scale = 1.0
	await boot(null, &"intro")
	app.autostart = true
	entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	if prep.is_valid():
		prep.call()
	entry.run()
	await until(func() -> bool: return entry.tools_ready and entry.zones_available(), 20.0)
	FirstVisit.start_with = first
	entry.call(&"_to_shelf", false)
	await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 30.0)
	await until(func() -> bool: return app.find_child("WorkshopController", true, false) != null, 10.0)
	return app.find_child("WorkshopController", true, false) as WorkshopController


func _played(ids: Array[StringName]) -> void:
	var memory := HubMemory.get_or_make()
	for id in ids:
		memory.played.append(id)


func _done(levels: Array[StringName]) -> void:
	App.main.progress.done[&"tidy_shelf"] = levels.duplicate()


func _open(hub: WorkshopController) -> bool:
	if not await until(func() -> bool: return hub.state == &"hub" and not hub.ring.turning and not app.get_tree().paused, 30.0):
		return false
	if not hub.ring.opened:
		Events.selected.emit(&"right", hub.cauldron_target, Vector3.ZERO, Vector3.FORWARD)
	return await until(func() -> bool: return hub.ring.opened and not hub.ring.turning, 10.0)


func _pinch(target: Target) -> void:
	Events.selected.emit(&"right", target, Vector3.ZERO, Vector3.FORWARD)


func _piece(hub: WorkshopController, kind: StringName) -> Impression:
	for piece in hub.ring.impressions + hub.ring.places:
		if is_instance_valid(piece) and piece.kind == kind:
			return piece
	return null


func _finish_rounds() -> void:
	while App.session.running:
		if App.session.trial != null and App.session.trial.is_running():
			App.session.trial.finish(false)   # every round wrong: stones are for effort, never accuracy
		await frames(2)


func _stones() -> int:
	return App.module(&"Inventory").count(&"magic_stone")


func test_the_dots_with_nothing_right_still_earn_three_stones_and_no_trophy() -> void:
	var hub := await _to_hub(func() -> void: _played([&"shelf"]))
	expect(await _open(hub), "the menu opens")
	var dots := _piece(hub, &"dots")
	expect(dots != null and not dots.sealed, "the dots are open (the shelf was played on an earlier visit)")
	expect(hub.ring.door != null and hub.badge != null, "a later visit: the places row and the badge from the start")
	_pinch(dots.target)
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.running, 60.0), "the dots play")
	Engine.time_scale = 4.0
	await _finish_rounds()
	expect(await until(func() -> bool: return hub.state == &"hub", 90.0), "back at the hub")
	Engine.time_scale = 1.0
	expect_eq(_stones(), 3, "3 stones for the first go, whatever the score")
	expect(App.main.progress.is_done(MotionVisit.WALL_TASK, MotionVisit.WALL_TASK.level_by_id(&"steady_flow")), "Steady Flow is marked done")
	expect(await until(func() -> bool: return hub.badge.count == 3 and not hub.badge.flying(), 10.0), "they fly into the badge: it shows 3")
	var magic := App.module(&"Magic")
	expect(magic == null or magic.find_child("LevelCelebration", true, false) == null, "no trophy in the workshop")


func test_leaving_a_game_by_the_x_earns_one_stone_and_never_marks_it_done() -> void:
	var hub := await _to_hub()
	expect(await _open(hub), "the menu opens")
	_pinch(_piece(hub, &"shelf").target)
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.running and App.session.trial != null, 30.0), "the shelf plays")
	_pinch(hub.cauldron_target)
	expect(await until(func() -> bool: return hub.stop_bubble != null, 5.0), "paused: the ✕ rises")
	expect(hub.eye_bubble != null, "with the eye beside it during the shelf (eye · ✕)")
	await wait(0.7)
	_pinch(hub.stop_bubble.target)
	expect(await until(func() -> bool: return hub.state == &"hub", 40.0), "back at the hub")
	expect_eq(_stones(), 1, "one stone for trying")
	expect(not App.main.progress.is_done(SHELF, SHELF.level_by_id(&"shadow")), "Shadow Match is not marked done")


func test_the_dots_pause_bubble_has_no_eye() -> void:
	var hub := await _to_hub(func() -> void: _played([&"shelf"]))
	expect(await _open(hub), "the menu opens")
	_pinch(_piece(hub, &"dots").target)
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.running and App.session.trial != null, 60.0), "the dots play")
	_pinch(hub.cauldron_target)
	expect(await until(func() -> bool: return hub.stop_bubble != null, 5.0), "paused: the ✕ rises")
	expect(hub.eye_bubble == null, "the ✕ alone: the dots' dim must stay the same every round")
	expect(is_equal_approx(App.reality.view.dim, MotionVisit.DIM.dim), "the room stays dimmed")
	await wait(0.6)
	_pinch(hub.cauldron_target)   # carry on (never leave the world paused)
	expect(await until(func() -> bool: return not app.get_tree().paused, 5.0), "a second tap: it carries on")


func test_nothing_done_one_press_starts_the_first_level() -> void:
	var hub := await _to_hub()
	expect(await _open(hub), "the menu opens")
	_pinch(_piece(hub, &"shelf").target)
	expect(await until(func() -> bool: return hub.state == &"game" and hub.current.played_level != null, 20.0), "one press: the game starts")
	expect(hub.row == null, "no level row")
	expect_eq(hub.current.played_level.id, &"shadow", "Shadow Match, the first")


func test_with_levels_done_a_press_opens_the_games_own_row_and_nothing_starts_by_itself() -> void:
	var hub := await _to_hub(func() -> void:
		_played([&"shelf"])
		_done([&"shadow", &"size"]))
	expect_eq(_piece(hub, &"shelf").rows, 3, "the shelf has 3 rows (2 levels done)")
	expect(await _open(hub), "the menu opens")
	_pinch(_piece(hub, &"shelf").target)
	expect(await until(func() -> bool: return hub.row != null and hub.row.opened, 10.0), "the shelf's own row rises")
	expect(not hub.ring.visible, "the games and the places sank")
	var titles := hub.row.impressions.map(func(p: Impression) -> String: return p.title)
	expect_eq(titles, ["Shadow Match", "Size Match", "Clutter Search"], "the finished levels and the next one, in order")
	expect_eq(hub.row.centre, 2, "the next one (Clutter Search) sits straight ahead")
	expect(hub.row.leader().level.id == &"clutter", "and waits glowing")
	var big := hub.row.impressions[2].scale.x
	expect(big > hub.row.impressions[1].scale.x, "the biggest")
	expect(hub.row.impressions[1].scale.x >= big * 0.6, "the others at least 60 %")
	await wait(2.0)
	expect(hub.state == &"hub" and App.session.trial == null, "nothing starts by itself")
	_pinch(hub.cauldron_target)
	expect(await until(func() -> bool: return hub.row == null and hub.ring.opened, 10.0), "a tap on the cauldron: back to the menu")
	_pinch(_piece(hub, &"shelf").target)
	expect(await until(func() -> bool: return hub.row != null and hub.row.opened, 10.0), "the row again")
	await wait(WorkshopController.ROW_WAIT + 1.5)
	expect(hub.row == null and hub.ring.opened and hub.state == &"hub", "8 s with no press: back to the menu, nothing started")
	_pinch(_piece(hub, &"shelf").target)
	expect(await until(func() -> bool: return hub.row != null and hub.row.opened, 10.0), "the row again")
	_pinch(hub.row.impressions[1].target)
	expect(await until(func() -> bool: return hub.state == &"game" and hub.current.played_level != null, 20.0), "a finished level, pressed")
	expect_eq(hub.current.played_level.id, &"size", "plays again: Size Match")


func test_the_next_level_is_saved_per_child() -> void:
	var hub := await _to_hub(func() -> void: _done([&"shadow", &"size"]))
	var shelf := hub.activities.filter(func(a: Summonable) -> bool: return a.id() == &"shelf")[0] as Summonable
	expect_eq(shelf.recommended().id, &"clutter", "after Size Match: Clutter Search")
	Save.write()
	App.main.progress.done = {}
	Save.reload()
	expect_eq(shelf.recommended().id, &"clutter", "after a reload of the save, still Clutter Search")
	_done([&"shadow", &"size", &"clutter", &"color", &"similar_shadows"])
	expect_eq(shelf.recommended().id, &"similar_shadows", "all done: the last one")


func test_the_shelf_grows_a_row_per_level_up_to_four() -> void:
	for done in 5:
		var piece := Impression.make(&"shelf")
		piece.set_rows(mini(1 + done, 4))
		expect_eq(piece.rows, mini(1 + done, 4), "%d done: %d rows" % [done, mini(1 + done, 4)])
		piece.free()


func test_the_eye_shows_the_looks_and_a_pinch_changes_the_real_room_and_is_saved() -> void:
	var reported := record(Events.reported)
	var hub := await _to_hub(func() -> void: _played([&"shelf"]))
	expect(await _open(hub), "the menu opens")
	var row := hub.ring.places.map(func(p: Impression) -> StringName: return p.kind)
	expect_eq(row, [&"help", &"eye", &"house", &"finish"], "? · eye · house · ✕")
	var eye_at := App.head().global_position
	var gaps := hub.ring.places.map(func(p: Impression) -> float: return p.bubble.global_position.distance_to(eye_at))
	expect(gaps.max() - gaps.min() < 0.04, "the row curves: every place about the same distance from the eyes (%s)" % [gaps.map(func(g: float) -> String: return "%.2f" % g)])
	_pinch(hub.ring.place_of(&"eye").target)
	expect(await until(func() -> bool: return hub.row != null and hub.row_kind == &"looks" and hub.row.opened, 10.0), "the looks rise")
	var looks := hub.row.impressions.map(func(p: Impression) -> StringName: return p.look)
	expect_eq(looks, [&"normal", &"high_contrast", &"edges", &"black_white"], "Normal · High contrast · Edges · Black and white")
	expect(hub.row.impressions[0].is_picked(), "the current look (Normal) is ringed")
	var edges: Impression = hub.row.impressions[2]
	_pinch(edges.target)
	await frames(3)
	expect_eq(App.reality.view.title, "Edges", "the real room changes at once")
	expect(edges.is_picked() and not hub.row.impressions[0].is_picked(), "the ring moves to it")
	expect(hub.row != null, "the looks stay up to try another")
	expect(reported.any(func(r: Array) -> bool: return r[0] == &"view_chosen" and r[1].get("look", "") == "edges"), "view_chosen is logged")
	_pinch(hub.cauldron_target)
	expect(await until(func() -> bool: return hub.row == null and hub.ring.opened, 10.0), "a tap on the cauldron: the menu comes back")
	expect_eq(App.reality.view.title, "Edges", "the last look stays")
	expect_eq(App.session.base_view.title, "Edges", "it is the base view from now on")
	Save.write()
	HubMemory.get_or_make().look = &"normal"
	Save.reload()
	expect_eq(HubMemory.get_or_make().look, &"edges", "saved with the child's progress")


func test_the_dots_use_their_own_dim_and_the_childs_look_comes_back_after() -> void:
	var hub := await _to_hub(func() -> void:
		_played([&"shelf"])
		HubMemory.get_or_make().choose_look(&"high_contrast"))
	expect(await _open(hub), "the menu opens")
	expect_eq(App.session.base_view.title, "High contrast", "the saved look is the base view")
	_pinch(_piece(hub, &"dots").target)
	expect(await until(func() -> bool: return App.session.trial != null and is_equal_approx(App.reality.view.dim, MotionVisit.DIM.dim), 60.0), "the dots: their fixed dim")
	Engine.time_scale = 4.0
	await _finish_rounds()
	expect(await until(func() -> bool: return hub.state == &"hub", 90.0), "back at the hub")
	Engine.time_scale = 1.0
	expect_eq(App.reality.view.title, "High contrast", "the child's look is back")


func test_the_shelf_pause_eye_opens_the_looks_and_the_game_carries_on_after() -> void:
	var hub := await _to_hub()
	expect(await _open(hub), "the menu opens")
	_pinch(_piece(hub, &"shelf").target)
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.trial != null, 30.0), "the shelf plays")
	_pinch(hub.cauldron_target)
	expect(await until(func() -> bool: return hub.eye_bubble != null, 5.0), "eye · ✕")
	await wait(0.7)
	_pinch(hub.eye_bubble.target)
	expect(await until(func() -> bool: return hub.row != null and hub.row_kind == &"looks" and hub.row.opened, 10.0), "the looks rise")
	expect(app.get_tree().paused, "the game stays paused")
	_pinch(hub.row.impressions[1].target)
	await frames(3)
	expect_eq(App.reality.view.title, "High contrast", "the real room changes")
	_pinch(hub.cauldron_target)
	expect(await until(func() -> bool: return hub.row == null and not app.get_tree().paused, 10.0), "a tap: the looks sink and the game carries on")
	expect(hub.state == &"game" and App.session.running, "the same game")
