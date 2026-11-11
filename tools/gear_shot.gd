extends Node
## A picture of the gear set into its socket (after the "place" part), to build/gear_shot/.
##   xvfb-run -a godot --rendering-driver opengl3 --xr-mode off --path . res://tools/gear_shot.tscn -- --profile=test_capture

var _out := ProjectSettings.globalize_path("res://build/gear_shot")


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
	entry.jump_to(&"place")
	await get_tree().create_timer(4.0).timeout
	entry.call("_dock_at_once")   # as if the child set it in
	await get_tree().create_timer(1.0).timeout
	var socket: Vector3 = entry.get("_socket_at")
	var head := App.rig.head
	head.look_at(socket, Vector3.UP)
	await get_tree().create_timer(0.5).timeout
	await _save("gear_docked")
	head.global_position = socket + Vector3(0.0, 0.25, 0.25)
	head.look_at(socket, Vector3.UP)
	await get_tree().create_timer(0.5).timeout
	await _save("gear_docked_close")
	get_tree().quit()


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("SHOT ", name)
