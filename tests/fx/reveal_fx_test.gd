extends TestCase
## The reveal's light (entry/fx/reveal_fx.gd, Effects chat): the table front keeps the old timing and
## never gets bright, the room's floor and walls join only when scanned (and stay fainter, below hip
## height, with the floor under the table dark), the workshop is drawn up at full width and left
## clean, and nothing is left behind when the reveal is cut short.


func _fx(origin: Vector3) -> RevealFx:
	var fx := RevealFx.new()
	app.add_child(fx)
	fx.global_position = Vector3.ZERO
	return fx


func _materials(fx: RevealFx) -> Dictionary:
	var found := {}
	for plane: MeshInstance3D in fx.find_children("reveal_light_*", "MeshInstance3D", true, false):
		found[plane.name] = (plane.mesh as PlaneMesh).material
	return found


func test_the_table_front_keeps_the_old_timing_and_stays_soft() -> void:
	await boot(null, &"intro")
	var keep := RevealFx.room_strength
	RevealFx.room_strength = 0.0
	var table := App.reality.work_surface()
	var origin := table.transform.origin
	var radii: Array[float] = []
	var fx := _fx(origin)
	fx.play(origin, 1.5, 1.0, func(t: float, _r: float) -> void: radii.append(t))
	expect_eq(fx.planes, 1, "no room surfaces wanted: the table only")
	await wait(0.5)
	var half := fx.table_radius
	expect(absf(half - 1.5 * sin(PI * 0.25)) < 0.2, "half way in time the front is where the old ring's sine ease had it (%.2f)" % half)
	await wait(0.7)
	expect(absf(fx.table_radius - 1.5) < 0.01, "the front reaches the old reach on time")
	var steady := true
	for i in range(1, radii.size()):
		steady = steady and radii[i] >= radii[i - 1] - 0.0001
	expect(steady, "the front only ever moves outward (no pulsing)")
	var material: ShaderMaterial = _materials(fx).values()[0]
	expect(float(material.get_shader_parameter(&"strength")) <= 0.35, "the band's peak alpha is at most 0.35 (no flash)")
	RevealFx.room_strength = keep
	var gone: WeakRef = weakref(fx)
	fx = null
	expect(await until(func() -> bool: return gone.get_ref() == null, 5.0), "the light frees itself when it has faded")


func test_scanned_walls_and_floor_join_fainter_below_hip_height_and_never_under_the_table() -> void:
	await boot(null, &"intro")
	var keep := RevealFx.room_strength
	RevealFx.room_strength = 0.6   # off by default since Nov 17 (table only); the room part still works
	for wall in RevealShots.sim_walls():
		App.reality.add_surface(wall)
	var table := App.reality.work_surface()
	var origin := table.transform.origin
	var fx := _fx(origin)
	fx.play(origin, 1.5, 1.0, Callable())
	expect(fx.planes >= 5, "the table, the floor and the three walls get the light (%d)" % fx.planes)
	var found := _materials(fx)
	var table_alpha := float((found["reveal_light_table"] as ShaderMaterial).get_shader_parameter(&"strength"))
	var floor_y := App.reality.surfaces(&"floor")[0].transform.origin.y
	for key: String in found:
		var material := found[key] as ShaderMaterial
		if key == "reveal_light_table":
			continue
		expect(float(material.get_shader_parameter(&"strength")) < table_alpha, "%s is fainter than the table" % key)
		expect(float(material.get_shader_parameter(&"band")) > 0.09, "%s has a wider, softer band" % key)
		if key.begins_with("reveal_light_wall"):
			expect(absf(float(material.get_shader_parameter(&"cap_y")) - (floor_y + RevealFx.WALL_CAP)) < 0.01,
					"%s: no light above hip height" % key)
	var floor_light := found["reveal_light_floor"] as ShaderMaterial
	expect(bool(floor_light.get_shader_parameter(&"has_hole")), "the floor under the table stays dark")
	await wait(1.4)
	expect(fx.room_radius > fx.table_radius + 0.5, "the room front travels on past the table (%.2f m)" % fx.room_radius)
	expect(fx.room_radius <= RevealFx.ROOM_FAR + 0.001, "but no farther than %.1f m" % RevealFx.ROOM_FAR)
	RevealFx.room_strength = keep


