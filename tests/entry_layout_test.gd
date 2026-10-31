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
	expect(layout.away(layout.socket) <= layout.reach_used() + 0.02 + EntryLayout.socket_stretch, "the socket is in reach, %d cm" % roundi(layout.away(layout.socket) * 100))


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
	var layout := _layout(Vector2(0.6, 0.4), 0.3, 0.48, 0.0)
	expect(layout.report() != "", "a 0.6 x 0.4 m desk has no room for the bench beside the cauldron and the socket")


func test_onion_stays_clear_of_the_teaching_hand_the_socket_the_panel_and_the_landing_spot() -> void:
	var layout := _layout(Vector2(1.2, 0.7), 0.3, 0.5, 0.0)
	for name: StringName in [&"onion_mouth", &"onion_aside", &"onion_lifted", &"onion_lifted_after", &"hand_tap", &"hand_pinch", &"hand_place", &"socket"]:
		expect(layout.zone(name) != null, "the zone map has %s" % name)
	expect(layout.report() == "", "and nothing overlaps: %s" % layout.report())
	var body := layout._circle(&"b", layout.onion_mouth, EntryLayout.ONION_BODY, 0.0)
	expect(EntryLayout.gap(body, layout.zone(&"hand_tap")) >= EntryLayout.HAND_CLEAR - 0.001, "Onion beside the mouth is a hand-breadth clear of the tap")
	expect(absf(layout.onion_mouth_offset.length() - EntryLayout.BESIDE_MOUTH) < 0.025, "at about BESIDE_MOUTH from the mouth (Megan moved Onion further out: 13 cm)")


func test_the_checker_catches_onion_on_the_hands_path() -> void:
	var layout := _layout(Vector2(1.2, 0.7), 0.3, 0.5, 0.0)
	var onion := layout.zone(&"onion_mouth")
	var hand := layout.zone(&"hand_tap")
	onion.centre = Vector3(hand.centre.x, onion.centre.y, hand.centre.z)   # Onion in the middle of the hand's sweep
	expect(not layout.overlaps().filter(func(o: Dictionary) -> bool: return o.a == &"hand_tap" and o.b == &"onion_mouth").is_empty(), "Onion on the tap hand's sweep is reported")
	var aside := layout.zone(&"onion_aside")
	var landing := layout.zone(&"gear_landing")
	aside.centre = Vector3(landing.centre.x, landing.centre.y, landing.centre.z)   # and down at the gear's height
	expect(not layout.overlaps().filter(func(o: Dictionary) -> bool: return o.b == &"onion_aside" or o.a == &"onion_aside").is_empty(), "and Onion on the gear's landing spot")


func test_the_panel_stays_put_where_the_table_allows_and_glides_where_it_does_not() -> void:
	var roomy := _layout(Vector2(1.2, 0.7), 0.3, 0.45, 0.72)   # a long reach: a fixed spot exists (the shelf turns 30 degrees)
	expect(roomy.panel_fixed, "on a long reach the panel has a fixed spot")
	expect(not roomy.mechanism_moves() and not roomy.cauldron_moves(), "so neither the panel nor the cauldron moves at the reveal")
	expect(roomy.onion_lifted.distance_to(roomy.onion_lifted_after) < 0.001, "and Onion has nothing to follow")
	var tight := _layout(Vector2(1.2, 0.7), 0.3, 0.45, 0.6)   # Wei's bench leaves no room: the panel glides
	expect(tight.panel_fixed != tight.mechanism_moves() or not tight.panel_fixed, "where the socket has no fixed spot the layout says so, and the socket then rides a track (or already stands clear)")
	expect(tight.report() == "", "and is clean both ways: %s" % tight.report())
	expect(not tight.cauldron_moves() and not roomy.cauldron_moves(), "the cauldron never moves: it sinks away where it stands")


func test_the_zones_are_real_volumes_not_footprints() -> void:
	var layout := EntryLayout.usual().plan()
	var onion := layout.zone(&"onion_aside")
	var landing := layout.zone(&"gear_landing")
	onion.centre = Vector3(landing.centre.x, landing.centre.y + 0.25, landing.centre.z)   # Onion hovering a hand's height above the gear
	expect(layout.overlaps().filter(func(o: Dictionary) -> bool: return o.a == &"onion_aside" or o.b == &"onion_aside").is_empty(),
			"Onion high above the landing spot is not an overlap (the volumes are apart)")
	expect(not layout.overlaps_flat().filter(func(o: Dictionary) -> bool: return o.a == &"onion_aside" or o.b == &"onion_aside").is_empty(),
			"but the flat fallback, which ignores heights, reports it")
	onion.centre.y = landing.centre.y
	expect(not layout.overlaps().filter(func(o: Dictionary) -> bool: return o.a == &"onion_aside" or o.b == &"onion_aside").is_empty(), "down at the gear's height it is")
	var arc := layout.zone(&"gear_arc")
	expect(arc != null and arc.shape == &"path" and arc.path.size() >= 10, "the gear's flight is a swept volume")
	expect(arc.path[0].y > layout.cauldron.y + layout.rim, "that starts over the rim")
	var panel := layout.zone(&"panel")
	arc.path[5] = Vector3(panel.centre.x, panel.centre.y + 0.03, panel.centre.z)   # a gear dropped through the panel
	expect(not layout.overlaps().filter(func(o: Dictionary) -> bool: return o.a == &"gear_arc" or o.b == &"gear_arc").is_empty(), "the flight through the panel is found")


