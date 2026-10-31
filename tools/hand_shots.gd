extends Node
## Frames of the candidate teaching hand (asset chat's right_hand_demo.glb): not part of the game.
var _out := ProjectSettings.globalize_path("res://build/hand")

func _ready() -> void:
	get_window().size = Vector2i(900, 700)
	var world := Node3D.new()
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, 30, 0)
	world.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.25, 0.27, 0.3)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	world.add_child(env)
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(_out.path_join("right_hand_demo.glb"), state)
	print("HAND load err ", err)
	var hand: Node3D = doc.generate_scene(state)
	world.add_child(hand)
	var player: AnimationPlayer = hand.find_child("AnimationPlayer", true, false)
	print("HAND anims ", player.get_animation_list())
	# an axes marker at the origin: red +x, green +y, blue +z
	for axis in 3:
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		var size := Vector3(0.002, 0.002, 0.002)
		size[axis] = 0.08
		box.size = size
		var mat := StandardMaterial3D.new()
		mat.albedo_color = [Color.RED, Color.GREEN, Color.BLUE][axis]
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		box.material = mat
		bar.mesh = box
		var off := Vector3.ZERO
		off[axis] = 0.04
		bar.position = off
		world.add_child(bar)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.current = true
	var views := {
		"side_x": [Vector3(0.28, 0.02, 0.0), "x"],      # looking along -x (from the hand's right)
		"top": [Vector3(0.0, 0.3, 0.001), "y"],
		"front": [Vector3(0.0, 0.02, -0.3), "z"],       # in front of the fingers (they point -z)
		"back": [Vector3(0.0, 0.02, 0.3), "z"],
	}
	var poses := [["idle", 0.0], ["pinch", 0.0], ["pinch", 0.5], ["pinch", 1.0], ["tap", 0.0], ["tap", 0.5]]
	for pose in poses:
		player.play(pose[0])
		player.seek(pose[1], true)
		player.pause()
		await get_tree().process_frame
		for view in views:
			cam.global_position = views[view][0]
			cam.look_at(Vector3(0, 0.0, 0.0), Vector3.UP if view != "top" else Vector3.FORWARD)
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_out.path_join("%s_%.1f_%s.png" % [pose[0], pose[1], view]))
	print("HAND done")
	get_tree().quit()
