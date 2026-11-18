extends TestCase
## Catch the butterflies (trials/butterfly): take the net, then swing it to meet
## each butterfly. Played through SimInput; the hoop is steered by placing the
## hand so the net reaches the wanted point.

const CATCH := preload("res://trials/butterfly/butterfly.tres")
const TASK := preload("res://content/tasks/catch_butterflies.tres")
const SWARM := preload("res://trials/butterfly/butterfly_swarm.tres")

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


func test_a_desktop_swing_across_a_butterfly_catches_it() -> void:
	await _start(CATCH)
	var trial: Node3D = App.session.trial
	await _take(trial._net)
	var swarm: ButterflySwarm = trial._swarm
	var eye := App.head().global_transform
	var ahead := -eye.basis.z
	# Wait for one to come round in front, as a player would.
	var in_front := func() -> int:
		for i in swarm.size():
			var to := swarm.position_of(i) - eye.origin
			if swarm.flying(i) and absf(rad_to_deg(Vector2(to.x, to.z).angle_to(Vector2(ahead.x, ahead.z)))) < 15.0:
				return i
		return -1
	expect(await until(func() -> bool: return in_front.call() >= 0, 30.0), "one comes round in front")
	var i: int = in_front.call()
	await _desktop_swing(swarm, i)
	expect(not swarm.flying(i), "the cursor swept across it against its flight: caught")


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


func test_swarm_scoops_each_contact_along_the_swing_and_releases_the_oldest() -> void:
	await _start(SWARM)
	var trial: Node3D = App.session.trial
	var swarm: ButterflySwarm = trial._swarm
	expect_eq(swarm.size(), 90, "the whole swarm")
	await _take(trial._net)
	await wait(1.0)
	_arrange_swarm_contacts(trial)
	var ended := record(Events.trial_ended)
	await _swing_through(trial, -1.0, true, 0.55)
	await wait(0.5)
	expect(ended.is_empty(), "passing below the flock does not win the round")
	expect_eq(swarm.flying_count(), 90, "a swing through empty space catches nothing")
	await _swing_through(trial, -1.0)
	expect(ended.is_empty(), "keep the round live for the whole swing")
	if not await until(func() -> bool: return not ended.is_empty(), 2.0):
		expect(false, "a completed swing that touched the flock wins")
		return
	expect(ended[0][1] and ended[0][2].first_try, "first try")
	expect_eq(ended[0][2].caught, 8, "all contacts at both ends of one swing are counted")
	expect_eq(swarm.flying_count(), 82, "butterflies above and beyond the hoop keep flying")
	expect_eq(swarm._bag.size(), ButterflySwarm.BAG_SPOTS.size(), "the bag has a fixed capacity")
	expect(swarm._state[0] == ButterflySwarm.FREE and swarm._state[1] == ButterflySwarm.FREE,
		"the oldest arrivals have already flown free")
	for i in swarm._bag:
		expect(trial._net.to_local(swarm.position_of(i)).z > 0.0, "each retained butterfly is inside the bag")
	await wait(trial.KEEP + 0.05)
	expect(swarm._bag.is_empty(), "the others are released after the round")


func test_butterfly_swarm_level_accepts_back_to_back_swings() -> void:
	await _play_swarm_level(TASK.level_by_id(&"swarm").plan)


func test_busy_swarm_level_accepts_back_to_back_swings() -> void:
	await _play_swarm_level(TASK.level_by_id(&"busy_swarm").plan)


func test_swarm_swing_with_the_flow_counts_once_the_net_stops() -> void:
	await _start(SWARM)
	var trial: Node3D = App.session.trial
	await _take(trial._net)
	await wait(1.0)
	_arrange_swarm_contacts(trial)
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
	_arrange_swarm_contacts(trial)
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
	await _start_plan(plan)


func _start_plan(plan: SessionPlan) -> void:
	await boot(plan, &"global_motion")
	App.session.run()
	expect(await until(func() -> bool: return App.session.trial != null and App.session.trial.is_running(), 10.0), "a round runs")
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, Vector3.ZERO))
	await frames(2)
	_grip_offset = App.rig.pointer(&"right").grip().origin - App.rig.hand(&"right").global_position


