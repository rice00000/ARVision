extends Node
## Pictures of the Menu button with the stone count (top left of the view) and the menu opened during
## the shelf, to build/menu_shot/.
##   xvfb-run -a godot --rendering-driver opengl3 --xr-mode off --path . res://tools/menu_shot.tscn -- --profile=test_capture

var _out := ProjectSettings.globalize_path("res://build/menu_shot")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.skip_setup = true
	entry.run()
	var n := 0
	while not entry.tools_ready and n < 900:
		await get_tree().process_frame
		n += 1
	entry.jump_to(&"shelf")
	n = 0
	while App.main.current_scene != &"first_visit" and n < 1200:
		await get_tree().process_frame
		n += 1
	await get_tree().create_timer(4.0).timeout
	App.module(&"Inventory").add(&"magic_stone", 3)
	await get_tree().create_timer(1.0).timeout
	await _save("shelf_with_menu_button")
	App.module(&"Home").open()
	await get_tree().create_timer(1.0).timeout
	await _save("menu_open_on_shelf")
	get_tree().quit()


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("SHOT ", name)
