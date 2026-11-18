extends Node
## PREVIEW pictures of the hub's ring of choices (Build B, Nov 17), to build/fx/ring_*.png: the opening up to
## the end of the reveal (cauldron left standing, no shelf), then the ring above the cauldron.
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://entry/fx/ring_preview.tscn -- --profile=test_capture

var _out := ProjectSettings.globalize_path("res://build/fx")
var _view := []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	RevealFx.shows_workshop = false
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	var cam := App.rig.head as Camera3D
	cam.fov = 80.0
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.run()
	var n := 0
	while not entry.zones_available() and n < 900:
		await get_tree().process_frame
		n += 1
	await _pause(0.8)
	entry.set("_cauldron_gone", true)
	entry.jump_to(&"reveal")
	await _pause(13.0)
	var panel: Node3D = entry.get("_panel")
	if panel:
		panel.visible = false
	var box: Node3D = entry.get("_box")
	box.visible = true
	box.scale = Vector3.ONE
	var mouth: Vector3 = entry.get("_mouth")
	# Seen from where v0.3 puts the child: the cauldron ~70 cm away at the side spot (this sim layout has it
	# nearer; the Hub's layout will move it), eyes ~45 cm above the table.
	var real_eye := App.head().global_position
	var toward := Vector3(real_eye.x - mouth.x, 0.0, real_eye.z - mouth.z).normalized()
	var eye := mouth + toward * 0.7 + Vector3.UP * 0.4
	_view = [eye, mouth + Vector3.UP * (ImpressionRing.ABOVE_RIM + 0.05)]
	var middle := Vector3(mouth.x, mouth.y + ImpressionRing.ABOVE_RIM, mouth.z)
	# 1. First visit: only the shelf (hidden, not sealed).
	var shelf := Impression.make(&"shelf")
	var ring := ImpressionRing.make(self, [shelf] as Array[Impression], middle, eye, mouth)
	await _pause(0.3)
	await _save("ring_1_first_visit")
	# 2. After the first shelf: the dots rise out of the cauldron and come to the front.
	var dots := Impression.make(&"dots")
	ring.add(dots, mouth)
	await _pause(ImpressionRing.RISE_SECONDS * 0.45)
	await _save("ring_2_dots_rising")
	await _pause(ImpressionRing.RISE_SECONDS * 0.55 + 0.3)
	await _save("ring_3_dots_in_front")
	# 3. Turn to fit can run: the cup joins too.
	var cup := Impression.make(&"turn_to_fit")
	ring.add(cup, mouth)
	await _pause(ImpressionRing.RISE_SECONDS + 0.3)
	await _save("ring_4_three")
	# 4. The hand aims at the shelf (left, half size): it lights softly.
	var at := shelf.target.global_position
	App.sim_input.point(&"right", real_eye + (at - real_eye).normalized() * 0.25 + Vector3.DOWN * 0.05, at)
	await _pause(0.2)
	await _save("ring_5_aim_at_shelf")
	# 5. One press: the ring turns it to the front, then it's chosen (its pulse).
	ring.press(shelf)
	await _pause(0.5)
	await _save("ring_6_turning")
	await _pause(0.6)
	var away := real_eye + Vector3(0.5, -0.4, -0.3)
	App.sim_input.point(&"right", real_eye + (away - real_eye).normalized() * 0.25 + Vector3.DOWN * 0.05, away)
	await _pause(0.2)
	await _save("ring_7_shelf_chosen")
	get_tree().quit()


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(name: String) -> void:
	var cam := App.rig.head as Camera3D
	cam.global_position = _view[0]
	cam.look_at(_view[1])
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("SHOT ", name)
