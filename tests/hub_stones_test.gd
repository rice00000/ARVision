extends TestCase
## The hub's stones, games and levels, and the eye (design chat, Nov 18, `claude/DESIGN_STONES_AND_LEVELS.md`
## and the 9:54 update of `claude/DESIGN_EXIT_AND_HELP.md`).

const SHELF := preload("res://content/tasks/tidy_shelf.tres")

var entry: Entry


## Into the hub. [param prep] runs after boot, before the opening hands over (to set saved progress).
func _to_hub(prep := Callable(), first := &"", check_ins := false) -> WorkshopController:
	Engine.time_scale = 1.0
	await boot(null, &"intro", check_ins)
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


## Games played on earlier visits.
func _played(ids: Array[StringName]) -> void:
	var memory := HubMemory.get_or_make()
	for id in ids:
		memory.played.append(id)


## Finished, and climbed past TaskProgress.READY_AT (so the next level is the one to play).
func _done(levels: Array[StringName]) -> void:
	App.main.progress.done[&"tidy_shelf"] = levels.duplicate()
	for id in levels:
		Profile.set_level(SHELF.level_by_id(id).staircase(), TaskProgress.READY_AT)


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
	var hub := await _to_hub(func() -> void: _played([&"shelf", &"real_life"]))
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
	var hub := await _to_hub(func() -> void: _played([&"shelf", &"real_life"]))
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
		_played([&"shelf", &"real_life"])
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
	var hub := await _to_hub(func() -> void: _played([&"shelf", &"real_life"]))
	expect(await _open(hub), "the menu opens")
	var row := hub.ring.places.map(func(p: Impression) -> StringName: return p.kind)
	expect_eq(row, [&"help", &"eye", &"house", &"finish"], "? · eye · house · ✕")
	var eye_at := App.head().global_position
	var gaps := hub.ring.places.map(func(p: Impression) -> float: return p.bubble.global_position.distance_to(eye_at))
	expect(gaps.max() - gaps.min() < 0.04, "the row curves: every place about the same distance from the eyes (%s)" % [gaps.map(func(g: float) -> String: return "%.2f" % g)])
	_pinch(hub.ring.place_of(&"eye").target)
	expect(await until(func() -> bool: return hub.row != null and hub.row_kind == &"looks" and hub.row.opened, 10.0), "the looks rise")
	var looks := hub.row.impressions.map(func(p: Impression) -> StringName: return p.look)
	# Megan, Nov 18: Wei's Greyscale and Dim room too; Spotlight only in a game's pause bubble.
	expect_eq(looks, [&"normal", &"high_contrast", &"edges", &"black_white", &"greyscale", &"dim"], "the hub's six looks, no Spotlight")
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
		_played([&"shelf", &"real_life"])
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


func test_weis_room_from_the_house_has_no_menu_a_cauldron_to_go_back_and_teal_stones() -> void:
	var hub := await _to_hub(func() -> void: _played([&"shelf", &"real_life"]))
	expect(await _open(hub), "the menu opens")
	var home := App.module(&"Home")
	_pinch(hub.ring.door.target)
	expect(await until(func() -> bool: return home.is_open, 15.0), "Wei's room opens")
	await frames(3)
	var panel := home.get("_panel") as Node3D
	expect(panel.find_child("menu_back", true, false) == null, "no Menu: it led out of the workshop")
	var back := panel.find_child("menu_resume", true, false) as Node3D
	expect(back != null, "a way back")
	var captions := back.find_children("*", "Label3D", true, false).map(func(l: Label3D) -> String: return l.text)
	expect(captions.has("Workshop"), "it says Workshop (%s)" % [captions])
	expect(HomeUI.teal_stones, "the stones are teal in the workshop")
	_pinch(back as Target)
	expect(await until(func() -> bool: return not home.is_open, 10.0), "the cauldron takes the child back")
	expect(await until(func() -> bool: return hub.state == &"hub" and hub.ring.opened, 15.0), "to the workshop's menu")


