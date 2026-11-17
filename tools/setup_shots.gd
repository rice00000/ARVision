extends Node
## Scene 0 (setup) pictures for the scene review, to build/setup/: step 1 on the setup panel, the
## "same table as last time" offer (when the build has it), and the staff tools' Tools page.
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://tools/setup_shots.tscn -- --profile=test_capture --mode=play [--prefix=after]

var _out := ProjectSettings.globalize_path("res://build/setup")
var _prefix := "now"


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--prefix="):
			_prefix = arg.trim_prefix("--prefix=")
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var memory: GDScript = load("res://entry/setup_memory.gd") if ResourceLoader.exists("res://entry/setup_memory.gd") else null
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	app.initial_scene = "intro"
	add_child(app)
	await _frames(5)
	(App.rig.head as Camera3D).fov = 80.0
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.skip_setup = false
	entry.plan_at_start = false
	entry.run()
	await _until(func() -> bool: return entry.find_child("entry_step_next", true, false) != null)
	await _frames(10)
	await _shot("1_step_one", "entry_step_next")
	App.sim_input.menu()   # the staff tools (as the tests open them)
	await _frames(3)
	await _press("fac_tools")
	await _frames(3)
	await _shot("3_tools_page", "fac_jump_reveal")
	if memory != null:   # the offer: keep the sim room's table, then open the opening again
		memory.set("path", "user://capture_last_setup.cfg")
		memory.call("remember", App.reality.surfaces(&"table")[0], 0.45)
		App.sim_input.menu()
		app.queue_free()
		await _frames(3)
		app = load("res://main.tscn").instantiate()
		app.autostart = false
		app.initial_scene = "intro"
		add_child(app)
		await _frames(5)
		(App.rig.head as Camera3D).fov = 80.0
		entry = app.get_node(^"Intro/Entry")
		entry.skip_setup = false
		entry.plan_at_start = false
		entry.run()
		await _until(func() -> bool: return entry.find_child("entry_reuse_yes", true, false) != null)
		await _frames(10)
		await _shot("2_same_table_offer", "entry_reuse_yes")
		memory.call("forget")
	Profile.wipe()
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func _until(condition: Callable) -> void:
	var end := Time.get_ticks_msec() + 20000
	while not condition.call() and Time.get_ticks_msec() < end:
		await get_tree().process_frame


func _press(id: String) -> void:
	var target := App.main.find_child(id, true, false) as Target
	App.sim_input.point(&"right", App.head().global_position + Vector3(0.12, -0.18, -0.15), target.global_position)
	await _frames(3)
	App.sim_input.click(&"right", &"trigger_click")
	await _frames(3)


func _shot(name: String, aimed_id: String) -> void:
	var target := App.main.find_child(aimed_id, true, false) as Target
	if target != null:
		App.sim_input.look_at(target.global_position + Vector3.UP * 0.04)
		App.sim_input.point(&"right", App.head().global_position + Vector3(0.12, -0.18, -0.15), target.global_position)
	await get_tree().physics_frame
	await _frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s_%s.png" % [_out, _prefix, name])
	print("SHOT ", _prefix, "_", name)
