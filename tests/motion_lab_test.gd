extends TestCase

const Lab := preload("res://tools/motion_lab/motion_lab.gd")

func test_flat_geometry_is_explicit_and_shared_settings_are_preserved() -> void:
	var volume: Dictionary = Lab.settings(false, 0.7, -1.0)
	var flat: Dictionary = Lab.settings(true, 0.7, -1.0)
	expect_eq(volume.half_size, Vector3(0.8, 0.5, 0.8), "baseline volume")
	expect_eq(flat.half_size, Vector3(0.8, 0.5, 0.0), "coplanar centres")
	for key: String in ["dots", "distance", "speed", "dot_lifetime", "radius", "seed", "signal_count", "flow"]:
		expect_eq(flat[key], volume[key], "same %s" % key)
	expect_eq(flat.dots, 200, "current dot count")
	expect_eq(flat.signal_count, 140, "exact selected coherence")
	expect_eq(flat.flow, Vector3.LEFT, "selected heading")
	expect_eq(volume.noise_dimensions, 3, "volume noise")
	expect_eq(flat.noise_dimensions, 2, "flat noise")

func test_mode_switch_does_not_reset_selected_condition() -> void:
	var lab := Lab.new()
	add_child(lab)
	lab.coherence = 0.4
	lab.heading = -1.0
	lab.set_mode(true)
	expect_eq(lab.current.signal_count, 80, "preserve coherence")
	expect_eq(lab.current.flow, Vector3.LEFT, "preserve direction")
	expect_eq(lab.cloud.process_material.get_shader_parameter("signal_count"), 80, "shader signal count")
	expect_eq(lab.current.noise_dimensions, 2, "flat mode selected")
	lab.set_mode(false)
	expect(is_equal_approx(lab.current.half_size.z, 0.8), "restore volume")
	expect_eq(lab.current.signal_count, 80, "condition still preserved")
	lab.queue_free()
	await frames(1)


# --- Trial block (Nov 9 plan): flow and record, driven by a fake clock -------------------

const TrialBlock := preload("res://tools/motion_lab/trial_block.gd")
const BlockConfig := preload("res://tools/motion_lab/block_config.gd")
const SECOND := 1000000
const Results := preload("res://tools/motion_lab/results.gd")
## Synthetic fixtures live in their own folder and dataset and never enter a real review dataset.
const SYNTHETIC := "SYNTHETIC-FIXTURE-not-participant-data"


func _flow(seed := 7) -> RefCounted:
	var flow := TrialBlock.new()
	flow.save_dir = "user://motion_lab_test_records"
	flow.begin(BlockConfig.preview(0.7), BlockConfig.timing(), 0, seed, {test = true}, SYNTHETIC)
	return flow


## Runs prepare and exposure (1 s each) from [param t]; returns the time the answer opens.
func _to_respond(flow: RefCounted, t: int) -> int:
	t += SECOND
	flow.tick(t)
	t += SECOND
	flow.tick(t)
	return t


func test_block_states_run_in_order_and_accept_one_answer() -> void:
	var flow := _flow()
	var phases: Array = []
	flow.phase_changed.connect(func(p: StringName) -> void: phases.append(p))
	var shown: Array = []
	flow.exposure_requested.connect(func(a: Dictionary) -> void: shown.append(a.id))
	expect(flow.start_block(0), "block starts from the menu")
	expect_eq(flow.phase, &"prepare", "prepare first")
	flow.tick(SECOND / 2)
	expect_eq(flow.phase, &"prepare", "still preparing at 0.5 s")
	var t := _to_respond(flow, 0)
	expect_eq(flow.phase, &"respond", "dots off, answer open")
	expect_eq(shown, ["B1-T1-A1"], "one exposure requested")
	expect_eq(flow.answer(-1, "test", t + 300000), &"accepted", "answer accepted")
	expect_eq(flow.answer(1, "test", t + 400000), &"duplicate", "second answer is a duplicate")
	expect_eq(flow.attempt.answer, "left", "first answer kept")
	expect_eq(flow.attempt.duplicate_inputs.size(), 1, "duplicate logged")
	expect_eq(flow.block.completed, 1, "one slot filled")
	expect(is_equal_approx(float(flow.attempt.latency_ms), 300.0), "latency from dots off")
	expect_eq(phases, [&"prepare", &"expose", &"respond", &"acknowledged"], "state order")
	expect(flow.next(t + SECOND), "Next")
	expect_eq(flow.attempt.id, "B1-T2-A1", "next trial")


