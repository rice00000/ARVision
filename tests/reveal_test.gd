extends TestCase
## Scene 6, the reveal (Megan's scene review, Nov 17): table only and no shelf in the light; the cauldron
## stays (the layout keeps it clear of Wei's bench) and answers with a warm puff when the band reaches it;
## Onion says "It hasn't done that in ages!" as the puff fades; then the shelf pops out of the cauldron
## like the gear did and grows at the bench (Megan's pick, Nov 17).

var entry: Entry


func _boot() -> void:
	Engine.time_scale = 1.0
	await boot(null, &"intro")
	app.autostart = true
	entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	entry.run()
	await until(func() -> bool: return entry.tools_ready and entry.zones_available(), 20.0)


func test_the_puff_rises_about_20_cm_spreads_and_is_gone_in_about_3_s() -> void:
	await boot()
	var mouth := App.head().global_position + Vector3(0.0, -0.4, -0.5)
	var puff := CauldronPuff.play(App.stage, mouth, 0.04)
	expect(puff.get_child_count() <= 6, "a few blobs, no sparkles")
	var peak := 0.0
	var highest := 0.0
	var widest := 0.0
	for i in 25:
		await wait(0.1)
		if not is_instance_valid(puff):
			break
		peak = maxf(peak, puff.strength())
		for blob: Node3D in puff.get_children():
			highest = maxf(highest, blob.global_position.y - mouth.y)
			widest = maxf(widest, blob.scale.x)
	expect(peak <= 1.001, "soft: never past its peak (%.2f)" % peak)
	expect(highest > 0.15 and highest < 0.26, "rises about 20 cm (%.2f m)" % highest)
	expect(widest > CauldronPuff.START_SIZE * 2.0, "spreads as it rises")
	var ref: WeakRef = weakref(puff)
	puff = null
	expect(await until(func() -> bool: return ref.get_ref() == null, 1.5), "gone in about 3 s")


func test_the_cauldron_is_planned_clear_of_the_bench() -> void:
	await _boot()
	var layout: EntryLayout = entry.get("_layout")
	var bench := layout.ripple_overlaps().filter(func(o: Dictionary) -> bool: return o.b == &"bench")
	expect(bench.is_empty(), "the cauldron never stands in the bench's way, so it can stay (%s)" % [layout.ripple_overlaps()])


func test_the_reveal_keeps_the_cauldron_puffs_and_speaks_with_no_shelf() -> void:
	await _boot()
	var said := record(Events.said)
	var box: Node3D = entry.get("_box")
	var pivot := (entry.get("_shelf").shelf() as Node3D).get_parent() as Node3D
	entry.jump_to(&"reveal")
	expect(await until(func() -> bool: return entry.find_child("reveal_light_table", true, false) != null, 20.0), "the light starts")
	expect(not pivot.visible, "no shelf in the light")
	expect(await until(func() -> bool: return entry.find_child("cauldron_puff", true, false) != null, 10.0), "the cauldron puffs when the band reaches it")
	expect(box.visible and box.scale.is_equal_approx(Vector3.ONE), "the cauldron stays")
	var puff := entry.find_child("cauldron_puff", true, false)
	var ref: WeakRef = weakref(puff)
	puff = null
	expect(await until(func() -> bool: return said.any(func(a: Array) -> bool: return a[0] == Entry.REVEAL_LINE), 10.0), "Onion's line")
	expect(ref.get_ref() == null, "said as the puff has faded, not over it")
	expect(not pivot.visible, "still no shelf while Onion speaks")
	# Scene 7: the shelf no longer pops out here: the hub's ring offers it in the first visit.
	# Megan, Nov 18: a jump plays on: after the reveal, the hub. The opening's cauldron goes on into it.
	expect(await until(func() -> bool: return not is_instance_valid(entry) or String(entry.beat).begins_with("5"), 20.0), "the reveal ends")
	expect(is_instance_valid(box) and box.visible, "with the cauldron still there")
	expect(not is_instance_valid(pivot) or not pivot.visible, "and no shelf (the hub offers it)")
