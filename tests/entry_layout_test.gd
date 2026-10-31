extends TestCase
## The zone map (entry/layout.gd): nothing the child uses overlaps, in view or on the table, for
## the tables and reaches a seated child meets; the checker really finds overlaps; the dev and
## setup panels stay out of the play; the opening puts things where the map says.


## A layout for a table [param size] whose near edge is [param edge] m from the eyes, the eyes
## [param drop] m above it, a measured [param reach] (0: not measured).
func _layout(size: Vector2, edge: float, drop: float, reach: float) -> EntryLayout:
	var layout := EntryLayout.new()
	layout.eye = Vector3(0.0, 1.2, 0.0)
	layout.table = Transform3D(Basis.IDENTITY, Vector3(0.0, 1.2 - drop, -(edge + size.y * 0.5)))
	layout.table_size = size
	layout.reach = reach
	return layout.plan()


## Big enough: at least 1.0 x 0.7 m, its near edge at least 15 cm inside the child's reach. Smaller
## or farther tables are reported (the next tests), and the setup's table step says so.
func test_nothing_overlaps_on_tables_big_enough_for_everything() -> void:
	var cases := 0
	for size: Vector2 in [Vector2(1.0, 0.7), Vector2(1.2, 0.7), Vector2(1.6, 0.9)]:
		for edge: float in [0.3, 0.4]:
			for drop: float in [0.45, 0.55]:
				for reach: float in [0.0, 0.5, 0.6, 0.72]:
					if (reach if reach > 0.0 else EntryLayout.REACH_USUAL) - edge < 0.15:
						continue   # only a strip of the table in reach: test_a_table_out_of_reach_is_reported
					var layout := _layout(size, edge, drop, reach)
					var problems := layout.report()
					expect(problems == "", "table %s, edge %d cm out, %d cm below the eyes, reach %d cm: %s" % [
							size, roundi(edge * 100), roundi(drop * 100), roundi(reach * 100), problems.replace("\n", "; ")])
					cases += 1
	expect_eq(cases, 42, "every case was tried")


func test_a_short_reach_still_reaches_the_gear_and_the_socket() -> void:
	var layout := _layout(Vector2(1.0, 0.6), 0.3, 0.5, 0.45)
	expect(layout.out_of_reach().is_empty(), "nothing the child needs is out of reach: %s" % layout.report())
	expect(layout.away(layout.socket) <= 0.47, "the socket is in reach, %d cm" % roundi(layout.away(layout.socket) * 100))


func test_the_checker_finds_overlaps_by_name_and_amount() -> void:
	var layout := EntryLayout.usual().plan()
	var a := layout.zone(&"cauldron")
	var b := layout.zone(&"gear_landing")
	b.centre = a.centre + Vector3(0.05, 0.0, 0.0)   # put the landing spot half into the cauldron
	var found := layout.overlaps().filter(func(o: Dictionary) -> bool: return o.a == &"cauldron" and o.b == &"gear_landing")
	expect_eq(found.size(), 1, "the overlap is found")
	if found.size() == 1:
		expect(found[0].how == "on the table" and found[0].amount > 0.1, "on the table, by more than 10 cm: %s" % found[0])


func test_a_table_too_small_for_everything_is_reported() -> void:
	var layout := _layout(Vector2(0.8, 0.5), 0.3, 0.48, 0.0)
	expect(layout.report() != "", "a 0.8 x 0.5 m desk has no room for the bench beside the cauldron and the panel")


func test_a_table_out_of_reach_is_reported() -> void:
	var layout := _layout(Vector2(1.2, 0.7), 0.4, 0.5, 0.5)
	expect(not layout.out_of_reach().is_empty(), "a table starting 40 cm out for a 50 cm reach: the socket is out of reach, and it says so")


func test_the_cauldron_and_panel_make_way_for_the_bench() -> void:
	var layout := EntryLayout.usual().plan()
	for name: StringName in [&"cauldron", &"panel", &"cauldron_after", &"panel_after"]:
		var z := layout.zone(name)
		if z == null:
			continue
		for other: StringName in [&"bench", &"shelf", &"things"]:
			if z.phases & layout.zone(other).phases != 0:
				expect(EntryLayout.gap(z, layout.zone(other)) >= EntryLayout.LOOKED_GAP, "%s is clear of %s when both are there" % [name, other])


