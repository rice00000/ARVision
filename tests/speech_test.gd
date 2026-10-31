extends TestCase
## Baked speech: every line the guide can say has files, and Voice plays them.

const FIND := preload("res://trials/find/find_trial.gd")
const POINT := preload("res://trials/point_real/point_real.tscn")


func _baked(text: String) -> void:
	var paths := BakedSpeech.paths_for(text)
	expect(not paths.is_empty(), "baked: %s" % text)
	for path in paths:
		expect(ResourceLoader.exists(path), "imported: %s" % path)


func test_every_session_line_is_baked() -> void:
	var defaults := SessionPlan.new()
	_baked(defaults.greeting)
	_baked(defaults.farewell)
	for file in DirAccess.get_files_at("res://content/sessions"):
		var plan: SessionPlan = load("res://content/sessions/" + file)
		_baked(plan.greeting)
		_baked(plan.farewell)
		for block in plan.blocks:
			if not block.intro.is_empty():
				_baked(block.intro)


func test_named_things_are_baked_in_their_lines() -> void:
	for shape in FIND.SHAPES:
		_baked("Find the %s!" % shape)
		_baked("Look for the %s, on your %s." % [shape, "left"])
	var trial := POINT.instantiate()
	var labels: PackedStringArray = trial.labels
	trial.free()
	for label in labels:
		_baked("Point at the %s and pinch your fingers." % label)
		_baked("The %s is on your %s." % [label, "front"])
	_baked("That's the %s. Find the %s!" % ["teddy bear", labels[0]])


func test_every_level_button_is_read_out() -> void:
	for file in DirAccess.get_files_at("res://content/tasks"):
		if file.ends_with(".tres"):
			var task: Task = load("res://content/tasks/" + file)
			for level in task.levels.size():
				_baked("Level %d. A new one!" % (level + 1))
				_baked("Level %d. Done!" % (level + 1))


func test_voice_plays_the_line_and_cuts_off_the_last() -> void:
	await boot(plan_of(load("res://trials/find/find.tres"), 1))
	var player: AudioStreamPlayer = App.module(&"Voice").get("_player")
	Events.say("Find the ball!")
	expect(player.playing and player.stream is AudioStreamPlaylist, "two baked phrases play as one line")
	expect(player.stream.get_length() > 0.5, "with real audio")
	Events.say("Look around the room.")
	expect(player.playing and player.stream is AudioStreamOggVorbis, "a newer line replaces it")


func test_the_voice_says_when_a_line_ends_and_whether_it_was_cut_off() -> void:
	await boot(plan_of(load("res://trials/find/find.tres"), 1))
	var voice := App.module(&"Voice")
	var ended := record(voice.line_finished)
	Events.say("Look around the room.")
	expect(await until(func() -> bool: return ended.size() == 1, 15.0), "a line that plays out says so")
	expect(ended[0][0] == "Look around the room." and ended[0][1] == true, "with its text, completed")
	Events.say("Find the ball!")
	Events.say("Look around the room.")
	expect(ended.size() >= 2 and ended[1][0] == "Find the ball!" and ended[1][1] == false, "a newer line cuts it off: not completed")
	expect(await until(func() -> bool: return ended.size() == 3, 15.0), "and the newer one ends too")


func test_a_line_with_no_baked_clip_does_not_crash_the_voice_and_still_ends() -> void:
	await boot(plan_of(load("res://trials/find/find.tres"), 1))
	var voice := App.module(&"Voice")
	var ended := record(voice.line_finished)
	Events.say("Zzzz a line nobody ever baked.")
	expect(await until(func() -> bool: return ended.size() == 1, 15.0), "it ends after its subtitle time")
	expect(ended[0][1] == true, "completed")
	Events.say("Look around the room.")
	expect(await until(func() -> bool: return ended.size() == 2, 15.0), "and the voice still works afterwards")