func test_early_input_is_logged_and_never_counted() -> void:
	var flow := _flow()
	flow.start_block(0)
	expect_eq(flow.answer(1, "test", 100), &"early", "during preparation")
	flow.tick(SECOND)
	expect_eq(flow.answer(1, "test", SECOND + 100), &"early", "during exposure")
	expect_eq(flow.attempt.early_inputs.size(), 2, "both logged")
	expect_eq(flow.attempt.status, "running", "attempt still open")
	expect_eq(flow.block.completed, 0, "nothing counted")
	flow.tick(2 * SECOND)
	expect_eq(flow.answer(1, "test", 2 * SECOND + 10), &"accepted", "post-exposure answer")


func test_six_trials_balanced_fresh_seeds_and_wrong_answers_still_advance() -> void:
	var flow := _flow(11)
	flow.start_block(0)
	var t := 0
	for slot in 6:
		t = _to_respond(flow, t)
		var wrong := 1 if flow.attempt.direction == "left" else -1
		expect_eq(flow.answer(wrong, "test", t + 1000), &"accepted", "wrong answer accepted %d" % slot)
		t += 2000
		expect(flow.next(t), "Next after a wrong answer %d" % slot)
	expect_eq(flow.phase, &"block_end", "local ending after six")
	expect_eq(flow.block.status, "complete", "block complete")
	var lefts := 0
	var seeds := {}
	for a: Dictionary in flow.block.attempts:
		lefts += 1 if a.direction == "left" else 0
		seeds[a.seed] = true
		expect_eq(a.correct, false, "correctness stored separately")
		expect(is_equal_approx(float(a.coherence), 0.7), "one stable condition")
	expect_eq(flow.block.attempts.size(), 6, "six attempts")
	expect_eq(lefts, 3, "three left, three right")
	expect_eq(seeds.size(), 6, "fresh dot seed each trial")
	expect(flow.rest(t), "rest offered")
	expect(flow.end_rest(t + 1), "back from rest")
	expect(flow.start_block(t + 2), "repeat offered")
	expect_eq(flow.block.id, "B2", "new block identity")


func test_pause_during_exposure_interrupts_and_resumes_as_a_new_attempt() -> void:
	var flow := _flow()
	var ended: Array = []
	flow.exposure_ended.connect(func(a: Dictionary) -> void: ended.append(a.id))
	flow.start_block(0)
	flow.tick(SECOND)
	expect_eq(flow.phase, &"expose", "exposing")
	expect(flow.pause(SECOND + 400000), "pause during exposure")
	expect_eq(ended, ["B1-T1-A1"], "dots hidden on pause")
	var first: Dictionary = flow.block.attempts[0]
	expect_eq(first.status, "interrupted", "partial view marked interrupted")
	expect_eq(first.interrupted.phase, "expose", "interrupted during exposure")
	expect_eq(flow.answer(1, "test", SECOND + 500000), &"ignored", "input while paused is ignored")
	expect_eq(flow.block.completed, 0, "slot not filled")
	expect(flow.resume(5 * SECOND), "resume")
	expect_eq(flow.attempt.id, "B1-T1-A2", "fresh attempt identity, same slot")
	expect_eq(flow.attempt.direction, first.direction, "planned direction kept")
	expect(flow.attempt.seed != first.seed, "fresh dots")
	expect_eq(flow.answer(1, "test", 5 * SECOND + 100), &"early", "leftover input on resume is early")
	var t := _to_respond(flow, 5 * SECOND)
	expect_eq(flow.answer(1, "test", t + 10), &"accepted", "the fresh attempt answers normally")
	expect_eq(flow.block.completed, 1, "only the completed attempt fills the slot")


