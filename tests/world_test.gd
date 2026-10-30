extends TestCase
## The World: the guide points the way, facing the table unfolds its task menu,
## locked levels stay locked, done tasks give back colour, and all of it is saved.

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


func test_levels_and_tasks_unlock_in_order() -> void:
	await boot()
	var world := App.world
	expect(world.can_play(TIDY, 0), "the first task's level 1 is open")
	expect(not world.can_play(TIDY, 1), "level 2 waits for level 1")
	expect(not world.can_play(WALL, 0), "the wall waits for the shelf")
	await world._complete(TIDY, 0)
	expect(world.can_play(TIDY, 1), "level 2 opens")
	expect(world.can_play(WALL, 0), "the wall opens")
	expect(not world.can_play(WALL, 1), "but not its level 2")


func test_colour_comes_back_the_first_time_each_task_is_done() -> void:
	await boot()
	var world := App.world
	var said := record(Events.said)
	world._show_colour()
	expect_eq(App.reality.view.title, "Black and white", "the room starts in black and white")
	await world._complete(TIDY, 0)
	expect_eq(world.colour, 1, "a step of colour")
	expect_eq(App.reality.view.title, "A little colour", "the room shows it")
	expect_eq(App.session.base_view.title, "A little colour", "and the next task plays in it")
	expect(said.back()[0].contains("Colour is coming back"), "the guide says so: %s" % said.back()[0])
	await world._complete(TIDY, 1)
	expect_eq(world.colour, 1, "another level of the same task: no more colour")
	await world._complete(WALL, 0)
	expect_eq(world.colour, 2, "the second task brings full colour")
	expect_eq(App.reality.view.title, "Normal", "full colour")
	expect(said.back()[0].contains("all its colours"), "and the guide says so: %s" % said.back()[0])


func test_progress_is_saved_and_read_back() -> void:
	await boot()
	await App.world._complete(TIDY, 0)
	App.world.done = {}
	App.world.colour = 0
	Save.reload()
	expect_eq(App.world.done, {&"tidy_shelf": [0]}, "levels done")
	expect_eq(App.world.colour, 1, "colour")
	Profile.wipe()
	expect_eq([App.world.done, App.world.colour], [{}, 0], "a wiped profile starts fresh")


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


func test_a_locked_level_says_so_and_an_open_one_plays_at_its_level() -> void:
	await boot()
	var said := record(Events.said)
	var started := record(Events.trial_started)
	App.world.run()
	expect(await until(func() -> bool: return App.world.menu != null and App.world.menu.get("_open"), 15.0), "facing the table: the menu")
	await select(_button("task_tidy_shelf_2").global_position)
	expect(said.back()[0].contains("still locked"), "level 2 before level 1: %s" % said.back()[0])
	expect(App.world.menu != null and not App.session.running, "nothing starts")
	await select(_button("task_tidy_shelf_1").global_position)
	expect(await until(func() -> bool: return started.size() == 1, 15.0), "the task plays")
	expect_eq(App.session.plan, TIDY.levels[0], "level 1's plan")
	expect(is_equal_approx(App.session.level(), TIDY.levels[0].blocks[0].difficulty), "at level 1's difficulty")
	expect(App.world.menu == null, "the menu folded away")
	expect_eq(started[0][1].view.title, "Black and white", "still in black and white")


func test_something_new_behind_turning_around_opens_its_menu() -> void:
	await boot()
	App.world.done = {&"tidy_shelf": [0]}
	var said := record(Events.said)
	App.world.run()
	expect(await until(func() -> bool: return App.world.menu != null and App.world.menu.get("_open"), 15.0), "the table's menu")
	expect_eq(App.world.place.title, "Alchemy table", "at the table")
	var guide: Node3D = App.world.get("_guide")
	expect(guide.visible, "the guide points to the new thing")
	expect(said.back()[0].contains("behind you"), "and says so: %s" % said.back()[0])
	var behind: Place = App.world.adventure.places[1]
	var eye := App.head().global_position
	var to_table := App.reality.work_surface().transform.origin - eye
	var to_behind := App.world.position_of(behind) - eye
	expect(rad_to_deg(Vector2(to_table.x, to_table.z).angle_to(Vector2(to_behind.x, to_behind.z))) > 179.0, "the other way")
	await _turn_from_table(100.0)
	await wait(1.0)
	expect_eq(App.world.place.title, "Alchemy table", "half way round is nowhere new")
	await _turn_from_table(180.0)
	var at_wall := func() -> bool: return App.world.place == behind and App.world.menu != null and App.world.menu.get("_open")
	expect(await until(at_wall, 5.0), "turned around: the wall's menu")
	expect(not guide.visible, "the guide's job is done")
	expect(_button("task_break_wall_1") != null and _button("task_tidy_shelf_1") == null, "the wall's list only")
	await select(_button("task_break_wall_1").global_position)
	expect(await until(func() -> bool: return App.session.running, 10.0), "the wall plays")
	expect_eq(App.session.plan, WALL.levels[0], "level 1's plan")
