extends Trial
## Read the flow: a seated 3D random-dot motion task. A cloud of dots floats
## ahead; some of them (coherence) move one way, the rest are noise. The child
## pinches, sweeps the hand the way the flow goes, and lets go.
## Original design and shader by Megan (Mgharv), ported from XRVision.
##
## Axes: coherence (driven), competing (1 = the noise is one opposite flow, 0 =
## random directions), direction (0 random, 1-4 right, left, toward, away),
## dots, speed, dot_lifetime, half_width / half_height / half_depth (cloud, m),
## distance (m), tolerance (degrees), min_sweep (m), min_seconds, max_seconds.
## A sweep that is too small, too brief or too long is invalid: it is not a
## perceptual error and counts no try. A wrong valid sweep counts a try; the
## flow stays the same until the child finds it.
## Hint 1 (only when asked): every dot follows the flow.

const HEADINGS: Array[StringName] = [&"right", &"left", &"toward", &"away"]
## Flow of each heading in the cloud's frame: its -Z points away from the child.
const FLOWS: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
## The cloud's near face stays at least this far from the eyes, metres.
const NEAR := 0.6
const ALIGN_SECONDS := 0.6
const INVALID_SAY := {
	too_small = "Sweep your hand a little farther.",
	timing = "Pinch, sweep, then let go.",
}

var _rng := RandomNumberGenerator.new()
## The cloud's frame, frozen at the start of the round; sweeps are judged in it.
var _frame := Transform3D.IDENTITY
var _flow := Vector3.RIGHT
var _dots := 0
## Dots following the flow now (all of them once help is on).
var _signal_dots := 0
var _min_sweep := 0.0
var _min_seconds := 0.0
var _max_seconds := 0.0
var _tolerance := 0.0
var _attempts: Array[Dictionary] = []
var _invalid := 0
## The hand pinching for a sweep, or &"".
var _hand: StringName = &""
var _start := Vector3.ZERO
## Round time at which the pinch began.
var _onset := 0.0
var _align: Tween

@onready var _cloud: GPUParticles3D = $Cloud
@onready var _material := _cloud.process_material as ShaderMaterial


## Judges one sweep: [param displacement] in the cloud's frame, held for [param duration] seconds.
static func classify(displacement: Vector3, duration: float, expected: Vector3,
		min_sweep: float, min_seconds: float, max_seconds: float, tolerance: float) -> Dictionary:
	if displacement.length() < min_sweep:
		return {valid = false, reason = &"too_small"}
	if duration < min_seconds or duration > max_seconds:
		return {valid = false, reason = &"timing"}
	var direction := displacement.normalized()
	var angle := rad_to_deg(direction.angle_to(expected.normalized()))
	return {valid = true, correct = angle <= tolerance, angle_degrees = angle, direction = direction,
		distance_metres = displacement.length(), duration_seconds = duration}


