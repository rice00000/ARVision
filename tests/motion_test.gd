extends TestCase
## The 3D motion task (trials/motion): the sweep classifier, then rounds played
## through SimInput. Particles do not simulate headless, so the shader is
## checked by the parameters the trial sets, not by pixels.

const MotionTrial := preload("res://trials/motion/motion_trial.gd")
const RANDOM := preload("res://trials/motion/motion.tres")
const COMPETING := preload("res://trials/motion/motion_competing.tres")
const HEADINGS := [&"right", &"left", &"toward", &"away"]
const SIDES := [&"right", &"left"]
## A sweep is reported once the hand has held still this long.
const SETTLE := 0.3

# -- the classifier -----------------------------------------------------------

func test_classifier_judges_valid_sweeps() -> void:
	for flow: Vector3 in MotionTrial.FLOWS:
		var result := _classify(flow * 0.2, flow)
		expect(result.valid and result.correct, "a sweep along %s is right" % flow)
		expect(is_zero_approx(result.angle_degrees), "no angle error along %s" % flow)
		expect(not _classify(-flow * 0.2, flow).correct, "the opposite sweep is wrong")
	expect(_classify(Vector3(0.2, 0.15, 0.0), Vector3.RIGHT).correct, "a 37 degree drift is within tolerance")
	expect(not _classify(Vector3(0.2, 0.18, 0.0), Vector3.RIGHT).correct, "a 42 degree drift is not")
	expect(not _classify(Vector3(0.0, 0.0, 0.2), Vector3.RIGHT).correct, "a sweep at right angles is wrong")


func test_classifier_calls_unusable_sweeps_invalid_not_wrong() -> void:
	expect_eq(_classify(Vector3.RIGHT * 0.05, Vector3.RIGHT).get("reason"), &"too_small", "a small sweep")
	expect_eq(_classify(Vector3.LEFT * 0.05, Vector3.RIGHT).get("reason"), &"too_small", "a small wrong-way sweep is still just small")
	expect_eq(_classify(Vector3.UP * 0.3, Vector3.RIGHT).get("reason"), &"vertical", "a hand raised")
	expect_eq(_classify(Vector3(0.1, -0.3, 0.0), Vector3.RIGHT).get("reason"), &"vertical", "a hand put down")
	expect(not _classify(Vector3.UP * 0.3, Vector3.RIGHT).has("correct"), "an invalid sweep is not judged")


# -- the task definitions -----------------------------------------------------

func test_two_defs_share_one_scene_and_split_the_skills() -> void:
	expect_eq(RANDOM.scene, COMPETING.scene, "same scene")
	expect(RANDOM.skill != COMPETING.skill, "separate staircases")
	expect_eq(RANDOM.condition(0.0, 0, false).value(&"competing"), 0.0, "random noise")
	expect_eq(COMPETING.condition(0.0, 0, false).value(&"competing"), 1.0, "competing flow")
	expect_eq(RANDOM.condition(0.0, 0, false).value(&"coherence"), 0.9, "easy end")
	expect(is_equal_approx(RANDOM.condition(1.0, 0, false).value(&"coherence"), 0.15), "hard end")
	expect(RANDOM.hint_after == 0.0 and RANDOM.max_hint == 1, "help only when asked, one level")


func test_competing_flow_keeps_a_strict_majority_at_every_level() -> void:
	for step in 11:
		var condition := COMPETING.condition(step / 10.0, 0, false)
		var signal_dots := roundi(condition.value(&"coherence") * condition.value(&"dots"))
		expect(signal_dots * 2 > condition.value(&"dots"), "level %d/10: %d of %d dots" % [step, signal_dots, condition.value(&"dots")])


func test_plans_run_the_motion_blocks_two_seconds_apart() -> void:
	var motion: SessionPlan = load("res://content/sessions/motion.tres")
	expect_eq(motion.blocks.map(func(block: Block) -> TrialDef: return block.trial), [RANDOM, COMPETING] as Array, "random then competing")
	var demo: SessionPlan = load("res://content/sessions/demo.tres")
	expect(demo.blocks.any(func(block: Block) -> bool: return block.trial == RANDOM), "the demo has a motion block")
	for block in motion.blocks + demo.blocks.filter(func(block: Block) -> bool: return block.trial == RANDOM):
		expect_eq(block.pause_between, 2.0, "time for the success animation")


