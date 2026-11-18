extends Trial
## Butterflies fly circles round the seated child, who catches them with a net.
## The net lies on the table until a hand takes it (reach and pinch), then stays
## in that hand for the block. The moving hoop scoops each butterfly it meets.
## In the circles, meet each butterfly head-on and catch them all. In the swarm,
## meet the group's flow head-on and finish one swing with a catch. A wrong
## swarm swing counts when the net stops, or is forgiven if it was a wind-up.

## Below this hoop speed (m/s) the net is not swinging.
const SWING := 0.3
## A swing counts as over once the hoop has been slower than [constant SWING] this long.
const SWING_STOP := 0.3
## Heights of the two circles below the eyes; one circle flies between them, the swarm fills them.
const UPPER := 0.12
const LOWER := 0.3
## Catch them all: a wrong bump counts one try, then none for this long.
const TRY_GAP := 0.8
## Swarm: each second this share of the noise trades places with the flow, and draws a new way to go.
const SHUFFLE := 0.5
## Seconds before releasing the bag at the end of a round.
const KEEP := 1.5
## The reach along the child's depth axis, where judging distance is harder.
const DEPTH_SLACK := 0.25

@export var swarm := false

var _rng := RandomNumberGenerator.new()
## The eyes at round start: the circles' centre, -Z ahead.
var _frame := Transform3D.IDENTITY
var _catch_radius := 0.0
var _tolerance := 0.0
var _attempts: Array[Dictionary] = []
var _quiet_until := 0.0
## Swarm: the flow's spin and who follows it.
var _flow := 1.0
var _signal: Array[int] = []
var _noise: Array[int] = []
var _shuffle_debt := 0.0
## The current swing's answer and a possible wrong-way wind-up from before a turn.
var _answer: Dictionary = {}
var _wrong: Dictionary = {}
var _swing_from := Vector3.ZERO
var _swing_at := 0.0
var _swinging := false
## The way the swing went when it started or was judged. Turning back starts a new swing.
var _swing_way := Vector3.ZERO
var _slow_for := 0.0
var _net: ButterflyNet
var _swarm: ButterflySwarm


func _ready() -> void:
	super()
	_net = ButterflyNet.new()
	_net.name = "Net"
	add_child(_net)
	_swarm = ButterflySwarm.new()
	_swarm.name = "Swarm"
	add_child(_swarm)


func _setup(round_condition: TrialCondition) -> void:
	_rng.randomize()
	_attempts.clear()
	_answer = {}
	_wrong = {}
	_quiet_until = 0.0
	_swinging = false
	_slow_for = 0.0
	_swarm.slow = 1.0
	_swarm.speed = round_condition.value(&"speed")
	_tolerance = round_condition.value(&"tolerance")
	_catch_radius = round_condition.value(&"catch_radius")
	if swarm:
		_setup_swarm(round_condition)
	else:
		_setup_circles(round_condition)
	if not _net.held():
		var rest := in_front(0.4).origin
		rest.y = App.reality.work_surface().transform.origin.y
		_net.lay(rest, _frame.origin)
		say("Pick up the net from the table.")
	if swarm:
		if round_condition.round_index == 0:
			say("Which way do most butterflies fly? Swing your net to meet them.")
	else:
		say("Catch the butterflies! Swing your net to meet them.")


## Catch them all: a fresh flock on one or two circles.
func _setup_circles(round_condition: TrialCondition) -> void:
	_frame = in_front(0.0)
	_swarm.radius = round_condition.value(&"radius")
	_swarm.reset(_frame.origin)
	var count := int(round_condition.value(&"butterflies"))
	var rings := int(round_condition.value(&"rings"))
	var spins: Array[float] = [1.0 if _rng.randf() < 0.5 else -1.0]
	spins.append(-spins[0])
	var per_ring := ceilf(float(count) / rings)
	for i in count:
		var ring := i % rings
		var height := -(LOWER + UPPER) * 0.5 if rings == 1 else -(UPPER if ring == 0 else LOWER)
		# Spread round the circle, from behind the child, so they come round into view one by one.
		var angle := -PI / 2.0 + TAU * (float(i / rings) + _rng.randf_range(-0.2, 0.2)) / per_ring
		_swarm.add(_rng.randi() % ButterflySwarm.SPECIES.size(), angle, height + _rng.randf_range(-0.03, 0.03), spins[ring])
	_swarm.show_all()
	round_condition.set_value(&"spins", spins.slice(0, rings))


