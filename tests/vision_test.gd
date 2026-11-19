extends TestCase
## Vision: the child's own profile. Saved with the child, it sets the filter,
## object sizes, help timing, time limits and menu-level difficulty, and is
## edited live on the facilitator's Vision page.

const FIND := preload("res://trials/find/find.tres")
const TIDY := preload("res://trials/tidy/tidy.tres")
const LOW_ACUITY := preload("res://content/vision/low_acuity.tres")


func _round_running() -> bool:
	return App.session.trial != null and App.session.trial.is_running()


func _answer() -> void:
	await select((App.session.trial.get("_target") as Target).global_position)


func _next_round(index: int) -> bool:
	return await until(func() -> bool: return _round_running() and App.session.trial.condition.round_index == index)


func test_a_new_child_starts_neutral() -> void:
	expect_eq(Vision.view.title, "Normal", "normal filter")
	expect(not Vision.view.is_graded() and Vision.view.dim == 0.0, "nothing changed")
	expect_eq([Vision.size_scale, Vision.help_scale, Vision.time_scale, Vision.adaptive], [1.0, 1.0, 1.0, true], "no scaling, levels adapt")
	expect_eq(FIND.condition(0.0, 0, false).value(&"size"), 0.07, "sizes as designed")


func test_the_profile_is_saved_with_the_child_and_wiped_with_them() -> void:
	Vision.use_preset(LOW_ACUITY)
	Vision.set_offset(&"visual_matching", 0.2)
	Vision.set_adaptive(false)
	Save.write()
	Save.reload()
	expect_eq(Vision.view.contrast, 1.6, "filter read back")
	expect_eq(Vision.size_scale, 1.5, "size read back")
	expect_eq(Vision.offset(&"visual_matching"), 0.2, "offset read back")
	expect(not Vision.adaptive, "fixed levels read back")
	expect_eq(Vision.preset, "Low acuity", "where it started")
	expect_eq(Vision.revision, 3, "three changes")
	expect(Vision.is_childs(Vision.view), "a loaded view is still the child's")
	Profile.wipe()
	expect_eq([Vision.view.contrast, Vision.size_scale, Vision.revision], [1.0, 1.0, 0], "forgotten with the save")


func test_values_stay_in_range() -> void:
	Vision.set_size_scale(9.0)
	Vision.set_help_scale(0.0)
	Vision.set_offset(&"x", -2.0)
	expect_eq([Vision.size_scale, Vision.help_scale, Vision.offset(&"x")], [2.0, 0.5, -0.5], "clamped")
	Vision.set_offset(&"x", 0.0)
	expect(not Vision.offsets.has(&"x"), "a zero offset is dropped")


func test_size_axes_grow_up_to_where_things_still_fit() -> void:
	Vision.set_size_scale(1.5)
	expect(is_equal_approx(FIND.condition(0.0, 0, false).value(&"size"), 0.105), "find: 0.07 x 1.5")
	expect(is_equal_approx(TIDY.condition(0.0, 0, false).value(&"size"), 0.075), "tidy: capped so the biggest still fits a cubby")
	expect(is_equal_approx(FIND.condition(0.0, 0, false, {&"size": 0.05}).value(&"size"), 0.05), "a pin is taken as it is")
	expect_eq(FIND.condition(0.0, 0, false).value(&"clutter"), 2.0, "untagged axes do not change")


func test_the_childs_filter_shows_and_a_blocks_own_view_wins() -> void:
	Vision.use_preset(LOW_ACUITY)
	var plan := plan_of(FIND, 1)
	plan.blocks.append(plan_of(FIND, 1, false, -1.0, load("res://content/views/edges.tres")).blocks[0])
	await boot(plan)
	var blocks := record(Events.block_started)
	App.session.run()
	await _next_round(0)
	expect_eq(App.reality.view.contrast, 1.6, "the child's filter in a block without a view")
	expect_eq(blocks[0][1].vision.size_scale, 1.5, "the block logs the whole profile")
	await _answer()
	await _next_round(0)
	expect_eq(App.reality.view.title, "Edges", "a block's own view (filter A/B) wins")
	Vision.set_size_scale(1.25)
	expect_eq(App.reality.view.title, "Edges", "changing the profile does not override it")


func test_a_change_shows_at_once_and_is_logged() -> void:
	await boot(plan_of(FIND, 1))
	var reports := record(Events.reported)
	App.session.run()
	await _next_round(0)
	var view: View = Vision.view.duplicate()
	view.saturation = 0.0
	Vision.set_view(view)
	expect_eq(App.reality.view.saturation, 0.0, "greyscale now")
	var changes := reports.filter(func(args: Array) -> bool: return args[0] == &"vision_changed")
	expect_eq(changes.size(), 1, "one change logged")
	expect_eq([changes[0][1].before.view.saturation, changes[0][1].after.view.saturation], [1.0, 0.0], "before and after")
	Vision.set_view(Vision.view)
	expect_eq(reports.filter(func(args: Array) -> bool: return args[0] == &"vision_changed").size(), 1, "no change, no line")


