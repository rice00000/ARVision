class_name FitGame
extends RefCounted
## Turn to fit as a game (Nov 15): rounds, the help ladder and the "Which is mine?" check-in.
## Pure logic on top of a FitMatcher. The lab (and later the Godot scene) draws it.
##
## Turn round: one shadow card is shown; the child turns the cup (or moves) until it fits.
##   Help, from most to least. It fades: STREAK wins in a row → one step less help,
##   STREAK misses in a row → one step more.
##     MIRROR   the live shadow is always drawn, and a fit is found by itself
##     GLIMMER  the live shadow shows only when close (card score ≥ GLIMMER_SHOW)
##     BLIND    no live shadow and no glow. The child looks at the real cup and presses
##              when they think it makes the card's shadow (commit); then the CV judges.
##              This is the vision step: predicting a view, not lining up two flat shapes.
## Pick round ("Which is mine?", a check-in with no help): the child holds the cup in a view
##   and picks which card it makes now. The CV's current view is the answer key; when the CV
##   isn't sure, nothing is scored.
## Design and reasons: claude/CV_TURN_TO_FIT_GAME.md (Project doc).

enum Mode { TURN, PICK }
enum Help { MIRROR, GLIMMER, BLIND }

const HELP_NAMES := ["mirror", "glimmer", "blind"]
## GLIMMER: the live shadow appears once the card's score reaches this.
const GLIMMER_SHOW := 0.6
## A commit or a pick is judged on the view the CV is sure of: best score ≥ JUDGE and ahead
## of the next best by FitMatcher.MARGIN. A little below FitMatcher.ENTER: there's no hold.
const JUDGE := 0.8
## A turn round with no fit by then ends as "timeout" (a miss). Target: < 30 s (CV_PLAN T4).
const TIMEOUT := 30.0
## Rounds in a row that move the help one step.
const STREAK := 2

## Emitted when a round ends, with its record (see [method _finish]).
signal finished(record: Dictionary)

var matcher: FitMatcher
var mode := Mode.TURN
## The current help (a Help value). Changes by itself after turn rounds.
var help: int = Help.MIRROR
## TURN: the target index to fit. PICK: -1 until judged, then the answer.
var card := -1
## PICK: target indices in the order the cards are shown.
var cards: Array[int] = []
var playing := false
## Seconds since the round started.
var time := 0.0
## Every finished round, oldest first.
var rounds: Array[Dictionary] = []

var _wins := 0
var _misses := 0
var _rng := RandomNumberGenerator.new()


func _init(fit_matcher: FitMatcher, rng_seed := -1) -> void:
	matcher = fit_matcher
	if rng_seed >= 0:
		_rng.seed = rng_seed


## Starts a round. Needs at least 2 captured targets (one target is no choice).
func start(round_mode: Mode) -> bool:
	var count := matcher.targets.size()
	if count < 2:
		return false
	mode = round_mode
	time = 0.0
	playing = true
	matcher.reset()
	if mode == Mode.TURN:
		var choices: Array[int] = []
		for i in count:
			if i != card: # never the same card twice in a row
				choices.append(i)
		card = choices[_rng.randi_range(0, choices.size() - 1)]
	else:
		card = -1
		cards.clear()
		for i in count:
			cards.append(i)
		for i in range(count - 1, 0, -1): # shuffle with our own seed (repeatable in tests)
			var j := _rng.randi_range(0, i)
			var keep := cards[i]
			cards[i] = cards[j]
			cards[j] = keep
	return true


## Call after every matcher.update(), with the same dt.
func update(dt: float) -> void:
	if not playing:
		return
	time += dt
	if mode != Mode.TURN:
		return
	if help != Help.BLIND and matcher.fit == card:
		_finish(true)
	elif time >= TIMEOUT:
		_finish(false, "timeout")


## Should the live shadow be drawn now? (Only turn rounds, and only as the help allows.)
func shows_live() -> bool:
	if not playing or mode != Mode.TURN:
		return false
	match help:
		Help.MIRROR:
			return true
		Help.GLIMMER:
			return matcher.scores[card] >= GLIMMER_SHOW
	return false


## The child says "it fits now" (BLIND turn rounds only). Returns the round's record, or {}
## when this isn't a blind turn round.
func commit() -> Dictionary:
	if not playing or mode != Mode.TURN or help != Help.BLIND:
		return {}
	return _finish(view() == card)


## The child picks the card in [param slot] (pick rounds). Returns the round's record,
## {unclear = true} when the CV can't tell the cup's view (nothing scored: hold still and
## pick again), or {} when this isn't a pick round.
func pick(slot: int) -> Dictionary:
	if not playing or mode != Mode.PICK or slot < 0 or slot >= cards.size():
		return {}
	var now := view()
	if now < 0:
		return {unclear = true}
	card = now
	return _finish(cards[slot] == now, "", cards[slot])


## The target the cup shows now, if the CV is sure (see JUDGE), else -1.
func view() -> int:
	var top := -1
	for i in matcher.scores.size():
		if top < 0 or matcher.scores[i] > matcher.scores[top]:
			top = i
	if top < 0 or matcher.scores[top] < JUDGE:
		return -1
	for i in matcher.scores.size():
		if i != top and matcher.scores[top] - matcher.scores[i] < FitMatcher.MARGIN:
			return -1
	return top


## Sets the help by hand (the lab's H key, or an adult). Starts the streaks again.
func set_help(level: int) -> void:
	help = clampi(level, Help.MIRROR, Help.BLIND)
	_wins = 0
	_misses = 0


## Ends the round. The record: mode, help ("none" in pick rounds), card (the answer),
## chosen (pick rounds), result (turn: fit / miss / timeout; pick: match / miss),
## seconds, score (the answer's score), next_help.
func _finish(success: bool, why := "", chosen := -1) -> Dictionary:
	playing = false
	var result := why
	if result == "":
		if mode == Mode.TURN:
			result = "fit" if success else "miss"
		else:
			result = "match" if success else "miss"
	var record := {
		mode = "turn" if mode == Mode.TURN else "pick",
		help = HELP_NAMES[help] if mode == Mode.TURN else "none",
		card = matcher.names[card] if card >= 0 else "",
		chosen = matcher.names[chosen] if chosen >= 0 else "",
		result = result,
		seconds = snappedf(time, 0.1),
		score = snappedf(matcher.scores[card], 0.01) if card >= 0 else 0.0,
	}
	if mode == Mode.TURN: # the check-in never changes the help
		_step_help(success)
	record.next_help = HELP_NAMES[help]
	rounds.append(record)
	finished.emit(record)
	return record


func _step_help(success: bool) -> void:
	if success:
		_wins += 1
		_misses = 0
		if _wins >= STREAK and help < Help.BLIND:
			help += 1
			_wins = 0
	else:
		_misses += 1
		_wins = 0
		if _misses >= STREAK and help > Help.MIRROR:
			help -= 1
			_misses = 0