# -- rounds -------------------------------------------------------------------

func test_correct_sweeps_in_every_direction_with_both_hands() -> void:
	await boot(plan_of(RANDOM, 8, false, 0.0, null, {&"direction": 1.0}))
	var ended := record(Events.trial_ended)
	App.session.run()
	for index in 8:
		expect(await until(_round_is.bind(index)), "round %d starts" % index)
		App.session.block.pins[&"direction"] = float((index + 1) % 4 + 1) # applies to the next round
		var heading := index % 4
		var side: StringName = SIDES[index / 4]
		var condition := App.session.trial.condition
		expect_eq(condition.value(&"heading"), HEADINGS[heading], "round %d heading" % index)
		expect_eq(condition.value(&"plane"), &"lateral" if heading < 2 else &"depth", "round %d plane" % index)
		await _sweep(side, MotionTrial.FLOWS[heading])
		expect_eq(ended.size(), index + 1, "round %d scored" % index)
		var data: Dictionary = ended[index][2]
		expect(ended[index][1], "%s %s is right" % [side, HEADINGS[heading]])
		expect_eq(data.tries, 0, "no wrong tries")
		expect_eq(data.first_attempt_correct, true, "first attempt correct")
		expect_eq(data.attempts.size(), 1, "one attempt")
		expect_eq(data.attempts[0].hand, side, "the hand that swept")
		expect(data.angle_degrees < 1.0, "angle error is logged")


func test_direction_is_random_across_rounds_when_not_pinned() -> void:
	await boot(plan_of(RANDOM, 1))
	App.session.run()
	await until(_round_is.bind(0))
	var seen := {}
	for i in 40:
		var condition := RANDOM.condition(0.5, i, false)
		App.session.trial.begin(condition)
		seen[condition.value(&"heading")] = true
	expect_eq(seen.keys().size(), 4, "all four headings come up: %s" % [seen.keys()])


func test_wrong_sweeps_count_tries_and_the_flow_stays() -> void:
	await boot(plan_of(RANDOM, 1, false, 0.0, null, {&"direction": 1.0}))
	var ended := record(Events.trial_ended)
	var feedback := record(Events.feedback)
	App.session.run()
	await until(_round_is.bind(0))
	var trial := App.session.trial
	var seed_before: int = trial.condition.value(&"seed")
	await _sweep(&"right", Vector3.LEFT)
	expect(trial.is_running(), "a wrong sweep keeps the round going")
	expect_eq(trial.tries, 1, "counted as a try")
	expect_eq(feedback.back()[0], &"bad", "bad feedback")
	await _sweep(&"left", Vector3.BACK)
	expect_eq(trial.tries, 2, "a sweep at right angles is wrong too")
	expect_eq(trial.condition.value(&"seed"), seed_before, "same stimulus on retries")
	await _sweep(&"right", Vector3.RIGHT)
	expect_eq(ended.size(), 1, "the right sweep ends the round")
	var data: Dictionary = ended[0][2]
	expect(ended[0][1], "eventually right")
	expect_eq(feedback.back()[0], &"good", "good feedback")
	expect_eq(data.tries, 2, "two tries")
	expect_eq(data.first_attempt_correct, false, "the first attempt was wrong")
	expect_eq(data.attempts.map(func(attempt: Dictionary) -> bool: return attempt.correct), [false, false, true] as Array, "every valid attempt is kept")
	expect_eq(data.invalid_gestures, 0, "none invalid")
	expect(data.first_onset_seconds < data.response_onset_seconds, "onset of the first attempt differs from the last")
	expect(data.gesture_seconds > 0.2 and data.gesture_seconds < 0.5, "the sweep's own duration is logged: %s" % data.gesture_seconds)


