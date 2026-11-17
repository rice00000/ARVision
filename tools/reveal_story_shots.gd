extends Node
## Scene 6 (the reveal) storyboard for the scene review, to build/reveal_story/: frames at fixed times
## after a jump to the reveal (game time), from the seated child's eyes, wide enough for the cauldron,
## the socket and the bench.
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://tools/reveal_story_shots.tscn -- --profile=test_capture [--prefix=after]

const TIMES := [1.0, 3.0, 4.5, 6.0, 8.0, 10.0, 12.0, 15.0]

var _out := ProjectSettings.globalize_path("res://build/reveal_story")
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
	await _until(func() -> bool: return entry.tools_ready and entry.zones_available())
	await get_tree().create_timer(0.5).timeout
	var eye := App.head().global_position
	var box: Node3D = entry.get("_box")
	var bench: Transform3D = entry.get("_bench")
	var middle := (box.global_position + bench.origin + Vector3.DOWN * 0.4) * 0.5
	App.sim_input.look_at(middle)
	var said := []
	Events.said.connect(func(text: String) -> void: said.append(text))
	entry.jump_to(&"reveal")
	await _until(func() -> bool: return bool(entry.get("_part_running")))
	var start := Engine.get_process_frames()
	for t: float in TIMES:
		await _until(func() -> bool: return (Engine.get_process_frames() - start) / 60.0 >= t)
		App.sim_input.look_at(middle)
		await _shot("%04.1fs" % t)
	print("SAID ", said)
	Profile.wipe()
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func _until(condition: Callable) -> void:
	var end := Time.get_ticks_msec() + 60000
	while not condition.call() and Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [_out, _prefix, name])
	print("SHOT ", _prefix, "_", name)