func test_staff_tools_restart_fresh_child_starts_a_new_save_from_the_hello() -> void:
	var hub := await _to_hub(func() -> void: _played([&"shelf", &"real_life", &"dots"]))
	expect(await _open(hub), "the menu opens")
	var before := Profile.id
	input.menu()   # Staff tools (M)
	await frames(2)
	await press_facilitator("fac_scenes")
	await frames(2)
	await press_facilitator("fac_fresh_start")
	expect(await until(func() -> bool: return App.main.current_scene == &"intro" and not App.main.switching, 30.0), "back to the opening")
	expect(Profile.id != before, "a new save (the old child's progress is kept under Saves)")
	expect(Profile.saves().has(before), "the old save is still there")
	expect(HubMemory.get_or_make().played.is_empty(), "nothing played: every game locked again")
	expect_eq(App.module(&"Inventory").count(&"magic_stone"), 0, "no stones")


## Megan, Nov 18: the dots run with the ray off, so a real pinch at the cauldron selected nothing: no way out.
func test_a_real_pinch_at_the_cauldron_pauses_the_dots_and_the_x_ends_them() -> void:
	var hub := await _to_hub(func() -> void: _played([&"shelf", &"real_life"]))
	expect(await _open(hub), "the menu opens")
	_pinch(_piece(hub, &"dots").target)
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.running and App.session.trial != null, 60.0), "the dots play")
	expect(not App.rig.pointer(&"right").ray_on(), "the dots run with the ray off")
	await _real_pinch_at(hub.cauldron_target)
	expect(await until(func() -> bool: return hub.stop_bubble != null, 5.0), "a real pinch at the cauldron: paused, the ✕ rises")
	await wait(0.8)
	await _real_pinch_at(hub.stop_bubble.target)
	expect(await until(func() -> bool: return hub.state == &"hub" and not app.get_tree().paused, 20.0), "the ✕: back at the hub")


## Megan, Nov 18: a jump (Staff tools → Scenes) to a game keeps the whole menu: the shelf, the locked games.
func test_a_jump_to_the_dots_keeps_the_whole_menu() -> void:
	var hub := await _to_hub(Callable(), &"dots")
	expect(await until(func() -> bool: return hub.state == &"game", 30.0), "the dots start at once")
	expect(_piece(hub, &"shelf") != null, "the shelf is in the menu")
	var butterflies := _piece(hub, &"butterflies")
	expect(butterflies != null and butterflies.sealed, "the butterflies wait locked")
	expect(_piece(hub, &"dots") != null and not _piece(hub, &"dots").sealed, "the dots are open")
	hub.current.leave()
	expect(await until(func() -> bool: return hub.state == &"hub" and not hub.ring.turning, 60.0), "back at the hub")


## Aims the simulated right hand at [param target] and pinches (the real input path, not Events.selected).
func _real_pinch_at(target: Target) -> void:
	var eye := App.head().global_position
	var from := eye + Vector3.DOWN * 0.15
	App.sim_input.set_hand(&"right", Transform3D(Basis.looking_at(target.global_position - from), from))
	await frames(3)
	App.sim_input.press(&"right", &"trigger_click", true)
	await frames(2)
	App.sim_input.press(&"right", &"trigger_click", false)
	await frames(2)


## Megan, Nov 18 (2:04 pm): the shelf too; the cauldron only takes a pinch now (not a pass of the hand), so the
## pinch has to get there with the ray off.
func test_a_real_pinch_at_the_cauldron_pauses_the_shelf() -> void:
	var hub := await _to_hub(func() -> void: _played([&"shelf", &"real_life"]))
	expect(await _open(hub), "the menu opens")
	_pinch(_piece(hub, &"shelf").target)
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.running and App.session.trial != null, 60.0), "the shelf plays")
	await wait(1.0)
	await _real_pinch_at(hub.cauldron_target)
	expect(await until(func() -> bool: return hub.stop_bubble != null, 5.0), "a real pinch at the cauldron: paused, the ✕ rises")
	await wait(0.8)
	await _real_pinch_at(hub.stop_bubble.target)
	expect(await until(func() -> bool: return hub.state == &"hub" and not app.get_tree().paused, 20.0), "the ✕: back at the hub")


