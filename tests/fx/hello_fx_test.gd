extends TestCase
## Hello's effects (entry/fx/hello_fx.gd): a few soft bubbles that go by themselves; a two-step cog tick.


func test_the_pop_is_a_few_bubbles_that_fade_and_go() -> void:
	await boot(null, &"intro")
	var burst := HelloFx.pop(app, Vector3(0, 0.8, -0.4), 0.04)
	expect_eq(burst.get_child_count(), PopBurst.COUNT, "a few bubbles only")
	expect(PopBurst.source_path().contains("kenney"), "Kenney's bubble texture is used")
	var image := PopBurst.texture().get_image()
	var strongest := 0.0
	for x in image.get_width():
		strongest = maxf(strongest, image.get_pixel(x, image.get_height() / 2).a)
	expect(strongest > 0.8, "made bright enough to see on a light table (alpha %.2f; Kenney's own is 0.56)" % strongest)
	var peak := 0.0
	for i in 8:
		await wait(0.1)
		for bubble: MeshInstance3D in burst.get_children():
			peak = maxf(peak, ((bubble.mesh as QuadMesh).material as StandardMaterial3D).albedo_color.a)
			expect((bubble.position as Vector3).length() < 0.2, "they stay near the mouth (clear of Onion, far below the eyes)")
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


func test_the_rattle_stops_quietly_when_the_cog_goes_mid_tick() -> void:
	await boot(null, &"intro")
	var cog := Node3D.new()
	app.add_child(cog)
	HelloFx.rattle(cog, 3)
	await wait(0.2)
	cog.free()   # a scene change during the gap between ticks
	await wait(1.2)
	expect(true, "no error after the cog is gone (the runner counts script errors)")