func test_an_offset_shifts_a_fixed_level_and_the_staircase_stays() -> void:
	Vision.set_offset(FIND.skill, -0.2)
	await boot(plan_of(FIND, 2, false, 0.5))
	App.session.run()
	await _next_round(0)
	expect(is_equal_approx(App.session.trial.condition.level, 0.3), "0.5 - 0.2")
	await _answer()
	await _next_round(1)
	expect(not Profile._levels.has(FIND.skill), "a fixed level does not move the staircase")


func _adaptive_find(rounds: int, start: float) -> SessionPlan:
	var plan := plan_of(FIND, rounds, false, start)
	plan.blocks[0].drive = {&"clutter": Vector2(2.0, 9.0)}
	plan.blocks[0].staircase = &"objects_in_clutter.test"
	return plan


func test_adaptive_levels_climb_their_own_range_quickly_at_first() -> void:
	await boot(_adaptive_find(3, 0.4))
	App.session.run()
	await _next_round(0)
	expect(is_equal_approx(App.session.trial.condition.level, 0.4), "starts at the level's difficulty")
	expect(is_equal_approx(App.session.trial.condition.value(&"clutter"), 4.8), "its own axis follows: 2 to 9 clutter")
	await _answer()
	await _next_round(1)
	expect(is_equal_approx(App.session.trial.condition.level, 0.6), "quick start: one right is two steps up")
	await _answer()
	await _next_round(2)
	expect(is_equal_approx(Profile.level(&"objects_in_clutter.test"), 0.8), "on the level's own staircase")
	expect(is_equal_approx(Profile.level(FIND.skill), Profile.START_LEVEL), "not the skill's")


func test_a_child_on_fixed_levels_plays_each_at_its_start() -> void:
	Vision.set_adaptive(false)
	Vision.set_offset(&"objects_in_clutter.test", 0.1)
	await boot(_adaptive_find(2, 0.4))
	App.session.run()
	await _next_round(0)
	await _answer()
	await _next_round(1)
	expect(is_equal_approx(App.session.trial.condition.level, 0.5), "the start plus the child's offset, not moving")


func test_help_comes_sooner_and_time_limits_stretch() -> void:
	Vision.set_help_scale(0.5)
	Vision.set_time_scale(2.0)
	await boot(plan_of(FIND, 1))
	var reports := record(Events.reported)
	var ended := record(Events.trial_ended)
	App.session.run()
	await _next_round(0)
	var trial := App.session.trial
	await until(func() -> bool: return trial.hint_level > 0, FIND.hint_after)
	expect(absf(trial.seconds() - FIND.hint_after * 0.5) < 0.1, "first hint at half the wait: %.2f s" % trial.seconds())
	expect(reports.any(func(args: Array) -> bool: return args[0] == &"hint"), "logged as usual")
	await wait(FIND.time_limit + 1.0 - trial.seconds())
	expect(ended.is_empty(), "still going after the usual time limit")


func test_the_vision_page_edits_the_profile() -> void:
	var plan := plan_of(TIDY, 1, false, 0.0)
	plan.blocks[0].drive = {&"things": Vector2(3.0, 5.0)}
	plan.blocks[0].staircase = &"visual_matching.test"
	await boot(plan)
	App.session.run()
	await _next_round(0)
	input.menu()
	await frames(2)
	await press_facilitator("fac_vision")
	await frames(2)
	await press_facilitator("fac_v_contrast_up")
	expect(is_equal_approx(Vision.view.contrast, 1.2), "contrast up one step")
	expect_eq(Vision.view.title, "Custom", "a hand-made filter")
	expect(is_equal_approx(App.reality.view.contrast, 1.2), "shown at once")
	await press_facilitator("fac_v_size_up")
	expect_eq(Vision.size_scale, 1.25, "bigger things")
	await press_facilitator("fac_v_level_up")
	expect(is_equal_approx(Profile.level(&"visual_matching.test"), 0.1), "an adaptive level: its staircase moves, from its own 0")
	await press_facilitator("fac_v_adaptive")
	expect(not Vision.adaptive, "fixed levels")
	await press_facilitator("fac_v_level_up")
	expect(is_equal_approx(Vision.offset(&"visual_matching.test"), 0.1), "a fixed level gets an offset")
	await press_facilitator("fac_v_preset_up")
	expect_eq(Vision.preset, "Normal", "first preset")
	await press_facilitator("fac_v_reset")
	expect_eq([Vision.size_scale, Vision.adaptive, Vision.offsets.size()], [1.0, true, 0], "back to normal")
