extends TestCase
## Catch the butterflies (trials/butterfly): take the net, then swing it to meet
## each butterfly. Played through SimInput; the hoop is steered by placing the
## hand so the net reaches the wanted point.

const CATCH := preload("res://trials/butterfly/butterfly.tres")
const TASK := preload("res://content/tasks/catch_butterflies.tres")
const SWARM := preload("res://trials/butterfly/butterfly_swarm.tres")
const BUTTERFLY_TRIAL := preload("res://trials/butterfly/butterfly_trial.gd")

## Grip point minus hand position for an unrotated hand.
var _grip_offset := Vector3.ZERO


func test_levels_and_defs() -> void:
	expect(CATCH.skill == &"butterfly_catch" and SWARM.skill == &"butterfly_swarm", "their own staircases")
	expect_eq(CATCH.condition(0.0, 0, false).value(&"speed"), 0.15, "slow at the easy end")
	expect(is_equal_approx(CATCH.condition(1.0, 0, false).value(&"speed"), 0.4), "faster at the hard end")
	var both_ways: Block = TASK.level_by_id(&"both_ways").plan.blocks[0]
	expect_eq(CATCH.condition(0.3, 0, false, both_ways.pins).value(&"rings"), 2.0, "level 2 flies two circles")
	expect_eq(SWARM.condition(0.0, 0, false).value(&"coherence"), 0.9, "the swarm's easy end")
	expect(SWARM.condition(0.0, 0, false).value(&"butterflies") >= 60.0, "a real swarm")
	expect_eq(TASK.levels.map(func(level: TaskLevel) -> TrialDef: return level.plan.blocks[0].trial), [CATCH, CATCH, SWARM, SWARM] as Array, "two catch levels, two swarm levels")
	var place: Place = load("res://content/places/motion.tres")
	expect(TASK in place.tasks, "on the motion menu")


func test_take_the_net_and_catch_every_butterfly() -> void:
	await _start(CATCH)
	var trial: Node3D = App.session.trial
	var net: ButterflyNet = trial._net
	expect(not net.held(), "the net lies on the table")
	await _take(net)
	expect_eq(net.hand, &"right", "the right hand holds it")
	var reports := record(Events.reported)
	var ended := record(Events.trial_ended)
	var swarm: ButterflySwarm = trial._swarm
	var count := swarm.size()
	expect_eq(count, 8, "eight butterflies")
	for swing in 12:
		if swarm.flying_count() == 0:
			break
		var i: int = range(count).filter(func(k: int) -> bool: return swarm.flying(k))[0]
		await _swing_at(swarm, i, -1.0)
		expect(not swarm.flying(i), "met head-on, butterfly %d is caught" % i)
	expect(await until(func() -> bool: return not ended.is_empty()), "the round ends with the last one")
	var data: Dictionary = ended[0][2]
	expect(ended[0][1], "won")
	expect_eq(data.caught, count, "all logged")
	expect(data.first_try, "no wrong swing, no help")


func test_chasing_a_butterfly_bumps_it_and_counts_a_try() -> void:
	await _start(CATCH)
	var trial: Node3D = App.session.trial
	await _take(trial._net)
	var swarm: ButterflySwarm = trial._swarm
	await _swing_at(swarm, 0, 1.0)
	expect(swarm.flying(0), "chased, it gets away")
	expect_eq(trial.tries, 1, "one wrong try")
	await _hold_still_at(swarm, 1)
	expect_eq(trial.tries, 1, "a net held still counts nothing")
	expect(swarm.flying(1), "and catches nothing")


func test_asking_for_help_slows_them() -> void:
	await _start(CATCH)
	var trial: Node3D = App.session.trial
	await raise_hand(&"left")
	expect_eq(trial.hint_level, 1, "help given")
	expect_eq(trial._swarm.slow, 0.5, "half speed")


func test_swarm_swing_against_the_flow_scoops_some_and_wins() -> void:
	await _start(SWARM)
	var trial: Node3D = App.session.trial
	var swarm: ButterflySwarm = trial._swarm
	expect_eq(swarm.size(), 90, "the whole swarm")
	expect_eq(trial._signal.size(), 81, "90% follow the flow")
	await _take(trial._net)
	await wait(1.0)
	var ended := record(Events.trial_ended)
	await _swing_through(trial, -1.0)
	expect(await until(func() -> bool: return not ended.is_empty(), 2.0), "a right swing wins the round")
	expect(ended[0][1] and ended[0][2].first_try, "first try")
	expect_eq(swarm.size() - swarm.flying_count(), trial.SCOOP, "a few in the net")


