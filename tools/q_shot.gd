extends Node
var _out := ProjectSettings.globalize_path("res://build/gear")
var _said := ""
func _ready() -> void:
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	var entry: Entry = app.get_node(^"Intro/Entry")
	App.rig.head.rotation.x = -0.55
	Events.said.connect(func(t: String) -> void: _said = t)
	entry.run()
	var n := 0
	while entry.find_child("entry_part_hello", true, false) == null and n < 900:
		await get_tree().process_frame
		n += 1
	await get_tree().create_timer(0.5).timeout
	entry._on_target(entry.find_child("entry_part_hello", true, false) as Target)
	n = 0
	while _said != "Could you help me with something?" and n < 3000:
		await get_tree().process_frame
		n += 1
	for i in 4:
		await get_tree().create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out.path_join("q_%d.png" % i))
	print("SHOT done ", _said)
	get_tree().quit()
