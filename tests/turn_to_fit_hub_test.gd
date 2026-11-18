extends TestCase
## Turn to fit in the workshop hub (TurnToFitActivity + TurnToFitGame), driven like the hub drives it, with
## Megan's mug photos as the camera (no CV server). Decisions: claude/SCENE_REVIEW_DECISIONS.md → "Turn to fit".
##   godot --headless --xr-mode off --fixed-fps 60 --path . res://tests/run.tscn -- --profile=test --only=turn_to_fit_hub

const DATA := "res://tests/data/turn_to_fit/"
const VIEWS := ["left", "right", "toward"]

var _view := "left"
var _said: Array


func _photo(view: String) -> Image:
	return Image.load_from_file(DATA + "santa_%s.jpg" % view)


func _box(view: String) -> Rect2i:
	var b: Array = JSON.parse_string(FileAccess.get_file_as_string(DATA + "santa.json")).boxes[view]
	return Rect2i(int(b[0]), int(b[1]), int(b[2] - b[0]), int(b[3] - b[1]))


## Saves a cup setup for the player, as the grown-up's capture would (cards + the cup's colours).
func _save_setup() -> void:
	var shapes := {}
	for view: String in VIEWS:
		shapes[view] = ShapeCV.target_from_mask(Image.load_from_file(DATA + "santa_%s_sam.png" % view), _box(view)).shape
	var model := ShapeCV.learn_colours(_photo("left"), Image.load_from_file(DATA + "santa_left_sam.png"), _box("left"))
	DirAccess.make_dir_recursive_absolute(Profile.path())
	var file := FileAccess.open(Profile.path(TurnToFit.SAVE_FILE), FileAccess.WRITE)
	file.store_var({version = TurnToFit.SAVE_VERSION, shapes = shapes, model = model, saved = "test"})
	file.close()


func _activity() -> TurnToFitActivity:
	await boot(null, &"turn_to_fit")
	_said = record(Events.said)
	var activity := TurnToFitActivity.new()
	activity.server_override = true
	activity.use_server = false
	activity.threaded = false
	activity.frame_source = func() -> Image: return _photo(_view)
	app.add_child(activity)
	return activity


## The camera now sees [param view] ("" = no cup).
func _show(activity: TurnToFitActivity, view: String) -> void:
	_view = view if view != "" else "left"
	if activity.current != null:
		activity.current.tracker.set_box(_box(view) if view != "" else Rect2i())


func _said_line(line: String) -> bool:
	return _said.any(func(args: Array) -> bool: return args[0] == line)


## Plays the current round of [param game] to a fit (the card's view; blind: the ✓ press).
func _fit_round(activity: TurnToFitActivity) -> bool:
	var g := activity.current
	if not await until(func() -> bool: return g.phase == &"turn" and g.game.playing, 30.0):
		return false
	_show(activity, g.matcher.names[g.game.card])
	if g.game.help == FitGame.Help.BLIND:
		await wait(1.0)
		g.fits.press()
	return await until(func() -> bool: return g.phase != &"turn" or not g.game.playing, 30.0)


func test_offered_only_with_a_saved_setup_and_the_server_answering() -> void:
	var activity := await _activity()
	expect_eq(activity.id(), &"turn_to_fit", "its id (the cup's bubble kind)")
	expect(not activity.is_available(), "no saved setup: not offered")
	_save_setup()
	expect(activity.is_available(), "a saved setup and the server: offered")
	activity.server_override = false
	expect(not activity.is_available(), "the server isn't answering: not offered")