func test_swarm_swing_with_the_flow_counts_once_the_net_stops() -> void:
	await _start(SWARM)
	var trial: Node3D = App.session.trial
	await _take(trial._net)
	await wait(1.0)
	await _swing_through(trial, 1.0)
	expect_eq(trial.tries, 0, "not yet: the net is still moving")
	await wait(0.6)
	expect_eq(trial.tries, 1, "the net stopped: one wrong try")
	expect(trial.is_running(), "the round goes on")


func test_swarm_wind_up_turned_straight_into_the_right_way_is_forgiven() -> void:
	await _start(SWARM)
	var trial: Node3D = App.session.trial
	await _take(trial._net)
	await wait(1.0)
	var reports := record(Events.reported)
	var ended := record(Events.trial_ended)
	await _swing_through(trial, 1.0, false)
	await _swing_through(trial, -1.0)
	expect(await until(func() -> bool: return not ended.is_empty(), 2.0), "the right swing wins")
	expect(ended[0][2].first_try, "the wind-up counted nothing")
	expect_eq(reports.filter(func(r: Array) -> bool: return r[0] == &"catch_windup").size(), 1, "logged as a wind-up")


func test_swarm_help_makes_every_butterfly_follow() -> void:
	await _start(SWARM)
	var trial: Node3D = App.session.trial
	await raise_hand(&"left")
	expect(trial._noise.is_empty() and trial._signal.size() == 90, "all follow the flow")


# -- helpers ------------------------------------------------------------------

func _start(def: TrialDef) -> void:
	var plan := plan_of(def, 1, false, 0.0)
	plan.blocks[0].pause_between = 3.0 # time to look at the net before the block ends
	await boot(plan, &"global_motion")
	App.session.run()
	expect(await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running(), 10.0), "a round runs")
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, Vector3.ZERO))
	await frames(2)
	_grip_offset = App.rig.pointer(&"right").grip().origin - App.rig.hand(&"right").global_position


func _take(net: ButterflyNet) -> void:
	_put_grip(net.grip.global_position)
	await frames(2)
	input.click(&"right", &"trigger_click")
	await frames(2)


func _put_grip(at: Vector3) -> void:
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, at - _grip_offset))


## Places the hand so the hoop sits at [param hoop], as the trial reckons the shoulder.
func _put_hoop(hoop: Vector3) -> void:
	var eye := App.head().global_transform
	var out := Vector3(eye.basis.x.x, 0.0, eye.basis.x.z).normalized()
	var shoulder := eye.origin + Vector3.DOWN * BUTTERFLY_TRIAL.SHOULDER_DOWN + out * BUTTERFLY_TRIAL.SHOULDER_OUT
	var reach := hoop.distance_to(shoulder) - ButterflyNet.HANDLE
	_put_grip(shoulder + (hoop - shoulder).normalized() * reach)


## Swings the hoop through butterfly [param i] at 1 m/s: [param way] -1 against its flight, +1 with it.
func _swing_at(swarm: ButterflySwarm, i: int, way: float) -> void:
	var start := 0.3 * -way
	for frame in 6:
		await _hoop_to(swarm.position_of(i) + swarm.heading(i).normalized() * start)
	for frame in 30:
		var flight := swarm.heading(i).normalized()
		await _hoop_to(swarm.position_of(i) + flight * (start + way * float(frame) / 60.0))
		if not swarm.flying(i):
			break
	await wait(0.4)


func _hold_still_at(swarm: ButterflySwarm, i: int) -> void:
	var at := swarm.position_of(i) + swarm.heading(i).normalized() * 0.3
	for frame in 60:
		await _hoop_to(at)


## Swings the hoop 0.3 m at 1 m/s through the swarm straight ahead: [param way] -1 against the flow, +1 with it.
## With [param stop], the net then rests.
func _swing_through(trial: Node3D, way: float, stop := true) -> void:
	var swarm: ButterflySwarm = trial._swarm
	var ahead: Vector3 = trial._frame.origin + trial._frame.basis * Vector3(0.0, -0.2, -swarm.radius)
	var flow := swarm.along(ahead, trial._flow)
	for frame in 4:
		await _hoop_to(ahead - flow * way * 0.15)
	for frame in 19:
		await _hoop_to(ahead + flow * way * (-0.15 + float(frame) / 60.0))
	if stop:
		await frames(2)


func _hoop_to(at: Vector3) -> void:
	_put_hoop(at)
	await get_tree().physics_frame
