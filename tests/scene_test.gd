extends TestCase
## Scene switches use the real menu input and discard the outgoing activity.

const FIND := preload("res://trials/find/find.tres")


func _press(id: String) -> void:
	var panel: Node3D = App.module(&"Facilitator").get("_panel")
	await select((panel.find_child(id, true, false) as Target).global_position)


func test_the_menu_switches_freely_between_all_three_scenes() -> void:
	await boot(null, &"intro")
	app.autostart = true
	var rig := App.rig
	var reality := App.reality
	var facilitator := App.module(&"Facilitator")
	for id: StringName in [&"global_motion", &"find_object", &"intro"]:
		input.menu()
		await frames(2)
		await _press("fac_scenes")
		var panel: Node3D = facilitator.get("_panel")
		var current: Target = panel.find_child("fac_scene_" + String(app.current_scene), true, false)
		expect(facilitator.get("_disabled")[current], "the current scene is marked and disabled")
		await _press("fac_scene_" + String(id))
		expect(await until(func() -> bool: return app.current_scene == id and not app.switching), "switched to %s" % id)
		expect(not facilitator.is_open and not get_tree().paused, "the menu closes and play resumes")
		expect(App.rig == rig and App.reality == reality, "the rig and room stay")
		expect_eq(get_tree().get_nodes_in_group(Module.GROUP).size(), 6, "modules stay without duplicates")
		expect_eq(App.session.get_parent().name, {&"intro": &"Intro", &"find_object": &"FindTheObject", &"global_motion": &"GlobalMotion"}[id], "one active scene")
	await wait(3.0)
	expect(app.find_child("Entry", true, false) != null and App.world == null, "Intro can be replayed")


func test_switching_mid_round_clears_targets_voice_effects_and_view_without_scoring() -> void:
	await boot(plan_of(FIND, 2))
	App.session.run()
	expect(await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running()), "a round starts")
	var ended := record(Events.trial_ended)
	var old_session := App.session
	var trial := App.session.trial
	var level := Profile.level(FIND.skill)
	Events.feedback.emit(&"good", trial.focus_point())
	App.reality.apply_view(load("res://content/views/greyscale.tres"))
	await app.change_scene(&"global_motion")
	expect(not is_instance_valid(trial) and not is_instance_valid(old_session), "the trial and its awaiting session are gone")
	expect(ended.is_empty() and Profile.level(FIND.skill) == level, "an interrupted round is unscored")
	expect_eq(App.stage.get_child_count(), 0, "no targets, replay ball or wall remains")
	expect_eq(App.module(&"Magic").get_child_count(), 0, "sparkles removed")
	expect_eq(App.module(&"Feedback").get_child_count(), 0, "feedback removed")
	expect(not (App.module(&"Voice").get("_player") as AudioStreamPlayer).playing, "old voice stopped")
	expect(not (App.module(&"Voice").get("_label") as Label3D).visible, "old subtitle removed")
	expect_eq(App.reality.view.title, "Normal", "the next scene starts in normal colour")
	await wait(4.0)
	expect(ended.is_empty() and App.stage.get_child_count() == 0, "the old coroutine never starts another round")


func test_game_targets_in_front_of_the_panel_cannot_block_a_scene_button() -> void:
	await boot()
	input.menu()
	await frames(2)
	await _press("fac_scenes")
	var panel: Node3D = App.module(&"Facilitator").get("_panel")
	var button: Target = panel.find_child("fac_scene_global_motion", true, false)
	var eye := App.head().global_position
	var origin := eye + (button.global_position - eye).normalized() * 0.25 + Vector3.DOWN * 0.05
	var blocker := Target.sphere(&"game_target", 0.08)
	App.stage.add_child(blocker)
	blocker.global_position = origin.lerp(button.global_position, 0.5)
	await frames(2)
	input.point(&"right", origin, button.global_position)
	await frames(2)
	expect_eq(App.rig.pointer(&"right").cast(), button, "the panel gets the ray through the game target")
	input.click(&"right", &"trigger_click")
	expect(await until(func() -> bool: return app.current_scene == &"global_motion" and not app.switching), "the scene button works")


func test_progress_survives_scene_switches_and_the_headset_keeps_its_pause() -> void:
	await boot()
	await App.world._complete(load("res://content/tasks/tidy_shelf.tres"), 0)
	App.hold_pause(&"headset", true)
	await app.change_scene(&"global_motion")
	expect(get_tree().paused, "switching does not release the headset's pause")
	App.hold_pause(&"headset", false)
	await App.world._complete(load("res://content/tasks/break_wall.tres"), 0)
	await app.change_scene(&"find_object")
	expect_eq(App.world.done, {&"tidy_shelf": [0], &"break_wall": [0]}, "both activities keep their progress")
	var session := App.session
	await app.change_scene(&"find_object")
	expect(App.session == session and not app.switching, "choosing the current scene does not restart it")


func test_leaving_intro_removes_its_music_debug_label_and_waiting_story() -> void:
	await boot(null, &"intro")
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false   # these tests look at the room before pressing anything
	entry.run()
	# The opening waits for the grown-up's setup; a jump button skips it and starts the story.
	await until(func() -> bool: return entry.find_child("entry_part_hello", true, false) != null, 10.0)
	entry._on_target(entry.find_child("entry_part_hello", true, false) as Target)
	await wait(3.0)
	var music: AudioStreamPlayer = entry.get("_music")
	var label: Label3D = entry.get("_beat_label")
	expect(music.playing and label.is_inside_tree(), "the opening is playing")
	await app.change_scene(&"find_object")
	expect(not is_instance_valid(entry) and not is_instance_valid(music) and not is_instance_valid(label), "all opening output removed")
	var said := record(Events.said)
	await wait(10.0)
	expect(said.is_empty(), "the old story never speaks again")
