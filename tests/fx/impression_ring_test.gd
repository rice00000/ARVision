extends TestCase
## The hub's ring of choices above the cauldron (entry/fx/impression_ring.gd; Megan, Nov 17): still unless
## asked, steps a pressed side choice to the front, chooses only the front one, lights what the hand aims
## at, goes dark before a task. The cup has no base.

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


func test_the_front_choice_faces_the_child_full_size_and_the_ring_holds_still() -> void:
	await boot(null, &"intro")
	var ring := _ring()
	var eye := App.head().global_position
	var front := ring.front()
	expect_eq(front.kind, &"shelf", "the first choice starts in front")
	for impression in ring.impressions:
		if impression != front:
			expect(Vector2(front.global_position.x - eye.x, front.global_position.z - eye.z).length()
					< Vector2(impression.global_position.x - eye.x, impression.global_position.z - eye.z).length(),
					"the front one is nearest the child (%s)" % impression.kind)
			expect(impression.scale.x < front.scale.x, "%s sits smaller round the ring" % impression.kind)
	expect(front._halo.visible, "the front one has the waiting halo")
	var before: Array[Vector3] = []
	for impression in ring.impressions:
		before.append(impression.global_position)
	await wait(1.0)
	for i in ring.impressions.size():
		expect(ring.impressions[i].global_position.is_equal_approx(before[i]), "nothing turns by itself")


func test_pressing_a_side_choice_turns_it_to_the_front_and_only_the_front_one_is_chosen() -> void:
	await boot(null, &"intro")
	var ring := _ring()
	var cup := ring.impressions[2]
	expect_eq(ring.press(cup), &"turned", "a side choice turns, it isn't chosen")
	expect_eq(ring.press(ring.impressions[1]), &"busy", "no second turn while it turns")
	await wait(ImpressionRing.TURN_SECONDS + 0.2)
	expect(ring.front() == cup, "the cup is in front now")
	expect(cup._halo.visible and not ring.impressions[0]._halo_light.albedo_color.a > 0.3, "the halo moved with it")
	expect_eq(ring.press(cup), &"chosen", "pressing the front one chooses it")


func test_a_sealed_choice_stays_where_it_is() -> void:
	await boot(null, &"intro")
	var ring := _ring(true)
	expect_eq(ring.press(ring.impressions[1]), &"sealed", "a sealed one can't be chosen or turned to")
	await wait(0.3)
	expect(ring.front() == ring.impressions[0], "the ring didn't move")


func test_aiming_at_a_side_choice_lights_it() -> void:
	await boot(null, &"intro")
	var ring := _ring()
	var side := ring.impressions[1]
	var eye := App.head().global_position
	var at := side.target.global_position
	await frames(2)
	var dark := side._halo_light.albedo_color.a if side._halo.visible else 0.0
	input.point(&"right", eye + (at - eye).normalized() * 0.25 + Vector3.DOWN * 0.05, at)
	await frames(3)
	expect(App.rig.pointer(&"right").aimed == side.target, "the ray is on it")
	expect(side._halo.visible and side._halo_light.albedo_color.a > dark + 0.2, "aimed at, it lights up softly")
	var away := eye + Vector3(0.6, -0.3, -0.4)
	input.point(&"right", eye + (away - eye).normalized() * 0.25 + Vector3.DOWN * 0.05, away)
	await frames(3)
	expect(not side._halo.visible or side._halo_light.albedo_color.a <= dark + 0.01, "and goes back when the aim leaves")


func test_quiet_all_darkens_the_ring_before_a_task() -> void:
	await boot(null, &"intro")
	_ring()
	await frames(2)
	expect(HubGlow.any_lit(), "lit while waiting")
	await HubGlow.quiet_all(0.3)
	await frames(2)
	expect(not HubGlow.any_lit(), "dark before the task")


func test_the_cup_has_no_base() -> void:
	await boot(null, &"intro")
	var cup := Impression.make(&"turn_to_fit")
	app.add_child(cup)
	var widest := 0.0
	for mesh: MeshInstance3D in cup.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh is CylinderMesh:
			widest = maxf(widest, (mesh.mesh as CylinderMesh).bottom_radius)
	expect(widest <= 0.06, "no wide base under the cup (widest round part %.3f m)" % widest)
