extends TestCase
## Usability: children are reminded how to ask for help, see how many rounds
## are left, hear when the last one comes, and can stop any game from the menu.

const FIND := preload("res://trials/find/find.tres")
const MOTION := preload("res://trials/motion/motion_demo.tres")


func _round_running() -> bool:
	return App.session.trial != null and App.session.trial.is_running()


func _round(index: int) -> bool:
	return await until(func() -> bool: return _round_running() and App.session.trial.condition.round_index == index)


func _answer() -> void:
	await select((App.session.trial.get("_target") as Target).global_position)


func _said(lines: Array) -> Array:
	return lines.map(func(args: Array) -> String: return args[0])


func test_a_child_stuck_where_help_only_comes_when_asked_is_reminded_once() -> void:
	await boot(plan_of(MOTION, 2), &"global_motion")
	var said := record(Events.said)
	App.session.run()
	await _round(0)
	await wait(Trial.REMIND_AFTER - 1.0)
	expect(not _said(said).has(Trial.REMINDER), "not at once")
	await wait(1.5)
	expect_eq(_said(said).count(Trial.REMINDER), 1, "after a while with no try: how to ask")
	await wait(10.0)
	expect_eq(_said(said).count(Trial.REMINDER), 1, "once: a reminder, not nagging")


func test_no_reminder_where_help_comes_by_itself_or_in_a_check_in() -> void:
	await boot(plan_of(MOTION, 1, true), &"global_motion")
	var said := record(Events.said)
	App.session.run()
	await _round(0)
	await wait(Trial.REMIND_AFTER + 2.0)
	expect(not _said(said).has(Trial.REMINDER), "check-ins have no help to ask for")
	await shutdown()
	await boot(plan_of(FIND, 1))
	said = record(Events.said)
	App.session.run()
	await _round(0)
	await wait(Trial.REMIND_AFTER + 1.0)
	expect(not _said(said).has(Trial.REMINDER), "Find's help comes by itself")


func test_round_dots_show_how_much_is_left_and_the_last_round_is_announced() -> void:
	await boot(plan_of(FIND, 3))
	var said := record(Events.said)
	App.session.run()
	await _round(0)
	var dots := App.stage.find_child("RoundDots", false, false) as RoundDots
	expect(dots != null, "a dot per round")
	expect_eq(dots.get_child_count(), 5, "three dots, the ring and the plate")
	await _answer()
	await _round(1)
	expect_eq(dots.solved(), 1, "the first round turns gold")
	expect(not _said(said).has(Session.LAST_ROUND), "not yet the last")
	await _answer()
	await _round(2)
	expect(_said(said).has(Session.LAST_ROUND), "before the last round: Last one!")
	await _answer()
	expect(await until(func() -> bool: return not App.session.running, 5.0), "done")
	expect(App.stage.find_child("RoundDots", false, false) == null or not is_instance_valid(dots), "the dots go with the level")


func test_a_child_can_stop_any_game_from_the_menu() -> void:
	var plan := plan_of(FIND, 5)
	plan.blocks.append(plan_of(FIND, 3).blocks[0])
	await boot(plan)
	var started := record(Events.block_started)
	App.session.run()
	await _round(0)
	var home := App.module(&"Home")
	home.open()
	await frames(3)
	var stop := home.find_child("menu_stop", true, false) as Target
	expect(stop != null, "Stop this game is on the menu during a level")
	await select(stop.global_position)
	expect(await until(func() -> bool: return not App.session.running, 5.0), "the game ends")
	expect_eq(started.size(), 1, "the whole level, not just one part of it")
	expect(not App.session.won, "a stopped game is not finished")
