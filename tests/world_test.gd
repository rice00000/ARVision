extends TestCase
## The World: the guide points the way, facing the table unfolds its task menu,
## every level is open and the first not done lights up, the room stays in colour, and progress is saved.

const TIDY := preload("res://content/tasks/tidy_shelf.tres")
const WALL := preload("res://content/tasks/break_wall.tres")


## Turns the head [param degrees] left (positive) of facing the table, level.
func _turn_from_table(degrees: float) -> void:
	var eye := App.head().global_position
	var table := App.reality.work_surface().transform.origin
	var ahead := Vector3(table.x - eye.x, 0.0, table.z - eye.z).normalized().rotated(Vector3.UP, deg_to_rad(degrees))
	input.set_head(Transform3D(Basis.looking_at(ahead), eye))
	await frames(2)


func _button(id: String) -> Target:
	return App.world.menu.find_child(id, false, false) as Target


func test_the_current_level_is_the_first_not_done() -> void:
	await boot()
	var world := App.world
	expect_eq([world.current(TIDY).id, world.current(WALL).id], [&"shadow", &"steady_flow"], "level 1 of each")
	await world._complete(TIDY, TIDY.levels[0])
	expect_eq([world.current(TIDY).id, world.current(WALL).id], [&"similar_shadows", &"steady_flow"], "the shelf moves on, the wall does not")
	await world._complete(TIDY, TIDY.levels[2])
	expect_eq(world.current(TIDY).id, &"similar_shadows", "a skipped level stays current")


func test_the_room_stays_in_normal_colour_before_and_after_tasks() -> void:
	await boot()
	var world := App.world
	expect_eq(App.reality.view.title, "Normal", "the room starts in normal colour")
	for completed in [[TIDY, TIDY.levels[0]], [TIDY, TIDY.levels[1]], [WALL, WALL.levels[0]]]:
		await world._complete(completed[0], completed[1])
		expect(not App.reality.view.is_graded() and not App.reality.view.black_and_white, "completing a task never changes the room's colour")
		expect_eq(App.session.base_view.title, "Normal", "the next task also plays in normal colour")


func test_progress_is_saved_and_read_back() -> void:
	await boot()
	await App.world._complete(TIDY, TIDY.levels[0])
	App.main.progress.done = {}
	Save.reload()
	expect_eq(App.main.progress.done, {&"tidy_shelf": [&"shadow"]}, "levels done")
	Profile.wipe()
	expect_eq(App.main.progress.done, {}, "a wiped profile starts fresh")


func test_legacy_progress_stays_with_the_level_when_a_new_card_is_inserted() -> void:
	await boot()
	var progress := App.main.progress
	progress.load_state({done = {&"tidy_shelf": [3], &"break_wall": [1]},
		seen = ["tidy_shelf:3", "break_wall:1"]})
	var task := Task.new()
	task.resource_path = "res://build/test_insert/tidy_shelf.tres"
	task.levels = TIDY.levels.duplicate()
	var size := task.level_by_id(&"size")
	var added := TaskLevel.new()
	added.id = &"fine_size"
	added.project = &"size"
	task.levels.insert(3, added)
	expect_eq([task.project_number(added), task.project_number(size)], [1, 2], "only the size project's numbers change")
	expect_eq(task.project_number(task.level_by_id(&"outline")), 1, "outline has its own numbering")
	expect(progress.is_done(task, size) and not progress.is_done(task, added), "completion stays with Size Match")
	expect_eq(progress.seen, ["tidy_shelf:size", "break_wall:mixed_flow"], "seen cards migrate too")
	Save.write()
	Save.reload()
	expect(progress.is_done(task, size) and progress.is_done(WALL, WALL.levels[1]), "converted IDs round-trip")


func test_each_level_pays_its_configured_first_and_repeat_reward() -> void:
	await boot()
	var task := Task.new()
	task.resource_path = "res://build/test_rewards/tidy_shelf.tres"
	task.levels = TIDY.levels.duplicate()
	var level := task.levels[0].duplicate() as TaskLevel
	level.first_reward = 5
	level.repeat_reward = 1
	task.levels[0] = level
	var progress := App.main.progress
	expect_eq(progress.reward(task, level), 5, "the first reward shown")
	expect_eq(progress.complete(task, level), 5, "the first reward paid")
	Save.reload()
	expect_eq(progress.reward(task, level), 1, "the repeat reward shown after loading")
	expect_eq(progress.complete(task, level), 1, "the repeat reward paid")
	expect_eq(App.module(&"Inventory").count(&"magic_stone"), 6, "both rewards persisted")
	expect_eq(progress.reward(task, task.levels[1]), 3, "another level has its own first reward")


