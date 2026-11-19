extends Node3D
## Close-up pictures of the hanging lantern (Kay Lousberg, CC0) and its glow, to build/fx/:
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://tools/lantern_preview.tscn -- --bare
## --bare: the model alone, lit (to see its parts). Default: a lantern glowing in a dark room, two moments.

var _out := ProjectSettings.globalize_path("res://build/fx")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(900, 900)
	var bare := "--bare" in OS.get_cmdline_user_args()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.55, 0.58) if bare else Color(0.16, 0.15, 0.15)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.8 if bare else 0.25
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.light_energy = 1.0 if bare else 0.3
	add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 40.0
	add_child(cam)
	if bare:
		var model: Node3D = load(Lantern.MODEL).instantiate()
		add_child(model)
		var box := Lantern.bounds(model)
		print("LANTERN bounds ", box)
		var c := box.get_center()
		for view: Array in [["front", Vector3(0, 0, 1)], ["side", Vector3(1, 0.3, 0.6)]]:
			cam.look_at_from_position(c + (view[1] as Vector3).normalized() * box.size.length() * 1.6, c)
			await _settle()
			get_viewport().get_texture().get_image().save_png(_out.path_join("lantern_bare_%s.png" % view[0]))
	else:
		var lantern := Lantern.make(self, Vector3(0, 0.3, 0), true)
		var floor_ := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(2, 2)
		floor_.mesh = plane
		floor_.position = Vector3(0, -0.35, 0)
		add_child(floor_)
		var wall := MeshInstance3D.new()
		var wall_plane := PlaneMesh.new()
		wall_plane.size = Vector2(2, 2)
		wall.mesh = wall_plane
		wall.rotation_degrees = Vector3(90, 0, 0)
		wall.position = Vector3(0, 0.3, -0.25)
		add_child(wall)
		cam.look_at_from_position(Vector3(0, 0.1, 1.3), Vector3(0, 0.02, 0))
		for i in 2:
			await _settle(1.3)
			get_viewport().get_texture().get_image().save_png(_out.path_join("lantern_glow_%d.png" % i))
		lantern.queue_free()
	get_tree().quit()


func _settle(seconds := 0.3) -> void:
	var until := Engine.get_process_frames() + int(seconds * 60.0)
	while Engine.get_process_frames() < until:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
