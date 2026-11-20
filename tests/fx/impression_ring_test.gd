extends TestCase
## The hub's bubble menu over the cauldron (entry/fx/impression_ring.gd; Megan, Nov 18): a still arc of
## bubbles (a carousel with peeking ends past five), one press picks any and it pops, sealed ones stay closed,
## a new one rises in, lights what the hand aims at, goes dark before a game; the door row below; rests
## after a while with no hand near and wakes when one comes; sinks and rises. The cup has no base.

const KINDS: Array[StringName] = [&"shelf", &"dots", &"turn_to_fit"]


func _ring(sealed_dots := false) -> ImpressionRing:
	var made: Array[Impression] = []
	for kind in KINDS:
		made.append(Impression.make(kind))
	var eye := App.head().global_position
	var middle := eye + Vector3(-0.3, -0.35, -0.55)
	var ring := ImpressionRing.make(app, made, middle, eye)
	if sealed_dots:
		made[1].set_sealed(true)
	return ring


## The hands away from the bubbles (a hand near one swells it: the hover cue, Megan Nov 18 5:29).
func _hands_away(ring: ImpressionRing) -> void:
	input.point(&"right", ring.global_position + Vector3(0.8, 0.0, 0.0), ring.global_position + Vector3(1.6, 0, 0))
	input.point(&"left", ring.global_position + Vector3(-0.8, 0.0, 0.0), ring.global_position + Vector3(-1.6, 0, 0))
	await frames(2)


func test_the_choices_stand_still_in_bubbles_on_an_arc_the_middle_one_biggest() -> void:
	await boot(null, &"intro")
	var ring := _ring()
	await _hands_away(ring)
	var eye := App.head().global_position
	var front := ring.front()
	expect_eq(front.kind, &"dots", "the middle choice is the front one")
	for impression in ring.impressions:
		expect(impression.bubble != null and impression.bubble.visible, "%s is in its bubble" % impression.kind)
		# Round the child like the places row (Megan, Nov 18 4:32): the ends no further and no lower than the middle.
		var to_eyes := Vector2(impression.bubble.global_position.x - eye.x, impression.bubble.global_position.z - eye.z).length()
		var front_to_eyes := Vector2(front.bubble.global_position.x - eye.x, front.bubble.global_position.z - eye.z).length()
		expect(absf(to_eyes - front_to_eyes) < 0.005, "%s is as far from the eyes as the middle one (%.3f, %.3f)" % [impression.kind, to_eyes, front_to_eyes])
		expect(absf(impression.bubble.global_position.y - front.bubble.global_position.y) < 0.03, "%s is at the middle one's height" % impression.kind)
		if impression != front:
			expect(is_equal_approx(impression.scale.x, ImpressionRing.SIDE_SCALE), "%s sits a little smaller" % impression.kind)
			expect(impression.scale.x / front.scale.x >= 0.6, "%s is at least 60 %% of the middle one" % impression.kind)
			var gap := (impression.global_position - front.global_position).length()
			var room := Impression.BUBBLE_RADIUS * (impression.scale.x + front.scale.x)
			expect(gap > room, "%s's bubble doesn't touch the middle one (%.3f > %.3f)" % [impression.kind, gap, room])
	expect(front._halo.visible, "the middle one has the waiting halo")
	var before: Array[Vector3] = []
	for impression in ring.impressions:
		before.append(impression.global_position)
	await wait(1.0)
	for i in ring.impressions.size():
		expect(ring.impressions[i].global_position.is_equal_approx(before[i]), "nothing moves by itself")