func test_teaching_is_unscored_and_kept_apart_from_the_block() -> void:
	var flow := _flow()
	expect(flow.start_demo(0), "demo")
	var t := _to_respond(flow, 0)
	expect_eq(flow.phase, &"expose", "the example shows for longer (2 s)")
	t += SECOND
	flow.tick(t)
	expect_eq(flow.phase, &"acknowledged", "the demo reveals instead of asking")
	expect(flow.attempt.assistance.has("answer_revealed"), "reveal recorded as assistance")
	flow.next(t)
	expect_eq(flow.phase, &"menu", "back to the menu")
	expect(flow.start_practice(t), "practice")
	t = _to_respond(flow, t)
	expect_eq(flow.answer(-1, "test", t + 10), &"accepted", "practice answer")
	expect(is_equal_approx(float(flow.attempt.coherence), 1.0), "easy teaching coherence")
	expect_eq(flow.attempt.scored, false, "unscored")
	expect_eq(flow.record.teaching.size(), 2, "teaching recorded")
	expect_eq(flow.record.blocks.size(), 0, "no block from teaching")


func test_leave_early_saves_a_retrievable_record() -> void:
	var flow := _flow()
	flow.start_block(0)
	var t := _to_respond(flow, 0)
	flow.answer(1, "test", t + 10)
	flow.next(t + 20)
	flow.tick(t + 20 + SECOND)
	expect_eq(flow.phase, &"expose", "second trial exposing")
	flow.leave(t + 20 + SECOND + 100)
	expect_eq(flow.phase, &"left", "left")
	var path: String = flow.saved_path
	expect(FileAccess.file_exists(path), "record file written")
	var saved: Dictionary = TrialBlock.load_record(path)
	expect_eq(saved.schema, TrialBlock.SCHEMA, "schema")
	expect_eq(saved.blocks[0].status, "left_early", "block left early")
	expect_eq(saved.blocks[0].attempts.size(), 2, "both attempts kept")
	expect_eq(saved.blocks[0].attempts[1].status, "abandoned", "attempt in progress abandoned")
	expect_eq(saved.blocks[0].attempts[0].answer, "right", "answer retrievable")
	expect(saved.blocks[0].attempts[0].has("correct"), "correctness retrievable")
	expect_eq(saved.blocks[0].config.name, "preview_rectangle", "configuration recorded")
	expect_eq(saved.blocks[0].config.provisional, true, "marked provisional")
	expect_eq(saved.ended.how, "left", "how it ended")
	expect(FileAccess.file_exists(path.get_base_dir().path_join("latest.json")), "latest.json")


func test_reference_circle_is_labelled_and_sized() -> void:
	var c := BlockConfig.reference_circle(0.9)
	expect_eq(c.dots, 15, "reference dot count")
	expect_eq(c.aperture, "circle", "circular aperture")
	var width := rad_to_deg(2.0 * atan(float(c.aperture_radius_m) / float(c.distance_m)))
	expect(absf(width - 10.0) < 0.01, "10 deg field")
	expect(String(c.label).contains("Not a replication"), "honest label")
	expect(c.unresolved.size() >= 4, "gaps listed")



# --- Nov 10: setup before replay, record fields, the three results views ------------------

## Runs one block; [param pattern] says which trials are answered correctly.
func _run_block(flow: RefCounted, t: int, pattern: Array, latency_us := 300000) -> int:
	expect(flow.start_block(t), "block starts")
	for i in pattern.size():
		t = _to_respond(flow, t)
		var truth := -1 if flow.attempt.direction == "left" else 1
		flow.answer(truth if pattern[i] else -truth, "synthetic", t + latency_us)
		t += latency_us + 1000
		flow.next(t)
	return t


func _near(a: float, b: float, what: String) -> void:
	expect(absf(a - b) < 0.0005, "%s: %.4f vs %.4f" % [what, a, b])


