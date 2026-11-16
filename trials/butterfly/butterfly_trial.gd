extends Trial
## Butterflies fly circles round the seated child, who catches them with a net.
## The net lies on the table until a hand takes it (reach and pinch), then stays
## in that hand for the block. Two games on one scene script:
##
## Catch them all ([member swarm] off): each butterfly is judged on its own. A
## swing that meets one head-on (the hoop going against its flight) takes it
## into the bag; one that chases it bumps it off the rim: a wrong try. A net
## held still, or swung across its path, it flutters round. The round is won
## when the last one is in the bag; then they are let go.
## Axes: speed (driven, m/s), butterflies, rings (1: all one way; 2: an upper and
## a lower circle flying opposite ways), radius, catch_radius, tolerance.
##
## The swarm ([member swarm] on): global motion. A share of the swarm
## (coherence) flies round one way, the rest flutter every way, and who is who
## keeps changing. A swing through the swarm against the flow scoops a few into
## the net and wins the round; one with the flow scatters them, and counts a
## try once the net stops (one that turns straight into the right way was a
## wind-up and counts nothing). Each round the flow may change.
## Axes: coherence (driven), butterflies, speed, radius, tolerance.
##
## Help (asked for, or after [member TrialDef.hint_after]): catch them all slows
## everyone to half speed; the swarm all flies with the flow.

## Below this hoop speed (m/s) the net is not swinging.
const SWING := 0.3
## A swing counts as over once the hoop has been slower than [constant SWING] this long.
const SWING_STOP := 0.3
## Heights of the two circles below the eyes; one circle flies between them, the swarm fills them.
const UPPER := 0.12
const LOWER := 0.3
## Catch them all: a wrong bump counts one try, then none for this long.
const TRY_GAP := 0.8
## Swarm: swings that set off in a round's first seconds are hands settling, ignored.
const ARM_SECONDS := 0.8
## Swarm: how many one right swing scoops, and how far from the band round the circle a swing still counts.
const SCOOP := 3
const REACH := 0.15
## Swarm: each second this share of the noise trades places with the flow, and draws a new way to go.
const SHUFFLE := 0.5
## Seconds caught butterflies stay in the net before they are let go (the swarm).
const KEEP := 1.5
## Where the shoulder is from the eyes: down and out to the hand's side.
const SHOULDER_DOWN := 0.22
const SHOULDER_OUT := 0.17

@export var swarm := false

var _rng := RandomNumberGenerator.new()
## The eyes at round start: the circles' centre, -Z ahead.
var _frame := Transform3D.IDENTITY
var _catch_radius := 0.0
var _tolerance := 0.0
var _attempts: Array[Dictionary] = []
var _quiet_until := 0.0
## Swarm: the flow's spin, who follows it, the wrong swing waiting for the net to stop.
var _flow := 1.0
var _signal: Array[int] = []
var _noise: Array[int] = []
var _shuffle_debt := 0.0
var _wrong: Dictionary = {}
var _swing_from := Vector3.ZERO
var _swing_at := 0.0
var _swinging := false
var _judged := false
## The way the judged swing went; turning back from it starts a new swing.
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
	_wrong.clear()
	_quiet_until = 0.0
	_swinging = false
	_judged = false
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
		Events.report(&"net_taken", {trial = condition.trial, hand = hand, seconds = snappedf(seconds(), 0.01)})


func _notification(what: int) -> void:
	super(what)
	if what == NOTIFICATION_PAUSED:
		_wrong.clear()
		_swinging = false


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	if swarm and is_running():
		_shuffle(delta)
	_swarm.step(delta)
	if not _net.held():
		return
	var pointer := App.rig.pointer(_net.hand)
	if not pointer.tracked():
		return
	var eye := App.head().global_transform
	var out := Vector3(eye.basis.x.x, 0.0, eye.basis.x.z).normalized() * (1.0 if _net.hand == &"right" else -1.0)
	_net.follow(pointer.grip().origin, eye.origin + Vector3.DOWN * SHOULDER_DOWN + out * SHOULDER_OUT, delta)
	if not is_running():
		return
	if swarm:
		_track_swing(delta)
		return
	for i in _swarm.size():
		if _swarm.flying(i) and _swarm.position_of(i).distance_to(_net.global_position) <= _catch_radius:
			_meet(i)


# -- catch them all -----------------------------------------------------------

