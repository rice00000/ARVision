extends TestCase

const SANDWICH := preload("res://trials/sandwich/sandwich.tres")


func _start() -> Trial:
	var plan := plan_of(SANDWICH, 1, false, 0.0)
	plan.blocks[0].ray = false
	await boot(plan)
	App.session.run()
	await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running())
	return App.session.trial


func _move_tip(point: Vector3, hand: StringName) -> void:
	input.point(hand, point + Vector3.UP * App.rig.pointer(hand).tip_reach, point)
	await frames(2)


func test_only_a_released_layer_is_judged_and_wrong_layers_return() -> void:
	var trial := await _start()
	var layout: Dictionary = trial.layout()
	var wrong: Dictionary = layout.things.filter(func(thing: Dictionary) -> bool: return thing.key != layout.recipe[0])[0]
	var picked := record(Events.picked)
	var feedback := record(Events.feedback)
	var sample: Node3D = trial.get("_sample")
	var sample_poses: Array = sample.find_children("*", "Node3D", true, false).map(func(node: Node3D) -> Transform3D: return node.transform)
	await _move_tip(wrong.centre, &"left")
	input.press(&"left", &"trigger_click", true)
	await _move_tip(layout.plate, &"left")
	trial.escalate()
	await wait(0.17)
	expect_eq(trial.layout().placed, 0, "hover above the plate never auto-places a layer")
	expect(picked.is_empty() and feedback.is_empty(), "pickup, hover and help do not reveal the answer")
	expect_eq(sample.find_children("*", "Node3D", true, false).map(func(node: Node3D) -> Transform3D: return node.transform),
		sample_poses, "giving help leaves the sample unchanged")
	input.press(&"left", &"trigger_click", false)
	await _move_tip(wrong.home, &"left")
	await wait(0.42)
	expect_eq(trial.tries, 1, "drop is judged at the release pose")
	expect_eq(picked.size(), 1, "one measured choice")
	expect_eq(feedback[0][0], &"bad", "an immediate distinct mark and sound")
	expect_eq(trial.layout().placed, 0, "the existing stack is kept")
	var returned: Dictionary = trial.layout().things.filter(func(thing: Dictionary) -> bool: return thing.key == wrong.key)[0]
	expect(returned.centre.is_equal_approx(wrong.home), "the wrong ingredient is ready to pick again")


func test_tracking_pause_and_off_plate_releases_are_unscored() -> void:
	var trial := await _start()
	var picked := record(Events.picked)
	var thing: Dictionary = trial.layout().things[0]
	for reason in ["outside", "pause", "tracking"]:
		await _move_tip(thing.centre, &"right")
		input.press(&"right", &"trigger_click", true)
		await _move_tip(thing.centre + Vector3.UP * 0.13, &"right")
		match reason:
			"outside":
				input.press(&"right", &"trigger_click", false)
			"pause":
				get_tree().paused = true
				await frames(2)
				input.press(&"right", &"trigger_click", false)
				get_tree().paused = false
			"tracking":
				input.track(&"right", false)
				await frames(2)
				input.press(&"right", &"trigger_click", false)
				input.track(&"right", true)
		await wait(0.5)
		var returned: Dictionary = trial.layout().things[0]
		expect(returned.carried == &"" and returned.centre.is_equal_approx(thing.home), reason + " returns to the tray")
	expect(picked.is_empty() and trial.tries == 0, "no spatial choice was made")
