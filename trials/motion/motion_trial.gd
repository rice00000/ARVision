extends Trial
## Read the flow: a seated 3D random-dot motion task. A cloud of dots floats
## ahead; some of them (coherence) move one way, the rest are noise. The child
## sweeps a hand the way the flow goes and holds still.
## Original design and shader by Megan (Mgharv), ported from XRVision.
##
## Axes: coherence (driven), competing (1 = the noise is one opposite flow, 0 =
## random directions), direction (0 random, 1-4 right, left, toward, away, 5
## random lateral),
## dots, speed, dot_lifetime, half_width / half_height / half_depth (cloud, m),
## distance (m), tolerance (degrees).
## The cloud is fully lit inside its half size; a [constant MotionCloud.MARGIN] shell around
## it, where dots fade in and out, gets extra dots at the same density, so
## [code]dots[/code] stay in the lit part and the signal share is the same.
## The dots' own shimmer plays from the cloud, looping, while they are shown.
## Sweeps come from the rig, no pinch ([signal Events.sweeping]). The moment a
## hand has gone the right way, the round is won. A sweep the wrong way counts a
## try once that hand stops ([signal Events.swept]); one that turns straight into
## the right way was a wind-up and counts nothing. Sweeps that set off in the
## first [constant ARM_SECONDS] of a round are hands settling from the last
## round, before the dots could be read: ignored. The flow stays the same until
## the child finds it. While a judged sweep goes on, a white streak and a whoosh
## show the hand was seen ([SweepTrail]), right or wrong alike.
## Hint 1 (only when asked): every dot follows the flow.
## With [member break_wall] (the tech demo), a right sweep also breaks the wall ahead.
##
## Log (for the Staff tools results, Nov 17; log only, stimuli and judging unchanged): every
## motion_attempt, motion_windup, motion_round_interrupted and the round's trial_end carry
## [method log_stamp]: the log version, the play mode, whether the level was pinned, and a
## per-run round number, so a round's lines join up and dev or pinned runs never mix with play.
## A round that ends without being won (skipped, timed out, or the scene left) logs
## motion_round_interrupted {trial, round, coherence_shown, help, seconds_shown, reason, ...}.

const HEADINGS: Array[StringName] = [&"right", &"left", &"toward", &"away"]
## Flow of each heading in the cloud's frame: its -Z points away from the child.
const FLOWS: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
const ARM_SECONDS := 0.8
## Version of the motion log lines. 1 = before Nov 17 (no log_version field). 2 adds
## motion_round_interrupted and [method log_stamp]. 3 (hub, Nov 17) adds view_dim, the room's dimming
## during the round, so dimmed and undimmed rounds never pool. Raise it whenever a motion line changes meaning.
const LOG_VERSION := 3

## Rounds started in this run; each round logs its own number ([code]round_serial[/code]).
static var _rounds_started := 0

## Tech demo: a right sweep breaks the real wall ahead ([WallBreak]).
@export var break_wall := false
## While Onion leads the motion route it speaks for the task: Wei's round line, his "Yes!..." and his
## hint line stay quiet (wrong-direction feedback stays until the story chat replaces it).
static var onion_voice := false
@export var wall_style: WallBreak.Style = WallBreak.Style.CRACK

var _rng := RandomNumberGenerator.new()
## The cloud's frame, frozen at the start of the round; sweeps are judged in it.
var _frame := Transform3D.IDENTITY
var _flow := Vector3.RIGHT
var _dots := 0
## Dots following the flow now (all of them once help is on).
var _signal_dots := 0
var _tolerance := 0.0
var _attempts: Array[Dictionary] = []
## Per hand, its latest wrong-way sweep, waiting for the hand to stop.
var _wrong: Dictionary[StringName, Dictionary] = {}
## This round's number in the run, and the share of dots following the flow as it began (before any help).
var _serial := 0
var _coherence_start := 0.0

@onready var _cloud: MotionCloud = $Cloud
@onready var _shimmer: AudioStreamPlayer3D = $Cloud/Shimmer
@onready var _trails: Dictionary[StringName, SweepTrail] = {&"left": $LeftTrail, &"right": $RightTrail}


## Judges one sweep: [param displacement] in the cloud's frame. Only its level
## part counts: the flow never rises or falls.
static func classify(displacement: Vector3, expected: Vector3, tolerance: float) -> Dictionary:
	var angle := rad_to_deg(Vector3(displacement.x, 0.0, displacement.z).angle_to(expected))
	return {correct = angle <= tolerance, angle_degrees = angle, direction = displacement.normalized(),
		distance_metres = displacement.length()}


func _setup(round_condition: TrialCondition) -> void:
	_attempts.clear()
	_wrong.clear()
	_rng.randomize()
	var pinned := int(round_condition.value(&"direction"))
	var heading := pinned - 1
	if pinned == 0 or pinned == 5:
		heading = _rng.randi_range(0, 1 if pinned == 5 else HEADINGS.size() - 1)
	_flow = FLOWS[heading]
	_dots = int(round_condition.value(&"dots"))
	var coherence: float = round_condition.value(&"coherence")
	var signal_dots := roundi(coherence * _dots)
	_tolerance = round_condition.value(&"tolerance")
	_frame = in_front(MotionCloud.distance(round_condition))
	_cloud.global_transform = _frame
	var trial_seed := _rng.randi_range(1, 1000000)
	_signal_dots = signal_dots
	_rounds_started += 1
	_serial = _rounds_started
	_coherence_start = float(signal_dots) / _dots
	_cloud.show_flow(round_condition, _flow, _signal_dots, trial_seed)
	_shimmer.play()
	round_condition.set_value(&"heading", HEADINGS[heading])
	round_condition.set_value(&"plane", &"lateral" if heading < 2 else &"depth")
	round_condition.set_value(&"flow", _flow)
	round_condition.set_value(&"signal_dots", signal_dots)
	round_condition.set_value(&"seed", trial_seed)
	if not onion_voice:
		say("Which way do the dots go? Sweep your hand that way, then hold still.")