## The hoop has reached butterfly [param i]: caught, bumped (a wrong try) or it flutters round.
func _meet(i: int) -> void:
	var swing := Vector3(_net.velocity.x, 0.0, _net.velocity.z)
	var flight := _swarm.heading(i)
	var against := rad_to_deg(swing.angle_to(-flight))
	var along := rad_to_deg(swing.angle_to(flight))
	if _net.velocity.length() < SWING or against > _tolerance and along > _tolerance:
		_swarm.dodge(i, _net.global_position)
		return
	var result := {trial = condition.trial, round = condition.round_index, hand = _net.hand,
		caught = against <= _tolerance, angle_degrees = snappedf(against, 0.1),
		swing_speed = snappedf(_net.velocity.length(), 0.01), species = _swarm.species_of(i),
		seconds = snappedf(seconds(), 0.01), help = hint_level}
	if result.caught:
		_attempts.append(result)
		Events.report(&"catch_attempt", result)
		judge(&"good", _swarm.position_of(i))
		_swarm.catch_in(i, _net, _bag_spot())
		var left := _swarm.flying_count()
		if left == 0:
			say("You caught them all! Let them fly free.")
			_swarm.release(_away())
			var wrong := _attempts.filter(func(a: Dictionary) -> bool: return not a.caught).size()
			finish(true, {attempts = _attempts.duplicate(), caught = _attempts.size() - wrong, wrong = wrong})
		elif left == 1:
			say("Just one more!")
		return
	_swarm.dodge(i, _net.global_position)
	if seconds() < _quiet_until:
		return
	_quiet_until = seconds() + TRY_GAP
	_attempts.append(result)
	Events.report(&"catch_attempt", result)
	judge(&"bad", _swarm.position_of(i))
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


## One judgement per swing: the first stretch of it fast enough, through the swarm's band. Turning back starts a new swing.
func _track_swing(delta: float) -> void:
	var hoop := _net.global_position
	if _net.velocity.length() < SWING:
		_slow_for += delta
		if _swinging and _slow_for >= SWING_STOP:
			_swinging = false
			_judged = false
			if not _wrong.is_empty():
				_count_wrong()
		return
	_slow_for = 0.0
	if _judged and _net.velocity.dot(_swing_way) < 0.0:
		_swinging = false
		_judged = false
	if not _swinging:
		_swinging = true
		_swing_from = hoop
		_swing_at = seconds()
	if _judged or _swing_at < ARM_SECONDS:
		return
	var off := Vector2(hoop.x - _frame.origin.x, hoop.z - _frame.origin.z).length() - _swarm.radius
	if absf(off) > _swarm.band + REACH:
		return
	_judged = true
	_swing_way = _net.velocity
	var flow := _swarm.along(hoop, _flow)
	var swing := Vector3(_net.velocity.x, 0.0, _net.velocity.z)
	var angle := rad_to_deg(swing.angle_to(-flow))
	var result := {trial = condition.trial, round = condition.round_index, hand = _net.hand,
		correct = angle <= _tolerance, angle_degrees = snappedf(angle, 0.1),
		swing_speed = snappedf(_net.velocity.length(), 0.01), onset_seconds = snappedf(_swing_at, 0.01),
		from = _swing_from, help = hint_level, coherence_shown = float(_signal.size()) / maxi(1, _signal.size() + _noise.size())}
	var near := _nearest(hoop, SCOOP)
	if not result.correct:
		for i in near:
			_swarm.dodge(i, hoop)
		_wrong = result
		return
	var windups := 0 if _wrong.is_empty() else 1
	if windups:
		Events.report(&"catch_windup", _wrong)
	_wrong.clear()
	_attempts.append(result)
	Events.report(&"catch_attempt", result)
	for i in near:
		_signal.erase(i)
		_noise.erase(i)
		_swarm.catch_in(i, _net, _bag_spot())
	judge(&"good", hoop)
	say("Got them!")
	_swarm.release(_away(), false, KEEP)
	finish(true, {attempts = _attempts.duplicate(), windups = windups,
		first_attempt_correct = _attempts[0].correct, angle_degrees = result.angle_degrees})


## The net stopped after going with the flow: that was its answer.
func _count_wrong() -> void:
	_attempts.append(_wrong)
	Events.report(&"catch_attempt", _wrong)
	_wrong.clear()
	judge(&"bad", _net.global_position)
	count_try()
	say("They flew away! Swing to meet most of them.")


func _nearest(at: Vector3, count: int) -> Array[int]:
	var flying: Array[int] = []
	for i in _swarm.size():
		if _swarm.flying(i):
			flying.append(i)
	flying.sort_custom(func(a: int, b: int) -> bool:
		return _swarm.position_of(a).distance_squared_to(at) < _swarm.position_of(b).distance_squared_to(at))
	return flying.slice(0, count)


# -- both ---------------------------------------------------------------------

func _bag_spot() -> Vector3:
	return Vector3(_rng.randf_range(-0.03, 0.03), _rng.randf_range(-0.03, 0.03), ButterflyNet.BAG_DEPTH * 0.6)


## Out from the child through the net, level.
func _away() -> Vector3:
	var away := _net.global_position - _frame.origin
	away.y = 0.0
	return away.normalized()


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