func test_synthetic_coherence_points_and_wilson_intervals() -> void:
	var flow := _flow(3)
	flow.set_config(BlockConfig.customized(flow.config, {coherence = 0.4}))
	var t := _run_block(flow, 0, [true, true, true, false, false, false])
	flow.set_config(BlockConfig.customized(flow.config, {coherence = 0.8}))
	t = _run_block(flow, t, [true, true, true, true, true, false])
	var series := Results.coherence_series([flow.record], SYNTHETIC)
	expect_eq(series.size(), 1, "same condition except coherence: one series")
	var points: Array = series.values()[0].points
	expect_eq(points.size(), 2, "two tested levels, two points")
	expect_eq([points[0].k, points[0].n], [3, 6], "3 of 6 at 40 %")
	_near(points[0].coherence_pct, 40.0, "x = 40 %")
	_near(points[0].accuracy, 0.5, "plots at 50 %")
	_near(points[0].ci[0], 0.1876, "Wilson low 3/6")
	_near(points[0].ci[1], 0.8124, "Wilson high 3/6")
	expect_eq([points[1].k, points[1].n], [5, 6], "5 of 6 at 80 %")
	_near(points[1].accuracy, 5.0 / 6.0, "about 83.3 %")
	_near(points[1].ci[0], 0.4365, "Wilson low 5/6")
	_near(points[1].ci[1], 0.9699, "Wilson high 5/6")
	expect_eq(Results.wilson(0, 0), [], "no data, no interval")


func test_repeated_blocks_pool_and_changed_conditions_split() -> void:
	var flow := _flow(5)
	flow.set_config(BlockConfig.customized(flow.config, {coherence = 0.4}))
	var t := _run_block(flow, 0, [true, true, true, false, false, false])
	t = _run_block(flow, t, [true, true, true, true, false, false])
	flow.set_config(BlockConfig.customized(flow.config, {blur_sigma_deg = 0.2}))
	t = _run_block(flow, t, [true, false, true, false, true, false])
	flow.set_config(BlockConfig.customized(flow.config, {blur_sigma_deg = 0.0, speed_m_s = 0.5}))
	t = _run_block(flow, t, [true, true, false, false, true, true])
	var series := Results.coherence_series([flow.record], SYNTHETIC)
	expect_eq(series.size(), 3, "blur and speed each make a separate series")
	var pooled := 0
	for key: String in series:
		for p: Dictionary in series[key].points:
			if p.n == 12:
				pooled += 1
				expect_eq(p.k, 7, "3/6 + 4/6 pooled to 7/12")
				expect_eq(p.left + p.right, 12, "direction counts kept")
				expect_eq(p.blocks.size(), 2, "both blocks listed")
	expect_eq(pooled, 1, "exactly one pooled point")
	var twice := Results.coherence_series([flow.record, flow.record], SYNTHETIC)
	var once_n := 0
	var twice_n := 0
	for key: String in series:
		for p: Dictionary in series[key].points:
			once_n += int(p.n)
	for key: String in twice:
		for p: Dictionary in twice[key].points:
			twice_n += int(p.n)
	expect_eq(twice_n, once_n, "re-reading the same record never double-counts")
	expect(Results.coherence_series([flow.record], "some-other-dataset").is_empty(), "other datasets excluded")


