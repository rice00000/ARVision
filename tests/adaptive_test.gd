extends TestCase
## Adaptive levels: fair scoring of help that came by itself, finishing on half
## the rounds, butterflies that adapt inside a round, and the desk, bookshelf and
## sandwich sizes a level can drive.

const FIND := preload("res://trials/find/find.tres")
const CATCH := preload("res://trials/butterfly/butterfly.tres")
const DESK := preload("res://trials/desk/desk.tres")
const BOOKSHELF := preload("res://trials/bookshelf/bookshelf.tres")
const SANDWICH := preload("res://trials/sandwich/sandwich.tres")


func _round_running() -> bool:
	return App.session.trial != null and App.session.trial.is_running()


func _adaptive(def: TrialDef, rounds: int, drive: Dictionary, pins := {}) -> SessionPlan:
	var plan := plan_of(def, rounds, false, 0.0, null, pins)
	plan.blocks[0].drive.assign(drive)
	plan.blocks[0].staircase = StringName(String(def.skill) + ".test")
	return plan


func test_how_a_round_moves_the_staircase() -> void:
	await boot()
	var session := App.session
	expect_eq(session.outcome(true, 0, 0, false), &"right", "first time, no help")
	expect_eq(session.outcome(true, 0, 1, false), &"neutral", "first time with help that came by itself: no move")
	expect_eq(session.outcome(true, 0, 1, true), &"wrong", "help the child asked for")
	expect_eq(session.outcome(true, 1, 0, false), &"wrong", "a wrong try")
	expect_eq(session.outcome(false, 0, 0, false), &"wrong", "not solved")


func test_a_slow_child_is_not_pushed_down_by_help_that_came_by_itself() -> void:
	await boot(_adaptive(FIND, 2, {&"clutter": Vector2(2.0, 9.0)}))
	var reports := record(Events.reported)
	App.session.run()
	await until(_round_running)
	var trial := App.session.trial
	await until(func() -> bool: return trial.hint_level > 0, FIND.hint_after + 2.0)
	await select((trial.get("_target") as Target).global_position)
	var levels := reports.filter(func(args: Array) -> bool: return args[0] == &"level")
	expect_eq(levels.size(), 1, "the round was scored")
	expect_eq([levels[0][1].outcome, levels[0][1].after], [&"neutral", 0.0], "the level stays")
	expect(not levels[0][1].first_try, "the research log still says it had help")


func test_an_adaptive_level_is_finished_when_half_its_rounds_are_solved() -> void:
	await boot(_adaptive(FIND, 2, {&"clutter": Vector2(2.0, 9.0)}))
	App.session.run()
	await until(_round_running)
	App.session.trial.finish(false)
	await until(func() -> bool: return _round_running() and App.session.trial.condition.round_index == 1)
	await select((App.session.trial.get("_target") as Target).global_position)
	await until(func() -> bool: return not App.session.running, 10.0)
	expect(App.session.won, "one of two solved: finished")


func test_butterflies_speed_up_after_a_catch_and_slow_after_a_miss() -> void:
	await boot(_adaptive(CATCH, 1, {&"speed": Vector2(0.12, 0.3)}))
	App.session.run()
	await until(_round_running)
	var trial := App.session.trial
	var swarm: ButterflySwarm = trial.get("_swarm")
	expect(is_equal_approx(swarm.speed, 0.12), "starts at the level's speed")
	trial.call("_score_circle_contact", 0, Vector3.ZERO, 180.0, true)
	expect(is_equal_approx(swarm.speed, 0.12 * trial.SPEED_UP), "a catch: a little faster")
	trial.set("_quiet_until", 0.0)
	trial.call("_score_circle_contact", 1, Vector3.ZERO, 180.0, false)
	expect(is_equal_approx(swarm.speed, 0.12 * trial.SPEED_UP * trial.SPEED_DOWN), "a chase: slower")
	for i in 30:
		trial.set("_quiet_until", 0.0)
		trial.call("_score_circle_contact", 1, Vector3.ZERO, 180.0, false)
	expect(is_equal_approx(swarm.speed, trial.SPEED_RANGE.x), "never slower than the floor")


func test_the_desk_can_ask_for_fewer_props_and_keeps_the_notebook_and_pencil() -> void:
	await boot(plan_of(DESK, 1, false, 0.0, null, {&"props": 3.0}))
	App.session.run()
	expect(await until(_round_running, 10.0), "a round")
	var keys: Array = (App.session.trial.get("_keys") as Dictionary).values()
	expect_eq(keys.size(), 3, "three props")
	expect(keys.has("notebook") and keys.has("pencil"), "the ending's notebook and pencil: %s" % [keys])
	expect_eq((App.session.trial.get("_guides") as Dictionary).size(), 3, "and only their outlines")


func test_the_bookshelf_can_ask_for_fewer_objects() -> void:
	await boot(plan_of(BOOKSHELF, 1, false, 0.0, null, {&"objects": 3.0}))
	App.session.run()
	expect(await until(_round_running, 10.0), "a round")
	expect_eq((App.session.trial.get("_keys") as Dictionary).size(), 3, "three objects")
	expect_eq((App.session.trial.get("_guides") as Dictionary).size(), 3, "three glass shapes")


func test_the_sandwich_can_ask_for_fewer_fillings() -> void:
	await boot(plan_of(SANDWICH, 1, false, 0.0, null, {&"fillings": 1.0}))
	App.session.run()
	expect(await until(_round_running, 10.0), "a round")
	var recipe: Array = App.session.trial.get("_recipe")
	expect_eq(recipe.size(), 2, "one filling and the top slice: %s" % [recipe])
	expect_eq(recipe.back(), "bread", "toast closes it")
