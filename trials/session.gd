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
##   godot --path . -- --plan=res://content/sessions/demo.tres

@export var plan: SessionPlan
## Start once the app is up. Tests switch it off and call [method run].
@export var autostart := true

var block_index := -1
## The block in progress, or null.
var block: Block
## Its trial scene, or null between blocks.
var trial: Trial
## Level pinned by the facilitator for the rest of the session; NAN = not pinned.
var pinned := NAN
var running := false

var _skip := false


func _ready() -> void:
	App.session = self
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--plan="):
			plan = load(arg.trim_prefix("--plan="))
	if autostart:
		run.call_deferred()


func run() -> void:
	running = true
	await _announce(plan.greeting)
	for index in plan.blocks.size():
		block_index = index
		block = plan.blocks[index]
		await _run_block()
	block = null
	running = false
	await _announce(plan.farewell)
	Events.session_finished.emit()


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
	App.reality.apply_view(block.view if block.view else View.new())
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
