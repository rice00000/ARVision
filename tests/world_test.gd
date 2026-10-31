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
	expect_eq([world.current(TIDY), world.current(WALL)], [0, 0], "level 1 of each")
	await world._complete(TIDY, 0)
	expect_eq([world.current(TIDY), world.current(WALL)], [1, 0], "the shelf moves on, the wall does not")
	await world._complete(TIDY, 2)
	expect_eq(world.current(TIDY), 1, "a skipped level stays current")


func test_the_room_stays_in_normal_colour_before_and_after_tasks() -> void:
	await boot()
	var world := App.world
	expect_eq(App.reality.view.title, "Normal", "the room starts in normal colour")
	for completed in [[TIDY, 0], [TIDY, 1], [WALL, 0]]:
		await world._complete(completed[0], completed[1])
		expect(not App.reality.view.is_graded() and not App.reality.view.black_and_white, "completing a task never changes the room's colour")
		expect_eq(App.session.base_view.title, "Normal", "the next task also plays in normal colour")


func test_progress_is_saved_and_read_back() -> void:
	await boot()
	await App.world._complete(TIDY, 0)
	App.world.done = {}
	Save.reload()
	expect_eq(App.world.done, {&"tidy_shelf": [0]}, "levels done")
	Profile.wipe()
	expect_eq(App.world.done, {}, "a wiped profile starts fresh")


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
	expect(menu.global_position.distance_to(App.head().global_position) < 0.5, "within reach")
	expect_eq(menu.find_children("task_*", "Target", false, false).size(), TIDY.levels.size(), "the table's one task, every level")


func test_any_level_plays_at_its_level() -> void:
	await boot()
	var started := record(Events.trial_started)
	App.world.run()
	expect(await until(func() -> bool: return App.world.menu != null and App.world.menu.get("_open"), 15.0), "facing the table: the menu")
	await select(_button("task_tidy_shelf_6").global_position)
	expect(await until(func() -> bool: return started.size() == 1, 15.0), "level 6 plays with nothing done")
	expect_eq(App.session.plan, TIDY.levels[5], "level 6's plan")
	expect(is_equal_approx(App.session.level(), TIDY.levels[5].blocks[0].difficulty), "at level 6's difficulty")
	expect(App.world.menu == null, "the menu folded away")
	expect_eq(started[0][1].view.title, "Normal", "played in normal colour")


func test_a_fingertip_near_a_button_hears_what_it_is() -> void:
	await boot()
	var said := record(Events.said)
	App.world.run()
	expect(await until(func() -> bool: return App.world.menu != null and App.world.menu.get("_open"), 15.0), "facing the table: the menu")
	for case in [["task_tidy_shelf_1", "Level 1. A new one!"], ["task_tidy_shelf_2", "Level 2. A new one!"]]:
		var button := _button(case[0])
		var front := button.global_basis.z
		input.point(&"right", button.global_position + front * (0.05 + 0.04), button.global_position) # fingertip 4 cm out
		await frames(3)
		expect_eq(said.back()[0], case[1], "read out")
		expect((button.get_node(^"Look") as Node3D).position.z > 0.0, "lifted toward the hand")
	expect(App.world.menu != null and not App.session.running, "hovering chooses nothing")


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
	expect(_button("task_break_wall_1") != null and _button("task_tidy_shelf_1") == null, "the wall's list only")
	await select(_button("task_break_wall_1").global_position)
	expect(await until(func() -> bool: return App.session.running, 10.0), "the wall plays")
	expect_eq(App.session.plan, WALL.levels[0], "level 1's plan")
