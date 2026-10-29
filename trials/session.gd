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
## With a plan (main.tscn's, or from the command line) it runs that plan and
## offers to play it again. Without one, the World chooses tasks and plays each
## with [method play].
##
##   godot --path . -- --plan=res://content/sessions/demo.tres

@export var plan: SessionPlan
## Start once the app is up, when there is a plan. Tests switch it off and call [method run].
@export var autostart := true
## How the real world looks in blocks without their own [member Block.view].
var base_view := View.new()

var block_index := -1
## The block in progress, or null.
var block: Block
## Its trial scene, or null between blocks.
var trial: Trial
## Level pinned for the rest of this play, by the level the child chose or by
## the facilitator; NAN = not pinned (the staircase moves).
var pinned := NAN
var running := false

var _skip := false


func _ready() -> void:
	App.session = self
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--plan="):
			plan = load(arg.trim_prefix("--plan="))
	if autostart and plan:
		run.call_deferred()


## Plays [member plan], then offers to play it again.
func run() -> void:
	await play(plan)
	_offer_replay()


## Plays [param session_plan] once, every round at [param at_level] when given
## (a level the child chose), else as [method level] says.
func play(session_plan: SessionPlan, at_level := NAN) -> void:
	plan = session_plan
	pinned = at_level
	running = true
	await _announce(plan.greeting)
	if not App.reality.is_settled:
		await App.reality.settled # toys placed before the table is known land on the lap
	for index in plan.blocks.size():
		block_index = index
		block = plan.blocks[index]
		await _run_block()
	block = null
	running = false
	await _announce(plan.farewell)
	Events.session_finished.emit()


## A "Play again" ball in reach in front of the child; pressed, the plan runs again.
func _offer_replay() -> void:
	var button := ReplayButton.new()
	App.stage.add_child(button)
	var eye := App.head().global_transform
	var forward := Vector3(-eye.basis.z.x, 0.0, -eye.basis.z.z).normalized()
	button.global_position = eye.origin + forward * 0.4 + Vector3.DOWN * 0.15
	Events.say("To play again, touch the yellow ball.")
	await button.pressed
	button.queue_free()
	Events.report(&"replay")
	run()


## The level the next round runs at.
func level() -> float:
	if not is_nan(pinned):
		return pinned
	if block.difficulty >= 0.0:
		return block.difficulty
	return Profile.level(block.trial.skill)


## Pins the level [param delta] away from now, for the rest of the session.
func nudge(delta: float) -> void:
	pinned = clampf(level() + delta, 0.0, 1.0)
	Events.report(&"level_pinned", {level = pinned})


## Back to the staircase.
func unpin() -> void:
	pinned = NAN
	Events.report(&"level_unpinned")


## Ends the current block now; its running round is dropped unscored.
func skip_block() -> void:
	_skip = true
	if trial:
		trial.abandon()


func _run_block() -> void:
	var def := block.trial
	var missing := def.requires.filter(func(module_name: StringName) -> bool: return App.module(module_name) == null)
	if not missing.is_empty():
		Events.report(&"block_skipped", {trial = def.id, missing = missing})
		return
	App.reality.apply_view(block.view if block.view else base_view)
	Events.block_started.emit(block_index, {trial = def.id, rounds = block.rounds, probe = block.probe})
	trial = def.scene.instantiate()
	trial.def = def
	trial.grab = not block.ray
	App.stage.add_child(trial)
	await _announce(block.intro)
	for round_index in block.rounds:
		if _skip:
			break
		var condition := def.condition(level(), round_index, block.probe, block.pins)
		condition.view = App.reality.view.to_log()
		trial.begin(condition)
		var result: Array = await trial.ended
		if result[1] and not block.probe and block.difficulty < 0.0 and is_nan(pinned):
			var first_try: bool = result[0] and trial.tries == 0 and trial.hint_level == 0
			var before := Profile.level(def.skill)
			Events.report(&"level", {skill = def.skill, first_try = first_try, before = before,
				after = Profile.adapt(def.skill, first_try, def.up_after, def.step)})
		if not _skip:
			await get_tree().create_timer(block.pause_between, false).timeout
	trial.queue_free()
	trial = null
	_skip = false


## Says [param text] and waits about as long as it takes to hear it.
func _announce(text: String) -> void:
	if text.is_empty():
		return
	Events.say(text)
	await get_tree().create_timer(clampf(text.length() * 0.06, 1.5, 6.0), false).timeout
