extends Node
## Close-ups of the teaching hand alone (DemoHand, whichever body it uses), frozen at exact moments of
## each gesture: from where the child sits (50 cm) and from the hand's side, top and front. Not part of the game.
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . res://tools/hand_closeups.tscn
var _out := ProjectSettings.globalize_path("res://build/hand_closeups")

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(800, 600)
	var world := Node3D.new()
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	world.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.32, 0.2)   # a table
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	world.add_child(env)
	var gear := Node3D.new()   # a 10 cm gear stand-in (a low base and the central shaft), origin at the middle of its base
	for part in [[0.05, 0.012, 0.006], [0.006, 0.048, 0.024]]:
		var piece := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = part[0]
		cylinder.bottom_radius = part[0]
		cylinder.height = part[1]
		piece.mesh = cylinder
		piece.position.y = part[2]
		gear.add_child(piece)
	world.add_child(gear)
	var marker := MeshInstance3D.new()   # the pinch point: where the thumb's and index finger's tips must meet
	var ball := SphereMesh.new()
	ball.radius = 0.004
	ball.height = 0.008
	var red := StandardMaterial3D.new()
	red.albedo_color = Color.RED
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.no_depth_test = true
	ball.material = red
	marker.mesh = ball
	world.add_child(marker)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	var demo := DemoHand.new()
	world.add_child(demo)
	var rim := Vector3(0.0, 0.12, 0.0)
	var plans := [
		["tap", func() -> void: demo.tap(rim), rim, [0.0, 0.9, 1.05, 1.6]],
		["pinch_lift", func() -> void: demo.pinch_lift(gear), Vector3(0, 0.024, 0), [0.0, 1.1, 1.7, 2.9]],
		["lower_release", func() -> void: demo.lower_release(Vector3.ZERO), Vector3(0, 0.026, 0), [0.0, 1.3, 2.4]],
	]
	for plan in plans:
		plan[1].call()
		demo.set_process(false)
		demo._fade = 1.0
		for time: float in plan[3]:
			marker.global_position = plan[2]
			demo._t = time
			demo._pose(time)
			await get_tree().process_frame
			await get_tree().process_frame
			if demo._player != null:   # where the GLB hand's finger joints are, in the pinch point's own frame
				var skel := demo._player.get_parent().find_child("Skeleton3D", true, false) as Skeleton3D
				var line := ""
				for joint in ["PointR_JNT3", "ThumbR_JNT3", "WristR_JNT", "MiddleR_JNT3"]:
					line += "%s=%s " % [joint, snapped(demo.to_local(skel.global_transform * skel.get_bone_global_pose(skel.find_bone(joint)).origin), Vector3.ONE * 0.001)]
				print("JOINTS ", plan[0], " ", time, " ", line)
			var at: Vector3 = demo.global_position
			var basis := demo.global_basis
			var views := {
				"seated": [Vector3(0.0, 0.32, 0.42), Vector3.UP],
				"side": [at + basis.x * 0.20, Vector3.UP],
				"top": [at + basis.y * 0.20, -basis.z],
				"front": [at - basis.z * 0.20 + basis.y * 0.04, Vector3.UP],
			}
			for view in views:
				camera.global_position = views[view][0]
				camera.look_at(plan[2] + Vector3.UP * 0.0 if view != "seated" else Vector3(0, 0.04, 0), views[view][1])
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(_out.path_join("%s_%.2f_%s.png" % [plan[0], time, view]))
		demo.stop()
		demo.set_process(true)
		for i in 40:
			await get_tree().process_frame
	print("HAND closeups done")
	get_tree().quit()
