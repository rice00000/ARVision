extends TestCase
## A short session and the wrong-pick-to-help flow in the simulated room.

const FIND := preload("res://trials/find/find.tres")


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
	await raise_hand()
	expect_eq(trial.hint_level, 1, "a raised hand asks for the first hint")


func _round_running() -> bool:
	return App.session.trial != null and App.session.trial.is_running()
