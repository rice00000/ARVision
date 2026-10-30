extends TestCase
## Tidy up: the shelf's stickers, taking a thing on the fingertip, putting it
## back right and wrong, help, and the sticker kinds.

const TIDY := preload("res://trials/tidy/tidy.tres")
const TRIAL := preload("res://trials/tidy/tidy_trial.gd")


func _start(rounds := 1, difficulty := 0.0, pins: Dictionary = {}) -> Trial:
	await boot(plan_of(TIDY, rounds, false, difficulty, null, pins))
	App.session.run()
	await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running())
	await wait(0.6) # the things have landed
	return App.session.trial


## Puts [param side]'s fingertip on [param point], coming from in front of the eyes.
func _tip_to(point: Vector3, side := &"right") -> void:
	var eye := App.head().global_position
	var along := (point - (eye + Vector3.DOWN * 0.2)).normalized()
	input.point(side, point - along * App.rig.pointer(side).tip_reach, point)
	await frames(2)


## Takes [param thing] and holds it at [param cell] until it is put (or not).
func _carry(trial: Trial, thing: Target, cell: int, side := &"right") -> void:
	await _tip_to(App.head().global_position + Vector3(0.0, -0.25, -0.15), side)
	await _tip_to(thing.global_position, side)
	await _tip_to(trial.get("_cell_point")[cell], side)
	await wait(TRIAL.HOLD + 0.2)


func _thing(trial: Trial, key: String) -> Target:
	var keys: Dictionary = trial.get("_key")
	return keys.find_key(key)


func _cell(trial: Trial, key: String) -> int:
	return (trial.get("_cell_key") as Array).find(key)


func test_every_thing_has_its_sticker_and_all_are_in_reach() -> void:
	var trial := await _start(1, 1.0)
	var keys: Array = trial.get("_cell_key")
	var things: Array = trial.get("_things")
	expect_eq(things.size(), 6, "six things at the hardest")
	expect_eq(keys.filter(func(key: String) -> bool: return not key.is_empty()).size(), 6, "six stickers")
	for thing: Target in things:
		expect_eq(keys.count(trial.get("_key")[thing]), 1, "one sticker for %s" % thing.id)
	expect(trial.get("_key").values().has("egg") and trial.get("_key").values().has("drum"), "look-alikes at six")
	var eye := App.head().global_position
	var reach := TRIAL.SNAP + 0.4 * (eye.y - App.rig.global_position.y)
	for point: Vector3 in (trial.get("_cell_point") as Array) + things.map(func(thing: Target) -> Vector3: return thing.global_position):
		var shoulder := eye + Vector3.DOWN * 0.2
		expect(point.distance_to(shoulder + Vector3.RIGHT * 0.13) < reach or point.distance_to(shoulder + Vector3.LEFT * 0.13) < reach,
			"within easy reach: %s" % point)
		expect(point.y < eye.y - 0.1, "below the eyes: %s" % point)


func test_the_right_thing_clicks_in_and_the_round_ends_when_all_are_back() -> void:
	var trial := await _start()
	var feedback := record(Events.feedback)
	var picked := record(Events.picked)
	var ended := record(Events.trial_ended)
	var things: Array = (trial.get("_things") as Array).duplicate()
	for thing: Target in things:
		var cell := _cell(trial, trial.get("_key")[thing])
		await _carry(trial, thing, cell)
		expect(trial.get("_placed").has(thing) or not trial.is_running(), "%s is in" % thing.id)
		expect(thing.global_position.distance_to(trial.get("_cell_point")[cell]) < 0.01, "in its cubby")
		await _tip_to(App.head().global_position + Vector3(0.0, -0.25, -0.15))
		await wait(TRIAL.TAKE_PAUSE)
	expect_eq(ended.size(), 1, "the round is over")
	expect(ended[0][1] and ended[0][2].first_try, "solved on the first try")
	expect_eq(ended[0][2].puts.size(), 3, "every put logged")
	expect_eq(picked.size(), 3, "a pick per put")
	expect(picked.all(func(args: Array) -> bool: return args[0].correct), "all right")
	expect_eq(feedback.filter(func(args: Array) -> bool: return args[0] == &"good").size(), 3, "a click each time")