func test_unusable_sweeps_are_invalid_not_tries() -> void:
	await boot(plan_of(RANDOM, 1, false, 0.0, null, {&"direction": 1.0}))
	var ended := record(Events.trial_ended)
	var feedback := record(Events.feedback)
	var reports := record(Events.reported)
	var said := record(Events.said)
	App.session.run()
	await until(_round_is.bind(0))
	var trial := App.session.trial
	await _sweep(&"right", Vector3.RIGHT, 0.05)
	await _sweep(&"right", Vector3.UP, 0.3)
	await _sweep(&"left", Vector3.LEFT, 0.05)
	expect(trial.is_running(), "invalid sweeps leave the round going")
	expect_eq(trial.tries, 0, "no tries")
	expect(feedback.is_empty(), "no good or bad feedback")
	var invalid := reports.filter(func(args: Array) -> bool: return args[0] == &"motion_invalid")
	expect_eq(invalid.map(func(args: Array) -> StringName: return args[1].reason), [&"too_small", &"vertical", &"too_small"] as Array, "reasons")
	expect_eq(said.filter(func(args: Array) -> bool: return args[0] == "Sweep your hand a little farther.").size(), 2, "small sweeps are answered, a raised hand is not")
	expect(not reports.any(func(args: Array) -> bool: return args[0] == &"motion_attempt"), "no valid attempt yet")
	await _sweep(&"right", Vector3.RIGHT)
	expect_eq(ended[0][2].invalid_gestures, 3, "invalid sweeps are totalled")
	expect_eq(ended[0][2].first_attempt_correct, true, "invalid sweeps do not spoil the first attempt")


func test_help_makes_every_dot_coherent_and_is_logged() -> void:
	await boot(plan_of(RANDOM, 1, false, 1.0, null, {&"direction": 1.0}))
	var ended := record(Events.trial_ended)
	var reports := record(Events.reported)
	var feedback := record(Events.feedback)
	App.session.run()
	await until(_round_is.bind(0))
	var trial := App.session.trial
	var material := _material()
	expect_eq(trial.condition.value(&"signal_dots"), 30, "0.15 of 200 dots")
	expect_eq(material.get_shader_parameter(&"signal_count"), 30, "shown without help")
	await _sweep(&"right", Vector3.LEFT)
	await raise_hand(&"left")
	expect_eq(trial.hint_level, 1, "a raised hand asks for help")
	expect_eq(material.get_shader_parameter(&"signal_count"), 200, "every dot follows the flow")
	expect_eq(trial.condition.value(&"signal_dots"), 30, "the round's condition keeps what it started at")
	expect_eq(feedback.back()[0], &"hint", "hint feedback")
	await raise_hand(&"left")
	expect_eq(reports.filter(func(args: Array) -> bool: return args[0] == &"hint").size(), 1, "one hint level only")
	await _sweep(&"right", Vector3.RIGHT)
	var data: Dictionary = ended[0][2]
	expect_eq(data.hint, 1, "help is logged")
	expect_eq(data.attempts.map(func(attempt: Dictionary) -> int: return attempt.help), [0, 1] as Array, "help level of each attempt")
	expect_eq(data.attempts.map(func(attempt: Dictionary) -> float: return attempt.coherence_shown), [0.15, 1.0] as Array, "coherence shown with each attempt")


func test_probe_rounds_get_no_help() -> void:
	await boot(plan_of(RANDOM, 1, true, 0.5))
	var reports := record(Events.reported)
	App.session.run()
	await until(_round_is.bind(0))
	var before: int = _material().get_shader_parameter(&"signal_count")
	await raise_hand(&"left")
	expect_eq(App.session.trial.hint_level, 0, "no hint level")
	expect_eq(_material().get_shader_parameter(&"signal_count"), before, "dots unchanged")
	expect(not reports.any(func(args: Array) -> bool: return args[0] == &"hint"), "no hint logged")


func test_pause_cancels_an_unfinished_sweep() -> void:
	await boot(plan_of(RANDOM, 1, false, 0.0, null, {&"direction": 1.0}))
	var ended := record(Events.trial_ended)
	var reports := record(Events.reported)
	App.session.run()
	await until(_round_is.bind(0))
	var trial := App.session.trial
	var start := App.head().global_position + Vector3(0.2, -0.4, -0.4)
	var end: Vector3 = start + (trial.get("_frame") as Transform3D).basis.x * 0.25
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, start))
	await frames(2)
	await _glide(&"right", start, start.lerp(end, 0.5), 0.15)
	input.menu()
	expect(get_tree().paused, "the panel pauses play")
	await _glide(&"right", start.lerp(end, 0.5), end, 0.15) # finished while paused
	await wait(SETTLE)
	input.menu()
	expect(not get_tree().paused, "closed again")
	await wait(SETTLE)
	expect(trial.is_running() and ended.is_empty(), "the sweep through the pause scored nothing")
	expect(not reports.any(func(args: Array) -> bool: return String(args[0]).begins_with("motion_")), "and was not judged as invalid either")
	await _sweep(&"left", Vector3.RIGHT)
	expect_eq(ended.size(), 1, "the next sweep still works")


