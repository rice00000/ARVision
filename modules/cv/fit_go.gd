class_name FitGo
extends RefCounted
## One go of Turn to fit in the workshop hub (Megan, Nov 18; `claude/SCENE_REVIEW_DECISIONS.md` →
## "Turn to fit"): TURN_ROUNDS turn rounds on the help ladder, then one "Which is mine?" check-in, then
## the end. Pure logic on top of a FitGame; the scene ([TurnToFitActivity]) draws it and says the lines.
##
## * The help starts at Mirror every go, so a child who fits every round goes Mirror, Mirror, Glimmer,
##   Glimmer, Blind: round 5 is their first blind try.
## * The ending: WELL or more fits of the TURN_ROUNDS → "found its place", fewer → "come back"
##   (the shelf's two lines). Leaving early (the exit token) is the hub's "come back" too.
## * The check-in never changes the help and never counts toward the ending (it's a check, no help).
## * A check-in the camera can't judge for PICK_TIMEOUT seconds ends the go anyway (nothing scored),
##   so a child is never stuck.

const TURN_ROUNDS := 5
## Fits (of the TURN_ROUNDS) for the warm ending.
const WELL := 4
## Seconds a check-in waits for a judgeable pick before the go ends anyway.
const PICK_TIMEOUT := 30.0

var game: FitGame
## Turn rounds finished so far (fit, miss or timeout).
var turns := 0
## Turn rounds that fit.
var fits := 0
## The check-in has been answered (or timed out).
var checked := false
## The go is over.
var over := false
## A blind round has started in this go (the first one gets its line).
var saw_blind := false

var _pick_time := 0.0


func _init(fit_game: FitGame) -> void:
	game = fit_game


## Starts the go: the help back to Mirror, the first turn round. False when there are fewer than 2 cards.
func start() -> bool:
	turns = 0
	fits = 0
	checked = false
	over = false
	saw_blind = false
	_pick_time = 0.0
	game.set_help(FitGame.Help.MIRROR)
	return game.start(FitGame.Mode.TURN)


## After a round's record (FitGame.finished): counts it and says what comes next:
## &"turn" (another turn round has started), &"pick" (the check-in has started) or &"end".
func next(record: Dictionary) -> StringName:
	if over:
		return &"end"
	if record.get("mode", "") == "turn":
		turns += 1
		if record.get("result", "") == "fit":
			fits += 1
		if turns < TURN_ROUNDS:
			game.start(FitGame.Mode.TURN)
			return &"turn"
		_pick_time = 0.0
		game.start(FitGame.Mode.PICK)
		return &"pick"
	checked = true
	over = true
	return &"end"


## Call every step with the step's dt. Returns true when the check-in has waited PICK_TIMEOUT
## without a judgeable pick: the go ends (nothing scored).
func tick(dt: float) -> bool:
	if over or not game.playing or game.mode != FitGame.Mode.PICK:
		return false
	_pick_time += dt
	if _pick_time >= PICK_TIMEOUT:
		game.playing = false
		checked = true
		over = true
		return true
	return false


## This round is the go's first blind one (say its line once). Call right after a round starts.
func first_blind_now() -> bool:
	if saw_blind or not game.playing or game.mode != FitGame.Mode.TURN or game.help != FitGame.Help.BLIND:
		return false
	saw_blind = true
	return true


## The ending: &"found_place" (WELL+ fits) or &"come_back".
func ending() -> StringName:
	return &"found_place" if fits >= WELL else &"come_back"
