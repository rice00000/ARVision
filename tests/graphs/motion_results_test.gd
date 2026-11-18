extends TestCase
## Results of the motion game rounds (modules/results/motion_results.gd): first attempt only,
## assisted and stopped rounds never scored, 10 % bands with Wilson intervals, groups kept apart.

const MotionTrial := preload("res://trials/motion/motion_trial.gd")
const RANDOM := preload("res://trials/motion/motion.tres")


## A log-version-2 round as the game logs it. [param first]: {} = no answer.
static func _won(serial: int, first: Dictionary, mode := "play", pinned := false, trial := "motion_demo") -> Dictionary:
	var attempts := [first] if not first.is_empty() else []
	return {type = "trial_end", success = true, data = {trial = trial, round = serial, log_version = 2,
		session_mode = mode, level_pinned = pinned, level_source = "pinned" if pinned else "fixed",
		round_serial = serial, heading = "left", coherence_start = first.get("coherence_shown", 0.5),
		attempts = attempts, first_attempt_correct = first.get("correct", false)}}


static func _stopped(serial: int, reason: String, first := {}, mode := "play") -> Dictionary:
	return {type = "event", what = "motion_round_interrupted", data = {trial = "motion_demo", round = serial,
		coherence_shown = 0.6, help = 0, seconds_shown = 4.2, reason = reason, attempts = 0 if first.is_empty() else 1,
		first_attempt = first, log_version = 2, session_mode = mode, level_pinned = false, level_source = "fixed",
		round_serial = serial, coherence_start = 0.6, heading = "right"}}


static func _attempt(correct: bool, coherence: float, help := 0, onset := 2.0) -> Dictionary:
	return {correct = correct, coherence_shown = coherence, help = help, onset_seconds = onset}


func test_only_the_first_attempt_counts() -> void:
	var won := _won(1, _attempt(false, 0.6))
	won.data.attempts.append(_attempt(true, 0.6)) # retried until right
	var rounds := MotionResults.rounds_in([won])
	expect_eq(rounds.size(), 1, "one round")
	expect_eq(MotionResults.outcome(rounds[0]), "wrong", "scored on its first attempt, not the win")
	expect_eq(MotionResults.summary(rounds), {correct = 0, eligible = 1, assisted = 0, stopped = 0, rounds = 1}, "0 of 1")


func test_help_before_the_first_sweep_makes_it_assisted_never_right_or_wrong() -> void:
	var helped := _won(1, _attempt(true, 1.0, 1)) # help on: every dot follows the flow
	helped.data.coherence_start = 0.5
	var rounds := MotionResults.rounds_in([helped, _won(2, _attempt(true, 0.6))])
	expect_eq(MotionResults.outcome(rounds[0]), "assisted", "helped")
	expect(not rounds[0].eligible, "not eligible")
	expect(is_equal_approx(rounds[0].coherence_start, 0.5), "labelled with the coherence before help")
	var s := MotionResults.summary(rounds)
	expect(s.correct == 1 and s.eligible == 1 and s.assisted == 1, "1 of 1 counted, 1 helped: %s" % s)
	expect_eq(MotionResults.median_first_sweep(rounds).n, 1, "the median leaves the helped round out")


func test_a_round_with_no_answer_is_a_gap_and_one_with_an_answer_keeps_it() -> void:
	var rounds := MotionResults.rounds_in([_stopped(1, "skipped"), _stopped(2, "left", _attempt(true, 0.6, 0, 3.0))])
	expect_eq(MotionResults.outcome(rounds[0]), "stopped", "no answer: stopped")
	expect_eq(rounds[0].reason, "skipped", "why")
	expect_eq(rounds[0].onset_s, null, "no time, never zero")
	expect_eq(MotionResults.outcome(rounds[1]), "correct", "its first answer still counts")
	var s := MotionResults.summary(rounds)
	expect(s.stopped == 1 and s.eligible == 1, "%s" % s)


func test_a_timed_out_round_joins_its_two_lines() -> void:
	var timed_out := {type = "trial_end", success = false, data = {trial = "motion_demo", round = 0, timed_out = true,
		log_version = 2, session_mode = "play", level_pinned = false, round_serial = 7, heading = "right", coherence_start = 0.6}}
	var rounds := MotionResults.rounds_in([_stopped(7, "timed_out"), timed_out])
	expect_eq(rounds.size(), 1, "one round, not two")
	expect_eq(rounds[0].status, "stopped", "stopped")
	expect_eq(rounds[0].reason, "timed_out", "timed out")


