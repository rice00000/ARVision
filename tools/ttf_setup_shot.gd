extends Node
## Turn to fit's setup page (Staff tools → Scenes → "Turn to fit (real cup)") with the laptop-address
## number pad. → build/ttf_hub/0_setup.png
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://tools/ttf_setup_shot.tscn -- --profile=test_capture --mode=play

var _out := ProjectSettings.globalize_path("res://build/ttf_hub")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	(App.rig.head as Camera3D).fov = 80.0
	await app.change_scene(&"turn_to_fit")
	await _until(func() -> bool: return not app.switching)
	var fit := app.find_child("Fit", true, false) as TurnToFit
	fit.frame_source = func() -> Image: return Image.load_from_file("res://tests/data/turn_to_fit/santa_left.jpg")
	fit.tracker.use_server = false
	fit.run()
	await get_tree().create_timer(1.5).timeout
	for key: String in ["1", "9", "2", "dot", "1", "6", "8", "dot", "1", "dot", "2", "3"]:
		fit.call(&"_type", key)
	var board := fit.find_child("SetupBoard", true, false) as Node3D
	App.rig.head.look_at(board.global_position + Vector3(0.12, -0.08, 0.0))
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("0_setup.png"))
	print("SHOT 0_setup")
	get_tree().quit()


func _until(cond: Callable, frames := 900) -> void:
	var n := 0
	while not cond.call() and n < frames:
		await get_tree().process_frame
		n += 1
