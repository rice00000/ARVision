extends Node
## Pictures of the gear coming out of the cauldron and setting into the table panel (no headset).
var _out := ProjectSettings.globalize_path("res://build/gear")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	var entry: Entry = app.get_node(^"Intro/Entry")
	App.rig.head.rotation.x = -0.55   # looking down at the table, as a seated child does
	entry.run()
	await _until(func() -> bool: return entry.find_child("entry_part_emerge", true, false) != null)
	await get_tree().create_timer(0.5).timeout
	await _save("0_before")
	entry._on_target(entry.find_child("entry_part_emerge", true, false) as Target)
	await get_tree().create_timer(2.0).timeout    # onion aside (1.5 s) + the pop begins
	await _save("1_popping")
	await get_tree().create_timer(1.1).timeout
	await _save("2_arcing")
	await get_tree().create_timer(1.6).timeout
	await _save("3_landed")
	await get_tree().create_timer(2.6).timeout
	await _save("4_docked")
	get_tree().quit()

func _until(c: Callable) -> void:
	var n := 0
	while not c.call() and n < 900:
		await get_tree().process_frame
		n += 1

func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("SHOT ", name)
