extends Node
## Renders what the child sees under every view preset, on the simulated room,
## to build/captures/<view>.png. For people (and agents) to look at; no headset.
##
##   godot --xr-mode off --path . res://tools/capture.tscn -- --profile=test_capture

const VIEWS := "res://content/views/"


func _ready() -> void:
	var out := ProjectSettings.globalize_path("res://build/captures")
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.get_node(^"Session").autostart = false
	app.get_node(^"Session").plan = TestCase.plan_of(load("res://trials/find/find.tres"), 1, false, 0.6)
	add_child(app)
	await get_tree().process_frame
	App.session.run()
	while App.session.trial == null or not App.session.trial.is_running():
		await get_tree().process_frame
	App.sim_input.look_at(App.reality.work_surface().transform.origin + Vector3(0, 0.0, -0.3))
	for file in DirAccess.get_files_at(VIEWS):
		if file.ends_with(".tres"):
			App.reality.apply_view(load(VIEWS + file))
			await _save(out.path_join(file.get_basename() + ".png"))
	App.reality.apply_view(View.new())
	var magic := App.module(&"Magic")
	magic.sparkle((App.session.trial.get("_target") as Node3D).global_position, magic.GOLD, 24)
	await get_tree().create_timer(0.3).timeout
	await _save(out.path_join("sparkles.png"))
	Events.report(&"task_done", {task = &"find_toys", level = 1, colour = 1})
	await get_tree().create_timer(1.3).timeout
	await _save(out.path_join("potion.png"))
	await get_tree().create_timer(2.5).timeout
	App.sim_input.menu()
	await _save(out.path_join("facilitator.png"))
	App.module(&"Facilitator").call(&"_show", &"Saves")
	App.module(&"Facilitator").call(&"_refresh")
	await _save(out.path_join("facilitator_saves.png"))
	print("CAPTURED ", out)
	get_tree().quit()


func _save(path: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
