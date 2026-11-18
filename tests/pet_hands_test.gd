extends TestCase
## Drive the real palm, fingertip and action paths using tracked joint frames.

const LEFT := &"left"
const RIGHT := &"right"
const OPEN := Basis(Vector3.RIGHT, -PI / 2.0)
const VALID := XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID | XRHandTracker.HAND_JOINT_FLAG_ORIENTATION_VALID
const OFFER := Vector3(-0.15, 0.70, -0.42)
const REST := Vector3(-0.15, 0.71, -0.09)

var _joints: Dictionary[StringName, XRHandTracker] = {}
var _calls: Array
var _pet: Pet
var _home: Node
var _pets: Node


func _start() -> void:
	await boot()
	App.xr = OpenXRInterface.new()
	for side in [LEFT, RIGHT]:
		var tracker := XRHandTracker.new()
		tracker.name = StringName("/user/hand_tracker/%s" % side)
		tracker.hand = XRPositionalTracker.TRACKER_HAND_LEFT if side == LEFT else XRPositionalTracker.TRACKER_HAND_RIGHT
		tracker.set_hand_joint_radius(TrackedHand.PALM, 0.018)
		XRServer.add_tracker(tracker)
		_joints[side] = tracker
	_calls = record(Events.reported)
	_home = App.module(&"Home")
	_pets = App.module(&"Pets")
	App.module(&"Inventory").add(&"pet_cat")
	_home.open()
	_home._show(&"room")
	await frames(2)
	_pet = _pets.pets()[0]
	_place(_pet, Vector3(-0.18, 0.0, -0.83))


func shutdown() -> void:
	App.xr = null
	for tracker in _joints.values(): XRServer.remove_tracker(tracker)
	_joints.clear()
	await super.shutdown()


func _place(pet: Pet, at: Vector3) -> void:
	pet.position = at
	pet._mood = Pet.Act.IDLE
	pet._mood_for = 120.0


## Fingers extend in +Y and the palm faces +Z in the Godot hand skeleton.
func _show_hand(side: StringName, at: Vector3, roll := 0.0, tip := Vector3.INF) -> void:
	var palm := Basis(Vector3.FORWARD, roll) * OPEN
	var to_rig := App.rig.global_transform.affine_inverse()
	var tracker := _joints[side]
	tracker.has_tracking_data = true
	for joint in XRHandTracker.HAND_JOINT_MAX:
		var offset := Vector3.ZERO
		if joint == 1: offset.y = -0.038
		elif joint >= 2 and joint <= TrackedHand.THUMB:
			offset = Vector3((0.022 + (joint - 2) * 0.009) * (-1 if side == LEFT else 1), 0.015 + (joint - 2) * 0.011, 0.012)
		elif joint > TrackedHand.THUMB:
			var finger := floori((joint - 6) / 5.0)
			offset = Vector3((0.024 - finger * 0.017) * (-1 if side == LEFT else 1), ((joint - 6) % 5) * 0.022, 0.003)
		var point := tip if joint == TrackedHand.INDEX and tip.is_finite() else at + palm * offset
		tracker.set_hand_joint_transform(joint, to_rig * Transform3D(palm, point))
		tracker.set_hand_joint_flags(joint, VALID)
	# The ray has its own position and orientation, which can differ from the palm.
	input.point(side, at, at + Vector3(0.0, -0.25, -0.6))


func _missing(side: StringName) -> void:
	_joints[side].has_tracking_data = false
	input.track(side, false)


func _count_calls() -> int:
	return _calls.filter(func(event: Array) -> bool: return event[0] == &"pets_called").size()


func _landed(pet: Pet, budget := 150) -> bool:
	for frame in budget:
		if pet.act == Pet.Act.ON_HAND: return true
		await frames()
	return false


