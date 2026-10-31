extends Node
var _out := ProjectSettings.globalize_path("res://build/gear")
func _ready() -> void:
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	await app.change_scene(&"global_motion")
	for i in 3:
		await get_tree().create_timer(2.5).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out.path_join("motion_%d.png" % i))
		print("SHOT motion_", i)
	get_tree().quit()