func test_onion_stands_beside_the_socket_for_the_set_in() -> void:
	var layout := EntryLayout.usual().plan()
	var near := Vector2(layout.onion_socket.x - layout.socket.x, layout.onion_socket.z - layout.socket.z).length()
	expect(near >= 0.11 and near <= 0.28, "Onion is %d cm from the socket (beside it, not across the table)" % roundi(near * 100.0))
	expect(layout.onion_socket.y > layout.table_y() + 0.09, "floating a little above the table")
	expect(layout.zone(&"onion_socket") != null and layout.report() == "", "and clear of everything: %s" % layout.report())
	expect(layout.onion_lifted.distance_to(layout.onion_socket) > 0.09, "then it rises from there")


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
	expect(await until(func() -> bool: return entry.find_child("entry_part_all", true, false) != null, 30.0), "the opening is set up (the layout is planned on a worker thread: wait for 'All set')")
	expect(entry.find_child("entry_part_place", true, false) != null, "the dev jumps are there")
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
	await wait(2.5)
	# Where the panel is fixed it never moves; where it glides, it ends at the map's spot for the revealed room.
	var want_box := layout.cauldron_after if entry.get("_made_way") else layout.cauldron
	var want_plate := layout.mechanism_after if entry.get("_made_way") else layout.mechanism
	expect(flat.call(box.global_position).distance_to(flat.call(want_box)) < 0.01, "the cauldron is where the map says after the reveal starts")
	expect(flat.call(plate.global_position).distance_to(flat.call(want_plate)) < 0.01, "and the panel")
	if layout.panel_fixed:
		expect(flat.call(plate.global_position).distance_to(flat.call(layout.mechanism)) < 0.001, "a fixed panel did not move")
	Engine.time_scale = 1.0


func test_the_first_things_appear_with_the_shelf_and_the_shelf_level_makes_the_same_ones() -> void:
	Engine.time_scale = 1.0
	load("res://trials/tidy/tidy_trial.gd").push = 0.0
	await boot(null, &"intro")
	app.autostart = true
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.poke_in_sim = true
	entry.run()
	expect(await until(func() -> bool: return entry.find_child("entry_part_all", true, false) != null, 30.0), "the opening is set up")
	var copy: Variant = entry.get("_shelf")
	expect(copy != null and copy.things().size() >= 3, "the opening has made the first round's things (%s)" % [copy.things().size() if copy != null else 0])
	var before := {}
	for thing: Node3D in copy.things():
		before[thing.name] = thing.global_position
		expect(not thing.visible, "%s is hidden until the ripple reaches it" % thing.name)
	entry._on_target(entry.find_child("entry_part_shelf", true, false) as Target)
	expect(await until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 60.0), "the first visit loads")
	expect(await until(func() -> bool: return App.session.trial != null and App.session.trial.get("_things") != null and not (App.session.trial.get("_things") as Array).is_empty(), 30.0), "and its trial makes things")
	var made: Array = App.session.trial.get("_things")
	expect_eq(made.size(), before.size(), "the same number of things")
	for thing: Node3D in made:
		expect(before.has(thing.name), "%s is one of the things the opening showed (same shape, same colour, same seed)" % thing.name)
		if before.has(thing.name):
			expect(thing.global_position.distance_to(before[thing.name]) < 0.001, "%s is in the same place (no swap, no drop-in)" % thing.name)
	await App.main.change_scene(&"global_motion")   # leave the first visit: it gives the shelf's static settings back
	var tidy = load("res://trials/tidy/tidy_trial.gd")
	tidy.push = 0.0
	tidy.seed_next = 0
	tidy.things_arrive = true
	tidy.onion_voice = false
	Engine.time_scale = 1.0


