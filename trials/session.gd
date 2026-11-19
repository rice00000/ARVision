class_name Session
extends Node
## Runs a [SessionPlan] block by block, round by round.
##
## For each round it picks the level (the facilitator's pin, the block's fixed
## difficulty, or the child's staircase), and after each scored, non-probe round
## it moves the staircase. A round counts as right for the staircase only when
## it was solved on the first try without help: trials allow retries, so a
## solved round alone says little. Each block shows the real world through its
## [View]. The facilitator steers it through the public methods.
##
## With a plan (Main's, or from the command line) it runs that plan and
## offers to play it again. Without one, the World chooses tasks and plays each
## with [method play].
##
##   godot --path . -- --plan=res://content/sessions/demo.tres

## Said before the last round of a level with more than two rounds and a pause between them.
const LAST_ROUND := "Last one!"

@export var plan: SessionPlan
## How the real world looks in blocks without their own [member Block.view]:
## the child's own filter (Vision).
var base_view: View:
	get:
		return Vision.view

var block_index := -1
## The block in progress, or null.
var block: Block
## Its trial scene, or null between blocks.
var trial: Trial
## Level pinned for the rest of this play by the facilitator; NAN = not pinned.
var pinned := NAN
var running := false
## False after any skipped, failed, abandoned or probe round.
var won := false

var _skip := false
## The whole plan ends after this block (the child chose Stop).
var _stop := false
var _dots: RoundDots


func _ready() -> void:
	App.session = self


## Plays [member plan], then offers to play it again.
func run() -> void:
	await play(plan)
	if won:
		Events.level_won.emit(StringName(plan.resource_path.get_file().get_basename()), 1, 2)
	_offer_replay()


## Plays [param session_plan] once. A story can provide its own announcements.
func play(session_plan: SessionPlan, announce_plan := true) -> void:
	plan = session_plan
	pinned = NAN
	running = true
	won = not plan.blocks.is_empty() and not plan.is_endless()
	_stop = false
	if announce_plan:
		await Events.say(plan.greeting, self)
	if not App.reality.is_settled:
		await App.reality.settled # toys placed before the table is known land on the lap
	for index in plan.blocks.size():
		if _stop:
			break
		block_index = index
		block = plan.blocks[index]
		await _run_block(announce_plan)
	block = null
	running = false
	if announce_plan:
		await Events.say(plan.farewell, self)
	Events.session_finished.emit()


## A "Play again" ball in reach in front of the child; pressed, the plan runs again.
func _offer_replay() -> void:
	var button := ReplayButton.new()
	App.stage.add_child(button)
	var eye := App.head().global_transform
	var forward := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	button.global_position = eye.origin + forward * 0.4 + Vector3.DOWN * 0.15
	Events.play(&"appear", button.global_position)
	Events.say("To play again, point at the yellow ball and pinch.")
	await button.pressed
	button.queue_free()
	Events.report(&"replay")
	run()


## The level the next round runs at: the facilitator's pin, else an adaptive
## level's own staircase (Block.drive; fixed at its start for a child on
## fixed levels), else the block's fixed difficulty, else the skill's staircase.
## Fixed levels take the child's Vision offset.
func level() -> float:
	if not is_nan(pinned):
		return pinned
	if adaptive_block() and Vision.adaptive:
		return Profile.level(staircase(), start_level())
	if block.difficulty >= 0.0:
		return clampf(block.difficulty + Vision.offset(staircase()), 0.0, 1.0)
	return Profile.level(staircase(), start_level())


## The staircase this block moves: [member Block.staircase], else its trial's skill.
func staircase() -> StringName:
	return block.staircase if not block.staircase.is_empty() else block.trial.skill


## A level that adapts on its own range ([member Block.drive]).
func adaptive_block() -> bool:
	return not block.drive.is_empty()


## Where this block's staircase starts if it never moved: the block's
## difficulty, else [constant Profile.START_LEVEL].
func start_level() -> float:
	return block.difficulty if block.difficulty >= 0.0 else Profile.START_LEVEL


## Whether this block plays on the child's staircase: blocks without a fixed
## difficulty, and adaptive levels unless the child plays fixed levels.
func on_staircase() -> bool:
	return block.difficulty < 0.0 or (adaptive_block() and Vision.adaptive)


## Whether scored rounds move the staircase: on it, not a check-in, not pinned.
func adapts() -> bool:
	return not block.probe and is_nan(pinned) and on_staircase()


