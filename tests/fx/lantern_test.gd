extends TestCase
## The workshop's lanterns (entry/fx/lantern.gd) and the fireplace ambience (entry/hub/hub_ambience.gd),
## Megan, Nov 18: one lantern behind and above the cauldron, a few on the scanned walls (never in front,
## never near the ring), a gentle glow that holds steady during a game, the quiet crackle under the hub.


func _walls(eye: Vector3) -> void:
	# A room 4.6 m wide around the child: a wall ahead and one on each side (as a scan gives them).
	for wall: Array in [[Vector3(0, 0, -2.4), Vector3(0, 0, 1)], [Vector3(-2.3, 0, -0.8), Vector3(1, 0, 0)], [Vector3(2.3, 0, -0.8), Vector3(-1, 0, 0)]]:
		var normal: Vector3 = wall[1]
		var along := normal.cross(Vector3.UP).normalized()
		var basis := Basis(along, normal, along.cross(normal))
		App.reality.add_surface(Surface.new(&"wall_face", Transform3D(basis, eye + (wall[0] as Vector3) + Vector3(0, 0.1, 0)), Vector2(4.6, 2.4)))


func _flat_angle(eye: Vector3, a: Vector3, b: Vector3) -> float:
	return rad_to_deg(Vector3(a.x - eye.x, 0, a.z - eye.z).angle_to(Vector3(b.x - eye.x, 0, b.z - eye.z)))


func test_without_scanned_walls_only_the_cauldrons_lantern_hangs_clear_of_the_ring() -> void:
	await boot(null, &"intro")
	var eye := App.head().global_position
	var mouth := eye + Vector3(-0.45, -0.4, -0.5)
	var middle := eye + Vector3(0, -0.45, -0.6)
	var hung := Lantern.hang(app, mouth, eye, middle)
	expect_eq(hung.size(), 1, "no walls in the scan: one lantern")
	var glass := hung[0].global_position + Lantern.GLASS
	expect(glass.y > mouth.y + ImpressionRing.ABOVE_RIM + 0.3, "it hangs above the ring")
	expect(Vector2(glass.x - eye.x, glass.z - eye.z).length() > Vector2(mouth.x - eye.x, mouth.z - eye.z).length(), "behind the cauldron")
	expect((glass - mouth).dot(mouth - middle) > 0.0, "on the cauldron's outer side, away from the table's middle")
	expect(hung[0].light != null, "the cauldron's lantern has the one warm light")
	expect_eq(hung[0].light.shadow_enabled, false, "no shadows (Quest)")
	expect_eq(hung[0].light.light_cull_mask & Lantern.OWN_LAYER, 0, "its light skips its own iron")


func test_wall_lanterns_stay_out_of_the_front_and_away_from_the_ring_at_different_heights() -> void:
	await boot(null, &"intro")
	var eye := App.head().global_position
	_walls(eye)
	var mouth := eye + Vector3(-0.45, -0.4, -0.5)
	var middle := eye + Vector3(0, -0.45, -0.6)
	var hung := Lantern.hang(app, mouth, eye, middle)
	expect(hung.size() >= 2, "lanterns line the walls (%d)" % hung.size())
	expect(hung.size() <= 1 + Lantern.WALL_MAX, "but only a few")
	var heights := {}
	for i in range(1, hung.size()):
		var glass := hung[i].global_position + Lantern.GLASS
		expect(_flat_angle(eye, glass, middle) >= Lantern.WALL_BEARING.x - 0.5, "never in front, even with a wall there (%d)" % i)
		expect(rad_to_deg((mouth - eye).angle_to(glass - eye)) >= Lantern.CLEAR_OF_RING_DEG, "never near the ring (%d)" % i)
		expect(hung[i].light == null, "wall lanterns glow without a dynamic light (%d)" % i)
		heights[snappedf(glass.y, 0.01)] = true
		for j in i:
			var other := hung[j].global_position + Lantern.GLASS
			expect(rad_to_deg((glass - eye).angle_to(other - eye)) >= Lantern.APART_DEG, "lanterns %d and %d are well apart in the view" % [j, i])
	expect_eq(heights.size(), hung.size() - 1, "each wall lantern at its own height")


func test_the_glow_breathes_gently_in_the_hub_and_holds_steady_during_a_game() -> void:
	await boot(null, &"intro")
	var lantern := Lantern.make(app, App.head().global_position + Vector3(0, 0.3, -1.0))
	Lantern.quiet = false
	var levels: Array[float] = []
	for i in 40:
		await wait(0.1)
		levels.append(lantern._glass.emission_energy_multiplier)
	var low: float = levels.min()
	var high: float = levels.max()
	expect(high - low > 0.01, "it breathes")
	expect(high <= Lantern.GLOW_ENERGY * (1.0 + Lantern.FLICKER) + 0.001 and low >= Lantern.GLOW_ENERGY * (1.0 - Lantern.FLICKER) - 0.001, "never more than ±10 %")
	for i in range(1, levels.size()):
		expect(absf(levels[i] - levels[i - 1]) < Lantern.GLOW_ENERGY * 0.05, "no sudden step (%d)" % i)
	lantern._next_ember = 0.05
	await wait(0.3)
	expect(lantern.find_child("ember", false, false) != null, "an ember rises now and then")
	Lantern.quiet = true
	await wait(1.6)
	var steady := lantern._glass.emission_energy_multiplier
	lantern._next_ember = 0.05
	await wait(1.0)
	expect(absf(lantern._glass.emission_energy_multiplier - steady) < 0.001, "during a game the glow holds steady")
	expect(is_equal_approx(steady, Lantern.GLOW_ENERGY), "at its normal level")
	await wait(3.0)
	expect(lantern.find_child("ember", false, false) == null, "and no embers rise")
	Lantern.quiet = false


