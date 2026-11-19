extends TestCase
## The optional story and data modules: Magic's effects, and the Picks CSV.

const FIND := preload("res://trials/find/find.tres")


func test_a_right_pick_sparkles_and_a_level_win_plays_a_clip() -> void:
	await boot()
	var magic := App.module(&"Magic")
	Events.feedback.emit(&"good", Vector3(0.0, 0.8, -0.4))
	Events.feedback.emit(&"bad", Vector3(0.0, 0.8, -0.4))
	expect_eq(magic.find_children("*", "CPUParticles3D", false, false).size(), 1, "sparkles for good only")
	expect(not magic.has_node(^"LevelCelebration"), "a right pick alone does not start the celebration")
	Events.level_won.emit(&"tidy_shelf", 1, 3)
	var clip := magic.get_node(^"LevelCelebration") as Sprite3D
	await wait(0.5)
	expect(clip.frame > 0, "the celebration advances")
	expect(await until(func() -> bool: return magic.get_child_count() == 0, 3.0), "it all goes by itself")
	Events.level_won.emit(&"tidy_shelf", 1, 2)
	Events.scene_changing.emit()
	expect(not magic.has_node(^"LevelCelebration"), "leaving clears the celebration")


func test_every_pick_is_a_csv_row_with_its_time_and_the_running_accuracy() -> void:
	var plan := plan_of(FIND, 2)
	plan.title = "Find the toys, level 1"
	await boot(plan)
	App.session.run()
	for round_index in 2:
		await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running())
		if round_index == 0:
			await wait(0.5)
			await select((App.session.trial.get("_toys").keys()[1] as Target).global_position)
		await select((App.session.trial.get("_target") as Target).global_position)
	var file := FileAccess.open(Profile.path("picks.csv"), FileAccess.READ)
	expect_eq(file.get_csv_line(), PackedStringArray(["time", "save", "game", "round", "target", "picked", "correct",
		"seconds", "accuracy"]), "header")
	var cells: Array[PackedStringArray] = []
	while file.get_position() < file.get_length():
		cells.append(file.get_csv_line())
	expect_eq(cells.size(), 3, "a row per pick")
	var save := String(Profile.id)
	expect_eq(cells.map(func(row: PackedStringArray) -> Array: return [row[1], row[2], row[3], row[6], row[8]]),
		[[save, "Find the toys, level 1", "1", "0", "0"], [save, "Find the toys, level 1", "1", "1", "50"],
		[save, "Find the toys, level 1", "2", "1", "67"]], "save, game, round, correct, accuracy")
	expect(cells[0][5] != cells[0][4] and cells[1][5] == cells[1][4], "picked against target")
	expect(float(cells[0][7]) >= 0.5 and float(cells[1][7]) >= float(cells[0][7]), "seconds since the round began")


func test_the_mix_puts_the_voice_over_the_sounds_over_the_piano() -> void:
	await boot()
	var bus := func(name: StringName) -> int: return AudioServer.get_bus_index(name)
	expect(bus.call(&"Music") < bus.call(&"SFX") and bus.call(&"SFX") < bus.call(&"Voice"),
		"the voice bus mixes first, so the others can dip under it")
	for ducked: StringName in [&"Music", &"SFX"]:
		var duck := AudioServer.get_bus_effect(bus.call(ducked), 0) as AudioEffectCompressor
		expect(duck != null and duck.sidechain == &"Voice", "%s dips while the guide speaks" % ducked)
	expect(AudioServer.get_bus_volume_db(bus.call(&"Music")) < AudioServer.get_bus_volume_db(bus.call(&"SFX")),
		"the piano sits under the sounds")
	expect_eq((App.module(&"Voice").get("_player") as AudioStreamPlayer).bus, &"Voice", "speech on the Voice bus")
	var piano := App.module(&"Music").get("_player") as AudioStreamPlayer
	expect(piano.playing and piano.bus == &"Music" and (piano.stream as AudioStreamOggVorbis).loop, "the piano loops")
	Events.feedback.emit(&"good", Vector3(0.0, 0.8, -0.4))
	var feedback := App.module(&"Feedback")
	expect_eq(feedback.get_child_count(), 1, "success plays a chime without a mark")
	expect_eq((feedback.get_child(0) as AudioStreamPlayer3D).bus, &"SFX", "chimes on the SFX bus")


func test_a_sound_plays_from_where_it_happens_and_leaves_with_its_scene() -> void:
	await boot()
	var sound := App.module(&"Sound")
	for cue: StringName in sound.CUES:
		for stream: AudioStream in sound.CUES[cue]:
			expect(stream.get_length() > 0.05, "%s has a sound" % cue)
	var at := Vector3(0.1, 0.8, -0.4)
	Events.play(&"place", at)
	var placed := sound.get_child(0) as AudioStreamPlayer3D
	expect(placed != null and placed.global_position.is_equal_approx(at) and placed.bus == &"SFX", "placed, on SFX")
	Events.play(&"transition")
	expect(sound.get_child(1) is AudioStreamPlayer, "a scene change plays flat")
	Events.play(&"ui_hover", at)
	Events.play(&"ui_hover", at)
	expect_eq(sound.get_child_count(), 3, "a ray sliding over buttons does not pile up hovers")
	Events.scene_changing.emit()
	expect(sound.get_child_count() == 1 and sound.get_child(0) is AudioStreamPlayer, "the old scene's sounds stop")