func test_a_detail_is_drawn_up_at_full_width_and_left_clean() -> void:
	await boot(null, &"intro")
	var detail := Node3D.new()
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	detail.add_child(box)
	app.add_child(detail)
	var fx := _fx(Vector3.ZERO)
	fx.arrive(detail, Vector3.ONE, 0.6)
	await frames(3)
	expect(detail.scale.x == 1.0 and detail.scale.z == 1.0, "full width and depth from the first frame (it never grows from a point)")
	expect(detail.scale.y < 0.5, "it rises from its base")
	expect(box.material_overlay is ShaderMaterial, "a line of light rides it")
	await wait(1.4)
	expect(detail.scale.is_equal_approx(Vector3.ONE), "it ends at its full size")
	expect(box.material_overlay == null and box.transparency == 0.0, "the line and the fade are gone afterwards")

	# Cut short (a jump button frees the light): nothing stays half see-through or lined.
	var other := MeshInstance3D.new()
	other.mesh = BoxMesh.new()
	app.add_child(other)
	var cut := _fx(Vector3.ZERO)
	cut.arrive(other, Vector3.ONE, 1.0)
	await wait(0.2)
	cut.free()
	expect(other.material_overlay == null and other.transparency == 0.0, "cut short: left clean")


func test_the_opening_reveal_shows_no_shelf_and_leaves_no_light_behind() -> void:
	Engine.time_scale = 1.0
	await boot(null, &"intro")
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	entry.run()
	await until(func() -> bool: return entry.zones_available(), 20.0)
	entry.jump_to(&"reveal")
	expect(await until(func() -> bool: return entry.find_child("reveal_light_table", true, false) != null, 20.0),
			"the reveal draws its light on the table")
	# Scene 6/7: the light shows no shelf; the hub's ring offers it after the reveal (in the first visit).
	var details: Array = entry.get("_details")
	expect(await until(func() -> bool: return entry.find_children("reveal_light_*", "", true, false).is_empty(), 40.0),
			"the light is gone once it has faded")
	expect(await until(func() -> bool: return not bool(entry.get("_part_running")), 20.0), "the reveal part ends")
	expect(details.all(func(d: Node3D) -> bool: return not d.visible), "no part of the shelf or its shapes is shown by the reveal")


func test_by_default_the_reveal_is_table_only_even_with_a_room_scan() -> void:
	await boot(null, &"intro")
	for wall in RevealShots.sim_walls():
		App.reality.add_surface(wall)
	expect_eq(RevealFx.room_strength, 0.0, "table only by default (Megan, Nov 17)")
	var table := App.reality.work_surface()
	var fx := _fx(table.transform.origin)
	fx.play(table.transform.origin, 1.5, 1.0, Callable())
	expect_eq(fx.planes, 1, "the light is on the table only")


func test_with_shows_workshop_off_the_reveal_shows_no_shelf_and_ends_on_the_gear_afterglow() -> void:
	Engine.time_scale = 1.0
	await boot(null, &"intro")
	var keep := RevealFx.shows_workshop
	RevealFx.shows_workshop = false
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	entry.run()
	await until(func() -> bool: return entry.zones_available(), 20.0)
	entry.jump_to(&"reveal")
	expect(await until(func() -> bool: return entry.find_child("hub_glow_afterglow", true, false) != null, 25.0),
			"the gear's afterglow (glow A) comes as the light ends")
	var details: Array = entry.get("_details")
	expect(details.all(func(d: Node3D) -> bool: return not d.visible), "Wei's shelf and the things stay hidden")
	expect(await until(func() -> bool: return not HubGlow.any_lit(), 8.0), "the afterglow goes by itself")
	RevealFx.shows_workshop = keep


func test_light_specks_lift_off_the_table_behind_the_front_and_settle_out() -> void:
	await boot(null, &"intro")
	var table := App.reality.work_surface()
	var origin := table.transform.origin
	var fx := _fx(origin)
	fx.play(origin, 1.5, 1.5, Callable())
	await wait(0.8)
	expect(fx.get_node_or_null(^"motes") is MultiMeshInstance3D, "the specks are one multimesh (cheap)")
	var motes: Array[Vector3] = fx.get("_mote_at")
	expect(motes.size() > 10, "specks lift off as the light spreads (%d)" % motes.size())
	var inverse := table.transform.affine_inverse()
	for i in motes.size():
		var local := inverse * motes[i]
		expect(absf(local.x) <= table.size.x * 0.5 + 0.02 and absf(local.z) <= table.size.y * 0.5 + 0.02, "only over the table, none in mid-air (%d)" % i)
		expect(local.y >= 0.0 and local.y < 0.2, "low over it, rising (%d)" % i)
	await wait(0.7 + RevealFx.SPECK_LIFE + 0.2)
	if is_instance_valid(fx):
		expect_eq((fx.get("_mote_at") as Array).size(), 0, "once the front stops, the last specks fade out")
	RevealFx.specks = false
	var plain := _fx(origin)
	plain.play(origin, 1.5, 1.0, Callable())
	expect(plain.get_node_or_null(^"motes") == null, "RevealFx.specks = false turns them off")
	RevealFx.specks = true