func test_tracking_loss_cancels_an_unfinished_sweep() -> void:
	await boot(plan_of(RANDOM, 1, false, 0.0, null, {&"direction": 1.0}))
	var ended := record(Events.trial_ended)
	var reports := record(Events.reported)
	App.session.run()
	await until(_round_is.bind(0))
	var trial := App.session.trial
	var start := App.head().global_position + Vector3(0.2, -0.4, -0.4)
	var end: Vector3 = start + (trial.get("_frame") as Transform3D).basis.x * 0.25
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, start))
	await frames(2)
	await _glide(&"right", start, start.lerp(end, 0.5), 0.15)
	input.track(&"right", false)
	await frames(2)
	input.track(&"right", true)
	await _glide(&"right", start.lerp(end, 0.5), end, 1.0) # the hand creeps on to where it was going
	await wait(SETTLE)
	expect(trial.is_running() and ended.is_empty(), "a sweep through a tracking loss scores nothing")
	expect(not reports.any(func(args: Array) -> bool: return String(args[0]).begins_with("motion_")), "and is not judged")
	# The other hand losing tracking does not matter.
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, start))
	await frames(2)
	await _glide(&"right", start, start.lerp(end, 0.5), 0.15)
	input.track(&"left", false)
	await _glide(&"right", start.lerp(end, 0.5), end, 0.15)
	await wait(SETTLE)
	expect_eq(ended.size(), 1, "the other hand's tracking loss changes nothing")


# -- stimulus -----------------------------------------------------------------

func test_cloud_is_placed_ahead_and_judged_in_its_frozen_frame() -> void:
	await boot(plan_of(RANDOM, 1, false, 0.0, null, {&"direction": 1.0}))
	var ended := record(Events.trial_ended)
	input.look_at(App.head().global_position + Vector3(1, 0, -1))
	await frames(1)
	var eye := App.head().global_position
	var forward := Vector3(-App.head().global_basis.z.x, 0.0, -App.head().global_basis.z.z).normalized()
	App.session.run()
	await until(_round_is.bind(0))
	var trial := App.session.trial
	var cloud: GPUParticles3D = trial.get_node(^"Cloud")
	expect((cloud.global_position - (eye + forward * 2.2)).length() < 0.01, "2.2 m ahead at eye height")
	expect((-cloud.global_basis.z).dot(forward) > 0.999, "its -Z points away from the child")
	expect_eq(cloud.amount, 200, "dot count")
	expect_eq(trial.focus_point(), cloud.global_position, "spotlight views centre on the cloud")
	# Turn the head away: the cloud and its right stay where they were.
	var frozen := cloud.global_transform
	input.look_at(eye + Vector3(-1, 0, -1))
	await frames(1)
	expect(cloud.global_transform.is_equal_approx(frozen), "the cloud stays put")
	var start := eye + Vector3(0.2, -0.4, -0.4)
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, start))
	await frames(2)
	await _glide(&"right", start, start + cloud.global_basis.x * 0.25, 0.3)
	await wait(SETTLE)
	expect(ended.size() == 1 and ended[0][1], "right is the cloud's right, not the turned head's")


