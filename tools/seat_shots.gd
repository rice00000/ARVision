extends Node
## Scene 2 (Tap) picture for the scene review, to build/seat/: the moment just after the tap.
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://tools/seat_shots.tscn -- --profile=test_capture [--prefix=after]

var _out := ProjectSettings.globalize_path("res://build/seat")
var _prefix := "now"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="):
			_prefix = arg.trim_prefix("--prefix=")
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	app.initial_scene = "intro"
	add_child(app)
	await _frames(5)
	(App.rig.head as Camera3D).fov = 50.0   # closer in on the cauldron
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	entry.run()
	entry.simulate_child = true
	await _until(func() -> bool: return entry.tools_ready and entry.get("_carry") != null)
	entry.jump_to(&"place")
	var sounds: Sounds = entry.get("_sounds")
	await _until(func() -> bool: return bool(entry.get("_part_running")))
	App.sim_input.look_at(entry.get("_socket_at"))
	await _until(func() -> bool: return sounds.played.has(&"seat"))
	await get_tree().create_timer(0.3).timeout
	await _shot("1_seated_0.3s")
	Profile.wipe()
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func _until(condition: Callable) -> void:
	var end := Time.get_ticks_msec() + 30000
	while not condition.call() and Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [_out, _prefix, name])
	print("SHOT ", _prefix, "_", name)