## The swarm: built at the block's first round, then kept; every round draws the flow again.
func _setup_swarm(round_condition: TrialCondition) -> void:
	_flow = 1.0 if _rng.randf() < 0.5 else -1.0
	if _swarm.size() == 0:
		_frame = in_front(0.0)
		_swarm.radius = round_condition.value(&"radius")
		_swarm.reset(_frame.origin)
		for i in int(round_condition.value(&"butterflies")):
			_swarm.add(_rng.randi() % ButterflySwarm.SPECIES.size(), _rng.randf() * TAU,
				-_rng.randf_range(UPPER - 0.05, LOWER + 0.05), _flow, _rng.randf_range(-PI, PI))
		_swarm.show_all()
	var flying: Array[int] = []
	for i in _swarm.size():
		if _swarm.flying(i):
			flying.append(i)
	flying.shuffle()
	var signal_count := roundi(round_condition.value(&"coherence") * flying.size())
	_signal = flying.slice(0, signal_count)
	_noise = flying.slice(signal_count)
	for i in _signal:
		_swarm.steer(i, _flow, 0.0)
	for i in _noise:
		_swarm.steer(i, _flow, _rng.randf_range(-PI, PI))
	round_condition.set_value(&"flow", &"anticlockwise" if _flow > 0.0 else &"clockwise")
	round_condition.set_value(&"signal_butterflies", signal_count)
	round_condition.set_value(&"flying", flying.size())


func focus_point() -> Vector3:
	return _frame.origin + _frame.basis * Vector3(0.0, -LOWER, -_swarm.radius)


func _on_touched(hand: StringName, target: Target) -> void:
	if target == _net.grip and not _net.held():
		_net.hold(hand)
		Events.play(&"grab", _net.grip.global_position)
		Events.report(&"net_taken", {trial = condition.trial, hand = hand, seconds = snappedf(seconds(), 0.01)})


func _notification(what: int) -> void:
	super(what)
	if what == NOTIFICATION_PAUSED:
		_net.reset_motion()
		_wrong = {}
		if not _answer.get("correct", false):
			_answer = {}
			_swinging = false


func _teardown() -> void:
	_swarm.release_after(KEEP)


func _process(delta: float) -> void:
	if is_running() and _answer.get("correct", false) and def.time_limit > 0.0 and seconds() + delta >= def.time_limit:
		_end_swing(true)
	super(delta)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	var from := _net.global_position
	if _net.held():
		var pointer := App.rig.pointer(_net.hand)
		if pointer.tracked():
			_net.follow(pointer.grip().origin, -pointer.global_basis.z, delta)
		else:
			_net.reset_motion()
	if swarm and is_running():
		_shuffle(delta)
	_swarm.step(delta)
	if not _net.held() or (not swarm and not is_running()):
		return
	var swing := _net.velocity.slide(Vector3.UP)
	var fast := swing.length_squared() >= SWING * SWING
	if swarm and is_running():
		if not _track_swing(swing, fast, delta):
			return
	elif not fast:
		return
	_sweep(from, swing)


## Check the whole path of the hoop this tick. Compress depth so the same
## circular reach test gives the child more room for error along their view.
func _sweep(from: Vector3, swing: Vector3) -> void:
	var hoop := _net.global_position
	var travel := hoop - from
	if travel.dot(swing) <= 0.0:
		return
	var depth := (hoop - _frame.origin).slide(Vector3.UP).normalized()
	var stretch := depth * (1.0 - _catch_radius / DEPTH_SLACK)
	var path := travel - stretch * travel.dot(depth)
	var reach_squared := _catch_radius * _catch_radius
	for i in _swarm.size():
		if not _swarm.flying(i):
			continue
		var at := _swarm.position_of(i)
		var offset := at - from
		var point := offset - stretch * offset.dot(depth)
		var closest := Geometry3D.get_closest_point_to_segment(point, Vector3.ZERO, path)
		if point.distance_squared_to(closest) <= reach_squared:
			_meet(i, at, swing)