func test_one_press_picks_any_bubble_at_once_and_it_pops() -> void:
	await boot(null, &"intro")
	var ring := _ring()
	await _hands_away(ring)
	var cup := ring.impressions[2]
	var where := cup.global_position
	var picked := record(ring.chosen)
	expect_eq(ring.press(cup), &"chosen", "one press picks a side one")
	expect(not ring.turning, "nothing slides (a still arc)")
	await frames(3)
	expect(cup.find_child("pop_drops", true, false) != null, "its bubble bursts into droplets")
	var title := app.find_child("chosen_title", true, false) as ChosenTitle
	expect(title != null and title.text == "Turn to Fit", "its name appears over it")
	expect(title != null and title.global_position.y > cup.bubble.global_position.y, "above the bubble")
	await wait(0.9)
	expect(cup.global_position.is_equal_approx(where), "it stayed where it was")
	expect_eq(picked.size(), 1, "chosen, once")
	expect(not cup.bubble.visible, "its bubble popped")
	await wait(ChosenTitle.IN_SECONDS + ChosenTitle.HOLD_SECONDS + ChosenTitle.OUT_SECONDS)
	expect(app.find_child("chosen_title", true, false) == null, "the name goes after a moment")


func test_past_five_the_arc_becomes_a_carousel_whose_ends_peek_out() -> void:
	await boot(null, &"intro")
	var made: Array[Impression] = []
	for i in 7:
		made.append(Impression.make(KINDS[i % 3]))
	var eye := App.head().global_position
	var ring := ImpressionRing.make(app, made, eye + Vector3(-0.3, -0.35, -0.55), eye)
	var shown := made.filter(func(i: Impression) -> bool: return i.visible)
	expect_eq(shown.size(), 5, "five in view, the rest wait")
	var far := made.filter(func(i: Impression) -> bool: return i.visible and i.scale.x < ImpressionRing.SIDE_SCALE - 0.01)
	expect_eq(far.size(), 2, "the two at the ends are smaller: there's more")
	var side := made[1]
	ring.press(side)
	expect(ring.turning, "a press on a side one slides it in first")
	await wait(ImpressionRing.TURN_SECONDS * 1.5 + 0.6)
	expect(ring.front() == side, "then it is in front")


func test_a_sealed_choice_says_soon_and_stays_closed() -> void:
	await boot(null, &"intro")
	var ring := _ring(true)
	var dots := ring.impressions[1]
	expect_eq(ring.press(dots), &"sealed", "a sealed one can't be chosen")
	expect(dots.bubble.visible, "its bubble stays closed")
	var lock := dots.find_child("lock", true, false) as Node3D
	expect(lock != null and lock.visible, "a padlock badge says it's not open yet")
	dots.unseal()
	await wait(1.6)
	expect(not lock.visible, "the lock opened and dropped away")
	expect_eq(ring.press(dots), &"chosen", "once opened it can be chosen")


func test_aiming_at_a_side_choice_lights_it() -> void:
	await boot(null, &"intro")
	var ring := _ring()
	var side := ring.impressions[1]
	var eye := App.head().global_position
	var at := side.target.global_position
	var far := eye + Vector3(0.6, -0.3, -0.4)
	input.point(&"right", eye + (far - eye).normalized() * 0.25 + Vector3.DOWN * 0.05, far)
	input.point(&"left", eye + Vector3(-0.3, -0.5, 0.1), eye + Vector3(-0.6, -0.8, 0.2))
	await frames(3)
	var dark := side._halo_light.albedo_color.a if side._halo.visible else 0.0
	input.point(&"right", eye + (at - eye).normalized() * 0.25 + Vector3.DOWN * 0.05, at)
	await frames(3)
	expect(App.rig.pointer(&"right").aimed == side.target, "the ray is on it")
	expect(side._halo.visible and side._halo_light.albedo_color.a > dark + 0.2, "aimed at, it lights up softly")
	var away := eye + Vector3(0.6, -0.3, -0.4)
	input.point(&"right", eye + (away - eye).normalized() * 0.25 + Vector3.DOWN * 0.05, away)
	await frames(3)
	expect(not side._halo.visible or side._halo_light.albedo_color.a <= dark + 0.01, "and goes back when the aim leaves")


