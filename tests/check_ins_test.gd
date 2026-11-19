extends TestCase
## Check-ins (modules/check_ins): no-help rounds on new things, before a place's
## menu when due, saved with the child, and shown on the facilitator's Progress page.

const FIND := preload("res://trials/find/find.tres")
const TIDY := preload("res://trials/tidy/tidy.tres")
const TABLE := preload("res://content/places/table.tres")
const TIDY_TRIAL := preload("res://trials/tidy/tidy_trial.gd")


func _check_ins() -> CheckIns:
	return App.module(&"CheckIns") as CheckIns


func _place(plan: SessionPlan) -> Place:
	var place := Place.new()
	place.title = "Test table"
	place.check_in = plan
	place.resource_path = "res://tests/test_place.tres" # its key: test_place
	return place


func _round_running() -> bool:
	return App.session.trial != null and App.session.trial.is_running()


func _answer_finds(count: int) -> void:
	for i in count:
		await until(func() -> bool: return _round_running() and App.session.trial.condition.round_index == i)
		await select((App.session.trial.get("_target") as Target).global_position)


func _turn_from_table(degrees: float) -> void:
	var eye := App.head().global_position
	var table := App.reality.work_surface().transform.origin
	var ahead := Vector3(table.x - eye.x, 0.0, table.z - eye.z).normalized().rotated(Vector3.UP, deg_to_rad(degrees))
	input.set_head(Transform3D(Basis.looking_at(ahead), eye))
	await frames(2)


func test_first_visit_then_weekly_and_a_skipped_one_waits_a_day() -> void:
	await boot(null, &"find_object", true)
	var check_ins := _check_ins()
	var place := _place(plan_of(FIND, 1, true, 0.3))
	var now := Time.get_unix_time_from_system()
	expect(check_ins.due(place, now), "due on the first visit: the baseline")
	check_ins.history.append({place = "test_place", title = "Test table", time = now, done = true, scores = {}})
	expect(not check_ins.due(place, now + 3600.0), "not again soon after")
	expect(check_ins.due(place, now + 7.0 * CheckIns.DAY), "a week later")
	check_ins.history.append({place = "test_place", title = "Test table", time = now + 7.0 * CheckIns.DAY, done = false, scores = {}})
	expect(not check_ins.due(place, now + 7.0 * CheckIns.DAY + 3600.0), "skipped: not asked again the same day")
	expect(check_ins.due(place, now + 8.0 * CheckIns.DAY), "but the next day")
	check_ins.ask()
	expect(check_ins.due(place, now + 3600.0), "staff can ask for one now")
	expect(not check_ins.due(Place.new()), "a place without a check-in never has one")


func test_a_check_in_is_scored_without_help_and_saved() -> void:
	var plan := plan_of(FIND, 2, true, 0.3)
	var block := plan_of(FIND, 1, true, 0.6).blocks[0]
	plan.blocks.append(block)
	await boot(null, &"find_object", true)
	var reports := record(Events.reported)
	var place := _place(plan)
	_check_ins().run(place)
	await _answer_finds(2)
	await until(func() -> bool: return _round_running() and App.session.block_index == 1)
	await wait(FIND.hint_after + 1.0)
	expect_eq(App.session.trial.hint_level, 0, "no help in a check-in")
	await select((App.session.trial.get("_target") as Target).global_position)
	expect(await until(func() -> bool: return not _check_ins().history.is_empty(), 20.0), "recorded")
	var entry: Dictionary = _check_ins().history.back()
	expect(entry.done, "finished")
	var score: Dictionary = entry.scores[String(FIND.skill)]
	expect_eq([score.rounds, score.right], [3, 3], "three rounds, all right")
	expect_eq(score.levels, {"0.30": [2, 2], "0.60": [1, 1]}, "by difficulty")
	expect_eq(Profile.level(FIND.skill), Profile.START_LEVEL, "the staircase did not move")
	expect(reports.any(func(args: Array) -> bool: return args[0] == &"check_in" and args[1].done), "logged")
	expect_eq(_check_ins().results(FIND.skill).size(), 1, "one result for the skill")
	Save.write()
	Save.reload()
	expect_eq(_check_ins().history.size(), 1, "saved with the child")


func test_the_table_checks_in_before_its_first_menu() -> void:
	await boot(null, &"find_object", true)
	var reports := record(Events.reported)
	await _turn_from_table(90.0)
	App.world.run()
	await _turn_from_table(0.0)
	expect(await until(func() -> bool: return reports.any(func(args: Array) -> bool: return args[0] == &"check_in_started"), 20.0),
		"the check-in starts")
	expect(App.world.menu == null, "before the menu")
	expect(await until(_round_running, 20.0), "a round runs")
	expect(App.session.trial.condition.probe, "as a check-in round")
	var keys := App.session.trial.get("_key") as Dictionary
	expect(keys.values().all(func(key: String) -> bool: return StringName(key) in TIDY_TRIAL.NOVEL_SHAPES),
		"with shapes the child never trains on: %s" % [keys.values()])
	while App.session.running:
		App.session.skip_block()
		await frames(5)
	expect(await until(func() -> bool: return App.world.menu != null, 20.0), "then the menu")
	var entry: Dictionary = _check_ins().history.back()
	expect(not entry.done and entry.place == "table", "a skipped check-in is kept, unfinished")
	expect(not _check_ins().due(TABLE), "and not asked again today")


func test_the_progress_page_shows_levels_and_check_ins() -> void:
	await boot(null, &"find_object", true)
	Profile.adapt(&"visual_matching", false, 2, 0.1)
	var now := Time.get_unix_time_from_system()
	for right in [2, 4]:
		_check_ins().history.append({place = "table", title = "Alchemy table", time = now, done = true,
			scores = {visual_matching = {rounds = 5, right = right, levels = {}}}})
	input.menu()
	await frames(2)
	await press_facilitator("fac_progress")
	await frames(2)
	var text := (App.module(&"Facilitator").get("_progress") as Label3D).text
	expect(text.contains("Shapes on the shelf:  level 0.20   check-in 2/5 -> 4/5"), "first and latest: %s" % text)
	await press_facilitator("fac_check_in")
	expect(_check_ins().asked(), "staff asked for a check-in")
	expect((App.module(&"Facilitator").get("_progress") as Label3D).text.contains("before the next menu"), "and the page says so")


func test_tidy_can_use_shapes_never_trained_on() -> void:
	await boot(plan_of(TIDY, 1, true, 0.67, null, {&"novel": 1.0, &"match": 0.0}), &"find_object", true)
	App.session.run()
	expect(await until(_round_running, 10.0), "a round")
	var keys := (App.session.trial.get("_key") as Dictionary).values()
	expect_eq(keys.size(), 5, "five things")
	for key: String in keys:
		expect(StringName(key) in TIDY_TRIAL.NOVEL_SHAPES and not StringName(key) in TIDY_TRIAL.SHAPES, "new: %s" % key)