func _play_swarm_level(plan: SessionPlan) -> void:
	await _start_plan(plan)
	var trial: Node3D = App.session.trial
	await _take(trial._net)
	var ended := record(Events.trial_ended)
	for round_index in plan.blocks[0].rounds:
		if not trial.is_running() or trial.condition.round_index != round_index:
			expect(false, "round %d starts as soon as the previous catch is scored" % (round_index + 1))
			return
		_arrange_swarm_contacts(trial)
		await _swing_through(trial, -1.0)
		if not await until(func() -> bool: return ended.size() > round_index, 2.0):
			expect(false, "round %d: the new swing catches butterflies" % (round_index + 1))
			return
		if not ended[round_index][1]:
			expect(false, "round %d won by the first swing" % (round_index + 1))
			return
		expect(ended[round_index][2].attempts[0].onset_seconds < 0.3, "the swing starts right away")
	var remaining: int = trial._swarm.flying_count()
	_arrange_swarm_contacts(trial)
	await _swing_through(trial, -1.0)
	expect(trial._swarm.flying_count() < remaining, "the net still catches during the closing animation")
	expect_eq(ended.size(), plan.blocks[0].rounds, "the last catch does not create another scored round")
	expect(await until(func() -> bool: return not App.session.running), "the level ends")
	expect(App.session.won, "all three rounds won")


func _take(net: ButterflyNet) -> void:
	_put_grip(net.grip.global_position)
	await frames(2)
	input.click(&"right", &"trigger_click")
	await frames(2)


func _put_grip(at: Vector3) -> void:
	input.set_hand(&"right", Transform3D(Basis.IDENTITY, at - _grip_offset))


## Places the hand so the hoop sits at [param hoop], the hand pointing at it from the eyes.
func _put_hoop(hoop: Vector3) -> void:
	var eye := App.head().global_position
	var ray := (hoop - eye).normalized()
	var reach := ButterflyNet.HANDLE + App.rig.pointer(&"right").tip_reach
	input.set_hand(&"right", Transform3D(Basis.looking_at(ray), hoop - ray * reach))


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


## One horizontal swing: [param way] -1 against the flow, +1 with it.
func _swing_through(trial: Node3D, way: float, stop := true, below := 0.2) -> void:
	var swarm: ButterflySwarm = trial._swarm
	var ahead: Vector3 = trial._frame * Vector3(0.0, -below, -swarm.radius)
	var flow := swarm.along(ahead, trial._flow)
	for frame in 4:
		await _hoop_to(ahead - flow * way * 0.15)
	for frame in 19:
		await _hoop_to(ahead + flow * way * (-0.15 + float(frame) / 60.0))
	if stop:
		await frames(2)


## Two groups at opposite ends of the swing, plus misses both above it and in depth.
func _arrange_swarm_contacts(trial: Node3D) -> void:
	var swarm: ButterflySwarm = trial._swarm
	var ahead: Vector3 = trial._frame * Vector3(0.0, -0.2, -swarm.radius)
	var flow := swarm.along(ahead, trial._flow)
	var offsets: Array[Vector3] = [
		Vector3(0.18, -0.03, 0.01), Vector3(0.19, 0.04, -0.01),
		Vector3(0.20, 0.02, 0.05), Vector3(0.22, -0.01, -0.03),
		Vector3(-0.18, -0.03, 0.02), Vector3(-0.19, 0.02, -0.02),
		Vector3(-0.21, -0.01, 0.05), Vector3(-0.20, 0.04, -0.03),
		Vector3(0.0, 0.32, 0.0), Vector3(0.0, 0.0, 0.32),
	]
	swarm.slow = 0.0
	var placed := 0
	for i in swarm.size():
		if not swarm.flying(i):
			continue
		var at: Vector3 = trial._frame * Vector3(0.0, -0.2, swarm.radius)
		if placed < offsets.size():
			var offset := offsets[placed]
			at = ahead + flow * offset.x + Vector3.UP * offset.y - trial._frame.basis.z * offset.z
			placed += 1
		swarm._pos[i] = at
		swarm._height[i] = at.y - swarm.centre.y
		swarm._flutter[i] = 0.0


## As DesktopDriver drags the hand: on the cursor's ray, [member DesktopDriver.depth] from the eye. The
## cursor sweeps 50 degrees in 0.4 s across butterfly [param i], against its flight.
func _desktop_swing(swarm: ButterflySwarm, i: int) -> void:
	var eye := App.head().global_position
	var to := swarm.position_of(i) - eye
	var against := -signf(to.cross(swarm.heading(i)).y)
	for frame in 25:
		var yaw := deg_to_rad(25.0 - 50.0 * frame / 24.0) * -against
		var ray := (swarm.position_of(i) - eye).normalized().rotated(Vector3.UP, yaw)
		input.set_hand(&"right", Transform3D(Basis.looking_at(ray), eye + ray * 0.45))
		await get_tree().physics_frame
		if not swarm.flying(i):
			break
	await wait(0.3)


func _hoop_to(at: Vector3) -> void:
	_put_hoop(at)
	await get_tree().physics_frame