func test_open_palm_tracks_a_moving_hand_and_stays_until_withdrawn() -> void:
	await _start()
	_show_hand(LEFT, REST, 0.65)
	await wait(0.18)
	for frame in 22:
		_show_hand(LEFT, REST.lerp(OFFER, smoothstep(0.0, 1.0, frame / 21.0)), 0.60)
		await frames()
	expect(await _landed(_pet), "a gradually extended, tilted palm catches the pet")
	expect(not App.rig.pointer(LEFT)._beam.visible, "the support hand's UI ray stays out of the pet")
	expect_eq(_pet.level, 0, "the supporting fingers do not pet the animal")
	expect(is_equal_approx(_pet._model.scale.x, Pet.HAND_SIZE), "the pet fits in the palm")
	await wait(13.0)
	expect_eq(_pet.act, Pet.Act.ON_HAND, "the animal stays as long as the hand is offered")
	var far := OFFER + Vector3(-0.06, 0.04, -0.06)
	for frame in 32:
		var sway := Vector3(sin(frame * 1.3), cos(frame * 1.7), sin(frame * 0.7)) * 0.005
		_show_hand(LEFT, OFFER.lerp(far, frame / 31.0) + sway, 0.88 + sin(frame * 0.9) * 0.05)
		input.set_head(Transform3D(Basis(Vector3.UP, frame * 0.025), Vector3(0.0, 1.2, 0.0)))
		await frames()
	expect_eq(_count_calls(), 1, "a held palm only invites once")
	expect(_pet.global_position.distance_to(App.rig.pointer(LEFT).palm().origin) < 0.025, "the pet follows small motion even as the head turns")
	_show_hand(LEFT, far + Vector3.BACK * 0.19, 0.88)
	await wait(0.17)
	expect_eq(_pet.act, Pet.Act.JUMP_DOWN, "withdrawing with the palm still up lets the pet go")
	expect(_pet.position.y > 0.0, "the descent is animated")
	await wait(0.46)
	expect(_pet.is_grounded() and is_zero_approx(_pet.position.y), "it lands on the floor")
	expect(is_equal_approx(_pet._model.scale.x, Pet.SIZE), "it returns to floor size")
	expect(App.rig.pointer(LEFT).ui_available, "the hand can point at buttons again")


func test_palm_normal_and_reach_reject_ordinary_hand_poses() -> void:
	await _start()
	var rejected := [
		[OFFER, PI, "palm down"],
		[OFFER, PI / 2.0, "palm sideways"],
		[Vector3(-0.20, 1.38, -0.42), 0.0, "raised for help"],
		[REST, 0.0, "hand near the chest"],
		[Vector3(-0.52, 0.70, -0.12), 0.0, "resting out to the side"],
		[Vector3(-0.16, 0.20, -0.40), 0.0, "reaching down to the floor"],
		[OFFER + Vector3.BACK * 0.80, 0.0, "a palm behind the child"],
	]
	for pose: Array in rejected:
		_show_hand(LEFT, pose[0], pose[1])
		await wait(0.51)
		expect_eq(_count_calls(), 0, pose[2])
	_show_hand(LEFT, OFFER)
	for action: StringName in [&"trigger_click", &"grip_click"]:
		input.press(LEFT, action, true)
		await wait(0.52)
		expect_eq(_count_calls(), 0, "closed hand: %s" % action)
		input.press(LEFT, action, false)


func test_passing_hands_and_switching_hands_do_not_add_up_to_an_offer() -> void:
	await _start()
	for frame in 34:
		_show_hand(LEFT, Vector3(-0.54 + frame * 0.031, 0.73, -0.41), 0.50)
		await frames()
	_show_hand(LEFT, OFFER)
	await wait(0.19)
	_show_hand(LEFT, REST)
	_show_hand(RIGHT, Vector3(0.16, 0.73, -0.42))
	await wait(0.22)
	_show_hand(RIGHT, OFFER, PI)
	expect_eq(_count_calls(), 0, "a palm passing through or two short offers count for nothing")
	_show_hand(RIGHT, Vector3(0.16, 0.74, -0.42), 0.75)
	expect(await _landed(_pet), "a sustained right palm still works")
	expect_eq(_pet._hand, RIGHT, "the correct palm")


