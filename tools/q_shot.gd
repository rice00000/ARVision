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
	var wanted := ["I was getting things ready.", "Uh... nearly ready.", "I'm Onion, by the way."]
	var shots := 0
	n = 0
	while shots < wanted.size() and n < 6000:
		await get_tree().process_frame
		n += 1
		if _said == wanted[shots]:
			await get_tree().create_timer(1.1 if shots == 0 else 0.5).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_out.path_join("hello_%d.png" % shots))
			print("SHOT hello_", shots, " ", _said)
			shots += 1
	get_tree().quit()