## Megan, Nov 18: in a game's pause bubble the eye offers Spotlight too (it lights round the game's focus); back
## in the hub the room shows Normal while Spotlight is the child's look.
func test_spotlight_is_offered_in_a_game_and_the_hub_shows_normal() -> void:
	var hub := await _to_hub()
	expect(await _open(hub), "the menu opens")
	_pinch(_piece(hub, &"shelf").target)
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.running and App.session.trial != null, 30.0), "the shelf plays")
	_pinch(hub.cauldron_target)
	expect(await until(func() -> bool: return hub.eye_bubble != null, 5.0), "paused: eye · ✕")
	await wait(0.7)
	_pinch(hub.eye_bubble.target)
	expect(await until(func() -> bool: return hub.row != null and hub.row_kind == &"looks" and hub.row.opened, 10.0), "the looks rise")
	var looks := hub.row.impressions.map(func(p: Impression) -> StringName: return p.look)
	expect(looks.has(&"spotlight"), "Spotlight is offered in a game")
	var spotlight: Impression = hub.row.impressions[looks.find(&"spotlight")]
	_pinch(spotlight.target)
	await frames(3)
	expect_eq(App.reality.view.title, "Spotlight", "the game shows it")
	expect_eq(hub.memory.look, &"spotlight", "and it's the child's look")
	_pinch(hub.cauldron_target)   # leave the looks: the game carries on
	expect(await until(func() -> bool: return hub.row == null and not app.get_tree().paused, 10.0), "the game carries on")
	await _finish_rounds()
	expect(await until(func() -> bool: return hub.state == &"hub", 40.0), "back at the hub")
	expect_eq(App.reality.view.title, "Normal", "the hub shows the room Normal")


## Megan, Nov 18: the room stayed dark after a jump cut the dots off mid-haze. The hub begins in the child's look.
func test_the_hub_begins_in_the_childs_look_whatever_was_left_on_the_room() -> void:
	var dark := View.new()
	dark.dim = 0.6
	var hub := await _to_hub(func() -> void: App.reality.apply_view(dark))
	expect(await until(func() -> bool: return hub.state == &"hub", 20.0), "the hub")
	expect(is_zero_approx(App.reality.view.dim), "no dim left on the room")


func test_real_life_opens_after_the_first_game_and_plays_weis_ready_to_study_on_the_bench() -> void:
	var hub := await _to_hub(func() -> void: _played([&"shelf"]))
	expect(await _open(hub), "the menu opens")
	var real_life := _piece(hub, &"real_life")
	expect(real_life != null and not real_life.sealed, "Real Life is open after the first game")
	expect(_piece(hub, &"dots").sealed, "the dots open after Real Life")
	expect(real_life.find_child("drawn_real_life", true, false) != null, "its bubble wears Ready to Study's drawing")
	_pinch(real_life.target)
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.running and App.session.trial != null, 30.0), "Real Life plays")
	expect_eq(hub.current.played_level.id, &"outline", "Ready to Study, the first")
	expect(String(App.session.trial.get_script().resource_path).contains("desk"), "Wei's desk")
	Engine.time_scale = 4.0
	await _finish_rounds()
	expect(await until(func() -> bool: return hub.state == &"hub", 90.0), "back at the hub")
	Engine.time_scale = 1.0
	expect(App.main.progress.is_done(SHELF, SHELF.level_by_id(&"outline")), "Ready to Study is marked done")
	expect(_stones() > 0, "stones for it")