func test_quiet_all_darkens_the_bubbles_before_a_task() -> void:
	await boot(null, &"intro")
	_ring()
	await frames(2)
	expect(HubGlow.any_lit(), "lit while waiting")
	await HubGlow.quiet_all(0.3)
	await frames(2)
	expect(not HubGlow.any_lit(), "dark before the task")


func test_only_the_focused_bubble_is_announced_when_another_is_near() -> void:
	await boot(null, &"intro")
	var ring := _ring()
	await _hands_away(ring)
	var nearby := ring.impressions[0]
	var aimed_at := ring.impressions[2]
	var announced := record(ring.hovered)
	var from := nearby.target.global_position + Vector3.BACK * 0.07
	input.point(&"left", from, from + Vector3.BACK)
	var at := aimed_at.target.global_position
	input.point(&"right", at + aimed_at.global_basis.z * 0.4, at)
	await frames(4)
	expect_eq(ring.lit, aimed_at, "a ray hit outranks the other hand's proximity")
	expect(not nearby._outer_glow.visible, "only the aimed-at bubble glows")
	expect_eq(announced, [[aimed_at]], "only the glowing bubble is announced")
	input.track(&"right", false)
	await frames(4)
	expect_eq(ring.lit, nearby, "nearby takes focus after the ray is gone")
	expect_eq(announced, [[aimed_at], [nearby]], "the new focus is announced once")
	input.track(&"left", false)
	await frames(4)
	expect(ring.lit == null, "a lost hand pose cannot keep a bubble focused")


func test_the_cup_has_no_base() -> void:
	await boot(null, &"intro")
	var cup := Impression.make(&"turn_to_fit")
	app.add_child(cup)
	var widest := 0.0
	for mesh: MeshInstance3D in cup.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh is CylinderMesh:
			widest = maxf(widest, (mesh.mesh as CylinderMesh).bottom_radius)
	expect(widest <= 0.06, "no wide base under the cup (widest round part %.3f m)" % widest)


func test_a_new_choice_rises_into_the_arc_and_the_others_make_room() -> void:
	await boot(null, &"intro")
	var shelf := Impression.make(&"shelf")
	var eye := App.head().global_position
	var middle := eye + Vector3(-0.3, -0.35, -0.55)
	var ring := ImpressionRing.make(app, [shelf] as Array[Impression], middle, eye)
	var dots := Impression.make(&"dots")
	ring.add(dots, middle + Vector3.DOWN * 0.15)
	expect_eq(ring.press(shelf), &"busy", "nothing is chosen while it rises")
	await wait(ImpressionRing.RISE_SECONDS + 0.2)
	expect(dots.bubble != null and dots.visible, "the new one is in its bubble, in the arc")
	expect((dots.global_position - shelf.global_position).length() > 0.1, "beside the shelf, apart")


func test_the_door_sits_below_the_tasks_and_a_press_chooses_it_at_once() -> void:
	await boot(null, &"intro")
	var ring := _ring()
	var door := Impression.make(&"house")
	ring.set_door(door)
	var eye := App.head().global_position
	var front := ring.front()
	expect(door.global_position.y < front.global_position.y - 0.05, "below the tasks")
	var flat := func(p: Vector3) -> float: return Vector2(p.x - eye.x, p.z - eye.z).length()
	expect(flat.call(door.global_position) > flat.call(front.global_position) + 0.04, "and set back behind the games, out of a resting hand's way")
	expect(ring.impression_for(door.target) == door, "its target is known")
	var picked := record(ring.chosen)
	expect_eq(ring.press(door), &"chosen", "one press")
	expect(not ring.turning, "the carousel doesn't move for it")
	await wait(0.9)
	expect(picked.size() == 1 and picked[0][0] == door, "the door is chosen")


