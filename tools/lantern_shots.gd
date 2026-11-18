extends Node
## The workshop's lanterns in the hub (Megan, Nov 18), seated child's view, to build/lanterns/:
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://tools/lantern_shots.tscn -- --profile=test_capture
## The sim room's walls are added as if the Quest had scanned them, so the wall lanterns show
## (without them only the cauldron's lantern hangs). Writes stills plus frames for a short clip.

var _out := ProjectSettings.globalize_path("res://build/lanterns")
var _hub: WorkshopController


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--style="):
			Lantern.style = StringName(arg.trim_prefix("--style="))
	_out = ProjectSettings.globalize_path("res://build/lanterns_%s" % Lantern.style)
	DirAccess.make_dir_recursive_absolute(_out.path_join("clip"))
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	(App.rig.head as Camera3D).fov = 80.0
	for wall in RevealShots.sim_walls():
		App.reality.add_surface(wall)
	app.autostart = true
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	entry.run()
	await _until(func() -> bool: return entry.tools_ready and entry.zones_available() and entry.get("_layout") != null, 2400)
	await _pause(1.0)
	_look(-0.45, 0.0)
	entry.call(&"_to_shelf", false)
	await _until(func() -> bool:
		_hub = app.find_child("WorkshopController", true, false) as WorkshopController
		return _hub != null and _hub.state == &"hub" and not _hub.ring.turning, 1800)
	var hub := _hub
	await _pause(2.5)
	print("LANTERNS ", hub.lanterns.size())
	for l in hub.lanterns:
		print("  at ", l.global_position + Lantern.GLASS, " light ", l.light != null)
	await _shot("1_hub", -0.45, 0.0)
	await _shot("2_ahead", -0.05, 0.0, 95.0)
	await _shot("3_up", 0.55, 0.0, 95.0)
	await _shot("4_left", 0.2, 1.2, 95.0)
	await _shot("5_right", 0.2, -1.2, 95.0)
	# A close look at the cauldron's lantern, then ~6 s of frames for a clip (the glow breathing, embers).
	var cam := App.rig.head as Camera3D
	cam.fov = 40.0
	var target := hub.lanterns[0].global_position + hub.lanterns[0].glass_offset()
	var eye := cam.global_position
	var flat := Vector3(target.x - eye.x, 0.0, target.z - eye.z)
	_look(atan2(target.y - eye.y, flat.length()), atan2(-flat.x, -flat.z))
	await _pause(0.3)
	await _shot("6_close", NAN, NAN, 40.0)
	if not "--clip" in OS.get_cmdline_user_args():
		get_tree().quit()
		return
	Lantern.alive[0].set("_next_ember", 1.0)   # make sure the clip shows one ember
	for i in 180:
		await get_tree().create_timer(1.0 / 30.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out.path_join("clip/f%03d.png" % i))
	get_tree().quit()


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _until(cond: Callable, frames := 900) -> void:
	var n := 0
	while not cond.call() and n < frames:
		await get_tree().process_frame
		n += 1


func _look(pitch: float, yaw: float) -> void:
	App.rig.head.rotation = Vector3(pitch, yaw, 0.0)


func _shot(file: String, pitch: float, yaw: float, fov := 80.0) -> void:
	if not is_nan(pitch):
		_look(pitch, yaw)
	(App.rig.head as Camera3D).fov = fov
	await _pause(0.2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(file + ".png"))
	print("SHOT ", file)