func test_levels_megan_has_not_drawn_show_their_own_drawing_in_the_games_frame() -> void:
	var hub := await _to_hub(func() -> void:
		_played([&"shelf", &"real_life"])
		_done([&"outline"]))
	expect(await _open(hub), "the menu opens")
	_pinch(_piece(hub, &"real_life").target)
	expect(await until(func() -> bool: return hub.row != null and hub.row.opened, 10.0), "Real Life's own row rises")
	var titles := hub.row.impressions.map(func(p: Impression) -> String: return p.title)
	expect_eq(titles, ["Ready to Study", "Bookshelf Match"], "the finished level and the next one")
	expect(hub.row.impressions.all(func(p: Impression) -> bool: return p.find_child("drawn_real_life", true, false) != null),
			"each wears its level's drawing")
	_pinch(hub.cauldron_target)
	expect(await until(func() -> bool: return hub.row == null and hub.ring.opened, 10.0), "back to the menu")


func test_a_check_in_comes_before_a_game_played_before_when_one_is_due() -> void:
	var reported := record(Events.reported)
	var hub := await _to_hub(func() -> void: HubMemory.get_or_make().played.append_array([&"shelf", &"real_life"]), &"", true)
	expect(await _open(hub), "the menu opens")
	_pinch(_piece(hub, &"shelf").target)
	expect(await until(func() -> bool: return reported.any(func(r: Array) -> bool: return r[0] == &"check_in_started"), 30.0),
			"the table's check-in starts first (none done yet)")
	expect(hub.state == &"game", "inside the game's time: the cauldron pauses it")


## Nov 19: picking Ready to Study opened the table's shelf check-in first; it measures shelf shapes and odd colour.
func test_real_life_goes_straight_to_its_level_with_no_check_in() -> void:
	var reported := record(Events.reported)
	var hub := await _to_hub(func() -> void: HubMemory.get_or_make().played.append_array([&"shelf", &"real_life"]), &"", true)
	expect(await _open(hub), "the menu opens")
	_pinch(_piece(hub, &"real_life").target)
	expect(await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running(), 30.0), "a game plays")
	expect(String(App.session.trial.get_script().resource_path).contains("desk"), "Ready to Study's desk")
	expect(not reported.any(func(r: Array) -> bool: return r[0] == &"check_in_started"), "no check-in")


## Nov 19 (laptop test): on Wei's desk, pinching a notebook with the cauldron behind it paused the game (Stop ·
## Looks rose and nothing could be picked up); and pinching inside the ✕ did nothing.
func test_picking_up_a_desk_thing_never_pauses_and_a_pinch_inside_the_x_presses_it() -> void:
	var hub := await _to_hub(func() -> void: _played([&"shelf"]))
	expect(await _open(hub), "the menu opens")
	_pinch(_piece(hub, &"real_life").target)
	expect(await until(func() -> bool: return hub.state == &"game" and App.session.trial != null and App.session.trial.is_running(), 30.0), "Ready to Study plays")
	var reported := record(Events.reported)
	var things: Array = App.session.trial.get(&"_things")
	var thing := things[0] as Node3D
	var at := thing.global_position
	App.sim_input.set_hand(&"right", Transform3D(Basis.looking_at(hub.cauldron_target.global_position - at), at))
	await frames(3)
	App.sim_input.press(&"right", &"trigger_click", true)
	await frames(3)
	expect(reported.any(func(r: Array) -> bool: return r[0] == &"taken"), "the notebook is picked up")
	await wait(0.5)
	expect(hub.stop_bubble == null and not app.get_tree().paused, "and the game never paused")
	App.sim_input.press(&"right", &"trigger_click", false)
	await wait(1.0)
	await _real_pinch_at(hub.cauldron_target)
	expect(await until(func() -> bool: return hub.stop_bubble != null, 5.0), "a pinch aimed at the cauldron still pauses")
	await wait(0.8)
	var x := hub.stop_bubble.target.global_position
	App.sim_input.set_hand(&"right", Transform3D(Basis.looking_at(Vector3.FORWARD), x))
	await frames(3)
	App.sim_input.press(&"right", &"trigger_click", true)
	await frames(2)
	App.sim_input.press(&"right", &"trigger_click", false)
	expect(await until(func() -> bool: return hub.state == &"hub" and not app.get_tree().paused, 20.0), "a pinch with the fingertip in the ✕: back at the hub")