func test_teaching_interrupted_and_assisted_stay_out_of_the_denominator() -> void:
	var flow := _flow(9)
	flow.start_practice(0)
	var t := _to_respond(flow, 0)
	flow.answer(1, "synthetic", t + 10)
	flow.next(t + 20)
	t += SECOND
	flow.start_block(t)
	flow.tick(t + SECOND)
	flow.pause(t + SECOND + 1000)            # slot 1, first attempt interrupted
	flow.resume(t + 2 * SECOND)
	t += 2 * SECOND
	for i in 6:
		t = _to_respond(flow, t)
		var truth := -1 if flow.attempt.direction == "left" else 1
		flow.answer(truth, "synthetic", t + 400000)
		t += 401000
		flow.next(t)
	flow.block.attempts[1].assistance.append("facilitator_hint")   # mark one answered trial assisted
	var summary := Results.block_summary(flow.block)
	expect_eq(summary.eligible, 5, "assisted trial outside the denominator")
	expect_eq(summary.correct, 5, "correct out of eligible")
	expect_eq(summary.assisted, 1, "assisted shown separately")
	expect_eq(summary.interrupted, 1, "interrupted shown separately")
	var series := Results.coherence_series([flow.record], SYNTHETIC)
	expect_eq(series.values()[0].points[0].n, 5, "teaching, interrupted and assisted not pooled")
	expect(Results.coherence_series([], SYNTHETIC).is_empty(), "empty state: no series")


func test_time_to_registered_answer_matches_a_known_fixture() -> void:
	var flow := _flow(13)
	flow.start_block(0)
	var t := 0
	var latencies := [250000, 500000, 750000]
	for us: int in latencies:
		t = _to_respond(flow, t)
		expect_eq(flow.attempt.times.response_enabled_ms, float(t) / 1000.0, "response enabled at dots off")
		var truth := -1 if flow.attempt.direction == "left" else 1
		flow.answer(truth, "synthetic", t + us)
		t += us + 1000
		flow.next(t)
	flow.tick(t + SECOND)
	flow.leave(t + SECOND + 10)   # trials 4-6 never answered
	var rows := Results.outcome_rows(flow.block)
	expect_eq([rows[0].latency_s, rows[1].latency_s, rows[2].latency_s], [0.25, 0.5, 0.75], "intervals match the fixture")
	expect_eq(rows[3].latency_s, null, "missing answer is a gap, not zero")
	expect_eq(rows[4].answered, false, "unanswered slot")
	var m := Results.median_latency(flow.block)
	expect_eq([m.median_s, m.n], [0.5, 3], "median of eligible trials with n")
	expect_eq(flow.block.attempts[0].input_modality, "synthetic", "input modality recorded")


func test_setup_changes_only_reach_a_new_block() -> void:
	var flow := _flow(17)
	flow.start_block(0)
	expect(not flow.set_config(BlockConfig.customized(flow.config, {coherence = 0.3})), "no change mid-block")
	expect(is_equal_approx(float(flow.block.config.coherence), 0.7), "snapshot intact")
	flow.tick(SECOND)
	flow.pause(SECOND + 10)
	expect(flow.end_block_for_setup(SECOND + 20), "a mid-block change ends the block")
	expect_eq(flow.record.blocks[0].status, "ended_for_setup_change", "marked")
	expect_eq(flow.record.blocks[0].attempts[0].status, "interrupted", "open attempt interrupted")
	expect(flow.set_config(BlockConfig.customized(flow.config, {coherence = 0.3, blur_sigma_deg = 9.0})), "allowed now")
	expect(is_equal_approx(float(flow.config.blur_sigma_deg), 0.5), "blur clamped to its documented range")
	flow.start_block(2 * SECOND)
	expect_eq(flow.block.id, "B2", "a separately identified block")
	expect(is_equal_approx(float(flow.block.config.coherence), 0.3), "the new block has the new setup")
	expect(flow.record.blocks[0].condition_key != "" and flow.block.condition_key != flow.record.blocks[0].condition_key,
		"blur changes the condition key")


func test_requested_and_realized_coherence_are_both_recorded() -> void:
	var flow := TrialBlock.new()
	flow.save_dir = "user://motion_lab_test_records"
	flow.begin(BlockConfig.reference_circle(0.7), BlockConfig.timing(), 0, 21, {}, SYNTHETIC)
	flow.start_block(0)
	expect_eq(flow.attempt.signal_dots, 11, "round(0.7 x 15) = 11")
	_near(flow.attempt.coherence_requested, 0.7, "requested")
	_near(flow.attempt.coherence_realized, 0.7333, "realized 11/15")
