extends TestCase
## The motion log additions (Graphs chat, Nov 17): every line of a round is stamped with the log
## version, the play mode and whether the level was pinned, and a round that ends unwon logs
## motion_round_interrupted. Log only: the round itself plays as before (tests/motion_test.gd).

const MotionTrial := preload("res://trials/motion/motion_trial.gd")
const RANDOM := preload("res://trials/motion/motion.tres")
const SETTLE := 0.55


func test_a_won_round_and_its_attempts_carry_the_stamp() -> void:
	await boot(plan_of(RANDOM, 1, false, 0.0, null, {&"direction": 1.0}))
	var ended := record(Events.trial_ended)
	var reports := record(Events.reported)
	App.session.run()
	await until(_round_is.bind(0))
	await _sweep(&"right", Vector3.LEFT)
	await _sweep(&"right", Vector3.RIGHT)
	expect_eq(ended.size(), 1, "one round")
	var data: Dictionary = ended[0][2]
	expect_eq(data.log_version, MotionTrial.LOG_VERSION, "log version on the round")
	expect_eq(data.session_mode, "dev", "tests run in dev mode")
	expect_eq(data.level_pinned, false, "not pinned")
	expect_eq(data.level_source, "fixed", "the block's own difficulty")
	expect(data.round_serial > 0, "a round number")
	expect_eq(data.heading, &"right", "the heading")
	var attempts := _reports(reports, &"motion_attempt")
	expect_eq(attempts.size(), 2, "two attempts")
	for attempt: Dictionary in attempts:
		expect_eq(attempt.log_version, MotionTrial.LOG_VERSION, "attempt stamped")
		expect_eq(attempt.round_serial, data.round_serial, "attempts join their round")
	expect(_reports(reports, &"motion_round_interrupted").is_empty(), "a won round is not interrupted")


func test_rounds_get_new_numbers_and_the_staircase_is_named() -> void:
	await boot(plan_of(RANDOM, 2, false, -1.0, null, {&"direction": 1.0}))
	var ended := record(Events.trial_ended)
	App.session.run()
	await until(_round_is.bind(0))
	await _sweep(&"right", Vector3.RIGHT)
	await until(_round_is.bind(1))
	await _sweep(&"right", Vector3.RIGHT)
	expect_eq(ended.size(), 2, "two rounds")
	expect_eq(ended[0][2].level_source, "staircase", "no pin, no fixed difficulty")
	expect_eq(ended[1][2].round_serial, ended[0][2].round_serial + 1, "the next round, the next number")


func test_a_pinned_level_is_logged_on_the_round() -> void:
	await boot(plan_of(RANDOM, 2, false, -1.0, null, {&"direction": 1.0}))
	var ended := record(Events.trial_ended)
	App.session.run()
	await until(_round_is.bind(0))
	App.session.pin(0.5, {source = &"test"})
	await _sweep(&"right", Vector3.RIGHT)
	expect_eq(ended[0][2].level_pinned, true, "pinned while it ran")
	expect_eq(ended[0][2].level_source, "pinned", "named pinned")


func test_a_skipped_round_is_logged_as_interrupted() -> void:
	await boot(plan_of(RANDOM, 3, false, 0.4, null, {&"direction": 1.0}))
	var reports := record(Events.reported)
	App.session.run()
	await until(_round_is.bind(0))
	var trial := App.session.trial
	await wait(1.0)
	var shown: float = float(trial.condition.value(&"signal_dots")) / trial.condition.value(&"dots")
	App.session.skip_block()
	var lines := _reports(reports, &"motion_round_interrupted")
	expect_eq(lines.size(), 1, "one interrupted line")
	var line: Dictionary = lines[0]
	expect_eq(line.reason, &"skipped", "skipped by the adult")
	expect_eq(line.trial, &"motion", "which task")
	expect_eq(line.round, 0, "which round")
	expect(is_equal_approx(line.coherence_shown, shown), "the coherence on screen: %s" % line.coherence_shown)
	expect_eq(line.help, 0, "no help")
	expect(line.seconds_shown >= 0.9 and line.seconds_shown < 1.5, "about a second shown: %s" % line.seconds_shown)
	expect_eq(line.attempts, 0, "no answer")
	expect(line.first_attempt.is_empty(), "no first attempt")
	expect_eq(line.log_version, MotionTrial.LOG_VERSION, "stamped")
	expect(_reports(reports, &"round_abandoned").size() == 1, "Wei's own line is still there")


