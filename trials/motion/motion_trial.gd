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

const HEADINGS: Array[StringName] = [&"right", &"left", &"toward", &"away"]
## Flow of each heading in the cloud's frame: its -Z points away from the child.
const FLOWS: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]
## The cloud's near face stays at least this far from the eyes, metres.
const NEAR := 0.6
const ALIGN_SECONDS := 0.6
const ARM_SECONDS := 0.8

## Tech demo: a right sweep breaks the real wall ahead ([WallBreak]).
@export var break_wall := false
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
var _align: Tween

@onready var _cloud: GPUParticles3D = $Cloud
@onready var _trails: Dictionary[StringName, SweepTrail] = {&"left": $LeftTrail, &"right": $RightTrail}
@onready var _material := _cloud.process_material as ShaderMaterial


## Judges one sweep: [param displacement] in the cloud's frame. Only its level
## part counts: the flow never rises or falls.
static func classify(displacement: Vector3, expected: Vector3, tolerance: float) -> Dictionary:
	var angle := rad_to_deg(Vector3(displacement.x, 0.0, displacement.z).angle_to(expected))
	return {correct = angle <= tolerance, angle_degrees = angle, direction = displacement.normalized(),
		distance_metres = displacement.length()}


func _setup(round_condition: TrialCondition) -> void:
	if _align:
		_align.kill()
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
		help = hint_level, coherence_shown = float(_signal_dots) / _dots})
	if not result.correct:
		_wrong[hand] = result
		return
	# A wrong sweep that set off elsewhere was a wind-up; this sweep's own start bending in is not.
	var windups := _wrong.values().filter(func(wrong: Dictionary) -> bool: return wrong.from != from)
	for windup: Dictionary in windups:
		Events.report(&"motion_windup", windup)
	_wrong.clear()
	_attempts.append(result)
	Events.report(&"motion_attempt", result)
	judge(&"good", _cloud.global_position)
	say("Yes! Now they all go together.")
	if break_wall:
		var eye := App.head().global_position
		WallBreak.burst(eye, (_cloud.global_position - eye).normalized(), _frame.basis * _flow, wall_style)
	_align = create_tween()
	_align.tween_method(_set_alignment, 0.0, 1.0, ALIGN_SECONDS)
	finish(true, {attempts = _attempts.duplicate(), windups = windups.size(),
		first_attempt_correct = _attempts[0].correct, first_onset_seconds = _attempts[0].onset_seconds,
		response_onset_seconds = result.onset_seconds, gesture_seconds = result.duration_seconds,
		angle_degrees = result.angle_degrees})


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
	say("Not that way. Watch the dots and try again.")


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_wrong.clear()


## Help: every dot follows the flow.
func _hint(_level: int) -> void:
	_show_signal(_dots)
	judge(&"hint", _cloud.global_position)
	say("Now every dot goes the same way. Watch, then sweep.")


func _show_signal(count: int) -> void:
	_signal_dots = count
	_material.set_shader_parameter(&"signal_count", count)


func _set_alignment(amount: float) -> void:
	_material.set_shader_parameter(&"alignment", amount)
