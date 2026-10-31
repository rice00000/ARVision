extends Node
## Pictures of three layouts of the shelf and cauldron after the opening's ripple, same view.
var _out := ProjectSettings.globalize_path("res://build/layouts")
## name -> [how far back, shelf angle (right), cauldron angle (left)]
const LAYOUTS := {"P1_back_12cm": [0.12, 0.0, 30.0], "P2_back_22cm": [0.22, 0.0, 30.0], "P3_back_32cm": [0.32, 0.0, 30.0]}

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	for name in LAYOUTS:
		Profile.wipe()
		var app: Node3D = load("res://main.tscn").instantiate()
		app.autostart = false
		add_child(app)
		await get_tree().process_frame
		var entry: Entry = app.get_node(^"Intro/Entry")
		entry.shelf_push = LAYOUTS[name][0]
		entry.shelf_angle = LAYOUTS[name][1]
		entry.cauldron_angle = LAYOUTS[name][2]
		entry.run()
		await _until(func() -> bool: return entry.find_child("entry_part_ripple", true, false) != null)
		entry._on_target(entry.find_child("entry_part_ripple", true, false) as Target)
		await get_tree().create_timer(9.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
		print("SHOT ", name)
		app.queue_free()
		await get_tree().create_timer(0.6).timeout
	get_tree().quit()

func _until(c: Callable) -> void:
	var n := 0
	while not c.call() and n < 900:
		await get_tree().process_frame
		n += 1
