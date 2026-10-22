extends TestCase
## The framework end to end on the simulated room: rounds, staircase, help,
## facilitator, CV and an unplugged module.

const FIND := preload("res://trials/find/find.tres")
const POINT := preload("res://trials/point_real/point_real.tres")
const SPOTLIGHT := preload("res://content/views/spotlight.tres")


func test_correct_picks_score_and_raise_the_level() -> void:
	await boot(plan_of(FIND, 2))
	var ended := record(Events.trial_ended)
	App.session.run()
	for round_index in 2:
		expect(await until(_round_running), "round %d starts" % round_index)
		var target: Target = App.session.trial.get("_target")
		await select(target.global_position)
		expect_eq(ended.size(), round_index + 1, "round %d scored" % round_index)
	expect(ended.all(func(args: Array) -> bool: return args[1]), "both picks were right")
	expect_eq(ended[0][2].tries, 0, "no wrong tries")
	expect(await until(func() -> bool: return not App.session.running), "session ends")
	expect(Profile.level(FIND.skill) > Profile.START_LEVEL, "two successes raise the level")
	expect(FileAccess.file_exists(Log.file_path), "research log written")


func test_wrong_pick_then_help() -> void:
	await boot(plan_of(FIND, 1))
	var feedback := record(Events.feedback)
	App.session.run()
	await until(_round_running)
	var trial := App.session.trial
	var other: Target = trial.get("_toys").keys()[1]
	await select(other.global_position)
	expect(trial.is_running(), "a wrong pick keeps the round going")
	expect_eq(trial.tries, 1, "wrong pick counted")
	expect_eq(feedback.back()[0], &"bad", "bad feedback")
	input.click(&"right", &"by_button")
	expect_eq(trial.hint_level, 1, "B asks for the first hint")


func test_a_round_solved_after_a_wrong_try_lowers_the_level() -> void:
	await boot(plan_of(FIND, 1))
	var ended := record(Events.trial_ended)
	App.session.run()
	await until(_round_running)
	await select((App.session.trial.get("_toys").keys()[1] as Target).global_position)
	await select((App.session.trial.get("_target") as Target).global_position)
	expect(ended[0][1] and not ended[0][2].first_try, "solved, but not on the first try")
	expect(Profile.level(FIND.skill) < Profile.START_LEVEL, "the staircase steps down")


func test_probe_rounds_get_no_help_and_keep_the_level() -> void:
	await boot(plan_of(FIND, 1, true, 0.3))
	App.session.run()
	await until(_round_running)
	input.click(&"left", &"by_button")
	expect_eq(App.session.trial.hint_level, 0, "no help in a probe")
	await select((App.session.trial.get("_toys").keys()[1] as Target).global_position)
	await select((App.session.trial.get("_target") as Target).global_position)
	expect_eq(Profile.level(FIND.skill), Profile.START_LEVEL, "probe leaves the staircase alone")


func test_facilitator_pauses_and_pins_the_level() -> void:
	await boot(plan_of(FIND, 3))
	App.session.run()
	await until(_round_running)
	var before := App.session.level()
	input.click(&"left", &"menu_button")
	expect(get_tree().paused, "panel pauses play")
	var panel := App.module(&"Facilitator").get_node(^"FacilitatorPanel")
	await select((panel.get_node(^"fac_harder") as Node3D).global_position)
	expect(is_equal_approx(App.session.level(), before + 0.1), "Harder pins the level up")
	await select((panel.get_node(^"fac_close") as Node3D).global_position)
	expect(not get_tree().paused, "Close resumes play")


func test_real_object_found_by_cv() -> void:
	await boot(plan_of(POINT, 1))
	var ended := record(Events.trial_ended)
	App.session.run()
	await until(_round_running)
	expect(await until(func() -> bool: return App.session.trial.get("_label") != ""), "an object in view is named")
	await select(App.session.trial.get("_place"))
	expect(ended.size() == 1 and ended[0][1], "pointing at it succeeds")


func test_unplugged_detector_skips_the_cv_block() -> void:
	await boot(plan_of(POINT, 1))
	app.get_node(^"Modules/Detector").free()
	var events := record(Events.reported)
	App.session.run()
	expect(await until(func() -> bool: return not App.session.running), "session still finishes")
	expect(events.any(func(args: Array) -> bool: return args[0] == &"block_skipped"), "block skipped")


func test_block_view_is_applied_and_logged() -> void:
	await boot(plan_of(FIND, 1, false, -1.0, SPOTLIGHT))
	var started := record(Events.trial_started)
	App.session.run()
	await until(_round_running)
	expect_eq(App.reality.view.title, "Spotlight", "block view applied")
	expect_eq(started[0][1].view.focus_radius, 0.35, "round logs the view")


func _round_running() -> bool:
	return App.session.trial != null and App.session.trial.is_running()