func test_onions_float_toward_the_shapes_stays_clear_of_the_shelf_the_things_and_the_bench() -> void:
	for size: Vector2 in [Vector2(1.0, 0.7), Vector2(1.2, 0.7), Vector2(1.6, 0.9)]:
		for reach: float in [0.0, 0.5, 0.72]:
			var layout := _layout(size, 0.3, 0.5, reach)
			expect(layout.zone(&"onion_invite") != null and layout.zone(&"onion_reveal") != null, "the invitation spots are in the map")
			expect(layout.invite_fraction <= EntryLayout.INVITE_FRACTION + 0.001 and layout.invite_fraction > 0.0, "it floats some of the way: %.2f of it" % layout.invite_fraction)
			expect(layout.report() == "", "%s, reach %d: %s" % [size, roundi(reach * 100), layout.report()])


func test_a_socket_that_must_move_rides_a_track_the_table_draws() -> void:
	Engine.time_scale = 1.0
	load("res://trials/tidy/tidy_trial.gd").push = 0.0
	await boot(null, &"intro")
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.poke_in_sim = true
	entry.run()
	expect(await until(func() -> bool: return entry.find_child("entry_part_all", true, false) != null, 30.0), "the opening is set up")
	var layout: EntryLayout = entry.get("_layout")
	# Whatever this table's own plan says, give the socket a place 25 cm to the right to ride to (the track is what is tested).
	layout.mechanism_after = layout.mechanism + Vector3(0.25, 0.0, 0.0)
	layout.mechanism_yaw_after = layout._facing(layout.mechanism_after)
	layout.socket_after = layout._socket_of(layout.mechanism_after, layout.mechanism_yaw_after)
	entry._on_target(entry.find_child("entry_part_reveal", true, false) as Target)
	expect(await until(func() -> bool: return entry.get_node_or_null("SocketTrack") != null, 20.0), "a groove is drawn from the socket to its new place")
	var plate: Node3D = entry.get("_mechanism")
	var track: Node3D = entry.get_node_or_null("SocketTrack")
	var last := plate.global_position
	await wait(0.5)
	expect(await until(func() -> bool: return plate.global_position.distance_to(last) > 0.01, 10.0), "then the socket rides along it")
	expect(await until(func() -> bool: return not is_instance_valid(track) or track.is_queued_for_deletion(), 20.0), "and the groove fades after")
	expect(plate.global_position.distance_to(layout.mechanism_after) < 0.01, "the socket ends where the map says")
	Engine.time_scale = 1.0


func test_the_first_visit_scene_is_loaded_in_the_background_so_the_handover_does_not_freeze() -> void:
	Engine.time_scale = 1.0
	load("res://trials/tidy/tidy_trial.gd").push = 0.0
	await boot(null, &"intro")
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.run()
	expect(await until(func() -> bool: return entry.find_child("entry_part_all", true, false) != null, 30.0), "the opening is set up")
	var path := String(Main.SCENES[&"first_visit"].path)
	expect(await until(func() -> bool: return ResourceLoader.has_cached(path), 10.0), "the first visit's scene was requested at the start and is ready (it cost 56 ms in one frame when loaded at the switch)")
	Engine.time_scale = 1.0


# --- The motion route (EntryMotionLayout) -------------------------------------------

func test_the_dots_numbers_match_weis_motion_def() -> void:
	var def := load("res://trials/motion/motion.tres") as TrialDef
	var condition := def.condition(0.0, 0, false, {})
	expect(absf(condition.value(&"half_width") - EntryMotionLayout.DOTS_HALF.x) < 0.001, "half width")
	expect(absf(condition.value(&"half_height") - EntryMotionLayout.DOTS_HALF.y) < 0.001, "half height")
	expect(absf(condition.value(&"half_depth") - EntryMotionLayout.DOTS_HALF.z) < 0.001, "half depth")
	expect(absf(condition.value(&"distance") - EntryMotionLayout.DOTS_DISTANCE) < 0.001, "distance")


