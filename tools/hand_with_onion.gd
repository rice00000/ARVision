extends Node
## Does the teaching hand overlap Onion? Runs the real opening, jumps to each beat that shows a gesture (the tap,
## the pinch, the set-in), waits for Onion to take its place, then steps the hand through its whole loop and
## measures how close its joints come to Onion's box in 3D and to Onion's outline on the screen, from the child's
## seat. Pictures at four moments of each gesture; the numbers go to build/onion_hand/overlap.txt.
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . res://tools/hand_with_onion.tscn -- --profile=test_capture
var _out := ProjectSettings.globalize_path("res://build/onion_hand")
var _report: Array[String] = []

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	var entry: Entry = app.get_node(^"Intro/Entry")
	App.rig.head.rotation.x = -0.55   # looking down at the table, as a seated child does
	entry.run()
	await _until(func() -> bool: return entry.find_child("entry_part_touch", true, false) != null)
	await _gesture(entry, "tap", "entry_part_touch", DemoHand.Mode.TAP, [0.4, 0.85, 1.05, 1.5])
	await _gesture(entry, "pinch_lift", "entry_part_pickup", DemoHand.Mode.PINCH_LIFT, [1.0, 1.7, 2.9, 5.0])
	await _gesture(entry, "lower_release", "entry_part_place", DemoHand.Mode.LOWER_RELEASE, [0.6, 1.9, 2.4, 3.4])
	var file := FileAccess.open(_out.path_join("overlap.txt"), FileAccess.WRITE)
	file.store_string("\n".join(_report))
	file.close()
	print("OVERLAP report\n", "\n".join(_report))
	get_tree().quit()

func _gesture(entry: Entry, name: String, button: String, mode: DemoHand.Mode, shot_times: Array) -> void:
	entry._on_target(entry.find_child(button, true, false) as Target)
	var demo: DemoHand = entry.get("_demo")
	await _until(func() -> bool: return demo._mode == mode, 1800)   # the beat's own lines come first
	await get_tree().create_timer(1.5).timeout   # Onion gets to its place
	if demo._mode != mode:
		_report.append("%s: the hand was not showing (mode %s)" % [name, demo._mode])
		return
	var orb: Node3D = entry.get("_orb")
	var onion: Node3D = entry.get("_onion")
	var box: AABB = entry._bounds(onion)   # Onion's box, tail and all (world axes)
	var camera := App.rig.head
	demo.set_process(false)
	demo._fade = 1.0
	# Onion's outline on the screen: the rectangle round the corners of its box.
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for i in 8:
		var corner := box.position + box.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1)
		var px := camera.unproject_position(corner)
		low = low.min(px)
		high = high.max(px)
	var best_3d := INF
	var best_2d := INF
	var worst_time := 0.0
	var t := 0.0
	while t < demo._length:
		demo._t = t
		demo._pose(t)
		await get_tree().process_frame
		for joint in _joints(demo):
			var nearest := joint.clamp(box.position, box.end)   # the point of the box nearest the joint
			var d3 := joint.distance_to(nearest) - 0.012   # minus the finger's own thickness
			if d3 < best_3d:
				best_3d = d3
				worst_time = t
			var px := camera.unproject_position(joint)
			var dx := maxf(maxf(low.x - px.x, px.x - high.x), 0.0)
			var dy := maxf(maxf(low.y - px.y, px.y - high.y), 0.0)
			best_2d = minf(best_2d, Vector2(dx, dy).length() - 4.0)   # inside the outline, or within 4 px of it: negative
		for shot_time: float in shot_times:
			if absf(t - shot_time) < 0.05:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(_out.path_join("%s_%.2f.png" % [name, t]))
		t += 0.1
	_report.append("%s: the hand's joints come no closer than %.1f cm to Onion's box (at %.1f s of the loop), and %.0f px from Onion's screen outline (negative = inside it); Onion at %s, box %s cm" % [
		name, best_3d * 100.0, worst_time, best_2d, snapped(orb.global_position, Vector3.ONE * 0.01), snapped(box.size * 100.0, Vector3.ONE * 0.1)])
	demo.set_process(true)
	demo.stop()
	await get_tree().create_timer(1.0).timeout

func _joints(demo: DemoHand) -> Array[Vector3]:
	var points: Array[Vector3] = []
	if demo._skeleton != null:
		for bone in demo._skeleton.get_bone_count():
			points.append(demo._skeleton.to_global(demo._skeleton.get_bone_global_pose(bone).origin))
	else:
		points.append(demo.global_position)
	return points

func _until(c: Callable, limit := 900) -> void:
	var n := 0
	while not c.call() and n < limit:
		await get_tree().process_frame
		n += 1