func test_it_rests_with_no_hand_near_and_wakes_when_one_comes() -> void:
	await boot(null, &"intro")
	var ring := _ring()
	var front := ring.front()
	input.point(&"right", ring.global_position + Vector3(0.8, 0.0, 0.0), ring.global_position + Vector3(1.6, 0, 0))
	input.point(&"left", ring.global_position + Vector3(-0.8, 0.0, 0.0), ring.global_position + Vector3(-1.6, 0, 0))
	await frames(2)
	var full := front.scale.x
	Engine.time_scale = 8.0
	await wait(ImpressionRing.REST_AFTER + ImpressionRing.REST_SECONDS + 1.0)
	Engine.time_scale = 1.0
	expect(is_equal_approx(ring.rest, 1.0), "it rested (%.2f)" % ring.rest)
	expect(is_equal_approx(front.scale.x, full * ImpressionRing.REST_SCALE), "the pieces shrank in place")
	input.point(&"right", ring.global_position + Vector3(0.1, -0.05, 0.1), ring.global_position)
	await wait(ImpressionRing.WAKE_SECONDS + 0.3)
	expect(ring.rest < 0.01, "a hand coming near wakes it")
	expect(is_equal_approx(front.base_size, full), "full size again (before the hand's hover swell)")
	expect(front.scale.x > full and front.scale.x <= full * (1.0 + Impression.HOVER_SWELL) + 0.001, "the hand near it swells it a little")


func test_a_hand_near_a_bubble_glows_its_rim_and_swells_it_and_it_settles_after() -> void:
	await boot(null, &"intro")
	var ring := _ring()
	await _hands_away(ring)
	var shelf := ring.impressions[0]
	var size := shelf.scale.x
	var middle := shelf.bubble.global_position
	expect(not shelf._outer_glow.visible, "no glow with no hand near")
	input.point(&"right", shelf.bubble.global_position + Vector3(0.0, 0.0, 0.05), shelf.bubble.global_position)
	await wait(0.4)
	expect(shelf._outer_glow.visible, "a warm glow round the outside")
	expect(shelf._rim_light.albedo_color.is_equal_approx(Impression.HOVER_GOLD), "its rim turns gold")
	expect(is_equal_approx(shelf.scale.x, size * (1.0 + Impression.HOVER_SWELL)), "it swells 8 %% (%.3f)" % (shelf.scale.x / size))
	expect(shelf.bubble.global_position.distance_to(middle) < 0.002, "round its middle: it doesn't jump")
	expect(not ring.impressions[1]._outer_glow.visible and is_equal_approx(ring.impressions[1].scale.x, ring.impressions[1].base_size), "the others don't")
	await _hands_away(ring)
	await wait(0.4)
	expect(not shelf._outer_glow.visible and is_equal_approx(shelf.scale.x, size), "it settles when the hand goes")


func test_resting_pieces_can_still_be_pressed() -> void:
	await boot(null, &"intro")
	var ring := _ring()
	ring.rest = 1.0
	var picked := record(ring.chosen)
	expect_eq(ring.press(ring.front()), &"chosen", "a resting piece can be pressed")
	await wait(1.0)
	expect_eq(picked.size(), 1, "and chosen")


func test_it_sinks_away_and_rises_back_with_its_pieces() -> void:
	await boot(null, &"intro")
	var ring := _ring()
	var mouth := ring.global_position + Vector3.DOWN * 0.2
	var front := ring.front()
	var at := front.global_position
	await ring.sink(mouth, 0.3)
	expect(not ring.visible and not ring.opened, "closed after sinking")
	expect_eq(ring.press(front), &"busy", "nothing to press while closed")
	await ring.rise(mouth, 0.3)
	expect(ring.visible and ring.opened, "open again")
	expect(front.global_position.is_equal_approx(at), "the front piece is back in its place")


func test_the_games_read_left_to_right_as_the_child_sees_them() -> void:
	await boot(null, &"intro")
	var ring := _ring()
	var eye := App.head().global_position
	var basis := App.head().global_basis
	var right := basis.x
	var xs: Array = ring.impressions.map(func(i: Impression) -> float: return (i.global_position - eye).dot(right))
	expect(xs[0] < xs[1] and xs[1] < xs[2], "the first game is on the left (%s)" % [xs])
