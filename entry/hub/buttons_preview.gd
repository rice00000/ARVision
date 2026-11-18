extends Node
## PREVIEW pictures (Hub chat, Nov 17) of the table gear's buttons and the exit-task token, for Megan's OK,
## to build/hub/buttons_*.png:
##   xvfb-run -a -s "-screen 0 1280x800x24" godot --rendering-driver opengl3 --xr-mode off --path . \
##       res://entry/hub/buttons_preview.tscn -- --profile=test_capture

var _out := ProjectSettings.globalize_path("res://build/hub")


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = Vector2i(1280, 800)
	Profile.wipe()
	var app: Node3D = load("res://main.tscn").instantiate()
	app.autostart = false
	add_child(app)
	await get_tree().process_frame
	var entry: Entry = app.get_node(^"Intro/Entry")
	entry.run()
	var n := 0
	while not entry.zones_available() and n < 900:
		await get_tree().process_frame
		n += 1
	await _pause(0.8)
	entry.jump_to(&"reveal")
	await _pause(14.0)
	var panel: Node3D = entry.get("_panel")
	if panel:
		panel.visible = false
	var eye := App.head().global_position
	var mouth: Vector3 = entry.get("_mouth")
	var box: Node3D = entry.get("_box")
	var gear: Node3D = entry.get("_gear")
	var shelf: Node3D = entry.get("_shelf")
	var middle := Vector3(mouth.x, mouth.y + ImpressionRing.ABOVE_RIM, mouth.z)
	# The hub: the ring (shelf + dots) and the gear's buttons shown (a hand came near).
	var ring := ImpressionRing.make(self, [Impression.make(&"shelf"), Impression.make(&"dots")] as Array[Impression], middle, eye, mouth)
	var menu := GearMenu.make(self, gear.global_position + Vector3.UP * 0.03, eye, true)
	menu.set_stones(3)
	menu.reveal()
	if shelf:
		shelf.visible = false
	await _pause(0.6)
	await _save("buttons_1_hub", eye, (middle + gear.global_position) * 0.5, 75.0)
	await _save("buttons_2_gear_close", eye, gear.global_position + Vector3.UP * 0.1, 28.0)
	# A task runs: the ring and the gear's buttons are away; the exit token sits low beside the cauldron.
	ring.visible = false
	menu.set_enabled(false)
	if shelf:
		shelf.visible = true
	var pot := box.global_position
	var to_eye := Vector3(eye.x - pot.x, 0.0, eye.z - pot.z).normalized()
	var exit := HubButton.make(&"exit_task", &"exit", 0.04)
	add_child(exit)
	exit.global_position = pot + to_eye * 0.17 + Vector3.UP * 0.06
	exit.face(eye)
	exit.set_open(true)
	await _pause(0.4)
	await _save("buttons_3_task_exit", eye, (pot + gear.global_position) * 0.5 + Vector3.UP * 0.05, 75.0)
	await _save("buttons_4_exit_close", eye, exit.global_position, 28.0)
	get_tree().quit()


func _pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _save(name: String, eye: Vector3, at: Vector3, fov: float) -> void:
	var cam := App.rig.head as Camera3D
	cam.fov = fov
	cam.global_position = eye
	cam.look_at(at)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))
	print("SHOT ", name)