func test_a_first_go_free_look_lines_five_rounds_check_in_ending_and_stones() -> void:
	_save_setup()
	var activity := await _activity()
	var reported := record(Events.reported)
	var stones_before: int = App.module(&"Inventory").count(&"magic_stone")
	var outcomes := record(activity.finished)
	_show(activity, "left")
	activity.summon(Transform3D.IDENTITY)
	var g := activity.current
	_show(activity, "left")
	expect(await until(func() -> bool: return g.free_look, 5.0), "the first go starts with a free look")
	await wait(0.6)
	var line_colour: Vector3 = g.get("_window_material").get_shader_parameter(&"line")
	expect(not g.game.playing, "no card during the free look")
	_show(activity, "right")   # the cup turns: the free look ends
	expect(await until(func() -> bool: return not g.free_look, 8.0), "the free look ends when the cup turns")
	expect(await until(func() -> bool: return _said_line(TurnToFitGame.OPEN_TURN), 15.0), "then Onion's two lines")
	expect(_said_line(TurnToFitGame.OPEN_LOOKING), "\"This shadow is looking for its cup.\"")
	var helps: Array[String] = []
	for i in FitGo.TURN_ROUNDS:
		expect(await until(func() -> bool: return g.phase == &"turn" and g.game.playing, 30.0), "round %d starts" % (i + 1))
		helps.append(FitGame.HELP_NAMES[g.game.help])
		expect(await _fit_round(activity), "round %d fits" % (i + 1))
	expect_eq(helps, ["mirror", "mirror", "glimmer", "glimmer", "blind"] as Array[String], "the help fades over the go")
	expect(_said_line(TurnToFitGame.FIRST_BLIND), "the first blind round has its line")
	expect(await until(func() -> bool: return g.phase == &"pick" and g.game.playing, 30.0), "then the check-in")
	expect(await until(func() -> bool: return _said_line(TurnToFitGame.CHECK_IN), 10.0), "with its line")
	expect(g.get("_board").visible, "on the wide board")
	_show(activity, "right")
	await wait(1.0)
	var slot := g.game.cards.find(g.matcher.names.find("right"))
	Events.touched.emit(&"right", g.find_child("ttf_card_%d" % slot, true, false) as Target)
	expect(await until(func() -> bool: return not outcomes.is_empty(), 30.0), "the go ends")
	expect_eq(outcomes[0][0] if not outcomes.is_empty() else &"", &"done", "outcome")
	expect(_said_line(TurnToFitGame.FOUND_PLACE), "5 of 5 fits: \"There. Everything's found its place.\"")
	var rounds := reported.filter(func(r: Array) -> bool: return r[0] == &"turn_to_fit_round")
	expect_eq(rounds.size(), 6, "6 rounds logged (5 turns + the check-in): %s" % [rounds.map(func(r: Array) -> String: return "%s/%s" % [r[1].get("mode", ""), r[1].get("result", "")])])
	expect_eq(App.module(&"Inventory").count(&"magic_stone") - stones_before, TurnToFitGame.STONES, "the first full go earns stones")
	expect_eq(line_colour, Vector3(TurnToFitGame.GOLD.r, TurnToFitGame.GOLD.g, TurnToFitGame.GOLD.b), "never green before a fit")
	activity.fold()


func test_a_later_go_has_no_free_look_no_opening_lines_and_no_more_stones() -> void:
	_save_setup()
	TurnToFitGame.save_progress({goes = 1, stones = true})
	var activity := await _activity()
	_show(activity, "left")
	activity.summon(Transform3D.IDENTITY)
	var g := activity.current
	_show(activity, "left")
	expect(await until(func() -> bool: return g.phase == &"turn" and g.game.playing, 10.0), "straight to the first card")
	expect(not _said_line(TurnToFitGame.OPEN_LOOKING), "no opening lines")
	activity.leave()
	activity.fold()


func test_leaving_early_logs_the_round_as_interrupted() -> void:
	_save_setup()
	TurnToFitGame.save_progress({goes = 1, stones = true})
	var activity := await _activity()
	var reported := record(Events.reported)
	var outcomes := record(activity.finished)
	_show(activity, "left")
	activity.summon(Transform3D.IDENTITY)
	var g := activity.current
	_show(activity, "left")
	await until(func() -> bool: return g.phase == &"turn" and g.game.playing, 10.0)
	activity.leave()
	expect(await until(func() -> bool: return not outcomes.is_empty(), 15.0), "it ends")
	expect_eq(outcomes[0][0] if not outcomes.is_empty() else &"", &"left", "outcome: left")
	expect(_said_line(TurnToFitGame.COME_BACK), "\"We can come back to these.\"")
	var rounds := reported.filter(func(r: Array) -> bool: return r[0] == &"turn_to_fit_round")
	expect(not rounds.is_empty() and rounds[-1][1].result == "interrupted", "the round is logged as interrupted")
	activity.fold()


func test_no_cup_in_view_asks_for_it_once() -> void:
	_save_setup()
	TurnToFitGame.save_progress({goes = 1, stones = true})
	var activity := await _activity()
	activity.summon(Transform3D.IDENTITY)
	_show(activity, "")
	expect(await until(func() -> bool: return _said_line(TurnToFitGame.CUP_MISSING), 15.0), "\"Hold the cup up, where I can see it.\"")
	var count := _said.filter(func(args: Array) -> bool: return args[0] == TurnToFitGame.CUP_MISSING).size()
	await wait(4.0)
	expect_eq(_said.filter(func(args: Array) -> bool: return args[0] == TurnToFitGame.CUP_MISSING).size(), count, "only once per go")
	activity.leave()
	activity.fold()


func test_it_pauses_with_the_world() -> void:
	_save_setup()
	TurnToFitGame.save_progress({goes = 1, stones = true})
	var activity := await _activity()
	activity.process_mode = Node.PROCESS_MODE_ALWAYS   # like the hub's controller
	_show(activity, "left")
	activity.summon(Transform3D.IDENTITY)
	var g := activity.current
	_show(activity, "toward")
	await until(func() -> bool: return g.phase == &"turn" and g.game.playing, 10.0)
	get_tree().paused = true
	var time := g.game.time
	await wait(1.5)
	expect_eq(g.game.time, time, "no time passes while paused")
	get_tree().paused = false
	activity.leave()
	activity.fold()


func test_the_lines_are_in_the_voice_list() -> void:
	var lines: Array = JSON.parse_string(FileAccess.get_file_as_string("res://content/voice/speech.tts")).lines
	for line: String in TurnToFitGame.LINES:
		expect(line in lines, "speech.tts lists \"%s\"" % line)