func test_groups_are_kept_apart() -> void:
	var older := {type = "trial_end", success = true, data = {trial = "motion", round = 0, first_attempt_correct = true,
		values = {signal_dots = 27, dots = 30, heading = "left"}, attempts = [_attempt(true, 0.9)]}}
	var rounds := MotionResults.rounds_in([_won(1, _attempt(true, 0.6)), _won(2, _attempt(true, 0.6), "dev"),
		_won(3, _attempt(true, 0.6), "play", true), _won(4, _attempt(true, 0.6), "dev", true), older])
	expect_eq(rounds.map(func(r: Dictionary) -> String: return r.group), ["play", "dev", "pinned", "dev", "unknown"],
		"play, dev, pinned, dev wins over pinned, version 1 is unknown")
	expect_eq(MotionResults.group_counts(rounds), {play = 1, pinned = 1, dev = 2, unknown = 1}, "counts")
	expect_eq(MotionResults.in_group(rounds, "play").size(), 1, "the play view has only play rounds")
	expect(is_equal_approx(rounds[4].coherence_start, 0.9), "version 1 coherence from its values")
	expect_eq(rounds[4].heading, "left", "version 1 heading from its values")


func test_wilson_matches_the_lab() -> void:
	var ci := MotionResults.wilson(3, 6)
	expect(absf(ci[0] - 0.188) < 0.002 and absf(ci[1] - 0.812) < 0.002, "3/6: 19–81 %%, as the lab: %s" % [ci])
	var all_right := MotionResults.wilson(2, 2)
	expect(all_right[1] == 1.0 and all_right[0] > 0.3 and all_right[0] < 0.4, "2/2 stays within 0–100 %%: %s" % [all_right])
	expect(MotionResults.wilson(0, 0).is_empty(), "no interval with no rounds")


func test_coherence_is_binned_in_ten_percent_bands_per_task() -> void:
	expect_eq([0.15, 0.199, 0.2, 0.9, 0.933, 1.0].map(MotionResults.band), [1, 1, 2, 9, 9, 9], "bands")
	var lines := [_won(1, _attempt(true, 0.9)), _won(2, _attempt(false, 0.93)), _won(3, _attempt(true, 0.5)),
		_won(4, _attempt(true, 0.55)), _won(5, _attempt(true, 1.0, 1)), _won(6, _attempt(true, 0.9), "play", false, "motion")]
	var series := MotionResults.coherence_series(MotionResults.rounds_in(lines))
	expect_eq(series.keys(), ["motion", "motion_demo"], "one series per task")
	var demo: Array = series.motion_demo
	expect_eq(demo.map(func(p: Dictionary) -> int: return p.band), [5, 9], "50–59 and 90–100, the helped round left out")
	expect(demo[0].k == 2 and demo[0].n == 2, "2/2 at 50–59 %")
	expect(demo[1].k == 1 and demo[1].n == 2 and demo[1].ci.size() == 2, "1/2 at 90–100 %, with an interval")
	expect_eq(demo[1].hi_pct, 100, "the top band includes 100 %")


func test_a_real_round_reads_back_from_the_log() -> void:
	await boot(plan_of(RANDOM, 2, false, 0.4, null, {&"direction": 1.0}))
	App.session.run()
	await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running())
	App.session.trial.escalate()
	await until(func() -> bool: return App.session.trial.seconds() > 1.0)
	App.session.skip_block()
	await frames(2)
	var rounds := MotionResults.load_rounds([Log.file_path])
	expect_eq(rounds.size(), 1, "the skipped round, from the log file")
	if rounds.is_empty():
		return
	expect_eq(rounds[0].status, "stopped", "no answer")
	expect_eq(rounds[0].group, "dev", "tests run in dev mode")
	expect_eq(rounds[0].trial, "motion", "the task")
	expect(rounds[0].coherence_start < 1.0, "the coherence before help: %s" % rounds[0].coherence_start)
	expect_eq(MotionResults.visit_paths(Log.file_path.get_base_dir()), [Log.file_path], "this visit's file is listed")