## How a scored round moves the staircase: &"right" solved first time without
## help; &"neutral" solved first time with only the help that came by itself
## after a wait (a slow child is not pushed down for being slow); else &"wrong".
func outcome(success: bool, tries: int, hints: int, asked: bool) -> StringName:
	if not success or tries > 0 or asked:
		return &"wrong"
	return &"right" if hints == 0 else &"neutral"


## Pins the level [param delta] away from now, for the rest of the session.
func nudge(delta: float) -> void:
	pin(level() + delta)


## Uses a fixed level from the next round until this play ends.
func pin(at_level: float, details: Dictionary = {}) -> void:
	pinned = clampf(at_level, 0.0, 1.0)
	Events.report(&"level_pinned", details.merged({level = pinned}, true))


## Back to the staircase.
func unpin() -> void:
	pinned = NAN
	Events.report(&"level_unpinned")


## The child chose Stop: the running round is dropped and the rest of this play
## (every block left) ends; nothing is finished or rewarded.
func stop() -> void:
	_stop = true
	Events.report(&"stopped", {block = block_index})
	skip_block()


## Ends the current block now; its running round is dropped unscored.
func skip_block() -> void:
	won = false
	_skip = true
	if trial:
		trial.abandon()


func _run_block(announce_plan: bool) -> void:
	var def := block.trial
	var missing := def.requires.filter(func(module_name: StringName) -> bool: return App.module(module_name) == null)
	if not missing.is_empty():
		won = false
		Events.report(&"block_skipped", {trial = def.id, missing = missing})
		return
	App.reality.apply_view(block.view if block.view else base_view)
	Events.block_started.emit(block_index, {trial = def.id, rounds = block.rounds, probe = block.probe,
		vision = Vision.to_log()})
	trial = def.scene.instantiate()
	trial.def = def
	trial.grab = not block.ray
	trial.tutorial_intro = block.intro
	App.stage.add_child(trial)
	if block.rounds > 1:
		_dots = RoundDots.new(block.rounds)
		App.stage.add_child(_dots)
		_dots.place(trial.in_front(0.85, -0.36))
	if announce_plan and block.probe:
		await Events.say(block.intro, self)
	var round_index := 0
	var solved := 0
	var scored := 0
	while not _skip and (block.rounds < 0 or round_index < block.rounds):
		var condition := def.condition(level(), round_index, block.probe, block.pins, block.drive)
		condition.view = App.reality.view.to_log()
		trial.begin(condition)
		if _dots:
			_dots.show_round(round_index)
		var result: Array = await trial.ended
		scored += int(result[1])
		solved += int(result[0] and result[1])
		if not adaptive_block(): # an adaptive level is finished when half its rounds are solved (below)
			won = won and result[0] and result[1] and not block.probe
		if result[1] and adapts():
			var first_try: bool = result[0] and trial.tries == 0 and trial.hint_level == 0
			var how := outcome(result[0], trial.tries, trial.hint_level, trial.help_asked)
			var key := staircase()
			var before := Profile.level(key, start_level())
			var after := before if how == &"neutral" else Profile.adapt(key, how == &"right", def.up_after, def.step, start_level(), adaptive_block())
			Events.report(&"level", {skill = key, first_try = first_try, outcome = how, before = before, step = def.step,
				fast = adaptive_block(), after = after})
		if _dots:
			_dots.finish_round(round_index, result[0] and result[1])
		round_index += 1
		var delay := block.pause_between
		if round_index == block.rounds and block.pause_after >= 0.0:
			delay = block.pause_after
		# Levels that flow round to round with no pause (the swarm) keep flowing: the dots show it.
		if not _skip and block.rounds > 2 and round_index == block.rounds - 1 and block.pause_between > 0.0:
			await _say_last_round()
		if not _skip and delay > 0.0:
			await get_tree().create_timer(delay, false).timeout
	if adaptive_block() and (block.probe or _skip or scored == 0 or solved * 2 < scored):
		won = false
	if _dots:
		_dots.queue_free()
		_dots = null
	trial.queue_free()
	trial = null
	_skip = false


## "Last one!" between the last two rounds, once what the guide is saying ends
## (never cutting off the round's own praise).
func _say_last_round() -> void:
	var voice := App.module(&"Voice")
	var waited := 0.0
	while voice != null and not voice.speaking().is_empty() and waited < 4.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	await Events.say(LAST_ROUND, self)
