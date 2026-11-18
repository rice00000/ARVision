extends TestCase
## The Staff tools Results tab (modules/results/results_view.gd in modules/facilitator/facilitator.gd).

const RANDOM := preload("res://trials/motion/motion.tres")


func test_the_results_tab_opens_on_round_outcomes_for_this_visit() -> void:
	await boot()
	input.menu()
	await frames(2)
	await press_facilitator("fac_results")
	await frames(2)
	var panel := App.module(&"Facilitator")
	var view := panel.find_child("ResultsView", true, false) as ResultsView
	expect(view != null and view.is_inside_tree(), "the graph is on the panel")
	if view == null:
		return
	expect_eq(view.graph_kind, &"outcomes", "round outcomes first")
	expect_eq(_caption("fac_res_scope"), "This visit", "this visit")
	expect_eq(_caption("fac_res_group"), "Showing: Play", "play rounds only")
	var size: Vector2 = (view.get_node(^"Graph") as MeshInstance3D).mesh.size
	expect(size.x >= 0.39, "nearly the panel's width: %s m" % size.x)


func test_the_buttons_switch_graph_scope_and_group() -> void:
	await boot()
	input.menu()
	await frames(2)
	await press_facilitator("fac_results")
	await frames(2)
	var view := App.module(&"Facilitator").find_child("ResultsView", true, false) as ResultsView
	var two_levels := MotionResults.rounds_in([_round(1, 0.9), _round(2, 0.5)])
	view.use_rounds(two_levels, two_levels)
	await press_facilitator("fac_res_rounds")   # refreshes the buttons
	await frames(2)
	await press_facilitator("fac_res_coherence")
	await frames(2)
	expect_eq(view.graph_kind, &"coherence", "accuracy vs coherence")
	expect_eq(_caption("fac_res_scope"), "All visits", "graph 3 starts on all visits")
	await press_facilitator("fac_res_scope")
	await frames(2)
	expect_eq(_caption("fac_res_scope"), "This visit", "toggled")
	await press_facilitator("fac_res_group")
	await frames(2)
	expect_eq(_caption("fac_res_group"), "Showing: Pinned level", "next group")
	await press_facilitator("fac_res_rounds")
	await frames(2)
	expect_eq(view.graph_kind, &"outcomes", "back to outcomes")
	expect_eq(_caption("fac_res_scope"), "This visit", "its own scope")


func test_a_dev_round_shows_only_under_dev() -> void:
	await boot(plan_of(RANDOM, 2, false, 0.4, null, {&"direction": 1.0}))
	App.session.run()
	await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running())
	await wait(0.5)
	App.session.skip_block()
	await frames(2)
	input.menu()
	await frames(2)
	await press_facilitator("fac_results")
	await frames(2)
	var view := App.module(&"Facilitator").find_child("ResultsView", true, false) as ResultsView
	expect(view.shown_rounds().is_empty(), "the test's dev round is not shown as play")
	for i in 2:
		await press_facilitator("fac_res_group")
		await frames(2)
	expect_eq(_caption("fac_res_group"), "Showing: Dev", "dev")
	expect_eq(view.shown_rounds().size(), 1, "the dev round, from this visit's log")
	expect_eq(view.graph().rounds.size(), 1, "and it is what the graph draws")


## Hub review, Nov 17: graph 3 waits for two coherence levels (Steady Flow is always 90 %).
func test_graph_3_is_hidden_until_two_coherence_levels() -> void:
	await boot()
	input.menu()
	await frames(2)
	await press_facilitator("fac_results")
	await frames(2)
	var view := App.module(&"Facilitator").find_child("ResultsView", true, false) as ResultsView
	var button := App.module(&"Facilitator").find_child("fac_res_coherence", true, false) as Node3D
	var one := MotionResults.rounds_in([_round(1, 0.9), _round(2, 0.9), _round(3, 0.92)])
	view.use_rounds(one, one)
	await press_facilitator("fac_res_rounds")
	await frames(2)
	expect(not button.visible, "one level (90 %): no Coherence button")
	expect(not view.press(&"fac_res_coherence") and view.graph_kind == &"outcomes", "and it can't be chosen")
	var two := MotionResults.rounds_in([_round(1, 0.9), _round(2, 0.5)])
	view.use_rounds(two, two)
	await press_facilitator("fac_res_rounds")
	await frames(2)
	expect(button.visible, "two levels: the Coherence button shows")


## Hub review, Nov 17: rounds in the dimmed room (Scene 9) are their own group.
func test_dimmed_rounds_never_pool_with_undimmed() -> void:
	var rounds := MotionResults.rounds_in([_round(1, 0.9), _round(2, 0.9, 0.6), _round(3, 0.9, 0.6)])
	expect_eq(rounds.map(func(r: Dictionary) -> String: return r.group), ["play", "play_dim", "play_dim"], "dimmed apart")
	expect_eq(MotionResults.groups_in(rounds), ["play", "play_dim", "pinned", "dev", "unknown"] as Array[String],
		"the dimmed group is offered only when it has rounds")
	expect_eq(MotionResults.group_title("play_dim"), "Play, dimmed room", "its title")
	expect_eq(MotionResults.in_group(rounds, "play").size(), 1, "play shows only the undimmed round")


## Scene 10: after a closing, Staff tools opens on Results, with End session there.
func test_after_a_closing_staff_tools_opens_on_results_with_end_session() -> void:
	await boot()
	App.results_after_closing = true
	input.menu()
	await frames(2)
	var panel := App.module(&"Facilitator")
	var view := panel.find_child("ResultsView", true, false) as ResultsView
	expect(view != null and view.is_inside_tree(), "it opens on Results")
	var end := panel.find_child("fac_end_session", true, false) as Node3D
	expect(end != null and end.is_inside_tree(), "End session is on the Results page")
	expect(not App.results_after_closing, "only the first time")


static func _round(serial: int, coherence: float, dim := 0.0) -> Dictionary:
	return {type = "trial_end", success = true, data = {trial = "motion_demo", round = serial, log_version = 3,
		session_mode = "play", level_pinned = false, level_source = "fixed", round_serial = serial, heading = "left",
		coherence_start = coherence, view_dim = dim,
		attempts = [{correct = true, coherence_shown = coherence, help = 0, onset_seconds = 2.0}], first_attempt_correct = true}}


func _caption(id: String) -> String:
	var button := App.module(&"Facilitator").find_child(id, true, false)
	return (button.get_node(^"Caption") as Label3D).text if button else ""
