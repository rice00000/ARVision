extends TestCase
## Turn to fit as a game (FitGame): the help ladder, blind commits and the "Which is mine?"
## check-in, on Megan's mug photos (targets = SAM outlines, live = colour tracking).
##   godot --headless --xr-mode off --fixed-fps 60 --path . res://tests/run.tscn -- --profile=test --only=fit_game

const DATA := "res://tests/data/turn_to_fit/"
const VIEWS := ["left", "right", "toward"]
const DT := 0.2

var _live := {} # view → the live (tracked) shape of that photo


func _photo(view: String) -> Image:
	return Image.load_from_file(DATA + "santa_%s.jpg" % view)


func _sam(view: String) -> Image:
	return Image.load_from_file(DATA + "santa_%s_sam.png" % view)


func _box(view: String) -> Rect2i:
	var b: Array = JSON.parse_string(FileAccess.get_file_as_string(DATA + "santa.json")).boxes[view]
	return Rect2i(int(b[0]), int(b[1]), int(b[2] - b[0]), int(b[3] - b[1]))


## A game on the three captured targets, with the live shapes of the photos ready.
func _game(rng_seed := 7) -> FitGame:
	var matcher := FitMatcher.new()
	for view: String in VIEWS:
		matcher.add_target(view, ShapeCV.target_from_mask(_sam(view), _box(view)).shape)
	if _live.is_empty():
		var model := ShapeCV.learn_colours(_photo("left"), _sam("left"), _box("left"))
		for view: String in VIEWS:
			_live[view] = ShapeCV.track(_photo(view), _box(view), model).shape
	return FitGame.new(matcher, rng_seed)


## Shows the camera [param view] ("" = no cup) for [param steps] steps of DT.
func _show(game: FitGame, view: String, steps: int) -> void:
	for i in steps:
		game.matcher.update(_live[view] if view != "" else PackedByteArray(), DT)
		game.update(DT)


func _card(game: FitGame) -> String:
	return game.matcher.names[game.card]


func _other(game: FitGame) -> String:
	return game.matcher.names[(game.card + 1) % VIEWS.size()]


func test_needs_two_targets() -> void:
	var matcher := FitMatcher.new()
	matcher.add_target("left", PackedByteArray([1]))
	expect(not FitGame.new(matcher).start(FitGame.Mode.TURN), "one target is no choice")


func test_mirror_round_ends_when_the_card_fits() -> void:
	var game := _game()
	var ended := record(game.finished)
	game.start(FitGame.Mode.TURN)
	expect(game.shows_live(), "mirror: the live shadow is drawn")
	_show(game, _other(game), 10)
	expect(game.playing, "fitting a different target doesn't end the round")
	_show(game, _card(game), 5)
	expect(not game.playing, "the card's own view ends it")
	expect_eq(ended.size(), 1, "one round finished")
	expect_eq(game.rounds[0].result, "fit", "result")
	expect_eq(game.rounds[0].help, "mirror", "help used")


func test_glimmer_shows_the_shadow_only_when_the_cup_is_nearest_this_card() -> void:
	var game := _game()
	game.set_help(FitGame.Help.GLIMMER)
	game.start(FitGame.Mode.TURN)
	_show(game, "", 2)
	expect(not game.shows_live(), "no cup: no shadow")
	for view: String in VIEWS:
		if view == _card(game):
			continue
		game.matcher.reset()
		_show(game, view, 3)
		expect(not game.shows_live(), "a wrong view (%s for %s, %.2f) never shows it" % [view, _card(game), game.matcher.scores[game.card]])
	game.matcher.reset()
	_show(game, _card(game), 2)
	expect(game.shows_live() or not game.playing, "the card's own view shows it (or already fits)")


func test_blind_never_ends_by_itself_and_the_commit_is_judged() -> void:
	var game := _game()
	game.set_help(FitGame.Help.BLIND)
	game.start(FitGame.Mode.TURN)
	_show(game, _card(game), 10)
	expect(game.playing, "blind: holding the fit doesn't end it (no glow to give it away)")
	expect(not game.shows_live(), "blind: no live shadow")
	expect_eq(game.commit().get("result"), "fit", "commit on the right view")
	game.start(FitGame.Mode.TURN)
	_show(game, _other(game), 5)
	expect_eq(game.commit().get("result"), "miss", "commit on the wrong view")
	game.start(FitGame.Mode.TURN)
	_show(game, "", 5)
	expect_eq(game.commit().get("result"), "miss", "commit with no cup in view")


func test_commit_only_counts_in_blind_rounds() -> void:
	var game := _game()
	game.start(FitGame.Mode.TURN)
	expect(game.commit().is_empty(), "mirror: Space does nothing")
	expect(game.playing, "still playing")


func test_help_fades_after_two_wins_and_comes_back_after_two_misses() -> void:
	var game := _game()
	var path: Array[String] = []
	for i in 4: # four wins: mirror → glimmer → blind
		game.start(FitGame.Mode.TURN)
		_show(game, _card(game), 6)
		if game.playing:
			game.commit()
		path.append(game.rounds[-1].next_help)
	expect_eq(path, ["mirror", "glimmer", "glimmer", "blind"] as Array[String], "two wins → one step less")
	for i in 2: # two blind misses → back to glimmer
		game.start(FitGame.Mode.TURN)
		_show(game, _other(game), 5)
		game.commit()
	expect_eq(game.help, FitGame.Help.GLIMMER, "two misses → one step more")


func test_a_round_times_out_as_a_miss() -> void:
	var game := _game()
	game.start(FitGame.Mode.TURN)
	_show(game, "", int(FitGame.TIMEOUT / DT) + 1)
	expect(not game.playing, "ended")
	expect_eq(game.rounds[0].result, "timeout", "result")


func test_the_same_card_never_comes_twice_in_a_row() -> void:
	var game := _game(3)
	var previous := -1
	for i in 20:
		game.start(FitGame.Mode.TURN)
		expect(game.card != previous, "round %d: a new card" % i)
		previous = game.card
		game.playing = false


func test_which_is_mine_uses_the_cv_view_as_the_answer() -> void:
	var game := _game()
	for view: String in VIEWS:
		game.start(FitGame.Mode.PICK)
		expect_eq(game.cards.size(), 3, "three cards")
		_show(game, view, 5)
		var answer := game.matcher.names.find(view)
		var right := game.cards.find(answer)
		var wrong := (right + 1) % 3
		var miss := game.pick(wrong)
		expect_eq(miss.get("result"), "miss", "%s: the wrong card" % view)
		game.start(FitGame.Mode.PICK)
		_show(game, view, 5)
		right = game.cards.find(answer)
		var hit := game.pick(right)
		expect_eq(hit.get("result"), "match", "%s: the right card" % view)
		expect_eq(hit.get("help"), "none", "a check-in: no help")
		expect(hit.get("seconds", 0.0) > 0.0, "%s: the time to answer is logged" % view)
	expect_eq(game.help, FitGame.Help.MIRROR, "check-ins never change the help")


func test_which_is_mine_waits_when_the_cv_is_unsure() -> void:
	var game := _game()
	game.start(FitGame.Mode.PICK)
	_show(game, "", 3)
	expect(game.pick(0).get("unclear", false), "no cup: unclear, nothing scored")
	expect(game.playing, "the round goes on")
	expect(game.rounds.is_empty(), "no record yet")
