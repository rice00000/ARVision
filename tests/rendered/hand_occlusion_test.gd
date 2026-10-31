extends TestCase
## Render the official hand over virtual geometry: the nearer surface wins,
## and the hand writes transparent colour so passthrough can show through.

func test_the_hand_reveals_passthrough_only_in_front_of_virtual_objects() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 320)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.28
	viewport.add_child(camera)
	var light := DirectionalLight3D.new()
	viewport.add_child(light)
	var scene: PackedScene = load("res://rig/hands/RightHandHumanoid.gltf")
	var hand := scene.instantiate() as Node3D
	viewport.add_child(hand)
	var mesh := hand.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var material := ShaderMaterial.new()
	material.shader = preload("res://rig/hand_occlusion.gdshader")
	mesh.material_override = material
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var box := mesh.global_transform * mesh.get_aabb()
	hand.position = Vector3(0.0, 0.0, -1.0) - box.get_center()
	var backdrop := MeshInstance3D.new()
	backdrop.mesh = QuadMesh.new()
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color.RED
	backdrop.material_override = red
	backdrop.position.z = -2.0
	viewport.add_child(backdrop)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var behind := viewport.get_texture().get_image()
	var clear := _clear_pixels(behind)
	expect(clear > 100 and clear < 50000, "only the hand silhouette is transparent: %d pixels" % clear)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/hand_check"))
	behind.save_png("res://build/hand_check/occlusion.png")
	backdrop.position.z = -0.5
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	expect_eq(_clear_pixels(viewport.get_texture().get_image()), 0, "a virtual object in front still covers the hand")
	viewport.queue_free()


func _clear_pixels(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < 0.05:
				count += 1
	return count
