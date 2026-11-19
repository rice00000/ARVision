extends TestCase
## The Turn to fit scene in the game (turn_to_fit/turn_to_fit.gd), driven like a person would:
## the board, the "It fits!" button and the cards are pressed by pointing and clicking. The camera
## is Megan's mug photos, and the captures are the saved SAM outlines (no CV server in tests).
##   godot --headless --xr-mode off --fixed-fps 60 --path . res://tests/run.tscn -- --profile=test --only=turn_to_fit_scene

const DATA := "res://tests/data/turn_to_fit/"

var _view := "left"   # which photo the "camera" shows


func _photo(view: String) -> Image:
	return Image.load_from_file(DATA + "santa_%s.jpg" % view)


func _box(view: String) -> Rect2i:
	var b: Array = JSON.parse_string(FileAccess.get_file_as_string(DATA + "santa.json")).boxes[view]
	return Rect2i(int(b[0]), int(b[1]), int(b[2] - b[0]), int(b[3] - b[1]))


## Boots the game into the scene, with the photos as its camera.
func _start() -> TurnToFit:
	await boot(null, &"turn_to_fit")
	var fit := app.find_child("Fit", true, false) as TurnToFit
	fit.server_file = Profile.path("cv_server.txt")
	fit.frame_source = func() -> Image: return _photo(_view)
	fit.tracker.use_server = false
	fit.tracker.threaded = false   # the same rounds every run (the threaded path: fit_tracker_test)
	await fit.run()
	return fit


## Captures [param views] from the photos and their saved SAM outlines.
func _capture(fit: TurnToFit, views: Array) -> void:
	for view: String in views:
		_show(fit, view)
		var mask := Image.load_from_file(DATA + "santa_%s_sam.png" % view)
		fit.tracker.add_capture(view, _photo(view), mask, _box(view))


## The camera now sees [param view] (and YOLO's box for it).
func _show(fit: TurnToFit, view: String) -> void:
	_view = view
	fit.tracker.set_box(_box(view))


func _press(fit: TurnToFit, id: String) -> void:
	await select((fit.find_child(id, true, false) as Node3D).global_position)


func test_the_setup_board_stands_on_the_table_above_the_cup() -> void:
	var fit := await _start()
	var table_y := App.reality.work_surface().transform.origin.y
	var window: MeshInstance3D = fit.get("_window")
	var eye := App.head().global_position
	var bottom := window.global_position.y - TurnToFit.WINDOW.y * 0.5
	expect(bottom > table_y + 0.12, "the window's bottom is %.2f m above the table: the real cup stays in view" % (bottom - table_y))
	var ahead := Vector2(window.global_position.x - eye.x, window.global_position.z - eye.z).length()
	expect(absf(ahead - TurnToFit.AHEAD) < 0.05, "it stands %.2f m ahead" % ahead)
	expect(fit.find_child("Onion", true, false) != null, "Onion is there")
	expect(not (fit.get("_fits") as Node3D).visible, "no \"It fits!\" button in setup")
	expect(fit.find_child("SetupBoard", true, false) != null, "the adult's board is there")


func test_the_board_captures_and_a_turn_round_ends_when_the_cards_view_fits() -> void:
	var fit := await _start()
	var reported := record(Events.reported)
	await _press(fit, "fit_play_turn")
	expect_eq(fit.session, "", "no play with fewer than 2 targets")
	_capture(fit, ["left", "right", "toward"])
	expect_eq(fit.matcher.names.size(), 3, "three targets")
	await _press(fit, "fit_play_turn")
	expect_eq(fit.session, "turn", "playing")
	_show(fit, ["left", "right", "toward"][(TurnToFit.TARGETS.find(fit.matcher.names[fit.game.card]) + 1) % 3])
	await wait(1.5)
	expect(fit.game.playing, "another view doesn't end the round")
	_show(fit, fit.matcher.names[fit.game.card])
	expect(await until(func() -> bool: return not fit.game.playing), "the card's own view fits")
	var rounds := reported.filter(func(r: Array) -> bool: return r[0] == &"turn_to_fit_round")
	expect_eq(rounds.size(), 1, "one round reported for the logs")
	expect_eq(rounds[0][1].result if not rounds.is_empty() else "", "fit", "result")
	expect(await until(func() -> bool: return fit.game.playing, 4.0), "the next round starts by itself")


