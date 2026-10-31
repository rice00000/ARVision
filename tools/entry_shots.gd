extends Node
## Pictures of the entry's setup panel, a ray on Start and the ripple, on the simulated room
## (no headset), to build/entry_shots/. Software rendering is fine:
##   xvfb-run -a godot --rendering-driver opengl3 --xr-mode off --path . res://tools/entry_shots.tscn -- --profile=test_capture

var _out := ProjectSettings.globalize_path("res://build/entry_shots")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.get_node(^"Session").autostart = false
	app.get_node(^"World").autostart = false
	app.get_node(^"Entry").autostart = false
	add_child(app)
	await get_tree().process_frame
	var entry: Entry = app.get_node(^"Entry")
	entry.run()
	await _until(func() -> bool: return entry.find_child("entry_confirm_yes", true, false) != null)
	await get_tree().create_timer(0.6).timeout
	await _save("1_table_check")
	entry._confirm_pressed.emit(&"entry_confirm_yes")
	await _until(func() -> bool: return entry.find_child("entry_part_all", true, false) != null)
	await get_tree().create_timer(1.0).timeout
	await _save("2_setup_panel")
	# a ray on Start: it should light up
	var start := entry.find_child("entry_part_all", true, false) as Target
	var eye := App.head().global_position
	var at := start.global_position
	App.sim_input.point(&"right", eye + (at - eye).normalized() * 0.25 + Vector3.DOWN * 0.05, at)
	await get_tree().create_timer(0.8).timeout
	await _save("3_ray_on_start")
	entry._part_pressed.emit(&"ripple")
	await get_tree().create_timer(3.0).timeout
	await _save("4_ripple_mid")
	await get_tree().create_timer(7.0).timeout
	await _save("5_ripple_done")
	get_tree().quit()

func _until(cond: Callable) -> void:
	var n := 0
	while not cond.call() and n < 600:
		await get_tree().process_frame
		n += 1

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("SHOT ", name)
