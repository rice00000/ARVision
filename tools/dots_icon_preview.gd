extends Node3D
## PREVIEW (Hub chat, Nov 17 late): the dots game's icon options side by side, with the shelf and the cup for
## comparison, on a light wall (the hardest background) and a dark one. To build/dots_icon/.

var _out := ProjectSettings.globalize_path("res://build/dots_icon")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1400, 520)
	var cam := Camera3D.new()
	cam.fov = 32.0
	add_child(cam)
	cam.position = Vector3(0, 0.09, 1.25)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(-0.6, 0.4, 0)
	add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment.background_mode = Environment.BG_COLOR
	add_child(env)
	var row := [[&"dots", &"disc", "1 today: disc"], [&"dots", &"comets", "2 rising together"], [&"dots", &"cloud", "3 cloud of dots"], [&"dots", &"lantern", "4 firefly lantern"], [&"shelf", &"", "shelf"], [&"turn_to_fit", &"", "cup"]]
	for i in row.size():
		Impression.dots_style = row[i][1] if row[i][1] != &"" else &"disc"
		var imp := Impression.make(row[i][0])
		add_child(imp)
		imp.position = Vector3(-0.55 + i * 0.22, 0.0, 0.0)
		var label := Label3D.new()
		label.text = row[i][2]
		label.font_size = 28
		label.pixel_size = 0.0007
		label.modulate = Color.BLACK
		label.outline_size = 0
		label.position = imp.position + Vector3(0, -0.045, 0)
		add_child(label)
	for wall: Array in [["light", Color(0.86, 0.84, 0.8)], ["dark", Color(0.18, 0.17, 0.16)]]:
		env.environment.background_color = wall[1]
		for l: Node in get_children():
			if l is Label3D:
				(l as Label3D).modulate = Color.BLACK if wall[0] == "light" else Color.WHITE
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_out.path_join("icons_%s.png" % wall[0]))
	get_tree().quit()