func test_palm_survives_finger_occlusion_and_a_short_tracking_gap() -> void:
	await _start()
	_show_hand(LEFT, OFFER, 0.70)
	_joints[LEFT].set_hand_joint_flags(TrackedHand.THUMB, 0)
	_joints[LEFT].set_hand_joint_flags(TrackedHand.INDEX, 0)
	await wait(0.23)
	_missing(LEFT)
	await wait(0.075)
	expect_eq(_count_calls(), 0, "missing frames never count toward the offer")
	_show_hand(LEFT, OFFER, 0.69)
	_joints[LEFT].set_hand_joint_flags(TrackedHand.INDEX, 0)
	_joints[LEFT].set_hand_joint_flags(TrackedHand.THUMB, 0)
	await wait(0.20)
	expect_eq(_count_calls(), 1, "good palm tracking is enough and a brief gap preserves the hold")
	expect(await _landed(_pet), "the pet reaches the palm without both fingertips")
	var at := _pet.global_position
	_joints[LEFT].set_hand_joint_flags(TrackedHand.PALM, XRHandTracker.HAND_JOINT_FLAG_POSITION_VALID)
	await wait(0.09)
	expect_eq(_pet.act, Pet.Act.ON_HAND, "a brief loss of orientation keeps the pet on the last valid point")
	expect(_pet.global_position.is_equal_approx(at), "no twitch when tracking is invalid")
	_show_hand(LEFT, OFFER + Vector3.UP * 0.02, 0.69)
	await wait(0.17)
	expect(_pet.global_position.distance_to(at) < 0.026, "recovering does not throw the pet")


func test_long_loss_resets_a_partial_offer_and_drops_a_perched_pet() -> void:
	await _start()
	_show_hand(LEFT, OFFER)
	await wait(0.22)
	_missing(LEFT)
	await wait(0.21)
	_show_hand(LEFT, OFFER)
	await wait(0.20)
	expect_eq(_count_calls(), 0, "an old partial hold has expired")
	expect(await _landed(_pet), "a fresh offer works")
	_missing(LEFT)
	await wait(0.20)
	expect_eq(_pet.act, Pet.Act.JUMP_DOWN, "sustained loss sends the pet back to the floor")
	_show_hand(LEFT, OFFER)
	await wait(0.7)
	expect_eq(_count_calls(), 1, "the same held pose does not invite again on recovery")
	_show_hand(LEFT, REST)
	await wait(0.20)
	_show_hand(LEFT, OFFER)
	expect(await _landed(_pet), "a new offer after bringing the hand to rest works")
	expect_eq(_count_calls(), 2, "one new call")


func test_implausible_pose_jump_does_not_teleport_a_pet() -> void:
	await _start()
	_show_hand(LEFT, OFFER)
	expect(await _landed(_pet), "settled on palm")
	var at := _pet.global_position
	_show_hand(LEFT, OFFER + Vector3.RIGHT * 0.33)
	await wait(0.09)
	expect(_pet.global_position.is_equal_approx(at), "an implausible pose change is ignored")
	await wait(0.12)
	expect_eq(_pet.act, Pet.Act.JUMP_DOWN, "a continuing bad pose leads to a safe descent")
	expect(_pet.global_position.distance_to(at) < 0.16, "the descent started at the last stable palm")


func test_withdrawing_during_the_run_or_the_jump_never_lands_on_empty_air() -> void:
	await _start()
	_place(_pet, Vector3(1.8, 0.0, 1.7))
	_show_hand(LEFT, OFFER)
	await wait(0.51)
	expect_eq(_pet.act, Pet.Act.COME, "a distant pet comes immediately after recognition")
	_show_hand(LEFT, REST)
	await wait(0.40)
	expect(_pet.is_grounded() and _pet.act != Pet.Act.COME, "an early withdrawal cancels the run")
	_place(_pet, Vector3(-0.2, 0.0, -0.82))
	_show_hand(LEFT, OFFER)
	for frame in 125:
		if _pet.act == Pet.Act.JUMP_UP: break
		await frames()
	expect_eq(_pet.act, Pet.Act.JUMP_UP, "the next offer starts a hop")
	_show_hand(LEFT, REST)
	await wait(0.18)
	expect_eq(_pet.act, Pet.Act.JUMP_DOWN, "withdrawal redirects an in-flight hop")
	await wait(0.5)
	expect(_pet.is_grounded() and is_zero_approx(_pet.position.y), "landed")


