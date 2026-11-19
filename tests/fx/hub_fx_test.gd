extends TestCase
## Impressions, the gear afterglow and the "found its place" signal.

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


func test_the_place_signal_is_soft_and_frees_itself() -> void:
	await boot(null, &"intro")
	var fx := PlaceSignal.play(app, Vector3(0, 0.75, -0.4))
	var material: ShaderMaterial = ((fx.get_child(0) as MeshInstance3D).mesh as PlaneMesh).material
	expect(float(material.get_shader_parameter(&"strength")) <= 0.35, "no flash")
	var gone: WeakRef = weakref(fx)
	fx = null
	expect(await until(func() -> bool: return gone.get_ref() == null, 3.0), "gone after about 1.5 s")
