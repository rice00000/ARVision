extends TestCase
## Hello's effects (entry/fx/hello_fx.gd): a few soft bubbles that go by themselves; a two-step cog tick.


func test_the_pop_is_a_few_bubbles_that_fade_and_go() -> void:
	await boot(null, &"intro")
	var burst := HelloFx.pop(app, Vector3(0, 0.8, -0.4), 0.04)
	expect_eq(burst.get_child_count(), PopBurst.COUNT, "a few bubbles only")
	expect(PopBurst.texture().resource_path.contains("kenney"), "Kenney's bubble texture is used")
	var peak := 0.0
	for i in 8:
		await wait(0.1)
		for bubble: MeshInstance3D in burst.get_children():
			peak = maxf(peak, ((bubble.mesh as QuadMesh).material as StandardMaterial3D).albedo_color.a)
			expect((bubble.position as Vector3).length() < 0.15, "they stay near the mouth")
	expect(peak <= 0.9, "soft (peak alpha %.2f)" % peak)
	var gone: WeakRef = weakref(burst)
	burst = null
	expect(await until(func() -> bool: return gone.get_ref() == null, 2.0), "gone after about a second")


func test_the_rattle_ticks_the_cog_twice_and_stops() -> void:
	await boot(null, &"intro")
	var cog := Node3D.new()
	app.add_child(cog)
	await HelloFx.rattle(cog, 2)
	expect(is_equal_approx(cog.rotation.y, ClockworkTick.STEP * 2.0), "two steps of 1/16 turn (%.3f rad)" % cog.rotation.y)
	await wait(0.3)
	expect(is_equal_approx(cog.rotation.y, ClockworkTick.STEP * 2.0), "then still")
