extends TestCase
## The real hand in passthrough: where the hand shape is in front of a virtual
## object it clears colour and alpha (the passthrough shows); where a virtual
## object is in front of the hand, the object stays. Needs a renderer:
## godot --xr-mode off --path . res://tests/run.tscn -- --profile=test --only=hand_reveal

const SIZE := 64


func test_the_hand_cuts_through_what_is_behind_it_only() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(Camera3D.new())
	var hand := TrackedHand.reveal_material()
	_quad(viewport, Vector2(10, 10), Vector3(0, 0, -2), Color.RED, null) # behind everything
	_quad(viewport, Vector2(1.6, 1.6), Vector3(-0.8, 0, -1), Color.WHITE, hand) # the left half
	_quad(viewport, Vector2(0.4, 0.4), Vector3(-0.2, 0.2, -0.5), Color.GREEN, null) # in front, top left
	await frames(3)
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	expect(image.get_pixel(16, 48).a < 0.02, "the hand in front: see-through (%s)" % image.get_pixel(16, 48))
	expect(image.get_pixel(48, 48).is_equal_approx(Color.RED), "no hand: the object (%s)" % image.get_pixel(48, 48))
	expect(image.get_pixel(16, 16).is_equal_approx(Color.GREEN), "an object in front of the hand stays (%s)" % image.get_pixel(16, 16))
	viewport.free()


## Menus are drawn over everything; the hand still clears them where it is,
## faces and text alike, and leaves the rest.
func test_the_hand_clears_menus() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	viewport.add_child(Camera3D.new())
	_quad(viewport, Vector2(10, 10), Vector3(0, 0, -0.5), Color.RED, TaskMenu._flat(Color.RED, 2)) # a menu face
	var text := TaskMenu._label("MMMM", 84)
	text.modulate = Color.GREEN
	text.pixel_size = 0.004
	text.position = Vector3(0, 0, -0.45)
	viewport.add_child(text)
	_quad(viewport, Vector2(1.6, 1.6), Vector3(-0.8, 0, -1), Color.WHITE, TrackedHand.reveal_material()) # the left half, behind the menu
	await frames(3)
	var image := viewport.get_texture().get_image()
	image.convert(Image.FORMAT_RGBA8)
	var text_pixels := 0
	for y in SIZE:
		for x in range(SIZE / 2, SIZE):
			text_pixels += 1 if image.get_pixel(x, y).g > 0.5 else 0
	for y in SIZE:
		for x in SIZE / 2 - 1:
			expect(image.get_pixel(x, y).a < 0.02, "the hand clears face and text (%d, %d: %s)" % [x, y, image.get_pixel(x, y)])
			if image.get_pixel(x, y).a >= 0.02:
				viewport.free()
				return
	expect(text_pixels > 0, "the text shows beside the hand")
	expect(image.get_pixel(60, 4).is_equal_approx(Color.RED), "no hand: the menu (%s)" % image.get_pixel(60, 4))
	viewport.free()


func _quad(viewport: SubViewport, size: Vector2, at: Vector3, colour: Color, material: Material) -> void:
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size
	quad.mesh = mesh
	if material == null:
		var plain := StandardMaterial3D.new()
		plain.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		plain.albedo_color = colour
		material = plain
	quad.material_override = material
	quad.position = at
	viewport.add_child(quad)