func test_with_the_light_switch_off_there_is_no_dynamic_light_but_the_glass_still_glows() -> void:
	await boot(null, &"intro")
	Lantern.lights_on = false
	var lantern := Lantern.make(app, App.head().global_position + Vector3(0, 0.3, -1.0), true)
	Lantern.lights_on = true
	expect(lantern.light == null, "no OmniLight3D")
	expect(lantern._glass.emission_enabled and lantern._glass.emission_energy_multiplier > 1.0, "the glass glows anyway")
	expect(lantern.find_child("halo", false, false) != null, "and the soft halo is there")


func test_the_fireplace_fades_in_under_the_hub_lower_in_a_game_and_out_without_a_jump() -> void:
	await boot(null, &"intro")
	var ambience := HubAmbience.make(app)
	expect(ambience.stream != null and (ambience.stream as AudioStreamOggVorbis).loop, "a looping file")
	ambience.hub()
	expect(ambience.playing, "it starts")
	await wait(1.0)
	expect(ambience.volume_db < HubAmbience.HUB_DB - 3.0, "still fading in after 1 s (no sudden start)")
	await wait(HubAmbience.FADE_IN)
	expect(absf(ambience.volume_db - HubAmbience.HUB_DB) < 0.5, "settles at %s dB" % HubAmbience.HUB_DB)
	ambience.game()
	await wait(HubAmbience.FADE + 0.2)
	expect(absf(ambience.volume_db - HubAmbience.GAME_DB) < 0.5, "a little lower during a game")
	ambience.fade_out()
	await wait(HubAmbience.FADE + 0.3)
	expect(not ambience.playing, "faded out and stopped")


func test_the_roof_beams_hang_small_dim_lanterns_high_out_of_the_working_view() -> void:
	await boot(null, &"intro")
	var eye := App.head().global_position
	_walls(eye)
	var middle := eye + Vector3(0, -0.45, -0.6)
	var hung := Lantern.hang_high(app, eye, middle)
	expect(hung.size() >= 4, "a few lanterns round the room (%d)" % hung.size())
	var top := Lantern._ceiling(eye)
	for lantern in hung:
		var glass := lantern.global_position + lantern.glass_offset()
		var flat := Vector3(glass.x - eye.x, 0, glass.z - eye.z)
		var up := rad_to_deg(atan2(glass.y - eye.y, flat.length()))
		expect(up > 12.0, "high: above the level gaze, ~40° above the table where the child works (%.0f°)" % up)
		expect(glass.y < top, "under the ceiling")
		expect(_flat_angle(eye, glass, middle) > 25.0, "none straight ahead")
		expect(not lantern.embers, "no embers")
		expect(lantern.light != null and not lantern.light.shadow_enabled and lantern.light.omni_range <= Lantern.HIGH_LIGHT_RANGE, "a small flickering light, no shadows")
		expect(lantern.find_child("specks", false, false) is CPUParticles3D, "light specks round it")
		expect(lantern.size < Lantern.SCALE and lantern.glow < 1.0, "smaller and dimmer")
	var rafters := app.get_node(^"Rafters")
	expect(rafters.get_child_count() == Lantern.BEAM_ROWS.size(), "the beams")
	for beam: MeshInstance3D in rafters.get_children():
		var half := (beam.mesh as BoxMesh).size.x * 0.5
		var ends: Array[Vector3] = [beam.global_transform * Vector3(-half, 0, 0), beam.global_transform * Vector3(half, 0, 0)]
		for end in ends:
			expect(absf(end.x - eye.x) < 2.3 and end.z - eye.z > -2.4, "a beam stops at the walls")


func test_the_specks_stay_on_during_a_game_and_the_lights_switch_off_for_the_quest() -> void:
	await boot(null, &"intro")
	var eye := App.head().global_position
	Lantern.quiet = false
	var hung := Lantern.hang_high(app, eye, eye + Vector3(0, -0.45, -0.6))
	var specks := hung[0].find_child("specks", false, false) as CPUParticles3D
	await wait(0.2)
	expect(specks.emitting, "specks drift in the hub")
	Lantern.quiet = true
	await wait(0.2)
	expect(specks.emitting, "the specks stay on during a game too (Megan, Nov 18)")
	Lantern.quiet = false
	Lantern.lights_on = false
	var dark := Lantern.hang_high(app, eye, eye + Vector3(0, -0.45, -0.6))
	Lantern.lights_on = true
	for lantern in dark:
		expect(lantern.light == null, "lights off: no dynamic light")
		expect(lantern.find_child("halo", false, false) != null, "the solid ring still shows")
