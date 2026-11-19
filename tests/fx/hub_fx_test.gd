extends TestCase
## The hub's effects (entry/fx, Effects chat, Nov 17): impressions, the glow, summon and fold, the
## "found its place" signal and the dots' entrance.

const KINDS: Array[StringName] = [&"shelf", &"dots", &"turn_to_fit"]


func _impressions() -> Array[Impression]:
	var made: Array[Impression] = []
	for i in KINDS.size():
		var impression := Impression.make(KINDS[i])
		app.add_child(impression)
		impression.global_position = Vector3(-0.3 + i * 0.3, 0.75, -0.5)
		made.append(impression)
	return made


static func _box(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if not mesh.is_visible_in_tree() or mesh.mesh is QuadMesh:
			continue
		var world := mesh.global_transform * mesh.get_aabb()
		box = world if first else box.merge(world)
		first = false
	return box


func test_the_three_impressions_are_big_and_differently_shaped_and_sound_different() -> void:
	await boot(null, &"intro")
	var made := _impressions()
	await frames(2)
	var shapes := {}
	for impression in made:
		var box := _box(impression)
		expect(box.size.y >= 0.12 and maxf(box.size.x, box.size.z) >= 0.12, "%s is big (%s)" % [impression.kind, box.size])
		expect(maxf(box.size.x, box.size.z) <= 0.22, "%s fits a hub spot" % impression.kind)
		shapes[impression.kind] = snappedf(box.size.y / maxf(box.size.x, 0.01), 0.05)
	expect(shapes.values().size() == 3 and shapes[&"shelf"] != shapes[&"dots"], "their outlines differ (%s)" % shapes)
	for impression in made:
		impression.touched()
	await frames(2)
	var keys := {}
	for sounds: Sounds in app.find_children("*", "Sounds", true, false):
		for key in sounds.played:
			keys[key] = true
	expect_eq(keys.size(), 3, "three different sounds (%s)" % [keys.keys()])


func test_a_sealed_impression_is_smaller_banded_and_unlit_and_opens() -> void:
	await boot(null, &"intro")
	var made := _impressions()
	var dots := made[1]
	dots.set_sealed(true)
	var glow := HubGlow.offer(app, made, 0.1)
	await wait(0.3)
	expect(not dots._halo.visible, "sealed: no pool of light")
	expect(made[0]._halo.visible, "an open one has its pool")
	expect(dots._body.scale.x < 0.8, "sealed: smaller")
	dots.unseal(0.4)
	await wait(0.8)
	expect(not dots.sealed and is_equal_approx(dots._body.scale.x, 1.0), "opened to full size")
	expect(dots._halo.visible, "and now it glows like the others")
	glow.queue_free()


func test_the_glow_is_quiet_after_quiet_all() -> void:
	await boot(null, &"intro")
	var made := _impressions()
	HubGlow.offer(app, made, 0.2)
	HubGlow.afterglow(app, Vector3(0, 0.75, -0.4), 10.0)
	await wait(0.8)
	expect(HubGlow.any_lit(), "lit while the choices wait")
	made[0]._near = 0.0
	var before := made[0]._halo_light.albedo_color.a
	for glow: HubGlow in app.find_children("hub_glow_offer", "HubGlow", true, false):
		glow.near(made[0], 1.0)
	expect(made[0]._halo_light.albedo_color.a > before, "a near hand brightens its pool")
	await HubGlow.quiet_all(0.4)
	await frames(2)
	expect(not HubGlow.any_lit(), "nothing lit before a task starts")
	expect(app.find_children("hub_glow_*", "", true, false).is_empty(), "and the glows are gone")
	for impression in made:
		expect(not impression._halo.visible, "%s: no pool left" % impression.kind)


func test_the_afterglow_breathes_slowly_and_goes_by_itself() -> void:
	await boot(null, &"intro")
	var glow := HubGlow.afterglow(app, Vector3(0, 0.75, -0.4), 2.0)
	var alphas: Array[float] = []
	for i in 12:
		await wait(0.1)
		alphas.append(glow._pool_light.albedo_color.a)
	var steepest := 0.0
	for i in range(1, alphas.size()):
		steepest = maxf(steepest, absf(alphas[i] - alphas[i - 1]))
	expect(steepest < 0.12, "never a jump in brightness (largest step %.2f per 0.1 s)" % steepest)
	expect(alphas.max() <= 0.7, "soft (peak %.2f)" % alphas.max())
	var gone: WeakRef = weakref(glow)
	glow = null
	expect(await until(func() -> bool: return gone.get_ref() == null, 4.0), "it frees itself")


func test_summon_grows_the_activity_at_the_workspace_and_fold_brings_the_impression_back() -> void:
	await boot(null, &"intro")
	var impression := Impression.make(&"shelf")
	app.add_child(impression)
	impression.global_position = Vector3(-0.3, 0.75, -0.45)
	var activity := Node3D.new()
	var body := MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	activity.add_child(body)
	app.add_child(activity)
	activity.visible = false
	var workspace := Transform3D(Basis.IDENTITY, Vector3(0.1, 0.75, -0.6))
	await SummonFx.grow(impression, activity, workspace, 0.6)
	expect(activity.visible and activity.global_position.is_equal_approx(workspace.origin), "the activity stands at the workspace")
	expect(activity.scale.is_equal_approx(Vector3.ONE), "at its full size")
	expect(not impression.visible, "the impression has become it")
	expect(body.material_overlay == null and body.transparency == 0.0, "no line or fade left on it")
	await SummonFx.fold(activity, impression, 0.6)
	expect(not activity.visible and activity.scale.is_equal_approx(Vector3.ONE), "folded away, ready to grow again")
	expect(impression.visible and impression.global_position.is_equal_approx(Vector3(-0.3, 0.75, -0.45)), "the impression is back at its spot")
	expect(impression.scale.is_equal_approx(Vector3.ONE), "at its size")


func test_the_place_signal_is_soft_and_frees_itself() -> void:
	await boot(null, &"intro")
	var fx := PlaceSignal.play(app, Vector3(0, 0.75, -0.4))
	var material: ShaderMaterial = ((fx.get_child(0) as MeshInstance3D).mesh as PlaneMesh).material
	expect(float(material.get_shader_parameter(&"strength")) <= 0.35, "no flash")
	var gone: WeakRef = weakref(fx)
	fx = null
	expect(await until(func() -> bool: return gone.get_ref() == null, 3.0), "gone after about 1.5 s")


func test_the_dots_rise_straight_up_and_stop() -> void:
	await boot(null, &"intro")
	var cloud := MeshInstance3D.new()
	cloud.mesh = SphereMesh.new()
	app.add_child(cloud)
	var to := Transform3D(Basis.IDENTITY, Vector3(0.0, 1.0, -1.1))
	var from := DotsEntrance.start_of(to)
	expect(is_equal_approx(from.origin.x, to.origin.x) and is_equal_approx(from.origin.z, to.origin.z),
			"no sideways or toward/away travel (could hint at the answer)")
	expect(from.origin.y < to.origin.y - 0.2, "it starts below, behind the table's edge")
	var heights: Array[float] = []
	var sideways := 0.0
	DotsEntrance.rise(cloud, from, to, 0.6)
	for i in 10:
		await wait(0.08)
		heights.append(cloud.global_position.y)
		sideways = maxf(sideways, Vector2(cloud.global_position.x - to.origin.x, cloud.global_position.z - to.origin.z).length())
	expect(sideways < 0.001, "it only rises")
	var rising := true
	for i in range(1, heights.size()):
		rising = rising and heights[i] >= heights[i - 1] - 0.0001
	expect(rising, "never goes back down")
	expect(cloud.global_transform.is_equal_approx(to) and cloud.transparency == 0.0, "stopped at its spot, fully shown")
