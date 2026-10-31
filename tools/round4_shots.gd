extends Node
## Layout chat, round 3: the teaching hand at three sizes over its targets (how much of each it
## covers from a seated child's eyes), and the subtitle in the first visit at Wei's setting and the
## proposed one. Pictures to build/round3/. Not part of the game.
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . res://tools/round4_shots.tscn -- --profile=test_capture


var _out := ProjectSettings.globalize_path("res://build/round4")
var _entry: Entry


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	(App.rig.head as Camera3D).fov = 80.0
	_entry = app.get_node(^"Intro/Entry")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reach="):   # a measured reach (setup step 3 is skipped): the layout and the shelf's push follow it
			var reach := float(arg.trim_prefix("--reach="))
			_entry.set("_reach_measured", reach)
			_entry.set("shelf_push", EntryLayout.shelf_push(reach))
			_entry.set("_cauldron_distance", EntryLayout.cauldron_out(reach))
	_entry.run()
	app.autostart = true
	await _until(func() -> bool: return _entry.find_child("entry_part_all", true, false) != null)   # the layout is planned
	await _pause(0.5)
	var args := OS.get_cmdline_user_args()
	if "--part=r5" in args:
		await _round5()
	elif "--part=visit" in args:
		await _visit()
	elif "--part=wall" in args:
		await _wall()
	else:
		await _hands("--zones" in args)
	get_tree().quit()


## Onion beside the hand: each gesture, a few frames across its loop.
## Round 5: the opening with the 3D zone map on (the wireframes), the reveal with the first things arriving
## with the shelf, and Onion beside the socket for the set-in.
func _round5() -> void:
	var layout: EntryLayout = _entry.get("_layout")
	print("R5 layout ", layout.summary(), " fixed ", layout.panel_fixed, " make_way ", layout.make_way)
	print("R5 report ", layout.report().replace("\n", "; ") if layout.report() != "" else "no problems")
	_press(&"entry_part_place")
	await _pause(1.6)
	var socket: Vector3 = _entry.get("_socket_at")
	_look_at(socket + Vector3(0, 0, -0.05))
	await _save("r5_set_in_onion_beside_socket")
	_entry._toggle_zones()
	await _pause(0.3)
	_look_at(socket + Vector3(0, 0, -0.1))
	await _save("r5_zones_3d_set_in")
	_entry._toggle_zones()
	_press(&"entry_part_reveal")
	for k in 6:
		await _pause(1.1)
		_look_at(socket + Vector3(0.1, 0, -0.2))
		await _save("r5_reveal_%d" % k)


func _hands(zones: bool) -> void:
	var layout: EntryLayout = _entry.get("_layout")
	print("R4 layout ", layout.summary())
	print("R4 report ", layout.report().replace("\n", "; ") if layout.report() != "" else "no problems")
	var plan := {
		touch = [func() -> Vector3: return _entry.call("_rim_point"), 3.0, "tap"],
		pickup = [func() -> Vector3: return Carry.middle_of(_entry.get("_gear")), 5.0, "pinch"],
		place = [func() -> Vector3: return _entry.get("_socket_at"), 2.4, "place"],
	}
	for part: String in plan:
		_press(StringName("entry_part_" + part))
		_look_at(plan[part][0].call())
		await _pause(plan[part][1])
		if zones and part == "touch":
			_entry._toggle_zones()
			await _pause(0.2)
		for k in 3:
			_look_at(plan[part][0].call())
			await _pause(0.45)
			await _save("hand_%s_%d%s" % [plan[part][2], k, "_zones" if zones and part == "touch" else ""])
		if zones and part == "touch":
			_entry._toggle_zones()


## The first visit seated: Onion at rest beside the shelf, the cauldron hidden, the subtitle at today's
## setting and the proposed one, looking at the things, the shelf's first row and Onion.
func _visit() -> void:
	await _pause(3.0)   # the opening has been up a while: the first visit's scene has been loading in the background
	_press(&"entry_part_shelf")
	await _until(func() -> bool: return App.main.current_scene == &"first_visit" and not App.main.switching, 900)
	await _pause(3.5)
	var voice := App.module(&"Voice")
	var trial := App.session.trial as Node3D
	var things: Array = trial.get("_things") if trial != null else []
	var middle := Vector3.ZERO
	for thing: Node3D in things:
		middle += thing.global_position
	middle /= maxf(things.size(), 1)
	var shelf := trial.get("_shelf") as Node3D
	var onion: Node3D = App.main.get_node(^"Workshop").get("_onion")
	var layout: EntryLayout = _entry.get("_layout") if is_instance_valid(_entry) else null
	for setting: Array in [[25.0, 20.0, "now"], [36.0, 12.0, "proposed"]]:
		voice.above_gaze = setting[0]
		voice.above_horizon = setting[1]
		var spots := {things = middle, row1 = shelf.global_position + Vector3.UP * 0.1, onion = onion.global_position}
		for look: String in spots:
			_look_at(spots[look])
			Events.say("Can you find a place for one of these?")
			await _pause(0.5)
			await _save("visit_%s_%s" % [setting[2], look])
	get_tree().quit()


func _look_at(at: Vector3) -> void:
	var d := at - App.head().global_position
	var flat := Vector2(d.x, d.z).length()
	App.rig.head.rotation = Vector3(atan2(d.y, flat), atan2(-d.x, -d.z), 0.0)


func _press(id: StringName) -> void:
	var target := _entry.find_child(String(id), true, false) as Target
	if target != null:
		_entry._on_target(target)


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(cond: Callable, frames := 900) -> void:
	var n := 0
	while not cond.call() and n < frames:
		await get_tree().process_frame
		n += 1


func _save(name: String, look := Vector3.INF) -> void:
	if look != Vector3.INF:
		App.rig.head.rotation = look
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("SHOT ", name)


## Motion round 1: the wall effect from the seated view, both looks, a few moments each (and the dots' box
## drawn as a wireframe so its place against the table and shelf shows). In build/round4/wall_*.png.
func _wall() -> void:
	var layout: EntryLayout = _entry.get("_layout")
	_press(&"entry_part_shelf")
	await _pause(4.0)
	var eye := App.head().global_position
	var ahead := Vector3(-App.head().global_basis.z.x, 0.0, -App.head().global_basis.z.z).normalized()
	var motion := EntryMotionLayout.new(layout)
	var box := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = EntryMotionLayout.DOTS_HALF * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.7, 1.0, 0.18)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material = material
	box.mesh = mesh
	get_tree().root.add_child(box)
	box.global_position = motion.dots_centre()
	box.global_rotation = Vector3(0.0, atan2(-ahead.x, -ahead.z), 0.0)
	await _save("wall_0_dots_box_seated", Vector3.ZERO)
	box.queue_free()
	for style: int in [WallBreak.Style.CRACK, WallBreak.Style.SPACE]:
		var name := "crack" if style == WallBreak.Style.CRACK else "space"
		WallBreak.burst(eye, ahead, Vector3.RIGHT, style as WallBreak.Style)
		var clock := 0.0
		for moment: float in [0.4, 1.0, 2.0, 3.5]:
			await _pause(moment - clock)
			clock = moment
			await _save("wall_%s_%d" % [name, roundi(moment * 10.0)], Vector3.ZERO)
		await _pause(6.0)