func test_two_palm_offers_invite_only_one_pet_and_do_not_queue_another() -> void:
	await _start()
	App.module(&"Inventory").add(&"pet_dog")
	var dog: Pet = _pets.pets()[1]
	dog.has_stone = true
	_place(dog, Vector3(-0.16, 0.0, -0.92))
	_show_hand(LEFT, OFFER)
	_show_hand(RIGHT, Vector3(0.15, 0.71, -0.42))
	expect(await _landed(dog), "a pet with a stone gets priority")
	expect_eq(_count_calls(), 1, "two hands produce one call")
	expect(_pet.is_grounded() and _pet.act != Pet.Act.COME, "the other pet stays on the floor")
	_show_hand(LEFT, REST)
	await wait(0.8)
	expect_eq(_count_calls(), 1, "the other already-held hand leaves no pending call")
	_show_hand(RIGHT, Vector3(0.15, 0.71, -0.09))
	await wait(0.21)
	_show_hand(RIGHT, Vector3(0.15, 0.71, -0.42))
	expect(await _landed(dog), "the other hand can deliberately invite later")


func test_free_hand_can_pet_and_take_a_stone_while_supporting_hand_does_not() -> void:
	await _start()
	_pet.has_stone = true
	_show_hand(LEFT, OFFER)
	expect(await _landed(_pet), "stone carried to the palm")
	expect_eq(_pet.level, 0, "landing did not count as petting")
	var body := _pet.global_position + Vector3.UP * Pet.BODY * Pet.HAND_SIZE / Pet.SIZE
	_show_hand(RIGHT, body + Vector3.RIGHT * 0.1, PI, body)
	await frames(2)
	expect_eq(_pet.level, 1, "the free fingertip pets the animal")
	var at := _pet.stone.global_position
	# Put the support fingertips on the stone for a moment, while the palm stays put.
	_show_hand(LEFT, OFFER, 0.0, at)
	input.click(LEFT, &"trigger_click")
	expect(_pet.has_stone, "closing the support hand cannot take the stone")
	var pose := Transform3D(OPEN, at)
	for joint in [TrackedHand.INDEX, TrackedHand.THUMB]:
		_joints[RIGHT].set_hand_joint_transform(joint, pose)
	input.click(RIGHT, &"trigger_click")
	expect_eq(App.module(&"Inventory").count(&"magic_stone"), 1, "the free hand can pinch the stone up close")
	expect_eq(_pet.act, Pet.Act.ON_HAND, "taking the stone does not release the pet")


func test_shop_and_room_close_clear_offers_and_cancel_airborne_motion() -> void:
	await _start()
	_home._show(&"shop")
	_show_hand(LEFT, OFFER)
	await wait(0.6)
	_home._show(&"room")
	await wait(0.55)
	expect_eq(_count_calls(), 0, "no call in the shop or from a palm held across page changes")
	_show_hand(LEFT, REST)
	await wait(0.20)
	_show_hand(LEFT, OFFER)
	expect(await _landed(_pet), "the room is interactive again")
	_home.close()
	expect(not _pet.is_visible_in_tree() and is_zero_approx(_pet.position.y), "closing the room cancels the palm state")
	_home.open()
	_home._show(&"room")
	await wait(0.65)
	expect_eq(_count_calls(), 1, "an old invite cannot be replayed by reopening the room")
	expect(_pet.is_grounded(), "no old jump can put the animal back in the air")


func test_furniture_blocks_launch_until_the_child_offers_a_clear_spot() -> void:
	await _start()
	App.module(&"Inventory").add(&"table")
	Events.furniture_requested.emit(&"table")
	var table: Target = App.module(&"Decor").items()[0]
	table.position = Vector3(-0.15, 0.0, -0.45)
	_show_hand(LEFT, OFFER)
	await wait(0.74)
	expect_eq(_count_calls(), 0, "the automatic hop will not cross a table covering the hand's floor projection")
	table.position = Vector3(-1.6, 0.0, -0.50)
	expect(await _landed(_pet), "an unblocked approach works")
