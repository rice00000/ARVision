extends Node
## Pictures of the Staff tools Results tab as the adult sees it (desktop render), with sample rounds.
##   xvfb-run -a godot --rendering-driver opengl3 --xr-mode off --path . res://modules/results/results_panel_shots.tscn -- --profile=test_results_shots
## Writes build/graphs/panel_outcomes.png, panel_timing.png, panel_coherence.png, panel_empty.png.

var out := "res://build/graphs/"


func _ready() -> void:
	if not String(Profile.id).begins_with("test"):
		get_tree().quit(2)
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	DirAccess.make_dir_recursive_absolute(out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var main: Main = load("res://main.tscn").instantiate()
	main.autostart = false
	main.initial_scene = "find_object"
	add_child(main)
	await _frames(5)
	App.sim_input.menu()
	await _frames(3)
	await _press("fac_results")
	await _shot("panel_empty")
	var view := App.main.find_child("ResultsView", true, false) as ResultsView
	var sample := preload("res://modules/results/results_shots.gd").sample()
	view.use_rounds(sample, sample)
	App.module(&"Facilitator")._refresh_results()
	await _shot("panel_outcomes")
	await _press("fac_res_time")
	await _shot("panel_timing")
	await _press("fac_res_coherence")
	await _shot("panel_coherence")
	print("RESULTS PANEL SHOTS in ", ProjectSettings.globalize_path(out))
	get_tree().quit()


func _frames(count: int) -> void:
	for i in count: await get_tree().process_frame


func _press(id: String) -> void:
	var target := App.main.find_child(id, true, false) as UITarget
	App.sim_input.point(&"right", App.head().global_position + Vector3(0.12, -0.18, -0.15), target.global_position)
	await _frames(3)
	App.sim_input.click(&"right", &"trigger_click")
	await _frames(3)


func _shot(name: String) -> void:
	App.sim_input.point(&"right", App.head().global_position + Vector3(0.3, -0.5, -0.1), App.head().global_position + Vector3(0.6, -1.0, -0.2))
	await get_tree().physics_frame
	await _frames(4)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + name + ".png")