func test_the_dots_rise_from_behind_the_table_clear_of_the_bench_and_onion_stays_out_of_their_view() -> void:
	var cases := 0
	for size: Vector2 in [Vector2(1.0, 0.7), Vector2(1.2, 0.7), Vector2(1.6, 0.9)]:
		for edge: float in [0.3, 0.4]:
			for drop: float in [0.45, 0.55]:
				for reach: float in [0.0, 0.5, 0.6, 0.72]:
					if (reach if reach > 0.0 else EntryLayout.REACH_USUAL) - edge < 0.15:
						continue
					var layout := _layout(size, edge, drop, reach)
					var motion := EntryMotionLayout.new(layout)
					var label := "table %s edge %d drop %d reach %d" % [size, roundi(edge * 100), roundi(drop * 100), roundi(reach * 100)]
					expect(motion.dots_near_face() >= EntryMotionLayout.DOTS_NEAR, "%s: the cloud's near face is %d cm out" % [label, roundi(motion.dots_near_face() * 100)])
					expect_eq(motion.table_into_dots(), 0.0, "%s: the table's far edge does not reach into the cloud" % label)
					var path := motion.entrance()
					expect(path[0].y < layout.table.origin.y, "%s: the group starts below the table top, hidden by the table" % label)
					var entrance := motion.entrance_zone()
					for other: EntryLayout.Zone in [layout._bench_zone(), layout._shelf_zone(), layout._things_zone()]:
						expect(EntryLayout.volume_gap(entrance, other) > 0.2, "%s: the entrance is clear of %s" % [label, other.name])
					var onion := motion.onion_spot()
					expect(onion.gap >= EntryMotionLayout.ONION_VIEW_GAP, "%s: Onion is %d degrees out of the dots' view" % [label, roundi(onion.gap)])
					var to: Vector3 = onion.at - layout.eye
					expect(absf(rad_to_deg(atan2(to.x, -to.z))) < 55.0, "%s: Onion is still in the child's view (within 55 degrees): %d, gap %d, moved %s" % [label, roundi(rad_to_deg(atan2(to.x, -to.z))), roundi(onion.gap), onion.moved])
					cases += 1
	expect_eq(cases, 42, "every case was tried")


func test_the_subtitle_covers_the_dots_unless_it_is_raised() -> void:
	var motion := EntryMotionLayout.new(EntryLayout.usual().plan())
	expect(motion.subtitle_gap(20.0) < 0.0, "Voice's 20 degrees puts the line over the dots (a known cost of the motion part)")
	expect(motion.subtitle_gap(12.0) < motion.subtitle_gap(20.0), "the proposed 12 degrees is worse for the dots")
	expect(motion.subtitle_gap(32.0) >= 0.0, "32 degrees clears the dots")


func test_the_coherence_control_maps_levels_like_weis_axis() -> void:
	expect_eq(EntryMotionLayout.level_for(90.0), 0.0, "90 % is level 0")
	expect_eq(EntryMotionLayout.level_for(15.0), 1.0, "15 % is level 1")
	expect(absf(EntryMotionLayout.percent_for(EntryMotionLayout.level_for(50.0)) - 50.0) < 0.001, "50 % round-trips")
	var head := Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 0))
	var marker := EntryMotionLayout.marker_spot(head)
	var yaw := rad_to_deg(atan2(marker.x - head.origin.x, -(marker.z - head.origin.z)))
	expect(yaw < -25.0 or yaw > 25.0, "the marker is off the middle of the view (%d degrees)" % roundi(yaw))
	expect(marker.y > head.origin.y, "the marker is above the horizon")
	for i in 5:
		var spot := EntryMotionLayout.coherence_spot(head, 1, i, 5, EntryMotionLayout.COHERENCE_PRESET_WIDE)
		expect(spot.distance_to(head.origin) < 0.62, "preset %d is within an arm's reach (%d cm)" % [i, roundi(spot.distance_to(head.origin) * 100)])
		for j in range(i + 1, 5):
			var other := EntryMotionLayout.coherence_spot(head, 1, j, 5, EntryMotionLayout.COHERENCE_PRESET_WIDE)
			expect(spot.distance_to(other) > EntryMotionLayout.COHERENCE_PRESET_WIDE, "presets %d and %d do not touch" % [i, j])
	# Clear of the jump buttons above (the lowest row of the jump panel ends about 17 cm under its middle).
	expect(EntryMotionLayout.coherence_row(head, 0).y < EntryLayout.dev_spot(head, false).y - 0.2, "the readout sits under the jump panel")


func test_the_motion_dev_marker_and_coherence_control_build_and_pin_like_the_facilitator() -> void:
	await boot(null, &"intro")
	var dev := EntryMotionDev.new()
	add_child(dev)
	dev.set_scene(&"Motion")
	expect_eq(dev._label.text, "Motion", "the marker names the scene")
	expect_eq(dev._buttons.size(), 7, "five presets and -5 / +5")
	var session := Session.new()
	add_child(session)
	dev.pin(50.0)
	expect(absf(App.session.pinned - EntryMotionLayout.level_for(50.0)) < 0.001, "50 %% pinned as a level, the way Easier/Harder pin: %s" % App.session.pinned)
	dev._press(&"dev_coh_up")
	expect(absf(dev.coherence() - 55.0) < 0.5, "+5 steps to 55 %%, got %s" % dev.coherence())
	dev._press(&"dev_coh_15")
	expect(absf(dev.coherence() - 15.0) < 0.5, "the 15 preset")
	dev.queue_free()
	session.queue_free()
