extends TestCase

const DESK := preload("res://trials/desk/desk.tres")
const TASK := preload("res://content/tasks/tidy_shelf.tres")


func _start(rounds := 1) -> Trial:
	var plan := plan_of(DESK, rounds, false, 0.0)
	plan.blocks[0].ray = false
	await boot(plan)
	App.session.run()
	await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running())
	return App.session.trial


func _tip(point: Vector3, hand := &"right") -> void:
	var along := (point - (App.head().global_position + Vector3.DOWN * 0.2)).normalized()
	input.point(hand, point - along * App.rig.pointer(hand).tip_reach, point)
	await frames(2)


func _take(thing: Target, hand := &"right") -> void:
	await _tip(thing.global_position, hand)
	input.press(hand, &"trigger_click", true)
	await frames(2)


func _drop(point: Vector3, hand := &"right") -> void:
	await _tip(point, hand)
	input.press(hand, &"trigger_click", false)
	await wait(0.45)
	await _tip(App.head().global_position + Vector3(0, -0.15, -0.12), hand)
	await wait(0.3)


func _cell(trial: Trial, key: String) -> Vector3:
	for cell: Dictionary in trial.layout().cells:
		if cell.key == key:
			return cell.position
	return Vector3.ZERO


func test_outline_level_uses_the_desk_and_keeps_saved_identity() -> void:
	var level := TASK.level_by_id(&"outline")
	expect_eq(level.title, "Ready to Study", "desk appears in the existing outline card")
	expect_eq(level.plan.blocks[0].trial, DESK, "the old shelf-outline path is replaced")
	expect_eq(level.plan.blocks[0].rounds, 1, "one complete desk")
	expect(not level.plan.blocks[0].ray, "reach and pinch")
	await boot()
	var said := record(Events.said)
	await App.world._complete(TASK, level)
	expect_eq(said[0][0], level.completion, "the desk has everyday completion wording")
	expect(not String(said[0][0]).contains("alchemist"), "no forced alchemist story")


func test_pickup_hover_and_help_never_reveal_the_matching_outline() -> void:
	var trial := await _start()
	var picked := record(Events.picked)
	var feedback := record(Events.feedback)
	var lines: Dictionary = trial.get("_guides")
	var original := {}
	for key: String in lines:
		original[key] = [lines[key].transform, lines[key].material_override]
		expect(lines[key].visible, "all five outlines show from the beginning")
	var thing: Target = trial.get("_things")[0]
	await _take(thing)
	await _tip(_cell(trial, trial.get("_keys")[thing]))
	trial.escalate()
	await wait(0.7)
	expect_eq(picked.size(), 0, "no decision before release")
	expect_eq(feedback.size(), 0, "help does not mark the answer")
	for key: String in lines:
		expect(lines[key].visible and lines[key].transform == original[key][0]
			and lines[key].material_override == original[key][1], "outline stays unchanged: " + key)
	expect(trial.get("_placed").is_empty(), "hovering never snaps the object")


func test_wrong_drop_returns_and_right_drop_snaps_and_hides_only_its_outline() -> void:
	var trial := await _start()
	var picked := record(Events.picked)
	var thing: Target = trial.get("_things")[0]
	var key: String = trial.get("_keys")[thing]
	var other := "pencil" if key != "pencil" else "mug"
	var home := thing.global_transform
	await _take(thing)
	await _drop(_cell(trial, other))
	expect_eq(trial.tries, 1, "a wrong outline is a scored attempt")
	expect_eq(picked.size(), 1, "one pick per deliberate drop")
	expect(not picked[0][0].correct, "wrong pairing recorded")
	expect(thing.global_transform.is_equal_approx(home), "wrong thing returns to its tray spot")
	for line: Node3D in trial.get("_guides").values():
		expect(line.visible, "a wrong answer reveals no correct outline")
	await _take(thing)
	await _drop(_cell(trial, key) + Vector3(0.009, 0.025, 0.008))
	expect(trial.get("_placed").has(thing), "a forgiving correct drop snaps into place")
	expect(thing.global_position.distance_to(_cell(trial, key)) < 0.001, "snapped to the clean arrangement")
	expect(not trial.get("_guides")[key].visible, "only its finished outline disappears")
	expect_eq(picked.size(), 2, "second drop logged once")


func test_tracking_loss_pause_and_release_off_the_desk_are_unscored() -> void:
	var trial := await _start()
	var thing: Target = trial.get("_things")[0]
	var picked := record(Events.picked)
	await _take(thing)
	input.track(&"right", false)
	await wait(0.4)
	expect(trial.get("_carried").is_empty(), "tracking loss returns the thing")
	input.press(&"right", &"trigger_click", false)
	input.track(&"right", true)
	await wait(0.3)
	await _take(thing)
	get_tree().paused = true
	await frames(2)
	expect(trial.get("_carried").is_empty(), "menu pause drops the unfinished gesture")
	input.press(&"right", &"trigger_click", false)
	get_tree().paused = false
	await wait(0.8)
	await _take(thing)
	await _drop(App.head().global_position + Vector3(0, -0.1, -0.1))
	expect_eq(trial.tries, 0, "off-desk drops and interrupted gestures are unscored")
	expect_eq(picked.size(), 0, "no false picks")


func test_brief_pinch_dropout_is_ignored_and_release_position_is_frozen() -> void:
	var trial := await _start()
	var thing: Target = trial.get("_things")[0]
	var key: String = trial.get("_keys")[thing]
	await _take(thing)
	await _tip(_cell(trial, key))
	input.press(&"right", &"trigger_click", false)
	await wait(0.035)
	input.press(&"right", &"trigger_click", true)
	await wait(0.2)
	expect(trial.get("_carried").get(&"right") == thing, "dropout does not steal the object")
	input.press(&"right", &"trigger_click", false)
	await _tip(App.head().global_position + Vector3(0, -0.1, -0.1))
	await wait(0.5)
	expect(trial.get("_placed").has(thing), "judges the pose at release, even if the hand withdraws")


func test_all_five_finish_with_a_pausable_study_animation_once() -> void:
	var trial := await _start()
	var ended := record(Events.trial_ended)
	for thing: Target in trial.get("_things"):
		await _take(thing)
		await _drop(_cell(trial, trial.get("_keys")[thing]))
	expect_eq(ended.size(), 0, "the result waits for the ending")
	expect(trial.layout().celebrating, "all five starts the ending")
	trial.escalate()
	expect_eq(trial.hint_level, 0, "help during the ending cannot change the completed matching score")
	var ending: Node3D = trial.get("_ending")
	get_tree().paused = true
	var before: Vector3 = ending.get("_actor").position
	await frames(30)
	expect(ending.get("_actor").position.is_equal_approx(before), "ending freezes with the menu")
	get_tree().paused = false
	await wait(5.8)
	expect_eq(ended.size(), 1, "completed exactly once")
	expect(ended[0][1] and ended[0][2].first_try, "all correct unaided")
	expect_eq(ended[0][2].ending, "studying", "student reached the studying phase")
	expect_eq(ended[0][2].puts.size(), 5, "five meaningful decisions recorded")


func test_abandon_during_the_ending_never_awards_a_completion() -> void:
	var trial := await _start()
	var ended := record(Events.trial_ended)
	for thing: Target in trial.get("_things"):
		await _take(thing)
		await _drop(_cell(trial, trial.get("_keys")[thing]))
	App.session.skip_block()
	await wait(6.0)
	expect_eq(ended.size(), 0, "an interrupted celebration cannot finish later")