func test_a_blind_round_waits_for_the_it_fits_button() -> void:
	var fit := await _start()
	_capture(fit, ["left", "right"])
	await _press(fit, "fit_help")
	await _press(fit, "fit_help")
	expect_eq(fit.game.help, FitGame.Help.BLIND, "help: blind, from the board")
	await _press(fit, "fit_play_turn")
	var button: Node3D = fit.get("_fits")
	expect(button.visible, "the brass button shows in blind rounds")
	_show(fit, fit.matcher.names[fit.game.card])
	await wait(2.0)
	expect(fit.game.playing, "holding the right view doesn't end it: no glow gives it away")
	await select(button.global_position)
	expect(not fit.game.playing and fit.result.get("result") == "fit", "\"It fits!\" on the right view: fit")


func test_which_is_mine_is_answered_by_pointing_at_a_card() -> void:
	var fit := await _start()
	_capture(fit, ["left", "right", "toward"])
	await _press(fit, "fit_play_pick")
	var cards: Array = fit.get("_cards")
	expect(cards.all(func(c: Node3D) -> bool: return c.visible), "three cards show")
	_show(fit, "right")
	await wait(1.0)
	var slot := fit.game.cards.find(fit.matcher.names.find("right"))
	await select((cards[slot] as Node3D).global_position)
	expect_eq(fit.result.get("result"), "match", "the right card")
	expect_eq(fit.result.get("help"), "none", "a check-in: no help")


func test_leaving_for_another_scene_takes_everything_away() -> void:
	var fit := await _start()
	_capture(fit, ["left", "right"])
	await _press(fit, "fit_play_turn")
	await app.change_scene(&"find_object")
	expect(await until(func() -> bool: return app.current_scene == &"find_object" and not app.switching), "switched")
	expect(not is_instance_valid(fit), "the scene is gone")
	expect(app.find_child("SetupBoard", true, false) == null, "no board left behind")


func test_setup_goes_step_by_step_and_a_saved_setup_comes_back_next_time() -> void:
	var fit := await _start()
	var words: Label3D = fit.get("_words")
	await wait(0.5)
	expect(words.text.begins_with("Setup 1/3"), "first: the cup in view (%s)" % words.text)
	_show(fit, "left")
	await wait(0.5)
	expect(words.text.begins_with("Setup 2/3") and "left" in words.text, "then: handle left (%s)" % words.text)
	expect((fit.find_child("fit_capture_left", true, false).get_parent() as EntryButton) != null, "the board has the button")
	_capture(fit, ["left"])
	await wait(2.2)
	expect("right" in words.text, "then: handle right (%s)" % words.text)
	_capture(fit, ["right"])
	await wait(2.2)
	expect(words.text.begins_with("Setup 3/3"), "then: save (%s)" % words.text)
	await _press(fit, "fit_save")
	expect(FileAccess.file_exists(Profile.path(TurnToFit.SAVE_FILE)), "saved in the player's save folder")
	await wait(2.2)
	expect(words.text.begins_with("Ready"), "then: ready to play (%s)" % words.text)
	# Leave and come back: the cards are there without capturing again.
	await app.change_scene(&"find_object")
	await until(func() -> bool: return not app.switching)
	await app.change_scene(&"turn_to_fit")
	await until(func() -> bool: return not app.switching)
	var again := app.find_child("Fit", true, false) as TurnToFit
	again.frame_source = func() -> Image: return _photo(_view)
	again.tracker.use_server = false
	await again.run()
	expect_eq(again.matcher.names, ["left", "right"] as Array[String], "the saved cards are back")
	expect(not again.tracker.model.is_empty(), "and the cup's colours")
	await _press(again, "fit_play_turn")
	expect_eq(again.session, "turn", "play starts straight away")


## The setup page (Megan, Nov 18): the laptop's address is typed on the board's number pad, once per headset.
func test_the_number_pad_saves_the_laptops_address_on_the_headset() -> void:
	var fit := await _start()
	var shown: Label3D = fit.get("_address_label")
	expect(shown != null and shown.text.begins_with("Server:"), "the board shows the address line")
	for key: String in ["1", "9", "2", "dot", "1", "6", "8", "dot", "1", "dot", "2", "3", "4", "back"]:
		await _press(fit, "fit_key_" + key)
	expect(shown.text.begins_with("Server: 192.168.1.23"), "typed: %s" % shown.text)
	await _press(fit, "fit_server_save")
	expect_eq(FitTracker.saved_server(fit.server_file), "http://192.168.1.23:8765", "saved on this headset")
	expect_eq(fit.tracker.server, "http://192.168.1.23:8765", "and used now")
	expect("saved" in shown.text, "the board says it's saved (%s)" % shown.text)
