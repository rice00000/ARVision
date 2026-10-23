extends TestCase
## Session steering (skip, nudge, unpin) and the Trial base's help clock and
## time limit, on the real app.

const FIND := preload("res://trials/find/find.tres")


func _round_running() -> bool:
	return App.session.trial != null and App.session.trial.is_running()


func _round_is(index: int) -> bool:
	return _round_running() and App.session.trial.condition.round_index == index


## Every hint of the running round as [level, round seconds when it came].
func _hint_clock() -> Array:
	var hints := []
	Events.reported.connect(func(what: StringName, data: Dictionary) -> void:
		if what == &"hint":
			hints.append([data.level, snappedf(App.session.trial.seconds(), 0.001)]))
	return hints


# -- skip, nudge, unpin -----------------------------------------------------------

func test_skip_drops_the_round_unscored_and_starts_the_next_block() -> void:
	var plan := plan_of(FIND, 3)
	plan.blocks.append(plan_of(FIND, 1, false, -1.0, load("res://content/views/edges.tres")).blocks[0])
	await boot(plan)
	var ended := record(Events.trial_ended)
	var reports := record(Events.reported)
	var blocks := record(Events.block_started)
	App.session.run()
	await until(_round_running)
	var trial := App.session.trial
	App.session.skip_block()
	expect(not trial.is_running(), "the round stops")
	expect(ended.is_empty(), "no trial_ended for a dropped round")
	expect(reports.any(func(args: Array) -> bool: return args[0] == &"round_abandoned" and args[1].round == 0), "logged as abandoned")
	expect(await until(_round_running), "the next block's round starts")
	expect_eq(blocks.size(), 2, "straight to block 2")
	expect_eq(App.reality.view.title, "Edges", "with its own view")
	expect_eq(Profile.level(FIND.skill), Profile.START_LEVEL, "the staircase did not move")


func test_skip_between_rounds_ends_the_block() -> void:
	var plan := plan_of(FIND, 3)
	plan.blocks[0].pause_between = 2.0
	await boot(plan)
	var started := record(Events.trial_started)
	var reports := record(Events.reported)
	App.session.run()
	await until(_round_running)
	await select((App.session.trial.get("_target") as Target).global_position)
	App.session.skip_block() # during the pause after round 0
	expect(await until(func() -> bool: return not App.session.running), "the session moves on and ends")
	expect_eq(started.size(), 1, "no further rounds")
	expect(not reports.any(func(args: Array) -> bool: return args[0] == &"round_abandoned"), "nothing was running to drop")


func test_nudge_pins_the_level_within_bounds_and_unpin_releases_it() -> void:
	await boot(plan_of(FIND, 4))
	var reports := record(Events.reported)
	App.session.run()
	await until(_round_is.bind(0))
	App.session.nudge(0.1)
	expect(is_equal_approx(App.session.level(), 0.4), "pinned 0.1 up")
	for i in 10:
		App.session.nudge(0.1)
	expect_eq(App.session.level(), 1.0, "never above 1")
	for i in 12:
		App.session.nudge(-0.1)
	expect_eq(App.session.level(), 0.0, "never below 0")
	await select((App.session.trial.get("_target") as Target).global_position)
	expect(await until(_round_is.bind(1)), "next round")
	expect_eq(App.session.trial.condition.level, 0.0, "runs at the pin")
	expect_eq(Profile.level(FIND.skill), Profile.START_LEVEL, "no staircase while pinned")
	App.session.unpin()
	expect(is_nan(App.session.pinned), "unpinned")
	expect_eq(App.session.level(), Profile.START_LEVEL, "back to the staircase")
	await select((App.session.trial.get("_target") as Target).global_position)
	expect(Profile.level(FIND.skill) == Profile.START_LEVEL, "one success keeps the level (2-up)")
	expect(reports.any(func(args: Array) -> bool: return args[0] == &"level"), "the staircase moves again")
	expect(reports.any(func(args: Array) -> bool: return args[0] == &"level_unpinned"), "unpin is logged")


func test_a_nudge_starts_from_a_blocks_fixed_difficulty() -> void:
	await boot(plan_of(FIND, 1, false, 0.7))
	App.session.run()
	await until(_round_running)
	App.session.nudge(-0.1)
	expect(is_equal_approx(App.session.pinned, 0.6), "0.1 below the block's 0.7")


# -- help clock and time limit ------------------------------------------------------

func test_hints_come_after_hint_after_and_fade_round_by_round() -> void:
	await boot(plan_of(FIND, 3))
	var hints := _hint_clock()
	App.session.run()
	for round_index in 3:
		await until(_round_is.bind(round_index), 60.0)
		hints.clear()
		var due := FIND.hint_after + FIND.hint_fade * round_index
		await wait(2.0 * due + 0.5)
		expect_eq(hints.map(func(hint: Array) -> int: return hint[0]), [1, 2], "round %d: two levels %s" % [round_index, hints])
		expect(absf(hints[0][1] - due) < 0.05, "round %d: first hint at %.1f s, got %s" % [round_index, due, hints[0][1]])
		expect(absf(hints[1][1] - 2.0 * due) < 0.05, "round %d: second at %.1f s" % [round_index, 2.0 * due])
		await select((App.session.trial.get("_target") as Target).global_position)


func test_a_wrong_try_restarts_the_clock_and_help_stops_at_max_hint() -> void:
	await boot(plan_of(FIND, 1))
	var hints := _hint_clock()
	App.session.run()
	await until(_round_running)
	await wait(5.0)
	var trial := App.session.trial
	await select((trial.get("_toys").keys()[1] as Target).global_position)
	var tried_at := trial.seconds()
	await wait(FIND.hint_after + 0.5)
	expect(absf(hints[0][1] - (tried_at + FIND.hint_after)) < 0.05, "hint %.1f s after the try, got %s" % [FIND.hint_after, hints])
	await raise_hand()
	await raise_hand()
	expect_eq(trial.hint_level, FIND.max_hint, "never above max_hint")
	expect_eq(hints.size(), 2, "the extra raise adds no level")


func test_time_limit_ends_the_round_as_a_failure_and_pauses_do_not_count() -> void:
	await boot(plan_of(FIND, 1))
	var ended := record(Events.trial_ended)
	var touched := record(Events.touched)
	App.session.run()
	await until(_round_running)
	await wait(10.0)
	App.hold_pause(&"facilitator", true)
	await wait(60.0)
	expect(ended.is_empty() and App.session.trial.is_running(), "paused time does not count")
	App.hold_pause(&"facilitator", false)
	await wait(FIND.time_limit - 10.0 + 0.2)
	expect_eq(ended.size(), 1, "ends at the limit")
	expect(not ended[0][1], "as a failure")
	expect_eq(ended[0][2].timed_out, true, "marked timed out")
	expect(absf(ended[0][2].seconds - FIND.time_limit) < 0.05, "after %.0f s of play: %s" % [FIND.time_limit, ended[0][2].seconds])
	expect(Profile.level(FIND.skill) < Profile.START_LEVEL, "a miss for the staircase")
	expect(touched.is_empty(), "nothing touched by accident")


func test_no_help_by_itself_when_hint_after_is_zero() -> void:
	var def: TrialDef = FIND.duplicate()
	def.hint_after = 0.0
	def.time_limit = 0.0
	await boot(plan_of(def, 1))
	var hints := _hint_clock()
	App.session.run()
	await until(_round_running)
	await wait(120.0)
	expect(hints.is_empty(), "none in two minutes")
	expect(App.session.trial.is_running(), "and no time limit either")
	await raise_hand(&"left")
	expect_eq(hints.size(), 1, "a raised hand still asks")