func test_turning_to_the_table_unfolds_its_menu() -> void:
	await boot()
	var said := record(Events.said)
	var reports := record(Events.reported)
	await _turn_from_table(90.0)
	App.world.run()
	var guide: Node3D = App.world.get("_guide")
	expect(await until(func() -> bool: return guide.visible, 15.0), "the guide shows the way")
	expect(said.back()[0].contains("Turn to your alchemy table"), "and says it: %s" % said.back()[0])
	var to_table := App.reality.work_surface().transform.origin - App.head().global_position
	var to_guide := guide.global_position - App.head().global_position
	expect(Vector2(to_guide.x, to_guide.z).angle_to(Vector2(to_table.x, to_table.z)) < Vector2(-App.head().global_basis.z.x,
		-App.head().global_basis.z.z).angle_to(Vector2(to_table.x, to_table.z)), "on the table's side")
	await wait(1.0)
	expect(App.world.menu == null, "no menu while facing away")
	await _turn_from_table(40.0)
	await wait(1.0)
	expect(App.world.menu == null, "nor half turned")
	await _turn_from_table(10.0)
	expect(await until(func() -> bool: return App.world.menu != null and App.world.menu.get("_open"), 3.0), "the menu unfolds")
	expect(not guide.visible, "the guide's job is done")
	expect(reports.any(func(args: Array) -> bool: return args[0] == &"place_entered"), "logged")
	var menu := App.world.menu
	expect(is_equal_approx(menu.global_position.distance_to(App.head().global_position), Vector2(0.58, 0.12).length()), "the menu stands farther ahead")
	expect_eq(menu.find_children("task_*", "Target", false, false).size(), TIDY.levels.size(), "the table's one task, every level")


func test_any_level_plays_at_its_level() -> void:
	await boot()
	var started := record(Events.trial_started)
	App.world.run()
	expect(await until(func() -> bool: return App.world.menu != null and App.world.menu.get("_open"), 15.0), "facing the table: the menu")
	await select(_button("task_tidy_shelf_clutter").global_position)
	expect(await until(func() -> bool: return started.size() == 1, 15.0), "level 6 plays with nothing done")
	expect_eq(App.session.plan, TIDY.levels[5].plan, "level 6's plan")
	expect(is_equal_approx(App.session.level(), TIDY.levels[5].plan.blocks[0].difficulty), "at level 6's difficulty")
	expect(App.world.menu == null, "the menu folded away")
	expect_eq(started[0][1].view.title, "Normal", "played in normal colour")


func test_the_menu_opens_during_its_intro_and_cards_are_silent() -> void:
	await boot()
	var said := record(Events.said)
	var started := record(Events.trial_started)
	App.world.run()
	expect(await until(func() -> bool: return App.world.menu != null and App.world.menu.get("_open"), 15.0), "facing the table: the menu")
	var intro := App.world.place.arrive
	expect_eq(said, [[intro]], "opening the menu speaks its gameplay introduction once")
	expect_eq(App.module(&"Voice").speaking(), intro, "cards are usable while the line plays")
	for id in ["task_tidy_shelf_shadow", "task_tidy_shelf_similar_shadows"]:
		var button := _button(id)
		var front := button.global_basis.z
		input.point(&"right", button.global_position + front * 0.4, button.global_position) # aim from a distance
		await frames(3)
		expect((button.get_node(^"Look") as Node3D).position.z > 0.0, "lifted toward the hand")
	expect(App.world.menu != null and not App.session.running, "hovering chooses nothing")
	expect_eq(said, [[intro]], "hovering does not interrupt the line")
	await select(_button("task_tidy_shelf_odd_color_1").global_position)
	expect(await until(func() -> bool: return started.size() == 1, 1.0), "choosing starts the round promptly")
	expect_eq(said, [[intro], ["Pinch the block with a different colour."]], "only the menu intro and the round instruction")


func test_motion_is_only_in_its_own_scene_and_needs_no_shelf_progress() -> void:
	await boot()
	App.world.run()
	expect(await until(func() -> bool: return App.world.menu != null and App.world.menu.get("_open"), 15.0), "the table's menu")
	expect_eq(App.world.place.title, "Alchemy table", "at the table")
	expect_eq(App.world.adventure.places.size(), 1, "no motion place in the object scene")
	await _turn_from_table(180.0)
	await wait(1.0)
	expect_eq(App.world.place.title, "Alchemy table", "turning around cannot enter motion")
	await _turn_from_table(0.0)
	app.autostart = true
	await App.main.change_scene(&"global_motion")
	var at_wall := func() -> bool: return App.world.menu != null and App.world.menu.get("_open")
	expect(await until(at_wall, 15.0), "motion has its own menu")
	expect(_button("task_break_wall_steady_flow") != null and _button("task_tidy_shelf_shadow") == null, "the wall's list only")
	await select(_button("task_break_wall_steady_flow").global_position)
	expect(await until(func() -> bool: return App.session.running, 10.0), "the wall plays")
	expect_eq(App.session.plan, WALL.levels[0].plan, "level 1's plan")
