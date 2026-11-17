extends Node
## Scene 1 (Hello) pictures for the scene review, to build/hello/: Onion's pop (bubbles), the first
## line's subtitle, and the same a moment later with the head turned 20 degrees to the right.
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://tools/hello_shots.tscn -- --profile=test_capture [--prefix=after]

var _out := ProjectSettings.globalize_path("res://build/hello")
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
	(App.rig.head as Camera3D).fov = 80.0
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.plan_at_start = false
	entry.run()
	await _until(func() -> bool: return entry.tools_ready and entry.get("_box") != null)
	await get_tree().create_timer(1.0).timeout
	var said := []
	Events.said.connect(func(text: String) -> void: said.append(text))
	entry.jump_to(&"hello")
	var box: Node3D = entry.get("_box")
	var pot := box.global_position + Vector3.UP * 0.1
	App.sim_input.look_at(pot)
	await _until(func() -> bool: return said.has("Oh! Hello there."))
	await get_tree().create_timer(0.05).timeout
	await _shot("1_pop")
	var eye := App.head().global_position
	var ahead := (pot - eye)
	var turned := ahead.rotated(Vector3.UP, deg_to_rad(-20.0))
	App.sim_input.look_at(eye + turned)
	await get_tree().create_timer(0.1).timeout
	await _shot("2_head_turned_20deg")
	Profile.wipe()
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func _until(condition: Callable) -> void:
	var end := Time.get_ticks_msec() + 30000
	while not condition.call() and Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [_out, _prefix, name])
	print("SHOT ", _prefix, "_", name)
