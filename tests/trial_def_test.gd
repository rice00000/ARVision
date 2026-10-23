extends TestCase
## What a round runs at: TrialAxis, TrialDef.condition (with block pins) and
## TrialCondition.

const FIND := preload("res://trials/find/find.tres")
const MOTION := preload("res://trials/motion/motion.tres")


func test_an_axis_follows_the_level_only_when_driven() -> void:
	var axis := TrialAxis.new()
	axis.easy = 2.0
	axis.hard = 9.0
	axis.driven = true
	expect_eq(axis.resolve(0.0), 2.0, "easy end")
	expect_eq(axis.resolve(1.0), 9.0, "hard end")
	expect_eq(axis.resolve(0.5), 5.5, "in between")
	expect_eq(axis.resolve(-0.5), 2.0, "below 0 clamps")
	expect_eq(axis.resolve(1.5), 9.0, "above 1 clamps")
	axis.driven = false
	expect_eq(axis.resolve(0.7), 2.0, "not driven: easy")
	axis.fixed = 4.0
	expect_eq(axis.resolve(0.7), 4.0, "not driven: the fixed value")
	var falling := TrialAxis.new()
	falling.easy = 0.9
	falling.hard = 0.15
	falling.driven = true
	expect(is_equal_approx(falling.resolve(0.5), 0.525), "an axis may get smaller as it gets harder")


func test_every_shipped_def_drives_exactly_one_axis_at_most() -> void:
	for path in ["res://trials/find/find.tres", "res://trials/motion/motion.tres",
			"res://trials/motion/motion_competing.tres", "res://trials/point_real/point_real.tres"]:
		var def: TrialDef = load(path)
		var driven := def.axes.filter(func(axis: TrialAxis) -> bool: return axis.driven)
		expect(driven.size() <= 1, "%s drives %d axes" % [path, driven.size()])
		var scene := def.scene.instantiate()
		expect(scene is Trial, "%s scene is a Trial" % path)
		scene.free()


func test_condition_resolves_every_axis_at_the_level() -> void:
	var condition := FIND.condition(0.5, 2, false)
	expect_eq(condition.trial, &"find", "id from the file name")
	expect_eq(condition.skill, &"objects_in_clutter", "skill")
	expect_eq(condition.level, 0.5, "level")
	expect_eq(condition.round_index, 2, "round")
	expect_eq(condition.probe, false, "not a probe")
	expect_eq(condition.value(&"clutter"), 5.5, "driven axis at the level")
	expect_eq(condition.value(&"size"), 0.07, "fixed axis")
	expect_eq(condition.value(&"spacing"), 1.8, "fixed axis")
	expect_eq(condition.value(&"same_colour"), 0.0, "fixed axis")
	expect_eq(condition.value(&"missing", -1.0), -1.0, "unknown axes give the default")


func test_pins_fix_axes_over_the_def() -> void:
	var pinned := FIND.condition(0.5, 0, true, {&"same_colour": 1.0, &"clutter": 3.0})
	expect_eq(pinned.value(&"same_colour"), 1.0, "a fixed axis pinned")
	expect_eq(pinned.value(&"clutter"), 3.0, "a pin overrides the driven axis too: the level no longer changes it")
	expect_eq(pinned.value(&"size"), 0.07, "unpinned axes keep their value")
	expect_eq(pinned.probe, true, "probe flag")
	var typo := FIND.condition(0.5, 0, false, {&"colour": 1.0})
	expect_eq(typo.value(&"colour", -1.0), -1.0, "a pin for an axis the def lacks is ignored (silently)")
	expect_eq(MOTION.condition(0.0, 0, false, {&"direction": 3.0}).value(&"direction"), 3.0, "motion direction pin")


func test_condition_logs_everything_and_keeps_its_own_copy() -> void:
	var condition := FIND.condition(0.3, 1, false)
	condition.view = View.new().to_log()
	condition.set_value(&"target", "ball")
	var logged := condition.to_log()
	expect_eq(logged.keys().map(func(key: Variant) -> String: return str(key)),
		["trial", "skill", "level", "round", "probe", "view", "values"], "every field")
	expect_eq(logged.values.target, "ball", "values set by the trial are logged")
	condition.set_value(&"target", "cone")
	expect_eq(logged.values.target, "ball", "a logged condition does not change afterwards")
	expect_eq(logged.view.title, "Normal", "the view goes with it")
