extends Node
## Onion's first-visit welcome flight into the child's room (Scene 12): ~5 s of frames (30 fps) from the
## child's seat, to build/onion_welcome/. Make a clip: ffmpeg -framerate 30 -i f%03d.png welcome.mp4
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       --fixed-fps 30 res://tools/onion_welcome_shots.tscn -- --profile=test_capture   (one game frame per picture)

var _out := ProjectSettings.globalize_path("res://build/onion_welcome")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_tree().create_timer(200.0, true, false, true).timeout.connect(get_tree().quit)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	add_child(app)
	await get_tree().create_timer(2.0).timeout
	(App.rig.head as Camera3D).fov = 90.0
	App.rig.head.rotation = Vector3(-0.12, 0, 0)
	var intro := app.get_node(^"RoomIntro") as RoomIntro
	intro.automatic = true
	intro.seen = false
	Events.room_requested.emit()   # the gear's Home, after the fade
	for i in 165:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out.path_join("f%03d.png" % i))
	get_tree().quit()
