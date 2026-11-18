extends TestCase
## One go of Turn to fit (FitGo): 5 turn rounds on the help ladder, then one check-in, then the end;
## the ending by the number of fits; the first blind round. On Megan's mug photos.
##   godot --headless --xr-mode off --fixed-fps 60 --path . res://tests/run.tscn -- --profile=test --only=fit_go

const DATA := "res://tests/data/turn_to_fit/"
const VIEWS := ["left", "right", "toward"]
const DT := 0.2

var _live := {}


func _box(view: String) -> Rect2i:
	var b: Array = JSON.parse_string(FileAccess.get_file_as_string(DATA + "santa.json")).boxes[view]
	return Rect2i(int(b[0]), int(b[1]), int(b[2] - b[0]), int(b[3] - b[1]))


func _go() -> FitGo:
	var matcher := FitMatcher.new()
	for view: String in VIEWS:
		matcher.add_target(view, ShapeCV.target_from_mask(Image.load_from_file(DATA + "santa_%s_sam.png" % view), _box(view)).shape)
	if _live.is_empty():
		var model := ShapeCV.learn_colours(Image.load_from_file(DATA + "santa_left.jpg"), Image.load_from_file(DATA + "santa_left_sam.png"), _box("left"))
		for view: String in VIEWS:
			_live[view] = ShapeCV.track(Image.load_from_file(DATA + "santa_%s.jpg" % view), _box(view), model).shape
	return FitGo.new(FitGame.new(matcher, 3))


## Plays the current turn round to its end: the card's view (a fit) or a wrong view held to the time-out.
func _play_turn(go: FitGo, fit: bool) -> Dictionary:
	var game := go.game
	var got: Array[Dictionary] = []   # a lambda can't assign an outer local: collect into an array
	var take := func(r: Dictionary) -> void: got.append(r)
	game.finished.connect(take)
	var view: String = game.matcher.names[game.card] if fit else game.matcher.names[(game.card + 1) % VIEWS.size()]
	if game.help == FitGame.Help.BLIND:
		for i in 3:
			game.matcher.update(_live[view], DT)
		game.commit()
	else:
		var steps := 0
		while game.playing and steps < int(FitGame.TIMEOUT / DT) + 2:
			game.matcher.update(_live[view], DT)
			game.update(DT)
			steps += 1
	game.finished.disconnect(take)
	return got[0] if not got.is_empty() else {}


func test_a_go_is_five_turn_rounds_then_one_check_in_then_the_end() -> void:
	var go := _go()
	expect(go.start(), "starts")
	expect_eq(go.game.help, FitGame.Help.MIRROR, "the help starts at Mirror")
	var helps: Array[String] = []
	for i in FitGo.TURN_ROUNDS:
		helps.append(FitGame.HELP_NAMES[go.game.help])
		var record := _play_turn(go, true)
		var next := go.next(record)
		expect_eq(next, &"turn" if i < FitGo.TURN_ROUNDS - 1 else &"pick", "after round %d" % (i + 1))
	expect_eq(helps, ["mirror", "mirror", "glimmer", "glimmer", "blind"] as Array[String], "every fit: round 5 is the first blind try")
	expect_eq(go.game.mode, FitGame.Mode.PICK, "the check-in")
	expect_eq(go.fits, 5, "five fits")
	expect_eq(go.next({mode = "pick", result = "match"}), &"end", "then the end")
	expect(go.over, "over")
	expect_eq(go.ending(), &"found_place", "5 of 5: found its place")


func test_the_ending_needs_four_fits() -> void:
	var go := _go()
	go.start()
	for result in ["fit", "fit", "fit", "fit", "miss"]:
		go.next({mode = "turn", result = result})
	expect_eq(go.ending(), &"found_place", "4 of 5")
	go = _go()
	go.start()
	for result in ["fit", "timeout", "fit", "miss", "fit"]:
		go.next({mode = "turn", result = result})
	expect_eq(go.ending(), &"come_back", "3 of 5")


func test_the_check_in_never_counts_and_never_changes_the_help() -> void:
	var go := _go()
	go.start()
	for i in FitGo.TURN_ROUNDS:
		go.next({mode = "turn", result = "miss"})
	var help := go.game.help
	go.next({mode = "pick", result = "match"})
	expect_eq(go.fits, 0, "a match isn't a fit")
	expect_eq(go.game.help, help, "help unchanged")


func test_an_unjudgeable_check_in_ends_the_go_after_its_time_out() -> void:
	var go := _go()
	go.start()
	for i in FitGo.TURN_ROUNDS:
		go.next({mode = "turn", result = "fit"})
	var ended := false
	var t := 0.0
	while not ended and t < FitGo.PICK_TIMEOUT + 1.0:
		ended = go.tick(DT)
		t += DT
	expect(ended and go.over, "ended after %.0f s" % t)
	expect(not go.game.playing, "nothing left playing")


func test_the_first_blind_round_is_noticed_once() -> void:
	var go := _go()
	go.start()
	go.game.set_help(FitGame.Help.BLIND)
	go.game.start(FitGame.Mode.TURN)
	expect(go.first_blind_now(), "the first blind round")
	go.game.start(FitGame.Mode.TURN)
	expect(not go.first_blind_now(), "not again")