func test_an_interrupted_round_keeps_its_first_answer_and_help() -> void:
	await boot(plan_of(RANDOM, 1, false, 0.4, null, {&"direction": 1.0}))
	var reports := record(Events.reported)
	App.session.run()
	await until(_round_is.bind(0))
	await _sweep(&"right", Vector3.LEFT)
	App.session.trial.escalate()
	App.session.skip_block()
	var line: Dictionary = _reports(reports, &"motion_round_interrupted")[0]
	expect_eq(line.attempts, 1, "one answer")
	expect_eq(line.first_attempt.correct, false, "it was wrong")
	expect_eq(line.first_attempt.help, 0, "given before the help")
	expect_eq(line.help, 1, "help by the end")
	expect(is_equal_approx(line.coherence_shown, 1.0), "with help every dot follows the flow")
	expect(line.coherence_start < 1.0, "it started lower: %s" % line.coherence_start)


func test_help_before_the_first_sweep_is_on_the_attempt() -> void:
	await boot(plan_of(RANDOM, 1, false, 0.4, null, {&"direction": 1.0}))
	var reports := record(Events.reported)
	App.session.run()
	await until(_round_is.bind(0))
	App.session.trial.escalate()
	await _sweep(&"right", Vector3.RIGHT)
	var attempt: Dictionary = _reports(reports, &"motion_attempt")[0]
	expect_eq(attempt.help, 1, "the first attempt was helped")


func test_a_timed_out_round_is_logged_as_interrupted() -> void:
	await boot(plan_of(RANDOM, 1, false, 0.0, null, {&"direction": 1.0}))
	var reports := record(Events.reported)
	var ended := record(Events.trial_ended)
	App.session.run()
	await until(_round_is.bind(0))
	var def: TrialDef = App.session.trial.def.duplicate()
	def.time_limit = 1.0
	App.session.trial.def = def
	await until(func() -> bool: return not ended.is_empty())
	var line: Dictionary = _reports(reports, &"motion_round_interrupted")[0]
	expect_eq(line.reason, &"timed_out", "timed out")
	expect_eq(ended[0][2].log_version, MotionTrial.LOG_VERSION, "the round's own line is stamped too")


func test_leaving_mid_round_is_logged_as_interrupted() -> void:
	await boot(plan_of(RANDOM, 1, false, 0.0, null, {&"direction": 1.0}))
	var reports := record(Events.reported)
	App.session.run()
	await until(_round_is.bind(0))
	var trial := App.session.trial
	trial.get_parent().remove_child(trial)
	var lines := _reports(reports, &"motion_round_interrupted")
	expect_eq(lines.size(), 1, "logged as the round leaves the tree")
	expect_eq(lines[0].reason if not lines.is_empty() else &"", &"left", "left")
	App.stage.add_child(trial) # back, so the session can finish it and the test shuts down cleanly
	App.session.skip_block()


func test_play_mode_is_stamped_as_play() -> void:
	await boot(plan_of(RANDOM, 1, false, 0.0, null, {&"direction": 1.0}))
	PlayMode.set_dev(false, "test")
	var ended := record(Events.trial_ended)
	App.session.run()
	await until(_round_is.bind(0))
	await _sweep(&"right", Vector3.RIGHT)
	expect_eq(ended[0][2].session_mode, "play", "play mode on the round")
	PlayMode.reset_for_tests()


# -- helpers (as in tests/motion_test.gd) ----------------------------------------

func _reports(reports: Array, what: StringName) -> Array:
	return reports.filter(func(args: Array) -> bool: return args[0] == what).map(func(args: Array) -> Dictionary: return args[1])


func _round_is(index: int) -> bool:
	return App.session.trial != null and App.session.trial.is_running() and App.session.trial.condition.round_index == index


func _sweep(side: StringName, flow: Vector3, length := 0.25) -> void:
	var seconds := length / 0.8
	var trial := App.session.trial
	await until(func() -> bool: return not trial.is_running() or trial.seconds() >= MotionTrial.ARM_SECONDS)
	var frame: Transform3D = trial.get("_frame")
	var start := App.head().global_position + Vector3(-0.2 if side == &"left" else 0.2, -0.4, -0.4)
	input.set_hand(side, Transform3D(Basis.IDENTITY, start))
	await frames(2)
	await _glide(side, start, start + frame.basis * flow * length, seconds)
	await wait(SETTLE)


func _glide(side: StringName, from: Vector3, to: Vector3, seconds: float) -> void:
	var steps := maxi(1, roundi(seconds * Engine.physics_ticks_per_second))
	for i in steps:
		input.set_hand(side, Transform3D(Basis.IDENTITY, from.lerp(to, float(i + 1) / steps)))
		await get_tree().physics_frame
