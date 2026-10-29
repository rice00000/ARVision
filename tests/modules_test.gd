extends TestCase
## The optional story and data modules: Magic's sparkles and flying treasure, and the
## Picks CSV.

const FIND := preload("res://trials/find/find.tres")


func test_a_right_pick_sparkles_and_a_new_treasure_flies_to_its_slot() -> void:
	await boot()
	var magic := App.module(&"Magic")
	Events.feedback.emit(&"good", Vector3(0.0, 0.8, -0.4))
	Events.feedback.emit(&"bad", Vector3(0.0, 0.8, -0.4))
	expect_eq(magic.find_children("Sparkles*", "CPUParticles3D", false, false).size(), 1, "sparkles for good only")
	var slot := Vector3(-0.5, 1.0, -0.5)
	Events.report(&"task_done", {task = &"find_toys", level = 1, colour = 1, treasure = {shape = "ring", colour = "ff8040"},
		slot = slot, size = 0.05, arrive = 1.8})
	var treasure := magic.find_child("Treasure", false, false) as Node3D
	expect(treasure != null, "the treasure shows")
	var eye := App.head().global_position
	expect(treasure.global_position.y < eye.y and treasure.global_position.distance_to(eye) < 0.6, "below the eyes, in front")
	await wait(1.75)
	expect(treasure.global_position.distance_to(slot) < 0.02, "and lands in its slot")
	expect(await until(func() -> bool: return magic.get_child_count() == 0, 3.0), "it all goes by itself")


func test_every_pick_is_a_csv_row_with_its_time_and_the_running_accuracy() -> void:
	var plan := plan_of(FIND, 2)
	plan.title = "Find the toys, level 1"
	await boot(plan)
	App.session.run()
	for round_index in 2:
		await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running())
		if round_index == 0:
			await wait(0.5)
			await select((App.session.trial.get("_toys").keys()[1] as Target).global_position)
		await select((App.session.trial.get("_target") as Target).global_position)
	var file := FileAccess.open(Profile.path("picks.csv"), FileAccess.READ)
	expect_eq(file.get_csv_line(), PackedStringArray(["time", "save", "game", "round", "target", "picked", "correct",
		"seconds", "accuracy"]), "header")
	var cells: Array[PackedStringArray] = []
	while file.get_position() < file.get_length():
		cells.append(file.get_csv_line())
	expect_eq(cells.size(), 3, "a row per pick")
	expect_eq(cells.map(func(row: PackedStringArray) -> Array: return [row[1], row[2], row[3], row[6], row[8]]),
		[["test", "Find the toys, level 1", "1", "0", "0"], ["test", "Find the toys, level 1", "1", "1", "50"],
		["test", "Find the toys, level 1", "2", "1", "67"]], "save, game, round, correct, accuracy")
	expect(cells[0][5] != cells[0][4] and cells[1][5] == cells[1][4], "picked against target")
	expect(float(cells[0][7]) >= 0.5 and float(cells[1][7]) >= float(cells[0][7]), "seconds since the round began")