func test_shader_gets_the_round_exactly() -> void:
	for def: TrialDef in [RANDOM, COMPETING]:
		await boot(plan_of(def, 1, false, 0.5))
		App.session.run()
		await until(_round_is.bind(0))
		var trial := App.session.trial
		var condition: TrialCondition = trial.condition
		var material := _material()
		var heading := HEADINGS.find(condition.value(&"heading"))
		expect_eq(material.get_shader_parameter(&"flow_direction"), MotionTrial.FLOWS[heading], "%s flow" % def.id)
		expect_eq(material.get_shader_parameter(&"competing_flow"), def == COMPETING, "%s noise model" % def.id)
		expect_eq(material.get_shader_parameter(&"signal_count"), roundi(condition.value(&"coherence") * 200.0), "%s exact signal count" % def.id)
		expect_eq(material.get_shader_parameter(&"dot_count"), 200, "%s dots" % def.id)
		expect_eq(material.get_shader_parameter(&"trial_seed"), condition.value(&"seed"), "%s seed" % def.id)
		expect(is_equal_approx(material.get_shader_parameter(&"speed"), 0.3), "%s speed" % def.id)
		expect(is_equal_approx(material.get_shader_parameter(&"dot_lifetime"), 0.8), "%s lifetime" % def.id)
		expect_eq(material.get_shader_parameter(&"half_size"), Vector3(0.8, 0.5, 0.8), "%s cloud size" % def.id)
		expect_eq(material.get_shader_parameter(&"alignment"), 0.0, "%s no alignment before an answer" % def.id)
		expect_eq(condition.value(&"flow"), MotionTrial.FLOWS[heading], "%s flow is logged" % def.id)
		await shutdown()


func test_success_aligns_the_dots_until_the_next_round() -> void:
	var plan := plan_of(RANDOM, 2, false, 0.0, null, {&"direction": 1.0})
	plan.blocks[0].pause_between = 2.0
	await boot(plan)
	App.session.run()
	await until(_round_is.bind(0))
	var material := _material()
	await _sweep(&"right", Vector3.LEFT)
	expect_eq(material.get_shader_parameter(&"alignment"), 0.0, "a wrong answer never aligns the dots")
	await _sweep(&"right", Vector3.RIGHT)
	expect(not App.session.trial.is_running(), "round over")
	await wait(1.0)
	expect_eq(material.get_shader_parameter(&"alignment"), 1.0, "aligned and still aligned after the round ended")
	expect(await until(_round_is.bind(1), 3.0), "the next round starts after the pause")
	expect_eq(_material().get_shader_parameter(&"alignment"), 0.0, "reset by the next round's setup")


func test_round_data_is_valid_json() -> void:
	await boot(plan_of(RANDOM, 1, false, 0.0, null, {&"direction": 3.0}))
	var ended := record(Events.trial_ended)
	App.session.run()
	await until(_round_is.bind(0))
	await _sweep(&"right", Vector3.BACK)
	var data: Dictionary = ended[0][2]
	var read = JSON.parse_string(JSON.stringify(Log.plain(data)))
	expect(read is Dictionary, "the log line parses")
	expect_eq(read.values.heading, "toward", "heading")
	expect_eq(read.values.plane, "depth", "plane")
	expect_eq(read.values.signal_dots, 180, "signal dots")
	expect_eq(read.values.competing, 0.0, "noise model")
	expect_eq(read.skill, "global_motion", "skill")
	expect(read.attempts[0].direction is Array, "directions are arrays")


# -- helpers ------------------------------------------------------------------

func _classify(displacement: Vector3, expected: Vector3) -> Dictionary:
	return MotionTrial.classify(displacement, expected, 0.12, 40.0)


func _round_is(index: int) -> bool:
	return App.session.trial != null and App.session.trial.is_running() and App.session.trial.condition.round_index == index


func _material() -> ShaderMaterial:
	return (App.session.trial.get_node(^"Cloud") as GPUParticles3D).process_material


## Sweeps [param side]'s hand [param length] metres along [param flow] (in the
## cloud's frame) at 0.8 m/s, then holds it still until judged.
func _sweep(side: StringName, flow: Vector3, length := 0.25) -> void:
	var seconds := length / 0.8
	var frame: Transform3D = App.session.trial.get("_frame")
	var start := App.head().global_position + Vector3(-0.2 if side == &"left" else 0.2, -0.4, -0.4)
	input.set_hand(side, Transform3D(Basis.IDENTITY, start)) # a jump: the rig never takes it for a sweep
	await frames(2)
	await _glide(side, start, start + frame.basis * flow * length, seconds)
	await wait(SETTLE)


## Moves a hand from [param from] to [param to] over [param seconds], a step per physics tick.
func _glide(side: StringName, from: Vector3, to: Vector3, seconds: float) -> void:
	var steps := maxi(1, roundi(seconds * Engine.physics_ticks_per_second))
	for i in steps:
		input.set_hand(side, Transform3D(Basis.IDENTITY, from.lerp(to, float(i + 1) / steps)))
		await get_tree().physics_frame