func focus_point() -> Vector3:
	return _cloud.global_position


func _on_sweeping(hand: StringName, from: Vector3, to: Vector3, duration: float) -> void:
	var onset := seconds() - duration
	if onset < ARM_SECONDS:
		return
	_trails[hand].show_sweep(from, to)
	var result := classify(_frame.basis.inverse() * (to - from), _flow, _tolerance)
	result.merge({trial = condition.trial, round = condition.round_index, hand = hand, from = from,
		onset_seconds = onset, duration_seconds = duration,
		help = hint_level, coherence_shown = float(_signal_dots) / _dots}, true)
	result.merge(log_stamp(), true)
	if not result.correct:
		_wrong[hand] = result
		return
	# A wrong sweep that set off elsewhere was a wind-up; this sweep's own start bending in is not.
	var windups := _wrong.values().filter(func(wrong: Dictionary) -> bool: return wrong.from != from)
	for windup: Dictionary in windups:
		Events.report(&"motion_windup", windup) # stamped with the attempt fields above
	_wrong.clear()
	_attempts.append(result)
	Events.report(&"motion_attempt", result)
	judge(&"good", _cloud.global_position)
	if not onion_voice:
		say("Yes! Now they all go together.")
	if break_wall:
		var eye := App.head().global_position
		WallBreak.burst(eye, (_cloud.global_position - eye).normalized(), _frame.basis * _flow, wall_style)
	_cloud.align()
	finish(true, {attempts = _attempts.duplicate(), windups = windups.size(),
		first_attempt_correct = _attempts[0].correct, first_onset_seconds = _attempts[0].onset_seconds,
		response_onset_seconds = result.onset_seconds, gesture_seconds = result.duration_seconds,
		angle_degrees = result.angle_degrees})


## What every motion log line of this round carries (log version 2).
func log_stamp() -> Dictionary:
	var session := App.session
	var mine := session != null and session.trial == self
	var source := "outside_session"
	if mine:
		if not is_nan(session.pinned):
			source = "pinned"
		elif session.block != null and session.block.difficulty >= 0.0:
			source = "fixed"
		else:
			source = "staircase"
	return {log_version = LOG_VERSION, session_mode = PlayMode.name(), level_pinned = source == "pinned",
		level_source = source, round_serial = _serial, coherence_start = _coherence_start,
		heading = condition.value(&"heading") if condition else &"",
		view_dim = snappedf(App.reality.view.dim, 0.01) if App.reality != null else 0.0}


## Ends the round (see [Trial]). Stamps its line and logs a round that ends unwon.
func finish(success: bool, extra: Dictionary = {}) -> void:
	if not is_running():
		return
	if not success:
		_log_interrupted(&"timed_out" if extra.get("timed_out", false) else &"ended_unwon")
	super(success, extra.merged(log_stamp(), true))


## The facilitator skipped the round (see [Trial]).
func abandon() -> void:
	if is_running():
		_log_interrupted(&"skipped")
	super()


## A round that ended without being won. Its first attempt, if there was one, still counts.
func _log_interrupted(reason: StringName) -> void:
	var first := {}
	if not _attempts.is_empty():
		var attempt: Dictionary = _attempts[0]
		first = {correct = attempt.correct, help = attempt.help, coherence_shown = attempt.coherence_shown,
			onset_seconds = attempt.onset_seconds}
	var data := {trial = condition.trial, round = condition.round_index,
		coherence_shown = float(_signal_dots) / maxi(_dots, 1), help = hint_level,
		seconds_shown = snappedf(seconds(), 0.001), reason = reason, attempts = _attempts.size(),
		first_attempt = first}
	Events.report(&"motion_round_interrupted", data.merged(log_stamp(), true))


## The hand stopped after going the wrong way: that was its answer.
func _on_swept(hand: StringName) -> void:
	if not _wrong.has(hand):
		return
	var result: Dictionary = _wrong[hand]
	_wrong.erase(hand)
	_attempts.append(result)
	Events.report(&"motion_attempt", result)
	judge(&"bad", _cloud.global_position)
	count_try()
	if onion_voice:   # in the workshop Onion says its own calm line (Scene 9, Megan Nov 17): MotionVisit hears this
		Events.report(&"motion_wrong", {trial = condition.trial, round = condition.round_index})
	else:
		say("Not that way. Watch the dots and try again.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_wrong.clear()
	elif what == NOTIFICATION_EXIT_TREE and is_running():
		_log_interrupted(&"left") # the scene changed or the app closed mid-round


## Help: every dot follows the flow.
func _hint(_level: int) -> void:
	_signal_dots = _dots
	_cloud.set_signal_dots(_signal_dots)
	judge(&"hint", _cloud.global_position)
	if not onion_voice:
		say("Now every dot goes the same way. Watch, then sweep.")
