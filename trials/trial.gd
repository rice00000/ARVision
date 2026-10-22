class_name Trial
extends Node3D
## One measured round of a training task. Every trial scene's root extends this.
##
## The Session instances the scene once per block and calls [method begin] for
## every round with that round's [TrialCondition]. A subclass builds the round
## in [method _setup], judges the child's input in the [code]_on_*[/code] hooks,
## and calls [method finish] once the round is decided (never from inside
## [method _setup]). The base owns what every round logs the same way: time,
## tries, help used and the whole condition.
##
## Input hooks run only while a round is running and the world is not paused,
## so a trial never sees a press meant for the facilitator panel. A press and
## its release can therefore straddle a pause: drop half-done gestures in
## [code]_notification(NOTIFICATION_PAUSED)[/code].
##
## Help: [member TrialDef.hint_after] seconds without progress raise the hint
## level by one (later each round, so help fades); B / Y asks for the next level
## at once; probe rounds get none. What each level shows is up to [method _hint].

## The round is over. [param scored] is false for an abandoned round, which
## sends no [signal Events.trial_ended].
signal ended(success: bool, scored: bool)

const GROUP := &"trial"

## Set by the Session before the scene enters the tree.
var def: TrialDef
## Settings of the round in progress.
var condition: TrialCondition
## Wrong attempts this round.
var tries := 0
## Highest hint level reached this round. 0 = solved unaided.
var hint_level := 0

var _running := false
## Seconds of play this round; paused time does not count.
var _elapsed := 0.0
## [member _elapsed] at which the next hint is due; 0 = none.
var _hint_at := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	Events.selected.connect(func(hand: StringName, target: Target, origin: Vector3, direction: Vector3) -> void:
		if _live():
			_on_selected(hand, target, origin, direction))
	Events.touched.connect(func(hand: StringName, target: Target) -> void:
		if _live():
			_on_touched(hand, target))
	Events.button.connect(func(hand: StringName, action: StringName, pressed: bool) -> void:
		if _live():
			_on_button(hand, action, pressed))
	Events.hand_tracking.connect(func(hand: StringName, tracked: bool) -> void:
		if _live():
			_on_tracking(hand, tracked))
	Events.help_requested.connect(func() -> void:
		if _live():
			Events.report(&"help_asked", {trial = condition.trial})
			escalate())


## Starts a round. Called by the Session.
func begin(round_condition: TrialCondition) -> void:
	condition = round_condition
	tries = 0
	hint_level = 0
	_elapsed = 0.0
	_running = true
	_setup(condition)
	App.reality.focus_on(focus_point())
	_arm_hint()
	Events.trial_started.emit(condition.trial, condition.to_log())


## Ends the round. [param extra] adds trial-specific fields to its log line.
func finish(success: bool, extra: Dictionary = {}) -> void:
	if not _running:
		return
	_running = false
	var data := condition.to_log()
	data.merge({seconds = snappedf(_elapsed, 0.001), tries = tries, hint = hint_level,
		first_try = success and tries == 0 and hint_level == 0}, true)
	data.merge(extra, true)
	_teardown()
	Events.trial_ended.emit(condition.skill, success, data)
	ended.emit(success, true)


## Drops the round unscored (the facilitator skipped it).
func abandon() -> void:
	if not _running:
		return
	_running = false
	_teardown()
	Events.report(&"round_abandoned", {trial = condition.trial, round = condition.round_index})
	ended.emit(false, false)


## Call on every wrong attempt. Restarts the hint clock: a child who tries is not stuck.
func count_try() -> void:
	tries += 1
	_arm_hint()


## The next hint level, now.
func escalate() -> void:
	if condition.probe or hint_level >= def.max_hint:
		return
	hint_level += 1
	_hint(hint_level)
	Events.report(&"hint", {trial = condition.trial, level = hint_level})
	_arm_hint()


func is_running() -> bool:
	return _running


func seconds() -> float:
	return _elapsed


# -- helpers for subclasses ---------------------------------------------------

func say(text: String) -> void:
	Events.say(text)


## Feedback at [param at]: &"good", &"bad" or &"hint".
func judge(kind: StringName, at: Vector3) -> void:
	Events.feedback.emit(kind, at)


func eye() -> Transform3D:
	return App.head().global_transform


## A level frame [param distance] in front of the eyes and [param below] them,
## its -Z pointing away from the child: where to put things to look at.
func in_front(distance: float, below := 0.0) -> Transform3D:
	var frame := eye()
	var forward := Vector3(-frame.basis.z.x, 0.0, -frame.basis.z.z).normalized()
	return Transform3D(Basis.looking_at(forward), frame.origin + forward * distance + Vector3.DOWN * below)


## Centre of a spotlight View. Override when the action is elsewhere.
func focus_point() -> Vector3:
	return App.reality.work_surface().transform.origin


# -- for subclasses -----------------------------------------------------------

## Build the round: place things, pick a target, say what to do.
func _setup(_round_condition: TrialCondition) -> void:
	pass


## Clean the round up. Called before the result goes out.
func _teardown() -> void:
	pass


## Show help at [param level], 1 = gentlest, up to [member TrialDef.max_hint].
func _hint(_level: int) -> void:
	pass


func _on_selected(_hand: StringName, _target: Target, _origin: Vector3, _direction: Vector3) -> void:
	pass


func _on_touched(_hand: StringName, _target: Target) -> void:
	pass


func _on_button(_hand: StringName, _action: StringName, _pressed: bool) -> void:
	pass


func _on_tracking(_hand: StringName, _tracked: bool) -> void:
	pass


# -- internals ----------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_running = false # the app closed mid-round: nothing left to judge


func _process(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	if _hint_at > 0.0 and _elapsed >= _hint_at:
		_hint_at = 0.0
		escalate()
	if def.time_limit > 0.0 and _elapsed >= def.time_limit:
		finish(false, {timed_out = true})


func _live() -> bool:
	return _running and not get_tree().paused


func _arm_hint() -> void:
	if condition.probe or hint_level >= def.max_hint or def.hint_after <= 0.0:
		_hint_at = 0.0
		return
	_hint_at = _elapsed + def.hint_after + def.hint_fade * condition.round_index