func test_the_dev_and_setup_panels_never_cover_the_play() -> void:
	var layout := EntryLayout.usual().plan()
	for o in layout.overlaps():
		expect(not (String(o.a).begins_with("dev_") or String(o.b).begins_with("dev_") or o.a == &"setup_panel" or o.b == &"setup_panel"),
				"%s and %s overlap %s" % [o.a, o.b, o.how])


func test_the_marks_look_the_same_size_near_and_far() -> void:
	expect_eq(EntryLayout.mark_colours(1).size(), 2, "a fill and an outline colour")
	for distance: float in [0.35, 0.6, 0.9]:
		var tall := EntryLayout.MARK_FONT_SIZE * EntryLayout.mark_pixel_size(distance) * EntryLayout.MARK_GLYPH
		var degrees := rad_to_deg(2.0 * atan(tall * 0.5 / distance))
		expect(absf(degrees - EntryLayout.MARK_DEGREES) < 0.05, "%d degrees tall at %d cm, got %.2f" % [EntryLayout.MARK_DEGREES, roundi(distance * 100), degrees])
	var lift := EntryLayout.mark_lift(0.11, EntryLayout.mark_pixel_size(0.5))
	expect(lift > 0.055 + EntryLayout.MARK_ABOVE, "the mark floats clear above Onion")


func test_the_opening_puts_things_where_the_map_says_and_moves_them_at_the_reveal() -> void:
	Engine.time_scale = 1.0
	load("res://trials/tidy/tidy_trial.gd").push = 0.0
	await boot(null, &"intro")
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.poke_in_sim = true
	entry.run()
	expect(await until(func() -> bool: return entry.find_child("entry_part_place", true, false) != null, 20.0), "the dev jumps are there")
	# Every dev button: in reach of a seated grown-up, none on top of another.
	var buttons: Array = entry.find_children("*", "EntryButton", true, false)
	var eye := App.head().global_position
	for i in buttons.size():
		var a: EntryButton = buttons[i]
		expect(a.global_position.distance_to(eye) < 0.65, "%s is in reach (%d cm)" % [a.id, roundi(a.global_position.distance_to(eye) * 100)])
		for j in range(i + 1, buttons.size()):
			var b: EntryButton = buttons[j]
			var apart := b.global_position - a.global_position
			var across := absf(Vector2(apart.x, apart.z).length())
			var up := absf(apart.y)
			expect(across >= (a.plate.x + b.plate.x) * 0.5 - 0.001 or up >= (a.plate.y + b.plate.y) * 0.5 - 0.001, "%s and %s do not overlap" % [a.id, b.id])
	entry._on_target(entry.find_child("entry_part_place", true, false) as Target)
	expect(await until(func() -> bool: return entry.get("_layout") != null and entry.get("_part_running"), 30.0), "a jump plays a part")
	var layout: EntryLayout = entry.get("_layout")
	var box: Node3D = entry.get("_box")
	var plate: Node3D = entry.get("_mechanism")
	var flat := func(p: Vector3) -> Vector2: return Vector2(p.x, p.z)
	expect(flat.call(box.global_position).distance_to(flat.call(layout.cauldron)) < 0.01, "the cauldron stands at the map's spot")
	expect(flat.call(plate.global_position).distance_to(flat.call(layout.mechanism)) < 0.01, "and the panel")
	expect(layout.zone(&"gear_landing") != null and flat.call(entry.get("_gear_rest")).distance_to(flat.call(layout.gear_rest)) < 0.01, "the gear lands where the map says")
	entry._on_target(entry.find_child("entry_part_reveal", true, false) as Target)
	expect(await until(func() -> bool: return entry.get("_made_way"), 30.0), "the reveal makes way")
	await wait(1.5)
	expect(flat.call(box.global_position).distance_to(flat.call(layout.cauldron_after)) < 0.01, "the cauldron is at its spot for the revealed room")
	expect(flat.call(plate.global_position).distance_to(flat.call(layout.mechanism_after)) < 0.01, "and the panel")
	Engine.time_scale = 1.0