func _setup(round_condition: TrialCondition) -> void:
	_cancel_sweep()
	if _align:
		_align.kill()
	_attempts.clear()
	_invalid = 0
	_rng.randomize()
	var pinned := int(round_condition.value(&"direction"))
	var heading := _rng.randi_range(0, HEADINGS.size() - 1) if pinned == 0 else pinned - 1
	_flow = FLOWS[heading]
	_dots = int(round_condition.value(&"dots"))
	var coherence: float = round_condition.value(&"coherence")
	var signal_dots := roundi(coherence * _dots)
	_min_sweep = round_condition.value(&"min_sweep")
	_min_seconds = round_condition.value(&"min_seconds")
	_max_seconds = round_condition.value(&"max_seconds")
	_tolerance = round_condition.value(&"tolerance")
	var half := Vector3(round_condition.value(&"half_width"), round_condition.value(&"half_height"),
		round_condition.value(&"half_depth"))
	_frame = in_front(maxf(round_condition.value(&"distance"), half.z + NEAR))
	_cloud.global_transform = _frame
	_cloud.amount = _dots
	_cloud.visibility_aabb = AABB(-half - Vector3.ONE * 0.3, half * 2.0 + Vector3.ONE * 0.6)
	var trial_seed := _rng.randi_range(1, 1000000)
	_material.set_shader_parameter(&"flow_direction", _flow)
	_material.set_shader_parameter(&"competing_flow", round_condition.value(&"competing") > 0.5)
	_material.set_shader_parameter(&"speed", round_condition.value(&"speed"))
	_material.set_shader_parameter(&"half_size", half)
	_material.set_shader_parameter(&"dot_count", _dots)
	_material.set_shader_parameter(&"dot_lifetime", round_condition.value(&"dot_lifetime"))
	_material.set_shader_parameter(&"trial_seed", trial_seed)
	_material.set_shader_parameter(&"alignment", 0.0)
	_show_signal(signal_dots)
	_cloud.restart()
	round_condition.set_value(&"heading", HEADINGS[heading])
	round_condition.set_value(&"plane", &"lateral" if heading < 2 else &"depth")
	round_condition.set_value(&"flow", _flow)
	round_condition.set_value(&"signal_dots", signal_dots)
	round_condition.set_value(&"seed", trial_seed)
	say("Which way do the dots go? Pinch your fingers, sweep your hand that way, then let go.")


func focus_point() -> Vector3:
	return _cloud.global_position


func _on_button(hand: StringName, action: StringName, pressed: bool) -> void:
	if action != &"trigger_click":
		return
	if pressed:
		if _hand == &"":
			_hand = hand
			_start = App.rig.hand(hand).global_position
			_onset = seconds()
	elif hand == _hand:
		_hand = &""
		_judge(hand, App.rig.hand(hand).global_position)


func _judge(hand: StringName, end: Vector3) -> void:
	var result := classify(_frame.basis.inverse() * (end - _start), seconds() - _onset, _flow,
		_min_sweep, _min_seconds, _max_seconds, _tolerance)
	result.merge({trial = condition.trial, round = condition.round_index, hand = hand, onset_seconds = _onset,
		help = hint_level, coherence_shown = float(_signal_dots) / _dots})
	if not result.valid:
		_invalid += 1
		Events.report(&"motion_invalid", result)
		say(INVALID_SAY[result.reason])
		return
	_attempts.append(result)
	Events.report(&"motion_attempt", result)
	if not result.correct:
		judge(&"bad", _cloud.global_position)
		count_try()
		say("Not that way. Watch the dots and try again.")
		return
	judge(&"good", _cloud.global_position)
	say("Yes! Now they all go together.")
	_align = create_tween()
	_align.tween_method(_set_alignment, 0.0, 1.0, ALIGN_SECONDS)
	finish(true, {attempts = _attempts.duplicate(), invalid_gestures = _invalid,
		first_attempt_correct = _attempts[0].correct, first_onset_seconds = _attempts[0].onset_seconds,
		response_onset_seconds = result.onset_seconds, gesture_seconds = result.duration_seconds,
		angle_degrees = result.angle_degrees})


## Help: every dot follows the flow. A sweep begun before it is dropped.
func _hint(_level: int) -> void:
	_cancel_sweep()
	_show_signal(_dots)
	judge(&"hint", _cloud.global_position)
	say("Now every dot goes the same way. Watch, then sweep.")


func _teardown() -> void:
	_cancel_sweep()


## The world paused (facilitator panel, system menu): a release now would never arrive.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_cancel_sweep()


func _on_tracking(hand: StringName, tracked: bool) -> void:
	if not tracked and hand == _hand:
		_cancel_sweep()


func _cancel_sweep() -> void:
	_hand = &""


func _show_signal(count: int) -> void:
	_signal_dots = count
	_material.set_shader_parameter(&"signal_count", count)


func _set_alignment(amount: float) -> void:
	_material.set_shader_parameter(&"alignment", amount)