func test_a_wrong_thing_does_not_fit_and_goes_back() -> void:
	var trial := await _start()
	var said := record(Events.said)
	var feedback := record(Events.feedback)
	var things: Array = trial.get("_things")
	var thing: Target = things[0]
	var home: Vector3 = trial.get("_home")[thing]
	var wrong := _cell(trial, trial.get("_key")[things[1]])
	await _carry(trial, thing, wrong)
	expect_eq(trial.tries, 1, "a try")
	expect_eq(feedback.back()[0], &"bad", "it does not fit")
	expect(said.back()[0].begins_with("That's not its shape"), "the guide says why: %s" % said.back()[0])
	expect(not trial.get("_placed").has(thing) and trial.get("_carried").is_empty(), "nor does it stay on the finger")
	await _tip_to(App.head().global_position + Vector3(0.0, -0.25, -0.15))
	await wait(0.5)
	expect(thing.global_position.distance_to(home) < 0.01, "back on the bench")


func test_holding_still_away_from_stickers_keeps_it_on_the_finger() -> void:
	var trial := await _start()
	var thing: Target = trial.get("_things")[0]
	await _tip_to(App.head().global_position + Vector3(0.0, -0.25, -0.15))
	await _tip_to(thing.global_position)
	expect(trial.get("_carried").get(&"right") == thing, "it sticks to the fingertip")
	var other: Target = trial.get("_things")[1]
	await _tip_to(other.global_position)
	expect(trial.get("_carried").get(&"right") == thing, "a hand holds one thing at a time")
	expect(thing.global_position.distance_to(App.rig.pointer(&"right").tip()) < 0.001, "and it follows the finger")
	await wait(1.0)
	expect_eq(trial.tries, 0, "held still over the bench: nothing is judged")


func test_help_wiggles_then_lights_the_right_cubby() -> void:
	var trial := await _start()
	var said := record(Events.said)
	var thing: Target = trial.get("_things")[0]
	var cell := _cell(trial, trial.get("_key")[thing])
	var sticker: Node3D = trial.get("_stickers")[cell]
	await raise_hand()
	expect_eq(trial.hint_level, 1, "first hint")
	await wait(0.15)
	expect(absf(sticker.rotation.z) > 0.01, "its sticker wiggles")
	await raise_hand()
	expect_eq(trial.hint_level, 2, "second hint")
	expect_eq((trial.get("_cards") as Array)[cell].albedo_color, TRIAL.SHINE, "its cubby shines")
	expect(said.back()[0].contains("shining"), "and the guide says so")
	await _carry(trial, thing, cell)
	var next: Target = trial.call(&"_focus")
	expect_eq((trial.get("_cards") as Array)[_cell(trial, trial.get("_key")[next])].albedo_color, TRIAL.SHINE,
		"help moves on to the next thing")
	expect_eq((trial.get("_cards") as Array)[cell].albedo_color, TRIAL.CARD, "and leaves the one done")


func test_sizes_colours_and_outlines() -> void:
	var trial := await _start(1, 0.34, {&"match": 1.0})
	var keys: Array = trial.get("_key").values()
	expect_eq(keys.size(), 4, "four sizes")
	expect_eq(keys.map(func(key: String) -> String: return key.get_slice("_", 0)).reduce(
		func(same: bool, shape: String) -> bool: return same and shape == keys[0].get_slice("_", 0), true), true, "one shape")
	var sizes: Array = trial.get("_size").values()
	sizes.sort()
	expect(sizes[0] < sizes[1] * 0.85 and sizes[2] < sizes[3] * 0.85, "sizes well apart: %s" % [sizes])
	await shutdown()
	trial = await _start(1, 0.67, {&"match": 2.0})
	var colours: Array = (trial.get("_things") as Array).map(func(thing: Target) -> Color:
		return (thing.get_meta(&"material") as StandardMaterial3D).albedo_color)
	expect_eq(colours.size(), 5, "five things")
	expect_eq(colours.filter(func(colour: Color) -> bool: return colour == colours[0]).size(), 1, "each its own colour")
	var thing: Target = trial.get("_things")[0]
	var sticker: Node3D = trial.get("_stickers")[_cell(trial, trial.get("_key")[thing])]
	expect_eq((sticker.get_child(0).get_child(0) as MeshInstance3D).material_override.albedo_color, colours[0], "a sticker of its colour")
	await shutdown()
	trial = await _start(1, 0.0, {&"outline": 1.0})
	sticker = (trial.get("_stickers") as Array).filter(func(node: Node3D) -> bool: return node != null)[0]
	expect(sticker.get_child_count() >= 2, "an outline: the edge in ink, the inside in card")
	expect(sticker.get_child(0).scale.x > sticker.get_child(1).scale.x, "the ink a little bigger")