func _meet(i: int, at: Vector3, swing: Vector3) -> void:
	var flight := _swarm.along(at, _flow) if swarm else _swarm.heading(i)
	var against := rad_to_deg(swing.angle_to(-flight))
	var caught := against <= _tolerance
	var score_swing := swarm and is_running()
	if score_swing:
		if _answer.is_empty():
			_answer = _attempt(against)
			_answer.merge({correct = caught, caught = 0, from = _swing_from,
				onset_seconds = snappedf(_swing_at, 0.01),
				coherence_shown = float(_signal.size()) / (_signal.size() + _noise.size())})
			_swing_way = swing
		caught = _answer.correct
	if caught:
		_swarm.catch_in(i, _net)
		Events.play(&"catch", at)
	else:
		_swarm.dodge(i, _net.global_position)
	if swarm:
		if score_swing and caught:
			if _answer.caught == 0:
				judge(&"good", at)
				say("Got them!")
			_answer.caught += 1
			_signal.erase(i)
			_noise.erase(i)
		return
	_score_circle_contact(i, at, against, caught)


func _score_circle_contact(i: int, at: Vector3, against: float, caught: bool) -> void:
	if not caught and (against < 180.0 - _tolerance or seconds() < _quiet_until):
		return
	var result := _attempt(against)
	result.merge({caught = caught, species = _swarm.species_of(i), seconds = snappedf(seconds(), 0.01)})
	_log_attempt(result)
	if caught:
		judge(&"good", at)
		var left := _swarm.flying_count()
		if left == 0:
			say("You caught them all! Let them fly free.")
			var wrong := _attempts.filter(func(a: Dictionary) -> bool: return not a.caught).size()
			finish(true, {attempts = _attempts.duplicate(), caught = _attempts.size() - wrong, wrong = wrong})
		elif left == 1:
			say("Just one more!")
		return
	_quiet_until = seconds() + TRY_GAP
	judge(&"bad", at)
	count_try()
	say("It flew away! Swing to meet it, not after it.")


# -- the swarm ----------------------------------------------------------------

## Some of the noise trade places with the flow, and the noise draws new ways to go.
func _shuffle(delta: float) -> void:
	if _noise.is_empty():
		return
	_shuffle_debt += _noise.size() * SHUFFLE * delta
	while _shuffle_debt >= 1.0:
		_shuffle_debt -= 1.0
		var k := _rng.randi() % _noise.size()
		var noise := _noise[k]
		if not _signal.is_empty():
			var j := _rng.randi() % _signal.size()
			_noise[k] = _signal[j]
			_signal[j] = noise
			_swarm.steer(noise, _flow, 0.0)
			noise = _noise[k]
		_swarm.steer(noise, _flow, _rng.randf_range(-PI, PI))


## A turn starts a fresh swing, even if the same frame starts the next round.
func _track_swing(swing: Vector3, fast: bool, delta: float) -> bool:
	if not fast:
		_slow_for += delta
		if _swinging and _slow_for >= SWING_STOP:
			_swinging = false
			_end_swing(true)
		return false
	_slow_for = 0.0
	if not _swinging or swing.dot(_swing_way) < 0.0:
		_end_swing(false)
		if not is_running():
			return false
		_swinging = true
		_swing_from = _net.global_position
		_swing_at = seconds()
		_swing_way = swing
	return true


## Score after the whole swing has had time to scoop butterflies along its path.
func _end_swing(stopped: bool) -> void:
	if not _answer.is_empty():
		var result := _answer
		_answer = {}
		if result.correct:
			var windups := 0 if _wrong.is_empty() else 1
			if windups:
				Events.report(&"catch_windup", _wrong)
			_wrong = {}
			_log_attempt(result)
			finish(true, {attempts = _attempts.duplicate(), windups = windups, caught = result.caught,
				first_attempt_correct = _attempts[0].correct, angle_degrees = result.angle_degrees})
			return
		_wrong = result
	if stopped and not _wrong.is_empty():
		_log_attempt(_wrong)
		_wrong = {}
		judge(&"bad", _net.global_position)
		count_try()
		say("They flew away! Swing to meet most of them.")


func _attempt(angle: float) -> Dictionary:
	return {trial = condition.trial, round = condition.round_index, hand = _net.hand,
		angle_degrees = snappedf(angle, 0.1), swing_speed = snappedf(_net.velocity.length(), 0.01), help = hint_level}


func _log_attempt(result: Dictionary) -> void:
	_attempts.append(result)
	Events.report(&"catch_attempt", result)


## Help: catch them all slows everyone; the swarm all flies with the flow.
func _hint(_level: int) -> void:
	judge(&"hint", focus_point())
	if not swarm:
		_swarm.slow = 0.5
		say("Now they fly slowly. Swing to meet one.")
		return
	_signal.append_array(_noise)
	_noise.clear()
	for i in _signal:
		_swarm.steer(i, _flow, 0.0)
	say("Now they all fly together. Watch, then swing.")
